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

Q durOf(ProjectDocument p, String id) =>
    Q.fromJson(clipOf(p, id)['timelineRange']['duration']);

Map cueOf(ProjectDocument p, [String id = 'cue-1']) =>
    (p.toJson()['captions'] as List).cast<Map>().singleWhere(
      (c) => c['id'] == id,
    );

Q cueStart(ProjectDocument p, [String id = 'cue-1']) =>
    Q.fromJson(cueOf(p, id)['timelineRange']['start']);

(ProjectDocument, String, String) linked() {
  var p = avFixture();
  final video = media(p).single['id'] as String;
  p = move.change(p, ExtractAudioClip(video, 'audio-stream'));
  final audio = media(p).singleWhere((c) => c['id'] != video)['id'] as String;
  return (p, video, audio);
}

ProjectDocument attachCue(
  ProjectDocument p,
  String clipId, {
  String id = 'cue-1',
  String text = 'hello',
  Q? start,
  Q? duration,
  bool clipLocal = true,
}) {
  final cs = startOf(p, clipId);
  final cd = durOf(p, clipId);
  var cue = CaptionCue(
    id,
    TimeRange(start ?? cs, duration ?? Q.of(1, 2)),
    text,
    manualFields: {'text', 'timing'},
  );
  if (clipLocal) {
    cue = cue.anchoredToClip(clipId, cs, cd);
  }
  return move.change(p, SetCaptions(CaptionStore([cue])));
}

void main() {
  test('clipLocal cue follows a reject move; absolute sibling stays; text and local range unchanged', () {
    final (base, video, audio) = linked();
    var p = attachCue(base, video, duration: Q.of(1, 2));
    final absolute = CaptionCue(
      'cue-abs',
      TimeRange(Q.of(2), Q.of(1, 2)),
      'stays',
      manualFields: {'text', 'timing'},
    );
    p = move.change(
      p,
      SetCaptions(
        CaptionStore([
          CaptionCue.fromProjectJson(Map<String, dynamic>.from(cueOf(p))),
          absolute,
        ]),
      ),
    );
    p = move.change(
      p,
      SetCaptions(
        CaptionStore([
          CaptionCue.fromProjectJson(Map<String, dynamic>.from(cueOf(p))),
          CaptionCue.fromProjectJson(
            Map<String, dynamic>.from(cueOf(p, 'cue-abs')),
          ).makeAbsolute(),
        ]),
      ),
    );
    final localBefore = cueOf(p)['anchor'];
    final textBefore = cueOf(p)['text'];
    final out = move.change(p, MoveClips([video], Q.of(1, 2)));
    expect(startOf(out, video), Q.of(1, 2));
    expect(startOf(out, audio), Q.of(1, 2));
    expect(cueStart(out), Q.of(1, 2));
    expect(cueOf(out)['text'], textBefore);
    expect(cueOf(out)['anchor'], localBefore);
    expect(cueStart(out, 'cue-abs'), Q.of(2));
    expect(cueOf(out, 'cue-abs')['anchor']['kind'], 'absolute');
  });

  test('includeLinks=false follows only the moved host; unmoved audio partner does not move the cue', () {
    final (base, video, audio) = linked();
    final p = attachCue(base, video);
    final out = move.change(
      p,
      MoveClips([video], Q.of(1, 2), includeLinks: false),
    );
    expect(startOf(out, video), Q.of(1, 2));
    expect(startOf(out, audio), Q.of(0));
    expect(cueStart(out), Q.of(1, 2));
    expect(cueOf(out)['anchor']['clipId'], video);
  });

  test('insert move still leaves a source gap and later/host clipLocal cues follow', () {
    final (base, video, audio) = linked();
    final p = attachCue(base, video);
    final inserted = move.change(
      p,
      MoveClips([video], Q.of(3, 2), mode: 'insert', includeLinks: false),
    );
    expect(startOf(inserted, video), Q.of(3, 2));
    expect(startOf(inserted, audio), Q.of(0));
    expect(cueStart(inserted), Q.of(3, 2));
    expect(
      Q.fromJson(inserted.toJson()['sequences'][0]['duration']),
      greaterThan(Q.fromJson(p.toJson()['sequences'][0]['duration'])),
    );
  });

  test('source-anchored cue follows a reject move; cues past the host still refuse', () {
    final (base, video, _) = linked();
    final p = attachCue(base, video);
    final host = clipOf(p, video);
    final sourced = move.change(
      p,
      SetCaptions(
        CaptionStore([
          CaptionCue.fromProjectJson(Map<String, dynamic>.from(cueOf(p)))
              .anchoredToSource(
                clipId: video,
                clipStart: Q.fromJson(host['timelineRange']['start']),
                clipDuration: Q.fromJson(host['timelineRange']['duration']),
                sourceDuration: Q.fromJson(host['sourceRange']['duration']),
                rate: Q.fromJson(host['timeMap']['rate']),
              ),
        ]),
      ),
    );
    expect(cueOf(sourced)['anchor']['kind'], 'source');
    final out = move.change(sourced, MoveClips([video], Q.of(1, 2)));
    expect(startOf(out, video), Q.of(1, 2));
    expect(cueStart(out), Q.of(1, 2));
    expect(cueOf(out)['anchor']['kind'], 'source');
    expect(cueOf(out)['text'], 'hello');
    expect(Q.fromJson(cueOf(out)['anchor']['range']['start']), Q.of(0));
    expect(
      () => attachCue(base, video, start: Q.of(5, 2), duration: Q.of(1)),
      code('ANCHOR_OUT_OF_RANGE'),
    );
  });

  test('text edit preserves clipLocal; making absolute stops follow on the next move', () {
    final (base, video, _) = linked();
    var p = attachCue(base, video, text: 'hello');
    p = move.change(
      p,
      SetCaptions(
        CaptionStore([
          CaptionCue.fromProjectJson(Map<String, dynamic>.from(cueOf(p)))
              .editText('edited'),
        ]),
      ),
    );
    expect(cueOf(p)['text'], 'edited');
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
    final out = move.change(p, MoveClips([video], Q.of(1, 2)));
    expect(startOf(out, video), Q.of(1, 2));
    expect(cueStart(out), Q.of(0));
  });

  test(
    'locked selected host still refuses the whole group and leaves the cue',
    () {
      final (base, video, _) = linked();
      final p = attachCue(base, video);
      final d = p.toJson();
      d['sequences'][0]['tracks'][0]['locked'] = true;
      final locked = ProjectDocument.fromJson(d);
      final before = contentHash(locked.toJson());
      expect(
        () => move.change(locked, MoveClips([video], Q.of(1, 2))),
        code('FIELD_LOCKED'),
      );
      expect(contentHash(locked.toJson()), before);
    },
  );
}
