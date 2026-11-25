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
    'leave-gap lengthen still collides; video-only ripple trim lengthen stays',
    () {
      final p = f.three();
      final a = media(p).first['id'] as String;
      expect(
        () => move.change(p, TrimClip(a, 'out', Q.of(1, 2))),
        code('COLLISION'),
      );
      final legacy = move.change(
        p,
        TrimClip(a, 'out', Q.of(1, 2), ripple: true),
      );
      expect(seqDur(legacy), Q.of(7, 2));
      expect(dur(legacy, a), Q.of(3, 2));
      expect(start(legacy, 'b'), Q.of(3, 2));
      expect(start(legacy, 'c'), Q.of(5, 2));
      final out = move.change(p, RippleTrimClip(a, 'out', Q.of(1, 2)));
      expect(seqDur(out), Q.of(7, 2));
      expect(dur(out, a), Q.of(3, 2));
      expect(sourceStart(out, a), Q.of(0));
      expect(start(out, 'b'), Q.of(3, 2));
      expect(sourceStart(out, 'b'), Q.of(1));
      expect(start(out, 'c'), Q.of(5, 2));
      expect(sourceStart(out, 'c'), Q.of(2));
      expect(p.toJson()['assets'], out.toJson()['assets']);
      final shortened = move.change(out, RippleTrimClip(a, 'out', Q.of(-1, 2)));
      expect(seqDur(shortened), Q.of(3));
      expect(dur(shortened, a), Q.of(1));
      expect(start(shortened, 'b'), Q.of(1));
    },
  );

  test('ripple trim in lengthen pins start, remaps earlier source, and shifts later clips', () {
    final p = f.three();
    expect(
      () => move.change(p, TrimClip('b', 'in', Q.of(-1, 2))),
      code('COLLISION'),
    );
    final out = move.change(p, RippleTrimClip('b', 'in', Q.of(-1, 2)));
    expect(start(out, 'b'), Q.of(1));
    expect(dur(out, 'b'), Q.of(3, 2));
    expect(sourceStart(out, 'b'), Q.of(1, 2));
    expect(start(out, 'c'), Q.of(5, 2));
    expect(sourceStart(out, 'c'), Q.of(2));
    expect(seqDur(out), Q.of(7, 2));
    final inserted = move.change(
      p,
      PasteClips(
        buildClipboard(p, [media(p).first['id'] as String]),
        at: Q.of(1),
        mode: 'insert',
      ),
    );
    expect(seqDur(inserted), Q.of(4));
  });

  test('ripple trim out lengthen remaps later opacity and does not move earlier clips', () {
    var p = f.three();
    final a = media(p).first['id'] as String;
    p = move.change(p, SetOpacityKeyframe('c', Q.of(0), .25));
    p = move.change(p, SetOpacityKeyframe('c', Q.of(1), .75));
    final out = move.change(p, RippleTrimClip('b', 'out', Q.of(1, 2)));
    expect(start(out, a), Q.of(0));
    expect(dur(out, 'b'), Q.of(3, 2));
    expect(start(out, 'c'), Q.of(5, 2));
    expect(out.toJson()['effects'], isNotEmpty);
    expect(seqDur(out), Q.of(7, 2));
  });

  test('ripple trim lengthen splits an unselected sync-lock audio spanning the old end', () {
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
    final out = move.change(p, RippleTrimClip('video-b', 'out', Q.of(1, 2)));
    expect(start(out, video), Q.of(0));
    expect(dur(out, 'video-b'), Q.of(3, 2));
    expect(start(out, 'video-c'), Q.of(5, 2));
    expect(sourceStart(out, 'video-c'), Q.of(2));
    final audios = media(out)
        .where((c) => c['trackId'] != clip(out, video)['trackId'])
        .toList();
    expect(audios, hasLength(2));
    expect(Q.fromJson(audios.first['timelineRange']['start']), Q.of(0));
    expect(Q.fromJson(audios.first['timelineRange']['duration']), Q.of(2));
    expect(Q.fromJson(audios.first['sourceRange']['start']), Q.of(0));
    expect(clip(out, audio), audios.first);
    expect(Q.fromJson(audios.last['timelineRange']['start']), Q.of(5, 2));
    expect(Q.fromJson(audios.last['timelineRange']['duration']), Q.of(1));
    expect(Q.fromJson(audios.last['sourceRange']['start']), Q.of(2));
    expect(seqDur(out), Q.of(7, 2));
  });

  test('ripple trim lengthen refuses locked tracks wholly and does not change the document', () {
    final p = f.three();
    final d = p.toJson();
    d['sequences'][0]['tracks'][0]['locked'] = true;
    final locked = ProjectDocument.fromJson(d);
    expect(
      () => move.change(locked, RippleTrimClip('b', 'out', Q.of(1, 2))),
      code('FIELD_LOCKED'),
    );
    expect(locked.hash, ProjectDocument.fromJson(d).hash);
  });

  test('ripple trim out lengthen at a dissolve cut keeps and shifts the later dissolve', () {
    var p = f.three();
    final a = media(p).first['id'] as String;
    p = move.change(p, SetDissolve(a, 'b', Q.of(1, 5), Q.of(1, 5)));
    p = move.change(p, SetDissolve('b', 'c', Q.of(1, 5), Q.of(1, 5)));
    final out = move.change(p, RippleTrimClip('b', 'out', Q.of(1, 2)));
    expect(out.toJson()['transitions'], hasLength(2));
    expect(Q.fromJson(out.toJson()['transitions'][0]['cut']), Q.of(1));
    expect(Q.fromJson(out.toJson()['transitions'][1]['cut']), Q.of(5, 2));
    expect(start(out, 'c'), Q.of(5, 2));
    expect(dur(out, 'b'), Q.of(3, 2));
    expect(seqDur(out), Q.of(7, 2));
  });
}
