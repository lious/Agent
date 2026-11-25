import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:studio_document/studio_document.dart';
import 'package:studio_contracts/studio_contracts.dart';

ProjectDocument dissolveFixture() {
  final d = jsonDecode(
    File('fixtures/project/local-video.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  final s = d['sequences'][0], t = s['tracks'][0], left = t['items'][0];
  left['id'] = 'dissolve-left';
  left['timelineRange'] = {
    'start': Q.of(0).toJson(),
    'duration': Q.of(1).toJson(),
  };
  left['sourceRange'] = {
    'start': Q.of(1, 2).toJson(),
    'duration': Q.of(1).toJson(),
  };
  final right = jsonDecode(jsonEncode(left)) as Map<String, dynamic>;
  right['id'] = 'dissolve-right';
  right['timelineRange']['start'] = Q.of(1).toJson();
  right['sourceRange']['start'] = Q.of(1).toJson();
  t['items'] = [left, right];
  s['duration'] = Q.of(2).toJson();
  return ProjectDocument.fromJson(d);
}

void main() {
  var serial = 100;
  ProjectDocument edit(ProjectDocument p, EditOperation op) => applyEdit(
    p,
    op,
    newId: () => 'dissolve-${serial++}',
    nextVersion: (_) => '${serial++}',
  );
  test('rational window half-open, exact handles, source offsets, curve endpoint hold and bounded composite recipes', () {
    var p = dissolveFixture();
    p = edit(p, SetOpacityKeyframe('dissolve-left', Q.of(0), 1));
    p = edit(p, SetOpacityKeyframe('dissolve-left', Q.of(1), .5));
    p = edit(
      p,
      SetClipTransform('dissolve-right', {
        ...identityTransform2d,
        'translateX': 16,
      }),
    );
    p = edit(
      p,
      SetDissolve('dissolve-left', 'dissolve-right', Q.of(1, 5), Q.of(1, 5)),
    );
    final g = TimelineVideoGraph(p);
    expect(g.sample(Q.of(79, 100)).secondary, isNull);
    final first = g.sample(Q.of(4, 5));
    expect(first.mixQ16, 0);
    expect(first.sourceTime, Q.of(13, 10));
    expect(first.secondary!.sourceTime, Q.of(4, 5));
    final mid = g.sample(Q.of(1));
    expect(mid.mixQ16, 32768);
    expect(mid.opacityQ16, 32768);
    expect(mid.secondary!.transform2d!['translateX'], 16);
    expect(g.sample(Q.of(6, 5)).secondary, isNull);
    expect(g.sample(Q.of(6, 5)).sourceTime, Q.of(6, 5));
    final parts = g.compileDissolves({
      'dissolve-left': {'path': '/fixture-a', 'streamIndex': 0},
      'dissolve-right': {'path': '/fixture-b', 'streamIndex': 0},
    });
    expect(parts.map((p) => p['frameCount']).reduce((a, b) => a + b), 60);
    final blended = parts.where((s) => s['secondary'] != null).toList();
    expect(blended.length, 2);
    expect(blended.first['mixFramesQ16'].first, 0);
    expect(blended.last['mixFramesQ16'].first, 32768);
    expect(Q.fromJson(blended.first['secondary']['sourceStart']), Q.of(4, 5));
  });
  test('missing head/tail handles, zero range/offgrid/freeze and disabled legs refuse without changing input', () {
    final p = dissolveFixture();
    for (final side in ['head', 'tail']) {
      final d = p.toJson();
      final c = d['sequences'][0]['tracks'][0]['items'][side == 'head' ? 1 : 0];
      c['sourceRange']['start'] = Q.of(side == 'head' ? 0 : 2).toJson();
      final before = ProjectDocument.fromJson(d);
      expect(
        () => edit(
          before,
          SetDissolve(
            'dissolve-left',
            'dissolve-right',
            Q.of(1, 5),
            Q.of(1, 5),
          ),
        ),
        throwsA(
          isA<StudioException>().having(
            (e) => e.code,
            'code',
            'TRANSITION_HANDLE_MISSING',
          ),
        ),
      );
    }
    expect(
      () => edit(
        p,
        SetDissolve('dissolve-left', 'dissolve-right', Q.of(0), Q.of(0)),
      ),
      throwsA(isA<StudioException>()),
    );
    expect(
      () => edit(
        p,
        SetDissolve(
          'dissolve-left',
          'dissolve-right',
          Q.of(1, 1000),
          Q.of(1, 5),
        ),
      ),
      throwsA(isA<StudioException>()),
    );
    final good = edit(
      p,
      SetDissolve('dissolve-left', 'dissolve-right', Q.of(1, 5), Q.of(1, 5)),
    );
    final disabled = good.toJson();
    disabled['sequences'][0]['tracks'][0]['items'][1]['enabled'] = false;
    expect(
      () => requireLocalEditingWritable(ProjectDocument.fromJson(disabled)),
      throwsA(isA<StudioException>()),
    );
    final d = good.toJson();
    d['transitions'][0]['missingHandlePolicy'] = 'freeze';
    expect(
      () => requireLocalEditingWritable(ProjectDocument.fromJson(d)),
      throwsA(isA<StudioException>()),
    );
  });
  test('slip revalidates handles, topology edits demand explicit removal, locked removal and noop/NOT_FOUND are real', () {
    final p = edit(
      dissolveFixture(),
      SetDissolve('dissolve-left', 'dissolve-right', Q.of(1, 5), Q.of(1, 5)),
    );
    final hash = p.hash;
    expect(
      edit(
        p,
        SetDissolve('dissolve-left', 'dissolve-right', Q.of(1, 5), Q.of(1, 5)),
      ).hash,
      hash,
    );
    expect(
      () => edit(p, SlipClip('dissolve-right', Q.of(-1))),
      throwsA(isA<StudioException>()),
    );
    expect(p.hash, hash);
    final slipped = edit(p, SlipClip('dissolve-right', Q.of(1, 5)));
    expect(
      TimelineVideoGraph(slipped).sample(Q.of(1)).secondary!.sourceTime,
      Q.of(6, 5),
    );
    for (final op in [
      SplitClip('dissolve-left', Q.of(1, 2), 'cut'),
      TrimClip('dissolve-left', 'out', Q.of(-1, 30)),
      MoveClip('dissolve-right', Q.of(2)),
    ]) {
      expect(
        () => edit(p, op),
        throwsA(
          isA<StudioException>().having(
            (e) => e.code,
            'code',
            'TRANSITION_RANGE_EDIT_REQUIRES_REMOVAL',
          ),
        ),
      );
      expect(p.hash, hash);
    }
    final id = p.toJson()['transitions'][0]['id'] as String;
    final locked = p.toJson();
    locked['sequences'][0]['tracks'][0]['items'][1]['lockedFields'] = [
      'transitions',
    ];
    expect(
      () => edit(ProjectDocument.fromJson(locked), RemoveDissolve(id)),
      throwsA(isA<StudioException>()),
    );
    final removed = edit(p, RemoveDissolve(id));
    expect(removed.toJson()['transitions'], isEmpty);
    expect(
      () => edit(removed, RemoveDissolve(id)),
      throwsA(isA<StudioException>()),
    );
    expect(
      edit(
        removed,
        SplitClip('dissolve-left', Q.of(1, 2), 'cut'),
      ).toJson()['transitions'],
      isEmpty,
    );
  });
  test('dissolve sequence closes both rendered leg definitions; schedule allocations retain native limits', () {
    final p = edit(
      dissolveFixture(),
      SetDissolve('dissolve-left', 'dissolve-right', Q.of(1, 5), Q.of(1, 5)),
    );
    final d = p.toJson(),
        seq = d['sequences'][0],
        clip = seq['tracks'][0]['items'][1];
    final a = DefinitionFingerprinter(p, const {});
    a.registerSnapshot(p);
    clip['sourceRange']['start'] = Q.of(6, 5).toJson();
    final changed = ProjectDocument.fromJson(d),
        b = DefinitionFingerprinter(changed, const {});
    b.registerSnapshot(changed);
    expect(
      a.source('sequence', seq['id'], seq['version']),
      isNot(b.source('sequence', seq['id'], seq['version'])),
    );
    expect(
      () => verifyDefinitionTransition(p, changed),
      throwsA(isA<StudioException>()),
    );
    final ta = a.resolvedDefinitions.singleWhere(
          (v) => v['kind'] == 'transitions',
        ),
        tb = b.resolvedDefinitions.singleWhere(
          (v) => v['kind'] == 'transitions',
        );
    expect(ta, tb); // transition topology is immutable; rendered legs belong to sequence closure.
    for (final count in [-1, 0, 120001]) {
      expect(
        () =>
            opacityScheduleRangeQ16(d, clip, FrameRate(30, 1), Q.of(0), count),
        throwsA(
          isA<StudioException>().having(
            (e) => e.code,
            'code',
            'OPACITY_SCHEDULE_RANGE',
          ),
        ),
      );
    }
  });
}
