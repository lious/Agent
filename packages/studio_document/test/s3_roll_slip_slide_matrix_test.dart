import 'dart:convert';

import 'package:studio_contracts/studio_contracts.dart';
import 'package:studio_document/studio_document.dart';
import 'package:test/test.dart';

import 'edit_algebra_test.dart' as algebra;
import 'multi_move_test.dart' as move;
import 'persistent_audio_test.dart' show avFixture;

/// Increment 1.87 official s3 roll/slip/slide rows on the same scaled A/B/C
/// fixture as Increment 1.39. This file does not rewrite
/// `s3_opened_matrix_test.dart`, `nle_random_undo_test.dart`,
/// `i005_locked_members_negative_range_test.dart`, or the I-006 1.84/1.85 suites.
///
/// One table frame is divided by 5 so the 450-frame sequence fits the 3-second
/// local video and stays on the 30 fps grid: f(15) = 1/10 s = 3/30.
Q f(int frames) => Q.of(frames, 150);

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

Q endOf(ProjectDocument p, String id) => startOf(p, id) + durOf(p, id);

Q sourceStartOf(ProjectDocument p, String id) =>
    Q.fromJson(clipOf(p, id)['sourceRange']['start']);

Q sourceDurOf(ProjectDocument p, String id) =>
    Q.fromJson(clipOf(p, id)['sourceRange']['duration']);

Q seqDur(ProjectDocument p) =>
    Q.fromJson(p.toJson()['sequences'][0]['duration']);

String content(ProjectDocument p) =>
    contentHash(p.toJson()..remove('revision'));

String videoA(ProjectDocument p) =>
    media(p)
            .where(
              (c) =>
                  c['trackId'] == p.toJson()['sequences'][0]['tracks'][0]['id'],
            )
            .reduce(
              (a, b) =>
                  Q.fromJson(a['timelineRange']['start']) <=
                      Q.fromJson(b['timelineRange']['start'])
                  ? a
                  : b,
            )['id']
        as String;

void assertPure(ProjectDocument before, void Function() action) {
  final start = content(before);
  final raw = jsonEncode(before.toJson());
  action();
  expect(content(before), start);
  expect(jsonEncode(before.toJson()), raw);
}

void refuse(ProjectDocument p, EditOperation op, String expected) {
  assertPure(p, () {
    expect(() => move.change(p, op), code(expected));
  });
}

void assertAssetsUnchanged(ProjectDocument before, ProjectDocument after) {
  expect(after.toJson()['assets'], before.toJson()['assets']);
}

ProjectDocument plantS3Sources(
  ProjectDocument p,
  String a,
  String b,
  String c,
) {
  final d = jsonDecode(jsonEncode(p.toJson())) as Map<String, dynamic>;
  void plant(String id, Q start) {
    for (final t in d['sequences'][0]['tracks']) {
      for (final item in t['items']) {
        if (item['id'] == id) {
          item['sourceRange'] = {
            'start': start.toJson(),
            'duration': Q.of(1).toJson(),
          };
        }
      }
    }
  }

  plant(a, f(30));
  plant(b, f(60));
  plant(c, f(0));
  return ProjectDocument.fromJson(d);
}

/// Scaled s3 A/B/C: A[0,1) src[0.2,1.2), B[1,2) src[0.4,1.4), C[2,3) src[0,1).
ProjectDocument s3Abc({bool linked = false}) {
  var p = avFixture();
  final a = algebra.firstId(p);
  if (linked) {
    p = move.change(p, ExtractAudioClip(a, 'audio-stream'));
  }
  p = move.change(p, SplitClip(a, Q.of(1), 's3-b'));
  p = move.change(p, SplitClip('s3-b', Q.of(2), 's3-c'));
  p = plantS3Sources(p, a, 's3-b', 's3-c');
  if (linked) {
    // Linked audio partners keep the same planted source windows at rate 1.
    final d = jsonDecode(jsonEncode(p.toJson())) as Map<String, dynamic>;
    final byVideo = {for (final c in media(p)) c['id'] as String: c};
    for (final t in d['sequences'][0]['tracks']) {
      if (t['kind'] != 'audio') continue;
      for (final item in t['items']) {
        if (item['source'] == null) continue;
        final group = item['linkGroupId'];
        final host = media(p)
            .where((c) => c['id'] != item['id'] && c['linkGroupId'] == group);
        if (host.length != 1) continue;
        item['sourceRange'] = jsonDecode(
          jsonEncode(byVideo[host.single['id']]!['sourceRange']),
        );
      }
    }
    p = ProjectDocument.fromJson(d);
  }
  return p;
}

Map? audioPartner(ProjectDocument p, String clipId) {
  final group = clipOf(p, clipId)['linkGroupId'];
  if (group == null) return null;
  final matches = [
    for (final c in media(p))
      if (c['id'] != clipId && c['linkGroupId'] == group) c,
  ];
  return matches.length == 1 ? matches.single : null;
}

ProjectDocument lockTrack(ProjectDocument p, String kind) {
  final d = jsonDecode(jsonEncode(p.toJson())) as Map<String, dynamic>;
  for (final t in d['sequences'][0]['tracks']) {
    if (t['kind'] == kind) t['locked'] = true;
  }
  return ProjectDocument.fromJson(d);
}

ProjectDocument lockField(ProjectDocument p, String clipId, String field) {
  final d = jsonDecode(jsonEncode(p.toJson())) as Map<String, dynamic>;
  for (final t in d['sequences'][0]['tracks']) {
    for (final c in t['items']) {
      if (c['id'] == clipId && c['source'] != null) {
        c['lockedFields'] = [field];
      }
    }
  }
  return ProjectDocument.fromJson(d);
}

void main() {
  test('s3 roll: A/B cut 150→165 keeps outer ends and C; shortfall and non-adjacent refuse', () {
    final p = s3Abc();
    final a = videoA(p);
    expect(seqDur(p), f(450));
    expect(sourceStartOf(p, a), f(30));
    expect(sourceStartOf(p, 's3-b'), f(60));

    final rolled = move.change(p, RollCut(a, 's3-b', f(15)));
    expect(content(p), content(s3Abc()));
    expect(startOf(rolled, a), Q.of(0));
    expect(durOf(rolled, a), f(165));
    expect(sourceStartOf(rolled, a), f(30));
    expect(sourceDurOf(rolled, a), f(165));
    expect(startOf(rolled, 's3-b'), f(165));
    expect(durOf(rolled, 's3-b'), f(135));
    expect(sourceStartOf(rolled, 's3-b'), f(75));
    expect(sourceDurOf(rolled, 's3-b'), f(135));
    expect(startOf(rolled, 's3-c'), f(300));
    expect(durOf(rolled, 's3-c'), f(150));
    expect(sourceStartOf(rolled, 's3-c'), f(0));
    expect(seqDur(rolled), f(450));
    expect(endOf(rolled, 's3-b'), f(300));
    assertAssetsUnchanged(p, rolled);

    final linked = s3Abc(linked: true);
    final linkedA = videoA(linked);
    final linkedRolled = move.change(linked, RollCut(linkedA, 's3-b', f(15)));
    final partnerB = audioPartner(linkedRolled, 's3-b');
    expect(partnerB, isNotNull);
    expect(startOf(linkedRolled, partnerB!['id'] as String), f(165));
    expect(durOf(linkedRolled, partnerB['id'] as String), f(135));
    expect(sourceStartOf(linkedRolled, partnerB['id'] as String), f(75));

    refuse(p, RollCut(a, 's3-c', f(15)), 'NOT_ADJACENT');
    refuse(p, RollCut(a, 's3-b', Q.of(0) - f(75)), 'INVALID_RANGE');
    refuse(lockTrack(p, 'video'), RollCut(a, 's3-b', f(15)), 'FIELD_LOCKED');
    refuse(
      lockField(p, a, 'sourceRange'),
      RollCut(a, 's3-b', f(15)),
      'FIELD_LOCKED',
    );
  });

  test('s3 slip: B +15 source frames keeps timeline, A/C, and duration; tail shortfall refuses', () {
    final p = s3Abc();
    final a = videoA(p);
    final slipped = move.change(p, SlipClip('s3-b', f(15)));
    expect(content(p), content(s3Abc()));
    expect(startOf(slipped, 's3-b'), f(150));
    expect(durOf(slipped, 's3-b'), f(150));
    expect(sourceStartOf(slipped, 's3-b'), f(75));
    expect(sourceDurOf(slipped, 's3-b'), f(150));
    expect(startOf(slipped, a), Q.of(0));
    expect(durOf(slipped, a), f(150));
    expect(sourceStartOf(slipped, a), f(30));
    expect(startOf(slipped, 's3-c'), f(300));
    expect(sourceStartOf(slipped, 's3-c'), f(0));
    expect(seqDur(slipped), f(450));
    assertAssetsUnchanged(p, slipped);

    final linked = s3Abc(linked: true);
    final linkedSlipped = move.change(linked, SlipClip('s3-b', f(15)));
    final partner = audioPartner(linkedSlipped, 's3-b')!;
    expect(startOf(linkedSlipped, partner['id'] as String), f(150));
    expect(sourceStartOf(linkedSlipped, partner['id'] as String), f(75));

    refuse(p, SlipClip('s3-b', Q.of(2)), 'SOURCE_OUT_OF_RANGE');
    refuse(p, SlipClip('s3-b', Q.of(0) - f(75)), 'INVALID_RANGE');
    refuse(lockTrack(p, 'video'), SlipClip('s3-b', f(15)), 'FIELD_LOCKED');
    refuse(
      lockField(p, 's3-b', 'sourceRange'),
      SlipClip('s3-b', f(15)),
      'FIELD_LOCKED',
    );
  });

  test('s3 slide: B +15 keeps left start, C outer end, and duration; non-adjacent refuses', () {
    final p = s3Abc();
    final a = videoA(p);
    final slid = move.change(p, SlideClip(a, 's3-b', 's3-c', f(15)));
    expect(content(p), content(s3Abc()));
    expect(startOf(slid, a), Q.of(0));
    expect(durOf(slid, a), f(165));
    expect(sourceStartOf(slid, a), f(30));
    expect(sourceDurOf(slid, a), f(165));
    expect(startOf(slid, 's3-b'), f(165));
    expect(durOf(slid, 's3-b'), f(150));
    expect(sourceStartOf(slid, 's3-b'), f(60));
    expect(sourceDurOf(slid, 's3-b'), f(150));
    expect(startOf(slid, 's3-c'), f(315));
    expect(durOf(slid, 's3-c'), f(135));
    expect(sourceStartOf(slid, 's3-c'), f(15));
    expect(sourceDurOf(slid, 's3-c'), f(135));
    expect(endOf(slid, 's3-c'), f(450));
    expect(seqDur(slid), f(450));
    assertAssetsUnchanged(p, slid);

    final linked = s3Abc(linked: true);
    final linkedA = videoA(linked);
    final linkedSlid = move.change(
      linked,
      SlideClip(linkedA, 's3-b', 's3-c', f(15)),
    );
    final partnerC = audioPartner(linkedSlid, 's3-c')!;
    expect(startOf(linkedSlid, partnerC['id'] as String), f(315));
    expect(sourceStartOf(linkedSlid, partnerC['id'] as String), f(15));
    expect(sourceStartOf(linkedSlid, 's3-b'), f(60));

    refuse(p, SlideClip(a, 's3-c', 's3-b', f(15)), 'NOT_ADJACENT');
    refuse(p, SlideClip(a, 's3-b', 's3-c', f(150)), 'INVALID_RANGE');
    refuse(
      lockTrack(p, 'video'),
      SlideClip(a, 's3-b', 's3-c', f(15)),
      'FIELD_LOCKED',
    );
    refuse(
      lockField(p, a, 'sourceRange'),
      SlideClip(a, 's3-b', 's3-c', f(15)),
      'FIELD_LOCKED',
    );
  });
}
