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

(ProjectDocument, String, String) linked() {
  var p = avFixture();
  final video = media(p).single['id'] as String;
  p = move.change(p, ExtractAudioClip(video, 'audio-stream'));
  final audio = media(p).singleWhere((c) => c['id'] != video)['id'] as String;
  return (p, video, audio);
}

void main() {
  test('default includeLinks still moves both partners and keeps preserve', () {
    final (p, video, audio) = linked();
    final out = move.change(p, MoveClips([video], Q.of(1, 2)));
    expect(start(out, video), Q.of(1, 2));
    expect(start(out, audio), Q.of(1, 2));
    expect(policy(out), 'preserve');
    expect(memberOffset(out, audio), memberOffset(p, audio));
    expect(seqDur(out), Q.of(7, 2));
  });

  test('includeLinks=false moves only the explicit clip, marks allowOutOfSync, keeps offset', () {
    final (p, video, audio) = linked();
    final stored = memberOffset(p, audio);
    expect(stored, Q.of(0));
    final out = move.change(
      p,
      MoveClips([video], Q.of(1, 2), includeLinks: false),
    );
    expect(start(out, video), Q.of(1, 2));
    expect(dur(out, video), Q.of(3));
    expect(start(out, audio), Q.of(0));
    expect(dur(out, audio), Q.of(3));
    expect(policy(out), 'allowOutOfSync');
    expect(memberOffset(out, audio), stored);
    expect(out.toJson()['linkGroups'], hasLength(1));
    expect(p.toJson()['assets'], out.toJson()['assets']);
  });

  test('moving every member with includeLinks=false does not mark the link out of sync', () {
    final (p, video, audio) = linked();
    final out = move.change(
      p,
      MoveClips([video, audio], Q.of(1, 2), includeLinks: false),
    );
    expect(start(out, video), Q.of(1, 2));
    expect(start(out, audio), Q.of(1, 2));
    expect(policy(out), 'preserve');
    expect(memberOffset(out, audio), memberOffset(p, audio));
  });

  test(
    'locked unmoved partner does not refuse; locked selected member still does',
    () {
      final (p, video, audio) = linked();
      final d = p.toJson();
      final audioTrack = clip(p, audio)['trackId'];
      for (final t in d['sequences'][0]['tracks']) {
        if (t['id'] == audioTrack) {
          t['locked'] = true;
        }
      }
      final lockedAudio = ProjectDocument.fromJson(d);
      expect(
        () => move.change(lockedAudio, MoveClips([video], Q.of(1, 2))),
        code('FIELD_LOCKED'),
      );
      final ignored = move.change(
        lockedAudio,
        MoveClips([video], Q.of(1, 2), includeLinks: false),
      );
      expect(start(ignored, video), Q.of(1, 2));
      expect(start(ignored, audio), Q.of(0));
      expect(policy(ignored), 'allowOutOfSync');
      expect(lockedAudio.hash, ProjectDocument.fromJson(d).hash);
      final d2 = p.toJson();
      d2['sequences'][0]['tracks'][0]['locked'] = true;
      final lockedVideo = ProjectDocument.fromJson(d2);
      expect(
        () => move.change(
          lockedVideo,
          MoveClips([video], Q.of(1, 2), includeLinks: false),
        ),
        code('FIELD_LOCKED'),
      );
      expect(lockedVideo.hash, ProjectDocument.fromJson(d2).hash);
    },
  );

  test(
    'insert and overwrite stay distinct; insert still leaves a source gap',
    () {
      final (p, video, audio) = linked();
      final inserted = move.change(
        p,
        MoveClips([video], Q.of(3, 2), mode: 'insert', includeLinks: false),
      );
      expect(start(inserted, video), Q.of(3, 2));
      expect(start(inserted, audio), Q.of(0));
      expect(policy(inserted), 'allowOutOfSync');
      expect(seqDur(inserted), greaterThan(seqDur(p)));
      final overwritten = move.change(
        p,
        MoveClips([video], Q.of(1, 2), mode: 'overwrite', includeLinks: false),
      );
      expect(start(overwritten, video), Q.of(1, 2));
      expect(start(overwritten, audio), Q.of(0));
      expect(policy(overwritten), 'allowOutOfSync');
    },
  );

  test(
    'includeLinks=false does not pull unselected selection-group members',
    () {
      var p = f.three();
      p = move.change(p, MoveClips(['c'], Q.of(1, 2)));
      expect(start(p, 'c'), Q.of(5, 2));
      p = move.change(p, GroupClips(['b', 'c']));
      expect(p.toJson()['selectionGroups'], hasLength(1));
      final withGroup = move.change(p, MoveClips(['b'], Q.of(1, 2)));
      expect(start(withGroup, 'b'), Q.of(3, 2));
      expect(start(withGroup, 'c'), Q.of(3));
      final ignored = move.change(
        p,
        MoveClips(['b'], Q.of(1, 2), includeLinks: false),
      );
      expect(start(ignored, 'b'), Q.of(3, 2));
      expect(start(ignored, 'c'), Q.of(5, 2));
      expect(ignored.toJson()['selectionGroups'], hasLength(1));
      expect(clip(ignored, 'b')['selectionGroupId'], isNotNull);
      expect(clip(ignored, 'c')['selectionGroupId'], isNotNull);
    },
  );
}
