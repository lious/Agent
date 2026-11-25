import 'dart:convert';
import 'dart:io';

import 'package:studio_contracts/studio_contracts.dart';

import 'dart:math';

import 'package:studio_document/studio_document.dart';
import 'package:test/test.dart';

/// This file is synthetic metadata only; it does NOT test decoding or rendering.
ProjectDocument fixture() => ProjectDocument.fromJson(
  jsonDecode(File('fixtures/project/local-video.json').readAsStringSync())
      as Map<String, dynamic>,
);
ProjectDocument change(ProjectDocument p, EditOperation op) {
  var id = 0;
  String version(String id) {
    final s = p.toJson()['sequences'][0];
    if (id == s['id']) {
      return (int.parse(s['version'] as String) + 1).toString();
    }
    final c = (s['tracks'][0]['items'] as List).singleWhere(
      (v) => v['id'] == id,
    );
    return (int.parse(c['version'] as String) + 1).toString();
  }

  return applyEdit(
    p,
    op,
    nextVersion: version,
    newId: () => 'gap-${p.hash.substring(7, 15)}-${id++}',
  );
}

String firstId(ProjectDocument p) =>
    p.toJson()['sequences'][0]['tracks'][0]['items'][0]['id'] as String;
ProjectDocument three() {
  var p = fixture();
  p = change(p, SplitClip(firstId(p), Q.of(1), 'b'));
  return change(p, SplitClip('b', Q.of(2), 'c'));
}

List<dynamic> items(ProjectDocument p) =>
    p.toJson()['sequences'][0]['tracks'][0]['items'] as List;
Map c(ProjectDocument p, String id) =>
    items(p).singleWhere((v) => v['id'] == id) as Map;
Q time(ProjectDocument p, String id, String range, String field) =>
    Q.fromJson(c(p, id)[range][field]);
Q duration(ProjectDocument p) =>
    Q.fromJson(p.toJson()['sequences'][0]['duration']);
Matcher error(String s) =>
    throwsA(isA<StudioException>().having((e) => e.code, 'code', s));

void main() {
  test('split preserves exact half-open source mapping and rejects endpoints/off-grid', () {
    final p = fixture(), id = firstId(fixture());
    final q = change(p, SplitClip(id, Q.of(1), 'b'));
    expect(time(q, id, 'sourceRange', 'duration'), Q.of(1));
    expect(time(q, 'b', 'sourceRange', 'start'), Q.of(1));
    expect(duration(q), Q.of(3));
    expect(
      () => change(p, SplitClip(id, Q.of(0), 'x')),
      error('SPLIT_BOUNDARY'),
    );
    expect(
      () => change(p, SplitClip(id, Q.of(3), 'x')),
      error('SPLIT_BOUNDARY'),
    );
    expect(
      () => change(p, SplitClip(id, Q.of(1, 100), 'x')),
      throwsA(isA<StudioException>()),
    );
    expect(p.hash, fixture().hash);
  });
  test(
    'normal lift and trim preserve trailing Gap; ripple changes duration',
    () {
      final p = three();
      final lift = change(p, const DeleteClip('c'));
      expect(duration(lift), Q.of(3));
      expect(items(lift).last['source'], null);
      expect(duration(change(p, const DeleteClip('c', ripple: true))), Q.of(2));
      final trim = change(p, TrimClip('c', 'out', Q.of(-1, 2)));
      expect(duration(trim), Q.of(3));
      expect(items(trim).last['source'], null);
      expect(
        duration(change(p, TrimClip('c', 'out', Q.of(-1, 2), ripple: true))),
        Q.of(5, 2),
      );
      final rip = change(p, TrimClip('b', 'in', Q.of(1, 2), ripple: true));
      expect(time(rip, 'b', 'timelineRange', 'start'), Q.of(1));
      expect(time(rip, 'b', 'sourceRange', 'start'), Q.of(3, 2));
      expect(time(rip, 'c', 'timelineRange', 'start'), Q.of(3, 2));
    },
  );
  test('roll slip slide conserve expected source/sequence intervals', () {
    final p = three(), a = firstId(three());
    final roll = change(p, RollCut(a, 'b', Q.of(1, 2)));
    expect(duration(roll), Q.of(3));
    expect(time(roll, a, 'timelineRange', 'duration'), Q.of(3, 2));
    expect(time(roll, 'b', 'sourceRange', 'start'), Q.of(3, 2));
    final slip = change(p, SlipClip('b', Q.of(1, 2)));
    expect(time(slip, 'b', 'timelineRange', 'start'), Q.of(1));
    expect(time(slip, 'b', 'sourceRange', 'start'), Q.of(3, 2));
    final slide = change(p, SlideClip(a, 'b', 'c', Q.of(1, 2)));
    expect(duration(slide), Q.of(3));
    expect(time(slide, 'b', 'timelineRange', 'start'), Q.of(3, 2));
    expect(time(slide, 'b', 'sourceRange', 'start'), Q.of(1));
    expect(time(slide, 'c', 'sourceRange', 'duration'), Q.of(1, 2));
  });
  test('collision, negative, source exhaustion, duplicate IDs and locks reject atomically', () {
    final p = three(), a = firstId(three());
    expect(
      () => change(p, MoveClip('missing', Q.of(0))),
      error('CLIP_NOT_FOUND'),
    );
    expect(
      () => change(p, TrimClip(a, 'invalid', Q.of(0))),
      error('INVALID_EDGE'),
    );
    expect(() => change(p, MoveClip(a, Q.of(1, 2))), error('COLLISION'));
    expect(() => change(p, MoveClip(a, Q.of(-1))), error('INVALID_RANGE'));
    expect(
      () => change(p, SlipClip('c', Q.of(1))),
      error('SOURCE_OUT_OF_RANGE'),
    );
    expect(
      () => change(p, SplitClip(a, Q.of(1, 2), 'b')),
      throwsA(isA<StudioException>()),
    );
    final d = p.toJson();
    d['sequences'][0]['tracks'][0]['items'][1]['lockedFields'] = [
      'sourceRange',
    ];
    final locked = ProjectDocument.fromJson(d);
    expect(
      () => change(locked, SlipClip('b', Q.of(1, 2))),
      error('FIELD_LOCKED'),
    );
    d['sequences'][0]['tracks'][0]['locked'] = true;
    expect(
      () => change(ProjectDocument.fromJson(d), const DeleteClip('b')),
      error('FIELD_LOCKED'),
    );
    expect(p.hash, three().hash);
  });
  test('1000 seeded legal slip/inverse cases conserve ranges without float rounding', () {
    final random = Random(251125);
    final p = three();
    for (var i = 0; i < 1000; i++) {
      final delta = Q.of(random.nextInt(61) - 30, 30);
      final next = change(p, SlipClip('b', delta));
      final back = change(next, SlipClip('b', Q.of(0) - delta));
      expect(time(next, 'b', 'sourceRange', 'duration'), Q.of(1));
      expect(duration(next), Q.of(3));
      final x = back.toJson(), y = p.toJson();
      x['sequences'][0]['version'] = y['sequences'][0]['version'];
      x['sequences'][0]['tracks'][0]['items'][1]['version'] =
          y['sequences'][0]['tracks'][0]['items'][1]['version'];
      expect(contentHash(x), contentHash(y), reason: 'seed case $i');
    }
  });
  test('strict JSON rejects duplicate decoded keys, invalid UTF8, depth and nonfinite numbers', () {
    for (final text in [
      '{"a":1,"\\u0061":2}',
      '[1e999]',
      '[01]',
      '{"a":true,}',
      '[${List.filled(65, '[').join()}0${List.filled(65, ']').join()}]',
    ]) {
      expect(
        () => readStrictJson(utf8.encode(text)),
        throwsA(isA<StudioException>()),
        reason: text,
      );
    }
    expect(() => readStrictJson([0xc0, 0xaf]), throwsA(isA<StudioException>()));
    expect(readStrictJson(utf8.encode('{"a":[1,true,null]}')), {
      'a': [1, true, null],
    });
  });
}
