import 'package:studio_document/studio_document.dart';
import 'package:studio_contracts/studio_contracts.dart';
import 'package:test/test.dart';

import 'edit_algebra_test.dart' as f;
import 'multi_move_test.dart' as move;

Matcher code(String c) =>
    throwsA(isA<StudioException>().having((e) => e.code, 'code', c));

void main() {
  test('group/ungroup is selection-only, no-op when identical, refuses partial steal', () {
    final p = f.three();
    final ids = f
        .items(p)
        .where((c) => c['source'] != null)
        .map((c) => c['id'] as String)
        .toList();
    expect(() => GroupClips([ids.first]), code('GROUP_TOO_SMALL'));
    expect(() => GroupClips([]), code('EMPTY_SELECTION'));
    final grouped = move.change(p, GroupClips(ids.take(2)));
    expect(grouped.toJson()['selectionGroups'], hasLength(1));
    final groupId = grouped.toJson()['selectionGroups'][0]['id'] as String;
    for (final id in ids.take(2)) {
      expect(f.c(grouped, id)['selectionGroupId'], groupId);
      expect(f.c(grouped, id)['timelineRange'], f.c(p, id)['timelineRange']);
      expect(f.c(grouped, id)['sourceRange'], f.c(p, id)['sourceRange']);
    }
    expect(move.change(grouped, GroupClips(ids.take(2))).hash, grouped.hash);
    expect(
      () => move.change(grouped, GroupClips(ids)),
      code('GROUP_ALREADY_MEMBER'),
    );
    final cleared = move.change(grouped, UngroupClips([groupId]));
    expect(cleared.toJson()['selectionGroups'], isEmpty);
    for (final id in ids.take(2)) {
      expect(f.c(cleared, id)['selectionGroupId'], isNull);
    }
    expect(
      () => move.change(p, UngroupClips(['missing-group-id-0001'])),
      code('GROUP_NOT_FOUND'),
    );
  });

  test('copy payload keeps relative gap and effects; paste reject/lift leave assets', () {
    var p = f.three();
    final media = f
        .items(p)
        .where((c) => c['source'] != null)
        .map((c) => c['id'] as String)
        .toList();
    p = move.change(p, SetOpacityKeyframe(media.first, Q.of(0), .25));
    final effects = p.toJson()['effects'];
    final payload = buildClipboard(p, [media.first, media.last]);
    expect(payload.clipIds, [media.first, media.last]..sort());
    expect(payload.origin, f.time(p, media.first, 'timelineRange', 'start'));
    expect(payload.effects, isNotEmpty);
    final gap =
        f.time(p, media.last, 'timelineRange', 'start') -
        f.time(p, media.first, 'timelineRange', 'start');
    final at = Q.fromJson(p.toJson()['sequences'][0]['duration']);
    final pasted = move.change(p, PasteClips(payload, at: at));
    final copies =
        f
            .items(pasted)
            .where((c) => c['source'] != null)
            .where((c) => !media.contains(c['id']))
            .toList()
          ..sort(
            (a, b) => Q
                .fromJson(a['timelineRange']['start'])
                .compareTo(Q.fromJson(b['timelineRange']['start'])),
          );
    expect(copies, hasLength(2));
    expect(
      Q.fromJson(copies[1]['timelineRange']['start']) -
          Q.fromJson(copies[0]['timelineRange']['start']),
      gap,
    );
    expect(Q.fromJson(copies[0]['timelineRange']['start']), at);
    expect(copies[0]['sourceRange'], f.c(p, media.first)['sourceRange']);
    expect(pasted.toJson()['effects'].length, effects.length * 2);
    expect(pasted.toJson()['assets'], p.toJson()['assets']);
    expect(
      () => move.change(p, PasteClips(payload, at: Q.of(0))),
      code('COLLISION'),
    );
    final lifted = move.change(p, LiftClips([media.first]));
    expect(f.items(lifted).where((c) => c['id'] == media.first), isEmpty);
    expect(lifted.toJson()['assets'], p.toJson()['assets']);
    expect(
      Q.fromJson(lifted.toJson()['sequences'][0]['duration']),
      Q.fromJson(p.toJson()['sequences'][0]['duration']),
    );
  });

  test('grouped move expands members while leaving ungrouped neighbors', () {
    var p = f.three();
    final media = f
        .items(p)
        .where((c) => c['source'] != null)
        .map((c) => c['id'] as String)
        .toList();
    p = move.change(p, GroupClips([media[1], media.last]));
    final moved = move.change(p, MoveClips([media[1]], Q.of(1)));
    expect(
      f.time(moved, media.last, 'timelineRange', 'start'),
      f.time(p, media.last, 'timelineRange', 'start') + Q.of(1),
    );
    expect(
      f.time(moved, media.first, 'timelineRange', 'start'),
      f.time(p, media.first, 'timelineRange', 'start'),
    );
  });
}
