import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:studio_contracts/studio_contracts.dart';
import 'package:studio_document/studio_document.dart';

Map<String, dynamic> definitionFixture() =>
    jsonDecode(File('fixtures/project/local-video.json').readAsStringSync())
        as Map<String, dynamic>;
String sequenceHash(
  ProjectDocument p, [
  Map<String, Uint8List> bytes = const {},
]) {
  final s = p.toJson()['sequences'][0];
  return DefinitionFingerprinter(
    p,
    bytes,
  ).source('sequence', s['id'], s['version']);
}

void main() {
  test('definition identity excludes project title; canonical own data and actual unversioned bus dependencies change identity', () {
    final d = definitionFixture(),
        a = ProjectDocument.fromJson(d),
        h = sequenceHash(a);
    d['title'] = 'unrelated title';
    expect(sequenceHash(ProjectDocument.fromJson(d)), h);
    d['audioBuses'][0]['gainDb'] = -6;
    final b = ProjectDocument.fromJson(d);
    expect(sequenceHash(b), isNot(h));
    expect(
      () => verifyDefinitionTransition(a, b),
      throwsA(
        isA<StudioException>().having(
          (e) => e.code,
          'code',
          'IMMUTABLE_VERSION_CONFLICT',
        ),
      ),
    );
    d['sequences'][0]['version'] = '2';
    expect(
      () => verifyDefinitionTransition(a, ProjectDocument.fromJson(d)),
      returnsNormally,
    );
  });
  test(
    'master bus edit advances owning sequence once; duplicate is a true no-op',
    () {
      final before = ProjectDocument.empty(
        namespace: Namespace('studio', 'local', 'audio-version'),
        projectId: 'audio-version',
        title: 'Audio',
      );
      var allocations = 0;
      String next(String _) => (++allocations).toString();
      final after = applyEdit(
        before,
        const SetMasterAudio(gainDb: -6),
        nextVersion: next,
        newId: () => throw StateError('must not allocate entity'),
      );
      expect(allocations, 1);
      expect(after.toJson()['sequences'][0]['version'], '1');
      expect(() => verifyDefinitionTransition(before, after), returnsNormally);
      final duplicate = applyEdit(
        after,
        const SetMasterAudio(gainDb: -6),
        nextVersion: next,
        newId: () => throw StateError('must not allocate entity'),
      );
      expect(identical(after, duplicate), true);
      expect(allocations, 1);
    },
  );
  test('actual Dart PCM consumer changes with the dependency fingerprint; this is not pixel equivalence', () {
    final d = definitionFixture();
    MixedAudio consume() {
      final bus = AudioBus.fromJson(
        Map<String, dynamic>.from(d['audioBuses'][0]),
      );
      return mix48k(AudioBusGraph([bus], bus.id), [
        PcmInput(
          busId: bus.id,
          channels: 2,
          samples: Float32List.fromList(List.filled(128, 0.5)),
        ),
      ]);
    }

    final before = consume(), h = sequenceHash(ProjectDocument.fromJson(d));
    d['audioBuses'][0]['gainDb'] = -6;
    final quieter = consume();
    expect(quieter.peak / before.peak, closeTo(gainAmplitude(-6), 1e-6));
    expect(sequenceHash(ProjectDocument.fromJson(d)), isNot(h));
    d['audioBuses'][0]['pan'] = 1;
    final panned = consume();
    expect(panned.interleavedStereo[0], 0);
    expect(panned.interleavedStereo[1], greaterThan(0));
  });
  for (final ownerKind in ['sequence', 'track']) {
    test(
      'unqualified $ownerKind effect ordering is refused, never silently omitted',
      () {
        final d = definitionFixture();
        d['effects'] = [
          {
            'id': 'effect-opaque-order',
            'version': '1',
            'owner': {
              'kind': ownerKind,
              'id': ownerKind == 'sequence'
                  ? d['sequences'][0]['id']
                  : d['sequences'][0]['tracks'][0]['id'],
            },
            'type': 'opacity',
            'pluginVersion': '1.0.0',
            'enabled': true,
            'parameters': {'value': 0.5},
            'keyframes': [],
            'extensions': {},
          },
        ];
        final p = ProjectDocument.fromJson(d);
        expect(
          () => sequenceHash(p),
          throwsA(
            isA<StudioException>().having(
              (e) => e.code,
              'code',
              'DEFINITION_PROFILE_UNQUALIFIED',
            ),
          ),
        );
        expect(p.toJson()['effects'], d['effects']);
      },
    );
  }
  test('clip-owned core effect parameters are actual definition dependencies, not an execution certificate', () {
    final d = definitionFixture(),
        clip = definitionFixture()['sequences'][0]['tracks'][0]['items'][0];
    d['sequences'][0]['tracks'][0]['items'][0]['effectIds'] = ['opacity'];
    d['effects'] = [
      {
        'id': 'opacity',
        'version': '1',
        'owner': {'kind': 'clip', 'id': clip['id']},
        'type': 'opacity',
        'pluginVersion': '1.0.0',
        'enabled': true,
        'parameters': {'value': 0.5},
        'keyframes': [],
        'extensions': {},
      },
    ];
    final h = sequenceHash(ProjectDocument.fromJson(d));
    d['effects'][0]['parameters']['value'] = 0.25;
    expect(sequenceHash(ProjectDocument.fromJson(d)), isNot(h));
  });
  test('blob packaging locator is not a rendering dependency; source bytes/role are', () {
    final d = definitionFixture(),
        h = sequenceHash(ProjectDocument.fromJson(d));
    d['blobs'][0]['packagePath'] = 'originals/relocated';
    expect(sequenceHash(ProjectDocument.fromJson(d)), h);
  });
  test('source refs resolve the exact frozen version, not latest; unrelated title in snapshot does not change definition', () {
    final old = definitionFixture(),
        first = ProjectDocument.fromJson(old),
        d = definitionFixture();
    final raw = Uint8List.fromList(utf8.encode(first.canonicalJson)),
        hash = rawBytesHash(raw);
    d['assets'][0]['version'] = '2';
    d['sequences'][0]['version'] = '2';
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
      'bytes': raw.length.toString(),
      'mime': 'application/json',
      'role': 'snapshot',
      'packagePath': 'snapshots/definition.json',
    });
    final p = ProjectDocument.fromJson(d),
        f = DefinitionFingerprinter(p, {hash: raw});
    expect(
      f.source('asset', old['assets'][0]['id'], '1'),
      DefinitionFingerprinter(
        first,
        const {},
      ).source('asset', old['assets'][0]['id'], '1'),
    );
    old['title'] = 'metadata only';
    final changed = ProjectDocument.fromJson(old);
    expect(sequenceHash(first), sequenceHash(changed));
    expect(
      () => DefinitionFingerprinter(
        p,
        const {},
      ).source('asset', old['assets'][0]['id'], '1'),
      throwsA(
        isA<StudioException>().having(
          (e) => e.code,
          'code',
          'RESOURCE_BYTES_MISSING',
        ),
      ),
    );
    expect(
      () => f.source('asset', old['assets'][0]['id'], '99'),
      throwsA(
        isA<StudioException>().having(
          (e) => e.code,
          'code',
          'SOURCE_VERSION_MISSING',
        ),
      ),
    );
  });
  test('same kind/id/version with equal literal sequence but changed resolved bus is an immutable conflict across snapshots', () {
    final d = definitionFixture(),
        a = ProjectDocument.fromJson(d),
        seq = d['sequences'][0];
    d['audioBuses'][0]['gainDb'] = -9;
    final b = ProjectDocument.fromJson(d),
        f = DefinitionFingerprinter(a, const {});
    f.registerSnapshot(a);
    expect(
      () => f.sourceIn(b, 'sequence', seq['id'], seq['version']),
      throwsA(
        isA<StudioException>().having(
          (e) => e.code,
          'code',
          'IMMUTABLE_VERSION_CONFLICT',
        ),
      ),
    );
  });
  test('unknown LUT/library semantics never get a qualified fingerprint', () {
    final d = definitionFixture();
    d['extensions'] = {
      'vendor.library': {'hash': 'opaque'},
    };
    expect(
      () => sequenceHash(ProjectDocument.fromJson(d)),
      throwsA(
        isA<StudioException>().having(
          (e) => e.code,
          'code',
          'UNRESOLVED_EXTENSION_CLOSURE',
        ),
      ),
    );
  });
}
