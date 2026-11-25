import 'dart:convert';

import 'package:studio_contracts/studio_contracts.dart';

import 'studio_document.dart';

part 'persistent_audio.dart';
part 'multi_move.dart';

typedef VersionAllocator = String Function(String entityId);
typedef IdAllocator = String Function();

sealed class EditOperation {
  const EditOperation();
  Map<String, Object?> toJson();
}

/// Detach only explicit current-head derived references; never deletes CAS bytes.
final class DiscardPreviewProxies extends EditOperation {
  const DiscardPreviewProxies(this.assetId);
  final String assetId;
  @override
  Map<String, Object?> toJson() => {
    'kind': 'discardPreviewProxies',
    'assetId': assetId,
  };
}

ProjectDocument _discardPreviewProxies(
  ProjectDocument before,
  DiscardPreviewProxies op,
  VersionAllocator nextVersion,
) {
  final d = before.toJson();
  final matches = (d['assets'] as List).where((a) => a['id'] == op.assetId);
  if (matches.length != 1) throw const StudioException('REF_NOT_FOUND');
  final asset = matches.single;
  if ((asset['proxyRefs'] as List).isEmpty) return before;
  final removed = <String>{
    for (final p in asset['proxyRefs']) p['blobHash'] as String,
    for (final p in asset['proxyRefs']) p['ptsMapBlobHash'] as String,
  };
  asset['proxyRefs'] = [];
  final version = nextVersion(asset['id']);
  asset['version'] = version;
  final used = <String>{
    for (final a in d['assets']) ...[
      if (a['originalBlobHash'] != null) a['originalBlobHash'] as String,
      for (final p in a['proxyRefs']) p['blobHash'] as String,
      for (final p in a['proxyRefs']) p['ptsMapBlobHash'] as String,
    ],
  };
  (d['blobs'] as List).removeWhere(
    (b) =>
        {'proxy', 'ptsMap'}.contains(b['role']) &&
        removed.contains(b['hash']) &&
        !used.contains(b['hash']),
  );
  for (final sequence in d['sequences']) {
    var changed = false;
    for (final track in sequence['tracks']) {
      for (final clip in track['items']) {
        final source = clip['source'];
        if (source != null &&
            source['kind'] == 'asset' &&
            source['id'] == op.assetId) {
          source['version'] = version;
          clip['version'] = nextVersion(clip['id']);
          changed = true;
        }
      }
    }
    if (changed) sequence['version'] = nextVersion(sequence['id']);
  }
  final result = ProjectDocument.fromJson(d);
  requireLocalEditingWritable(result);
  return result;
}

/// SDK-controlled, fully byte-validated CAS resources, committed with revision CAS.
final class AttachPreviewProxies extends EditOperation {
  AttachPreviewProxies(List<Map<String, dynamic>> resources)
    : _json = jsonEncode(resources);
  final String _json;
  @override
  Map<String, Object?> toJson() => {
    'kind': 'attachPreviewProxies',
    'resources': jsonDecode(_json),
  };
}

ProjectDocument _attachPreviewProxies(
  ProjectDocument before,
  AttachPreviewProxies op,
  VersionAllocator nextVersion,
) {
  final d = before.toJson();
  final changed = <String, String>{};
  for (final raw in op.toJson()['resources'] as List) {
    final a = (d['assets'] as List).singleWhere(
      (a) => a['id'] == raw['assetId'],
    );
    if (changed.containsKey(a['id']) ||
        a['originalBlobHash'] != raw['sourceHash'] ||
        (a['proxyRefs'] as List).isNotEmpty) {
      throw const StudioException('PROXY_ADOPTION_CONFLICT');
    }
    final v = nextVersion(a['id']);
    a['version'] = v;
    changed[a['id'] as String] = v;
    a['proxyRefs'] = [
      {...Map<String, dynamic>.from(raw['proxy'] as Map), 'sourceVersion': v},
    ];
    for (final blob in raw['blobs']) {
      final previous = (d['blobs'] as List).where(
        (b) => b['hash'] == blob['hash'],
      );
      if (previous.isEmpty) {
        d['blobs'].add(blob);
      } else if (contentHash(previous.single) != contentHash(blob)) {
        throw const StudioException('BLOB_METADATA_INVALID');
      }
    }
  }
  if (changed.isEmpty) return before;
  for (final s in d['sequences']) {
    for (final t in s['tracks']) {
      for (final c in t['items']) {
        final source = c['source'];
        if (source != null &&
            source['kind'] == 'asset' &&
            changed.containsKey(source['id'])) {
          source['version'] = changed[source['id']];
          c['version'] = nextVersion(c['id']);
        }
      }
    }
    s['version'] = nextVersion(s['id']);
  }
  final result = ProjectDocument.fromJson(d);
  requireLocalEditingWritable(result);
  return result;
}

final class SetClipOpacity extends EditOperation {
  const SetClipOpacity(this.clipId, this.value);
  final String clipId;
  final double value;
  @override
  Map<String, Object?> toJson() => {
    'kind': 'setClipOpacity',
    'clipId': clipId,
    'value': value,
  };
}

final class SetDissolve extends EditOperation {
  const SetDissolve(this.leftClipId, this.rightClipId, this.before, this.after);
  final String leftClipId, rightClipId;
  final Q before, after;
  @override
  Map<String, Object?> toJson() => {
    'kind': 'setDissolve',
    'leftClipId': leftClipId,
    'rightClipId': rightClipId,
    'before': before.toJson(),
    'after': after.toJson(),
  };
}

final class RemoveDissolve extends EditOperation {
  const RemoveDissolve(this.transitionId);
  final String transitionId;
  @override
  Map<String, Object?> toJson() => {
    'kind': 'removeDissolve',
    'transitionId': transitionId,
  };
}

ProjectDocument _dissolveEdit(
  ProjectDocument before,
  EditOperation op,
  VersionAllocator version,
  IdAllocator id,
) {
  final d = before.toJson(), seq = d['sequences'][0];
  final list = d['transitions'] as List;
  final tracks = seq['tracks'] as List;
  if (op is RemoveDissolve) {
    final found = list.where((t) => t['id'] == op.transitionId).toList();
    if (found.isEmpty) throw const StudioException('NOT_FOUND');
    final track = tracks.singleWhere((t) => t['id'] == found.single['trackId']);
    if (track['locked'] == true) throw const StudioException('FIELD_LOCKED');
    for (final c in track['items']) {
      if ([
            found.single['leftClipId'],
            found.single['rightClipId'],
          ].contains(c['id']) &&
          (c['lockedFields'] as List).any(
            (f) =>
                f == '*' ||
                f == 'transitions' ||
                (f as String).startsWith('transitions.'),
          )) {
        throw const StudioException('FIELD_LOCKED');
      }
    }
    list.removeWhere((t) => t['id'] == op.transitionId);
  } else {
    final x = op as SetDissolve;
    final matches = tracks
        .where((t) => (t['items'] as List).any((c) => c['id'] == x.leftClipId))
        .toList();
    if (matches.length != 1) throw const StudioException('CLIP_NOT_FOUND');
    final track = matches.single;
    if (track['locked'] == true) throw const StudioException('FIELD_LOCKED');
    final left = (track['items'] as List).singleWhere(
      (c) => c['id'] == x.leftClipId,
    );
    for (final c in (track['items'] as List).where(
      (c) => [x.leftClipId, x.rightClipId].contains(c['id']),
    )) {
      if (c['source'] != null &&
          (c['lockedFields'] as List).any(
            (f) =>
                f == '*' ||
                f == 'transitions' ||
                (f as String).startsWith('transitions.'),
          )) {
        throw const StudioException('FIELD_LOCKED');
      }
    }
    final old = list
        .where(
          (t) =>
              t['leftClipId'] == x.leftClipId &&
              t['rightClipId'] == x.rightClipId,
        )
        .toList();
    if (old.isNotEmpty &&
        Q.fromJson(old.single['before']) == x.before &&
        Q.fromJson(old.single['after']) == x.after &&
        old.single['enabled'] == true) {
      return before;
    }
    final tid = old.isEmpty ? id() : old.single['id'] as String;
    list.removeWhere((t) => t['id'] == tid);
    list.add({
      'id': tid,
      'version': version(tid),
      'sequenceId': seq['id'],
      'trackId': track['id'],
      'leftClipId': x.leftClipId,
      'rightClipId': x.rightClipId,
      'cut':
          (Q.fromJson(left['timelineRange']['start']) +
                  Q.fromJson(left['timelineRange']['duration']))
              .toJson(),
      'before': x.before.toJson(),
      'after': x.after.toJson(),
      'kind': 'dissolve',
      'curve': 'linear',
      'missingHandlePolicy': 'reject',
      'enabled': true,
    });
  }
  seq['version'] = version(seq['id']);
  final result = ProjectDocument.fromJson(d);
  requireLocalEditingWritable(result);
  return result;
}

final class SetClipTransform extends EditOperation {
  SetClipTransform(this.clipId, Map<String, double> parameters)
    : parameters = Map.unmodifiable(parameters) {
    validateTransform2d(this.parameters);
  }
  final String clipId;
  final Map<String, double> parameters;
  @override
  Map<String, Object?> toJson() => {
    'kind': 'setClipTransform',
    'clipId': clipId,
    'parameters': parameters,
  };
}

final class SetClipCrop extends EditOperation {
  SetClipCrop(this.clipId, Map<String, double> value)
    : parameters = Map.unmodifiable(value) {
    validateStaticRaster('crop', parameters);
  }
  final String clipId;
  final Map<String, double> parameters;
  @override
  Map<String, Object?> toJson() => {
    'kind': 'setClipCrop',
    'clipId': clipId,
    'parameters': parameters,
  };
}

final class SetClipColorBasic extends EditOperation {
  SetClipColorBasic(this.clipId, Map<String, double> value)
    : parameters = Map.unmodifiable(value) {
    validateStaticRaster('colorBasic', parameters);
  }
  final String clipId;
  final Map<String, double> parameters;
  @override
  Map<String, Object?> toJson() => {
    'kind': 'setClipColorBasic',
    'clipId': clipId,
    'parameters': parameters,
  };
}

ProjectDocument _setStaticVisual(
  ProjectDocument before,
  String clipId,
  String type,
  Map<String, double> parameters,
  VersionAllocator version,
  IdAllocator id,
) {
  final d = before.toJson(), s = d['sequences'][0];
  for (final t in s['tracks']) {
    for (final c in t['items']) {
      if (c['id'] != clipId || c['source'] == null) continue;
      if (t['kind'] != 'video') {
        throw const StudioException('UNSUPPORTED_EDIT_TECHNIQUE');
      }
      if (t['locked'] == true ||
          (c['lockedFields'] as List).any(
            (v) =>
                v == '*' ||
                v == 'effects' ||
                v == 'effectIds' ||
                (v as String).startsWith('effects.') ||
                v.startsWith('effectIds.'),
          )) {
        throw const StudioException('FIELD_LOCKED');
      }
      final existing = admittedClipEffects(
        d,
        c,
      ).where((e) => e['type'] == type);
      final Map? old = existing.isEmpty ? null : existing.single;
      if (old != null &&
          old['enabled'] == true &&
          contentHash(old['parameters']) == contentHash(parameters)) {
        return before;
      }
      final eid = old?['id'] as String? ?? id();
      final effect = {
        'id': eid,
        'version': version(eid),
        'owner': {'kind': 'clip', 'id': c['id']},
        'type': type,
        'pluginVersion': '1.0.0',
        'enabled': true,
        'parameters': parameters,
        'keyframes': <dynamic>[],
        'extensions': <String, dynamic>{},
      };
      d['effects'] = [
        for (final e in d['effects'])
          if (e['id'] != eid) e,
        effect,
      ];
      c['effectIds'] = [
        eid,
        for (final i in c['effectIds'])
          if (i != eid) i,
      ];
      (c['effectIds'] as List).sort(
        (a, b) => visualEffectOrder
            .indexOf(
              (d['effects'] as List).singleWhere((e) => e['id'] == a)['type'],
            )
            .compareTo(
              visualEffectOrder.indexOf(
                (d['effects'] as List).singleWhere((e) => e['id'] == b)['type'],
              ),
            ),
      );
      c['version'] = version(c['id']);
      s['version'] = version(s['id']);
      final result = ProjectDocument.fromJson(d);
      requireLocalEditingWritable(result);
      return result;
    }
  }
  throw const StudioException('CLIP_NOT_FOUND');
}

final class SetOpacityKeyframe extends EditOperation {
  const SetOpacityKeyframe(
    this.clipId,
    this.time,
    this.value, {
    this.interpolation = 'linear',
  });
  final String clipId;
  final Q time;
  final double value;
  final String interpolation;
  @override
  Map<String, Object?> toJson() => {
    'kind': 'setOpacityKeyframe',
    'clipId': clipId,
    'localTime': time.toJson(),
    'value': value,
    'interpolation': interpolation,
  };
}

final class RemoveOpacityKeyframe extends EditOperation {
  const RemoveOpacityKeyframe(this.clipId, this.time);
  final String clipId;
  final Q time;
  @override
  Map<String, Object?> toJson() => {
    'kind': 'removeOpacityKeyframe',
    'clipId': clipId,
    'localTime': time.toJson(),
  };
}

ProjectDocument _opacityKeyframeEdit(
  ProjectDocument before,
  EditOperation operation,
  VersionAllocator version,
  IdAllocator id,
) {
  final adding = operation is SetOpacityKeyframe;
  final clipId = adding
      ? operation.clipId
      : (operation as RemoveOpacityKeyframe).clipId;
  final time = adding
      ? operation.time
      : (operation as RemoveOpacityKeyframe).time;
  var d = before.toJson();
  final sequence = d['sequences'][0];
  Map? selected;
  Map? track;
  for (final t in sequence['tracks']) {
    for (final c in t['items']) {
      if (c['id'] == clipId && c['source'] != null) {
        selected = c;
        track = t;
      }
    }
  }
  if (selected == null) throw const StudioException('CLIP_NOT_FOUND');
  if (track!['kind'] != 'video') {
    throw const StudioException('UNSUPPORTED_EDIT_TECHNIQUE');
  }
  if (track['locked'] == true ||
      (selected['lockedFields'] as List).any(
        (v) =>
            v == '*' ||
            v == 'effects' ||
            v == 'effectIds' ||
            (v as String).startsWith('effects.') ||
            v.startsWith('effectIds.'),
      )) {
    throw const StudioException('FIELD_LOCKED');
  }
  if (time < Q.of(0) ||
      time > Q.fromJson(selected['timelineRange']['duration'])) {
    throw const StudioException('KEYFRAME_OUT_OF_RANGE');
  }
  final fps = FrameRate(sequence['frameRate']['n'], sequence['frameRate']['d']);
  if (fps.quantize(time, Rounding.tiesToEven) != time) {
    throw const StudioException('KEYFRAME_NOT_ON_FRAME');
  }
  if (adding &&
      (!operation.value.isFinite ||
          operation.value < 0 ||
          operation.value > 1)) {
    throw const StudioException('OPACITY_RANGE');
  }
  if (adding && !['hold', 'linear'].contains(operation.interpolation)) {
    throw const StudioException('UNSUPPORTED_EDIT_TECHNIQUE');
  }
  final allIds = selected['effectIds'] as List;
  final ids = admittedClipEffects(
    d,
    selected,
  ).where((e) => e['type'] == 'opacity').map((e) => e['id']).toList();
  Map effect;
  if (ids.isEmpty) {
    if (!adding) throw const StudioException('KEYFRAME_NOT_FOUND');
    final eid = id();
    effect = {
      'id': eid,
      'version': '0',
      'owner': {'kind': 'clip', 'id': clipId},
      'type': 'opacity',
      'pluginVersion': '1.0.0',
      'enabled': true,
      'parameters': {'value': operation.value},
      'keyframes': <Map>[],
      'extensions': <String, dynamic>{},
    };
    (d['effects'] as List).add(effect);
    selected['effectIds'] = [...allIds, eid];
  } else {
    effect =
        (d['effects'] as List).singleWhere((e) => e['id'] == ids.single) as Map;
  }
  final points = List<Map>.from(effect['keyframes']);
  final index = points.indexWhere((k) => Q.fromJson(k['localTime']) == time);
  if (adding) {
    final op = operation;
    if (index >= 0 &&
        points[index]['value'] == op.value &&
        points[index]['interpolation'] == op.interpolation) {
      return before;
    }
    final key = {
      'id': index >= 0 ? points[index]['id'] : id(),
      'param': 'value',
      'localTime': time.toJson(),
      'value': op.value,
      'interpolation': op.interpolation,
      'easing': null,
    };
    if (index >= 0) {
      points[index] = key;
    } else {
      points.add(key);
    }
  } else {
    if (index < 0) throw const StudioException('KEYFRAME_NOT_FOUND');
    points.removeAt(index);
  }
  points.sort(
    (a, b) => Q.fromJson(a['localTime']).compareTo(Q.fromJson(b['localTime'])),
  );
  effect['keyframes'] = points;
  effect['version'] = version(effect['id']);
  selected['version'] = version(clipId);
  sequence['version'] = version(sequence['id']);
  final result = ProjectDocument.fromJson(d);
  requireLocalEditingWritable(result);
  return result;
}

void _normalizeOpacityOwners(
  Map<String, dynamic> d,
  VersionAllocator version,
  IdAllocator id,
  ProjectDocument before,
  EditOperation operation,
) {
  final previous = before.toJson();
  final oldClips = {
    for (final sequence in previous['sequences'])
      for (final track in sequence['tracks'])
        for (final c in track['items'])
          if (c['source'] != null) c['id']: c,
  };
  final effects = {for (final e in d['effects']) e['id']: e};
  final kept = <String, Map>{};
  for (final s in d['sequences']) {
    for (final t in s['tracks']) {
      for (final c in t['items']) {
        if (c['source'] == null) continue;
        final ids = <String>[];
        for (final eid in c['effectIds']) {
          var e = effects[eid] as Map;
          if (e['owner']['id'] != c['id']) {
            final fresh = id();
            e = {
              ...e,
              'id': fresh,
              'version': version(fresh),
              'owner': {'kind': 'clip', 'id': c['id']},
            };
          }
          final old =
              oldClips[c['id']] ?? oldClips[effects[eid]['owner']['id']];
          if ((e['keyframes'] as List).isNotEmpty && old != null) {
            final ownerChanged = e['id'] != eid;
            final duration = Q.fromJson(c['timelineRange']['duration']);
            var offset = Q.of(0);
            if (operation is SplitClip) {
              offset =
                  Q.fromJson(c['timelineRange']['start']) -
                  Q.fromJson(old['timelineRange']['start']);
            } else if (operation is TrimClip ||
                operation is RollCut ||
                operation is SlideClip) {
              offset =
                  (Q.fromJson(c['sourceRange']['start']) -
                      Q.fromJson(old['sourceRange']['start'])) /
                  Q.fromJson(old['timeMap']['rate']);
            }
            final crop =
                offset != Q.of(0) ||
                duration != Q.fromJson(old['timelineRange']['duration']);
            if (crop &&
                (old['lockedFields'] as List).any(
                  (v) =>
                      v == '*' ||
                      v == 'effects' ||
                      v == 'effectIds' ||
                      (v as String).startsWith('effects.') ||
                      v.startsWith('effectIds.'),
                )) {
              throw const StudioException('FIELD_LOCKED');
            }
            if (crop || ownerChanged) {
              e = {
                ...e,
                'version': ownerChanged ? e['version'] : version(e['id']),
                'keyframes': crop
                    ? cropOpacityPoints(e, offset, duration, id)
                    : List<Map>.from(e['keyframes']),
              };
              if (ownerChanged) {
                e['keyframes'] = [
                  for (final k in e['keyframes']) {...k, 'id': id()},
                ];
              }
            }
          }
          ids.add(e['id'] as String);
          kept[e['id'] as String] = e;
        }
        c['effectIds'] = ids;
      }
    }
  }
  d['effects'] = kept.values.toList();
}

ProjectDocument _setOpacity(
  ProjectDocument before,
  SetClipOpacity op,
  VersionAllocator version,
  IdAllocator id,
) {
  if (!op.value.isFinite || op.value < 0 || op.value > 1) {
    throw const StudioException('OPACITY_RANGE');
  }
  final d = before.toJson(), s = d['sequences'][0];
  for (final t in s['tracks']) {
    for (final c in t['items']) {
      if (c['id'] != op.clipId || c['source'] == null) continue;
      if (t['kind'] != 'video') {
        throw const StudioException('UNSUPPORTED_EDIT_TECHNIQUE');
      }
      if (t['locked'] == true ||
          (c['lockedFields'] as List).any(
            (v) =>
                v == 'effectIds' ||
                v == 'effects' ||
                v == '*' ||
                (v as String).startsWith('effectIds.') ||
                v.startsWith('effects.'),
          )) {
        throw const StudioException('FIELD_LOCKED');
      }
      final allIds = c['effectIds'] as List;
      final ids = admittedClipEffects(
        d,
        c,
      ).where((e) => e['type'] == 'opacity').map((e) => e['id']).toList();
      if (ids.isNotEmpty &&
          ((d['effects'] as List).singleWhere(
                    (e) => e['id'] == ids.single,
                  )['keyframes']
                  as List)
              .isNotEmpty) {
        throw const StudioException(
          'ANIMATED_OPACITY_REQUIRES_EXPLICIT_KEYFRAME_EDIT',
        );
      }
      if (ids.isEmpty && op.value == 1) return before;
      Map? existing = ids.isEmpty
          ? null
          : (d['effects'] as List).singleWhere((e) => e['id'] == ids.single)
                as Map;
      if (existing != null &&
          existing['parameters']['value'] == op.value &&
          existing['enabled'] == true) {
        return before;
      }
      final eid = existing?['id'] as String? ?? id();
      final e = {
        'id': eid,
        'version': version(eid),
        'owner': {'kind': 'clip', 'id': c['id']},
        'type': 'opacity',
        'pluginVersion': '1.0.0',
        'enabled': true,
        'parameters': {'value': op.value},
        'keyframes': <dynamic>[],
        'extensions': <String, dynamic>{},
      };
      d['effects'] = [
        for (final old in d['effects'])
          if (old['id'] != eid) old,
        e,
      ];
      c['effectIds'] = [
        for (final i in allIds)
          if (i != eid) i,
        eid,
      ];
      c['version'] = version(c['id']);
      s['version'] = version(s['id']);
      final result = ProjectDocument.fromJson(d);
      requireLocalEditingWritable(result);
      return result;
    }
  }
  throw const StudioException('CLIP_NOT_FOUND');
}

final class SetMasterAudio extends EditOperation {
  const SetMasterAudio({
    this.gainDb = 0,
    this.pan = 0,
    this.muted = false,
    this.solo = false,
  });
  final double gainDb, pan;
  final bool muted, solo;
  @override
  Map<String, Object?> toJson() {
    AudioBus(
      id: 'validation',
      inputs: const [],
      gainDb: gainDb,
      pan: pan,
      muted: muted,
      solo: solo,
    );
    return {
      'kind': 'setMasterAudio',
      'gainDb': gainDb,
      'pan': pan,
      'muted': muted,
      'solo': solo,
    };
  }
}

final class RenameProject extends EditOperation {
  const RenameProject(this.title);
  final String title;
  @override
  Map<String, Object?> toJson() => {'kind': 'renameProject', 'title': title};
}

/// One atomic caption-set command; rich unsupported fields are never discarded.
final class SetCaptions extends EditOperation {
  SetCaptions(CaptionStore value, {this.automatic = false})
    : _json = jsonEncode([
        for (final c in value.cues) c.toProjectJson('pending'),
      ]);
  final String _json;
  final bool automatic;
  List<CaptionCue> get cues => (jsonDecode(_json) as List)
      .map((c) => CaptionCue.fromProjectJson(c as Map<String, dynamic>))
      .toList();
  @override
  Map<String, Object?> toJson() => {
    'kind': 'setCaptions',
    'automatic': automatic,
    'cues': jsonDecode(_json),
  };
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
  if (operation is MoveClips) {
    return _moveClips(before, operation, nextVersion, newId);
  }
  if (operation is SetOpacityKeyframe || operation is RemoveOpacityKeyframe) {
    return _opacityKeyframeEdit(before, operation, nextVersion, newId);
  }
  if (operation is SetDissolve || operation is RemoveDissolve) {
    return _dissolveEdit(before, operation, nextVersion, newId);
  }
  // Do not silently move/drop a transition when editing its topology.
  // Explicit removal is reversible; slip remains allowed if handles revalidate.
  if ((before.toJson()['transitions'] as List).isNotEmpty &&
      (operation is SplitClip ||
          operation is TrimClip ||
          operation is MoveClip ||
          operation is RollCut ||
          operation is SlideClip)) {
    throw const StudioException('TRANSITION_RANGE_EDIT_REQUIRES_REMOVAL');
  }
  if (operation is SetClipTransform) {
    return _setStaticVisual(
      before,
      operation.clipId,
      'transform2d',
      operation.parameters,
      nextVersion,
      newId,
    );
  }
  if (operation is SetClipCrop) {
    return _setStaticVisual(
      before,
      operation.clipId,
      'crop',
      operation.parameters,
      nextVersion,
      newId,
    );
  }
  if (operation is SetClipColorBasic) {
    return _setStaticVisual(
      before,
      operation.clipId,
      'colorBasic',
      operation.parameters,
      nextVersion,
      newId,
    );
  }
  if (operation is SetClipOpacity) {
    return _setOpacity(before, operation, nextVersion, newId);
  }
  if (operation is DiscardPreviewProxies) {
    return _discardPreviewProxies(before, operation, nextVersion);
  }
  if (operation is AttachPreviewProxies) {
    return _attachPreviewProxies(before, operation, nextVersion);
  }
  if (operation is ExtractAudioClip ||
      operation is LinkAudioVideo ||
      operation is UnlinkAudioVideo ||
      operation is SetAudioTrackState ||
      ((before.toJson()['sequences'][0]['tracks'] as List).any(
            (t) => t['kind'] == 'audio',
          ) &&
          operation is! SetMasterAudio &&
          operation is! RenameProject &&
          operation is! SetCaptions &&
          operation is! AppendVideoAsset)) {
    return _persistentAudioEdit(before, operation, nextVersion, newId);
  }
  if (operation is SetMasterAudio) {
    AudioBus(
      id: 'validated-master',
      inputs: [],
      gainDb: operation.gainDb,
      pan: operation.pan,
      muted: operation.muted,
      solo: operation.solo,
    );
    final d = before.toJson(),
        b = (before.toJson()['audioBuses'] as List).single;
    if (b['gainDb'] == operation.gainDb &&
        b['pan'] == operation.pan &&
        b['muted'] == operation.muted &&
        b['solo'] == operation.solo) {
      return before;
    }
    b['gainDb'] = operation.gainDb;
    b['pan'] = operation.pan;
    b['muted'] = operation.muted;
    b['solo'] = operation.solo;
    d['audioBuses'] = [b];
    // AudioBus is unversioned, but its rendered sequence definition is not.
    // Local writable admission currently permits exactly one sequence/bus.
    for (final sequence in d['sequences']) {
      sequence['version'] = nextVersion(sequence['id'] as String);
    }
    return ProjectDocument.fromJson(d);
  }
  if (operation is RenameProject) {
    return before.withTitle(operation.title, before.revision);
  }
  if (operation is SetCaptions) {
    return _setCaptions(before, operation, nextVersion, newId);
  }
  if ((before.toJson()['captions'] as List).isNotEmpty &&
      operation is! AppendVideoAsset) {
    throw const StudioException('CAPTION_SYNC_EDIT_NOT_IMPLEMENTED');
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
  if ((d['captions'] as List).isNotEmpty) {
    retainedEnd = Q.of(0);
    for (final track in tracks.where((t) => t['kind'] == 'video')) {
      for (final item in track['items']) {
        final r = item['timelineRange'];
        final end = Q.fromJson(r['start']) + Q.fromJson(r['duration']);
        if (end > retainedEnd) retainedEnd = end;
      }
    }
  }
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
      case MoveClips():
      case DiscardPreviewProxies():
      case AttachPreviewProxies():
        throw StateError("handled above");
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
    case MoveClips():
    case DiscardPreviewProxies():
    case AttachPreviewProxies():
      throw StateError("handled above");
    case ExtractAudioClip():
    case LinkAudioVideo():
    case UnlinkAudioVideo():
    case SetAudioTrackState():
      throw StateError('persistent audio dispatch');
    case SetDissolve():
    case RemoveDissolve():
    case SetClipCrop():
    case SetClipColorBasic():
    case SetClipTransform():
    case SetClipOpacity():
    case SetOpacityKeyframe():
    case RemoveOpacityKeyframe():
    case SetMasterAudio():
      throw StateError('Handled master audio edit');
    case SetCaptions():
      throw StateError('Handled caption edit');
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
      if (tracks.isEmpty || tracks[0]['kind'] != 'video') {
        for (final t in tracks) {
          t['order'] = (t['order'] as int) + 1;
        }
        tracks.insert(0, {
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
          'start': retainedEnd.toJson(),
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
  for (final c in d['captions'] as List) {
    final r = c['timelineRange'];
    final captionEnd = Q.fromJson(r['start']) + Q.fromJson(r['duration']);
    if (captionEnd > end) end = captionEnd;
  }
  s['duration'] = end.toJson();
  s['version'] = nextVersion(s['id'] as String);
  _normalizeOpacityOwners(d, nextVersion, newId, before, operation);
  final after = ProjectDocument.fromJson(d);
  requireLocalEditingWritable(after);
  return after;
}

ProjectDocument _setCaptions(
  ProjectDocument before,
  SetCaptions operation,
  VersionAllocator nextVersion,
  IdAllocator newId,
) {
  final d = before.toJson();
  // Work ONLY on the detached document that will be validated below.
  final s = d['sequences'][0],
      tracks = s['tracks'] as List,
      old = d['captions'] as List;
  final captions =
      operation.cues; // constructor already enforces deterministic nonoverlap.
  final existingTracks = tracks.where((t) => t['kind'] == 'caption');
  if (existingTracks.any((t) => t['locked'] == true)) {
    throw const StudioException('FIELD_LOCKED');
  }
  if (old.isEmpty && captions.isEmpty) return before;
  final track = existingTracks.isEmpty ? null : existingTracks.single;
  final trackId = track == null ? newId() : track['id'] as String;
  final byId = {for (final c in old) c['id']: c};
  final result = <Map<String, Object?>>[];
  if (operation.automatic) {
    final incoming = {for (final c in captions) c.id: c};
    for (final c in old) {
      final fields = Set<String>.from(c['manualFields'] as List),
          next = incoming[c['id']];
      if (next == null && fields.isNotEmpty) {
        throw const StudioException('MANUAL_FIELD_LOCKED');
      }
      if (next != null &&
          ((fields.contains('text') && next.text != c['text']) ||
              (fields.contains('timing') &&
                  contentHash(next.toProjectJson(trackId)['timelineRange']) !=
                      contentHash(c['timelineRange'])))) {
        throw const StudioException('MANUAL_FIELD_LOCKED');
      }
    }
  }
  for (final c in captions) {
    final prev = byId[c.id];
    var next = c.toProjectJson(trackId);
    if (operation.automatic && prev != null) {
      next = {
        ...next,
        'manualFields': ({
          ...c.manualFields,
          ...Set<String>.from(prev['manualFields'] as List),
        }.toList()..sort()),
      };
    }
    final left = prev == null ? null : Map<String, dynamic>.from(prev);
    left?.remove('version');
    final right = Map<String, Object?>.from(next)..remove('version');
    next['version'] = left != null && contentHash(left) == contentHash(right)
        ? prev['version']
        : nextVersion(c.id);
    result.add(next);
  }
  if (contentHash(old) == contentHash(result)) return before;
  if (track == null) {
    tracks.add({
      'id': trackId,
      'sequenceId': s['id'],
      'name': 'Captions',
      'kind': 'caption',
      'order': tracks.length,
      'locked': false,
      'muted': false,
      'solo': false,
      'syncLock': true,
      'targeted': true,
      'busId': null,
      'items': <Object>[],
    });
  }
  d['captions'] = result;
  var end = Q.of(0);
  for (final t in tracks) {
    for (final item in t['items']) {
      final r = item['timelineRange'];
      final e = Q.fromJson(r['start']) + Q.fromJson(r['duration']);
      if (e > end) end = e;
    }
  }
  for (final c in captions) {
    if (c.range.end > end) end = c.range.end;
  }
  for (final c in d['captions'] as List) {
    final r = c['timelineRange'];
    final captionEnd = Q.fromJson(r['start']) + Q.fromJson(r['duration']);
    if (captionEnd > end) end = captionEnd;
  }
  s['duration'] = end.toJson();
  s['version'] = nextVersion(s['id'] as String);
  final after = ProjectDocument.fromJson(d);
  requireLocalEditingWritable(after);
  return after;
}
