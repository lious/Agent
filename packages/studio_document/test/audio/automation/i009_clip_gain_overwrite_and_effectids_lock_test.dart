import 'dart:convert';
import 'dart:io';

import 'package:studio_contracts/studio_contracts.dart';
import 'package:studio_document/studio_document.dart';
import 'package:test/test.dart';

Matcher code(String value) =>
    throwsA(isA<StudioException>().having((e) => e.code, 'code', value));

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
    newId: () => 'i009-gain-cov-${serial++}',
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
  String audioClipId(ProjectDocument p) =>
      tracks(p)
              .singleWhere((t) => t['kind'] == 'audio')['items']
              .firstWhere((x) => x['source'] != null)['id']
          as String;
  Map clipById(ProjectDocument p, String id) {
    for (final t in tracks(p)) {
      for (final c in t['items']) {
        if (c['id'] == id) return c as Map;
      }
    }
    throw StateError('missing clip $id');
  }

  List<Map> audioMedia(ProjectDocument p) => [
    for (final c in tracks(p).singleWhere((t) => t['kind'] == 'audio')['items'])
      if (c['source'] != null) c as Map,
  ];

  Map gainEffect(ProjectDocument p, String clipId) {
    final ids = clipById(p, clipId)['effectIds'] as List;
    return (p.toJson()['effects'] as List).singleWhere(
      (e) => ids.contains(e['id']) && e['type'] == 'gain',
    ) as Map;
  }

  ProjectDocument extractedUnlinked() {
    var p = apply(
      avFixture(),
      ExtractAudioClip(video(avFixture()), 'audio-stream'),
    );
    final linkId = p.toJson()['linkGroups'][0]['id'] as String;
    return apply(p, UnlinkAudioVideo(linkId));
  }

  setUp(() {
    serial = 0;
    versions.clear();
  });

  test(
    'official overwrite paste crops a destination gain curve with param gainDb',
    () {
      var p = extractedUnlinked();
      final destId = audioClipId(p);
      p = apply(p, SetGainKeyframe(destId, Q.of(0), -6));
      p = apply(p, SetGainKeyframe(destId, Q.of(3), 0));
      final beforeEffect = gainEffect(p, destId);
      expect(
        (beforeEffect['keyframes'] as List).every(
          (k) => k['param'] == 'gainDb',
        ),
        isTrue,
      );
      final payload = buildClipboard(p, [destId]);
      p = apply(p, PasteClips(payload, at: Q.of(1), mode: 'overwrite'));
      final clips = audioMedia(p);
      expect(clips, hasLength(2));
      final left = clips.singleWhere((c) => c['id'] == destId);
      final incoming = clips.singleWhere((c) => c['id'] != destId);
      expect(Q.fromJson(left['timelineRange']['start']), Q.of(0));
      expect(Q.fromJson(left['timelineRange']['duration']), Q.of(1));
      expect(Q.fromJson(incoming['timelineRange']['start']), Q.of(1));
      expect(Q.fromJson(incoming['timelineRange']['duration']), Q.of(3));
      final leftFx = gainEffect(p, left['id'] as String);
      final incomingFx = gainEffect(p, incoming['id'] as String);
      expect(leftFx['id'], isNot(incomingFx['id']));
      expect(leftFx['type'], 'gain');
      expect(incomingFx['type'], 'gain');
      expect(leftFx['owner']['id'], left['id']);
      expect(incomingFx['owner']['id'], incoming['id']);
      final leftKeys = leftFx['keyframes'] as List;
      final incomingKeys = incomingFx['keyframes'] as List;
      expect(leftKeys, isNotEmpty);
      expect(incomingKeys, isNotEmpty);
      for (final k in [...leftKeys, ...incomingKeys]) {
        expect(k['param'], 'gainDb');
      }
      expect(Q.fromJson(leftKeys.first['localTime']), Q.of(0));
      expect((leftKeys.first['value'] as num).toDouble(), closeTo(-6, 1e-9));
      expect(Q.fromJson(leftKeys.last['localTime']), Q.of(1));
      expect((leftKeys.last['value'] as num).toDouble(), closeTo(-4, 1e-9));
      expect(Q.fromJson(incomingKeys.first['localTime']), Q.of(0));
      expect(
        (incomingKeys.first['value'] as num).toDouble(),
        closeTo(-6, 1e-9),
      );
      expect(Q.fromJson(incomingKeys.last['localTime']), Q.of(3));
      expect((incomingKeys.last['value'] as num).toDouble(), closeTo(0, 1e-9));
    },
  );

  test('effectIds.* lockedFields refuse gain edits, official analysis, and overwrite crop as a group', () {
    var p = extractedUnlinked();
    final id = audioClipId(p);
    p = apply(p, SetGainKeyframe(id, Q.of(0), -3, interpolation: 'hold'));
    p = apply(p, SetGainKeyframe(id, Q.of(3), -3));
    final eid = gainEffect(p, id)['id'] as String;
    final speech = [TimeRange(Q.of(1), Q.of(1))];
    final payload = buildClipboard(p, [id]);
    for (final field in ['effectIds.$eid', 'effectIds.gain']) {
      final d = p.toJson();
      for (final t in d['sequences'][0]['tracks']) {
        for (final c in t['items']) {
          if (c['id'] == id) c['lockedFields'] = [field];
        }
      }
      final gated = ProjectDocument.fromJson(d);
      final before = jsonEncode(gated.toJson());
      expect(
        () => apply(gated, SetGainKeyframe(id, Q.of(1), -9)),
        code('FIELD_LOCKED'),
        reason: field,
      );
      expect(
        () => apply(gated, RemoveGainKeyframe(id, Q.of(3))),
        code('FIELD_LOCKED'),
        reason: field,
      );
      expect(
        () => apply(gated, SetClipGain(id, -9)),
        code('FIELD_LOCKED'),
        reason: field,
      );
      expect(
        () => applyOfficialClipAnalysis(
          project: gated.toJson(),
          clipId: id,
          speech: speech,
        ),
        code('MANUAL_LOCKED'),
        reason: field,
      );
      expect(
        () => apply(gated, PasteClips(payload, at: Q.of(1), mode: 'overwrite')),
        code('FIELD_LOCKED'),
        reason: field,
      );
      expect(jsonEncode(gated.toJson()), before, reason: field);
    }
  });
}
