import 'package:studio_contracts/studio_contracts.dart';
import 'package:studio_document/studio_document.dart';
import 'package:test/test.dart';

import 'multi_move_test.dart' as move;
import 'persistent_audio_test.dart' show avFixture;
import 'edit_algebra_test.dart' as f;

Matcher code(String c) =>
    throwsA(isA<StudioException>().having((e) => e.code, 'code', c));

List<Map> media(ProjectDocument p) => [
  for (final t in p.toJson()['sequences'][0]['tracks'])
    for (final c in t['items'])
      if (c['source'] != null) c as Map,
];

String videoId(ProjectDocument p) => media(p).first['id'] as String;

Q startOf(ProjectDocument p, [String? id]) => Q.fromJson(
  media(
    p,
  ).singleWhere((c) => id == null || c['id'] == id)['timelineRange']['start'],
);

List<Map> markersOf(ProjectDocument p) =>
    (p.toJson()['markers'] as List).cast<Map>();

Map markerOf(ProjectDocument p, String id) =>
    markersOf(p).singleWhere((m) => m['id'] == id);

Q markerTime(ProjectDocument p, String id) =>
    Q.fromJson(markerOf(p, id)['time']);

TimelineMarker absolute(
  ProjectDocument p,
  String id, {
  required Q time,
  Q? duration,
  bool ripple = false,
  String label = 'mark',
}) => TimelineMarker(
  id,
  sequenceId: p.toJson()['rootSequenceId'] as String,
  label: label,
  time: time,
  duration: duration,
  ripple: ripple,
);

ProjectDocument setMarkers(ProjectDocument p, List<TimelineMarker> markers) =>
    move.change(p, SetMarkers(MarkerStore(markers)));

void main() {
  test('SetMarkers writes absolute markers and is a no-op when unchanged', () {
    final p = avFixture();
    final added = setMarkers(p, [absolute(p, 'm1', time: Q.of(1, 2))]);
    expect(markersOf(added), hasLength(1));
    expect(markerTime(added, 'm1'), Q.of(1, 2));
    expect(added.toJson()['sequences'][0]['markerIds'], ['m1']);
    expect(markerOf(added, 'm1')['anchor']['kind'], 'absolute');
    expect(markerOf(added, 'm1')['ripple'], false);
    final again = setMarkers(added, [
      TimelineMarker.fromJson(Map<String, dynamic>.from(markerOf(added, 'm1'))),
    ]);
    expect(identical(again, added) || again.hash == added.hash, true);
  });

  test('clipLocal marker follows a reject move; absolute sibling stays', () {
    var p = avFixture();
    final video = videoId(p);
    p = setMarkers(p, [
      absolute(p, 'follow', time: Q.of(1, 2)).anchoredToClip(
        video,
        Q.of(0),
        Q.fromJson(media(p).first['timelineRange']['duration']),
      ),
      absolute(p, 'stay', time: Q.of(2), label: 'stay'),
    ]);
    final out = move.change(p, MoveClips([video], Q.of(1, 2)));
    expect(startOf(out, video), Q.of(1, 2));
    expect(markerTime(out, 'follow'), Q.of(1));
    expect(markerOf(out, 'follow')['anchor']['clipId'], video);
    expect(markerTime(out, 'stay'), Q.of(2));
    expect(markerOf(out, 'stay')['anchor']['kind'], 'absolute');
  });

  test('ripple close drops a marker inside the hole; ripple=false later stays; ripple=true later shifts', () {
    var p = avFixture();
    p = setMarkers(p, [
      absolute(p, 'before', time: Q.of(1, 2)),
      absolute(p, 'inside', time: Q.of(5, 4), label: 'gone'),
      absolute(p, 'later-hold', time: Q.of(5, 2), ripple: false),
      absolute(p, 'later-shift', time: Q.of(2), ripple: true),
      absolute(p, 'span', time: Q.of(1, 2), duration: Q.of(2), ripple: true),
    ]);
    final out = move.change(
      p,
      RippleDeleteClips(const [], range: TimeRange(Q.of(1), Q.of(1))),
    );
    final ids = {for (final m in markersOf(out)) m['id']};
    expect(ids.contains('inside'), false);
    expect(markerTime(out, 'before'), Q.of(1, 2));
    expect(markerTime(out, 'later-hold'), Q.of(5, 2));
    expect(markerTime(out, 'later-shift'), Q.of(1));
    expect(markerTime(out, 'span'), Q.of(1, 2));
    expect(Q.fromJson(markerOf(out, 'span')['duration']), Q.of(1, 2));
    final right = markersOf(out).singleWhere(
      (m) =>
          m['id'] != 'span' &&
          Q.fromJson(m['duration']) == Q.of(1, 2) &&
          Q.fromJson(m['time']) == Q.of(1),
    );
    expect(right['label'], 'mark');
    expect(right['ripple'], true);
  });

  test('insert-move leaves a source gap and does not split a following clipLocal marker at the destination', () {
    var p = avFixture();
    final video = videoId(p);
    p = setMarkers(p, [
      absolute(p, 'follow', time: Q.of(1, 2)).anchoredToClip(
        video,
        Q.of(0),
        Q.fromJson(media(p).first['timelineRange']['duration']),
      ),
      absolute(
        p,
        'later',
        time: Q.of(0),
        ripple: true,
      ), // at 0 moves with hole? at=1
      absolute(p, 'hold', time: Q.of(2), ripple: false),
    ]);
    // later at 0 is before dest hole at 1, stays. Add one at 2 with ripple true.
    p = setMarkers(p, [
      TimelineMarker.fromJson(Map<String, dynamic>.from(markerOf(p, 'follow'))),
      absolute(p, 'shifted', time: Q.of(2), ripple: true),
      absolute(p, 'hold', time: Q.of(5, 2), ripple: false),
    ]);
    final out = move.change(p, MoveClips([video], Q.of(1), mode: 'insert'));
    expect(startOf(out, video), Q.of(1));
    // Source is vacated as a gap, not closed.
    final outItems = [
      for (final t in out.toJson()['sequences'][0]['tracks'])
        for (final c in t['items']) c as Map,
    ];
    expect(
      outItems.any(
        (c) =>
            c['source'] == null &&
            Q.fromJson(c['timelineRange']['start']) == Q.of(0),
      ),
      true,
    );
    expect(
      markersOf(out).map((m) => m['id']),
      unorderedEquals(['follow', 'shifted', 'hold']),
    );
    expect(markerTime(out, 'follow'), Q.of(3, 2));
    expect(markerOf(out, 'follow')['anchor']['kind'], 'clipLocal');
    expect(markerTime(out, 'shifted'), Q.of(5));
    expect(markerTime(out, 'hold'), Q.of(5, 2));
  });

  test('unsupported marker anchor kinds refuse; lifting a clipLocal host is atomic', () {
    final p = avFixture();
    expect(
      () => TimelineMarker(
        'bad',
        sequenceId: p.toJson()['rootSequenceId'] as String,
        label: 'x',
        time: Q.of(0),
        anchorKind: 'source',
        anchorClipId: videoId(p),
      ),
      code('MARKER_ANCHOR_NOT_IMPLEMENTED'),
    );
    var marked = setMarkers(p, [
      absolute(p, 'follow', time: Q.of(1, 2)).anchoredToClip(
        videoId(p),
        Q.of(0),
        Q.fromJson(media(p).first['timelineRange']['duration']),
      ),
    ]);
    expect(
      () => move.change(marked, LiftClips([videoId(p)])),
      code('REF_NOT_FOUND'),
    );
    expect(markersOf(marked), hasLength(1));
    expect(startOf(marked), Q.of(0));
  });

  test(
    'planMoveSnap uses admitted markers as targets and does not strip them',
    () {
      final d = f.three().toJson(), s = d['sequences'][0];
      s['markerIds'] = ['marker'];
      d['markers'] = [
        {
          'id': 'marker',
          'sequenceId': s['id'],
          'label': 'retained',
          'colorRGBA': [1, 0, 0, 1],
          'anchor': {'kind': 'absolute', 'clipId': null},
          'time': Q.of(3, 2).toJson(),
          'duration': Q.of(0).toJson(),
          'ripple': false,
        },
      ];
      final p = ProjectDocument.fromJson(d),
          id = f.items(p).first['id'] as String;
      final plan = planMoveSnap(
        p,
        clipIds: [id],
        viewport: TimelineViewport(origin: Q.of(0), pixelsPerSecond: Q.of(100)),
        pointerPixel: Q.of(146),
        playhead: Q.of(0),
      );
      expect(plan.decision.target!.kind, SnapKind.marker);
      expect(plan.decision.target!.id, 'marker');
      expect(plan.decision.target!.time, Q.of(3, 2));
      expect(p.toJson()['markers'], d['markers']);
    },
  );
}
