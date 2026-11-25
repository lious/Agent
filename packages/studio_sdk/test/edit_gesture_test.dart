import 'dart:io';
import 'dart:convert';

import 'package:sqlite3/sqlite3.dart';
import 'package:studio_sdk/studio_sdk.dart';
import 'package:studio_store/studio_store.dart';
import 'package:test/test.dart';

import 'dissolve_fixture.dart';

Matcher code(String value) =>
    throwsA(isA<StudioException>().having((e) => e.code, 'code', value));
List<Map> clips(StudioWorkspace w) =>
    (w.current.toJson()['sequences'][0]['tracks'][0]['items'] as List)
        .where((c) => c['source'] != null)
        .cast<Map>()
        .toList();
String contents(StudioWorkspace w) =>
    contentHash(w.current.toJson()..remove('revision'));
void main() {
  late Directory dir;
  late StudioWorkspace w;
  StudioWorkspace open() => StudioWorkspace.open(
    profile: AppProfile(
      appId: 'studio',
      region: 'local',
      features: {'project.metadata', 'media.local'},
    ),
    databasePath: '${dir.path}/db',
    tenantId: 'local',
    workspaceId: 'gestures',
    mediaLibraryPath: Platform.environment['STUDIO_MEDIA_LIBRARY'],
    mediaRootPath: '${dir.path}/media',
  );
  setUp(() async {
    dir = Directory.systemTemp.createTempSync('gesture-edit-');
    w = open();
    await installDissolveFixture(w, dir);
  });
  tearDown(() async {
    await w.closeAsync();
    dir.deleteSync(recursive: true);
  });
  Map<String, int> journal() {
    final db = sqlite3.open('${dir.path}/db');
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

  test('REAL40 ghost changes -> one command/inverse; preview=commit; reopen redo, archive fork and MP4', () async {
    final id = clips(w).first['id'] as String;
    w.setClipOpacity(id, .9, expectedRevision: w.current.revision);
    final base = w.current, hash = contents(w), counts = journal();
    final g = w.beginGesture(
      SetClipOpacity(id, .9),
      expectedRevision: base.revision,
    );
    for (var i = 1; i <= 40; i++) {
      w.updateGesture(g, SetClipOpacity(id, .9 - i * .01));
    }
    expect(w.current.hash, base.hash);
    expect(journal(), counts);
    final ghost = await w.previewGestureAt(g, Q.of(1, 2));
    expect(w.current.hash, base.hash);
    expect(journal(), counts);
    final committed = w.commitGesture(g);
    expect(committed.revision, base.revision + BigInt.one);
    expect(journal()['commands'], counts['commands']! + 1);
    expect(g.finished, true);
    expect((await w.previewTimelineAt(Q.of(1, 2))).rgba, ghost.rgba);
    final after = contents(w);
    w.undo(expectedRevision: w.current.revision);
    expect(contents(w), hash);
    final file = File('${dir.path}/project.studio');
    await w.saveArchive(file);
    await w.closeAsync();
    w = open();
    w.openDemo();
    expect(w.canRedo, true);
    w.redo(expectedRevision: w.current.revision);
    expect(contents(w), after);
    expect(() => w.commitGesture(g), code('GESTURE_NOT_ACTIVE'));
    await w.saveArchive(file);
    await w.restoreArchive(LocalFileGrant.fromUserSelection(file));
    expect(w.canUndo, false);
    expect(w.canRedo, false);
    final out = File('${dir.path}/out.mp4');
    await w.exportVideo(out);
    expect(out.lengthSync(), greaterThan(100));
  });

  test('explicit cancellation/no-op preserve redo; new different gesture truncates redo, never another target', () async {
    final a = clips(w)[0]['id'] as String, b = clips(w)[1]['id'] as String;
    w.setClipOpacity(a, .8, expectedRevision: w.current.revision);
    w.setClipOpacity(a, .6, expectedRevision: w.current.revision);
    w.undo(expectedRevision: w.current.revision);
    final base = w.current, counts = journal();
    expect(w.canRedo, true);
    final g = w.beginGesture(
      SetClipOpacity(a, .8),
      expectedRevision: base.revision,
    );
    w.updateGesture(g, SetClipOpacity(a, .2));
    w.cancelGesture(g);
    w.cancelGesture(g);
    expect(w.current.hash, base.hash);
    expect(journal(), counts);
    expect(w.canRedo, true);
    final noop = w.beginGesture(
      SetClipOpacity(a, .8),
      expectedRevision: base.revision,
    );
    w.commitGesture(noop);
    expect(journal()['commands'], counts['commands']);
    expect(w.canRedo, true);
    final separate = w.beginGesture(
      SetClipOpacity(b, .7),
      expectedRevision: w.current.revision,
    );
    expect(
      () => w.updateGesture(separate, SetClipOpacity(a, .5)),
      code('GESTURE_TARGET_MISMATCH'),
    );
    expect(() => w.commitGesture(separate), code('GESTURE_INVALID'));
    w.updateGesture(separate, SetClipOpacity(b, .5));
    w.commitGesture(separate);
    expect(w.canRedo, false);
    expect(journal()['commands'], counts['commands']! + 1);
    w.undo(expectedRevision: w.current.revision);
    expect(contents(w), contentHash(base.toJson()..remove('revision')));
  });

  test('basic move/trim/slip absolute-from-base matrix, collision/handles/edge targets and invalid release', () {
    final b = clips(w)[1]['id'] as String;
    final base = w.current, counts = journal();
    final g = w.beginGesture(
      MoveClip(b, Q.of(1, 30)),
      expectedRevision: base.revision,
    );
    final preview = w.updateGesture(g, MoveClip(b, Q.of(2, 30)));
    final p = (preview.toJson()['sequences'][0]['tracks'][0]['items'] as List)
        .singleWhere((c) => c['id'] == b);
    expect(Q.fromJson(p['timelineRange']['start']), Q.of(1) + Q.of(2, 30));
    expect(
      () => w.updateGesture(g, MoveClip(b, Q.of(-1, 30))),
      code('COLLISION'),
    );
    expect(() => w.commitGesture(g), code('GESTURE_INVALID'));
    expect(journal(), counts);
    w.updateGesture(g, MoveClip(b, Q.of(3, 30)));
    w.commitGesture(g);
    w.undo(expectedRevision: w.current.revision);
    expect(contents(w), contentHash(base.toJson()..remove('revision')));
    final trim = w.beginGesture(
      TrimClip(b, 'in', Q.of(1, 30)),
      expectedRevision: w.current.revision,
    );
    expect(
      () => w.updateGesture(trim, TrimClip(b, 'out', Q.of(-1, 30))),
      code('GESTURE_TARGET_MISMATCH'),
    );
    expect(
      () => w.updateGesture(trim, TrimClip(b, 'in', Q.of(1, 30), ripple: true)),
      code('GESTURE_TARGET_MISMATCH'),
    );
    w.updateGesture(trim, TrimClip(b, 'in', Q.of(2, 30)));
    w.commitGesture(trim);
    w.undo(expectedRevision: w.current.revision);
    final slip = w.beginGesture(
      SlipClip(b, Q.of(1, 30)),
      expectedRevision: w.current.revision,
    );
    expect(
      () => w.updateGesture(slip, SlipClip(b, Q.of(2))),
      throwsA(isA<StudioException>()),
    );
    expect(() => w.commitGesture(slip), code('GESTURE_INVALID'));
    w.cancelGesture(slip);
    expect(contents(w), contentHash(base.toJson()..remove('revision')));
    final noMotionBase = w.current.hash, noMotionCounts = journal();
    final noMotion = w.beginGesture(
      MoveClip(b, Q.of(1, 30)),
      expectedRevision: w.current.revision,
    );
    w.updateGesture(noMotion, MoveClip(b, Q.of(0)));
    w.commitGesture(noMotion);
    expect(w.current.hash, noMotionBase);
    expect(journal(), noMotionCounts);
    expect(
      () => w.beginGesture(
        RenameProject('not a drag'),
        expectedRevision: w.current.revision,
      ),
      code('GESTURE_OPERATION_UNSUPPORTED'),
    );
  });

  test('SQL late abort keeps candidate and journal atomic; explicit retry; revision and writer fencing', () {
    final id = clips(w).first['id'] as String;
    final g = w.beginGesture(
      SetClipOpacity(id, .5),
      expectedRevision: w.current.revision,
    );
    final before = w.current, counts = journal();
    final db = sqlite3.open('${dir.path}/db');
    db.execute(
      "CREATE TRIGGER gesture_fail BEFORE INSERT ON events BEGIN SELECT RAISE(ABORT,'gesture SQL failure'); END",
    );
    try {
      expect(() => w.commitGesture(g), throwsA(isA<SqliteException>()));
      expect(g.finished, false);
      expect(w.current.hash, before.hash);
      expect(journal(), counts);
    } finally {
      db.execute('DROP TRIGGER gesture_fail');
      db.dispose();
    }
    w.commitGesture(g);
    expect(journal()['commands'], counts['commands']! + 1);
    final stale = w.beginGesture(
      SetClipOpacity(id, .4),
      expectedRevision: w.current.revision,
    );
    final repo = DocumentRepository.open('${dir.path}/db', w.current.namespace);
    try {
      final owner = repo.acquireWriter(
        w.projectId,
        'other',
        expectedEpoch: repo.writerEpoch(w.projectId),
      );
      expect(() => w.commitGesture(stale), code('WRITER_FENCED'));
      w.cancelGesture(stale);
      w.openDemo();
      final revision = w.beginGesture(
        SetClipOpacity(id, .3),
        expectedRevision: w.current.revision,
      );
      w.rename('intervening edit', expectedRevision: w.current.revision);
      expect(() => w.commitGesture(revision), code('REVISION_CONFLICT'));
      w.cancelGesture(revision);
      expect(repo.read(owner.projectId)!.title, 'intervening edit');
    } finally {
      repo.close();
    }
  });

  test('transform/crop/color gesture matrix uses same native preview and commit nodes', () async {
    final id = clips(w).first['id'] as String;
    final operations = <EditOperation>[
      SetClipTransform(id, {...identityTransform2d, 'translateX': 8}),
      SetClipCrop(id, {...identityCrop, 'left': .25}),
      SetClipColorBasic(id, {...identityColorBasic, 'exposureStops': -1}),
    ];
    for (final op in operations) {
      final before = contents(w), rev = w.current.revision;
      final g = w.beginGesture(op, expectedRevision: rev);
      expect(
        () => w.updateGesture(g, SetClipOpacity(id, .5)),
        code('GESTURE_TARGET_MISMATCH'),
      );
      expect(() => w.commitGesture(g), code('GESTURE_INVALID'));
      w.updateGesture(g, op);
      final ghost = await w.previewGestureAt(g, Q.of(1, 2));
      w.commitGesture(g);
      expect(w.current.revision, rev + BigInt.one);
      expect((await w.previewTimelineAt(Q.of(1, 2))).rgba, ghost.rgba);
      w.undo(expectedRevision: w.current.revision);
      expect(contents(w), before);
    }
  });

  test('actual child SIGKILL while100 updates staged preserves committed journal on reopen', () async {
    final before = w.current.hash, counts = journal();
    final process = await Process.start(Platform.resolvedExecutable, [
      '--packages=${File('.dart_tool/package_config.json').absolute.path}',
      'packages/studio_sdk/tool/edit_gesture_probe.dart',
      dir.path,
    ]);
    final errors = process.stderr.transform(systemEncoding.decoder).join();
    try {
      expect(
        await process.stdout
            .transform(systemEncoding.decoder)
            .transform(const LineSplitter())
            .first
            .timeout(const Duration(seconds: 20)),
        'GHOST_READY',
      );
      expect(process.kill(ProcessSignal.sigkill), true);
      expect(await process.exitCode.timeout(const Duration(seconds: 10)), -9);
      expect(await errors, '');
    } finally {
      process.kill(ProcessSignal.sigkill);
      await process.exitCode.timeout(const Duration(seconds: 10));
    }
    w.openDemo();
    expect(w.current.hash, before);
    expect(journal(), counts);
    final g = w.beginGesture(
      SetClipOpacity(clips(w).first['id'] as String, .5),
      expectedRevision: w.current.revision,
    );
    w.commitGesture(g);
    expect(journal()['commands'], counts['commands']! + 1);
  });

  test('public still preview keeps asynchronous capability refusal before reading unopened head', () async {
    final bare = StudioWorkspace.open(
      profile: AppProfile(
        appId: 'studio',
        region: 'local',
        features: {'project.metadata'},
      ),
      databasePath: '${dir.path}/bare-db',
      tenantId: 'local',
      workspaceId: 'bare',
    );
    try {
      final future = bare.previewTimelineAt(Q.of(0));
      await expectLater(future, code('MEDIA_ADAPTER_NOT_INSTALLED'));
    } finally {
      bare.close();
    }
  });

  test('keyframe coordinate isolation, unknown-history refusal, superseded/canceled image never admitted', () async {
    final id = clips(w).first['id'] as String;
    final g = w.beginGesture(
      SetOpacityKeyframe(id, Q.of(0), .7),
      expectedRevision: w.current.revision,
    );
    expect(
      () => w.updateGesture(g, SetOpacityKeyframe(id, Q.of(1, 30), .6)),
      code('GESTURE_TARGET_MISMATCH'),
    );
    w.updateGesture(g, SetOpacityKeyframe(id, Q.of(0), .4));
    final pending = w.previewGestureAt(g, Q.of(0));
    final check = expectLater(pending, throwsA(isA<StudioException>()));
    w.cancelGesture(g);
    await check;
    expect(
      () => w.updateGesture(g, SetOpacityKeyframe(id, Q.of(0), .6)),
      code('GESTURE_NOT_ACTIVE'),
    );
    w.setClipOpacity(id, .5, expectedRevision: w.current.revision);
    final db = sqlite3.open('${dir.path}/db');
    try {
      final row = db
          .select('SELECT * FROM commands ORDER BY rowid DESC LIMIT 1')
          .single;
      final original = row['payload_json'] as String,
          input = row['input_hash'] as String;
      final payload = {
        'kind': 'undo',
        'historyVersion': 99,
        'targetCommandId': 'future',
      };
      db.execute('UPDATE commands SET payload_json=?,input_hash=? WHERE id=?', [
        jsonEncode(payload),
        contentHash({
          'projectId': w.projectId,
          'commandId': row['id'],
          'expectedRevision': row['expected_revision'].toString(),
          'payload': payload,
        }),
        row['id'],
      ]);
      expect(
        () => w.beginGesture(
          SetClipOpacity(id, .7),
          expectedRevision: w.current.revision,
        ),
        code('HISTORY_FORMAT_UNSUPPORTED'),
      );
      db.execute('UPDATE commands SET payload_json=?,input_hash=? WHERE id=?', [
        original,
        input,
        row['id'],
      ]);
    } finally {
      db.dispose();
    }
    final valid = w.beginGesture(
      SetClipOpacity(id, .7),
      expectedRevision: w.current.revision,
    );
    await w.closeAsync();
    expect(valid.finished, true);
    w = open();
    w.openDemo();
  });
}
