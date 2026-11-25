import 'dart:io';

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
List<Map> media(ProjectDocument p) => [
  for (final t in p.toJson()['sequences'][0]['tracks'])
    for (final c in t['items'])
      if (c['source'] != null) c as Map,
];
Map<String, int> journal(Directory root) {
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

void main() {
  late Directory root;
  late StudioWorkspace w;
  setUp(() async {
    root = Directory.systemTemp.createTempSync('clipboard-');
    w = openMoveWorkspace(root);
    await installLinkedMoveFixture(w, root);
  });
  tearDown(() async {
    await w.closeAsync();
    root.deleteSync(recursive: true);
  });

  test('copy is not a document write; cut/paste/group are one command each with undo/reopen/fork/AAC', () async {
    final videos = moveVideos(w.current);
    final first = videos.first['id'] as String,
        last = videos.last['id'] as String;
    final counts = journal(root);
    w.edit(
      SetOpacityKeyframe(first, Q.of(0), .4),
      expectedRevision: w.current.revision,
    );
    final withEffect = w.current;
    expect(w.clipboard, isNull);
    final copied = w.copySelection([first]);
    expect(copied.clipIds, hasLength(2)); // linked audio included
    expect(w.current.hash, withEffect.hash);
    expect(
      journal(root),
      isNot(counts),
    ); // opacity wrote; copy itself did not add more after:
    final afterCopy = journal(root);
    w.copySelection([first]);
    expect(journal(root), afterCopy);
    expect(w.clipboard!.hash, copied.hash);
    final at = Q.fromJson(w.current.toJson()['sequences'][0]['duration']);
    final pixels = await w.previewTimelineAt(Q.of(0));
    w.pasteClipboard(at: at, expectedRevision: w.current.revision);
    expect(w.current.revision, withEffect.revision + BigInt.one);
    final pasted = media(w.current)
        .where(
          (c) =>
              c['id'] != first &&
              c['id'] != last &&
              !media(withEffect).any((o) => o['id'] == c['id']),
        )
        .toList();
    expect(
      pasted.where((c) => moveVideos(w.current).any((v) => v['id'] == c['id'])),
      isNotEmpty,
    );
    final newVideo = moveVideos(w.current)
        .singleWhere((c) => c['id'] != first && c['id'] != last);
    expect(Q.fromJson(newVideo['timelineRange']['start']), at);
    expect(newVideo['sourceRange'], videos.first['sourceRange']);
    expect((w.current.toJson()['effects'] as List).length, 2);
    expect((await w.previewTimelineAt(at)).rgba, pixels.rgba);
    expect(w.current.toJson()['assets'], withEffect.toJson()['assets']);
    w.undo(expectedRevision: w.current.revision);
    expect(contents(w.current), contents(withEffect));
    w.redo(expectedRevision: w.current.revision);
    final moved = w.current;
    w.openDemo();
    expect(contents(w.current), contents(moved));
    final archive = File('${root.path}/clipboard.studio-project');
    await w.saveArchive(archive);
    await w.restoreArchive(LocalFileGrant.fromUserSelection(archive));
    expect(w.canUndo, false);
    expect((await w.previewTimelineAt(at)).rgba, pixels.rgba);
    final out = await w.exportVideo(
      File('${root.path}/clipboard.mp4'),
      captureFrames: [0, (at * Q.of(30)).n.toInt()],
    );
    expect(out['audio'], 'aac');
    expect(File('${root.path}/clipboard.mp4').lengthSync(), greaterThan(1000));
  });

  test('cut is one lift command; group expands later moves; locks/collisions/transitions refuse wholly', () async {
    final videos = moveVideos(w.current);
    final first = videos.first['id'] as String,
        last = videos.last['id'] as String;
    final original = w.current, counts = journal(root);
    w.cutSelection([first], expectedRevision: w.current.revision);
    expect(w.current.revision, original.revision + BigInt.one);
    expect(media(w.current).where((c) => c['id'] == first), isEmpty);
    expect(w.current.toJson()['assets'], original.toJson()['assets']);
    expect(w.clipboard, isNotNull);
    w.undo(expectedRevision: w.current.revision);
    expect(contents(w.current), contents(original));
    expect(journal(root).keys, counts.keys);
    w.groupSelection([first, last], expectedRevision: w.current.revision);
    final grouped = w.current;
    expect(grouped.toJson()['selectionGroups'], hasLength(1));
    // Same-track grouped videos with a later neighbor would collide if shifted +1
    // onto the second already-present clip; move the group to the tail instead.
    final duration = Q.fromJson(grouped.toJson()['sequences'][0]['duration']);
    // Moving both videos +3s (1s past end) keeps relative offset and audio links.
    // First starts at 0, last at 1.5; +3 lands at 3 and 4.5.
    w.edit(MoveClips([first], Q.of(3)), expectedRevision: w.current.revision);
    expect(
      Q.fromJson(
        moveVideos(w.current)
            .firstWhere((c) => c['id'] == last)['timelineRange']['start'],
      ),
      Q.of(3, 2) + Q.of(3),
    );
    for (final c in media(w.current)) {
      if (c['linkGroupId'] != null) {
        expect(Q.fromJson(c['timelineRange']['start']) >= Q.of(3), true);
      }
    }
    w.undo(expectedRevision: w.current.revision);
    expect(contents(w.current), contents(grouped));
    await adoptMoveMetadata(w, root, (d) {
      d['sequences'][0]['tracks'][1]['locked'] = true;
    });
    final locked = w.current.hash;
    // adopt/fork remaps IDs; use the current earliest video, not a stale handle.
    final currentFirst = moveVideos(w.current).first['id'] as String;
    expect(
      () =>
          w.cutSelection([currentFirst], expectedRevision: w.current.revision),
      code('FIELD_LOCKED'),
    );
    w.copySelection([currentFirst]);
    expect(
      () =>
          w.pasteClipboard(at: duration, expectedRevision: w.current.revision),
      code('FIELD_LOCKED'),
    );
    expect(w.current.hash, locked);
    await adoptMoveMetadata(w, root, (d) {
      d['sequences'][0]['tracks'][1]['locked'] = false;
    });
    final unlockedFirst = moveVideos(w.current).first['id'] as String;
    w.copySelection([unlockedFirst]);
    expect(
      () => w.pasteClipboard(at: Q.of(0), expectedRevision: w.current.revision),
      code('COLLISION'),
    );
    expect(
      () =>
          w.pasteClipboard(at: Q.of(-1), expectedRevision: w.current.revision),
      code('NEGATIVE_TIMELINE_START'),
    );
    expect(w.clipboard, isNotNull);
    await w.closeAsync();
    root.deleteSync(recursive: true);
    root = Directory.systemTemp.createTempSync('clipboard-dissolve-');
    w = openMoveWorkspace(root);
    await installDissolveFixture(w, root);
    final pair = moveVideos(w.current).map((c) => c['id'] as String).toList();
    w.setDissolve(
      pair.first,
      pair.last,
      Q.of(1, 5),
      Q.of(1, 5),
      expectedRevision: w.current.revision,
    );
    final withDissolve = w.current.hash;
    expect(
      () => w.copySelection([pair.first]),
      code('TRANSITION_COPY_REQUIRES_BOTH'),
    );
    expect(w.current.hash, withDissolve);
    final both = w.copySelection(pair);
    expect(both.transitions, hasLength(1));
    final cut = Q.fromJson(w.current.toJson()['transitions'][0]['cut']);
    final end = Q.fromJson(w.current.toJson()['sequences'][0]['duration']);
    w.pasteClipboard(at: end, expectedRevision: w.current.revision);
    final transitions = w.current.toJson()['transitions'] as List;
    expect(transitions, hasLength(2));
    expect(Q.fromJson(transitions.last['cut']), cut + (end - both.origin));
    expect(transitions.last['before'], transitions.first['before']);
    expect(transitions.last['after'], transitions.first['after']);
  });

  test('clipboard stays internal and session-scoped; stale/SQL/fence failures do not commit partial members', () async {
    final first = moveVideos(w.current).first['id'] as String;
    w.copySelection([first]);
    expect(w.clipboard, isNotNull);
    final payload = w.clipboard!;
    expect(
      () => w.pasteClipboard(
        at: Q.of(0),
        expectedRevision: w.current.revision - BigInt.one,
      ),
      code('REVISION_CONFLICT'),
    );
    final db = sqlite3.open('${root.path}/db');
    db.execute(
      "CREATE TRIGGER clip_fail BEFORE INSERT ON events BEGIN SELECT RAISE(ABORT,'fixture'); END",
    );
    final before = w.current.hash, counts = journal(root);
    try {
      expect(
        () => w.pasteClipboard(
          at: Q.fromJson(w.current.toJson()['sequences'][0]['duration']),
          expectedRevision: w.current.revision,
        ),
        throwsA(isA<SqliteException>()),
      );
      expect(w.current.hash, before);
      expect(journal(root), counts);
    } finally {
      db.execute('DROP TRIGGER clip_fail');
      db.dispose();
    }
    final at = Q.fromJson(w.current.toJson()['sequences'][0]['duration']);
    w.pasteClipboard(at: at, expectedRevision: w.current.revision);
    final pasted = w.current.hash;
    expect(
      () => w.pasteClipboard(at: at, expectedRevision: w.current.revision),
      code('COLLISION'),
    );
    expect(w.current.hash, pasted);
    expect(payload.hash, w.clipboard!.hash);
    final repository = DocumentRepository.open(
      '${root.path}/db',
      w.current.namespace,
    );
    try {
      repository.acquireWriter(
        w.projectId,
        'fixture-other',
        expectedEpoch: repository.writerEpoch(w.projectId),
      );
      expect(
        () => w.cutSelection([first], expectedRevision: w.current.revision),
        code('WRITER_FENCED'),
      );
      w.openDemo();
    } finally {
      repository.close();
    }
    expect(w.clipboard, isNull); // project reopen clears the internal clipboard
    expect(
      () => w.pasteClipboard(at: Q.of(3), expectedRevision: w.current.revision),
      code('CLIPBOARD_EMPTY'),
    );
  });
}
