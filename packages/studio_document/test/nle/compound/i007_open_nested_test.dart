import 'dart:convert';

import 'package:studio_contracts/studio_contracts.dart';
import 'package:studio_document/studio_document.dart';
import 'package:test/test.dart';

import '../../persistent_audio_test.dart' show avFixture;

Matcher throwsCode(String code) =>
    throwsA(isA<StudioException>().having((e) => e.code, 'code', code));

String content(ProjectDocument p) =>
    contentHash(p.toJson()..remove('revision'));

Map clipOf(ProjectDocument p, String id) {
  for (final s in p.toJson()['sequences'] as List) {
    for (final t in s['tracks'] as List) {
      for (final c in t['items'] as List) {
        if (c['id'] == id) return c as Map;
      }
    }
  }
  throw StateError('missing $id');
}

Map sequenceOf(ProjectDocument p, String id) =>
    (p.toJson()['sequences'] as List).cast<Map>().singleWhere(
      (s) => s['id'] == id,
    );

Map trackOf(ProjectDocument p, String kind, {String? sequenceId}) {
  final sid = sequenceId ?? p.toJson()['rootSequenceId'] as String;
  return (sequenceOf(p, sid)['tracks'] as List).cast<Map>().singleWhere(
    (t) => t['kind'] == kind,
  );
}

String videoId(ProjectDocument p) {
  for (final c in trackOf(p, 'video')['items'] as List) {
    if (c['source'] != null) return c['id'] as String;
  }
  throw StateError('no video');
}

String nestId(ProjectDocument p) {
  for (final c in trackOf(p, 'video')['items'] as List) {
    if (c['source'] != null && c['source']['kind'] == 'sequence') {
      return c['id'] as String;
    }
  }
  throw StateError('no nest');
}

Q startOfItem(Map c) => Q.fromJson(c['timelineRange']['start']);
Q durationOfItem(Map c) => Q.fromJson(c['timelineRange']['duration']);

/// Retain the current project definition, then advance the live child.
/// Returns snapshot bytes keyed by definitionBlobHash. This is not
/// OpenNested persist of in-child edits, and is not an edit surface.
({ProjectDocument project, Map<String, List<int>> snapshots})
retainAndBumpChild(
  ProjectDocument p, {
  required String sequenceId,
  required String newVersion,
  required Q newDuration,
}) {
  final raw = utf8.encode(p.canonicalJson);
  final hash = rawBytesHash(raw);
  final d = jsonDecode(jsonEncode(p.toJson())) as Map<String, dynamic>;
  final child = (d['sequences'] as List).cast<Map>().singleWhere(
    (s) => s['id'] == sequenceId,
  );
  final fromVersion = child['version'] as String;
  (d['blobs'] as List).add({
    'hash': hash,
    'bytes': raw.length.toString(),
    'mime': 'application/json',
    'role': 'snapshot',
    'packagePath': 'snapshots/${hash.substring(7)}',
  });
  (d['retainedSources'] as List).add({
    'kind': 'sequence',
    'id': sequenceId,
    'version': fromVersion,
    'definitionBlobHash': hash,
    'dependencyBlobHashes': [
      for (final b in d['blobs'] as List)
        if (b['role'] == 'original') b['hash'] as String,
    ],
  });

  Q start(Map c) => Q.fromJson(c['timelineRange']['start']);
  Q dur(Map c) => Q.fromJson(c['timelineRange']['duration']);
  var serial = 0;
  for (final track in child['tracks'] as List) {
    for (final item in track['items'] as List) {
      if (item['source'] == null) continue;
      final end = start(item as Map) + dur(item);
      if (end > newDuration) {
        final keep = newDuration - start(item);
        if (keep <= Q.of(0)) {
          throw StateError('cannot shrink past item start');
        }
        item['timelineRange']['duration'] = keep.toJson();
        item['sourceRange']['duration'] = keep.toJson();
      }
    }
    track['items'] = [
      for (final item in track['items'] as List)
        if (start(item as Map) < newDuration) item,
    ];
    var cover = Q.of(0);
    for (final item in track['items'] as List) {
      final end = start(item as Map) + dur(item);
      if (end > cover) cover = end;
    }
    if (cover < newDuration) {
      (track['items'] as List).add({
        'id': 'retain-gap-${serial++}',
        'trackId': track['id'],
        'timelineRange': {
          'start': cover.toJson(),
          'duration': (newDuration - cover).toJson(),
        },
      });
    }
  }
  child['duration'] = newDuration.toJson();
  child['version'] = newVersion;
  final next = ProjectDocument.fromJson(d);
  requireLocalEditingWritable(next);
  return (project: next, snapshots: {hash: raw});
}

void main() {
  var serial = 0;
  ProjectDocument edit(ProjectDocument p, EditOperation op) => applyEdit(
    p,
    op,
    newId: () => 'open-${serial++}',
    nextVersion: (_) => '${serial++}',
  );

  setUp(() => serial = 0);

  ProjectDocument packedCompound() {
    var p = avFixture();
    final id = videoId(p);
    p = edit(p, SplitClip(id, Q.of(1), 'mid'));
    p = edit(p, SplitClip('mid', Q.of(2), 'right'));
    return edit(p, MakeCompound([id, 'mid'], 'seq-compound', 'AB'));
  }

  test('opening a live-pinned nest returns the child timeline and does not mutate the project', () {
    final p = packedCompound();
    final nest = nestId(p);
    final child = sequenceOf(p, 'seq-compound');
    final startHash = content(p);
    final raw = jsonEncode(p.toJson());
    final opened = openNested(p, nest);
    expect(content(p), startHash);
    expect(jsonEncode(p.toJson()), raw);
    expect(opened.clipId, nest);
    expect(opened.sequenceId, 'seq-compound');
    expect(opened.version, child['version']);
    expect(opened.fromRetainedSource, isFalse);
    expect(opened.duration, Q.of(2));
    final moved = [
      for (final t in opened.sequence['tracks'] as List)
        for (final c in t['items'] as List)
          if (c['source'] != null) c as Map,
    ];
    expect(moved, hasLength(2));
    expect(startOfItem(moved.first), Q.of(0));
    // Mutating the returned map must not write back into the project.
    opened.sequence['duration'] = Q.of(9).toJson();
    expect(Q.fromJson(sequenceOf(p, 'seq-compound')['duration']), Q.of(2));
    expect(content(p), startHash);
  });

  test('opening a historical pin shows the retained child, not the live v2 duration, and does not auto-follow', () {
    var p = packedCompound();
    final nest = nestId(p);
    final from = clipOf(p, nest)['source']['version'] as String;
    final beforeDuration = Q.fromJson(
      sequenceOf(p, 'seq-compound')['duration'],
    );
    expect(beforeDuration, Q.of(2));
    final bumped = retainAndBumpChild(
      p,
      sequenceId: 'seq-compound',
      newVersion: '100',
      newDuration: Q.of(5, 2),
    );
    p = bumped.project;
    expect(clipOf(p, nest)['source']['version'], from);
    expect(Q.fromJson(sequenceOf(p, 'seq-compound')['duration']), Q.of(5, 2));
    expect(sequenceOf(p, 'seq-compound')['version'], '100');

    final startHash = content(p);
    final opened = openNested(p, nest, snapshotBytes: bumped.snapshots);
    expect(content(p), startHash);
    expect(opened.version, from);
    expect(opened.fromRetainedSource, isTrue);
    expect(opened.duration, Q.of(2));
    expect(opened.duration, isNot(Q.of(5, 2)));
    expect(clipOf(p, nest)['source']['version'], from);
  });

  test('after UpgradeNest, opening the upgraded pin shows the live child; a non-nest clip is refused', () {
    var p = packedCompound();
    final nest = nestId(p);
    final from = clipOf(p, nest)['source']['version'] as String;
    final bumped = retainAndBumpChild(
      p,
      sequenceId: 'seq-compound',
      newVersion: '100',
      newDuration: Q.of(5, 2),
    );
    p = bumped.project;
    p = edit(p, UpgradeNest([nest], from, '100', lengthPolicy: 'fit'));
    expect(clipOf(p, nest)['source']['version'], '100');

    final startHash = content(p);
    final opened = openNested(p, nest);
    expect(content(p), startHash);
    expect(opened.version, '100');
    expect(opened.fromRetainedSource, isFalse);
    expect(opened.duration, Q.of(5, 2));

    // A historical open without bytes still refuses and does not write.
    // Re-pin is already at v100; use the retained hash against a stale request
    // by opening is not possible on this clip. Opening a non-nest is refused.
    final media = videoId(packedCompound());
    expect(
      () => openNested(packedCompound(), media),
      throwsCode('CLIP_NOT_FOUND'),
    );
    expect(
      () => openNested(p, 'missing-clip-id-0001'),
      throwsCode('CLIP_NOT_FOUND'),
    );
  });

  test('a historical pin without snapshot bytes or with a bad hash is refused and leaves the document unchanged', () {
    var p = packedCompound();
    final nest = nestId(p);
    final bumped = retainAndBumpChild(
      p,
      sequenceId: 'seq-compound',
      newVersion: '100',
      newDuration: Q.of(5, 2),
    );
    p = bumped.project;
    final startHash = content(p);
    final raw = jsonEncode(p.toJson());
    expect(() => openNested(p, nest), throwsCode('RESOURCE_BYTES_MISSING'));
    expect(content(p), startHash);
    expect(jsonEncode(p.toJson()), raw);

    final hash = bumped.snapshots.keys.single;
    expect(
      () => openNested(
        p,
        nest,
        snapshotBytes: {hash: utf8.encode('not-a-snapshot')},
      ),
      throwsCode('BLOB_HASH_MISMATCH'),
    );
    expect(content(p), startHash);
  });
}
