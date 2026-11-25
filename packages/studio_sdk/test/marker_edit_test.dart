import 'dart:io';

import 'package:sqlite3/sqlite3.dart';
import 'package:studio_sdk/studio_sdk.dart';
import 'package:test/test.dart';

import 'multi_move_fixture.dart';

Matcher code(String c) =>
    throwsA(isA<StudioException>().having((e) => e.code, 'code', c));

String contents(ProjectDocument p) =>
    contentHash(p.toJson()..remove('revision'));

List<Map> markersOf(ProjectDocument p) =>
    (p.toJson()['markers'] as List).cast<Map>();

Map markerOf(ProjectDocument p, String id) =>
    markersOf(p).singleWhere((m) => m['id'] == id);

Q markerTime(ProjectDocument p, String id) =>
    Q.fromJson(markerOf(p, id)['time']);

String sequenceId(ProjectDocument p) => p.toJson()['rootSequenceId'] as String;

void main() {
  late Directory root;
  late StudioWorkspace w;
  setUp(() async {
    root = Directory.systemTemp.createTempSync('marker-edit-');
    w = openMoveWorkspace(root);
    await installLinkedMoveFixture(w, root);
  });
  tearDown(() async {
    await w.closeAsync();
    root.deleteSync(recursive: true);
  });

  test('clipLocal marker follows a host move, one command, undo/reopen/fork; export stays caption-free', () async {
    final host = moveVideos(w.current).last['id'] as String;
    final before = w.current;
    w.edit(
      SetMarkers(
        MarkerStore([
          TimelineMarker(
            'follow',
            sequenceId: sequenceId(before),
            label: 'follows',
            time: Q.of(2),
          ).anchoredToClip(host, Q.of(3, 2), Q.of(3, 2)),
          TimelineMarker(
            'stay',
            sequenceId: sequenceId(before),
            label: 'stays',
            time: Q.of(0),
          ),
        ]),
      ),
      expectedRevision: w.current.revision,
    );
    expect(w.current.revision, before.revision + BigInt.one);
    expect(markerOf(w.current, 'follow')['anchor']['kind'], 'clipLocal');
    final marked = w.current;
    w.edit(MoveClips([host], Q.of(1, 2)), expectedRevision: w.current.revision);
    expect(w.current.revision, marked.revision + BigInt.one);
    expect(
      Q.fromJson(moveVideos(w.current).last['timelineRange']['start']),
      Q.of(2),
    );
    expect(markerTime(w.current, 'follow'), Q.of(5, 2));
    expect(markerTime(w.current, 'stay'), Q.of(0));
    w.undo(expectedRevision: w.current.revision);
    expect(contents(w.current), contents(marked));
    expect(markerTime(w.current, 'follow'), Q.of(2));
    w.redo(expectedRevision: w.current.revision);
    final redone = w.current;
    w.openDemo();
    expect(contents(w.current), contents(redone));
    final archive = File('${root.path}/markers.studio-project');
    await w.saveArchive(archive);
    await w.restoreArchive(LocalFileGrant.fromUserSelection(archive));
    expect(w.canUndo, false);
    expect(markerTime(w.current, 'follow'), Q.of(5, 2));
    expect(markerOf(w.current, 'follow')['anchor']['kind'], 'clipLocal');
    final output = File('${root.path}/markers.mp4');
    await w.exportVideo(output);
    expect(output.lengthSync(), greaterThan(1000));
  });

  test('ripple close drops an in-range marker, shifts ripple=true, SQL failure is a no-op', () {
    final seq = sequenceId(w.current);
    w.edit(
      SetMarkers(
        MarkerStore([
          TimelineMarker(
            'inside',
            sequenceId: seq,
            label: 'gone',
            time: Q.of(1, 2),
          ),
          TimelineMarker(
            'hold',
            sequenceId: seq,
            label: 'hold',
            time: Q.of(5, 2),
            ripple: false,
          ),
          TimelineMarker(
            'shift',
            sequenceId: seq,
            label: 'shift',
            time: Q.of(2),
            ripple: true,
          ),
        ]),
      ),
      expectedRevision: w.current.revision,
    );
    final before = w.current;
    w.edit(
      RippleDeleteClips(const [], range: TimeRange(Q.of(0), Q.of(1))),
      expectedRevision: w.current.revision,
    );
    expect(w.current.revision, before.revision + BigInt.one);
    expect(
      markersOf(w.current).map((m) => m['id']),
      unorderedEquals(['hold', 'shift']),
    );
    expect(markerTime(w.current, 'hold'), Q.of(5, 2));
    expect(markerTime(w.current, 'shift'), Q.of(1));
    w.undo(expectedRevision: w.current.revision);
    expect(contents(w.current), contents(before));
    expect(markersOf(w.current), hasLength(3));
    final frozen = w.current.hash;
    final db = sqlite3.open('${root.path}/db');
    db.execute(
      "CREATE TRIGGER marker_fail BEFORE INSERT ON events BEGIN SELECT RAISE(ABORT,'fixture'); END",
    );
    try {
      expect(
        () => w.edit(
          RippleDeleteClips(const [], range: TimeRange(Q.of(0), Q.of(1))),
          expectedRevision: w.current.revision,
        ),
        throwsA(isA<SqliteException>()),
      );
      expect(w.current.hash, frozen);
    } finally {
      db.execute('DROP TRIGGER marker_fail');
      db.dispose();
    }
  });
}
