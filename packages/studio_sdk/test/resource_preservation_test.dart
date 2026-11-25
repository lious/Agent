import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:studio_sdk/studio_sdk.dart';
import 'package:studio_store/project_archive.dart';

import 'resource_fixture.dart';

Matcher code(String c) =>
    throwsA(isA<StudioException>().having((e) => e.code, 'code', c));
void main() {
  late Directory dir;
  late File json, font, mask, video;
  late Map<String, dynamic> data;
  Future<ResourcePreservationSession> load() =>
      ResourcePreservationSession.openJson(
        LocalFileGrant.fromUserSelection(json),
      );
  Future<void> attachAll(ResourcePreservationSession s) async {
    for (final f in [font, mask, video]) {
      await s.attach(LocalFileGrant.fromUserSelection(f));
    }
  }

  setUp(() {
    dir = Directory.systemTemp.createTempSync('resource-preservation-');
    font = fixtureFont();
    mask = File('${dir.path}/mask.png')..writeAsBytesSync(fixtureMask());
    video = File(Platform.environment['STUDIO_TEST_VIDEO']!);
    data = resourceFixture(font.readAsBytesSync(), mask.readAsBytesSync());
    json = File('${dir.path}/project.json')
      ..writeAsStringSync(jsonEncode(data));
  });
  tearDown(() => dir.deleteSync(recursive: true));
  test('REAL source/font/mask/image collection → metadata/archive → separate-process reopen → registered fork preserves hashes/refs, not execution', () async {
    final s = await load();
    expect(s.report['missingBytes'], hasLength(3));
    expect(s.report['registeredClosure'], true);
    final missing = File('${dir.path}/missing.zip');
    await expectLater(
      s.saveArchive(
        missing,
        confirmedCollection: true,
        expectedCollectionReviewHash: s.collectionReviewHash,
      ),
      code('RESOURCE_BYTES_MISSING'),
    );
    expect(missing.existsSync(), false);
    await attachAll(s);
    expect(s.report['missingBytes'], isEmpty);
    expect(s.report['renderExecutable'], false);
    expect(
      (s.report['resources'] as List).every(
        (r) => r['formatQualification'] == 'notRun',
      ),
      true,
    );
    final zip = File('${dir.path}/project.zip');
    await expectLater(
      s.saveArchive(
        zip,
        confirmedCollection: false,
        expectedCollectionReviewHash: s.collectionReviewHash,
      ),
      code('RESOURCE_COLLECTION_CONFIRMATION_REQUIRED'),
    );
    await s.saveMetadata(File('${dir.path}/saved.json'));
    expect(
      (await ResourcePreservationSession.openJson(
        LocalFileGrant.fromUserSelection(File('${dir.path}/saved.json')),
      )).project.hash,
      s.project.hash,
    );
    await s.saveArchive(
      zip,
      confirmedCollection: true,
      expectedCollectionReviewHash: s.collectionReviewHash,
    );
    expect(
      ProjectArchive().open(zip, preservationOnly: true).preservationOnly,
      true,
    );
    expect(() => ProjectArchive().open(zip), code('FEATURE_NOT_IMPLEMENTED'));
    final child = await Process.run(Platform.resolvedExecutable, [
      'run',
      'packages/studio_sdk/tool/resource_preservation_probe.dart',
      zip.path,
    ]);
    expect(child.exitCode, 0, reason: child.stderr.toString());
    final decoded = jsonDecode(child.stdout as String);
    expect(decoded['projectHash'], s.project.hash);
    expect(decoded['report']['missingBytes'], isEmpty);
    final reopened = await ResourcePreservationSession.openArchive(
      LocalFileGrant.fromUserSelection(zip),
    );
    expect(reopened.project.toJson(), data);
    final fork = reopened.fork(Namespace('studio', 'local', 'target'));
    final d = fork.project.toJson();
    expect(d['projectId'], isNot(data['projectId']));
    expect(d['revision'], '0');
    expect(d['fontRefs'][0]['hash'], data['fontRefs'][0]['hash']);
    expect(d['imageDocuments'][0]['fontRefs'][0], d['fontRefs'][0]['id']);
    expect(
      d['imageDocuments'][0]['layers'][0]['sourceRef']['id'],
      d['assets'][0]['id'],
    );
    expect(
      d['effects'][0]['owner']['id'],
      d['imageDocuments'][0]['layers'][0]['id'],
    );
    expect(
      d['imageDocuments'][0]['layers'][0]['maskRef'],
      data['imageDocuments'][0]['layers'][0]['maskRef'],
    );
    expect(
      d['assets'][0]['originalBlobHash'],
      data['assets'][0]['originalBlobHash'],
    );
    final out = File('${dir.path}/fork.zip');
    await fork.saveArchive(
      out,
      confirmedCollection: true,
      expectedCollectionReviewHash: fork.collectionReviewHash,
    );
    expect(
      (await ResourcePreservationSession.openArchive(
        LocalFileGrant.fromUserSelection(out),
      )).project.hash,
      fork.project.hash,
    );
    expect(font.readAsBytesSync().length.toString(), data['blobs'][1]['bytes']);
    expect(video.existsSync(), true);
    final generatedData = resourceFixture(
      font.readAsBytesSync(),
      mask.readAsBytesSync(),
    );
    generatedData['blobs'][0]['role'] = 'generated';
    final generatedJson = File('${dir.path}/generated.json')
      ..writeAsStringSync(jsonEncode(generatedData));
    final generated = await ResourcePreservationSession.openJson(
      LocalFileGrant.fromUserSelection(generatedJson),
    );
    await attachAll(generated);
    final generatedZip = File('${dir.path}/generated.zip');
    await generated.saveArchive(
      generatedZip,
      confirmedCollection: true,
      expectedCollectionReviewHash: generated.collectionReviewHash,
    );
    expect(
      ProjectArchive()
          .open(generatedZip, preservationOnly: true)
          .project
          .toJson()['blobs'][0]['role'],
      'generated',
    );
  });
  test('REAL opaque LUT/library refs remain byte-preserved metadata; missing/role resources diagnosed without guessing opaque hashes or fork', () async {
    data['extensions'] = {
      'vendor.library.v1': {
        'id': 'font-fixture',
        'version': 7,
        'hash': data['blobs'][1]['hash'],
        'locator': 'file:///not-followed',
      },
    };
    json.writeAsStringSync(jsonEncode(data));
    final s = await load();
    expect(
      (s.report['issues'] as List).any(
        (e) => e['code'] == 'UNRESOLVED_EXTENSION_CLOSURE',
      ),
      true,
    );
    await attachAll(s);
    await s.saveMetadata(File('${dir.path}/opaque.json'));
    final restored = await ResourcePreservationSession.openJson(
      LocalFileGrant.fromUserSelection(File('${dir.path}/opaque.json')),
    );
    expect(restored.project.toJson()['extensions'], data['extensions']);
    await expectLater(
      s.saveArchive(
        File('${dir.path}/opaque.zip'),
        confirmedCollection: true,
        expectedCollectionReviewHash: s.collectionReviewHash,
      ),
      code('UNRESOLVED_EXTENSION_CLOSURE'),
    );
    expect(
      () => s.fork(Namespace('studio', 'local', 'other')),
      code('UNRESOLVED_EXTENSION_CLOSURE'),
    );
    data['extensions'] = {};
    data['effects'][0]['type'] = 'vendor/lut3d';
    data['effects'][0]['parameters'] = {
      'lutHash': data['blobs'][1]['hash'],
      'libraryRef': 'external-library-v2',
    };
    json.writeAsStringSync(jsonEncode(data));
    expect((await load()).report['issues'], isNotEmpty);
    data = resourceFixture(font.readAsBytesSync(), mask.readAsBytesSync());
    data['blobs'].removeAt(1);
    json.writeAsStringSync(jsonEncode(data));
    final missing = await load();
    expect(
      (missing.report['issues'] as List).any(
        (e) => e['code'] == 'MISSING_RESOURCE_DECLARATION',
      ),
      true,
    );
    data = resourceFixture(font.readAsBytesSync(), mask.readAsBytesSync());
    data['blobs'][1]['role'] = 'original';
    json.writeAsStringSync(jsonEncode(data));
    expect(
      (await load()).report['issues'][0]['code'],
      'RESOURCE_ROLE_MISMATCH',
    );
  });
  test('REAL corrupted/wrong-size/unrelated inputs do not enter collection; stale consent and cancel cannot publish', () async {
    final s = await load();
    final stale = s.collectionReviewHash;
    await s.attach(LocalFileGrant.fromUserSelection(font));
    await expectLater(
      s.saveArchive(
        File('${dir.path}/stale.zip'),
        confirmedCollection: true,
        expectedCollectionReviewHash: stale,
      ),
      code('RESOURCE_COLLECTION_REVIEW_STALE'),
    );
    final wrong = File('${dir.path}/wrong')
      ..writeAsStringSync('not a declared resource');
    await expectLater(
      s.attach(LocalFileGrant.fromUserSelection(wrong)),
      code('DECLARED_RESOURCE_REQUIRED'),
    );
    await attachAll(s);
    final output = File('${dir.path}/cancel.zip'),
        pending = s.saveArchive(
          output,
          confirmedCollection: true,
          expectedCollectionReviewHash: s.collectionReviewHash,
        );
    s.cancelPending();
    await expectLater(pending, code('CANCELED'));
    expect(output.existsSync(), false);
    expect(dir.listSync().where((e) => e.path.endsWith('.pending')), isEmpty);
    data['blobs'][1]['bytes'] = '1';
    json.writeAsStringSync(jsonEncode(data));
    await expectLater(
      (await load()).attach(LocalFileGrant.fromUserSelection(font)),
      code('BLOB_SIZE_MISMATCH'),
    );
  });
  test('REAL no-clobber outputs and symlink input/output refuse; existing source/target bytes remain', () async {
    final s = await load();
    await attachAll(s);
    final output = File('${dir.path}/existing')
      ..writeAsStringSync('original stays');
    await expectLater(
      s.saveArchive(
        output,
        confirmedCollection: true,
        expectedCollectionReviewHash: s.collectionReviewHash,
      ),
      code('OUTPUT_ALREADY_EXISTS'),
    );
    expect(output.readAsStringSync(), 'original stays');
    final link = Link('${dir.path}/link')..createSync(output.path);
    await expectLater(
      ResourcePreservationSession.openJson(
        LocalFileGrant.fromUserSelection(File(link.path)),
      ),
      code('LOCAL_FILE_REQUIRED'),
    );
    await expectLater(
      s.saveMetadata(File(link.path)),
      code('UNSAFE_OUTPUT_TARGET'),
    );
    expect(output.readAsStringSync(), 'original stays');
    final same = File('${dir.path}/race.json');
    final results = await Future.wait([
      s.saveMetadata(same).then((_) => true, onError: (_) => false),
      s.saveMetadata(same).then((_) => true, onError: (_) => false),
    ]);
    expect(results.where((v) => v).length, 1);
    expect(
      (await ResourcePreservationSession.openJson(
        LocalFileGrant.fromUserSelection(same),
      )).project.hash,
      s.project.hash,
    );
  });
  test('REAL two-process prepared publishers race one new target; exactly one wins without clobber', () async {
    final children = <Process>[], errors = <Future<String>>[];
    try {
      for (var i = 0; i < 2; i++) {
        final child = await Process.start(Platform.resolvedExecutable, [
          'run',
          'packages/studio_sdk/tool/resource_publish_worker.dart',
          dir.path,
          i.toString(),
        ]);
        children.add(child);
        errors.add(child.stderr.transform(utf8.decoder).join());
      }
      await Future.wait(
        children.map(
          (p) => p.stdout
              .transform(utf8.decoder)
              .transform(const LineSplitter())
              .firstWhere((l) => l == 'READY')
              .timeout(const Duration(seconds: 20)),
        ),
      );
      for (final p in children) {
        p.stdin.add([1]);
        await p.stdin.flush();
      }
      final codes = await Future.wait(children.map((p) => p.exitCode));
      final diagnostics = await Future.wait(errors);
      expect(
        codes.where((c) => c == 0).length,
        1,
        reason: '$codes $diagnostics',
      );
      expect(codes.where((c) => c == 7).length, 1);
      final winner = jsonDecode(
        File('${dir.path}/process-race.json').readAsStringSync(),
      )['winner'];
      expect(codes[winner as int], 0);
      expect(dir.listSync().where((e) => e.path.endsWith('.pending')), isEmpty);
    } finally {
      for (final p in children) {
        p.kill(ProcessSignal.sigkill);
        await p.exitCode;
      }
    }
  });
}
