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

Q startOf(ProjectDocument p, String id) =>
    Q.fromJson(clipOf(p, id)['timelineRange']['start']);

Q durationOf(ProjectDocument p, String id) =>
    Q.fromJson(clipOf(p, id)['timelineRange']['duration']);

Q sourceDurationOf(ProjectDocument p, String id) =>
    Q.fromJson(clipOf(p, id)['sourceRange']['duration']);

Q rateOf(ProjectDocument p, String id) =>
    Q.fromJson(clipOf(p, id)['timeMap']['rate']);

/// Pin the live child at [newVersion] with [newDuration], retaining the
/// current definition so existing nest pins keep working. This is a legal
/// retainedSources fixture, not OpenNested persist.
ProjectDocument retainAndBumpChild(
  ProjectDocument p, {
  required String sequenceId,
  required String newVersion,
  required Q newDuration,
}) {
  final d = jsonDecode(jsonEncode(p.toJson())) as Map<String, dynamic>;
  final child = (d['sequences'] as List).cast<Map>().singleWhere(
    (s) => s['id'] == sequenceId,
  );
  final fromVersion = child['version'] as String;
  final snapshot = utf8.encode(jsonEncode(child));
  final hash = rawBytesHash(snapshot);
  (d['blobs'] as List).add({
    'hash': hash,
    'bytes': snapshot.length.toString(),
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
    // Drop gaps that now sit entirely past the new end.
    track['items'] = [
      for (final item in track['items'] as List)
        if (start(item as Map) < newDuration) item,
    ];
  }
  var serial = 0;
  for (final track in child['tracks'] as List) {
    Q cover = Q.of(0);
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
  return next;
}

void main() {
  var serial = 0;
  ProjectDocument edit(ProjectDocument p, EditOperation op) => applyEdit(
    p,
    op,
    newId: () => 'upg-${serial++}',
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

  test('fit keeps timeline duration, retimes to the new child, and leaves a v1 nest unchanged', () {
    var p = packedCompound();
    final nest = nestId(p);
    final from = clipOf(p, nest)['source']['version'] as String;
    expect(durationOf(p, nest), Q.of(2));
    expect(startOf(p, 'right'), Q.of(2));

    // A second nest still pinning v1, placed after a leave-gap copy at 4s
    // so UpgradeNest of the first cannot silently follow it.
    p = retainAndBumpChild(
      p,
      sequenceId: 'seq-compound',
      newVersion: '100',
      newDuration: Q.of(5, 2),
    );
    final d = jsonDecode(jsonEncode(p.toJson())) as Map<String, dynamic>;
    final track = (d['sequences'] as List)
        .cast<Map>()
        .singleWhere((s) => s['id'] == d['rootSequenceId'])['tracks']
        .cast<Map>()
        .singleWhere((t) => t['kind'] == 'video');
    final copy =
        jsonDecode(jsonEncode(clipOf(p, nest))) as Map<String, dynamic>;
    copy['id'] = 'nest-v1-copy';
    copy['version'] = '1';
    copy['linkGroupId'] = null;
    copy['timelineRange'] = {
      'start': Q.of(4).toJson(),
      'duration': Q.of(2).toJson(),
    };
    (track['items'] as List).add({
      'id': 'gap-before-copy',
      'trackId': track['id'],
      'timelineRange': {
        'start': Q.of(3).toJson(),
        'duration': Q.of(1).toJson(),
      },
    });
    (track['items'] as List).add(copy);
    final root = (d['sequences'] as List).cast<Map>().singleWhere(
      (s) => s['id'] == d['rootSequenceId'],
    );
    root['duration'] = Q.of(6).toJson();
    p = ProjectDocument.fromJson(d);
    requireLocalEditingWritable(p);

    final startHash = content(p);
    final after = edit(
      p,
      UpgradeNest([nest], from, '100', lengthPolicy: 'fit'),
    );
    expect(content(p), startHash);
    requireLocalEditingWritable(after);

    expect(clipOf(after, nest)['source']['version'], '100');
    expect(durationOf(after, nest), Q.of(2));
    expect(startOf(after, nest), Q.of(0));
    expect(sourceDurationOf(after, nest), Q.of(5, 2));
    expect(rateOf(after, nest), Q.of(5, 4));
    expect(startOf(after, 'right'), Q.of(2));
    expect(clipOf(after, 'nest-v1-copy')['source']['version'], from);
    expect(durationOf(after, 'nest-v1-copy'), Q.of(2));
    expect(rateOf(after, 'nest-v1-copy'), Q.of(1));
  });

  test('trim keeps the shorter of the old slot and new child and leaves a gap, without moving later clips', () {
    var p = packedCompound();
    final nest = nestId(p);
    final from = clipOf(p, nest)['source']['version'] as String;
    p = retainAndBumpChild(
      p,
      sequenceId: 'seq-compound',
      newVersion: '100',
      newDuration: Q.of(3, 2),
    );
    final after = edit(
      p,
      UpgradeNest([nest], from, '100', lengthPolicy: 'trim'),
    );
    expect(durationOf(after, nest), Q.of(3, 2));
    expect(sourceDurationOf(after, nest), Q.of(3, 2));
    expect(rateOf(after, nest), Q.of(1));
    expect(startOf(after, 'right'), Q.of(2));
    final items = trackOf(after, 'video')['items'] as List;
    final gap = items.cast<Map>().singleWhere(
      (c) =>
          c['source'] == null &&
          Q.fromJson(c['timelineRange']['start']) == Q.of(3, 2),
    );
    expect(Q.fromJson(gap['timelineRange']['duration']), Q.of(1, 2));
    expect(clipOf(after, nest)['source']['version'], '100');
  });

  test('ripple grows the nest to the new child duration and shifts later clips; an explicit list is not auto-expanded', () {
    var p = packedCompound();
    final nest = nestId(p);
    final from = clipOf(p, nest)['source']['version'] as String;
    final videoTrack = trackOf(p, 'video')['id'] as String;
    p = retainAndBumpChild(
      p,
      sequenceId: 'seq-compound',
      newVersion: '100',
      newDuration: Q.of(5, 2),
    );
    final after = edit(
      p,
      UpgradeNest(
        [nest],
        from,
        '100',
        lengthPolicy: 'ripple',
        rippleTrackIds: [videoTrack],
      ),
    );
    expect(durationOf(after, nest), Q.of(5, 2));
    expect(sourceDurationOf(after, nest), Q.of(5, 2));
    expect(rateOf(after, nest), Q.of(1));
    expect(startOf(after, 'right'), Q.of(5, 2));
    expect(clipOf(after, nest)['source']['version'], '100');
  });

  test('a duration change cannot auto-follow: fit/trim/ripple is required, and a partial AV link is refused', () {
    var p = packedCompound();
    final nest = nestId(p);
    final from = clipOf(p, nest)['source']['version'] as String;
    expect(
      () => edit(p, UpgradeNest([nest], from, from, lengthPolicy: 'warp')),
      throwsCode(upgradePolicyUnsupported),
    );

    p = retainAndBumpChild(
      p,
      sequenceId: 'seq-compound',
      newVersion: '100',
      newDuration: Q.of(5, 2),
    );
    expect(
      () => edit(
        p,
        UpgradeNest(
          [nest],
          from,
          '100',
          lengthPolicy: 'fit',
          rippleTrackIds: [trackOf(p, 'video')['id'] as String],
        ),
      ),
      throwsCode(upgradeRippleTracks),
    );
    expect(
      () => edit(p, UpgradeNest([nest], from, '99', lengthPolicy: 'fit')),
      throwsCode('SOURCE_VERSION_MISSING'),
    );

    var linked = avFixture();
    final v = videoId(linked);
    linked = edit(linked, ExtractAudioClip(v, 'audio-stream'));
    final a = [
      for (final c in trackOf(linked, 'audio')['items'] as List)
        if (c['source'] != null) c['id'] as String,
    ].single;
    linked = edit(linked, MakeCompound([v, a], 'seq-av', 'AV'));
    final videoNest = [
      for (final c in trackOf(linked, 'video')['items'] as List)
        if (c['source'] != null && c['source']['kind'] == 'sequence')
          c['id'] as String,
    ].single;
    final fromAv = clipOf(linked, videoNest)['source']['version'] as String;
    linked = retainAndBumpChild(
      linked,
      sequenceId: 'seq-av',
      newVersion: '100',
      newDuration: Q.of(5, 2),
    );
    final before = content(linked);
    expect(
      () => edit(
        linked,
        UpgradeNest([videoNest], fromAv, '100', lengthPolicy: 'fit'),
      ),
      throwsCode(compoundExternalLink),
    );
    expect(content(linked), before);
  });

  test('a locked nest track is FIELD_LOCKED and does not half-write; optical-flow is not a length policy', () {
    var p = packedCompound();
    final nest = nestId(p);
    final from = clipOf(p, nest)['source']['version'] as String;
    p = retainAndBumpChild(
      p,
      sequenceId: 'seq-compound',
      newVersion: '100',
      newDuration: Q.of(5, 2),
    );
    p = edit(
      p,
      SetTrackState(trackOf(p, 'video')['id'] as String, locked: true),
    );
    final before = content(p);
    expect(
      () => edit(p, UpgradeNest([nest], from, '100', lengthPolicy: 'ripple')),
      throwsCode('FIELD_LOCKED'),
    );
    expect(content(p), before);
    expect(clipOf(p, nest)['source']['version'], from);
  });
}
