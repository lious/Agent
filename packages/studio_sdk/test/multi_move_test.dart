import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';

import 'package:sqlite3/sqlite3.dart';
import 'package:studio_sdk/studio_sdk.dart';
import 'package:studio_store/studio_store.dart';
import 'package:test/test.dart';

import 'multi_move_fixture.dart';
import 'dissolve_fixture.dart';

Matcher code(String c) =>
    throwsA(isA<StudioException>().having((e) => e.code, 'code', c));
String contents(ProjectDocument p) =>
    contentHash(p.toJson()..remove('revision'));
void contender(
  (String, Namespace, String, WriterToken, BigInt, List<String>, SendPort, int)
  a,
) async {
  final r = DocumentRepository.open(a.$1, a.$2), gate = ReceivePort();
  final rev = r.read(a.$3)!.revision;
  a.$7.send(gate.sendPort);
  await gate.first;
  gate.close();
  var result = 'won';
  try {
    r.edit(
      writer: a.$4,
      commandId: 'move-${a.$8}',
      receiptKey: 'move-${a.$8}',
      expectedRevision: rev,
      operation: MoveClips(a.$6, Q.of(1)),
    );
  } on StudioException catch (e) {
    result = e.code;
  } finally {
    r.close();
  }
  a.$7.send(result);
}

void main() {
  late Directory root;
  late StudioWorkspace w;
  setUp(() async {
    root = Directory.systemTemp.createTempSync('multi-move-');
    w = openMoveWorkspace(root);
    await installLinkedMoveFixture(w, root);
  });
  tearDown(() async {
    await w.closeAsync();
    root.deleteSync(recursive: true);
  });
  List<String> ids() =>
      moveVideos(w.current).map((c) => c['id'] as String).toList();
  Map<String, int> journal() {
    final db = sqlite3.open('${root.path}/db');
    try {
      return {
        for (final t in [
          'commands',
          'revisions',
          'receipts',
          'events',
          'outbox',
          'entity_versions',
          'blob_edges',
        ])
          t: db.select('SELECT count(*) n FROM $t').single['n'] as int,
      };
    } finally {
      db.dispose();
    }
  }

  test('REAL linked4 atomic gesture -> exact native preview/preencoder/AAC MP4 -> undo redo save reopen fork', () async {
    final selected = ids(), a = selected.first;
    w.setOpacityKeyframe(a, Q.of(0), .2, expectedRevision: w.current.revision);
    w.setOpacityKeyframe(
      a,
      Q.of(3, 2),
      .8,
      expectedRevision: w.current.revision,
    );
    w.setClipTransform(a, {
      ...identityTransform2d,
      'translateX': 8,
    }, expectedRevision: w.current.revision);
    w.setClipCrop(a, {
      ...identityCrop,
      'left': .25,
    }, expectedRevision: w.current.revision);
    w.setClipColorBasic(a, {
      ...identityColorBasic,
      'exposureStops': -1,
    }, expectedRevision: w.current.revision);
    await w.buildTimelinePreviewProxies();
    final base = w.current,
        before = contents(base),
        counts = journal(),
        raw = base.toJson();
    final pixels = await w.previewTimelineAt(Q.of(1, 2));
    final g = w.beginGesture(
      MoveClips(selected, Q.of(1, 30)),
      expectedRevision: base.revision,
    );
    for (var n = 1; n <= 30; n++) {
      w.updateGesture(g, MoveClips(selected.reversed, Q.of(n, 30)));
    }
    expect(
      () => w.updateGesture(g, MoveClips(selected.take(1), Q.of(1))),
      code('GESTURE_TARGET_MISMATCH'),
    );
    expect(() => w.commitGesture(g), code('GESTURE_INVALID'));
    w.updateGesture(g, MoveClips(selected, Q.of(1)));
    expect(w.current.hash, base.hash);
    expect(journal(), counts);
    expect(expandedMoveClipIds(base, MoveClips(selected, Q.of(1))).length, 4);
    expect((await w.previewGestureAt(g, Q.of(3, 2))).rgba, pixels.rgba);
    w.commitGesture(g);
    expect(w.current.revision, base.revision + BigInt.one);
    expect(journal()['commands'], counts['commands']! + 1);
    final after = contents(w.current), d = w.current.toJson();
    for (final k in [
      'effects',
      'linkGroups',
      'assets',
      'blobs',
      'audioBuses',
    ]) {
      expect(d[k], raw[k]);
    }
    final video = await w.exportVideo(
      File('${root.path}/move.mp4'),
      captureFrames: [45],
    );
    expect(video['preEncoderSamples'][0]['rgba'], pixels.rgba);
    expect(video['audio'], isNotNull);
    w.undo(expectedRevision: w.current.revision);
    expect(contents(w.current), before);
    await w.closeAsync();
    w = openMoveWorkspace(root);
    w.openDemo();
    expect(w.canRedo, true);
    w.redo(expectedRevision: w.current.revision);
    expect(contents(w.current), after);
    final archive = File('${root.path}/move.zip');
    await w.saveArchive(archive);
    await w.restoreArchive(LocalFileGrant.fromUserSelection(archive));
    expect(w.canUndo, false);
    expect(w.canRedo, false);
    expect(w.current.toJson()['linkGroups'].length, 2);
    expect(w.current.toJson()['assets'][0]['proxyRefs'], isNotEmpty);
    final forkPixels = await w.previewTimelineAt(Q.of(3, 2));
    expect(forkPixels.rgba, pixels.rgba);
  });
  test('linked closure lock/field/grid failures reject whole DB mutation, never skip audio', () async {
    for (final locked in ['track', 'field']) {
      await adoptMoveMetadata(w, root, (d) {
        final audio = d['sequences'][0]['tracks'][1];
        if (locked == 'track') {
          audio['locked'] = true;
        } else {
          audio['items'][1]['lockedFields'] = ['timelineRange.start'];
        }
      });
      final before = w.current.hash, counts = journal();
      expect(
        () => w.edit(
          MoveClips(ids(), Q.of(1)),
          expectedRevision: w.current.revision,
        ),
        code('FIELD_LOCKED'),
      );
      expect(w.current.hash, before);
      expect(journal(), counts);
      await adoptMoveMetadata(w, root, (d) {
        final audio = d['sequences'][0]['tracks'][1];
        audio['locked'] = false;
        for (final c in audio['items']) {
          if (c['source'] != null) c['lockedFields'] = [];
        }
      });
    }
    final before = w.current.hash, counts = journal();
    expect(
      () => w.edit(
        MoveClips([ids().last], Q.of(-1, 30)),
        expectedRevision: w.current.revision,
      ),
      code('COLLISION'),
    );
    expect(
      () => w.edit(
        MoveClips(ids(), Q.of(-1, 30)),
        expectedRevision: w.current.revision,
      ),
      code('NEGATIVE_TIMELINE_START'),
    );
    expect(
      () => w.edit(
        MoveClips([...ids(), 'unknown'], Q.of(1)),
        expectedRevision: w.current.revision,
      ),
      code('CLIP_NOT_FOUND'),
    );
    expect(w.current.hash, before);
    expect(journal(), counts);
  });
  test('imported covered cues default to clipLocal and follow; made-absolute cues stay; source still refuses; no MP4 burn-in', () async {
    final srt = File('${root.path}/cue.srt')
      ..writeAsStringSync(
        '1\n00:00:00,000 --> 00:00:01,000\nCovered cue follows\n',
      );
    await w.importCaptions(
      LocalFileGrant.fromUserSelection(srt),
      CaptionFormat.srt,
      expectedRevision: w.current.revision,
    );
    expect(w.current.toJson()['captions'][0]['anchor']['kind'], 'clipLocal');
    final imported = w.current;
    w.edit(MoveClips(ids(), Q.of(1)), expectedRevision: w.current.revision);
    expect(
      Q.fromJson(w.current.toJson()['captions'][0]['timelineRange']['start']),
      Q.of(1),
    );
    expect(w.current.toJson()['captions'][0]['anchor']['kind'], 'clipLocal');
    await expectLater(
      w.previewTimelineAt(Q.of(3, 2)),
      code('CAPTION_RENDER_POLICY_NOT_IMPLEMENTED'),
    );
    await expectLater(
      w.exportVideo(File('${root.path}/must-not.mp4')),
      code('CAPTION_RENDER_POLICY_NOT_IMPLEMENTED'),
    );
    expect(File('${root.path}/must-not.mp4').existsSync(), false);
    w.undo(expectedRevision: w.current.revision);
    expect(contents(w.current), contents(imported));
    w.edit(
      SetCaptions(
        CaptionStore([
          CaptionCue.fromProjectJson(
            Map<String, dynamic>.from(w.current.toJson()['captions'][0] as Map),
          ).makeAbsolute(),
        ]),
      ),
      expectedRevision: w.current.revision,
    );
    final frozenAbs = w.current;
    w.edit(MoveClips(ids(), Q.of(1)), expectedRevision: w.current.revision);
    expect(
      Q.fromJson(w.current.toJson()['captions'][0]['timelineRange']['start']),
      Q.of(0),
    );
    expect(w.current.toJson()['captions'][0]['anchor']['kind'], 'absolute');
    w.undo(expectedRevision: w.current.revision);
    expect(contents(w.current), contents(frozenAbs));
    expect(
      Q.fromJson(w.current.toJson()['captions'][0]['timelineRange']['start']),
      Q.of(0),
    );
    final d = w.current.toJson(), clip = ids().first;
    d['captions'][0]['anchor'] = {
      'kind': 'source',
      'clipId': clip,
      'range': {'start': Q.of(0).toJson(), 'duration': Q.of(1).toJson()},
    };
    final unsupported = ProjectDocument.fromJson(d);
    expect(
      () => expandedMoveClipIds(unsupported, MoveClips([clip], Q.of(1))),
      code('CAPTION_RICH_EDIT_NOT_IMPLEMENTED'),
    );
  });
  test('mixed exact grids reject fractional audio samples; nonzero link offsets remain exact', () async {
    final d = w.current.toJson(), seq = d['sequences'][0];
    seq['frameRate'] = {'n': 30000, 'd': 1001};
    seq['duration'] = Q.of(2002, 1000).toJson();
    for (final t in seq['tracks']) {
      for (var i = 0; i < t['items'].length; i++) {
        final c = t['items'][i];
        c['timelineRange'] = {
          'start': Q.of(i * 1001, 1000).toJson(),
          'duration': Q.of(1001, 1000).toJson(),
        };
        c['sourceRange'] = {
          'start': Q.of(i * 1001, 1000).toJson(),
          'duration': Q.of(1001, 1000).toJson(),
        };
      }
    }
    final p = ProjectDocument.fromJson(d),
        selected = moveVideos(p).map((c) => c['id'] as String).toList();
    expect(
      () => applyEdit(
        p,
        MoveClips(selected, Q.of(1001, 30000)),
        nextVersion: (_) => '9999',
        newId: () => 'unused-gap',
      ),
      code('NOT_ON_SAMPLE'),
    );
    var serial = 0;
    final q = applyEdit(
      p,
      MoveClips(selected, Q.of(1001, 6000)),
      nextVersion: (_) => '9999',
      newId: () => 'gap-${serial++}',
    );
    expect(q.toJson()['linkGroups'], p.toJson()['linkGroups']);
    await adoptMoveMetadata(w, root, (data) {
      final s = data['sequences'][0];
      for (final c in s['tracks'][1]['items']) {
        c['timelineRange']['start'] =
            (Q.fromJson(c['timelineRange']['start']) + Q.of(1, 50)).toJson();
      }
      s['tracks'][1]['items'].insert(0, {
        'id': 'offset-gap',
        'trackId': s['tracks'][1]['id'],
        'timelineRange': {
          'start': Q.of(0).toJson(),
          'duration': Q.of(1, 50).toJson(),
        },
      });
      for (final g in data['linkGroups']) {
        g['members'][1]['offset'] = Q.of(1, 50).toJson();
      }
      s['duration'] = Q.of(151, 50).toJson();
    });
    final links = w.current.toJson()['linkGroups'];
    w.edit(MoveClips(ids(), Q.of(1)), expectedRevision: w.current.revision);
    expect(w.current.toJson()['linkGroups'], links);
    w.edit(MoveClips(ids(), Q.of(-1)), expectedRevision: w.current.revision);
    expect(w.current.toJson()['linkGroups'], links);
    expect(
      Q.fromJson(w.current.toJson()['sequences'][0]['duration']),
      Q.of(121, 30),
    );
  });
  test('real dissolve endpoints move together, exact cut/handles/effect order shared with encoder and archive', () async {
    // This helper requires a pristine empty project, not the linked AV setup.
    await w.closeAsync();
    root.deleteSync(recursive: true);
    root = Directory.systemTemp.createTempSync('multi-dissolve-');
    w = openMoveWorkspace(root);
    await installDissolveFixture(w, root);
    final selected = ids();
    w.setDissolve(
      selected.first,
      selected.last,
      Q.of(1, 5),
      Q.of(1, 5),
      expectedRevision: w.current.revision,
    );
    w.setClipTransform(selected.first, {
      ...identityTransform2d,
      'translateX': 8,
    }, expectedRevision: w.current.revision);
    w.setClipOpacity(selected.last, .4, expectedRevision: w.current.revision);
    final base = w.current,
        raw = base.toJson(),
        counts = journal(),
        frame = await w.previewTimelineAt(Q.of(1));
    expect(
      () => w.edit(
        MoveClips([selected.first], Q.of(1)),
        expectedRevision: w.current.revision,
      ),
      code('TRANSITION_MOVE_REQUIRES_BOTH'),
    );
    expect(w.current.hash, base.hash);
    expect(journal(), counts);
    w.edit(MoveClips(selected, Q.of(1)), expectedRevision: w.current.revision);
    final cut = w.current.toJson()['transitions'][0];
    expect(Q.fromJson(cut['cut']), Q.of(2));
    expect(cut['before'], raw['transitions'][0]['before']);
    expect(cut['after'], raw['transitions'][0]['after']);
    expect((await w.previewTimelineAt(Q.of(2))).rgba, frame.rgba);
    final encoded = await w.exportVideo(
      File('${root.path}/dissolve-moved.mp4'),
      captureFrames: [60],
    );
    expect(encoded['preEncoderSamples'][0]['rgba'], frame.rgba);
    w.undo(expectedRevision: w.current.revision);
    expect(contents(w.current), contents(base));
    w.redo(expectedRevision: w.current.revision);
    final archive = File('${root.path}/dissolve.zip');
    await w.saveArchive(archive);
    await w.restoreArchive(LocalFileGrant.fromUserSelection(archive));
    expect((await w.previewTimelineAt(Q.of(2))).rgba, frame.rgba);
  });
  test('late SQL rollback/retry/receipt idempotency, revision and stale writer fencing', () {
    final g = w.beginGesture(
          MoveClips(ids(), Q.of(1)),
          expectedRevision: w.current.revision,
        ),
        before = w.current.hash,
        counts = journal();
    final db = sqlite3.open('${root.path}/db');
    db.execute(
      "CREATE TRIGGER multi_fail BEFORE INSERT ON events BEGIN SELECT RAISE(ABORT,'multi fixture'); END",
    );
    try {
      expect(() => w.commitGesture(g), throwsA(isA<SqliteException>()));
      expect(w.current.hash, before);
      expect(journal(), counts);
    } finally {
      db.execute('DROP TRIGGER multi_fail');
      db.dispose();
    }
    w.commitGesture(g);
    expect(journal()['commands'], counts['commands']! + 1);
    final stale = w.beginGesture(
      MoveClips(ids(), Q.of(1)),
      expectedRevision: w.current.revision,
    );
    w.rename('intervening edit', expectedRevision: w.current.revision);
    expect(() => w.commitGesture(stale), code('REVISION_CONFLICT'));
    w.cancelGesture(stale);
    final fenced = w.beginGesture(
      MoveClips(ids(), Q.of(1)),
      expectedRevision: w.current.revision,
    );
    final repo = DocumentRepository.open(
      '${root.path}/db',
      w.current.namespace,
    );
    try {
      repo.acquireWriter(
        w.projectId,
        'other',
        expectedEpoch: repo.writerEpoch(w.projectId),
      );
      expect(() => w.commitGesture(fenced), code('WRITER_FENCED'));
      w.cancelGesture(fenced);
      w.openDemo();
    } finally {
      repo.close();
    }
  });
  test('actual two independent SQLite contenders publish one entire four-member move', () async {
    final ns = w.current.namespace,
        project = w.projectId,
        rev = w.current.revision,
        db = sqlite3.open('${root.path}/db'),
        row = db.select(
          'SELECT owner,fence FROM project_heads WHERE ns=? AND project_id=?',
          [ns.key, project],
        ).single;
    final writer = WriterToken(
      ns,
      project,
      row['owner'] as String,
      row['fence'] as int,
    );
    db.dispose();
    final port = ReceivePort(), it = StreamIterator<dynamic>(port);
    for (var i = 0; i < 2; i++) {
      await Isolate.spawn(contender, (
        '${root.path}/db',
        ns,
        project,
        writer,
        rev,
        ids(),
        port.sendPort,
        i,
      ));
    }
    final gates = <SendPort>[];
    for (var i = 0; i < 2; i++) {
      expect(await it.moveNext().timeout(const Duration(seconds: 20)), true);
      gates.add(it.current as SendPort);
    }
    for (final gate in gates) {
      gate.send(true);
    }
    final results = <String>[];
    for (var i = 0; i < 2; i++) {
      expect(await it.moveNext().timeout(const Duration(seconds: 20)), true);
      results.add(it.current as String);
    }
    await it.cancel();
    port.close();
    expect(results.where((x) => x == 'won').length, 1);
    expect(results.where((x) => x == 'REVISION_CONFLICT').length, 1);
    expect(w.current.revision, rev + BigInt.one);
    final clips = [
      for (final t in w.current.toJson()['sequences'][0]['tracks'])
        for (final c in t['items'])
          if (c['source'] != null) c,
    ];
    expect(clips.length, 4);
    for (final c in clips) {
      expect(Q.fromJson(c['timelineRange']['start']) >= Q.of(1), true);
    }
  });
  test('100 seeded selection moves each undo/redo retain exact full roots, source and canceled candidate', () {
    final random = Random(261126), selected = ids();
    for (var i = 0; i < 100; i++) {
      final before = contents(w.current),
          g = w.beginGesture(
            MoveClips(selected, Q.of(1 + random.nextInt(30), 30)),
            expectedRevision: w.current.revision,
          );
      if (i % 10 == 0) {
        w.cancelGesture(g);
        expect(contents(w.current), before);
        continue;
      }
      w.commitGesture(g);
      final after = contents(w.current);
      w.undo(expectedRevision: w.current.revision);
      expect(contents(w.current), before);
      w.redo(expectedRevision: w.current.revision);
      expect(contents(w.current), after);
      w.undo(expectedRevision: w.current.revision);
      expect(contents(w.current), before);
    }
  }, timeout: const Timeout(Duration(minutes: 3)));
}
