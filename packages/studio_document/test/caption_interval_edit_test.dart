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

List<Map> cuesOf(ProjectDocument p) =>
    (p.toJson()['captions'] as List).cast<Map>();

Map cueOf(ProjectDocument p, [String id = 'cue-1']) =>
    cuesOf(p).singleWhere((c) => c['id'] == id);

Q cueStart(ProjectDocument p, [String id = 'cue-1']) =>
    Q.fromJson(cueOf(p, id)['timelineRange']['start']);

Q cueDur(ProjectDocument p, [String id = 'cue-1']) =>
    Q.fromJson(cueOf(p, id)['timelineRange']['duration']);

(ProjectDocument, String, String) linked() {
  var p = avFixture();
  final video = media(p).single['id'] as String;
  p = move.change(p, ExtractAudioClip(video, 'audio-stream'));
  final audio = media(p).singleWhere((c) => c['id'] != video)['id'] as String;
  return (p, video, audio);
}

ProjectDocument attachCue(
  ProjectDocument p, {
  String id = 'cue-1',
  String text = 'hello',
  required Q start,
  required Q duration,
  String? clipId,
  bool forceAbsolute = false,
}) {
  var cue = CaptionCue(
    id,
    TimeRange(start, duration),
    text,
    manualFields: {'text', 'timing'},
  );
  if (clipId != null) {
    cue = cue.anchoredToClip(clipId, startOf(p, clipId), durOf(p, clipId));
  }
  p = move.change(p, SetCaptions(CaptionStore([cue])));
  if (!forceAbsolute) {
    return p;
  }
  return move.change(
    p,
    SetCaptions(
      CaptionStore([
        CaptionCue.fromProjectJson(Map<String, dynamic>.from(cueOf(p, id)))
            .makeAbsolute(),
      ]),
    ),
  );
}

String content(ProjectDocument p) =>
    contentHash(p.toJson()..remove('revision'));

void main() {
  test('ripple close crops, splits, and shifts absolute cues without rewriting text', () {
    final (base, video, _) = linked();
    var p = attachCue(
      base,
      start: Q.of(1, 2),
      duration: Q.of(2),
      forceAbsolute: true,
    );
    p = move.change(
      p,
      SetCaptions(
        CaptionStore([
          CaptionCue.fromProjectJson(Map<String, dynamic>.from(cueOf(p))),
          CaptionCue(
            'cue-later',
            TimeRange(Q.of(5, 2), Q.of(1, 2)),
            'later',
            manualFields: {'text', 'timing'},
          ),
        ]),
      ),
    );
    p = move.change(
      p,
      RippleDeleteClips(const [], range: TimeRange(Q.of(1), Q.of(1))),
    );
    expect(startOf(p, video), Q.of(0));
    expect(durOf(p, video), Q.of(1));
    final left = cuesOf(p)
        .singleWhere((c) => c['text'] == 'hello' && c['id'] == 'cue-1');
    final right = cuesOf(p)
        .singleWhere((c) => c['text'] == 'hello' && c['id'] != 'cue-1');
    expect(Q.fromJson(left['timelineRange']['start']), Q.of(1, 2));
    expect(Q.fromJson(left['timelineRange']['duration']), Q.of(1, 2));
    expect(Q.fromJson(right['timelineRange']['start']), Q.of(1));
    expect(Q.fromJson(right['timelineRange']['duration']), Q.of(1, 2));
    expect(left['anchor']['kind'], 'absolute');
    expect(right['anchor']['kind'], 'absolute');
    expect(cueStart(p, 'cue-later'), Q.of(3, 2));
    expect(cueDur(p, 'cue-later'), Q.of(1, 2));
    expect(cuesOf(p).map((c) => c['text']), isNot(contains('hellohello')));

    var dropped = attachCue(
      base,
      id: 'cue-inside',
      text: 'gone',
      start: Q.of(5, 4),
      duration: Q.of(1, 4),
      forceAbsolute: true,
    );
    dropped = move.change(
      dropped,
      RippleDeleteClips(const [], range: TimeRange(Q.of(1), Q.of(1))),
    );
    expect(cuesOf(dropped), isEmpty);
  });

  test('clipLocal later cue follows once after a close; spanning cue splits onto remnants', () {
    final (base, video, _) = linked();
    var p = attachCue(
      base,
      start: Q.of(1, 2),
      duration: Q.of(2),
      clipId: video,
    );
    p = move.change(
      p,
      SetCaptions(
        CaptionStore([
          CaptionCue.fromProjectJson(Map<String, dynamic>.from(cueOf(p))),
          CaptionCue(
            'cue-later',
            TimeRange(Q.of(5, 2), Q.of(1, 2)),
            'later',
            manualFields: {'text', 'timing'},
          ).anchoredToClip(video, startOf(p, video), durOf(p, video)),
        ]),
      ),
    );
    p = move.change(
      p,
      RippleDeleteClips(const [], range: TimeRange(Q.of(1), Q.of(1))),
    );
    final left = cueOf(p);
    final right = cuesOf(p)
        .singleWhere((c) => c['id'] != left['id'] && c['text'] == 'hello');
    final later = cueOf(p, 'cue-later');
    expect(Q.fromJson(left['timelineRange']['start']), Q.of(1, 2));
    expect(Q.fromJson(left['timelineRange']['duration']), Q.of(1, 2));
    expect(Q.fromJson(right['timelineRange']['start']), Q.of(1));
    expect(Q.fromJson(right['timelineRange']['duration']), Q.of(1, 2));
    expect(cueStart(p, 'cue-later'), Q.of(3, 2));
    expect(later['anchor']['kind'], 'clipLocal');
    expect(left['anchor']['kind'], 'clipLocal');
    expect(right['anchor']['kind'], 'clipLocal');
    expect(left['anchor']['clipId'], video);
    expect(right['anchor']['clipId'], isNot(video));
    expect(later['anchor']['clipId'], right['anchor']['clipId']);
    expect(durOf(p, video), Q.of(1));
    expect(durOf(p, right['anchor']['clipId'] as String), Q.of(1));
    expect(startOf(p, right['anchor']['clipId'] as String), Q.of(1));
  });

  test('insert move leaves a source gap; unsplit host clipLocal is not split at the hole', () {
    final (base, video, _) = linked();
    var p = attachCue(
      base,
      start: Q.of(0),
      duration: Q.of(1, 2),
      clipId: video,
    );
    p = move.change(
      p,
      SetCaptions(
        CaptionStore([
          CaptionCue.fromProjectJson(Map<String, dynamic>.from(cueOf(p))),
          CaptionCue(
            'cue-abs',
            TimeRange(Q.of(2), Q.of(1, 2)),
            'later abs',
            manualFields: {'text', 'timing'},
          ),
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
    p = move.change(p, MoveClips([video], Q.of(1), mode: 'insert'));
    expect(startOf(p, video), Q.of(1));
    expect(durOf(p, video), Q.of(3));
    expect(cueStart(p), Q.of(1));
    expect(cueDur(p), Q.of(1, 2));
    expect(cuesOf(p).where((c) => c['text'] == 'hello'), hasLength(1));
    expect(cueOf(p)['anchor']['clipId'], video);
    // Absolute later cue sits after the insert point, so the destination
    // hole shifts it in timeline space; the moving host still leaves a gap.
    expect(cueStart(p, 'cue-abs'), Q.of(5));
    expect(
      media(p).where((c) => startOf(p, c['id'] as String) == Q.of(0)),
      isEmpty,
    );
  });

  test('insert opening splits an absolute cue that spans the hole', () {
    final (base, video, _) = linked();
    var p = attachCue(
      base,
      start: Q.of(0),
      duration: Q.of(2),
      forceAbsolute: true,
    );
    p = move.change(p, MoveClips([video], Q.of(1), mode: 'insert'));
    final left = cueOf(p);
    final right = cuesOf(p).singleWhere((c) => c['id'] != left['id']);
    expect(left['text'], 'hello');
    expect(right['text'], 'hello');
    expect(Q.fromJson(left['timelineRange']['start']), Q.of(0));
    expect(Q.fromJson(left['timelineRange']['duration']), Q.of(1));
    expect(Q.fromJson(right['timelineRange']['start']), Q.of(4));
    expect(Q.fromJson(right['timelineRange']['duration']), Q.of(1));
    expect(startOf(p, video), Q.of(1));
  });

  test('ripple trim shorten reuses the same interval transform', () {
    final (base, video, _) = linked();
    final p = attachCue(
      base,
      start: Q.of(0),
      duration: Q.of(7, 2),
      forceAbsolute: true,
    );
    final shortened = move.change(p, RippleTrimClip(video, 'out', Q.of(-1)));
    expect(durOf(shortened, video), Q.of(2));
    final shortLeft = cueOf(shortened);
    final shortRight = cuesOf(shortened)
        .singleWhere((c) => c['id'] != shortLeft['id']);
    expect(Q.fromJson(shortLeft['timelineRange']['start']), Q.of(0));
    expect(Q.fromJson(shortLeft['timelineRange']['duration']), Q.of(2));
    expect(Q.fromJson(shortRight['timelineRange']['start']), Q.of(2));
    expect(Q.fromJson(shortRight['timelineRange']['duration']), Q.of(1, 2));

    // Lengthen-out is not available on this 3s source (already fully used);
    // SDK packed-clip tests cover ripple-trim lengthen with captions.
  });

  test('uncovering a source cue or a locked caption track still refuse the whole command', () {
    final (base, video, _) = linked();
    final p = attachCue(
      base,
      start: Q.of(0),
      duration: Q.of(2),
      forceAbsolute: true,
    );
    final d = p.toJson();
    d['captions'][0]['anchor'] = {
      'kind': 'source',
      'clipId': video,
      'range': {'start': Q.of(0).toJson(), 'duration': Q.of(2).toJson()},
    };
    final sourced = ProjectDocument.fromJson(d);
    expect(
      () => move.change(
        sourced,
        RippleDeleteClips(const [], range: TimeRange(Q.of(1), Q.of(1))),
      ),
      code('ANCHOR_OUT_OF_RANGE'),
    );
    expect(content(sourced), content(ProjectDocument.fromJson(d)));

    final lockedJson = p.toJson();
    for (final t in lockedJson['sequences'][0]['tracks'] as List) {
      if (t['kind'] == 'caption') {
        t['locked'] = true;
      }
    }
    final locked = ProjectDocument.fromJson(lockedJson);
    expect(
      () => move.change(
        locked,
        RippleDeleteClips(const [], range: TimeRange(Q.of(1), Q.of(1))),
      ),
      code('FIELD_LOCKED'),
    );
    expect(content(locked), content(ProjectDocument.fromJson(lockedJson)));
  });
}
