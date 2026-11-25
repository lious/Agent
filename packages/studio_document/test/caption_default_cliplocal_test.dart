import 'package:studio_contracts/studio_contracts.dart';
import 'package:studio_document/studio_document.dart';
import 'package:test/test.dart';

import 'multi_move_test.dart' as move;
import 'persistent_audio_test.dart' show avFixture;

Matcher code(String c) =>
    throwsA(isA<StudioException>().having((e) => e.code, 'code', c));

List<Map> media(ProjectDocument p) => [
  for (final t in p.toJson()['sequences'][0]['tracks'])
    for (final c in t['items'])
      if (c['source'] != null) c as Map,
];

Map clipOf(ProjectDocument p, String id) =>
    media(p).singleWhere((c) => c['id'] == id);

Q startOf(ProjectDocument p, String id) =>
    Q.fromJson(clipOf(p, id)['timelineRange']['start']);

Map cueOf(ProjectDocument p, [String id = 'cue-1']) =>
    (p.toJson()['captions'] as List).cast<Map>().singleWhere(
      (c) => c['id'] == id,
    );

Q cueStart(ProjectDocument p, [String id = 'cue-1']) =>
    Q.fromJson(cueOf(p, id)['timelineRange']['start']);

String content(ProjectDocument p) =>
    contentHash(p.toJson()..remove('revision'));

void main() {
  test('a new cue on a unique covering host defaults to clipLocal and follows a move', () {
    var p = avFixture();
    final video = media(p).single['id'] as String;
    p = move.change(
      p,
      SetCaptions(
        CaptionStore([
          CaptionCue(
            'cue-1',
            TimeRange(Q.of(0), Q.of(1, 2)),
            'follows',
            manualFields: {'text', 'timing'},
          ),
        ]),
      ),
    );
    expect(cueOf(p)['anchor']['kind'], 'clipLocal');
    expect(cueOf(p)['anchor']['clipId'], video);
    expect(cueStart(p), Q.of(0));
    final out = move.change(p, MoveClips([video], Q.of(1, 2)));
    expect(startOf(out, video), Q.of(1, 2));
    expect(cueStart(out), Q.of(1, 2));
    expect(cueOf(out)['text'], 'follows');
    expect(cueOf(out)['anchor']['clipId'], video);
  });

  test('a cue spanning a cut or sitting in a gap stays absolute and does not follow', () {
    var p = avFixture();
    final video = media(p).single['id'] as String;
    p = move.change(p, SplitClip(video, Q.of(3, 2), 'video-right'));
    p = move.change(
      p,
      SetCaptions(
        CaptionStore([
          CaptionCue(
            'cue-span',
            TimeRange(Q.of(1), Q.of(1)),
            'spans cut',
            manualFields: {'text', 'timing'},
          ),
        ]),
      ),
    );
    expect(cueOf(p, 'cue-span')['anchor']['kind'], 'absolute');
    final moved = move.change(p, MoveClips([video, 'video-right'], Q.of(1, 2)));
    expect(startOf(moved, video), Q.of(1, 2));
    expect(cueStart(moved, 'cue-span'), Q.of(1));

    var gapped = avFixture();
    final host = media(gapped).single['id'] as String;
    gapped = move.change(gapped, DeleteClip(host, ripple: false));
    gapped = move.change(
      gapped,
      SetCaptions(
        CaptionStore([
          CaptionCue(
            'cue-gap',
            TimeRange(Q.of(0), Q.of(1, 2)),
            'in gap',
            manualFields: {'text', 'timing'},
          ),
        ]),
      ),
    );
    expect(cueOf(gapped, 'cue-gap')['anchor']['kind'], 'absolute');
  });

  test(
    'makeAbsolute is not re-anchored; planted source cues follow their host',
    () {
      var p = avFixture();
      final video = media(p).single['id'] as String;
      p = move.change(
        p,
        SetCaptions(
          CaptionStore([
            CaptionCue(
              'cue-1',
              TimeRange(Q.of(0), Q.of(1, 2)),
              'hello',
              manualFields: {'text', 'timing'},
            ),
          ]),
        ),
      );
      expect(cueOf(p)['anchor']['kind'], 'clipLocal');
      p = move.change(
        p,
        SetCaptions(
          CaptionStore([
            CaptionCue.fromProjectJson(Map<String, dynamic>.from(cueOf(p)))
                .makeAbsolute(),
          ]),
        ),
      );
      expect(cueOf(p)['anchor']['kind'], 'absolute');
      final edited = move.change(
        p,
        SetCaptions(
          CaptionStore([
            CaptionCue.fromProjectJson(Map<String, dynamic>.from(cueOf(p)))
                .editText('still absolute'),
          ]),
        ),
      );
      expect(cueOf(edited)['anchor']['kind'], 'absolute');
      expect(cueOf(edited)['text'], 'still absolute');
      final out = move.change(edited, MoveClips([video], Q.of(1, 2)));
      expect(startOf(out, video), Q.of(1, 2));
      expect(cueStart(out), Q.of(0));

      final d = p.toJson();
      d['captions'][0]['anchor'] = {
        'kind': 'source',
        'clipId': video,
        'range': {'start': Q.of(0).toJson(), 'duration': Q.of(1, 2).toJson()},
      };
      final sourced = ProjectDocument.fromJson(d);
      final followed = move.change(sourced, MoveClips([video], Q.of(1, 2)));
      expect(startOf(followed, video), Q.of(1, 2));
      expect(cueStart(followed), Q.of(1, 2));
      expect(cueOf(followed)['anchor']['kind'], 'source');
      expect(cueOf(followed)['text'], 'hello');
    },
  );
}
