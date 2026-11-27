import 'dart:convert';
import 'dart:io';

import 'package:studio_contracts/studio_contracts.dart';
import 'package:studio_document/studio_document.dart';
import 'package:test/test.dart';

import 'persistent_audio_test.dart' show avFixture;

Matcher code(String c) =>
    throwsA(isA<StudioException>().having((e) => e.code, 'code', c));

ProjectDocument lumaFixture() {
  final d = jsonDecode(
    File('fixtures/project/local-video.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  final s = d['sequences'][0], t = s['tracks'][0], left = t['items'][0];
  left['id'] = 'luma-left';
  left['timelineRange'] = {
    'start': Q.of(0).toJson(),
    'duration': Q.of(1).toJson(),
  };
  left['sourceRange'] = {
    'start': Q.of(1, 2).toJson(),
    'duration': Q.of(1).toJson(),
  };
  final right = jsonDecode(jsonEncode(left)) as Map<String, dynamic>;
  right['id'] = 'luma-right';
  right['timelineRange']['start'] = Q.of(1).toJson();
  right['sourceRange']['start'] = Q.of(1).toJson();
  t['items'] = [left, right];
  s['duration'] = Q.of(2).toJson();
  return ProjectDocument.fromJson(d);
}

void main() {
  var serial = 200;
  ProjectDocument edit(ProjectDocument p, EditOperation op) => applyEdit(
    p,
    op,
    newId: () => 'luma-${serial++}',
    nextVersion: (_) => '${serial++}',
  );

  final set = SetLumaWipe(
    'luma-left',
    'luma-right',
    Q.of(1, 5),
    Q.of(1, 5),
    softness: 0.1,
  );

  test('formula endpoints: p=0 is all A, p=1 is all B, compile emits lumaWipe not dissolve mix', () {
    expect(
      lumaWipeWeight(
        p: 0,
        red: 0,
        green: 0,
        blue: 0,
        softness: 0.1,
        invert: false,
      ),
      0,
    );
    expect(
      lumaWipeWeight(
        p: 0,
        red: 1,
        green: 1,
        blue: 1,
        softness: 0.1,
        invert: true,
      ),
      0,
    );
    expect(
      lumaWipeWeight(
        p: 1,
        red: 0,
        green: 0,
        blue: 0,
        softness: 0.1,
        invert: false,
      ),
      1,
    );
    expect(
      lumaWipeWeight(
        p: 1,
        red: 1,
        green: 1,
        blue: 1,
        softness: 0.5,
        invert: true,
      ),
      1,
    );
    final mid = lumaWipeWeight(
      p: 0.5,
      red: 0,
      green: 0,
      blue: 0,
      softness: 0.1,
      invert: false,
    );
    expect(mid, inInclusiveRange(0, 1));
    expect(mid, isNot(equals(0.5)));

    final p = edit(lumaFixture(), set);
    expect(p.toJson()['requiredFeatures'], [lumaWipeRequiredFeature]);
    expect(p.toJson()['transitions'], isEmpty);
    expect(
      (p.toJson()['sequences'][0] as Map).containsKey('effectIds'),
      isFalse,
    );
    final effect = lumaWipeEffects(p.toJson()).single;
    expect(effect['type'], lumaWipeEffectType);
    expect(effect['owner'], {
      'kind': 'sequence',
      'id': p.toJson()['sequences'][0]['id'],
    });
    expect(effect['parameters']['maskMode'], lumaWipeMaskIncoming);
    expect(effect['parameters']['maskAssetRef'], isNull);

    final g = TimelineVideoGraph(p);
    final first = g.sample(Q.of(4, 5));
    expect(first.lumaWipe, isNotNull);
    expect(first.lumaWipe!.progress, Q.of(0));
    expect(first.mixQ16, 0);
    expect(first.secondary, isNotNull);
    expect(
      lumaWipeWeight(
        p:
            first.lumaWipe!.progress.n.toDouble() /
            first.lumaWipe!.progress.d.toDouble(),
        red: 0.2,
        green: 0.3,
        blue: 0.4,
        softness: first.lumaWipe!.softness,
        invert: first.lumaWipe!.invert,
      ),
      0,
    );
    expect(g.sample(Q.of(79, 100)).lumaWipe, isNull);
    expect(g.sample(Q.of(6, 5)).lumaWipe, isNull);
    expect(g.sample(Q.of(6, 5)).secondary, isNull);
    final lastIn = g.sample(Q.of(6, 5) - Q.of(1, 30));
    expect(lastIn.lumaWipe, isNotNull);
    expect(lastIn.lumaWipe!.progress < Q.of(1), isTrue);

    final parts = g.compileDissolves({
      'luma-left': {'path': '/fixture-a', 'streamIndex': 0},
      'luma-right': {'path': '/fixture-b', 'streamIndex': 0},
    });
    final blended = parts.where((s) => s['secondary'] != null).toList();
    expect(blended, isNotEmpty);
    for (final s in blended) {
      expect(s.containsKey('mixFramesQ16'), isFalse);
      expect(s['lumaWipe'], isNotNull);
      expect(s['lumaWipe']['softness'], 0.1);
      expect(s['lumaWipe']['invert'], isFalse);
    }
    expect(Q.fromJson(blended.first['lumaWipe']['progress'].first), Q.of(0));
  });

  test('missing head/tail handles return HANDLE_UNAVAILABLE without freeze fallback or document change', () {
    final p = lumaFixture();
    final beforeHash = p.hash;
    for (final side in ['head', 'tail']) {
      final d = p.toJson();
      final c = d['sequences'][0]['tracks'][0]['items'][side == 'head' ? 1 : 0];
      c['sourceRange']['start'] = Q.of(side == 'head' ? 0 : 2).toJson();
      final before = ProjectDocument.fromJson(d);
      final hash = before.hash;
      expect(() => edit(before, set), code('HANDLE_UNAVAILABLE'));
      expect(before.hash, hash);
    }
    expect(p.hash, beforeHash);
    expect(
      () => edit(
        p,
        SetLumaWipe('luma-left', 'luma-right', Q.of(0), Q.of(0), softness: 0.1),
      ),
      throwsA(isA<StudioException>()),
    );
    expect(p.hash, beforeHash);
  });

  test('core Transition or another pair operator in the same window is TRANSITION_WINDOW_CONFLICT; removeTransition then luma is accepted', () {
    final start = lumaFixture();
    final withDissolve = edit(
      start,
      SetDissolve('luma-left', 'luma-right', Q.of(1, 5), Q.of(1, 5)),
    );
    final hash = withDissolve.hash;
    expect(() => edit(withDissolve, set), code('TRANSITION_WINDOW_CONFLICT'));
    expect(withDissolve.hash, hash);
    expect(withDissolve.toJson()['transitions'], isNotEmpty);
    expect(lumaWipeEffects(withDissolve.toJson()), isEmpty);

    final cleared = edit(
      withDissolve,
      RemoveDissolve(withDissolve.toJson()['transitions'][0]['id'] as String),
    );
    final replaced = edit(cleared, set);
    expect(replaced.toJson()['transitions'], isEmpty);
    expect(lumaWipeEffects(replaced.toJson()), hasLength(1));

    expect(() => edit(replaced, set), returnsNormally);
    expect(
      () => edit(
        replaced,
        SetLumaWipe(
          'luma-left',
          'luma-right',
          Q.of(1, 10),
          Q.of(3, 10),
          softness: 0.2,
        ),
      ),
      returnsNormally,
    );
    final overlapping = edit(
      replaced,
      SetLumaWipe(
        'luma-left',
        'luma-right',
        Q.of(1, 5),
        Q.of(1, 5),
        softness: 0.2,
      ),
    );
    expect(lumaWipeEffects(overlapping.toJson()), hasLength(1));
  });

  test('luma is not written as dissolve, unopened mask modes are refused, and unsupported technique is not silently stripped', () {
    final p = edit(lumaFixture(), set);
    final d = p.toJson();
    expect(d['transitions'], isEmpty);
    expect(lumaWipeEffects(d).single['type'], isNot('dissolve'));
    expect(d['requiredFeatures'], [lumaWipeRequiredFeature]);

    expect(
      () => edit(
        lumaFixture(),
        SetLumaWipe(
          'luma-left',
          'luma-right',
          Q.of(1, 5),
          Q.of(1, 5),
          softness: 0,
        ),
      ),
      code('UNSUPPORTED_EDIT_TECHNIQUE'),
    );

    final raw = p.toJson();
    raw['effects'][0]['parameters']['maskMode'] = 'assetLuma';
    expect(
      () => requireLocalEditingWritable(ProjectDocument.fromJson(raw)),
      anyOf(code('UNSUPPORTED_EDIT_TECHNIQUE'), code('MASK_MEDIA_UNSUPPORTED')),
    );
    final alpha = p.toJson();
    alpha['effects'][0]['parameters']['maskMode'] = 'assetAlpha';
    expect(
      () => requireLocalEditingWritable(ProjectDocument.fromJson(alpha)),
      anyOf(code('UNSUPPORTED_EDIT_TECHNIQUE'), code('MASK_MEDIA_UNSUPPORTED')),
    );
    final videoMatte = p.toJson();
    videoMatte['effects'][0]['parameters']['maskMode'] = 'assetLuma';
    videoMatte['effects'][0]['parameters']['maskAssetRef'] = {
      'kind': 'asset',
      'id': videoMatte['assets'][0]['id'],
    };
    expect(
      () => requireLocalEditingWritable(ProjectDocument.fromJson(videoMatte)),
      code('MASK_MEDIA_UNSUPPORTED'),
    );
  });

  test('audio does not automatically fade with a luma wipe; no audioEqualPower transition is introduced', () {
    var p = avFixture();
    final videoId =
        p.toJson()['sequences'][0]['tracks'][0]['items'][0]['id'] as String;
    p = edit(p, ExtractAudioClip(videoId, 'audio-stream'));
    p = edit(p, UnlinkAudioVideo(p.toJson()['linkGroups'][0]['id'] as String));
    final d = p.toJson();
    final s = d['sequences'][0], videoTrack = s['tracks'][0];
    final left = videoTrack['items'][0];
    left['id'] = 'luma-left';
    left['timelineRange'] = {
      'start': Q.of(0).toJson(),
      'duration': Q.of(1).toJson(),
    };
    left['sourceRange'] = {
      'start': Q.of(1, 2).toJson(),
      'duration': Q.of(1).toJson(),
    };
    final right = jsonDecode(jsonEncode(left)) as Map<String, dynamic>;
    right['id'] = 'luma-right';
    right['timelineRange']['start'] = Q.of(1).toJson();
    right['sourceRange']['start'] = Q.of(1).toJson();
    videoTrack['items'] = [left, right];
    s['duration'] = Q.of(2).toJson();
    // Keep the extracted audio clip range covering the whole sequence; luma
    // must not invent an audio fade or transition on it.
    final audio = s['tracks'].singleWhere((t) => t['kind'] == 'audio');
    audio['items'][0]['timelineRange'] = {
      'start': Q.of(0).toJson(),
      'duration': Q.of(2).toJson(),
    };
    audio['items'][0]['sourceRange'] = {
      'start': Q.of(0).toJson(),
      'duration': Q.of(2).toJson(),
    };
    p = ProjectDocument.fromJson(d);
    final beforeAudio = jsonDecode(jsonEncode(audio['items'][0]));
    final beforeBuses = jsonDecode(jsonEncode(p.toJson()['audioBuses']));
    p = edit(p, set);
    expect(p.toJson()['transitions'], isEmpty);
    expect(
      (p.toJson()['transitions'] as List).any(
        (t) => t['kind'] == 'audioEqualPower',
      ),
      isFalse,
    );
    final afterAudio = p.toJson()['sequences'][0]['tracks'].singleWhere(
      (t) => t['kind'] == 'audio',
    )['items'][0];
    expect(afterAudio['timelineRange'], beforeAudio['timelineRange']);
    expect(afterAudio['sourceRange'], beforeAudio['sourceRange']);
    expect(afterAudio['effectIds'], beforeAudio['effectIds']);
    expect(p.toJson()['audioBuses'], beforeBuses);
    expect(afterAudio['effectIds'], isEmpty);
  });

  test('track and clip locks refuse luma writes without half-write; noop and explicit removal are real', () {
    final start = lumaFixture();
    final lockedTrack = start.toJson();
    lockedTrack['sequences'][0]['tracks'][0]['locked'] = true;
    final trackDoc = ProjectDocument.fromJson(lockedTrack);
    final trackHash = trackDoc.hash;
    expect(() => edit(trackDoc, set), code('FIELD_LOCKED'));
    expect(trackDoc.hash, trackHash);

    for (final field in ['*', 'transitions', 'effects']) {
      final d = start.toJson();
      d['sequences'][0]['tracks'][0]['items'][1]['lockedFields'] = [field];
      final locked = ProjectDocument.fromJson(d);
      final hash = locked.hash;
      expect(() => edit(locked, set), code('FIELD_LOCKED'));
      expect(locked.hash, hash);
    }

    final p = edit(start, set);
    final hash = p.hash;
    expect(edit(p, set).hash, hash);
    final id = lumaWipeEffects(p.toJson()).single['id'] as String;
    final lockedRemove = p.toJson();
    lockedRemove['sequences'][0]['tracks'][0]['items'][0]['lockedFields'] = [
      'effects',
    ];
    expect(
      () => edit(ProjectDocument.fromJson(lockedRemove), RemoveLumaWipe(id)),
      code('FIELD_LOCKED'),
    );
    final removed = edit(p, RemoveLumaWipe(id));
    expect(lumaWipeEffects(removed.toJson()), isEmpty);
    expect(removed.toJson()['requiredFeatures'], isEmpty);
    expect(() => edit(removed, RemoveLumaWipe(id)), code('NOT_FOUND'));
  });
}
