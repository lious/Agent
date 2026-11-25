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
  test('insert mode is refused at the command; reject still collides', () {
    final p = f.three();
    final ids = media(p).map((c) => c['id'] as String).toList();
    expect(
      () => MoveClips(ids, Q.of(1), mode: 'insert'),
      code('INSERT_MODE_NOT_IMPLEMENTED'),
    );
    expect(
      () => MoveClips([ids.first], Q.of(1), mode: 'bogus'),
      code('UNSUPPORTED_EDIT_MODE'),
    );
    final payload = buildClipboard(p, [ids.first]);
    expect(
      () => PasteClips(payload, at: Q.of(0), mode: 'insert'),
      code('INSERT_MODE_NOT_IMPLEMENTED'),
    );
    expect(
      () => move.change(p, PasteClips(payload, at: Q.of(0))),
      code('COLLISION'),
    );
    expect(
      () => move.change(p, MoveClips([ids.first], Q.of(1))),
      code('COLLISION'),
    );
  });

  test('overwrite paste cuts intersecting items, remaps sources, keeps later clips and duration', () {
    final p = f.three();
    final a = media(p).first['id'] as String, b = 'b', c = 'c';
    final payload = buildClipboard(p, [a]);
    final out = move.change(
      p,
      PasteClips(payload, at: Q.of(1, 2), mode: 'overwrite'),
    );
    // A[0,1) -> front [0,0.5); new [0.5,1.5); B back [1.5,2); C[2,3) unchanged.
    expect(start(out, a), Q.of(0));
    expect(dur(out, a), Q.of(1, 2));
    expect(sourceStart(out, a), Q.of(0));
    expect(start(out, b), Q.of(3, 2));
    expect(dur(out, b), Q.of(1, 2));
    expect(sourceStart(out, b), Q.of(3, 2));
    expect(start(out, c), Q.of(2));
    expect(dur(out, c), Q.of(1));
    expect(sourceStart(out, c), Q.of(2));
    final copies = media(out)
        .where((x) => !{a, b, c}.contains(x['id']))
        .toList();
    expect(copies, hasLength(1));
    expect(Q.fromJson(copies.single['timelineRange']['start']), Q.of(1, 2));
    expect(Q.fromJson(copies.single['timelineRange']['duration']), Q.of(1));
    expect(copies.single['sourceRange'], clip(p, a)['sourceRange']);
    expect(seqDur(out), Q.of(3));
    expect(out.toJson()['assets'], p.toJson()['assets']);
  });

  test('gapped overwrite paste does not punch the interval between members', () {
    final p = f.three();
    final a = media(p).first['id'] as String, c = 'c';
    final payload = buildClipboard(p, [a, c]);
    // At 0 the package occupies [0,1) and [2,3); B sits wholly in the kept gap.
    final out = move.change(
      p,
      PasteClips(payload, at: Q.of(0), mode: 'overwrite'),
    );
    expect(start(out, 'b'), Q.of(1));
    expect(dur(out, 'b'), Q.of(1));
    expect(sourceStart(out, 'b'), Q.of(1));
    expect(clip(out, 'b')['sourceRange'], clip(p, 'b')['sourceRange']);
    expect(seqDur(out), Q.of(3));
    final copies =
        media(out).where((x) => !{a, 'b', c}.contains(x['id'])).toList()..sort(
          (x, y) => Q
              .fromJson(x['timelineRange']['start'])
              .compareTo(Q.fromJson(y['timelineRange']['start'])),
        );
    expect(copies, hasLength(2));
    expect(Q.fromJson(copies.first['timelineRange']['start']), Q.of(0));
    expect(Q.fromJson(copies.last['timelineRange']['start']), Q.of(2));
  });

  test('overwrite paste crops opacity curves and refuses locked neighbors as a group', () {
    var p = f.three();
    final a = media(p).first['id'] as String;
    p = move.change(p, SetOpacityKeyframe(a, Q.of(0), .25));
    p = move.change(p, SetOpacityKeyframe(a, Q.of(1), .75));
    final payload = buildClipboard(p, [a]);
    final out = move.change(
      p,
      PasteClips(payload, at: Q.of(1, 2), mode: 'overwrite'),
    );
    expect(out.toJson()['effects'], isNotEmpty);
    for (final e in out.toJson()['effects']) {
      if ((e['keyframes'] as List).isNotEmpty) {
        for (final k in e['keyframes']) {
          expect(Q.fromJson(k['localTime']) >= Q.of(0), true);
          expect(
            Q.fromJson(k['localTime']) <=
                Q.fromJson(
                  media(out).singleWhere(
                    (c) => (c['effectIds'] as List).contains(e['id']),
                  )['timelineRange']['duration'],
                ),
            true,
          );
        }
      }
    }
    final d = p.toJson();
    d['sequences'][0]['tracks'][0]['locked'] = true;
    final locked = ProjectDocument.fromJson(d);
    expect(
      () => move.change(
        locked,
        PasteClips(payload, at: Q.of(1, 2), mode: 'overwrite'),
      ),
      code('FIELD_LOCKED'),
    );
    expect(locked.hash, ProjectDocument.fromJson(d).hash);
  });

  test('overwrite paste deletes an affected dissolve and leaves an uninvolved later clip', () {
    var p = f.three();
    p = move.change(
      p,
      SetDissolve(media(p).first['id'] as String, 'b', Q.of(1, 5), Q.of(1, 5)),
    );
    expect(p.toJson()['transitions'], isNotEmpty);
    expect(
      () => buildClipboard(p, [media(p).first['id'] as String]),
      code('TRANSITION_COPY_REQUIRES_BOTH'),
    );
    final mid = buildClipboard(f.three(), [
      media(f.three()).first['id'] as String,
    ]);
    final out = move.change(
      p,
      PasteClips(mid, at: Q.of(1, 2), mode: 'overwrite'),
    );
    expect(out.toJson()['transitions'], isEmpty);
    expect(start(out, 'c'), Q.of(2));
    expect(seqDur(out), Q.of(3));
  });

  test('overwrite move carves the destination, vacates the source, and does not shorten duration', () {
    final p = f.three();
    final a = media(p).first['id'] as String;
    final out = move.change(p, MoveClips([a], Q.of(3, 2), mode: 'overwrite'));
    // A moves 0-1 -> 1.5-2.5; B[1,2) carved to [1,1.5); C[2,3) carved to [2.5,3).
    expect(start(out, a), Q.of(3, 2));
    expect(dur(out, a), Q.of(1));
    expect(sourceStart(out, a), Q.of(0));
    expect(start(out, 'b'), Q.of(1));
    expect(dur(out, 'b'), Q.of(1, 2));
    expect(start(out, 'c'), Q.of(5, 2));
    expect(dur(out, 'c'), Q.of(1, 2));
    expect(sourceStart(out, 'c'), Q.of(5, 2));
    expect(seqDur(out), Q.of(3));
    // vacated [0,1) is a gap, not a ripple close
    expect(
      media(out)
          .where((c) => Q.fromJson(c['timelineRange']['start']) == Q.of(0)),
      isEmpty,
    );
  });

  test('overwrite move of a dissolve pair keeps and shifts the cut', () {
    var p = f.three();
    final a = media(p).first['id'] as String;
    p = move.change(p, SetDissolve(a, 'b', Q.of(1, 5), Q.of(1, 5)));
    expect(p.toJson()['transitions'], isNotEmpty);
    final cut = Q.fromJson(p.toJson()['transitions'].single['cut']);
    final out = move.change(
      p,
      MoveClips([a, 'b'], Q.of(1, 2), mode: 'overwrite'),
    );
    expect(out.toJson()['transitions'], hasLength(1));
    expect(
      Q.fromJson(out.toJson()['transitions'].single['cut']),
      cut + Q.of(1, 2),
    );
    expect(start(out, a), Q.of(1, 2));
    expect(start(out, 'b'), Q.of(3, 2));
    expect(start(out, 'c'), Q.of(5, 2));
    expect(dur(out, 'c'), Q.of(1, 2));
    expect(seqDur(out), Q.of(3));
  });

  test('overwrite paste past the last clip extends duration and does not ripple earlier items', () {
    final p = f.three();
    final a = media(p).first['id'] as String;
    final payload = buildClipboard(p, [a]);
    final out = move.change(
      p,
      PasteClips(payload, at: Q.of(5, 2), mode: 'overwrite'),
    );
    expect(start(out, a), Q.of(0));
    expect(dur(out, a), Q.of(1));
    expect(start(out, 'b'), Q.of(1));
    expect(start(out, 'c'), Q.of(2));
    expect(dur(out, 'c'), Q.of(1, 2));
    expect(sourceStart(out, 'c'), Q.of(2));
    expect(seqDur(out), Q.of(7, 2));
    final copies = media(out).where((x) => !{a, 'b', 'c'}.contains(x['id']));
    expect(copies, hasLength(1));
    expect(Q.fromJson(copies.single['timelineRange']['start']), Q.of(5, 2));
  });
}
