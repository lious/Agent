import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

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
    newId: () => 'i009-gain-${serial++}',
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
  String audioTrackId(ProjectDocument p) =>
      tracks(p).singleWhere((t) => t['kind'] == 'audio')['id'] as String;
  Map audioClip(ProjectDocument p, [String? id]) {
    final want = id ?? audioClipId(p);
    for (final t in tracks(p)) {
      for (final c in t['items']) {
        if (c['id'] == want) return c as Map;
      }
    }
    throw StateError('missing clip');
  }

  Map? gainEffect(ProjectDocument p, [String? clipId]) {
    final clip = audioClip(p, clipId);
    final ids = clip['effectIds'] as List;
    final matches = (p.toJson()['effects'] as List)
        .where((e) => ids.contains(e['id']) && e['type'] == 'gain')
        .toList();
    return matches.isEmpty ? null : matches.single as Map;
  }

  MixedAudio mixProject(ProjectDocument p, String clipId, Float32List pcm) {
    final d = p.toJson();
    final inputs = compileOfficialMixInputs(
      project: d,
      pcmByClipId: {clipId: pcm},
    );
    return mix48k(
      AudioBusGraph([
        for (final raw in d['audioBuses'] as List)
          AudioBus.fromJson(Map<String, dynamic>.from(raw as Map)),
      ], d['sequences'][0]['masterBusId'] as String),
      inputs,
    );
  }

  setUp(() {
    serial = 0;
    versions.clear();
  });

  test('SetClipGain persists a clip gain Effect; default 0 dB is a no-op', () {
    var p = apply(
      avFixture(),
      ExtractAudioClip(video(avFixture()), 'audio-stream'),
    );
    final id = audioClipId(p);
    final unchanged = apply(p, SetClipGain(id, 0));
    expect(
      identical(unchanged, p) ||
          jsonEncode(unchanged.toJson()) == jsonEncode(p.toJson()),
      isTrue,
    );
    expect((unchanged.toJson()['effects'] as List), isEmpty);
    p = apply(p, SetClipGain(id, -6));
    final effect = gainEffect(p)!;
    expect(effect['type'], 'gain');
    expect(effect['owner'], {'kind': 'clip', 'id': id});
    expect(effect['pluginVersion'], '1.0.0');
    expect(effect['parameters']['gainDb'], -6);
    expect(effect['keyframes'], isEmpty);
    expect(audioClip(p)['effectIds'], [effect['id']]);
    expect(
      () => apply(p, const SetClipGain('missing', -3)),
      code('CLIP_NOT_FOUND'),
    );
    expect(() => apply(p, SetClipGain(id, 13)), code('AUDIO_PARAMETER_RANGE'));
    expect(() => apply(p, SetClipGain(id, -97)), code('AUDIO_PARAMETER_RANGE'));
    expect(
      () => apply(p, SetClipGain(video(p), -6)),
      code('UNSUPPORTED_EDIT_TECHNIQUE'),
    );
  });

  test('SetGainKeyframe writes sample-quantized absolute dB points; SetClipGain refuses an animated curve', () {
    var p = apply(
      avFixture(),
      ExtractAudioClip(video(avFixture()), 'audio-stream'),
    );
    final id = audioClipId(p);
    expect(
      () => apply(p, SetGainKeyframe(id, Q.of(1, 96000), -6)),
      code('KEYFRAME_NOT_ON_SAMPLE'),
    );
    expect(
      () => apply(p, SetGainKeyframe(id, Q.of(4), -6)),
      code('KEYFRAME_OUT_OF_RANGE'),
    );
    expect(
      () => apply(p, SetGainKeyframe(id, Q.of(0), 13)),
      code('AUDIO_PARAMETER_RANGE'),
    );
    p = apply(p, SetGainKeyframe(id, Q.of(0), -6, interpolation: 'hold'));
    p = apply(p, SetGainKeyframe(id, Q.of(1), 0));
    final effect = gainEffect(p)!;
    expect(effect['parameters']['gainDb'], 0);
    final keys = effect['keyframes'] as List;
    expect(keys.length, 2);
    expect(keys[0]['param'], 'gainDb');
    expect(keys[0]['value'], -6);
    expect(keys[0]['interpolation'], 'hold');
    expect(keys[1]['value'], 0);
    expect(keys[1]['interpolation'], 'linear');
    expect(
      () => apply(p, SetClipGain(id, -3)),
      code('ANIMATED_GAIN_REQUIRES_EXPLICIT_KEYFRAME_EDIT'),
    );
    final beforeRemove = jsonEncode(effect);
    p = apply(p, RemoveGainKeyframe(id, Q.of(1)));
    expect((gainEffect(p)!['keyframes'] as List).length, 1);
    expect(
      () => apply(p, RemoveGainKeyframe(id, Q.of(1))),
      code('KEYFRAME_NOT_FOUND'),
    );
    expect(beforeRemove, isNot(jsonEncode(gainEffect(p))));
  });

  test('official mix applies persisted clip gain before the default pan and track/master bus', () {
    var p = apply(
      avFixture(),
      ExtractAudioClip(video(avFixture()), 'audio-stream'),
    );
    final id = audioClipId(p);
    p = apply(p, SetClipGain(id, -6));
    final pcm = Float32List(8)..fillRange(0, 8, 1);
    final inputs = compileOfficialMixInputs(
      project: p.toJson(),
      pcmByClipId: {id: pcm},
    );
    expect(inputs.single.gainDb, -6);
    expect(inputs.single.automation, isNull);
    expect(inputs.single.pan, 0);
    var mixed = mixProject(p, id, pcm);
    expect(mixed.interleavedStereo[0], closeTo(gainAmplitude(-6), 1e-6));
    p = apply(p, const SetMasterAudio(gainDb: -6));
    mixed = mixProject(p, id, pcm);
    expect(mixed.interleavedStereo[0], closeTo(gainAmplitude(-12), 1e-6));
    // Animated points are absolute dB, not multiplied by a leftover static gain.
    var keyed = apply(
      avFixture(),
      ExtractAudioClip(video(avFixture()), 'audio-stream'),
    );
    keyed = apply(
      keyed,
      SetGainKeyframe(audioClipId(keyed), Q.of(0), -12, interpolation: 'hold'),
    );
    final keyedInputs = compileOfficialMixInputs(
      project: keyed.toJson(),
      pcmByClipId: {audioClipId(keyed): pcm},
    );
    expect(keyedInputs.single.gainDb, 0);
    expect(keyedInputs.single.automation, isNotNull);
    expect(keyedInputs.single.sourceAnchored, isFalse);
    mixed = mixProject(keyed, audioClipId(keyed), pcm);
    expect(mixed.interleavedStereo[0], closeTo(gainAmplitude(-12), 1e-6));
  });

  test('split and trim crop gain curves with param gainDb; slip leaves clip-local keys unchanged', () {
    var p = apply(
      avFixture(),
      ExtractAudioClip(video(avFixture()), 'audio-stream'),
    );
    final leftId = audioClipId(p);
    p = apply(p, SetGainKeyframe(leftId, Q.of(0), -6));
    p = apply(p, SetGainKeyframe(leftId, Q.of(2), 0));
    p = apply(p, SplitClip(video(p), Q.of(1), 'video-right'));
    final audioItems = [
      for (final c in tracks(
        p,
      ).singleWhere((t) => t['kind'] == 'audio')['items'])
        if (c['source'] != null) c,
    ];
    expect(audioItems.length, 2);
    final left = audioItems[0] as Map;
    final right = audioItems[1] as Map;
    final leftFx = gainEffect(p, left['id'] as String)!;
    final rightFx = gainEffect(p, right['id'] as String)!;
    expect(leftFx['id'], isNot(rightFx['id']));
    expect(leftFx['owner']['id'], left['id']);
    expect(rightFx['owner']['id'], right['id']);
    final leftKeys = leftFx['keyframes'] as List;
    final rightKeys = rightFx['keyframes'] as List;
    for (final k in [...leftKeys, ...rightKeys]) {
      expect(k['param'], 'gainDb');
    }
    expect(Q.fromJson(leftKeys.first['localTime']), Q.of(0));
    expect((leftKeys.first['value'] as num).toDouble(), closeTo(-6, 1e-9));
    expect(Q.fromJson(leftKeys.last['localTime']), Q.of(1));
    expect((leftKeys.last['value'] as num).toDouble(), closeTo(-3, 1e-9));
    expect(Q.fromJson(rightKeys.first['localTime']), Q.of(0));
    expect((rightKeys.first['value'] as num).toDouble(), closeTo(-3, 1e-9));
    expect(Q.fromJson(rightKeys.last['localTime']), Q.of(2));
    expect((rightKeys.last['value'] as num).toDouble(), closeTo(0, 1e-9));

    final linkId = p.toJson()['linkGroups'][0]['id'] as String;
    p = apply(p, UnlinkAudioVideo(linkId));
    final beforeSlip = jsonEncode(
      gainEffect(p, right['id'] as String)!['keyframes'],
    );
    p = apply(p, SlipClip(right['id'] as String, Q.of(0) - Q.of(1, 48000)));
    expect(
      jsonEncode(gainEffect(p, right['id'] as String)!['keyframes']),
      beforeSlip,
    );

    p = apply(p, TrimClip(left['id'] as String, 'out', Q.of(0) - Q.of(1, 2)));
    final trimmed = gainEffect(p, left['id'] as String)!;
    expect(
      Q.fromJson((trimmed['keyframes'] as List).last['localTime']),
      Q.of(1, 2),
    );
    expect(
      ((trimmed['keyframes'] as List).last['value'] as num).toDouble(),
      closeTo(-4.5, 1e-9),
    );
  });

  test('locked track or locked manual gain fields refuse user edits and official analysis as a group', () {
    var p = apply(
      avFixture(),
      ExtractAudioClip(video(avFixture()), 'audio-stream'),
    );
    final id = audioClipId(p);
    p = apply(p, SetGainKeyframe(id, Q.of(0), -3, interpolation: 'hold'));
    p = apply(p, SetGainKeyframe(id, Q.of(2), -3));
    final speech = [TimeRange(Q.of(1), Q.of(1))];
    final applied = applyOfficialClipAnalysis(
      project: p.toJson(),
      clipId: id,
      speech: speech,
    );
    expect(applied.manualMutations, 0);
    expect(applied.manual.points.map((pt) => (pt.time, pt.db)).toList(), [
      (Q.of(0), -3),
      (Q.of(2), -3),
    ]);
    expect(applied.at(Q.of(3, 2)), closeTo(-12, 1e-9));
    expect(applied.auto.at(Q.of(3, 2)), closeTo(-9, 1e-9));
    final effectBefore = jsonEncode(gainEffect(p));
    // Successful analysis never rewrites the persisted manual Effect.
    expect(jsonEncode(gainEffect(p)), effectBefore);

    final locked = apply(p, SetTrackState(audioTrackId(p), locked: true));
    final beforeLock = jsonEncode(locked.toJson());
    expect(() => apply(locked, SetClipGain(id, -9)), code('FIELD_LOCKED'));
    expect(
      () => apply(locked, SetGainKeyframe(id, Q.of(1), -9)),
      code('FIELD_LOCKED'),
    );
    expect(
      () => applyOfficialClipAnalysis(
        project: locked.toJson(),
        clipId: id,
        speech: speech,
      ),
      code('TRACK_LOCKED'),
    );
    expect(jsonEncode(locked.toJson()), beforeLock);

    for (final field in ['effects', 'effectIds', 'gain', 'effects.gain']) {
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
        () => applyOfficialClipAnalysis(
          project: gated.toJson(),
          clipId: id,
          speech: speech,
        ),
        code('MANUAL_LOCKED'),
        reason: field,
      );
      expect(jsonEncode(gated.toJson()), before, reason: field);
    }
  });

  test(
    'limiter and pan Effect types stay refused on the official audio clip',
    () {
      var p = apply(
        avFixture(),
        ExtractAudioClip(video(avFixture()), 'audio-stream'),
      );
      final id = audioClipId(p);
      p = apply(p, SetClipGain(id, -6));
      final d = p.toJson();
      final eid = 'not-gain-fx';
      (d['effects'] as List).add({
        'id': eid,
        'version': '0',
        'owner': {'kind': 'clip', 'id': id},
        'type': 'limiter',
        'pluginVersion': '1.0.0',
        'enabled': true,
        'parameters': {'ceilingDb': -1, 'lookaheadMs': 5, 'releaseMs': 100},
        'keyframes': <dynamic>[],
        'extensions': <String, dynamic>{},
      });
      for (final t in d['sequences'][0]['tracks']) {
        for (final c in t['items']) {
          if (c['id'] == id) c['effectIds'] = [...c['effectIds'], eid];
        }
      }
      expect(
        () => requireLocalEditingWritable(ProjectDocument.fromJson(d)),
        code('UNSUPPORTED_EDIT_TECHNIQUE'),
      );
      final pan = p.toJson();
      (pan['effects'] as List).add({
        'id': 'pan-fx',
        'version': '0',
        'owner': {'kind': 'clip', 'id': id},
        'type': 'pan',
        'pluginVersion': '1.0.0',
        'enabled': true,
        'parameters': {'value': 0, 'mode': 'stereoBalance'},
        'keyframes': <dynamic>[],
        'extensions': <String, dynamic>{},
      });
      for (final t in pan['sequences'][0]['tracks']) {
        for (final c in t['items']) {
          if (c['id'] == id) c['effectIds'] = [...c['effectIds'], 'pan-fx'];
        }
      }
      expect(
        () => requireLocalEditingWritable(ProjectDocument.fromJson(pan)),
        code('UNSUPPORTED_EDIT_TECHNIQUE'),
      );
    },
  );
}
