import 'package:studio_contracts/studio_contracts.dart';
import 'package:studio_document/studio_document.dart';
import 'package:test/test.dart';

import 'edit_algebra_test.dart' as algebra;
import 'multi_move_test.dart' as move;
import 'persistent_audio_test.dart' show avFixture;

/// Increment 2.82 official I-005 leftover: the s3 table's 0.02s AV
/// link-offset example (video at 0s, audio at 0.02s). This file does
/// not rewrite the frozen s3 opened-matrix 1/30 s substitute, does not
/// invent a TrimPlanner or new trim modes, does not open video/caption
/// muted/solo on SetTrackState, does not invent OS clipboard,
/// auto-close, or mobile gestures, and does not silently clear other
/// I-005 remainingAcceptance labels. InversePatch kind stays
/// restoreSnapshot. Project user_version stays 9. I-005 stays partial.
Matcher code(String c) =>
    throwsA(isA<StudioException>().having((e) => e.code, 'code', c));

Q startOf(ProjectDocument p, String id) {
  for (final t in p.toJson()['sequences'][0]['tracks']) {
    for (final c in t['items']) {
      if (c['id'] == id && c['source'] != null) {
        return Q.fromJson(c['timelineRange']['start']);
      }
    }
  }
  throw StateError(id);
}

String? audioId(ProjectDocument p) {
  for (final t in p.toJson()['sequences'][0]['tracks']) {
    if (t['kind'] != 'audio') continue;
    for (final c in t['items']) {
      if (c['source'] != null) return c['id'] as String;
    }
  }
  return null;
}

/// Video at 0s, audio at 0.02s, linked, with the current offset recorded.
({ProjectDocument project, String video, String audio}) linkedOffset() {
  var p = avFixture();
  final video = algebra.firstId(p);
  p = move.change(p, ExtractAudioClip(video, 'audio-stream'));
  final audio = audioId(p)!;
  p = move.change(p, MoveClips([audio], Q.of(1, 50), includeLinks: false));
  final groupId = p.toJson()['linkGroups'][0]['id'] as String;
  p = move.change(p, UnlinkAudioVideo(groupId));
  p = move.change(p, LinkAudioVideo(video, audio));
  return (project: p, video: video, audio: audio);
}

void main() {
  test(
    's3 table: video at 0s / audio at 0.02s linked, move +1s yields 1 / 1.02',
    () {
      final linked = linkedOffset();
      expect(startOf(linked.project, linked.video), Q.of(0));
      expect(startOf(linked.project, linked.audio), Q.of(1, 50));
      final moved = move.change(
        linked.project,
        MoveClips([linked.video], Q.of(1)),
      );
      expect(startOf(moved, linked.video), Q.of(1));
      expect(startOf(moved, linked.audio), Q.of(1) + Q.of(1, 50));
    },
  );

  test('force-moving only the video +1s marks allowOutOfSync; unlink keeps both clips and does not relocate', () {
    final linked = linkedOffset();
    final together = move.change(
      linked.project,
      MoveClips([linked.video], Q.of(1)),
    );
    final ignored = move.change(
      together,
      MoveClips([linked.video], Q.of(1), includeLinks: false),
    );
    expect(startOf(ignored, linked.video), Q.of(2));
    expect(startOf(ignored, linked.audio), Q.of(1) + Q.of(1, 50));
    expect(
      (ignored.toJson()['linkGroups'] as List).single['syncPolicy'],
      'allowOutOfSync',
    );
    final unlinked = move.change(
      ignored,
      UnlinkAudioVideo(ignored.toJson()['linkGroups'][0]['id'] as String),
    );
    expect(startOf(unlinked, linked.video), Q.of(2));
    expect(startOf(unlinked, linked.audio), Q.of(1) + Q.of(1, 50));
    expect(unlinked.toJson()['linkGroups'], isEmpty);
  });

  test('moving video by 0.02s is still NOT_ON_FRAME; the leftover is the audio link offset only', () {
    var p = avFixture();
    final video = algebra.firstId(p);
    expect(
      () => move.change(p, MoveClips([video], Q.of(1, 50))),
      code('NOT_ON_FRAME'),
    );
    p = move.change(p, ExtractAudioClip(video, 'audio-stream'));
    final audio = audioId(p)!;
    final offset = move.change(
      p,
      MoveClips([audio], Q.of(1, 50), includeLinks: false),
    );
    expect(startOf(offset, video), Q.of(0));
    expect(startOf(offset, audio), Q.of(1, 50));
  });
}
