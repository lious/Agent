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
    (p.toJson()['sequences'] as List).cast<Map>().singleWhere((s) => s['id'] == id);

String videoId(ProjectDocument p) {
  for (final t in p.toJson()['sequences'][0]['tracks']) {
    if (t['kind'] != 'video') continue;
    for (final c in t['items']) {
      if (c['source'] != null) return c['id'] as String;
    }
  }
  throw StateError('no video');
}

String? audioId(ProjectDocument p) {
  for (final t in p.toJson()['sequences'][0]['tracks']) {
    if (t['kind'] != 'audio') continue;
    for (final c in t['items']) {
      if (c['source'] != null) return c['id'] as String;
    }
  }
  return null;
}

void main() {
  var serial = 0;
  ProjectDocument edit(ProjectDocument p, EditOperation op) => applyEdit(
    p,
    op,
    newId: () => 'cmp-${serial++}',
    nextVersion: (_) => '${serial++}',
  );

  setUp(() => serial = 0);

  test('A+B become a pinned nest; C stays; child starts are rebased; holes are explicit gaps', () {
    var p = avFixture();
    final id = videoId(p);
    p = edit(p, SplitClip(id, Q.of(1), 'mid'));
    p = edit(p, SplitClip('mid', Q.of(2), 'right'));
    final startHash = content(p);
    final after = edit(p, MakeCompound([id, 'mid'], 'seq-compound', 'AB'));
    expect(content(p), startHash);
    requireLocalEditingWritable(after);

    final child = sequenceOf(after, 'seq-compound');
    expect(Q.fromJson(child['duration']), Q.of(2));
    expect(child['version'], isNotEmpty);
    final moved = [
      for (final t in child['tracks'] as List)
        for (final c in t['items'] as List)
          if (c['source'] != null) c as Map,
    ];
    expect(moved.map((c) => c['id']).toSet(), {id, 'mid'});
    expect(Q.fromJson(moved.singleWhere((c) => c['id'] == id)['timelineRange']['start']), Q.of(0));
    expect(Q.fromJson(moved.singleWhere((c) => c['id'] == 'mid')['timelineRange']['start']), Q.of(1));

    final root = sequenceOf(after, after.toJson()['rootSequenceId'] as String);
    final videoItems = (root['tracks'] as List)
        .cast<Map>()
        .singleWhere((t) => t['kind'] == 'video')['items'] as List;
    final nest = videoItems.cast<Map>().singleWhere(
      (c) => c['source'] != null && c['source']['kind'] == 'sequence',
    );
    expect(nest['source']['id'], 'seq-compound');
    expect(nest['source']['version'], child['version']);
    expect(nest['source']['streamId'], isNull);
    expect(Q.fromJson(nest['timelineRange']['start']), Q.of(0));
    expect(Q.fromJson(nest['timelineRange']['duration']), Q.of(2));
    expect(Q.fromJson(nest['sourceRange']['duration']), Q.of(2));
    expect(clipOf(after, 'right')['id'], 'right');
    expect(Q.fromJson(clipOf(after, 'right')['timelineRange']['start']), Q.of(2));
    expect(
      videoItems.where((c) => (c as Map)['source'] == null).map((c) => Q.fromJson((c as Map)['timelineRange']['start'])),
      isEmpty,
    );
  });

  test('an external AV link must be unlinked or fully included; include keeps sync', () {
    var p = avFixture();
    p = edit(p, ExtractAudioClip(videoId(p), 'audio-stream'));
    final v = videoId(p);
    final a = audioId(p)!;
    final group = clipOf(p, v)['linkGroupId'] as String;
    final before = content(p);
    expect(
      () => edit(p, MakeCompound([v], 'seq-partial', 'Video only')),
      throwsCode(compoundExternalLink),
    );
    expect(content(p), before);

    final included = edit(p, MakeCompound([v, a], 'seq-linked', 'AV'));
    requireLocalEditingWritable(included);
    expect(clipOf(included, v)['linkGroupId'], group);
    expect(clipOf(included, a)['linkGroupId'], group);
    expect(sequenceOf(included, 'seq-linked')['tracks'], hasLength(2));
    final nests = [
      for (final t in sequenceOf(included, included.toJson()['rootSequenceId'] as String)['tracks'] as List)
        for (final c in t['items'] as List)
          if (c['source'] != null && c['source']['kind'] == 'sequence') c as Map,
    ];
    expect(nests, hasLength(2));
    expect(nests[0]['linkGroupId'], nests[1]['linkGroupId']);
    expect(nests[0]['linkGroupId'], isNotNull);
    final policy = (included.toJson()['linkGroups'] as List)
        .cast<Map>()
        .singleWhere((g) => g['id'] == nests[0]['linkGroupId']);
    expect(policy['syncPolicy'], 'preserve');
  });

  test('unlinking first allows compounding only the video; the audio partner stays on the parent', () {
    var p = avFixture();
    p = edit(p, ExtractAudioClip(videoId(p), 'audio-stream'));
    final v = videoId(p);
    final a = audioId(p)!;
    final group = clipOf(p, v)['linkGroupId'] as String;
    p = edit(p, UnlinkAudioVideo(group));
    final after = edit(p, MakeCompound([v], 'seq-video', 'Video'));
    requireLocalEditingWritable(after);
    expect(clipOf(after, v)['source']['kind'], 'asset');
    expect(sequenceOf(after, 'seq-video')['tracks'], hasLength(1));
    expect(clipOf(after, a)['source']['kind'], 'asset');
    expect(
      sequenceOf(after, after.toJson()['rootSequenceId'] as String)['tracks']
          .where((t) => t['kind'] == 'audio')
          .expand((t) => t['items'] as List)
          .any((c) => c['id'] == a),
      isTrue,
    );
  });

  test('a locked host track refuses the compound without a half-write', () {
    var p = avFixture();
    final id = videoId(p);
    final d = p.toJson();
    d['sequences'][0]['tracks'][0]['locked'] = true;
    p = ProjectDocument.fromJson(d);
    final before = content(p);
    expect(
      () => edit(p, MakeCompound([id], 'seq-locked', 'Locked')),
      throwsCode('FIELD_LOCKED'),
    );
    expect(content(p), before);
  });

  test('nest depth greater than 8 is refused and optical-flow remains unclaimed', () {
    var p = avFixture();
    var current = videoId(p);
    for (var i = 0; i < 7; i++) {
      p = edit(p, MakeCompound([current], 'seq-depth-$i', 'D$i'));
      current = [
        for (final t in sequenceOf(p, p.toJson()['rootSequenceId'] as String)['tracks'] as List)
          for (final c in t['items'] as List)
            if (c['source'] != null && c['source']['kind'] == 'sequence') c['id'] as String,
      ].single;
      requireLocalEditingWritable(p);
    }
    final before = content(p);
    expect(
      () => edit(p, MakeCompound([current], 'seq-depth-7', 'Too deep')),
      throwsCode(nestDepth),
    );
    expect(content(p), before);
    expect(() => RetimeMap.piecewise(
      knots: [RetimeKnot(Q.of(0), Q.of(0)), RetimeKnot(Q.of(1), Q.of(1))],
      interpolation: 'opticalFlow',
    ), throwsCode(retimeInterpUnsupported));
  });
}
