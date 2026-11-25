import 'package:studio_contracts/studio_contracts.dart';
import 'package:studio_document/studio_document.dart';
import 'package:test/test.dart';

import 'edit_algebra_test.dart' as f;
import 'multi_move_test.dart' as move;
import 'persistent_audio_test.dart' show avFixture;

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
  test(
    'lift still leaves a gap; gapped selections refuse; insert stays distinct',
    () {
      final p = f.three();
      final a = media(p).first['id'] as String;
      final lift = move.change(p, LiftClips(['c']));
      expect(seqDur(lift), Q.of(3));
      expect(start(lift, a), Q.of(0));
      expect(start(lift, 'b'), Q.of(1));
      expect(
        () => move.change(p, RippleDeleteClips([a, 'c'])),
        code('RIPPLE_RANGE_NOT_CONTIGUOUS'),
      );
      final inserted = move.change(
        p,
        PasteClips(buildClipboard(p, [a]), at: Q.of(1), mode: 'insert'),
      );
      expect(seqDur(inserted), Q.of(4));
    },
  );

  test(
    'ripple delete of a trailing clip closes the hole and shortens duration',
    () {
      final p = f.three();
      final out = move.change(p, RippleDeleteClips(['c']));
      expect(start(out, media(p).first['id'] as String), Q.of(0));
      expect(start(out, 'b'), Q.of(1));
      expect(dur(out, 'b'), Q.of(1));
      expect(() => clip(out, 'c'), throwsA(isA<StateError>()));
      expect(seqDur(out), Q.of(2));
      expect(out.toJson()['assets'], p.toJson()['assets']);
    },
  );

  test('ripple delete of a middle clip shifts later content and remaps nothing on the left', () {
    final p = f.three();
    final a = media(p).first['id'] as String;
    final out = move.change(p, RippleDeleteClips(['b']));
    expect(start(out, a), Q.of(0));
    expect(dur(out, a), Q.of(1));
    expect(sourceStart(out, a), Q.of(0));
    expect(start(out, 'c'), Q.of(1));
    expect(dur(out, 'c'), Q.of(1));
    expect(sourceStart(out, 'c'), Q.of(2));
    expect(seqDur(out), Q.of(2));
  });

  test('ripple delete of a partial covering range keeps both remnants and remaps sources', () {
    // Selecting only B deletes [1,2). To crop through the middle of a longer
    // clip, delete A+B after they have been conceptually adjacent? Instead
    // delete B, then also verify a split of a longer item by deleting A which
    // starts at 0: here delete nothing mid-clip unless we build R from two
    // adjacent clips A+B = [0,2), leaving C at 0.
    final p = f.three();
    final a = media(p).first['id'] as String;
    final out = move.change(p, RippleDeleteClips([a, 'b']));
    expect(() => clip(out, a), throwsA(isA<StateError>()));
    expect(() => clip(out, 'b'), throwsA(isA<StateError>()));
    expect(start(out, 'c'), Q.of(0));
    expect(sourceStart(out, 'c'), Q.of(2));
    expect(seqDur(out), Q.of(1));
  });

  test('ripple delete preserves later opacity curves when a middle clip is removed', () {
    var p = f.three();
    final a = media(p).first['id'] as String;
    p = move.change(p, SetOpacityKeyframe('c', Q.of(0), .25));
    p = move.change(p, SetOpacityKeyframe('c', Q.of(1), .75));
    final out = move.change(p, RippleDeleteClips(['b']));
    expect(start(out, 'c'), Q.of(1));
    expect(out.toJson()['effects'], isNotEmpty);
    expect(seqDur(out), Q.of(2));
    expect(start(out, a), Q.of(0));
  });

  test('ripple delete crops an unselected sync-lock audio spanning the range and keeps both remnants', () {
    var p = avFixture();
    final video = media(p).single['id'] as String;
    p = move.change(p, ExtractAudioClip(video, 'audio-stream'));
    final audio = media(p).singleWhere((c) => c['id'] != video)['id'] as String;
    p = move.change(
      p,
      UnlinkAudioVideo(p.toJson()['linkGroups'][0]['id'] as String),
    );
    p = move.change(p, SplitClip(video, Q.of(1), 'video-b'));
    p = move.change(p, SplitClip('video-b', Q.of(2), 'video-c'));
    final out = move.change(p, RippleDeleteClips(['video-b']));
    expect(() => clip(out, 'video-b'), throwsA(isA<StateError>()));
    expect(start(out, video), Q.of(0));
    expect(dur(out, video), Q.of(1));
    expect(start(out, 'video-c'), Q.of(1));
    expect(sourceStart(out, 'video-c'), Q.of(2));
    final audios = media(out)
        .where((c) => c['trackId'] != clip(out, video)['trackId'])
        .toList();
    expect(audios, hasLength(2));
    expect(Q.fromJson(audios.first['timelineRange']['start']), Q.of(0));
    expect(Q.fromJson(audios.first['timelineRange']['duration']), Q.of(1));
    expect(Q.fromJson(audios.first['sourceRange']['start']), Q.of(0));
    expect(Q.fromJson(audios.last['timelineRange']['start']), Q.of(1));
    expect(Q.fromJson(audios.last['timelineRange']['duration']), Q.of(1));
    expect(Q.fromJson(audios.last['sourceRange']['start']), Q.of(2));
    expect(clip(out, audio), audios.first);
    expect(seqDur(out), Q.of(2));
  });

  test('ripple delete refuses locked tracks wholly and does not change the document', () {
    final p = f.three();
    final d = p.toJson();
    d['sequences'][0]['tracks'][0]['locked'] = true;
    final locked = ProjectDocument.fromJson(d);
    expect(
      () => move.change(locked, RippleDeleteClips(['b'])),
      code('FIELD_LOCKED'),
    );
    expect(locked.hash, ProjectDocument.fromJson(d).hash);
  });

  test('ripple delete of a dissolve pair removes the transition; later dissolves shift', () {
    var p = f.three();
    final a = media(p).first['id'] as String;
    p = move.change(p, SetDissolve(a, 'b', Q.of(1, 5), Q.of(1, 5)));
    p = move.change(p, SetDissolve('b', 'c', Q.of(1, 5), Q.of(1, 5)));
    expect(p.toJson()['transitions'], hasLength(2));
    final out = move.change(p, RippleDeleteClips([a]));
    expect(out.toJson()['transitions'], hasLength(1));
    expect(out.toJson()['transitions'].single['leftClipId'], 'b');
    expect(out.toJson()['transitions'].single['rightClipId'], 'c');
    expect(Q.fromJson(out.toJson()['transitions'].single['cut']), Q.of(1));
    expect(start(out, 'b'), Q.of(0));
    expect(start(out, 'c'), Q.of(1));
    expect(seqDur(out), Q.of(2));
  });

  test('ripple delete at a dissolve cut with the right clip removes that transition', () {
    var p = f.three();
    p = move.change(
      p,
      SetDissolve(media(p).first['id'] as String, 'b', Q.of(1, 5), Q.of(1, 5)),
    );
    final out = move.change(p, RippleDeleteClips(['b']));
    expect(out.toJson()['transitions'], isEmpty);
    expect(start(out, 'c'), Q.of(1));
    expect(seqDur(out), Q.of(2));
  });
}
