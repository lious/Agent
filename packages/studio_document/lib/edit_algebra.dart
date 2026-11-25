import 'dart:convert';

import 'package:studio_contracts/studio_contracts.dart';

import 'studio_document.dart';

typedef VersionAllocator = String Function(String entityId);
typedef IdAllocator = String Function();

sealed class EditOperation {
  const EditOperation();
  Map<String, Object?> toJson();
}

final class RenameProject extends EditOperation {
  const RenameProject(this.title);
  final String title;
  @override
  Map<String, Object?> toJson() => {'kind': 'renameProject', 'title': title};
}

final class AppendVideoAsset extends EditOperation {
  AppendVideoAsset({
    required Map<String, dynamic> asset,
    required Map<String, dynamic> blob,
    required Map<String, dynamic> rights,
    required this.clipId,
    this.matchEmptySequence = false,
  }) : _encoded = jsonEncode({'asset': asset, 'blob': blob, 'rights': rights});
  final String _encoded, clipId;
  final bool matchEmptySequence;
  @override
  Map<String, Object?> toJson() => {
    'kind': 'appendVideoAsset',
    ...Map<String, Object?>.from(jsonDecode(_encoded) as Map),
    'clipId': clipId,
    'matchEmptySequence': matchEmptySequence,
  };
}

final class SplitClip extends EditOperation {
  const SplitClip(this.clipId, this.at, this.rightId);
  final String clipId, rightId;
  final Q at;
  @override
  Map<String, Object?> toJson() => {
    'kind': 'splitClip',
    'clipId': clipId,
    'at': at.toJson(),
    'rightId': rightId,
  };
}

final class MoveClip extends EditOperation {
  const MoveClip(this.clipId, this.delta);
  final String clipId;
  final Q delta;
  @override
  Map<String, Object?> toJson() => {
    'kind': 'moveClip',
    'clipId': clipId,
    'delta': delta.toJson(),
  };
}

final class DeleteClip extends EditOperation {
  const DeleteClip(this.clipId, {this.ripple = false});
  final String clipId;
  final bool ripple;
  @override
  Map<String, Object?> toJson() => {
    'kind': 'deleteClip',
    'clipId': clipId,
    'ripple': ripple,
  };
}

final class TrimClip extends EditOperation {
  const TrimClip(this.clipId, this.edge, this.delta, {this.ripple = false});
  final String clipId, edge;
  final Q delta;
  final bool ripple;
  @override
  Map<String, Object?> toJson() => {
    'kind': 'trimClip',
    'clipId': clipId,
    'edge': edge,
    'delta': delta.toJson(),
    'ripple': ripple,
  };
}

final class SlipClip extends EditOperation {
  const SlipClip(this.clipId, this.sourceDelta);
  final String clipId;
  final Q sourceDelta;
  @override
  Map<String, Object?> toJson() => {
    'kind': 'slipClip',
    'clipId': clipId,
    'sourceDelta': sourceDelta.toJson(),
  };
}

final class RollCut extends EditOperation {
  const RollCut(this.leftId, this.rightId, this.delta);
  final String leftId, rightId;
  final Q delta;
  @override
  Map<String, Object?> toJson() => {
    'kind': 'rollCut',
    'leftId': leftId,
    'rightId': rightId,
    'delta': delta.toJson(),
  };
}

final class SlideClip extends EditOperation {
  const SlideClip(this.leftId, this.clipId, this.rightId, this.delta);
  final String leftId, clipId, rightId;
  final Q delta;
  @override
  Map<String, Object?> toJson() => {
    'kind': 'slideClip',
    'leftId': leftId,
    'clipId': clipId,
    'rightId': rightId,
    'delta': delta.toJson(),
  };
}

/// Pure edit algebra over detached documents. IDs/version allocations are explicit
/// dependencies. No DB, network, media writes or source mutation occurs here.
ProjectDocument applyEdit(
  ProjectDocument before,
  EditOperation operation, {
  required VersionAllocator nextVersion,
  required IdAllocator newId,
}) {
  requireLocalEditingWritable(before);
  if (operation is RenameProject) {
    return before.withTitle(operation.title, before.revision);
  }
  final zeroDelta = switch (operation) {
    MoveClip(:final delta) => delta == Q.of(0),
    TrimClip(:final delta) => delta == Q.of(0),
    SlipClip(:final sourceDelta) => sourceDelta == Q.of(0),
    RollCut(:final delta) => delta == Q.of(0),
    SlideClip(:final delta) => delta == Q.of(0),
    _ => false,
  };
  final d = before.toJson();
  final s = d['sequences'][0];
  final tracks = s['tracks'] as List;
  if (tracks.isEmpty && operation is! AppendVideoAsset) {
    throw const StudioException('CLIP_NOT_FOUND');
  }
  if (tracks.isNotEmpty && tracks[0]['locked'] == true) {
    throw const StudioException('FIELD_LOCKED');
  }
  final changed = <String>{};
  var retainedEnd = Q.fromJson(s['duration']);
  Map<String, dynamic> clip(String id, List<String> paths) {
    final found = (s['tracks'][0]['items'] as List).where(
      (c) => c['id'] == id && c['source'] != null,
    );
    if (found.length != 1) throw const StudioException('CLIP_NOT_FOUND');
    final c = found.single as Map<String, dynamic>;
    for (final lock in c['lockedFields'] as List) {
      if (paths.any(
        (p) =>
            p == lock ||
            p.startsWith('$lock.') ||
            (lock as String).startsWith('$p.'),
      )) {
        throw const StudioException('FIELD_LOCKED');
      }
    }
    changed.add(id);
    return c;
  }

  Q get(Map c, String range, String field) => Q.fromJson(c[range][field]);
  void set(Map c, String range, String field, Q value) {
    c[range][field] = value.toJson();
  }

  void shiftAfter(Q boundary, Q delta, Set<String> excluded) {
    for (final c in s['tracks'][0]['items']) {
      if (excluded.contains(c['id']) ||
          get(c, 'timelineRange', 'start') < boundary) {
        continue;
      }
      if (c['source'] != null) {
        clip(c['id'] as String, ['timelineRange']);
      }
      set(
        c,
        'timelineRange',
        'start',
        get(c, 'timelineRange', 'start') + delta,
      );
    }
  }

  if (zeroDelta) {
    switch (operation) {
      case MoveClip():
        clip(operation.clipId, ['timelineRange']);
      case TrimClip():
        if (operation.edge != 'in' && operation.edge != 'out') {
          throw const StudioException('INVALID_EDGE');
        }
        clip(operation.clipId, ['timelineRange', 'sourceRange']);
      case SlipClip():
        clip(operation.clipId, ['sourceRange']);
      case RollCut():
        final a = clip(operation.leftId, ['timelineRange', 'sourceRange']),
            b = clip(operation.rightId, ['timelineRange', 'sourceRange']);
        if (get(a, 'timelineRange', 'start') +
                get(a, 'timelineRange', 'duration') !=
            get(b, 'timelineRange', 'start')) {
          throw const StudioException('NOT_ADJACENT');
        }
      case SlideClip():
        final a = clip(operation.leftId, ['timelineRange', 'sourceRange']),
            b = clip(operation.clipId, ['timelineRange']),
            c = clip(operation.rightId, ['timelineRange', 'sourceRange']);
        if (get(a, 'timelineRange', 'start') +
                    get(a, 'timelineRange', 'duration') !=
                get(b, 'timelineRange', 'start') ||
            get(b, 'timelineRange', 'start') +
                    get(b, 'timelineRange', 'duration') !=
                get(c, 'timelineRange', 'start')) {
          throw const StudioException('NOT_ADJACENT');
        }
      default:
        throw StateError('Non-delta operation');
    }
    return before;
  }
  switch (operation) {
    case RenameProject():
      throw StateError('Handled before sequence edit');
    case AppendVideoAsset():
      final p = operation.toJson();
      final a = p['asset'] as Map<String, dynamic>;
      if ((d['assets'] as List).any((v) => v['id'] == a['id'])) {
        throw const StudioException('DUPLICATE_ID');
      }
      final videos = (a['streams'] as List).where((v) => v['type'] == 'video');
      if (videos.isEmpty) throw const StudioException('VIDEO_STREAM_REQUIRED');
      final stream = videos.first;
      if (tracks.isEmpty) {
        tracks.add({
          'id': newId(),
          'sequenceId': s['id'],
          'name': 'Video 1',
          'kind': 'video',
          'order': 0,
          'locked': false,
          'muted': false,
          'solo': false,
          'syncLock': true,
          'targeted': true,
          'busId': null,
          'items': [],
        });
      }
      if (operation.matchEmptySequence &&
          (tracks[0]['items'] as List).isEmpty) {
        s['canvas']['width'] = stream['width'];
        s['canvas']['height'] = stream['height'];
        if (stream['nominalFrameRate'] != null) {
          s['frameRate'] = stream['nominalFrameRate'];
        }
      }
      final fps = FrameRate(
        s['frameRate']['n'] as int,
        s['frameRate']['d'] as int,
      );
      final duration = fps.quantize(
        Q.fromJson(stream['duration']),
        Rounding.floor,
      );
      if (duration <= Q.of(0)) throw const StudioException('CLIP_TOO_SHORT');
      (d['assets'] as List).add(a);
      (d['rightsRecords'] as List).add(p['rights']);
      if (!(d['blobs'] as List).any(
        (v) => v['hash'] == (p['blob'] as Map)['hash'],
      )) {
        (d['blobs'] as List).add(p['blob']);
      }
      tracks[0]['items'].add({
        'id': operation.clipId,
        'version': '1',
        'trackId': tracks[0]['id'],
        'name': a['name'],
        'source': {
          'kind': 'asset',
          'id': a['id'],
          'version': a['version'],
          'streamId': stream['id'],
        },
        'timelineRange': {
          'start': s['duration'],
          'duration': duration.toJson(),
        },
        'sourceRange': {
          'start': Q.of(0).toJson(),
          'duration': duration.toJson(),
        },
        'timeMap': {'kind': 'linear', 'rate': Q.of(1).toJson()},
        'enabled': true,
        'lockedFields': [],
        'linkGroupId': null,
        'selectionGroupId': null,
        'effectIds': [],
        'shotId': null,
        'candidateId': null,
        'provenanceId': null,
      });
    case SplitClip():
      final c = clip(operation.clipId, ['timelineRange', 'sourceRange']);
      final start = get(c, 'timelineRange', 'start'),
          duration = get(c, 'timelineRange', 'duration');
      final left = operation.at - start;
      if (left <= Q.of(0) || left >= duration) {
        throw const StudioException('SPLIT_BOUNDARY');
      }
      final right = jsonDecode(jsonEncode(c)) as Map<String, dynamic>;
      final rate = Q.fromJson(c['timeMap']['rate']);
      right['id'] = operation.rightId;
      right['version'] = '1';
      set(right, 'timelineRange', 'start', operation.at);
      set(right, 'timelineRange', 'duration', duration - left);
      set(
        right,
        'sourceRange',
        'start',
        get(c, 'sourceRange', 'start') + rate * left,
      );
      set(right, 'sourceRange', 'duration', rate * (duration - left));
      set(c, 'timelineRange', 'duration', left);
      set(c, 'sourceRange', 'duration', rate * left);
      tracks[0]['items'].add(right);
    case MoveClip():
      final c = clip(operation.clipId, ['timelineRange']);
      set(
        c,
        'timelineRange',
        'start',
        get(c, 'timelineRange', 'start') + operation.delta,
      );
    case DeleteClip():
      final c = clip(operation.clipId, ['timelineRange', 'sourceRange']);
      final end =
          get(c, 'timelineRange', 'start') +
          get(c, 'timelineRange', 'duration');
      (tracks[0]['items'] as List).remove(c);
      if (operation.ripple) {
        retainedEnd = retainedEnd - get(c, 'timelineRange', 'duration');
        shiftAfter(end, Q.of(0) - get(c, 'timelineRange', 'duration'), {});
      }
    case TrimClip():
      if (operation.edge != 'in' && operation.edge != 'out') {
        throw const StudioException('INVALID_EDGE');
      }
      final c = clip(operation.clipId, ['timelineRange', 'sourceRange']);
      final start = get(c, 'timelineRange', 'start'),
          duration = get(c, 'timelineRange', 'duration');
      final delta = operation.delta, rate = Q.fromJson(c['timeMap']['rate']);
      if (operation.edge == 'in') {
        if (!operation.ripple) set(c, 'timelineRange', 'start', start + delta);
        set(c, 'timelineRange', 'duration', duration - delta);
        set(
          c,
          'sourceRange',
          'start',
          get(c, 'sourceRange', 'start') + rate * delta,
        );
        set(
          c,
          'sourceRange',
          'duration',
          get(c, 'sourceRange', 'duration') - rate * delta,
        );
        if (operation.ripple) {
          retainedEnd = retainedEnd - delta;
          shiftAfter(start + duration, Q.of(0) - delta, {c['id'] as String});
        }
      } else {
        set(c, 'timelineRange', 'duration', duration + delta);
        set(
          c,
          'sourceRange',
          'duration',
          get(c, 'sourceRange', 'duration') + rate * delta,
        );
        if (operation.ripple) {
          retainedEnd = retainedEnd + delta;
          shiftAfter(start + duration, delta, {c['id'] as String});
        }
      }
    case SlipClip():
      final c = clip(operation.clipId, ['sourceRange']);
      set(
        c,
        'sourceRange',
        'start',
        get(c, 'sourceRange', 'start') + operation.sourceDelta,
      );
    case RollCut():
      final a = clip(operation.leftId, ['timelineRange', 'sourceRange']),
          b = clip(operation.rightId, ['timelineRange', 'sourceRange']);
      final cut =
          get(a, 'timelineRange', 'start') +
          get(a, 'timelineRange', 'duration');
      if (cut != get(b, 'timelineRange', 'start')) {
        throw const StudioException('NOT_ADJACENT');
      }
      final delta = operation.delta,
          ra = Q.fromJson(a['timeMap']['rate']),
          rb = Q.fromJson(b['timeMap']['rate']);
      set(
        a,
        'timelineRange',
        'duration',
        get(a, 'timelineRange', 'duration') + delta,
      );
      set(
        a,
        'sourceRange',
        'duration',
        get(a, 'sourceRange', 'duration') + ra * delta,
      );
      set(
        b,
        'timelineRange',
        'start',
        get(b, 'timelineRange', 'start') + delta,
      );
      set(
        b,
        'timelineRange',
        'duration',
        get(b, 'timelineRange', 'duration') - delta,
      );
      set(
        b,
        'sourceRange',
        'start',
        get(b, 'sourceRange', 'start') + rb * delta,
      );
      set(
        b,
        'sourceRange',
        'duration',
        get(b, 'sourceRange', 'duration') - rb * delta,
      );
    case SlideClip():
      final a = clip(operation.leftId, ['timelineRange', 'sourceRange']),
          c = clip(operation.clipId, ['timelineRange']),
          b = clip(operation.rightId, ['timelineRange', 'sourceRange']);
      if (get(a, 'timelineRange', 'start') +
                  get(a, 'timelineRange', 'duration') !=
              get(c, 'timelineRange', 'start') ||
          get(c, 'timelineRange', 'start') +
                  get(c, 'timelineRange', 'duration') !=
              get(b, 'timelineRange', 'start')) {
        throw const StudioException('NOT_ADJACENT');
      }
      final delta = operation.delta,
          ra = Q.fromJson(a['timeMap']['rate']),
          rb = Q.fromJson(b['timeMap']['rate']);
      set(
        a,
        'timelineRange',
        'duration',
        get(a, 'timelineRange', 'duration') + delta,
      );
      set(
        a,
        'sourceRange',
        'duration',
        get(a, 'sourceRange', 'duration') + ra * delta,
      );
      set(
        c,
        'timelineRange',
        'start',
        get(c, 'timelineRange', 'start') + delta,
      );
      set(
        b,
        'timelineRange',
        'start',
        get(b, 'timelineRange', 'start') + delta,
      );
      set(
        b,
        'timelineRange',
        'duration',
        get(b, 'timelineRange', 'duration') - delta,
      );
      set(
        b,
        'sourceRange',
        'start',
        get(b, 'sourceRange', 'start') + rb * delta,
      );
      set(
        b,
        'sourceRange',
        'duration',
        get(b, 'sourceRange', 'duration') - rb * delta,
      );
  }
  final items = tracks[0]['items'] as List;
  // Gaps are transparent domain intervals, not source references. Rebuild internal
  // gaps after applying the entire operation; reject overlap, never clamp silently.
  final clips = items.where((v) => v['source'] != null).toList()
    ..sort(
      (a, b) => get(
        a,
        'timelineRange',
        'start',
      ).compareTo(get(b, 'timelineRange', 'start')),
    );
  final normalized = <dynamic>[];
  var end = Q.of(0);
  for (final c in clips) {
    final start = get(c, 'timelineRange', 'start'),
        duration = get(c, 'timelineRange', 'duration');
    if (start < Q.of(0) || duration <= Q.of(0)) {
      throw const StudioException('INVALID_RANGE');
    }
    if (start < end) throw const StudioException('COLLISION');
    if (start > end) {
      normalized.add({
        'id': newId(),
        'trackId': tracks[0]['id'],
        'timelineRange': {
          'start': end.toJson(),
          'duration': (start - end).toJson(),
        },
      });
    }
    if (changed.contains(c['id'])) {
      c['version'] = nextVersion(c['id'] as String);
    }
    normalized.add(c);
    end = start + duration;
  }
  if (end < retainedEnd) {
    normalized.add({
      'id': newId(),
      'trackId': tracks[0]['id'],
      'timelineRange': {
        'start': end.toJson(),
        'duration': (retainedEnd - end).toJson(),
      },
    });
    end = retainedEnd;
  }
  tracks[0]['items'] = normalized;
  s['duration'] = end.toJson();
  s['version'] = nextVersion(s['id'] as String);
  final after = ProjectDocument.fromJson(d);
  requireLocalEditingWritable(after);
  return after;
}
