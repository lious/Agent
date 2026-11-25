import 'dart:io';

import 'package:studio_contracts/studio_contracts.dart';
import 'package:studio_document/studio_document.dart';
import 'package:test/test.dart';

ProjectDocument fixture() => ProjectDocument.empty(
  namespace: Namespace('studio', 'local', 'ws'),
  projectId: 'p1',
  title: 'Example',
);
void main() {
  test('complete 2.0 empty project roundtrip is immutable', () {
    final p = fixture();
    final json = p.toJson();
    expect(ProjectDocument.fromJson(json).hash, p.hash);
    json['title'] = 'mutated';
    expect(p.title, 'Example');
    expect(DocumentValidator().validate(p.toJson()), isEmpty);
    var root = Directory.current;
    while (!File('${root.path}/schemas/project.schema.json').existsSync() &&
        root.parent.path != root.path) {
      root = root.parent;
    }
    expect(
      File('${root.path}/fixtures/project/empty-2.0.0.json')
          .readAsStringSync()
          .trim(),
      p.canonicalJson,
    );
    p.requireFoundationWritable();
  });
  test('structural errors are distinct from semantic errors', () {
    final missing = fixture().toJson()..remove('assets');
    expect(DocumentValidator().validate(missing).first.phase, 'structural');
    final fk = fixture().toJson()..['rootSequenceId'] = 'missing';
    expect(DocumentValidator().validate(fk).single.code, 'REF_NOT_FOUND');
    expect(DocumentValidator().validate(fk).single.phase, 'semantic');
  });
  test('closed root, unknown version and invalid namespace rejected', () {
    for (final j in [
      fixture().toJson()..['unknown'] = true,
      fixture().toJson()..['schemaVersion'] = '3.0.0',
      fixture().toJson()
        ..['namespace'] = {
          'appId': '../x',
          'tenantId': 't',
          'workspaceId': 'w',
        },
    ]) {
      expect(
        () => ProjectDocument.fromJson(j),
        throwsA(isA<StudioException>()),
      );
    }
  });
  test('ID duplicates, time encoding and numeric overflow rejected', () {
    final j = fixture().toJson();
    j['sequences'][0]['id'] = 'p1';
    expect(
      DocumentValidator().validate(j).map((x) => x.code),
      contains('DUPLICATE_ID'),
    );
    final t = fixture().toJson();
    t['sequences'][0]['duration'] = {'n': '0', 'd': 2};
    expect(
      DocumentValidator().validate(t).map((x) => x.code),
      contains('TIME_NON_CANONICAL'),
    );
    final rev = fixture().toJson()..['revision'] = '9223372036854775808';
    expect(
      DocumentValidator().validate(rev).map((x) => x.code),
      contains('TIME_OVERFLOW'),
    );
  });
  test('bus references and cycles rejected', () {
    final j = fixture().toJson();
    j['audioBuses'][0]['outputBusId'] = 'bus-master';
    expect(
      DocumentValidator().validate(j).map((x) => x.code),
      contains('REFERENCE_CYCLE'),
    );
    final missing = fixture().toJson();
    missing['sequences'][0]['masterBusId'] = 'missing';
    expect(
      DocumentValidator().validate(missing).map((x) => x.code),
      contains('REF_NOT_FOUND'),
    );
  });
  test('half-open gap intervals and duration validate, overlap rejects', () {
    final j = fixture().toJson();
    Map<String, Object> gap(String id, int start, int duration) => {
      'id': id,
      'trackId': 'v1',
      'timelineRange': {
        'start': Q.of(start).toJson(),
        'duration': Q.of(duration).toJson(),
      },
    };
    j['sequences'][0]['duration'] = Q.of(2).toJson();
    j['sequences'][0]['frameRate'] = {'n': 30, 'd': 1};
    j['sequences'][0]['tracks'] = [
      {
        'id': 'v1',
        'sequenceId': 'sequence-main',
        'name': 'V1',
        'kind': 'video',
        'order': 0,
        'locked': false,
        'muted': false,
        'solo': false,
        'syncLock': true,
        'targeted': true,
        'busId': null,
        'items': [gap('g1', 0, 1), gap('g2', 1, 1)],
      },
    ];
    expect(DocumentValidator().validate(j), isEmpty);
    expect(
      () => ProjectDocument.fromJson(j).requireFoundationWritable(),
      throwsA(isA<StudioException>()),
    );
    j['sequences'][0]['tracks'][0]['items'][1] = gap('g2', 0, 2);
    expect(
      DocumentValidator().validate(j).map((x) => x.code),
      contains('COLLISION'),
    );
  });
  test('JCS number vectors, UTF16 order and exact I64 string', () {
    expect(contentHash({'a': 1, 'b': 2}), contentHash({'b': 2, 'a': 1}));
    expect(
      contentHash([-0.0, 1e30, 0.000001]),
      contentHash([0, 1e30, 0.000001]),
    );
    expect(Q.fromJson({'n': '9223372036854775807', 'd': 1}).n, maxI64);
  });
  test('validator rejects cyclic/nonJSON input without recursing forever', () {
    final j = fixture().toJson();
    j['extensions']['cycle'] = j;
    expect(DocumentValidator().validate(j).first.code, 'DOCUMENT_LIMIT');
    final bad = fixture().toJson();
    bad['extensions']['bad'] = double.nan;
    expect(DocumentValidator().validate(bad).first.code, 'INVALID_JSON');
  });
  test(
    'unknown extensions roundtrip unchanged and are not interpreted as time',
    () {
      final j = fixture().toJson();
      j['extensions']['vendor.test'] = {'n': 'not-a-time', 'd': 0};
      final doc = ProjectDocument.fromJson(j);
      expect(doc.toJson()['extensions'], j['extensions']);
      expect(
        () => doc.requireFoundationWritable(),
        throwsA(isA<StudioException>()),
      );
    },
  );
}
