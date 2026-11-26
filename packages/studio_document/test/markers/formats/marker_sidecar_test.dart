import 'dart:convert';

import 'package:studio_contracts/studio_contracts.dart';
import 'package:studio_document/studio_document.dart';
import 'package:test/test.dart';

import '../../multi_move_test.dart' as move;
import '../../persistent_audio_test.dart' show avFixture;

Matcher code(String c) =>
    throwsA(isA<StudioException>().having((e) => e.code, 'code', c));

List<Map> media(ProjectDocument p) => [
  for (final t in p.toJson()['sequences'][0]['tracks'])
    for (final c in t['items'])
      if (c['source'] != null) c as Map,
];

String videoId(ProjectDocument p) => media(p).first['id'] as String;

Q clipStart(ProjectDocument p, [String? id]) => Q.fromJson(
  media(
    p,
  ).singleWhere((c) => id == null || c['id'] == id)['timelineRange']['start'],
);

Q clipDuration(ProjectDocument p, [String? id]) => Q.fromJson(
  media(p).singleWhere(
    (c) => id == null || c['id'] == id,
  )['timelineRange']['duration'],
);

String sequenceId(ProjectDocument p) => p.toJson()['rootSequenceId'] as String;

ProjectDocument setMarkers(ProjectDocument p, List<TimelineMarker> markers) =>
    move.change(p, SetMarkers(MarkerStore(markers)));

TimelineMarker absoluteMarker(
  ProjectDocument p,
  String id, {
  required Q time,
  Q? duration,
  bool ripple = false,
  String label = 'mark',
  List<num> colorRGBA = const [1, 0.8, 0.2, 1],
}) => TimelineMarker(
  id,
  sequenceId: sequenceId(p),
  label: label,
  time: time,
  duration: duration,
  ripple: ripple,
  colorRGBA: colorRGBA,
);

Map officialOf(TimelineMarker m) => m.toJson();

Map decodedMarkers(String text) => jsonDecode(text) as Map;

void expectOfficialEqual(TimelineMarker a, TimelineMarker b) {
  expect(a.toJson(), b.toJson());
}

void main() {
  test('empty markers export and import round-trip', () {
    final p = avFixture();
    expect(p.toJson()['markers'], isEmpty);
    final text = MarkerSidecar.export(p.toJson());
    expect(text.contains('\uFEFF'), isFalse);
    final envelope = decodedMarkers(text);
    expect(envelope['format'], MarkerSidecar.formatName);
    expect(envelope['formatVersion'], MarkerSidecar.formatVersion);
    expect(envelope['markers'], isEmpty);
    final imported = MarkerSidecar.import(text, p.toJson());
    expect(imported.markers, isEmpty);
    final bytes = MarkerSidecar.exportBytes(p.toJson());
    expect(bytes.take(3).toList(), isNot([0xef, 0xbb, 0xbf]));
    expect(MarkerSidecar.import(bytes, p.toJson()).markers, isEmpty);
  });

  test(
    'absolute and clipLocal official fields round-trip and are not dropped',
    () {
      var p = avFixture();
      final host = videoId(p);
      final stay = absoluteMarker(
        p,
        'stay',
        time: Q.of(0),
        label: 'stay-label',
        ripple: false,
        colorRGBA: [0, 0.5, 1, 1],
      );
      final span = absoluteMarker(
        p,
        'span',
        time: Q.of(1, 2),
        duration: Q.of(1, 2),
        label: 'span-label',
        ripple: true,
        colorRGBA: [0.25, 0.5, 0.75, 1],
      );
      final follow = absoluteMarker(
        p,
        'follow',
        time: Q.of(1, 2),
        duration: Q.of(1, 4),
        label: 'follow-label',
      ).anchoredToClip(host, clipStart(p), clipDuration(p));
      p = setMarkers(p, [stay, span, follow]);
      expect(p.toJson()['markers'], hasLength(3));

      final text = MarkerSidecar.export(p.toJson());
      final envelope = decodedMarkers(text);
      expect(envelope['format'], 'studio.markers.sidecar');
      expect(envelope['formatVersion'], '1.0.0');
      expect((envelope['markers'] as List), hasLength(3));

      final imported = MarkerSidecar.import(text, p.toJson());
      expect(imported.markers, hasLength(3));
      expect(
        {for (final m in imported.markers) m.id},
        {'stay', 'span', 'follow'},
      );
      for (final original in [stay, span, follow]) {
        expectOfficialEqual(
          original,
          imported.markers.singleWhere((m) => m.id == original.id),
        );
      }

      final selected = MarkerSidecar.export(
        p.toJson(),
        ids: ['span', 'follow'],
      );
      final selectedStore = MarkerSidecar.import(selected, p.toJson());
      expect({for (final m in selectedStore.markers) m.id}, {'span', 'follow'});
      expect(
        () => MarkerSidecar.export(p.toJson(), ids: ['span', 'missing']),
        code('MARKER_SIDECAR_INVALID'),
      );
    },
  );

  test(
    'applying a full-file import restores official fields via SetMarkers',
    () {
      var p = avFixture();
      final host = videoId(p);
      p = setMarkers(p, [
        absoluteMarker(p, 'stay', time: Q.of(0), label: 'stay'),
        absoluteMarker(
          p,
          'follow',
          time: Q.of(1, 2),
        ).anchoredToClip(host, clipStart(p), clipDuration(p)),
      ]);
      final text = MarkerSidecar.export(p.toJson());
      var other = setMarkers(p, [
        absoluteMarker(p, 'other', time: Q.of(1), label: 'should-not-remain'),
      ]);
      other = setMarkers(
        other,
        MarkerSidecar.import(text, other.toJson()).markers,
      );
      expect(
        {for (final m in other.toJson()['markers']) m['id']},
        {'stay', 'follow'},
      );
      expect(other.toJson()['markers'][0]['label'], isNot('should-not-remain'));
      expect(
        other.toJson()['markers'].singleWhere(
          (m) => m['id'] == 'follow',
        )['anchor'],
        {'kind': 'clipLocal', 'clipId': host},
      );
    },
  );

  test(
    'missing required marker field or illegal value refuses the whole file',
    () {
      final p = avFixture();
      final valid = {
        'format': MarkerSidecar.formatName,
        'formatVersion': MarkerSidecar.formatVersion,
        'markers': [
          absoluteMarker(p, 'ok', time: Q.of(0)).toJson(),
          absoluteMarker(p, 'bad', time: Q.of(1, 2)).toJson(),
        ],
      };
      final missing = jsonDecode(jsonEncode(valid)) as Map<String, dynamic>;
      (missing['markers'][1] as Map).remove('label');
      expect(
        () => MarkerSidecar.import(jsonEncode(missing), p.toJson()),
        code('MARKER_INVALID'),
      );
      expect(
        MarkerSidecar.tryImport(jsonEncode(missing), p.toJson()).isOk,
        false,
      );

      final illegalLabel =
          jsonDecode(jsonEncode(valid)) as Map<String, dynamic>;
      (illegalLabel['markers'][1] as Map)['label'] = 'x' * 1025;
      expect(
        () => MarkerSidecar.import(jsonEncode(illegalLabel), p.toJson()),
        code('MARKER_INVALID'),
      );

      final nul = jsonDecode(jsonEncode(valid)) as Map<String, dynamic>;
      (nul['markers'][1] as Map)['label'] = 'a\u0000b';
      expect(
        () => MarkerSidecar.import(jsonEncode(nul), p.toJson()),
        code('MARKER_INVALID'),
      );

      final color = jsonDecode(jsonEncode(valid)) as Map<String, dynamic>;
      (color['markers'][1] as Map)['colorRGBA'] = [0, 0, 2, 1];
      expect(
        () => MarkerSidecar.import(jsonEncode(color), p.toJson()),
        code('MARKER_INVALID'),
      );

      final seconds = jsonDecode(jsonEncode(valid)) as Map<String, dynamic>;
      (seconds['markers'][1] as Map)['time'] = 1.5;
      expect(
        () => MarkerSidecar.import(jsonEncode(seconds), p.toJson()),
        code('TIME_ENCODING'),
      );
    },
  );

  test('duplicate id, wrong format, and unknown major version refuse the file', () {
    final p = avFixture();
    final marker = absoluteMarker(p, 'm1', time: Q.of(0)).toJson();
    expect(
      () => MarkerSidecar.import(
        jsonEncode({
          'format': MarkerSidecar.formatName,
          'formatVersion': MarkerSidecar.formatVersion,
          'markers': [marker, Map<String, Object?>.from(marker)],
        }),
        p.toJson(),
      ),
      code('DUPLICATE_ID'),
    );
    expect(
      () => MarkerSidecar.import(
        jsonEncode({
          'format': 'application/x-premiere-markers+csv',
          'formatVersion': MarkerSidecar.formatVersion,
          'markers': [marker],
        }),
        p.toJson(),
      ),
      code('MARKER_SIDECAR_INVALID'),
    );
    expect(
      () => MarkerSidecar.import(
        jsonEncode({
          'format': MarkerSidecar.formatName,
          'formatVersion': '2.0.0',
          'markers': [marker],
        }),
        p.toJson(),
      ),
      code('MARKER_SIDECAR_INVALID'),
    );
    expect(
      () => MarkerSidecar.import(
        jsonEncode({
          'format': MarkerSidecar.formatName,
          'formatVersion': 'not-a-version',
          'markers': [marker],
        }),
        p.toJson(),
      ),
      code('MARKER_SIDECAR_INVALID'),
    );
    // Same major, later minor is admitted when the official field set is used.
    final minor = MarkerSidecar.import(
      jsonEncode({
        'format': MarkerSidecar.formatName,
        'formatVersion': '1.1.0',
        'markers': [marker],
      }),
      p.toJson(),
    );
    expect(minor.markers, hasLength(1));
    expect(minor.markers.single.id, 'm1');

    final bom = <int>[
      0xef,
      0xbb,
      0xbf,
      ...utf8.encode(
        jsonEncode({
          'format': MarkerSidecar.formatName,
          'formatVersion': MarkerSidecar.formatVersion,
          'markers': <Object>[],
        }),
      ),
    ];
    expect(
      () => MarkerSidecar.import(bom, p.toJson()),
      code('MARKER_SIDECAR_INVALID'),
    );
  });

  test(
    'unknown extra fields warn MARKER_SIDECAR_UNSUPPORTED and refuse the file',
    () {
      final p = avFixture();
      final marker = absoluteMarker(p, 'm1', time: Q.of(0)).toJson();
      final text = jsonEncode({
        'format': MarkerSidecar.formatName,
        'formatVersion': MarkerSidecar.formatVersion,
        'chapterTitle': 'dropped-if-ignored',
        'markers': [
          {...marker, 'comment': 'not-official'},
        ],
      });
      final result = MarkerSidecar.tryImport(text, p.toJson());
      expect(result.isOk, isFalse);
      expect(result.code, 'MARKER_SIDECAR_UNSUPPORTED');
      expect(
        result.warnings,
        containsAll([
          'MARKER_SIDECAR_UNSUPPORTED:/chapterTitle',
          'MARKER_SIDECAR_UNSUPPORTED:/markers/0/comment',
        ]),
      );
      expect(() => result.requireOk, code('MARKER_SIDECAR_UNSUPPORTED'));
      expect(
        () => MarkerSidecar.import(text, p.toJson()),
        code('MARKER_SIDECAR_UNSUPPORTED'),
      );

      final anchorExtra = jsonEncode({
        'format': MarkerSidecar.formatName,
        'formatVersion': MarkerSidecar.formatVersion,
        'markers': [
          {
            ...marker,
            'anchor': {'kind': 'absolute', 'clipId': null, 'track': 1},
          },
        ],
      });
      final anchorResult = MarkerSidecar.tryImport(anchorExtra, p.toJson());
      expect(anchorResult.code, 'MARKER_SIDECAR_UNSUPPORTED');
      expect(
        anchorResult.warnings,
        contains('MARKER_SIDECAR_UNSUPPORTED:/markers/0/anchor/track'),
      );
    },
  );

  test(
    'unknown anchor kind is MARKER_ANCHOR_NOT_IMPLEMENTED, not stripped',
    () {
      final p = avFixture();
      final marker = absoluteMarker(p, 'm1', time: Q.of(0)).toJson();
      expect(
        () => MarkerSidecar.import(
          jsonEncode({
            'format': MarkerSidecar.formatName,
            'formatVersion': MarkerSidecar.formatVersion,
            'markers': [
              {
                ...marker,
                'anchor': {'kind': 'sourceLocal', 'clipId': null},
              },
            ],
          }),
          p.toJson(),
        ),
        code('MARKER_ANCHOR_NOT_IMPLEMENTED'),
      );
    },
  );

  test('missing sequenceId or uncovered clipLocal host refuses, never becomes absolute', () {
    final p = avFixture();
    final host = videoId(p);
    final follow = absoluteMarker(
      p,
      'follow',
      time: Q.of(1, 2),
    ).anchoredToClip(host, clipStart(p), clipDuration(p));

    expect(
      () => MarkerSidecar.import(
        jsonEncode({
          'format': MarkerSidecar.formatName,
          'formatVersion': MarkerSidecar.formatVersion,
          'markers': [
            {...follow.toJson(), 'sequenceId': 'sequence-missing'},
          ],
        }),
        p.toJson(),
      ),
      code('PARENT_MISMATCH'),
    );

    expect(
      () => MarkerSidecar.import(
        jsonEncode({
          'format': MarkerSidecar.formatName,
          'formatVersion': MarkerSidecar.formatVersion,
          'markers': [
            {
              ...follow.toJson(),
              'anchor': {'kind': 'clipLocal', 'clipId': 'clip-missing'},
            },
          ],
        }),
        p.toJson(),
      ),
      code('ANCHOR_OUT_OF_RANGE'),
    );

    // Time sits past the host; must not silently rewrite as absolute.
    final uncovered = TimelineMarker(
      'follow',
      sequenceId: sequenceId(p),
      label: 'follow-label',
      time: clipStart(p) + clipDuration(p) + Q.of(1),
      anchorKind: 'clipLocal',
      anchorClipId: host,
    );
    final rejected = MarkerSidecar.tryImport(
      jsonEncode({
        'format': MarkerSidecar.formatName,
        'formatVersion': MarkerSidecar.formatVersion,
        'markers': [uncovered.toJson()],
      }),
      p.toJson(),
    );
    expect(rejected.isOk, isFalse);
    expect(rejected.code, 'ANCHOR_OUT_OF_RANGE');
    expect(
      () => MarkerSidecar.import(
        jsonEncode({
          'format': MarkerSidecar.formatName,
          'formatVersion': MarkerSidecar.formatVersion,
          'markers': [uncovered.toJson()],
        }),
        p.toJson(),
      ),
      code('ANCHOR_OUT_OF_RANGE'),
    );
  });

  test(
    'absolute with a clipId or clipLocal without clipId is ANCHOR_INVALID',
    () {
      final p = avFixture();
      final marker = absoluteMarker(p, 'm1', time: Q.of(0)).toJson();
      expect(
        () => MarkerSidecar.import(
          jsonEncode({
            'format': MarkerSidecar.formatName,
            'formatVersion': MarkerSidecar.formatVersion,
            'markers': [
              {
                ...marker,
                'anchor': {'kind': 'absolute', 'clipId': videoId(p)},
              },
            ],
          }),
          p.toJson(),
        ),
        code('ANCHOR_INVALID'),
      );
      expect(
        () => MarkerSidecar.import(
          jsonEncode({
            'format': MarkerSidecar.formatName,
            'formatVersion': MarkerSidecar.formatVersion,
            'markers': [
              {
                ...marker,
                'anchor': {'kind': 'clipLocal', 'clipId': null},
              },
            ],
          }),
          p.toJson(),
        ),
        code('ANCHOR_INVALID'),
      );
    },
  );
}
