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

Q cueDur(ProjectDocument p, [String id = 'cue-1']) =>
    Q.fromJson(cueOf(p, id)['timelineRange']['duration']);

String content(ProjectDocument p) =>
    contentHash(p.toJson()..remove('revision'));

(ProjectDocument, String, String) linked() {
  var p = avFixture();
  final video = media(p).single['id'] as String;
  p = move.change(p, ExtractAudioClip(video, 'audio-stream'));
  final audio = media(p).singleWhere((c) => c['id'] != video)['id'] as String;
  return (p, video, audio);
}

CaptionCue toSource(ProjectDocument p, CaptionCue cue, String clipId) {
  final host = clipOf(p, clipId);
  return cue.anchoredToSource(
    clipId: clipId,
    clipStart: Q.fromJson(host['timelineRange']['start']),
    clipDuration: Q.fromJson(host['timelineRange']['duration']),
    sourceDuration: Q.fromJson(host['sourceRange']['duration']),
    rate: Q.fromJson(host['timeMap']['rate']),
  );
}

ProjectDocument attachSource(
  ProjectDocument p,
  String clipId, {
  String id = 'cue-1',
  String text = 'hello',
  Q? start,
  Q? duration,
}) {
  final cs = startOf(p, clipId);
  final cue = toSource(
    p,
    CaptionCue(
      id,
      TimeRange(start ?? cs, duration ?? Q.of(1, 2)),
      text,
      manualFields: {'text', 'timing'},
    ),
    clipId,
  );
  return move.change(p, SetCaptions(CaptionStore([cue])));
}

void main() {
  test('new covered cues still default to clipLocal, not source', () {
    final (base, video, _) = linked();
    final p = move.change(
      base,
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
    expect(cueOf(p)['anchor']['clipId'], video);
  });

  test('explicit source cue follows reject move; absolute sibling stays; text unchanged', () {
    final (base, video, _) = linked();
    var p = attachSource(base, video, duration: Q.of(1, 2));
    p = move.change(
      p,
      SetCaptions(
        CaptionStore([
          CaptionCue.fromProjectJson(Map<String, dynamic>.from(cueOf(p))),
          CaptionCue(
            'cue-abs',
            TimeRange(Q.of(2), Q.of(1, 2)),
            'stays',
            manualFields: {'text', 'timing'},
          ),
        ]),
      ),
    );
    // A brand-new covered cue would default to clipLocal; freeze it absolute.
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
    expect(cueOf(p)['anchor']['kind'], 'source');
    final textBefore = cueOf(p)['text'];
    final localBefore = cueOf(p)['anchor']['range'];
    final out = move.change(p, MoveClips([video], Q.of(1, 2)));
    expect(startOf(out, video), Q.of(1, 2));
    expect(cueStart(out), Q.of(1, 2));
    expect(cueOf(out)['text'], textBefore);
    expect(cueOf(out)['anchor']['kind'], 'source');
    expect(cueOf(out)['anchor']['range'], localBefore);
    expect(cueStart(out, 'cue-abs'), Q.of(2));
    expect(cueOf(out, 'cue-abs')['anchor']['kind'], 'absolute');
  });

  test('includeLinks=false follows only the moved host', () {
    final (base, video, audio) = linked();
    final p = attachSource(base, video);
    final out = move.change(
      p,
      MoveClips([video], Q.of(1, 2), includeLinks: false),
    );
    expect(startOf(out, video), Q.of(1, 2));
    expect(startOf(out, audio), Q.of(0));
    expect(cueStart(out), Q.of(1, 2));
    expect(cueOf(out)['anchor']['clipId'], video);
    expect(cueOf(out)['anchor']['kind'], 'source');
  });

  test(
    'insert move still leaves a source gap and the host source cue follows',
    () {
      final (base, video, audio) = linked();
      final p = attachSource(base, video);
      final inserted = move.change(
        p,
        MoveClips([video], Q.of(3, 2), mode: 'insert', includeLinks: false),
      );
      expect(startOf(inserted, video), Q.of(3, 2));
      expect(startOf(inserted, audio), Q.of(0));
      expect(cueStart(inserted), Q.of(3, 2));
      expect(cueOf(inserted)['anchor']['kind'], 'source');
      expect(
        Q.fromJson(inserted.toJson()['sequences'][0]['duration']),
        greaterThan(Q.fromJson(p.toJson()['sequences'][0]['duration'])),
      );
    },
  );

  test(
    'ripple close that still covers a later source cue reprojects locals',
    () {
      final (base, video, _) = linked();
      final p = attachSource(base, video, start: Q.of(2), duration: Q.of(1, 2));
      final out = move.change(
        p,
        RippleDeleteClips(const [], range: TimeRange(Q.of(0), Q.of(1))),
      );
      expect(cueOf(out)['anchor']['kind'], 'source');
      expect(cueOf(out)['text'], 'hello');
      expect(cueStart(out), Q.of(1));
      expect(cueDur(out), Q.of(1, 2));
      expect(Q.fromJson(cueOf(out)['anchor']['range']['start']), Q.of(1));
      expect(Q.fromJson(cueOf(out)['anchor']['range']['duration']), Q.of(1, 2));
    },
  );

  test(
    'ripple close that would uncover a source cue refuses and drops nothing',
    () {
      final (base, video, _) = linked();
      final p = attachSource(base, video, start: Q.of(0), duration: Q.of(2));
      expect(
        () => move.change(
          p,
          RippleDeleteClips(const [], range: TimeRange(Q.of(1), Q.of(1))),
        ),
        code('ANCHOR_OUT_OF_RANGE'),
      );
      expect(content(p), content(ProjectDocument.fromJson(p.toJson())));
      expect(cueOf(p)['text'], 'hello');
      expect(cueOf(p)['anchor']['kind'], 'source');
    },
  );

  test(
    'ripple delete of the host refuses instead of dropping the source cue',
    () {
      final (base, video, _) = linked();
      final p = attachSource(base, video);
      expect(
        () => move.change(p, RippleDeleteClips([video])),
        code('ANCHOR_OUT_OF_RANGE'),
      );
      expect(content(p), content(ProjectDocument.fromJson(p.toJson())));
      expect((p.toJson()['captions'] as List), hasLength(1));
    },
  );

  test('anchoredToSource of a cue past the host, and styles, still refuse', () {
    final (base, video, _) = linked();
    final host = clipOf(base, video);
    final past = CaptionCue(
      'cue-1',
      TimeRange(Q.of(4), Q.of(1, 2)),
      'past',
      manualFields: {'text', 'timing'},
    );
    expect(
      () => past.anchoredToSource(
        clipId: video,
        clipStart: Q.fromJson(host['timelineRange']['start']),
        clipDuration: Q.fromJson(host['timelineRange']['duration']),
        sourceDuration: Q.fromJson(host['sourceRange']['duration']),
        rate: Q.fromJson(host['timeMap']['rate']),
      ),
      code('ANCHOR_OUT_OF_RANGE'),
    );
    final d = attachSource(base, video).toJson();
    d['captions'][0]['styleEffectId'] = 'style-1';
    expect(
      () => CaptionCue.fromProjectJson(
        Map<String, dynamic>.from(d['captions'][0] as Map),
      ),
      code('CAPTION_RICH_EDIT_NOT_IMPLEMENTED'),
    );
  });

  test(
    'split and trim of a source cue slice the source window, not the text',
    () {
      final (base, video, _) = linked();
      final p = attachSource(base, video, start: Q.of(0), duration: Q.of(2));
      final cue = CaptionCue.fromProjectJson(
        Map<String, dynamic>.from(cueOf(p)),
      );
      final parts = cue.split(Q.of(1), 'cue-right');
      expect(parts[0].text, 'hello');
      expect(parts[1].text, 'hello');
      expect(parts[0].anchorKind, 'source');
      expect(parts[1].anchorKind, 'source');
      expect(parts[0].anchorRange!.start, Q.of(0));
      expect(parts[0].anchorRange!.duration, Q.of(1));
      expect(parts[1].anchorRange!.start, Q.of(1));
      expect(parts[1].anchorRange!.duration, Q.of(1));
      final trimmed = cue.trim(TimeRange(Q.of(1, 2), Q.of(1)));
      expect(trimmed.text, 'hello');
      expect(trimmed.range.start, Q.of(1, 2));
      expect(trimmed.range.duration, Q.of(1));
      expect(trimmed.anchorKind, 'source');
      expect(trimmed.anchorRange!.start, Q.of(1, 2));
      expect(trimmed.anchorRange!.duration, Q.of(1));
    },
  );

  test('makeAbsolute stops source follow on the next move', () {
    final (base, video, _) = linked();
    var p = attachSource(base, video);
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

  test('locked selected host still refuses the whole group and leaves the source cue', () {
    final (base, video, _) = linked();
    final p = attachSource(base, video);
    final d = p.toJson();
    d['sequences'][0]['tracks'][0]['locked'] = true;
    final locked = ProjectDocument.fromJson(d);
    expect(
      () => move.change(locked, MoveClips([video], Q.of(1, 2))),
      code('FIELD_LOCKED'),
    );
    expect(content(locked), content(ProjectDocument.fromJson(d)));
    expect(cueOf(locked)['text'], 'hello');
    expect(cueOf(locked)['anchor']['kind'], 'source');
  });
}
