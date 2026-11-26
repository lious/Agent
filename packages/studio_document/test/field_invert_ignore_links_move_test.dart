import 'dart:convert';

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

Q durationOf(ProjectDocument p, String id) =>
    Q.fromJson(clipOf(p, id)['timelineRange']['duration']);

Map cueOf(ProjectDocument p, String id) => (p.toJson()['captions'] as List)
    .cast<Map>()
    .singleWhere((c) => c['id'] == id);

Q seqDur(ProjectDocument p) =>
    Q.fromJson(p.toJson()['sequences'][0]['duration']);

String policy(ProjectDocument p) =>
    p.toJson()['linkGroups'][0]['syncPolicy'] as String;

Q memberOffset(ProjectDocument p, String clipId) {
  final members = p.toJson()['linkGroups'][0]['members'] as List;
  return Q.fromJson(
    members.singleWhere((m) => m['clipId'] == clipId)['offset'],
  );
}

String content(ProjectDocument p) =>
    contentHash(p.toJson()..remove('revision'));

void assertPure(ProjectDocument before, void Function() action) {
  final start = content(before);
  final raw = jsonEncode(before.toJson());
  action();
  expect(content(before), start);
  expect(jsonEncode(before.toJson()), raw);
}

(ProjectDocument, String, String) linkedWithCues() {
  var p = avFixture();
  final video = media(p).single['id'] as String;
  p = move.change(p, ExtractAudioClip(video, 'audio-stream'));
  final audio = media(p).singleWhere((c) => c['id'] != video)['id'] as String;
  final hello = CaptionCue(
    'cue-left',
    TimeRange(Q.of(0), Q.of(1, 2)),
    'hello',
    manualFields: {'text', 'timing'},
  ).anchoredToClip(video, Q.of(0), Q.of(3));
  final stay = CaptionCue(
    'cue-stay',
    TimeRange(Q.of(2), Q.of(1, 2)),
    'stay',
    manualFields: {'text', 'timing'},
  );
  p = move.change(p, SetCaptions(CaptionStore([hello, stay])));
  p = move.change(
    p,
    SetCaptions(
      CaptionStore([
        CaptionCue.fromProjectJson(
          Map<String, dynamic>.from(cueOf(p, 'cue-left')),
        ),
        CaptionCue.fromProjectJson(
          Map<String, dynamic>.from(cueOf(p, 'cue-stay')),
        ).makeAbsolute(),
      ]),
    ),
  );
  return (p, video, audio);
}

ProjectDocument afterMarkers(ProjectDocument p) => move.change(
  p,
  SetMarkers(
    MarkerStore([
      TimelineMarker(
        'mark-1',
        sequenceId: p.toJson()['rootSequenceId'] as String,
        label: 'later',
        time: Q.of(3),
      ),
    ]),
  ),
);

MoveClips ignoreLinksVideo(String video) =>
    MoveClips([video], Q.of(1), includeLinks: false);

void main() {
  test('inverting an includeLinks=false MoveClips after a later marker edit restores the moved host, followed cue, and link policy', () {
    var (p, video, audio) = linkedWithCues();
    expect(startOf(p, video), Q.of(0));
    expect(startOf(p, audio), Q.of(0));
    expect(policy(p), 'preserve');
    expect(memberOffset(p, audio), Q.of(0));
    expect(seqDur(p), Q.of(3));
    final beforeMove = p;
    p = move.change(p, ignoreLinksVideo(video));
    final afterMove = p;
    expect(startOf(p, video), Q.of(1));
    expect(durationOf(p, video), Q.of(3));
    expect(startOf(p, audio), Q.of(0));
    expect(durationOf(p, audio), Q.of(3));
    expect(policy(p), 'allowOutOfSync');
    expect(memberOffset(p, audio), Q.of(0));
    expect(seqDur(p), Q.of(4));
    expect(cueOf(p, 'cue-left')['anchor']['kind'], 'clipLocal');
    expect(
      Q.fromJson(cueOf(p, 'cue-left')['timelineRange']['start']),
      Q.of(1),
    );
    expect(cueOf(p, 'cue-stay')['anchor']['kind'], 'absolute');
    expect(
      Q.fromJson(cueOf(p, 'cue-stay')['timelineRange']['start']),
      Q.of(2),
    );
    p = afterMarkers(p);
    final changes = documentFieldChanges(
      beforeMove.toJson()..remove('revision'),
      afterMove.toJson()..remove('revision'),
    );
    expect(fieldInvertConflicts(p.toJson(), changes), isFalse);
    final restored = ProjectDocument.fromJson(
      applyFieldInvert(p.toJson(), changes)
        ..['revision'] = p.revision.toString(),
    );
    expect(startOf(restored, video), Q.of(0));
    expect(startOf(restored, audio), Q.of(0));
    expect(durationOf(restored, video), Q.of(3));
    expect(durationOf(restored, audio), Q.of(3));
    expect(policy(restored), 'preserve');
    expect(memberOffset(restored, audio), Q.of(0));
    expect(seqDur(restored), Q.of(3));
    expect(cueOf(restored, 'cue-left')['text'], 'hello');
    expect(cueOf(restored, 'cue-left')['anchor']['kind'], 'clipLocal');
    expect(
      Q.fromJson(cueOf(restored, 'cue-left')['timelineRange']['start']),
      Q.of(0),
    );
    expect(cueOf(restored, 'cue-stay')['text'], 'stay');
    expect(cueOf(restored, 'cue-stay')['anchor']['kind'], 'absolute');
    expect(
      Q.fromJson(cueOf(restored, 'cue-stay')['timelineRange']['start']),
      Q.of(2),
    );
    expect((restored.toJson()['markers'] as List).single['label'], 'later');
    expect(restored.toJson()['linkGroups'], hasLength(1));
  });

  test('inverting an includeLinks=false MoveClips after a later text edit of the unmoved stay cue keeps the new text', () {
    var (p, video, audio) = linkedWithCues();
    final beforeMove = p;
    p = move.change(p, ignoreLinksVideo(video));
    final afterMove = p;
    final hello = CaptionCue.fromProjectJson(
      Map<String, dynamic>.from(cueOf(p, 'cue-left')),
    );
    final stay = CaptionCue.fromProjectJson(
      Map<String, dynamic>.from(cueOf(p, 'cue-stay')),
    );
    p = move.change(
      p,
      SetCaptions(CaptionStore([hello, stay.editText('revised')])),
    );
    final changes = documentFieldChanges(
      beforeMove.toJson()..remove('revision'),
      afterMove.toJson()..remove('revision'),
    );
    expect(fieldInvertConflicts(p.toJson(), changes), isFalse);
    final restored = ProjectDocument.fromJson(
      applyFieldInvert(p.toJson(), changes)
        ..['revision'] = p.revision.toString(),
    );
    expect(startOf(restored, video), Q.of(0));
    expect(startOf(restored, audio), Q.of(0));
    expect(policy(restored), 'preserve');
    expect(seqDur(restored), Q.of(3));
    expect(cueOf(restored, 'cue-left')['text'], 'hello');
    expect(cueOf(restored, 'cue-stay')['text'], 'revised');
    expect(
      Q.fromJson(cueOf(restored, 'cue-stay')['timelineRange']['start']),
      Q.of(2),
    );
    expect(cueOf(restored, 'cue-stay')['anchor']['kind'], 'absolute');
  });

  test('inverting an includeLinks=false MoveClips after a later text edit of the followed cue keeps the new text', () {
    var (p, video, audio) = linkedWithCues();
    final beforeMove = p;
    p = move.change(p, ignoreLinksVideo(video));
    final afterMove = p;
    final hello = CaptionCue.fromProjectJson(
      Map<String, dynamic>.from(cueOf(p, 'cue-left')),
    );
    final stay = CaptionCue.fromProjectJson(
      Map<String, dynamic>.from(cueOf(p, 'cue-stay')),
    );
    p = move.change(
      p,
      SetCaptions(CaptionStore([hello.editText('revised-left'), stay])),
    );
    final changes = documentFieldChanges(
      beforeMove.toJson()..remove('revision'),
      afterMove.toJson()..remove('revision'),
    );
    expect(fieldInvertConflicts(p.toJson(), changes), isFalse);
    final restored = ProjectDocument.fromJson(
      applyFieldInvert(p.toJson(), changes)
        ..['revision'] = p.revision.toString(),
    );
    expect(startOf(restored, video), Q.of(0));
    expect(startOf(restored, audio), Q.of(0));
    expect(policy(restored), 'preserve');
    expect(cueOf(restored, 'cue-left')['text'], 'revised-left');
    expect(
      Q.fromJson(cueOf(restored, 'cue-left')['timelineRange']['start']),
      Q.of(0),
    );
    expect(cueOf(restored, 'cue-stay')['text'], 'stay');
  });

  test('a later second includeLinks=false move of the same host conflicts with invert', () {
    var (p, video, audio) = linkedWithCues();
    final beforeMove = p;
    p = move.change(p, ignoreLinksVideo(video));
    final afterMove = p;
    expect(startOf(p, video), Q.of(1));
    // A second +1s move would slide the followed hello onto the unmoved
    // absolute stay and refuse CAPTION_OVERLAP; official conflict uses a
    // later +0.5s includeLinks=false move that still changes the recorded start.
    p = move.change(p, MoveClips([video], Q.of(1, 2), includeLinks: false));
    expect(startOf(p, video), Q.of(3, 2));
    expect(startOf(p, audio), Q.of(0));
    expect(policy(p), 'allowOutOfSync');
    final changes = documentFieldChanges(
      beforeMove.toJson()..remove('revision'),
      afterMove.toJson()..remove('revision'),
    );
    expect(fieldInvertConflicts(p.toJson(), changes), isTrue);
    assertPure(p, () {
      expect(
        () => applyFieldInvert(p.toJson(), changes),
        code('UNDO_CONFLICT'),
      );
    });
    expect(startOf(p, video), Q.of(3, 2));
    expect(startOf(p, audio), Q.of(0));
    expect(policy(p), 'allowOutOfSync');
    expect(
      Q.fromJson(cueOf(p, 'cue-left')['timelineRange']['start']),
      Q.of(3, 2),
    );
  });
}
