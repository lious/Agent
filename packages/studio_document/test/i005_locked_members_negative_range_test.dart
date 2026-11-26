import 'dart:convert';

import 'package:studio_contracts/studio_contracts.dart';
import 'package:studio_document/studio_document.dart';
import 'package:test/test.dart';

import 'multi_move_test.dart' as move;
import 'persistent_audio_test.dart' show avFixture;

/// Increment 1.86 official I-005 matrix for “锁定成员与负区间整组拒”.
/// This file does not rewrite `nle_random_undo_test.dart`,
/// `s3_opened_matrix_test.dart`, `i006_random_legal_inputs_test.dart`,
/// or `i006_trim_mode_matrix_test.dart`.
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

String firstVideoId(ProjectDocument p) {
  for (final t in p.toJson()['sequences'][0]['tracks']) {
    if (t['kind'] != 'video') continue;
    for (final c in t['items']) {
      if (c['source'] != null) return c['id'] as String;
    }
  }
  throw StateError('no video clip');
}

void assertUnchanged(ProjectDocument p, void Function() body) {
  final before = content(p);
  final raw = jsonEncode(p.toJson());
  body();
  expect(content(p), before);
  expect(jsonEncode(p.toJson()), raw);
}

void refuse(ProjectDocument p, Object action, String expected) {
  assertUnchanged(p, () {
    expect(() {
      if (action is EditOperation) {
        move.change(p, action);
      } else if (action is void Function()) {
        action();
      } else {
        throw StateError('unsupported refusal action');
      }
    }, code(expected));
  });
}

ProjectDocument baseline({required bool linked, bool split = false}) {
  var p = avFixture();
  final video = firstVideoId(p);
  if (linked) {
    p = move.change(p, ExtractAudioClip(video, 'audio-stream'));
  }
  if (split) {
    p = move.change(p, SplitClip(video, Q.of(1), 'i005-right'));
  }
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

void main() {
  group('MoveClips', () {
    test('a locked member or negative start refuses the whole group', () {
      final solo = baseline(linked: false, split: true);
      final left = firstVideoId(solo);
      refuse(solo, MoveClips([left], Q.of(-1)), 'NEGATIVE_TIMELINE_START');
      refuse(
        solo,
        MoveClips([left], Q.of(-1), mode: 'overwrite'),
        'NEGATIVE_TIMELINE_START',
      );
      refuse(
        solo,
        MoveClips([left], Q.of(-1), mode: 'insert'),
        'NEGATIVE_TIMELINE_START',
      );
      refuse(
        lockTrack(solo, 'video'),
        MoveClips([left], Q.of(1, 30)),
        'FIELD_LOCKED',
      );
      refuse(
        lockField(solo, left, 'timelineRange'),
        MoveClips([left], Q.of(1, 30)),
        'FIELD_LOCKED',
      );
      // One locked selection member refuses the whole multi-move.
      refuse(
        lockField(solo, 'i005-right', 'timelineRange'),
        MoveClips([left, 'i005-right'], Q.of(1, 30)),
        'FIELD_LOCKED',
      );

      final linked = baseline(linked: true);
      final video = firstVideoId(linked);
      refuse(
        lockTrack(linked, 'audio'),
        MoveClips([video], Q.of(1, 30)),
        'FIELD_LOCKED',
      );
      refuse(
        lockTrack(linked, 'video'),
        MoveClips([video], Q.of(1, 30)),
        'FIELD_LOCKED',
      );
      refuse(
        lockField(linked, video, 'timelineRange'),
        MoveClips([video], Q.of(1, 30), includeLinks: true),
        'FIELD_LOCKED',
      );
    });
  });

  group('SplitClip and leave-gap TrimClip', () {
    test('a locked member or negative range refuses the whole command', () {
      final solo = baseline(linked: false);
      final video = firstVideoId(solo);
      refuse(solo, SplitClip(video, Q.of(-1), 'i005-neg'), 'SPLIT_BOUNDARY');
      refuse(solo, TrimClip(video, 'in', Q.of(-1, 30)), 'INVALID_RANGE');
      refuse(
        lockTrack(solo, 'video'),
        SplitClip(video, Q.of(1), 'i005-cut'),
        'FIELD_LOCKED',
      );
      refuse(
        lockField(solo, video, 'sourceRange'),
        SplitClip(video, Q.of(1), 'i005-cut'),
        'FIELD_LOCKED',
      );
      refuse(
        lockTrack(solo, 'video'),
        TrimClip(video, 'out', Q.of(-1, 30)),
        'FIELD_LOCKED',
      );
      refuse(
        lockField(solo, video, 'sourceRange'),
        TrimClip(video, 'in', Q.of(1, 30)),
        'FIELD_LOCKED',
      );

      final linked = baseline(linked: true);
      final host = firstVideoId(linked);
      refuse(
        lockTrack(linked, 'audio'),
        SplitClip(host, Q.of(1), 'i005-cut'),
        'FIELD_LOCKED',
      );
      refuse(
        lockTrack(linked, 'audio'),
        TrimClip(host, 'out', Q.of(-1, 30)),
        'FIELD_LOCKED',
      );
    });
  });

  group('LiftClips and leave-gap DeleteClip', () {
    test('a locked member refuses the whole lift or leave-gap delete', () {
      final solo = baseline(linked: false, split: true);
      final left = firstVideoId(solo);
      refuse(lockTrack(solo, 'video'), LiftClips([left]), 'FIELD_LOCKED');
      refuse(
        lockField(solo, 'i005-right', 'timelineRange'),
        LiftClips(['i005-right']),
        'FIELD_LOCKED',
      );
      refuse(
        lockTrack(solo, 'video'),
        const DeleteClip('i005-right'),
        'FIELD_LOCKED',
      );

      final linked = baseline(linked: true, split: true);
      refuse(
        lockTrack(linked, 'audio'),
        LiftClips([firstVideoId(linked)]),
        'FIELD_LOCKED',
      );
      refuse(
        lockTrack(linked, 'audio'),
        const DeleteClip('i005-right'),
        'FIELD_LOCKED',
      );
    });
  });

  group('RippleDeleteClips and RippleTrimClip', () {
    test('a locked member or negative range refuses the whole ripple', () {
      final solo = baseline(linked: false, split: true);
      final left = firstVideoId(solo);
      refuse(solo, () {
        RippleDeleteClips(const [], range: TimeRange(Q.of(-1), Q.of(1, 30)));
      }, 'NEGATIVE_TIMELINE_START');
      refuse(
        lockTrack(solo, 'video'),
        RippleDeleteClips([left]),
        'FIELD_LOCKED',
      );
      refuse(
        lockField(solo, 'i005-right', 'timelineRange'),
        RippleDeleteClips(['i005-right']),
        'FIELD_LOCKED',
      );
      refuse(
        lockTrack(solo, 'video'),
        RippleTrimClip('i005-right', 'out', Q.of(-1, 30)),
        'FIELD_LOCKED',
      );

      final linked = baseline(linked: true, split: true);
      refuse(
        lockTrack(linked, 'audio'),
        RippleDeleteClips([firstVideoId(linked)]),
        'FIELD_LOCKED',
      );
      refuse(
        lockTrack(linked, 'audio'),
        RippleTrimClip('i005-right', 'out', Q.of(-1, 30)),
        'FIELD_LOCKED',
      );
    });
  });

  group('PasteClips reject/insert/overwrite', () {
    test(
      'a locked destination or negative paste origin refuses without writing',
      () {
        final p = baseline(linked: false, split: true);
        final left = firstVideoId(p);
        final payload = buildClipboard(p, [left]);
        refuse(p, () {
          PasteClips(payload, at: Q.of(-1));
        }, 'NEGATIVE_TIMELINE_START');
        refuse(p, () {
          PasteClips(payload, at: Q.of(-1), mode: 'insert');
        }, 'NEGATIVE_TIMELINE_START');
        refuse(p, () {
          PasteClips(payload, at: Q.of(-1), mode: 'overwrite');
        }, 'NEGATIVE_TIMELINE_START');
        refuse(
          lockTrack(p, 'video'),
          PasteClips(payload, at: Q.of(2), mode: 'reject'),
          'FIELD_LOCKED',
        );
        refuse(
          lockTrack(p, 'video'),
          PasteClips(payload, at: Q.of(2), mode: 'insert'),
          'FIELD_LOCKED',
        );
        refuse(
          lockTrack(p, 'video'),
          PasteClips(payload, at: Q.of(2), mode: 'overwrite'),
          'FIELD_LOCKED',
        );
      },
    );
  });
}
