import 'dart:convert';

import 'package:studio_contracts/studio_contracts.dart';
import 'package:studio_document/studio_document.dart';
import 'package:test/test.dart';

import 'multi_move_test.dart' as move;
import 'persistent_audio_test.dart' show avFixture;

/// Increment 1.85 official I-006 trim-mode matrix. This file does not rewrite
/// `i006_random_legal_inputs_test.dart` or `nle_random_undo_test.dart`.
Matcher code(String c) =>
    throwsA(isA<StudioException>().having((e) => e.code, 'code', c));

String content(ProjectDocument p) =>
    contentHash(p.toJson()..remove('revision'));

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

Q endOf(ProjectDocument p, String id) => startOf(p, id) + durationOf(p, id);

Q sourceStartOf(ProjectDocument p, String id) =>
    Q.fromJson(clipOf(p, id)['sourceRange']['start']);

Q sourceDurationOf(ProjectDocument p, String id) =>
    Q.fromJson(clipOf(p, id)['sourceRange']['duration']);

Q seqDur(ProjectDocument p) =>
    Q.fromJson(p.toJson()['sequences'][0]['duration']);

Q rateOf(ProjectDocument p, String id) =>
    Q.fromJson(clipOf(p, id)['timeMap']['rate']);

String firstVideoId(ProjectDocument p) {
  for (final t in p.toJson()['sequences'][0]['tracks']) {
    if (t['kind'] != 'video') continue;
    for (final c in t['items']) {
      if (c['source'] != null) return c['id'] as String;
    }
  }
  throw StateError('no video clip');
}

Q streamDuration(ProjectDocument p, String id) {
  final source = clipOf(p, id)['source'] as Map;
  final assets = (p.toJson()['assets'] as List).where(
    (a) => a['id'] == source['id'],
  );
  final streams = (assets.single['streams'] as List).where(
    (s) => s['id'] == source['streamId'],
  );
  return Q.fromJson(streams.single['duration']);
}

Set<String> mediaIds(ProjectDocument p) => {
  for (final c in media(p)) c['id'] as String,
};

Map? audioPartner(ProjectDocument p, String clipId) {
  final group = clipOf(p, clipId)['linkGroupId'];
  if (group == null) return null;
  final matches = [
    for (final c in media(p))
      if (c['id'] != clipId && c['linkGroupId'] == group) c,
  ];
  return matches.length == 1 ? matches.single : null;
}

void assertUnchanged(ProjectDocument p, void Function() body) {
  final before = content(p);
  final raw = jsonEncode(p.toJson());
  body();
  expect(content(p), before);
  expect(jsonEncode(p.toJson()), raw);
}

void assertMapping(ProjectDocument p, String id) {
  expect(clipOf(p, id)['timeMap']['kind'], 'linear');
  final rate = rateOf(p, id);
  expect(sourceDurationOf(p, id), rate * durationOf(p, id));
  expect(sourceStartOf(p, id) >= Q.of(0), isTrue);
  expect(
    sourceStartOf(p, id) + sourceDurationOf(p, id) <= streamDuration(p, id),
    isTrue,
    reason: 'source handle must stay inside the available stream for $id',
  );
}

void assertSourceIdentity(ProjectDocument before, ProjectDocument after) {
  for (final a in before.toJson()['assets'] as List) {
    final b = (after.toJson()['assets'] as List).singleWhere(
      (x) => x['id'] == a['id'],
    );
    expect(b['originalBlobHash'], a['originalBlobHash']);
  }
  for (final id in mediaIds(before).intersection(mediaIds(after))) {
    expect(
      clipOf(after, id)['source']['id'],
      clipOf(before, id)['source']['id'],
    );
    expect(
      clipOf(after, id)['source']['streamId'],
      clipOf(before, id)['source']['streamId'],
    );
  }
}

void assertLinkedTogether(ProjectDocument p, String hostId) {
  final partner = audioPartner(p, hostId);
  expect(
    partner,
    isNotNull,
    reason: 'expected a linked audio partner for $hostId',
  );
  final audioId = partner!['id'] as String;
  expect(startOf(p, audioId), startOf(p, hostId));
  expect(durationOf(p, audioId), durationOf(p, hostId));
  assertMapping(p, hostId);
  assertMapping(p, audioId);
}

ProjectDocument packedTriple({required bool linked}) {
  var p = avFixture();
  final video = firstVideoId(p);
  if (linked) {
    p = move.change(p, ExtractAudioClip(video, 'audio-stream'));
  }
  p = move.change(p, SplitClip(video, Q.of(1), 'i006-mid'));
  p = move.change(p, SplitClip('i006-mid', Q.of(2), 'i006-right'));
  return p;
}

ProjectDocument lockTrack(ProjectDocument p, String kind) {
  final d = jsonDecode(jsonEncode(p.toJson())) as Map<String, dynamic>;
  var found = false;
  for (final t in d['sequences'][0]['tracks']) {
    if (t['kind'] == kind) {
      t['locked'] = true;
      found = true;
    }
  }
  expect(found, isTrue, reason: 'missing $kind track to lock');
  return ProjectDocument.fromJson(d);
}

ProjectDocument lockField(ProjectDocument p, String clipId, String field) {
  final d = jsonDecode(jsonEncode(p.toJson())) as Map<String, dynamic>;
  var found = false;
  for (final t in d['sequences'][0]['tracks']) {
    for (final c in t['items']) {
      if (c['id'] == clipId && c['source'] != null) {
        c['lockedFields'] = [field];
        found = true;
      }
    }
  }
  expect(found, isTrue, reason: 'missing clip $clipId to lock');
  return ProjectDocument.fromJson(d);
}

void refuse(ProjectDocument p, EditOperation op, String expected) {
  assertUnchanged(p, () {
    expect(() => move.change(p, op), code(expected));
  });
}

void main() {
  final frames = Q.of(1, 2); // 15 frames at 30fps

  group('leave-gap TrimClip', () {
    test('in/out shorten keeps neighbors, mapping, and source handles', () {
      final p = packedTriple(linked: false);
      final video = firstVideoId(p);
      final beforeIds = mediaIds(p);
      final midStart = startOf(p, 'i006-mid');
      final midEnd = endOf(p, 'i006-mid');
      final rightStart = startOf(p, 'i006-right');

      final outShort = move.change(
        p,
        TrimClip('i006-mid', 'out', Q.of(0) - frames),
      );
      expect(content(p), content(packedTriple(linked: false)));
      expect(mediaIds(outShort), beforeIds);
      expect(startOf(outShort, 'i006-mid'), midStart);
      expect(durationOf(outShort, 'i006-mid'), Q.of(1) - frames);
      expect(endOf(outShort, 'i006-mid'), midEnd - frames);
      expect(
        startOf(outShort, 'i006-right'),
        rightStart,
        reason: 'leave-gap does not move the neighbor',
      );
      assertMapping(outShort, 'i006-mid');
      assertSourceIdentity(p, outShort);

      final inShort = move.change(p, TrimClip(video, 'in', frames));
      expect(mediaIds(inShort), beforeIds);
      expect(startOf(inShort, video), frames);
      expect(durationOf(inShort, video), Q.of(1) - frames);
      expect(sourceStartOf(inShort, video), frames);
      expect(startOf(inShort, 'i006-mid'), midStart);
      assertMapping(inShort, video);
      assertSourceIdentity(p, inShort);
    });

    test('lengthen uses source handles into a gap and refuses a shortfall or collision', () {
      final p = packedTriple(linked: false);
      final video = firstVideoId(p);
      // Packed mid cannot grow without deleting or colliding with the right.
      refuse(p, TrimClip('i006-mid', 'out', frames), 'COLLISION');
      expect(mediaIds(p), mediaIds(packedTriple(linked: false)));
      // Last remnant has no source tail handle.
      refuse(
        p,
        TrimClip('i006-right', 'out', Q.of(1, 30)),
        'SOURCE_OUT_OF_RANGE',
      );
      // First remnant has no source head handle.
      refuse(p, TrimClip(video, 'in', Q.of(-1, 30)), 'INVALID_RANGE');

      final gapped = move.change(
        p,
        TrimClip('i006-mid', 'out', Q.of(0) - frames),
      );
      final grown = move.change(gapped, TrimClip('i006-mid', 'out', frames));
      expect(durationOf(grown, 'i006-mid'), Q.of(1));
      expect(sourceDurationOf(grown, 'i006-mid'), Q.of(1));
      expect(startOf(grown, 'i006-right'), Q.of(2));
      assertMapping(grown, 'i006-mid');
      assertSourceIdentity(gapped, grown);
    });

    test('linked AV stays whole-group; a locked partner or host track is FIELD_LOCKED', () {
      final p = packedTriple(linked: true);
      final video = firstVideoId(p);
      final trimmed = move.change(
        p,
        TrimClip('i006-mid', 'out', Q.of(0) - frames),
      );
      expect(content(p), content(packedTriple(linked: true)));
      assertLinkedTogether(trimmed, 'i006-mid');
      assertLinkedTogether(trimmed, video);
      assertLinkedTogether(trimmed, 'i006-right');
      expect(startOf(trimmed, 'i006-right'), Q.of(2));
      expect(mediaIds(trimmed).containsAll(mediaIds(p)), isTrue);

      refuse(
        lockTrack(p, 'audio'),
        TrimClip('i006-mid', 'out', Q.of(0) - frames),
        'FIELD_LOCKED',
      );
      refuse(
        lockTrack(p, 'video'),
        TrimClip('i006-mid', 'out', Q.of(0) - frames),
        'FIELD_LOCKED',
      );
      refuse(
        lockField(p, 'i006-mid', 'sourceRange'),
        TrimClip('i006-mid', 'out', Q.of(0) - frames),
        'FIELD_LOCKED',
      );
    });
  });

  group('RippleTrimClip', () {
    test(
      'in/out shorten and lengthen conserve mapping; handle shortfall refuses',
      () {
        final p = packedTriple(linked: false);
        final video = firstVideoId(p);
        final beforeIds = mediaIds(p);

        final outShort = move.change(
          p,
          RippleTrimClip('i006-mid', 'out', Q.of(0) - frames),
        );
        expect(mediaIds(outShort).containsAll(beforeIds), isTrue);
        expect(durationOf(outShort, 'i006-mid'), Q.of(1) - frames);
        expect(
          startOf(outShort, 'i006-right'),
          Q.of(2) - frames,
          reason: 'ripple closes the vacated tail',
        );
        expect(seqDur(outShort), seqDur(p) - frames);
        assertMapping(outShort, 'i006-mid');
        assertSourceIdentity(p, outShort);

        final inShort = move.change(p, RippleTrimClip(video, 'in', frames));
        expect(
          startOf(inShort, video),
          Q.of(0),
          reason: 'ripple in pins timeline start',
        );
        expect(durationOf(inShort, video), Q.of(1) - frames);
        expect(sourceStartOf(inShort, video), frames);
        expect(startOf(inShort, 'i006-mid'), Q.of(1) - frames);
        expect(seqDur(inShort), seqDur(p) - frames);
        assertMapping(inShort, video);

        final outLong = move.change(p, RippleTrimClip(video, 'out', frames));
        expect(durationOf(outLong, video), Q.of(1) + frames);
        expect(startOf(outLong, 'i006-mid'), Q.of(1) + frames);
        expect(seqDur(outLong), seqDur(p) + frames);
        assertMapping(outLong, video);

        final inLong = move.change(
          p,
          RippleTrimClip('i006-mid', 'in', Q.of(0) - frames),
        );
        expect(startOf(inLong, 'i006-mid'), Q.of(1));
        expect(durationOf(inLong, 'i006-mid'), Q.of(1) + frames);
        expect(sourceStartOf(inLong, 'i006-mid'), Q.of(1) - frames);
        expect(startOf(inLong, 'i006-right'), Q.of(2) + frames);
        assertMapping(inLong, 'i006-mid');

        refuse(
          p,
          RippleTrimClip('i006-right', 'out', Q.of(1, 30)),
          'SOURCE_OUT_OF_RANGE',
        );
        refuse(
          p,
          RippleTrimClip(video, 'in', Q.of(-1, 30)),
          'SOURCE_OUT_OF_RANGE',
        );
      },
    );

    test('linked AV stays whole-group; a locked partner or host track is FIELD_LOCKED', () {
      final p = packedTriple(linked: true);
      final trimmed = move.change(
        p,
        RippleTrimClip('i006-mid', 'out', Q.of(0) - frames),
      );
      assertLinkedTogether(trimmed, 'i006-mid');
      assertLinkedTogether(trimmed, 'i006-right');
      expect(startOf(trimmed, 'i006-right'), Q.of(2) - frames);
      expect(mediaIds(trimmed).containsAll(mediaIds(p)), isTrue);

      refuse(
        lockTrack(p, 'audio'),
        RippleTrimClip('i006-mid', 'out', Q.of(0) - frames),
        'FIELD_LOCKED',
      );
      refuse(
        lockTrack(p, 'video'),
        RippleTrimClip('i006-mid', 'out', Q.of(0) - frames),
        'FIELD_LOCKED',
      );
      refuse(
        lockField(p, 'i006-mid', 'sourceRange'),
        RippleTrimClip('i006-mid', 'out', Q.of(0) - frames),
        'FIELD_LOCKED',
      );
    });
  });

  group('SlipClip', () {
    test('source handles, linked members, and locked tracks or fields', () {
      final solo = packedTriple(linked: false);
      final slipped = move.change(solo, SlipClip('i006-mid', frames));
      expect(startOf(slipped, 'i006-mid'), Q.of(1));
      expect(durationOf(slipped, 'i006-mid'), Q.of(1));
      expect(sourceStartOf(slipped, 'i006-mid'), Q.of(1) + frames);
      expect(seqDur(slipped), seqDur(solo));
      assertMapping(slipped, 'i006-mid');
      expect(mediaIds(slipped), mediaIds(solo));
      refuse(solo, SlipClip('i006-right', Q.of(1, 30)), 'SOURCE_OUT_OF_RANGE');
      refuse(solo, SlipClip(firstVideoId(solo), Q.of(-1, 30)), 'INVALID_RANGE');

      final p = packedTriple(linked: true);
      final linked = move.change(p, SlipClip('i006-mid', frames));
      assertLinkedTogether(linked, 'i006-mid');
      expect(sourceStartOf(linked, 'i006-mid'), Q.of(1) + frames);
      expect(
        sourceStartOf(
          linked,
          audioPartner(linked, 'i006-mid')!['id'] as String,
        ),
        Q.of(1) + frames,
      );
      expect(startOf(linked, 'i006-mid'), Q.of(1));

      refuse(
        lockTrack(p, 'audio'),
        SlipClip('i006-mid', frames),
        'FIELD_LOCKED',
      );
      refuse(
        lockTrack(p, 'video'),
        SlipClip('i006-mid', frames),
        'FIELD_LOCKED',
      );
      refuse(
        lockField(p, 'i006-mid', 'sourceRange'),
        SlipClip('i006-mid', frames),
        'FIELD_LOCKED',
      );
    });
  });

  group('RollCut', () {
    test('source handles, linked members, and locked tracks or fields', () {
      final solo = packedTriple(linked: false);
      final video = firstVideoId(solo);
      final rolled = move.change(solo, RollCut(video, 'i006-mid', frames));
      expect(startOf(rolled, video), Q.of(0));
      expect(durationOf(rolled, video), Q.of(1) + frames);
      expect(startOf(rolled, 'i006-mid'), Q.of(1) + frames);
      expect(durationOf(rolled, 'i006-mid'), Q.of(1) - frames);
      expect(endOf(rolled, 'i006-mid'), Q.of(2));
      expect(seqDur(rolled), seqDur(solo));
      assertMapping(rolled, video);
      assertMapping(rolled, 'i006-mid');
      expect(mediaIds(rolled), mediaIds(solo));
      // Mid still has a 1s source tail, so +15 frames on mid/right is legal.
      // Slip mid first so only 0.1s of tail remains; +0.2s then exceeds the stream.
      final tightMid = move.change(solo, SlipClip('i006-mid', Q.of(9, 10)));
      refuse(
        tightMid,
        RollCut('i006-mid', 'i006-right', Q.of(1, 5)),
        'SOURCE_OUT_OF_RANGE',
      );
      refuse(solo, RollCut(video, 'i006-right', frames), 'NOT_ADJACENT');

      final p = packedTriple(linked: true);
      final linked = move.change(
        p,
        RollCut(firstVideoId(p), 'i006-mid', frames),
      );
      assertLinkedTogether(linked, firstVideoId(linked));
      assertLinkedTogether(linked, 'i006-mid');
      expect(endOf(linked, 'i006-mid'), Q.of(2));

      refuse(
        lockTrack(p, 'audio'),
        RollCut(firstVideoId(p), 'i006-mid', frames),
        'FIELD_LOCKED',
      );
      refuse(
        lockTrack(p, 'video'),
        RollCut(firstVideoId(p), 'i006-mid', frames),
        'FIELD_LOCKED',
      );
      refuse(
        lockField(p, firstVideoId(p), 'sourceRange'),
        RollCut(firstVideoId(p), 'i006-mid', frames),
        'FIELD_LOCKED',
      );
    });
  });

  group('SlideClip', () {
    test('source handles, linked members, and locked tracks or fields', () {
      final solo = packedTriple(linked: false);
      final video = firstVideoId(solo);
      final slid = move.change(
        solo,
        SlideClip(video, 'i006-mid', 'i006-right', frames),
      );
      expect(startOf(slid, video), Q.of(0));
      expect(durationOf(slid, video), Q.of(1) + frames);
      expect(startOf(slid, 'i006-mid'), Q.of(1) + frames);
      expect(durationOf(slid, 'i006-mid'), Q.of(1));
      expect(sourceStartOf(slid, 'i006-mid'), Q.of(1));
      expect(startOf(slid, 'i006-right'), Q.of(2) + frames);
      expect(durationOf(slid, 'i006-right'), Q.of(1) - frames);
      expect(endOf(slid, 'i006-right'), Q.of(3));
      expect(seqDur(slid), seqDur(solo));
      assertMapping(slid, video);
      assertMapping(slid, 'i006-mid');
      assertMapping(slid, 'i006-right');
      expect(mediaIds(slid), mediaIds(solo));
      // +1s zeros the right remnant before the left source tail runs out.
      refuse(
        solo,
        SlideClip(video, 'i006-mid', 'i006-right', Q.of(1)),
        'INVALID_RANGE',
      );
      // Slip the left remnant so only 0.1s of tail remains; +0.2s then exceeds the stream.
      final tightLeft = move.change(solo, SlipClip(video, Q.of(19, 10)));
      refuse(
        tightLeft,
        SlideClip(video, 'i006-mid', 'i006-right', Q.of(1, 5)),
        'SOURCE_OUT_OF_RANGE',
      );
      refuse(
        solo,
        SlideClip(video, 'i006-right', 'i006-mid', frames),
        'NOT_ADJACENT',
      );

      final p = packedTriple(linked: true);
      final linked = move.change(
        p,
        SlideClip(firstVideoId(p), 'i006-mid', 'i006-right', frames),
      );
      assertLinkedTogether(linked, firstVideoId(linked));
      assertLinkedTogether(linked, 'i006-mid');
      assertLinkedTogether(linked, 'i006-right');
      expect(endOf(linked, 'i006-right'), Q.of(3));

      refuse(
        lockTrack(p, 'audio'),
        SlideClip(firstVideoId(p), 'i006-mid', 'i006-right', frames),
        'FIELD_LOCKED',
      );
      refuse(
        lockTrack(p, 'video'),
        SlideClip(firstVideoId(p), 'i006-mid', 'i006-right', frames),
        'FIELD_LOCKED',
      );
      refuse(
        lockField(p, firstVideoId(p), 'sourceRange'),
        SlideClip(firstVideoId(p), 'i006-mid', 'i006-right', frames),
        'FIELD_LOCKED',
      );
    });
  });
}
