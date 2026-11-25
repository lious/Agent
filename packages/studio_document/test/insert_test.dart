import 'package:studio_contracts/studio_contracts.dart';
import 'package:studio_document/studio_document.dart';
import 'package:test/test.dart';

import 'edit_algebra_test.dart' as f;
import 'multi_move_test.dart' as move;

Matcher code(String c) =>
    throwsA(isA<StudioException>().having((e) => e.code, 'code', c));

List<Map> media(ProjectDocument p) => [
  for (final t in p.toJson()['sequences'][0]['tracks'])
    for (final c in t['items'])
      if (c['source'] != null) c as Map,
];

Map clip(ProjectDocument p, String id) =>
    media(p).singleWhere((c) => c['id'] == id);

Q start(ProjectDocument p, String id) =>
    Q.fromJson(clip(p, id)['timelineRange']['start']);

Q dur(ProjectDocument p, String id) =>
    Q.fromJson(clip(p, id)['timelineRange']['duration']);

Q sourceStart(ProjectDocument p, String id) =>
    Q.fromJson(clip(p, id)['sourceRange']['start']);

Q seqDur(ProjectDocument p) =>
    Q.fromJson(p.toJson()['sequences'][0]['duration']);

void main() {
  test('reject and overwrite stay distinct; insert is a third legal mode', () {
    final p = f.three();
    final ids = media(p).map((c) => c['id'] as String).toList();
    final payload = buildClipboard(p, [ids.first]);
    expect(
      () => move.change(p, PasteClips(payload, at: Q.of(0))),
      code('COLLISION'),
    );
    expect(
      () => move.change(p, MoveClips([ids.first], Q.of(1))),
      code('COLLISION'),
    );
    final over = move.change(
      p,
      PasteClips(payload, at: Q.of(1, 2), mode: 'overwrite'),
    );
    expect(seqDur(over), Q.of(3));
    expect(start(over, 'c'), Q.of(2));
    expect(
      () => MoveClips(
        [ids.first],
        Q.of(1),
        mode: 'overwrite',
        rippleTrackIds: [ids.first],
      ),
      code('RIPPLE_TRACKS_REQUIRE_INSERT'),
    );
  });

  test('insert paste at a cut shifts later clips by L and grows duration', () {
    final p = f.three();
    final a = media(p).first['id'] as String;
    final payload = buildClipboard(p, [a]);
    final out = move.change(
      p,
      PasteClips(payload, at: Q.of(1), mode: 'insert'),
    );
    expect(start(out, a), Q.of(0));
    expect(dur(out, a), Q.of(1));
    expect(start(out, 'b'), Q.of(2));
    expect(dur(out, 'b'), Q.of(1));
    expect(sourceStart(out, 'b'), Q.of(1));
    expect(start(out, 'c'), Q.of(3));
    expect(seqDur(out), Q.of(4));
    final copies = media(out).where((x) => !{a, 'b', 'c'}.contains(x['id']));
    expect(copies, hasLength(1));
    expect(Q.fromJson(copies.single['timelineRange']['start']), Q.of(1));
    expect(Q.fromJson(copies.single['timelineRange']['duration']), Q.of(1));
    expect(copies.single['sourceRange'], clip(p, a)['sourceRange']);
  });

  test('insert paste mid-clip splits, remaps sources, and does not overwrite the right remnant', () {
    final p = f.three();
    final a = media(p).first['id'] as String;
    final payload = buildClipboard(p, [a]);
    final out = move.change(
      p,
      PasteClips(payload, at: Q.of(1, 2), mode: 'insert'),
    );
    expect(start(out, a), Q.of(0));
    expect(dur(out, a), Q.of(1, 2));
    expect(sourceStart(out, a), Q.of(0));
    final rights = media(out)
        .where(
          (x) =>
              x['id'] != a &&
              x['id'] != 'b' &&
              x['id'] != 'c' &&
              Q.fromJson(x['timelineRange']['start']) == Q.of(3, 2),
        )
        .toList();
    // The remapped back of A starts at 0.5+1=1.5 after the inserted second.
    expect(start(out, 'b'), Q.of(2));
    expect(start(out, 'c'), Q.of(3));
    expect(seqDur(out), Q.of(4));
    final inserted = media(out).singleWhere(
      (x) =>
          Q.fromJson(x['timelineRange']['start']) == Q.of(1, 2) && x['id'] != a,
    );
    expect(Q.fromJson(inserted['timelineRange']['duration']), Q.of(1));
    expect(inserted['sourceRange'], clip(p, a)['sourceRange']);
    final remnant = media(out)
        .singleWhere((x) => !{a, 'b', 'c', inserted['id']}.contains(x['id']));
    expect(Q.fromJson(remnant['timelineRange']['start']), Q.of(3, 2));
    expect(Q.fromJson(remnant['timelineRange']['duration']), Q.of(1, 2));
    expect(Q.fromJson(remnant['sourceRange']['start']), Q.of(1, 2));
    expect(rights, hasLength(1));
  });

  test(
    'gapped insert paste opens the package span, not per-member holes only',
    () {
      final p = f.three();
      final a = media(p).first['id'] as String, c = 'c';
      final payload = buildClipboard(p, [a, c]);
      final out = move.change(
        p,
        PasteClips(payload, at: Q.of(1), mode: 'insert'),
      );
      // Package span is 3s (A+gap+C). B at 1 shifts to 4; original A,C stay.
      expect(start(out, a), Q.of(0));
      expect(start(out, 'b'), Q.of(4));
      expect(dur(out, 'b'), Q.of(1));
      expect(sourceStart(out, 'b'), Q.of(1));
      expect(start(out, c), Q.of(5));
      expect(seqDur(out), Q.of(6));
      final copies =
          media(out).where((x) => !{a, 'b', c}.contains(x['id'])).toList()
            ..sort(
              (x, y) => Q
                  .fromJson(x['timelineRange']['start'])
                  .compareTo(Q.fromJson(y['timelineRange']['start'])),
            );
      expect(copies, hasLength(2));
      expect(Q.fromJson(copies.first['timelineRange']['start']), Q.of(1));
      expect(Q.fromJson(copies.last['timelineRange']['start']), Q.of(3));
    },
  );

  test(
    'insert paste crops opacity on the split and refuses locked tracks wholly',
    () {
      var p = f.three();
      final a = media(p).first['id'] as String;
      p = move.change(p, SetOpacityKeyframe(a, Q.of(0), .25));
      p = move.change(p, SetOpacityKeyframe(a, Q.of(1), .75));
      final payload = buildClipboard(p, [a]);
      final out = move.change(
        p,
        PasteClips(payload, at: Q.of(1, 2), mode: 'insert'),
      );
      expect(out.toJson()['effects'], isNotEmpty);
      for (final e in out.toJson()['effects']) {
        if ((e['keyframes'] as List).isNotEmpty) {
          for (final k in e['keyframes']) {
            expect(Q.fromJson(k['localTime']) >= Q.of(0), true);
          }
        }
      }
      final d = p.toJson();
      d['sequences'][0]['tracks'][0]['locked'] = true;
      final locked = ProjectDocument.fromJson(d);
      expect(
        () => move.change(
          locked,
          PasteClips(payload, at: Q.of(1, 2), mode: 'insert'),
        ),
        code('FIELD_LOCKED'),
      );
      expect(locked.hash, ProjectDocument.fromJson(d).hash);
    },
  );

  test('insert paste at a dissolve cut deletes the transition and shifts the later clip', () {
    var p = f.three();
    p = move.change(
      p,
      SetDissolve(media(p).first['id'] as String, 'b', Q.of(1, 5), Q.of(1, 5)),
    );
    expect(p.toJson()['transitions'], isNotEmpty);
    final mid = buildClipboard(f.three(), [
      media(f.three()).first['id'] as String,
    ]);
    final out = move.change(p, PasteClips(mid, at: Q.of(1), mode: 'insert'));
    expect(out.toJson()['transitions'], isEmpty);
    expect(start(out, 'b'), Q.of(2));
    expect(start(out, 'c'), Q.of(3));
    expect(seqDur(out), Q.of(4));
  });

  test(
    'insert paste mid-clip remaps a later dissolve onto the right remnant',
    () {
      var p = f.three();
      p = move.change(
        p,
        SetDissolve(
          media(p).first['id'] as String,
          'b',
          Q.of(1, 5),
          Q.of(1, 5),
        ),
      );
      final mid = buildClipboard(f.three(), [
        media(f.three()).first['id'] as String,
      ]);
      final out = move.change(
        p,
        PasteClips(mid, at: Q.of(1, 2), mode: 'insert'),
      );
      expect(out.toJson()['transitions'], hasLength(1));
      final t = out.toJson()['transitions'].single;
      expect(Q.fromJson(t['cut']), Q.of(2));
      expect(start(out, 'b'), Q.of(2));
      expect(t['leftClipId'], isNot(media(p).first['id']));
      expect(t['rightClipId'], 'b');
      expect(seqDur(out), Q.of(4));
    },
  );

  test('insert move opens dest, vacates source as a gap, and grows duration', () {
    final p = f.three();
    final a = media(p).first['id'] as String;
    final out = move.change(p, MoveClips([a], Q.of(3, 2), mode: 'insert'));
    // A 0-1 moves to 1.5-2.5; B[1,2) splits at 1.5; right of B and C shift +1.
    expect(start(out, a), Q.of(3, 2));
    expect(dur(out, a), Q.of(1));
    expect(sourceStart(out, a), Q.of(0));
    expect(start(out, 'b'), Q.of(1));
    expect(dur(out, 'b'), Q.of(1, 2));
    final remnant = media(out)
        .singleWhere((x) => !{a, 'b', 'c'}.contains(x['id']));
    expect(Q.fromJson(remnant['timelineRange']['start']), Q.of(5, 2));
    expect(Q.fromJson(remnant['timelineRange']['duration']), Q.of(1, 2));
    expect(start(out, 'c'), Q.of(3));
    expect(seqDur(out), Q.of(4));
    expect(
      media(out)
          .where((c) => Q.fromJson(c['timelineRange']['start']) == Q.of(0)),
      isEmpty,
    );
  });

  test('insert move of a dissolve pair keeps and shifts the cut; source stays a gap', () {
    var p = f.three();
    final a = media(p).first['id'] as String;
    p = move.change(p, SetDissolve(a, 'b', Q.of(1, 5), Q.of(1, 5)));
    final cut = Q.fromJson(p.toJson()['transitions'].single['cut']);
    final out = move.change(p, MoveClips([a, 'b'], Q.of(1), mode: 'insert'));
    expect(out.toJson()['transitions'], hasLength(1));
    expect(
      Q.fromJson(out.toJson()['transitions'].single['cut']),
      cut + Q.of(1),
    );
    expect(start(out, a), Q.of(1));
    expect(start(out, 'b'), Q.of(2));
    expect(start(out, 'c'), Q.of(4));
    expect(seqDur(out), Q.of(5));
  });

  test(
    'insert paste past the end grows duration and does not move earlier items',
    () {
      final p = f.three();
      final a = media(p).first['id'] as String;
      final payload = buildClipboard(p, [a]);
      final out = move.change(
        p,
        PasteClips(payload, at: Q.of(3), mode: 'insert'),
      );
      expect(start(out, a), Q.of(0));
      expect(start(out, 'b'), Q.of(1));
      expect(start(out, 'c'), Q.of(2));
      expect(seqDur(out), Q.of(4));
      final copies = media(out).where((x) => !{a, 'b', 'c'}.contains(x['id']));
      expect(copies, hasLength(1));
      expect(Q.fromJson(copies.single['timelineRange']['start']), Q.of(3));
    },
  );
}
