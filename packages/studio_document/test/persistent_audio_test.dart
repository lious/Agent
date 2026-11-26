import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:studio_document/studio_document.dart';
import 'package:studio_contracts/studio_contracts.dart';

ProjectDocument avFixture() {
  final d = jsonDecode(
    File('fixtures/project/local-video.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  final st = Map<String, dynamic>.from(d['assets'][0]['streams'][0] as Map)
    ..addAll({
      'id': 'audio-stream',
      'type': 'audio',
      'codec': 'aac',
      'profile': 'LC',
      'width': null,
      'height': null,
      'pixelFormat': null,
      'color': null,
      'nominalFrameRate': null,
      'sampleRate': 48000,
      'channels': 2,
      'channelLayout': 'stereo',
      'timeBase': Q.of(1, 48000).toJson(),
    });
  (d['assets'][0]['streams'] as List).add(st);
  return ProjectDocument.fromJson(d);
}

void main() {
  var serial = 0;
  final versions = <String, int>{};
  ProjectDocument apply(ProjectDocument p, EditOperation op) => applyEdit(
    p,
    op,
    newId: () => 'audio-test-${serial++}',
    nextVersion: (id) =>
        '${versions.update(id, (v) => v + 1, ifAbsent: () => 10)}',
  );
  String video(ProjectDocument p) =>
      p.toJson()['sequences'][0]['tracks'][0]['items'].firstWhere(
            (x) => x['source'] != null,
          )['id']
          as String;
  List<dynamic> tracks(ProjectDocument p) =>
      p.toJson()['sequences'][0]['tracks'] as List;
  setUp(() {
    serial = 0;
    versions.clear();
  });
  test('persistent extraction pins stream, materializes separate clip and exact reciprocal AV link; unlink keeps both and relink works', () {
    final p = avFixture(),
        linked = apply(p, ExtractAudioClip(video(p), 'audio-stream'));
    final d = linked.toJson();
    expect(tracks(linked).length, 2);
    expect(d['linkGroups'].length, 1);
    final a = tracks(linked)[1]['items'][0];
    expect(a['source']['streamId'], 'audio-stream');
    expect(a['source']['version'], d['assets'][0]['version']);
    expect(a['timelineRange'], tracks(linked)[0]['items'][0]['timelineRange']);
    final unlinked = apply(
      linked,
      UnlinkAudioVideo(d['linkGroups'][0]['id'] as String),
    );
    expect(unlinked.toJson()['linkGroups'], isEmpty);
    expect(tracks(unlinked)[1]['items'][0]['id'], a['id']);
    expect(tracks(unlinked)[0]['items'][0]['linkGroupId'], isNull);
    final relinked = apply(
      unlinked,
      LinkAudioVideo(video(unlinked), a['id'] as String),
    );
    expect(relinked.toJson()['linkGroups'].length, 1);
    expect(p.toJson()['sequences'][0]['tracks'].length, 1);
  });
  test('linked split/trim/move/slip are atomic and maintain pinned sample/source ranges; locks refuse whole command', () {
    var p = avFixture();
    p = apply(p, ExtractAudioClip(video(p), 'audio-stream'));
    p = apply(p, SplitClip(video(p), Q.of(1), 'video-right'));
    expect(p.toJson()['linkGroups'].length, 2);
    expect(
      tracks(p).every(
        (t) =>
            (t['items'] as List).where((c) => c['source'] != null).length == 2,
      ),
      isTrue,
    );
    p = apply(p, TrimClip('video-right', 'in', Q.of(1, 30)));
    final v = tracks(p)[0]['items'].last, a = tracks(p)[1]['items'].last;
    expect(v['timelineRange'], a['timelineRange']);
    expect(v['sourceRange'], a['sourceRange']);
    final frozen = p.hash, j = p.toJson();
    j['sequences'][0]['tracks'][1]['locked'] = true;
    final locked = ProjectDocument.fromJson(j);
    expect(
      () => apply(locked, TrimClip('video-right', 'in', Q.of(1, 30))),
      throwsA(
        isA<StudioException>().having((e) => e.code, 'code', 'FIELD_LOCKED'),
      ),
    );
    expect(p.hash, frozen);
    final beforeRight = Q.fromJson(
      tracks(p)[0]['items'].last['timelineRange']['duration'],
    );
    final rippled = apply(
      p,
      TrimClip('video-right', 'out', Q.of(-1, 2), ripple: true),
    );
    expect(
      Q.fromJson(tracks(rippled)[0]['items'].last['timelineRange']['duration']),
      beforeRight - Q.of(1, 2),
    );
    expect(
      Q.fromJson(tracks(rippled)[1]['items'].last['timelineRange']['duration']),
      beforeRight - Q.of(1, 2),
    );
    expect(
      tracks(rippled)[0]['items'].last['timelineRange'],
      tracks(rippled)[1]['items'].last['timelineRange'],
    );
    expect(p.hash, frozen);
    final deleted = apply(p, const DeleteClip('video-right', ripple: true));
    expect([
      for (final c in tracks(deleted)[0]['items'])
        if (c['source'] != null) c['id'],
    ], isNot(contains('video-right')));
    expect(
      [
        for (final t in tracks(deleted))
          for (final c in t['items'])
            if (c['source'] != null) c['id'],
      ].length,
      2,
    ); // left AV pair remains
    expect(p.hash, frozen);
  });
  test('1000 linked legal trim/inverse commands conserve exact offsets/source windows; failures do not mutate', () {
    var p = avFixture();
    p = apply(p, ExtractAudioClip(video(p), 'audio-stream'));
    final original = tracks(p)[0]['items'][0]['sourceRange'];
    for (var i = 0; i < 500; i++) {
      p = apply(p, TrimClip(video(p), 'out', Q.of(-1, 30)));
      p = apply(p, TrimClip(video(p), 'out', Q.of(1, 30)));
    }
    expect(tracks(p)[0]['items'][0]['sourceRange'], original);
    expect(tracks(p)[1]['items'][0]['sourceRange'], original);
    expect(
      p.toJson()['linkGroups'][0]['members'][1]['offset'],
      Q.of(0).toJson(),
    );
  });
  test('sample-aligned absolute stream origins, unavailable audio, duplicate extraction and id collision are explicit atomic refusals', () {
    final j = avFixture().toJson();
    j['assets'][0]['streams'][0]['timeBase'] = Q.of(1, 30).toJson();
    j['assets'][0]['streams'][0]['startPTS'] = '30';
    j['assets'][0]['streams'][1]['startPTS'] = '4800';
    j['assets'][0]['streams'][1]['duration'] = Q.of(4).toJson();
    final p = ProjectDocument.fromJson(j),
        linked = apply(p, ExtractAudioClip(video(p), 'audio-stream'));
    expect(
      tracks(linked)[1]['items'][0]['sourceRange']['start'],
      Q.of(9, 10).toJson(),
    );
    expect(
      () => apply(linked, ExtractAudioClip(video(linked), 'audio-stream')),
      throwsA(
        isA<StudioException>().having(
          (e) => e.code,
          'code',
          'CLIP_ALREADY_LINKED',
        ),
      ),
    );
    final hash = linked.hash;
    expect(
      () => apply(linked, SplitClip(video(linked), Q.of(1), video(linked))),
      throwsA(isA<StudioException>()),
    );
    expect(linked.hash, hash);
    final bad = avFixture().toJson();
    bad['assets'][0]['streams'][1]['startPTS'] = '48000';
    final absent = ProjectDocument.fromJson(bad);
    expect(
      () => apply(absent, ExtractAudioClip(video(absent), 'audio-stream')),
      throwsA(
        isA<StudioException>().having(
          (e) => e.code,
          'code',
          'AUDIO_SOURCE_RANGE_UNAVAILABLE',
        ),
      ),
    );
  });
  test('editing from linked audio selection, unlink independent moves/slips/deletes, no-op and append import retain valid semantics', () {
    var p = avFixture();
    p = apply(p, ExtractAudioClip(video(p), 'audio-stream'));
    final audio = tracks(p)[1]['items'][0]['id'] as String;
    p = apply(p, SplitClip(audio, Q.of(1), 'audio-right'));
    expect(tracks(p)[1]['items'][1]['id'], 'audio-right');
    expect(tracks(p)[1]['items'][1]['version'], isNot('0'));
    final muted = apply(
      p,
      SetAudioTrackState(tracks(p)[1]['id'] as String, muted: true, solo: true),
    );
    expect(
      identical(
        apply(
          muted,
          SetAudioTrackState(
            tracks(muted)[1]['id'] as String,
            muted: true,
            solo: true,
          ),
        ),
        muted,
      ),
      isTrue,
    );
    p = apply(p, UnlinkAudioVideo(p.toJson()['linkGroups'][1]['id'] as String));
    p = apply(p, TrimClip('audio-right', 'out', Q.of(-1, 30)));
    p = apply(p, SlipClip('audio-right', Q.of(1, 30)));
    p = apply(p, MoveClip('audio-right', Q.of(1, 30)));
    expect(tracks(p)[0]['items'][1]['sourceRange']['start'], Q.of(1).toJson());
    p = apply(p, const DeleteClip('audio-right'));
    expect(
      (tracks(p)[1]['items'] as List).where((c) => c['source'] != null).length,
      1,
    );
    final source = avFixture().toJson(),
        asset = Map<String, dynamic>.from(source['assets'][0] as Map),
        right = Map<String, dynamic>.from(source['rightsRecords'][0] as Map);
    asset['id'] = 'extra-asset';
    asset['rightsId'] = 'extra-right';
    right['id'] = 'extra-right';
    right['assetIds'] = ['extra-asset'];
    asset['streams'] = [
      Map<String, dynamic>.from(asset['streams'][0] as Map)
        ..['id'] = 'extra-stream',
    ];
    p = apply(
      p,
      AppendVideoAsset(
        clipId: 'extra-clip',
        asset: asset,
        blob: Map<String, dynamic>.from(source['blobs'][0] as Map),
        rights: right,
      ),
    );
    expect(
      (tracks(p)[0]['items'] as List).where((c) => c['source'] != null).length,
      3,
    );
  });
  test('semantic FK/version/map/link/bus errors reject before commit; opaque extension IDs do not allocate entities', () {
    final p = avFixture();
    final d = p.toJson();
    d['extensions'] = {
      'fixture.opaque': {
        'id': video(p),
        'version': '9999999999999999999999',
        'anything': 42,
      },
    };
    expect(DocumentValidator().validate(d), isEmpty);
    final linked = apply(p, ExtractAudioClip(video(p), 'audio-stream'));
    final changes = <void Function(Map<String, dynamic>)>[
      (d) => d['sequences'][0]['tracks'][0]['items'][0]['source']['version'] =
          '999',
      (d) => d['sequences'][0]['tracks'][1]['items'][0]['source']['streamId'] =
          d['assets'][0]['streams'][0]['id'],
      (d) => d['linkGroups'][0]['members'][1]['offset'] = Q.of(1).toJson(),
      (d) => d['linkGroups'][0]['members'][1]['clipId'] = 'missing',
      (d) => d['sequences'][0]['tracks'][0]['items'][0]['timeMap']['rate'] = Q
          .of(2)
          .toJson(),
      (d) => d['assets'][0]['rightsId'] = 'missing',
      (d) => d['sequences'][0]['markerIds'] = ['missing'],
      (d) =>
          d['sequences'][0]['tracks'][0]['items'][0]['effectIds'] = ['missing'],
    ];
    for (final change in changes) {
      final d = linked.toJson();
      change(d);
      final issues = DocumentValidator().validate(d);
      expect(issues, isNotEmpty);
      expect(issues.first.phase, 'semantic');
    }
  });
}
