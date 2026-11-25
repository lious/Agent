import 'dart:io';

import 'package:sqlite3/sqlite3.dart';
import 'package:studio_sdk/studio_sdk.dart';
import 'package:test/test.dart';

import 'multi_move_fixture.dart';

Matcher code(String c) =>
    throwsA(isA<StudioException>().having((e) => e.code, 'code', c));

String contents(ProjectDocument p) =>
    contentHash(p.toJson()..remove('revision'));

Q startOf(Map c) => Q.fromJson(c['timelineRange']['start']);

List<Map> cuesOf(ProjectDocument p) =>
    (p.toJson()['captions'] as List).cast<Map>();

void main() {
  late Directory root;
  late StudioWorkspace w;
  setUp(() async {
    root = Directory.systemTemp.createTempSync('caption-interval-');
    w = openMoveWorkspace(root);
    await installLinkedMoveFixture(w, root);
  });
  tearDown(() async {
    await w.closeAsync();
    root.deleteSync(recursive: true);
  });

  test('ripple close crops a spanning absolute cue, one command, undo/reopen/fork/sidecar', () async {
    final srt = File('${root.path}/cue.srt')
      ..writeAsStringSync('1\n00:00:00,000 --> 00:00:02,000\nSpan hole\n');
    await w.importCaptions(
      LocalFileGrant.fromUserSelection(srt),
      CaptionFormat.srt,
      expectedRevision: w.current.revision,
    );
    final before = w.current;
    w.edit(
      RippleDeleteClips(const [], range: TimeRange(Q.of(0), Q.of(3, 2))),
      expectedRevision: w.current.revision,
    );
    expect(w.current.revision, before.revision + BigInt.one);
    expect(startOf(moveVideos(w.current).first), Q.of(0));
    final cues = cuesOf(w.current);
    expect(cues, hasLength(1));
    expect(cues.single['text'], 'Span hole');
    expect(Q.fromJson(cues.single['timelineRange']['start']), Q.of(0));
    expect(Q.fromJson(cues.single['timelineRange']['duration']), Q.of(1, 2));
    expect(cues.single['anchor']['kind'], 'absolute');
    w.undo(expectedRevision: w.current.revision);
    expect(contents(w.current), contents(before));
    expect(cuesOf(w.current), hasLength(1));
    expect(
      Q.fromJson(cuesOf(w.current).single['timelineRange']['duration']),
      Q.of(2),
    );
    w.redo(expectedRevision: w.current.revision);
    final redone = w.current;
    w.openDemo();
    expect(contents(w.current), contents(redone));
    final archive = File('${root.path}/caption-interval.studio-project');
    await w.saveArchive(archive);
    await w.restoreArchive(LocalFileGrant.fromUserSelection(archive));
    expect(w.canUndo, false);
    expect(
      Q.fromJson(cuesOf(w.current).single['timelineRange']['duration']),
      Q.of(1, 2),
    );
    final sidecar = File('${root.path}/interval.vtt');
    w.exportCaptions(sidecar, CaptionFormat.vtt);
    final decoded = CaptionFormats.decode(
      sidecar.readAsStringSync(),
      CaptionFormat.vtt,
    ).captions.cues.single;
    expect(decoded.range.start, Q.of(0));
    expect(decoded.range.duration, Q.of(1, 2));
    expect(decoded.text, 'Span hole');
    await expectLater(
      w.exportVideo(File('${root.path}/must-not.mp4')),
      code('CAPTION_RENDER_POLICY_NOT_IMPLEMENTED'),
    );
    expect(File('${root.path}/must-not.mp4').existsSync(), false);
  });

  test(
    'insert paste splits a spanning absolute cue and SQL failure is a no-op',
    () async {
      final srt = File('${root.path}/cue.srt')
        ..writeAsStringSync('1\n00:00:00,000 --> 00:00:02,000\nSpan hole\n');
      await w.importCaptions(
        LocalFileGrant.fromUserSelection(srt),
        CaptionFormat.srt,
        expectedRevision: w.current.revision,
      );
      final firstId = moveVideos(w.current).first['id'] as String;
      w.copySelection([firstId]);
      final before = w.current;
      w.pasteClipboard(
        at: Q.of(1, 2),
        mode: 'insert',
        expectedRevision: w.current.revision,
      );
      expect(w.current.revision, before.revision + BigInt.one);
      final cues = cuesOf(w.current);
      cues.sort(
        (a, b) => Q
            .fromJson(a['timelineRange']['start'])
            .compareTo(Q.fromJson(b['timelineRange']['start'])),
      );
      expect(cues, hasLength(2));
      expect(cues[0]['text'], 'Span hole');
      expect(cues[1]['text'], 'Span hole');
      expect(Q.fromJson(cues[0]['timelineRange']['start']), Q.of(0));
      expect(Q.fromJson(cues[0]['timelineRange']['duration']), Q.of(1, 2));
      expect(Q.fromJson(cues[1]['timelineRange']['start']), Q.of(2));
      expect(Q.fromJson(cues[1]['timelineRange']['duration']), Q.of(3, 2));
      w.undo(expectedRevision: w.current.revision);
      expect(contents(w.current), contents(before));
      final frozen = w.current.hash;
      final db = sqlite3.open('${root.path}/db');
      db.execute(
        "CREATE TRIGGER cap_interval_fail BEFORE INSERT ON events BEGIN SELECT RAISE(ABORT,'fixture'); END",
      );
      try {
        expect(
          () => w.pasteClipboard(
            at: Q.of(1, 2),
            mode: 'insert',
            expectedRevision: w.current.revision,
          ),
          throwsA(isA<SqliteException>()),
        );
        expect(w.current.hash, frozen);
      } finally {
        db.execute('DROP TRIGGER cap_interval_fail');
        db.dispose();
      }
    },
  );
}
