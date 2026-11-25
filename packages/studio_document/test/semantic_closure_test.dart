import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:studio_document/studio_document.dart';

Map<String, dynamic> rich() =>
    jsonDecode(File('fixtures/project/semantic-rich.json').readAsStringSync())
        as Map<String, dynamic>;
void main() {
  test('full closed-root rich image/story/provenance/font/unknown-plugin project validates and roundtrips opaque references', () {
    final d = rich();
    expect(DocumentValidator().validate(d), isEmpty);
    expect(ProjectDocument.fromJson(d).toJson(), d);
  });
  final changes = <String, void Function(Map<String, dynamic>)>{
    'image parent missing': (d) =>
        d['imageDocuments'][0]['layers'][1]['parentId'] = 'missing',
    'image parent cycle': (d) =>
        d['imageDocuments'][0]['layers'][0]['parentId'] = 'child',
    'image source version': (d) =>
        d['imageDocuments'][0]['layers'][1]['sourceRef']['version'] = '999',
    'image font missing': (d) =>
        d['imageDocuments'][0]['fontRefs'] = ['missing'],
    'effect owner mismatch': (d) => d['effects'][0]['owner']['id'] = 'missing',
    'effect backlink missing': (d) =>
        d['sequences'][0]['tracks'][0]['items'][0]['effectIds'] = [],
    'character rights missing': (d) =>
        d['characters'][0]['rightsId'] = 'missing',
    'character appearance missing': (d) =>
        d['characters'][0]['appearanceRef']['id'] = 'missing',
    'script brief missing': (d) => d['scripts'][0]['briefId'] = 'missing',
    'script scene mismatch': (d) => d['scripts'][0]['sceneIds'] = ['missing'],
    'scene character missing': (d) =>
        d['scenes'][0]['characterIds'] = ['missing'],
    'scene shot missing': (d) => d['scenes'][0]['shotIds'] = ['missing'],
    'shot subject version': (d) =>
        d['shots'][0]['subjectRefs'][1]['version'] = '999',
    'shot continuity version': (d) =>
        d['shots'][0]['continuity']['characterRefs'][0]['version'] = '999',
    'generation output version': (d) =>
        d['generationRecords'][0]['outputAssetRefs'][0]['version'] = '999',
    'candidate missing': (d) =>
        d['sequences'][0]['tracks'][0]['items'][0]['candidateId'] = 'missing',
  };
  for (final entry in changes.entries) {
    test('semantic not structural: ${entry.key}', () {
      final d = rich();
      entry.value(d);
      final issues = DocumentValidator().validate(d);
      expect(issues, isNotEmpty);
      expect(issues.first.phase, 'semantic');
    });
  }
  test('exact piecewise endpoints/monotonicity and semantic arithmetic overflow are reported, not thrown', () {
    final d = rich(), c = d['sequences'][0]['tracks'][0]['items'][0];
    c['timeMap'] = {
      'kind': 'piecewise',
      'interpolation': 'linear',
      'knots': [
        {
          'u': {'n': '0', 'd': 1},
          'v': {'n': '0', 'd': 1},
        },
        {
          'u': {'n': '1', 'd': 1},
          'v': {'n': '1', 'd': 1},
        },
        {
          'u': {'n': '3', 'd': 1},
          'v': {'n': '3', 'd': 1},
        },
      ],
    };
    expect(DocumentValidator().validate(d), isEmpty);
    c['timeMap']['knots'][1]['v'] = {'n': '4', 'd': 1};
    expect(
      DocumentValidator().validate(d).any((e) => e.code == 'TIME_MAP_MISMATCH'),
      isTrue,
    );
    final huge = rich();
    huge['sequences'][0]['tracks'][0]['items'][0]['sourceRange']['start'] = {
      'n': '9223372036854775807',
      'd': 1,
    };
    expect(
      DocumentValidator().validate(huge).any((e) => e.phase == 'semantic'),
      isTrue,
    );
  });
  test('nested current sequence references depth8 accepted, depth9/cycle rejected without following retained-version graph as current', () {
    Map<String, dynamic> chain(int n) {
      final d = jsonDecode(
            File('fixtures/project/local-video.json').readAsStringSync(),
          ) as Map<String, dynamic>,
          base = d['sequences'][0];
      d['sequences'] = [
        for (var i = 0; i < n; i++) jsonDecode(jsonEncode(base)),
      ];
      for (var i = 0; i < n; i++) {
        final seq = d['sequences'][i];
        seq['id'] = 'seq-$i';
        seq['version'] = '1';
        seq['tracks'][0]['id'] = 'track-$i';
        seq['tracks'][0]['sequenceId'] = seq['id'];
        final c = seq['tracks'][0]['items'][0];
        c['id'] = 'clip-$i';
        c['trackId'] = 'track-$i';
        if (i + 1 < n) {
          c['source'] = {
            'kind': 'sequence',
            'id': 'seq-${i + 1}',
            'version': '1',
            'streamId': null,
          };
        }
      }
      d['rootSequenceId'] = 'seq-0';
      return d;
    }

    expect(DocumentValidator().validate(chain(8)), isEmpty);
    expect(
      DocumentValidator().validate(chain(9)).any((e) => e.code == 'NEST_DEPTH'),
      isTrue,
    );
    final cycle = chain(3);
    cycle['sequences'][2]['tracks'][0]['items'][0]['source'] = {
      'kind': 'sequence',
      'id': 'seq-0',
      'version': '1',
      'streamId': null,
    };
    expect(
      DocumentValidator()
          .validate(cycle)
          .any((e) => e.code == 'REFERENCE_CYCLE'),
      isTrue,
    );
  });
  test('opaque plugin/provider versions and rational lookalikes remain opaque, never project invariants', () {
    final d = rich();
    d['effects'][0]['parameters'] = {
      'id': 'outside',
      'version': '9999999999999999999999999',
      'q': {'n': '7', 'd': 0},
    };
    d['generationRecords'][0]['parameters'] = {
      'version': '9999999999999999999999999',
    };
    expect(DocumentValidator().validate(d), isEmpty);
    expect(ProjectDocument.fromJson(d).toJson(), d);
  });
  test('3000-node valid reciprocal bus graph validates without recursive host-stack exhaustion; closing its cycle refuses', () {
    final d = rich(), base = d['audioBuses'][0];
    d['audioBuses'] = [
      for (var i = 0; i < 3000; i++)
        <String, dynamic>{
          ...Map<String, dynamic>.from(base as Map),
          'id': 'bus-$i',
          'inputBusIds': [if (i > 0) 'bus-${i - 1}'],
          'outputBusId': i == 2999 ? null : 'bus-${i + 1}',
        },
    ];
    d['sequences'][0]['masterBusId'] = 'bus-2999';
    expect(DocumentValidator().validate(d), isEmpty);
    d['audioBuses'][2999]['outputBusId'] = 'bus-0';
    d['audioBuses'][0]['inputBusIds'] = ['bus-2999'];
    expect(
      DocumentValidator().validate(d).any((e) => e.code == 'REFERENCE_CYCLE'),
      isTrue,
    );
  });
}
