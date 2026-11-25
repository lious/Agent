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
  test('insert move still leaves a source gap; close range packs it and shortens duration', () {
    final p = f.three();
    final a = media(p).first['id'] as String;
    final moved = move.change(p, MoveClips([a], Q.of(3, 2), mode: 'insert'));
    expect(seqDur(moved), Q.of(4));
    expect(start(moved, a), Q.of(3, 2));
    expect(
      media(moved).where((c) => start(moved, c['id'] as String) == Q.of(0)),
      isEmpty,
    );
    final out = move.change(
      moved,
      RippleDeleteClips(const [], range: TimeRange(Q.of(0), Q.of(1))),
    );
    expect(seqDur(out), Q.of(3));
    expect(start(out, 'b'), Q.of(0));
    expect(dur(out, 'b'), Q.of(1, 2));
    expect(start(out, a), Q.of(1, 2));
    expect(sourceStart(out, a), Q.of(0));
    expect(start(out, 'c'), Q.of(2));
    expect(out.toJson()['assets'], p.toJson()['assets']);
    final byId = move.change(p, RippleDeleteClips(['c']));
    expect(seqDur(byId), Q.of(2));
  });

  test(
    'range and clip ids are mutually exclusive; invalid ranges refuse wholly',
    () {
      final p = f.three();
      final frozen = p.hash;
      expect(
        () => RippleDeleteClips(['c'], range: TimeRange(Q.of(0), Q.of(1))),
        code('RIPPLE_RANGE_AND_SELECTION'),
      );
      expect(
        () => RippleDeleteClips(const [], range: TimeRange(Q.of(-1), Q.of(1))),
        code('NEGATIVE_TIMELINE_START'),
      );
      expect(() => RippleDeleteClips(const []), code('EMPTY_SELECTION'));
      expect(() => TimeRange(Q.of(0), Q.of(0)), code('INVALID_RANGE'));
      expect(p.hash, frozen);
    },
  );

  test('insert paste stays distinct from closing a vacated interval', () {
    final p = f.three();
    final a = media(p).first['id'] as String;
    final inserted = move.change(
      p,
      PasteClips(buildClipboard(p, [a]), at: Q.of(1), mode: 'insert'),
    );
    expect(seqDur(inserted), Q.of(4));
  });

  test(
    'closing a mid-span range crops unselected items and remaps sources',
    () {
      var p = avFixture();
      final video = media(p).single['id'] as String;
      p = move.change(p, ExtractAudioClip(video, 'audio-stream'));
      p = move.change(
        p,
        UnlinkAudioVideo(p.toJson()['linkGroups'][0]['id'] as String),
      );
      final out = move.change(
        p,
        RippleDeleteClips(const [], range: TimeRange(Q.of(1), Q.of(1))),
      );
      expect(dur(out, video), Q.of(1));
      expect(start(out, video), Q.of(0));
      final right = media(out)
          .where(
            (c) =>
                c['trackId'] == clip(out, video)['trackId'] && c['id'] != video,
          )
          .single;
      expect(Q.fromJson(right['timelineRange']['start']), Q.of(1));
      expect(Q.fromJson(right['sourceRange']['start']), Q.of(2));
      final audios = media(out)
          .where((c) => c['trackId'] != clip(out, video)['trackId'])
          .toList();
      expect(audios, hasLength(2));
      expect(Q.fromJson(audios.first['timelineRange']['duration']), Q.of(1));
      expect(Q.fromJson(audios.last['timelineRange']['start']), Q.of(1));
      expect(Q.fromJson(audios.last['sourceRange']['start']), Q.of(2));
      expect(seqDur(out), Q.of(2));
    },
  );

  test('range close refuses locked sync-lock tracks wholly', () {
    final p = f.three();
    final d = p.toJson();
    d['sequences'][0]['tracks'][0]['locked'] = true;
    final locked = ProjectDocument.fromJson(d);
    expect(
      () => move.change(
        locked,
        RippleDeleteClips(const [], range: TimeRange(Q.of(0), Q.of(1))),
      ),
      code('SYNC_LOCKED'),
    );
    expect(locked.hash, ProjectDocument.fromJson(d).hash);
  });

  test('range close shifts later dissolves and drops cuts inside the hole', () {
    var p = f.three();
    final a = media(p).first['id'] as String;
    p = move.change(p, SetDissolve(a, 'b', Q.of(1, 5), Q.of(1, 5)));
    p = move.change(p, SetDissolve('b', 'c', Q.of(1, 5), Q.of(1, 5)));
    final out = move.change(
      p,
      RippleDeleteClips(const [], range: TimeRange(Q.of(0), Q.of(1))),
    );
    expect(out.toJson()['transitions'], hasLength(1));
    expect(out.toJson()['transitions'].single['leftClipId'], 'b');
    expect(out.toJson()['transitions'].single['rightClipId'], 'c');
    expect(Q.fromJson(out.toJson()['transitions'].single['cut']), Q.of(1));
    expect(start(out, 'b'), Q.of(0));
    expect(seqDur(out), Q.of(2));
  });
}
