import 'dart:convert';
import 'dart:io';

import 'package:studio_assets/studio_assets.dart';
import 'package:studio_contracts/studio_contracts.dart';
import 'package:studio_document/studio_document.dart';
import 'package:test/test.dart';

/// Increment 2.39 official I-037 leftover 「J/L cut/handles命令golden」.
/// Compiles to already-admitted UnlinkAudioVideo + TrimClip commands
/// only. This file does not invent a TrimPlanner or a new trim mode,
/// does not start SOFT_CAMERA_CONTROL or external-skill privilege
/// escalation, and does not rewrite the Increment 2.38 unregistered
/// technique suite or the frozen I-036 fts5Enabled==false assertions.
Matcher code(String c) =>
    throwsA(isA<StudioException>().having((e) => e.code, 'code', c));

final jOffset = Q.of(2, 5); // 0.4s at 30fps
final shortHead = Q.of(1, 5); // 0.2s

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

ProjectDocument apply(ProjectDocument p, EditOperation op) {
  var serial = 0, max = 0;
  void scan(dynamic v) {
    if (v is Map) {
      if (v['version'] is String) {
        final n = int.tryParse(v['version']);
        if (n != null && n > max) max = n;
      }
      for (final c in v.values) {
        scan(c);
      }
    } else if (v is List) {
      for (final c in v) {
        scan(c);
      }
    }
  }

  scan(p.toJson());
  return applyEdit(
    p,
    op,
    nextVersion: (id) => '${++max}',
    newId: () => 'jl-${p.hash.substring(7, 15)}-${serial++}',
  );
}

String firstVideoId(ProjectDocument p) {
  for (final t in p.toJson()['sequences'][0]['tracks']) {
    if (t['kind'] != 'video') continue;
    for (final c in t['items']) {
      if (c['source'] != null) return c['id'] as String;
    }
  }
  throw StateError('no video');
}

String audioTrackId(ProjectDocument p) {
  for (final t in p.toJson()['sequences'][0]['tracks']) {
    if (t['kind'] == 'audio') return t['id'] as String;
  }
  throw StateError('no audio track');
}

Map clipOf(ProjectDocument p, String id) {
  for (final t in p.toJson()['sequences'][0]['tracks']) {
    for (final c in t['items']) {
      if (c['id'] == id) return c as Map;
    }
  }
  throw StateError(id);
}

Q startOf(ProjectDocument p, String id) =>
    Q.fromJson(clipOf(p, id)['timelineRange']['start']);

Q durationOf(ProjectDocument p, String id) =>
    Q.fromJson(clipOf(p, id)['timelineRange']['duration']);

({
  ProjectDocument project,
  String left,
  String right,
  String leftAudio,
  String rightAudio,
})
packedPair({Q? splitAt}) {
  splitAt ??= Q.of(1);
  var p = avFixture();
  final left = firstVideoId(p);
  p = apply(p, ExtractAudioClip(left, 'audio-stream'));
  p = apply(p, SplitClip(left, splitAt, 'video-right'));
  String? leftAudio;
  String? rightAudio;
  for (final g in p.toJson()['linkGroups'] as List) {
    final members = [for (final m in g['members']) m['clipId'] as String];
    if (members.contains(left)) {
      leftAudio = members.firstWhere((id) => id != left);
    }
    if (members.contains('video-right')) {
      rightAudio = members.firstWhere((id) => id != 'video-right');
    }
  }
  return (
    project: p,
    left: left,
    right: 'video-right',
    leftAudio: leftAudio!,
    rightAudio: rightAudio!,
  );
}

ProjectDocument applyProposal(ProjectDocument p, CraftProposal proposal) {
  var next = p;
  for (final command in proposal.commands) {
    next = apply(next, command);
  }
  return next;
}

void main() {
  test('a 0.4s J-cut compiles to unlink and trim, moves only the audio cut, and restores from the before snapshot', () {
    final pair = packedPair();
    final before = pair.project;
    final beforeHash = before.hash;
    final compiler = CraftSkillCompiler();
    final proposal = compiler.compileJlCut(
      project: before,
      request: JlCutRequest(
        kind: JlCutKind.j,
        offset: jOffset,
        leftVideoId: pair.left,
        rightVideoId: pair.right,
      ),
    );
    expect(compiler.documentWrites, 0);
    expect(proposal.documentWrites, 0);
    expect(proposal.inverseKind, 'restoreSnapshot');
    expect(proposal.beforeSnapshotHash, beforeHash);
    expect(proposal.commands.whereType<UnlinkAudioVideo>(), hasLength(2));
    expect(proposal.commands.whereType<TrimClip>(), hasLength(2));
    expect(
      proposal.commands.every((c) => c is UnlinkAudioVideo || c is TrimClip),
      isTrue,
    );

    final after = applyProposal(before, proposal);
    expect(startOf(after, pair.left), Q.of(0));
    expect(durationOf(after, pair.left), Q.of(1));
    expect(startOf(after, pair.right), Q.of(1));
    expect(
      startOf(after, pair.leftAudio) + durationOf(after, pair.leftAudio),
      Q.of(3, 5),
    );
    expect(startOf(after, pair.rightAudio), Q.of(3, 5));
    expect(after.toJson()['linkGroups'], isEmpty);
    expect(before.hash, beforeHash);
    expect(after.hash, isNot(beforeHash));
  });

  test('a 0.4s L-cut extends outgoing audio past the video cut using the same admitted commands', () {
    final pair = packedPair();
    final proposal = CraftSkillCompiler().compileJlCut(
      project: pair.project,
      request: JlCutRequest(
        kind: JlCutKind.l,
        offset: jOffset,
        leftVideoId: pair.left,
        rightVideoId: pair.right,
      ),
    );
    expect(proposal.inverseKind, 'restoreSnapshot');
    final after = applyProposal(pair.project, proposal);
    expect(startOf(after, pair.left) + durationOf(after, pair.left), Q.of(1));
    expect(startOf(after, pair.right), Q.of(1));
    expect(
      startOf(after, pair.leftAudio) + durationOf(after, pair.leftAudio),
      Q.of(7, 5),
    );
    expect(startOf(after, pair.rightAudio), Q.of(7, 5));
  });

  test('insufficient audio head, a locked audio track, and a 0.4s J on a 0.2s handle are refused without writing', () {
    final short = packedPair(splitAt: shortHead);
    final compiler = CraftSkillCompiler();
    expect(
      () => compiler.compileJlCut(
        project: short.project,
        request: JlCutRequest(
          kind: JlCutKind.j,
          offset: jOffset,
          leftVideoId: short.left,
          rightVideoId: short.right,
        ),
      ),
      code('HANDLE_UNAVAILABLE'),
    );
    expect(compiler.documentWrites, 0);
    expect(short.project.toJson()['linkGroups'], hasLength(2));

    final pair = packedPair();
    final locked = apply(
      pair.project,
      SetTrackState(audioTrackId(pair.project), locked: true),
    );
    expect(
      () => compiler.compileJlCut(
        project: locked,
        request: JlCutRequest(
          kind: JlCutKind.j,
          offset: jOffset,
          leftVideoId: pair.left,
          rightVideoId: pair.right,
        ),
      ),
      code('FIELD_LOCKED'),
    );
    expect(compiler.documentWrites, 0);
  });
}
