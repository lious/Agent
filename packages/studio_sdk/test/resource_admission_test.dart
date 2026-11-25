import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:studio_sdk/studio_sdk.dart';
import 'package:studio_store/project_archive.dart';

import 'resource_fixture.dart';

Map<String, dynamic> coreResourceFixture() => jsonDecode(
  File(
    '${File(Platform.environment['STUDIO_TEST_VIDEO']!).parent.parent.parent.path}/fixtures/project/local-video.json',
  ).readAsStringSync(),
) as Map<String, dynamic>;

void main() {
  late Directory dir;
  late StudioWorkspace w;
  late File video;
  setUp(() {
    dir = Directory.systemTemp.createTempSync('resource-admission-');
    video = File(Platform.environment['STUDIO_TEST_VIDEO']!);
    w = StudioWorkspace.open(
      profile: AppProfile(
        appId: 'studio',
        region: 'local',
        features: {'project.metadata', 'media.local'},
      ),
      databasePath: '${dir.path}/db',
      tenantId: 'local',
      workspaceId: 'admission',
      mediaLibraryPath: Platform.environment['STUDIO_MEDIA_LIBRARY'],
      mediaRootPath: '${dir.path}/media',
    );
    w.openDemo();
  });
  tearDown(() {
    w.close();
    dir.deleteSync(recursive: true);
  });
  Future<ResourcePreservationSession> load(
    Map<String, dynamic> d, {
    File? granted,
  }) async {
    final json = File('${dir.path}/input.json')
      ..writeAsStringSync(jsonEncode(d));
    final s = await ResourcePreservationSession.openJson(
      LocalFileGrant.fromUserSelection(json),
    );
    await s.attach(LocalFileGrant.fromUserSelection(granted ?? video));
    return s;
  }

  Future<ProjectDocument> adopt(
    ResourcePreservationSession s, {
    String? activeHash,
  }) => w.adoptPreservedResources(
    s,
    expectedCollectionReviewHash: s.collectionReviewHash,
    expectedActiveHash: activeHash ?? w.current.hash,
    confirmed: true,
  );

  test('REAL native qualification -> writable fork -> ImportMap -> edit/archive/reopen/original-file export', () async {
    final producer = StudioWorkspace.open(
      profile: w.profile,
      databasePath: '${dir.path}/origin-db',
      tenantId: 'local',
      workspaceId: 'origin',
      mediaLibraryPath: Platform.environment['STUDIO_MEDIA_LIBRARY'],
      mediaRootPath: '${dir.path}/origin-media',
    );
    late ProjectDocument old;
    try {
      producer.openDemo();
      old = await producer.importVideo(
        LocalFileGrant.fromUserSelection(video),
        expectedRevision: producer.current.revision,
      );
    } finally {
      producer.close();
    }
    final s = await load(old.toJson());
    final p = await adopt(s), map = w.currentImportMap!;
    expect(p.projectId, isNot(s.project.projectId));
    expect(p.revision, BigInt.zero);
    expect(map['origin']['snapshotHash'], s.project.hash);
    expect(map['local']['snapshotHash'], p.hash);
    expect(map['entityIds'][s.project.projectId], p.projectId);
    expect(map['entityIds'].values.toSet().length, map['entityIds'].length);
    w.rename('adopted and edited', expectedRevision: p.revision);
    final head = w.current.hash;
    await w.saveArchive(File('${dir.path}/adopted.zip'));
    expect(
      ProjectArchive().open(File('${dir.path}/adopted.zip')).project.hash,
      head,
    );
    final result = await w.exportVideo(File('${dir.path}/adopted.mp4'));
    expect(result, isNotEmpty);
    expect(File('${dir.path}/adopted.mp4').lengthSync(), greaterThan(0));
    w.close();
    w = StudioWorkspace.open(
      profile: AppProfile(
        appId: 'studio',
        region: 'local',
        features: {'project.metadata', 'media.local'},
      ),
      databasePath: '${dir.path}/db',
      tenantId: 'local',
      workspaceId: 'admission',
      mediaLibraryPath: Platform.environment['STUDIO_MEDIA_LIBRARY'],
      mediaRootPath: '${dir.path}/media',
    );
    w.openDemo();
    expect(w.current.hash, head);
    expect(w.currentImportMap, map);
    expect(old.projectId, isNot(w.current.projectId));
  });
  test('REAL AAC source qualification decodes bounded PCM and adopted timeline exports its audio', () async {
    final av = File('${dir.path}/av.mp4');
    final made = Process.runSync('ffmpeg', [
      '-v',
      'error',
      '-i',
      video.path,
      '-f',
      'lavfi',
      '-i',
      'sine=frequency=997:sample_rate=44100:duration=3',
      '-c:v',
      'copy',
      '-c:a',
      'aac',
      '-ac',
      '2',
      av.path,
    ]);
    expect(made.exitCode, 0, reason: '${made.stderr}');
    final origin = await w.importVideo(
      LocalFileGrant.fromUserSelection(av),
      expectedRevision: w.current.revision,
      acknowledgeVideoOnly: true,
    );
    final s = await load(origin.toJson(), granted: av);
    await adopt(s);
    final output = File('${dir.path}/adopted-av.mp4');
    await w.exportVideo(output, includeEmbeddedAudio: true);
    final media = NativeMedia.open(
      Platform.environment['STUDIO_MEDIA_LIBRARY']!,
      w.current.namespace,
    );
    try {
      expect(
        (media.probe(output)['streams'] as List).any(
          (v) => v['type'] == 'audio' && v['sampleRate'] == 48000,
        ),
        true,
      );
    } finally {
      media.close();
    }
  });
  test('REAL opaque/font/mask/image content stays readonly, never stripped to pass renderer gate', () async {
    final data = resourceFixture(
      fixtureFont().readAsBytesSync(),
      fixtureMask(),
    );
    final s = await load(data),
        before = w.current.hash,
        inventory = w.namespaceStorageInventory();
    await expectLater(
      adopt(s),
      throwsA(
        isA<StudioException>().having(
          (e) => e.code,
          'code',
          'FEATURE_NOT_IMPLEMENTED',
        ),
      ),
    );
    expect(w.current.hash, before);
    expect(s.project.toJson(), data);
    expect(w.namespaceStorageInventory(), inventory);
    final opaque = coreResourceFixture();
    opaque['extensions'] = {
      'vendor.library': {'lutHash': data['blobs'][1]['hash']},
    };
    final u = await load(opaque);
    await expectLater(adopt(u), throwsA(isA<StudioException>()));
    expect(u.project.toJson()['extensions'], opaque['extensions']);
    expect(w.currentImportMap, isNull);
  });
  test(
    'REAL native source metadata forgery rejected without project publication',
    () async {
      final d = coreResourceFixture();
      d['assets'][0]['streams'][0]['codec'] = 'vp9';
      final s = await load(d), hash = w.current.hash;
      await expectLater(
        adopt(s),
        throwsA(
          isA<StudioException>().having(
            (e) => e.code,
            'code',
            'SOURCE_STREAM_CHANGED',
          ),
        ),
      );
      expect(w.current.hash, hash);
      expect(w.currentImportMap, isNull);
    },
  );
  test('REAL explicit cancellation and intervening revision reject adoption without switching projects', () async {
    final s = await load(coreResourceFixture()), hash = w.current.hash;
    var pending = adopt(s);
    w.cancelResourceImport();
    await expectLater(
      pending,
      throwsA(isA<StudioException>().having((e) => e.code, 'code', 'CANCELED')),
    );
    expect(w.current.hash, hash);
    pending = adopt(s);
    w.rename('concurrent edit', expectedRevision: w.current.revision);
    final edited = w.current.hash;
    await expectLater(
      pending,
      throwsA(
        isA<StudioException>().having(
          (e) => e.code,
          'code',
          'REVISION_CONFLICT',
        ),
      ),
    );
    expect(w.current.hash, edited);
    expect(w.currentImportMap, isNull);
    await expectLater(
      adopt(s, activeHash: hash),
      throwsA(isA<StudioException>()),
    );
  });
  test('REAL namespace budget rejects resource adoption without project, source or reservation leakage', () async {
    final s = await load(coreResourceFixture()), before = w.current.hash;
    await w.configureNamespaceDiskBudget('20000', confirmed: true);
    final inventory = w.namespaceStorageInventory();
    await expectLater(
      adopt(s),
      throwsA(
        isA<StudioException>().having(
          (e) => e.code,
          'code',
          'NAMESPACE_DISK_BUDGET_EXCEEDED',
        ),
      ),
    );
    expect(w.current.hash, before);
    expect(w.currentImportMap, isNull);
    expect(w.namespaceStorageInventory(), inventory);
  });
  test('REAL retained full-Project snapshot/pin qualification and archive reopen; no retained renderer claim', () async {
    final old = coreResourceFixture(),
        snapshot = Uint8List.fromList(
          utf8.encode(ProjectDocument.fromJson(old).canonicalJson),
        );
    final hash = rawBytesHash(snapshot), d = coreResourceFixture();
    d['assets'][0]['version'] = '2';
    d['retainedSources'] = [
      {
        'kind': 'asset',
        'id': old['assets'][0]['id'],
        'version': '1',
        'definitionBlobHash': hash,
        'dependencyBlobHashes': [old['blobs'][0]['hash']],
      },
    ];
    d['blobs'].add({
      'hash': hash,
      'bytes': snapshot.length.toString(),
      'mime': 'application/json',
      'role': 'snapshot',
      'packagePath': 'snapshots/retained.json',
    });
    final s = await load(d),
        definition = File('${dir.path}/definition.json')
          ..writeAsBytesSync(snapshot);
    expect(s.report['registeredClosure'], false);
    await s.attach(LocalFileGrant.fromUserSelection(definition));
    expect(s.report['registeredClosure'], true);
    expect(s.report['renderExecutable'], false);
    final zip = File('${dir.path}/retained.zip');
    await s.saveArchive(
      zip,
      confirmedCollection: true,
      expectedCollectionReviewHash: s.collectionReviewHash,
    );
    expect(
      (await ResourcePreservationSession.openArchive(
        LocalFileGrant.fromUserSelection(zip),
      )).report['registeredClosure'],
      true,
    );
    await expectLater(adopt(s), throwsA(isA<StudioException>()));
    Map<String, Uint8List> collected = {
      hash: snapshot,
      old['blobs'][0]['hash']: video.readAsBytesSync(),
    };
    final badPins = jsonDecode(jsonEncode(d)) as Map<String, dynamic>;
    badPins['retainedSources'][0]['dependencyBlobHashes'] = [];
    expect(
      (qualifyResourceClosure(
                ProjectDocument.fromJson(badPins),
                collected,
              )['issues']
              as List)
          .any((i) => i['code'] == 'RETAINED_DEPENDENCY_UNPINNED'),
      true,
    );
    collected[hash] = Uint8List.fromList([1, 2]);
    expect(
      (qualifyResourceClosure(s.project, collected)['issues'] as List).any(
        (i) => i['code'] == 'BLOB_HASH_MISMATCH',
      ),
      true,
    );

    Map<String, dynamic> withDefinition(Uint8List value) {
      final copy = jsonDecode(jsonEncode(d)) as Map<String, dynamic>,
          h = rawBytesHash(value);
      copy['retainedSources'][0]['definitionBlobHash'] = h;
      copy['blobs'].last['hash'] = h;
      copy['blobs'].last['bytes'] = value.length.toString();
      return copy;
    }

    List<dynamic> issuesFor(
      Map<String, dynamic> doc,
      Map<String, Uint8List> bytes,
    ) =>
        qualifyResourceClosure(ProjectDocument.fromJson(doc), bytes)['issues']
            as List;
    final invalid = Uint8List.fromList(utf8.encode('[]'));
    expect(
      issuesFor(withDefinition(invalid), {
        rawBytesHash(invalid): invalid,
      }).any((i) => i['code'] == 'RETAINED_SNAPSHOT_INVALID'),
      true,
    );
    final foreign = coreResourceFixture();
    foreign['namespace']['workspaceId'] = 'foreign';
    final fb = Uint8List.fromList(
      utf8.encode(ProjectDocument.fromJson(foreign).canonicalJson),
    );
    expect(
      issuesFor(withDefinition(fb), {
        rawBytesHash(fb): fb,
      }).any((i) => i['code'] == 'RETAINED_ORIGIN_MISMATCH'),
      true,
    );
    final wrong = coreResourceFixture();
    wrong['assets'][0]['version'] = '3';
    wrong['sequences'][0]['tracks'][0]['items'][0]['source']['version'] = '3';
    final wb = Uint8List.fromList(
      utf8.encode(ProjectDocument.fromJson(wrong).canonicalJson),
    );
    expect(
      issuesFor(withDefinition(wb), {
        rawBytesHash(wb): wb,
      }).any((i) => i['code'] == 'SOURCE_VERSION_MISSING'),
      true,
    );
    var chain = ProjectDocument.fromJson(coreResourceFixture());
    final chainBytes = <String, Uint8List>{
      old['blobs'][0]['hash']: video.readAsBytesSync(),
    };
    for (var i = 2; i <= 11; i++) {
      final value = Uint8List.fromList(utf8.encode(chain.canonicalJson)),
          h = rawBytesHash(value),
          next = chain.toJson();
      chainBytes[h] = value;
      next['assets'][0]['version'] = '$i';
      next['sequences'][0]['version'] = '$i';
      next['sequences'][0]['tracks'][0]['items'][0]['version'] = '$i';
      next['sequences'][0]['tracks'][0]['items'][0]['source']['version'] = '$i';
      next['retainedSources'] = [
        {
          'kind': 'asset',
          'id': old['assets'][0]['id'],
          'version': '${i - 1}',
          'definitionBlobHash': h,
          'dependencyBlobHashes': [for (final b in next['blobs']) b['hash']],
        },
      ];
      next['blobs'].add({
        'hash': h,
        'bytes': value.length.toString(),
        'mime': 'application/json',
        'role': 'snapshot',
        'packagePath': 'snapshots/retained-$i.json',
      });
      chain = ProjectDocument.fromJson(next);
    }
    expect(
      (qualifyResourceClosure(chain, chainBytes)['issues'] as List).any(
        (i) => i['code'] == 'RETAINED_CLOSURE_LIMIT',
      ),
      true,
    );
  });
}
