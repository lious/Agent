import 'dart:convert';

import 'package:studio_contracts/studio_contracts.dart';
import 'package:studio_document/studio_document.dart';
import 'package:test/test.dart';

import 'edit_algebra_test.dart' as algebra;
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

String content(ProjectDocument p) =>
    contentHash(p.toJson()..remove('revision'));

void assertPure(ProjectDocument before, void Function() action) {
  final start = content(before);
  final raw = jsonEncode(before.toJson());
  action();
  expect(content(before), start);
  expect(jsonEncode(before.toJson()), raw);
}

Map trackOf(ProjectDocument p, String kind) =>
    (p.toJson()['sequences'][0]['tracks'] as List).cast<Map>().singleWhere(
      (t) => t['kind'] == kind,
    );

String? audioClipId(ProjectDocument p) {
  final audio = trackOf(p, 'audio');
  for (final c in audio['items'] as List) {
    if (c['source'] != null) return c['id'] as String;
  }
  return null;
}

/// Independent spanning audio: extract then unlink so default syncLock,
/// not the AV link, is what would pull the audio into an insert ripple.
ProjectDocument unlinkedSpanning() {
  var p = avFixture();
  final a = algebra.firstId(p);
  p = move.change(p, ExtractAudioClip(a, 'audio-stream'));
  p = move.change(
    p,
    UnlinkAudioVideo(p.toJson()['linkGroups'][0]['id'] as String),
  );
  return p;
}

void main() {
  test('SetTrackState can clear syncLock without changing locked, including on a locked track', () {
    var p = unlinkedSpanning();
    final audio = trackOf(p, 'audio')['id'] as String;
    expect(trackOf(p, 'audio')['syncLock'], isTrue);
    expect(trackOf(p, 'audio')['locked'], isFalse);
    p = move.change(p, SetTrackState(audio, syncLock: false));
    expect(trackOf(p, 'audio')['syncLock'], isFalse);
    expect(trackOf(p, 'audio')['locked'], isFalse);
    p = move.change(p, SetTrackState(audio, locked: true));
    expect(trackOf(p, 'audio')['locked'], isTrue);
    expect(trackOf(p, 'audio')['syncLock'], isFalse);
    p = move.change(p, SetTrackState(audio, syncLock: true));
    expect(trackOf(p, 'audio')['syncLock'], isTrue);
    expect(trackOf(p, 'audio')['locked'], isTrue);
    assertPure(p, () {
      expect(
        () => move.change(
          p,
          const SetTrackState('missing-track-id-0001', syncLock: false),
        ),
        code('TRACK_NOT_FOUND'),
      );
      expect(
        () => move.change(p, SetTrackState(audio)),
        code('INVALID_TRACK_STATE'),
      );
    });
  });

  test('a locked syncLock track is SYNC_LOCKED on default insert ripple; clearing syncLock excludes it and does not half-write', () {
    var p = unlinkedSpanning();
    final a = algebra.firstId(p);
    p = move.change(p, SplitClip(a, Q.of(1), 'right'));
    final audioId = audioClipId(p)!;
    final audioTrack = trackOf(p, 'audio')['id'] as String;
    expect(startOf(p, audioId), Q.of(0));
    expect(durationOf(p, audioId), Q.of(3));
    expect(startOf(p, 'right'), Q.of(1));

    p = move.change(p, SetTrackState(audioTrack, locked: true));
    assertPure(p, () {
      expect(
        () => move.change(p, MoveClips(['right'], Q.of(1), mode: 'insert')),
        code('SYNC_LOCKED'),
      );
    });
    expect(startOf(p, 'right'), Q.of(1));
    expect(startOf(p, audioId), Q.of(0));
    expect(durationOf(p, audioId), Q.of(3));

    // Meta-op is allowed on a locked track so the user can clear syncLock
    // and preview again without moving that track.
    p = move.change(p, SetTrackState(audioTrack, syncLock: false));
    expect(trackOf(p, 'audio')['locked'], isTrue);
    expect(trackOf(p, 'audio')['syncLock'], isFalse);
    p = move.change(p, MoveClips(['right'], Q.of(1), mode: 'insert'));
    expect(startOf(p, 'right'), Q.of(2));
    expect(startOf(p, audioId), Q.of(0));
    expect(durationOf(p, audioId), Q.of(3));
    expect(trackOf(p, 'audio')['locked'], isTrue);
  });

  test('an explicit rippleTrackIds list is not auto-expanded to other syncLock tracks', () {
    var p = unlinkedSpanning();
    final a = algebra.firstId(p);
    p = move.change(p, SplitClip(a, Q.of(1), 'right'));
    final audioId = audioClipId(p)!;
    final videoTrack = trackOf(p, 'video')['id'] as String;
    final audioTrack = trackOf(p, 'audio')['id'] as String;
    expect(trackOf(p, 'audio')['syncLock'], isTrue);
    expect(trackOf(p, 'audio')['locked'], isFalse);
    expect(startOf(p, audioId), Q.of(0));
    expect(durationOf(p, audioId), Q.of(3));

    p = move.change(
      p,
      MoveClips(
        ['right'],
        Q.of(1),
        mode: 'insert',
        rippleTrackIds: [videoTrack],
      ),
    );
    expect(startOf(p, 'right'), Q.of(2));
    expect(startOf(p, audioId), Q.of(0));
    expect(durationOf(p, audioId), Q.of(3));
    expect(trackOf(p, 'audio')['id'], audioTrack);
    expect(trackOf(p, 'audio')['syncLock'], isTrue);
  });
}
