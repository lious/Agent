import 'dart:convert';

import 'package:studio_document/studio_document.dart';
import 'package:studio_contracts/studio_contracts.dart';
import 'package:test/test.dart';

import 'edit_algebra_test.dart' as f;

Matcher code(String c) =>
    throwsA(isA<StudioException>().having((e) => e.code, 'code', c));
ProjectDocument change(ProjectDocument p, EditOperation op) {
  var serial = 0, max = 0;
  void scan(dynamic v) {
    if (v is Map) {
      if (v['version'] is String) {
        final n = int.tryParse(v['version']);
        if (n != null && n > max) max = n;
      }
      for (final c in v.values) {
        scan(c);
      }
    } else if (v is List) {
      for (final c in v) {
        scan(c);
      }
    }
  }

  scan(p.toJson());
  final allocations = <String, String>{};
  return applyEdit(
    p,
    op,
    nextVersion: (id) => allocations.putIfAbsent(id, () => '${++max}'),
    newId: () => 'multi-${p.hash.substring(7, 15)}-${serial++}',
  );
}

void main() {
  test('adjacent selection moves together without self-collision; exact sources/curves retained', () {
    var p = f.three();
    final ids = f
        .items(p)
        .where((c) => c['source'] != null)
        .map((c) => c['id'] as String)
        .toList();
    p = change(p, SetOpacityKeyframe(ids.first, Q.of(0), .2));
    p = change(p, SetOpacityKeyframe(ids.first, Q.of(1), .8));
    final effects = jsonEncode(p.toJson()['effects']);
    expect(
      () => change(p, MoveClips([ids.first], Q.of(1, 30))),
      code('COLLISION'),
    );
    final result = change(p, MoveClips(ids.reversed, Q.of(1, 30)));
    for (final id in ids) {
      expect(
        f.time(result, id, 'timelineRange', 'start'),
        f.time(p, id, 'timelineRange', 'start') + Q.of(1, 30),
      );
      expect(f.c(result, id)['sourceRange'], f.c(p, id)['sourceRange']);
      expect(f.c(result, id)['timeMap'], f.c(p, id)['timeMap']);
    }
    expect(jsonEncode(result.toJson()['effects']), effects);
    expect(p.hash, isNot(result.hash));
    expect(
      () => change(p, MoveClips(ids, Q.of(-1, 30))),
      code('NEGATIVE_TIMELINE_START'),
    );
    expect(() => change(p, MoveClips(ids, Q.of(1, 100))), code('NOT_ON_FRAME'));
    expect(change(p, MoveClips(ids, Q.of(0))).hash, p.hash);
  });
  test('immutable canonical selection never filters duplicate/missing/gap IDs; bounded input', () {
    final p = f.three(),
        ids = f.items(p).map((c) => c['id'] as String).toList();
    final copy = ids.reversed.toList(), op = MoveClips(copy, Q.of(1));
    copy.clear();
    expect(op.clipIds, ids.toList()..sort());
    expect(() => op.clipIds.add('bad'), throwsUnsupportedError);
    expect(() => MoveClips([], Q.of(1)), code('EMPTY_SELECTION'));
    expect(
      () => MoveClips([ids.first, ids.first], Q.of(1)),
      code('DUPLICATE_SELECTION'),
    );
    expect(
      () => MoveClips(Iterable.generate(100001, (i) => 'clip$i'), Q.of(1)),
      code('SELECTION_LIMIT'),
    );
    expect(
      () => change(p, MoveClips([...ids, 'missing'], Q.of(1))),
      code('CLIP_NOT_FOUND'),
    );
    final gap = change(p, MoveClips(ids, Q.of(1)));
    final gapId = f.items(gap).first['id'] as String;
    expect(
      () => change(gap, MoveClips([gapId], Q.of(1))),
      code('SELECTION_ITEM_UNSUPPORTED'),
    );
  });
  test('all locks preflight atomically; only written field locks block', () {
    final p = f.three(),
        ids = f.items(p).map((c) => c['id'] as String).toList();
    for (final field in ['*', 'timelineRange', 'timelineRange.start']) {
      final d = p.toJson();
      d['sequences'][0]['tracks'][0]['items'][1]['lockedFields'] = [field];
      final locked = ProjectDocument.fromJson(d), hash = locked.hash;
      expect(
        () => change(locked, MoveClips(ids, Q.of(1))),
        code('FIELD_LOCKED'),
      );
      expect(locked.hash, hash);
    }
    final d = p.toJson();
    d['sequences'][0]['tracks'][0]['locked'] = true;
    expect(
      () => change(ProjectDocument.fromJson(d), MoveClips(ids, Q.of(1))),
      code('FIELD_LOCKED'),
    );
    d['sequences'][0]['tracks'][0]['locked'] = false;
    d['sequences'][0]['tracks'][0]['items'][1]['lockedFields'] = [
      'sourceRange',
    ];
    expect(
      change(
        ProjectDocument.fromJson(d),
        MoveClips(ids, Q.of(1)),
      ).toJson()['sequences'][0]['tracks'][0]['items'].length,
      4,
    );
  });
  test('transition endpoints must move together; cut translates, exact handles and sources untouched', () {
    var p = f.fixture();
    final a = f.firstId(p);
    p = change(p, SplitClip(a, Q.of(3, 2), 'right'));
    p = change(p, SetDissolve(a, 'right', Q.of(1, 10), Q.of(1, 10)));
    final hash = p.hash, t = p.toJson()['transitions'][0];
    expect(
      () => change(p, MoveClips([a], Q.of(1))),
      code('TRANSITION_MOVE_REQUIRES_BOTH'),
    );
    expect(p.hash, hash);
    final moved = change(p, MoveClips([a, 'right'], Q.of(1))),
        q = moved.toJson()['transitions'][0];
    expect(Q.fromJson(q['cut']), Q.fromJson(t['cut']) + Q.of(1));
    expect(q['before'], t['before']);
    expect(q['after'], t['after']);
    for (final id in [a, 'right']) {
      expect(f.c(moved, id)['sourceRange'], f.c(p, id)['sourceRange']);
    }
    final d = p.toJson();
    d['sequences'][0]['tracks'][0]['items'][0]['lockedFields'] = [
      'transitions',
    ];
    expect(
      () =>
          change(ProjectDocument.fromJson(d), MoveClips([a, 'right'], Q.of(1))),
      code('FIELD_LOCKED'),
    );
  });
}
