import 'package:studio_contracts/studio_contracts.dart';
import 'package:studio_document/studio_document.dart';
import 'package:test/test.dart';

import 'multi_move_test.dart' as move;
import 'persistent_audio_test.dart' show avFixture;

/// Increment 1.89 official I-008 remainingAcceptance clause
/// 「未知技术UNSUPPORTED_EDIT_TECHNIQUE」. This file does not rewrite the
/// Increment 1.15–1.18 suites, which throw StudioException on several of
/// these paths but do not officialize this exact code as that clause.
Matcher code(String c) =>
    throwsA(isA<StudioException>().having((e) => e.code, 'code', c));

String content(ProjectDocument p) =>
    contentHash(p.toJson()..remove('revision'));

String firstVideoId(ProjectDocument p) {
  for (final t in p.toJson()['sequences'][0]['tracks']) {
    if (t['kind'] != 'video') continue;
    for (final c in t['items']) {
      if (c['source'] != null) return c['id'] as String;
    }
  }
  throw StateError('no video clip');
}

String firstAudioId(ProjectDocument p) {
  for (final t in p.toJson()['sequences'][0]['tracks']) {
    if (t['kind'] != 'audio') continue;
    for (final c in t['items']) {
      if (c['source'] != null) return c['id'] as String;
    }
  }
  throw StateError('no audio clip');
}

ProjectDocument withExtractedAudio(ProjectDocument p) {
  final video = firstVideoId(p);
  final stream =
      (p.toJson()['assets'][0]['streams'] as List).singleWhere(
            (s) => s['type'] == 'audio',
          )['id']
          as String;
  return move.change(p, ExtractAudioClip(video, stream));
}

void expectUnchanged(
  ProjectDocument before,
  String beforeHash,
  void Function() act,
) {
  expect(act, code('UNSUPPORTED_EDIT_TECHNIQUE'));
  expect(content(before), beforeHash);
  expect(before.hash, isNotEmpty);
}

void main() {
  test('unknown opacity interpolation is UNSUPPORTED_EDIT_TECHNIQUE and does not half-write', () {
    final start = avFixture();
    final id = firstVideoId(start);
    final beforeHash = content(start);
    expectUnchanged(
      start,
      beforeHash,
      () => move.change(
        start,
        SetOpacityKeyframe(id, Q.of(0), 0.5, interpolation: 'bezier'),
      ),
    );
    expectUnchanged(
      start,
      beforeHash,
      () => move.change(
        start,
        SetOpacityKeyframe(id, Q.of(0), 0.5, interpolation: 'easeIn'),
      ),
    );
    // A non-null easing field is a Schema refusal (SCHEMA_TYPE) at
    // fromJson and is not retargeted to UNSUPPORTED_EDIT_TECHNIQUE.
  });

  test('visual opacity commands on an audio clip are UNSUPPORTED_EDIT_TECHNIQUE and do not half-write', () {
    final start = withExtractedAudio(avFixture());
    final audio = firstAudioId(start);
    final beforeHash = content(start);
    expectUnchanged(
      start,
      beforeHash,
      () => move.change(start, SetClipOpacity(audio, 0.5)),
    );
    expectUnchanged(
      start,
      beforeHash,
      () => move.change(start, SetOpacityKeyframe(audio, Q.of(0), 0.5)),
    );
  });

  test('unknown registered technique, version, extensions, and audio-owned effects refuse UNSUPPORTED_EDIT_TECHNIQUE without stripping', () {
    final base = move.change(
      avFixture(),
      SetClipOpacity(firstVideoId(avFixture()), 0.5),
    );
    final beforeHash = content(base);

    void refuseAdmission(void Function(Map<String, dynamic>) mutate) {
      final json = base.toJson();
      mutate(json);
      expectUnchanged(
        base,
        beforeHash,
        () => requireLocalEditingWritable(ProjectDocument.fromJson(json)),
      );
    }

    // Unknown Effect.type is SCHEMA_UNION at fromJson and is not
    // retargeted. The already-admitted registry still names that
    // technique UNSUPPORTED_EDIT_TECHNIQUE when presented a raw node.
    final clip =
        (base.toJson()['sequences'][0]['tracks'][0]['items'] as List).first
            as Map;
    final raw = Map<String, dynamic>.from(base.toJson());
    final effects = [
      for (final e in raw['effects'] as List)
        Map<String, dynamic>.from(e as Map),
    ];
    effects.first['type'] = 'lumaWipe';
    raw['effects'] = effects;
    expect(
      () => admittedClipEffects(raw, Map<String, dynamic>.from(clip)),
      code('UNSUPPORTED_EDIT_TECHNIQUE'),
    );
    expect(content(base), beforeHash);

    refuseAdmission((d) {
      (d['effects'] as List).first['pluginVersion'] = '9.0.0';
    });
    refuseAdmission((d) {
      (d['effects'] as List).first['extensions'] = {'future': true};
    });

    // Pointing a video-owned effect at an audio clip is
    // EFFECT_OWNER_MISMATCH at fromJson and is not retargeted. An
    // effect whose owner is the audio clip itself is schema-valid and
    // the already-admitted writable admission still refuses
    // UNSUPPORTED_EDIT_TECHNIQUE (no silent strip).
    final extracted = withExtractedAudio(base);
    final extractedHash = content(extracted);
    final audioJson = extracted.toJson();
    String? audioId;
    for (final t in audioJson['sequences'][0]['tracks']) {
      if (t['kind'] != 'audio') continue;
      for (final c in t['items']) {
        if (c['source'] != null) audioId = c['id'] as String;
      }
    }
    final template = Map<String, dynamic>.from(
      (audioJson['effects'] as List).first as Map,
    );
    template['id'] = 'audio-opacity';
    template['owner'] = {'kind': 'clip', 'id': audioId};
    (audioJson['effects'] as List).add(template);
    for (final t in audioJson['sequences'][0]['tracks']) {
      if (t['kind'] != 'audio') continue;
      for (final c in t['items']) {
        if (c['source'] != null) {
          c['effectIds'] = ['audio-opacity'];
        }
      }
    }
    expectUnchanged(
      extracted,
      extractedHash,
      () => requireLocalEditingWritable(ProjectDocument.fromJson(audioJson)),
    );

    // Already-admitted distinct codes stay un-retargeted.
    final withTransform = move.change(
      base,
      SetClipTransform(firstVideoId(base), {
        ...identityTransform2d,
        'translateX': 16,
      }),
    );
    final withTransformHash = content(withTransform);
    final animated = withTransform.toJson();
    final xf = (animated['effects'] as List).firstWhere(
      (e) => e['type'] == 'transform2d',
    );
    xf['keyframes'] = [
      {
        'id': 'xf-anim-key',
        'param': 'translateX',
        'localTime': Q.of(0).toJson(),
        'value': 0,
        'interpolation': 'linear',
        'easing': null,
      },
    ];
    expect(
      () => requireLocalEditingWritable(ProjectDocument.fromJson(animated)),
      code('TRANSFORM_ANIMATION_NOT_IMPLEMENTED'),
    );
    expect(content(withTransform), withTransformHash);
    expect(content(base), beforeHash);
    expect(
      () => captureRasterEffects({
        'lumaWipe': {'softness': 0.2},
      }),
      code('UNSUPPORTED_EDIT_TECHNIQUE'),
    );
  });
}
