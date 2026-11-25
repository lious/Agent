import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:sqlite3/sqlite3.dart';
import 'package:studio_sdk/studio_sdk.dart';
import 'package:studio_store/studio_store.dart';
import 'package:test/test.dart';

import 'multi_move_fixture.dart';
import 'dissolve_fixture.dart';
import '../../studio_document/test/multi_move_test.dart' as pure;

Matcher code(String c) =>
    throwsA(isA<StudioException>().having((e) => e.code, 'code', c));
String contents(ProjectDocument p) =>
    contentHash(p.toJson()..remove('revision'));
void main() {
  late Directory root;
  late StudioWorkspace w;
  setUp(() async {
    root = Directory.systemTemp.createTempSync('snap-move-');
    w = openMoveWorkspace(root);
    await installLinkedMoveFixture(w, root);
  });
  tearDown(() async {
    await w.closeAsync();
    root.deleteSync(recursive: true);
  });
  List<String> ids() =>
      moveVideos(w.current).map((c) => c['id'] as String).toList();
  SnappedMovePlan plan({
    ProjectDocument? base,
    List<String>? selected,
    int pointer = 96,
    int head = 1,
  }) => planMoveSnap(
    base ?? w.current,
    clipIds: selected ?? ids(),
    viewport: TimelineViewport(origin: Q.of(0), pixelsPerSecond: Q.of(100)),
    pointerPixel: Q.of(pointer),
    playhead: Q.of(head),
  );
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

  test('real snapped linked4 -> ghost/one history -> exact pixels/AAC leading silence -> reopen/fork', () async {
    final before = w.current,
        hash = contents(before),
        counts = journal(),
        p = plan(),
        pixels = await w.previewTimelineAt(Q.of(1, 2));
    expect(p.decision.target!.kind, SnapKind.playhead);
    expect(p.decision.distancePixels, Q.of(4));
    expect(p.operation.delta, Q.of(1));
    expect(p.expandedIds.length, 4);
    expect(p.trackIds.length, 2);
    final g = w.beginSnappedMove(p);
    expect((await w.previewGestureAt(g, Q.of(3, 2))).rgba, pixels.rgba);
    expect(w.current.hash, before.hash);
    expect(journal(), counts);
    w.cancelGesture(g);
    expect(journal(), counts);
    final committed = w.beginSnappedMove(p);
    w.commitGesture(committed);
    expect(journal()['commands'], counts['commands']! + 1);
    final after = contents(w.current);
    final file = File('${root.path}/snapped.mp4'),
        out = await w.exportVideo(file, captureFrames: [45]);
    expect(out['preEncoderSamples'][0]['rgba'], pixels.rgba);
    final decoded = await Process.run('ffmpeg', [
      '-v',
      'error',
      '-i',
      file.path,
      '-t',
      '1.2',
      '-map',
      '0:a:0',
      '-ar',
      '48000',
      '-ac',
      '2',
      '-f',
      'f32le',
      'pipe:1',
    ], stdoutEncoding: null);
    expect(decoded.exitCode, 0);
    final samples = ByteData.sublistView(
      Uint8List.fromList(decoded.stdout as List<int>),
    );
    expect(samples.lengthInBytes, greaterThanOrEqualTo(57600 * 2 * 4));
    double rms(int from, int until) {
      var energy = 0.0;
      for (var i = from * 2; i < until * 2; i++) {
        final v = samples.getFloat32(i * 4, Endian.little);
        expect(v.isFinite, true);
        energy += v * v;
      }
      return sqrt(energy / ((until - from) * 2));
    }

    expect(rms(0, 38400), lessThan(.0001));
    expect(
      rms(52800, 57600),
      greaterThan(.005),
    ); // codec-safe windows, NOT sample-exact AAC edge/DAC latency
    w.undo(expectedRevision: w.current.revision);
    expect(contents(w.current), hash);
    await w.closeAsync();
    w = openMoveWorkspace(root);
    w.openDemo();
    w.redo(expectedRevision: w.current.revision);
    expect(contents(w.current), after);
    final archive = File('${root.path}/snap.zip');
    await w.saveArchive(archive);
    await w.restoreArchive(LocalFileGrant.fromUserSelection(archive));
    expect(w.canUndo, false);
    expect(w.canRedo, false);
    expect((await w.previewTimelineAt(Q.of(3, 2))).rgba, pixels.rgba);
  });
  test('late SQL failure fully rolls back snapped command; retry same candidate, stale plan/candidate and writer refuse', () {
    final p = plan(),
        g = w.beginSnappedMove(p),
        before = w.current.hash,
        counts = journal(),
        db = sqlite3.open('${root.path}/db');
    db.execute(
      "CREATE TRIGGER snap_fail BEFORE INSERT ON events BEGIN SELECT RAISE(ABORT,'snap fixture'); END",
    );
    try {
      expect(() => w.commitGesture(g), throwsA(isA<SqliteException>()));
      expect(w.current.hash, before);
      expect(journal(), counts);
    } finally {
      db.execute('DROP TRIGGER snap_fail');
      db.dispose();
    }
    w.commitGesture(g);
    final once = journal();
    expect(() => w.commitGesture(g), code('GESTURE_NOT_ACTIVE'));
    expect(journal(), once);
    expect(() => w.beginSnappedMove(p), code('REVISION_CONFLICT'));
    final fresh = plan(), active = w.beginSnappedMove(fresh);
    expect(() => w.updateSnappedMove(active, p), code('REVISION_CONFLICT'));
    expect(() => w.commitGesture(active), code('GESTURE_INVALID'));
    w.updateSnappedMove(active, fresh);
    w.cancelGesture(active);
    final fenced = w.beginSnappedMove(plan()),
        r = DocumentRepository.open('${root.path}/db', w.current.namespace);
    try {
      r.acquireWriter(
        w.projectId,
        'other',
        expectedEpoch: r.writerEpoch(w.projectId),
      );
      expect(() => w.commitGesture(fenced), code('WRITER_FENCED'));
      w.cancelGesture(fenced);
      w.openDemo();
    } finally {
      r.close();
    }
  });
  test('stationary cut snap cannot hide collision; linked locks/negative boundary reject whole DB change', () async {
    final before = w.current.hash,
        counts = journal(),
        single = plan(selected: [ids().last], pointer: 4, head: 100);
    expect(single.decision.target!.kind, SnapKind.cut);
    expect(() => w.beginSnappedMove(single), code('COLLISION'));
    expect(w.current.hash, before);
    expect(journal(), counts);
    final negative = plan(pointer: -104, head: 100);
    expect(() => w.beginSnappedMove(negative), code('NEGATIVE_TIMELINE_START'));
    expect(w.current.hash, before);
    await adoptMoveMetadata(w, root, (d) {
      d['sequences'][0]['tracks'][1]['items'][0]['lockedFields'] = [
        'timelineRange.start',
      ];
    });
    final locked = w.current.hash, lockedCounts = journal();
    expect(() => w.beginSnappedMove(plan()), code('FIELD_LOCKED'));
    expect(w.current.hash, locked);
    expect(journal(), lockedCounts);
  });
  test('real dissolve snapped pair retains handles/shared preview and encoder; lone endpoint refuses', () async {
    await w.closeAsync();
    root.deleteSync(recursive: true);
    root = Directory.systemTemp.createTempSync('snap-dissolve-');
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
    final before = w.current,
        counts = journal(),
        pixels = await w.previewTimelineAt(Q.of(1));
    expect(
      () => w.beginSnappedMove(plan(selected: [selected.first])),
      code('TRANSITION_MOVE_REQUIRES_BOTH'),
    );
    expect(w.current.hash, before.hash);
    expect(journal(), counts);
    final g = w.beginSnappedMove(plan());
    w.commitGesture(g);
    final transition = w.current.toJson()['transitions'][0];
    expect(Q.fromJson(transition['cut']), Q.of(2));
    expect(transition['before'], before.toJson()['transitions'][0]['before']);
    expect(transition['after'], before.toJson()['transitions'][0]['after']);
    expect((await w.previewTimelineAt(Q.of(2))).rgba, pixels.rgba);
    final out = await w.exportVideo(
      File('${root.path}/cut.mp4'),
      captureFrames: [60],
    );
    expect(out['preEncoderSamples'][0]['rgba'], pixels.rgba);
    w.undo(expectedRevision: w.current.revision);
    expect(contents(w.current), contents(before));
  });
  test('real AV-derived metadata: exact mixed frame/sample gate and standalone audio sample snapping', () {
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
    final mixed = ProjectDocument.fromJson(d),
        selected = moveVideos(mixed).map((c) => c['id'] as String).toList(),
        v = TimelineViewport(origin: Q.of(0), pixelsPerSecond: Q.of(1000));
    final one = planMoveSnap(
      mixed,
      clipIds: selected,
      viewport: v,
      pointerPixel: Q.of(1001, 30),
      playhead: Q.of(1001, 30000),
    );
    expect(one.operation.delta, Q.of(1001, 30000));
    expect(() => pure.change(mixed, one.operation), code('NOT_ON_SAMPLE'));
    final five = planMoveSnap(
      mixed,
      clipIds: selected,
      viewport: v,
      pointerPixel: Q.of(1001, 6),
      playhead: Q.of(1001, 6000),
    );
    expect(five.operation.delta, Q.of(1001, 6000));
    expect(
      pure.change(mixed, five.operation).toJson()['linkGroups'],
      mixed.toJson()['linkGroups'],
    );
    final a = w.current.toJson();
    a['linkGroups'] = [];
    for (final t in a['sequences'][0]['tracks']) {
      for (final c in t['items']) {
        if (c['source'] != null) c['linkGroupId'] = null;
      }
    }
    final audio = a['sequences'][0]['tracks'][1];
    audio['items'] = [audio['items'][0]];
    final standalone = ProjectDocument.fromJson(a),
        id = audio['items'][0]['id'] as String,
        p = planMoveSnap(
          standalone,
          clipIds: [id],
          viewport: TimelineViewport(
            origin: Q.of(0),
            pixelsPerSecond: Q.of(100),
          ),
          pointerPixel: Q.of(1, 480),
          playhead: Q.of(1, 48000),
        );
    expect(p.operation.delta, Q.of(1, 48000));
    expect(p.expandedIds, [id]);
    expect(
      pure.change(standalone, p.operation).toJson()['linkGroups'],
      isEmpty,
    );
  });
}
