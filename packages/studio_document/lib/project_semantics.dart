part of 'validator.dart';

const _entityTables = [
  'sequences',
  'assets',
  'effects',
  'transitions',
  'captions',
  'audioBuses',
  'markers',
  'rightsRecords',
  'linkGroups',
  'selectionGroups',
  'imageDocuments',
  'briefs',
  'scripts',
  'scenes',
  'characters',
  'shots',
  'generationRecords',
  'fontRefs',
];

/// Project-local semantic closure. External provider/template/license/job IDs are
/// NOT invented project FKs. Retained definition bytes still require resource
/// admission before rendering; this validator never fetches files or network refs.
void _projectSemantics(
  Map<String, dynamic> d,
  void Function(String, String) issue,
) {
  final indexes = {
    for (final name in _entityTables)
      name: {for (final x in d[name] as List) x['id']: x},
  };
  final tracks = <dynamic, dynamic>{},
      clips = <dynamic, dynamic>{},
      layers = <dynamic, dynamic>{},
      sequenceFor = <dynamic, dynamic>{};
  final blobs = {for (final x in d['blobs'] as List) x['hash']: x};
  if (blobs.length != (d['blobs'] as List).length) {
    issue('DUPLICATE_BLOB', '/blobs');
  }
  void ref(String table, dynamic id, String path, {bool nullable = false}) {
    if (id == null && nullable) return;
    if (!(indexes[table]?.containsKey(id) ?? false)) {
      issue('REF_NOT_FOUND', path);
    }
  }

  void blob(dynamic hash, String path, {bool nullable = false}) {
    if (hash == null && nullable) return;
    if (!blobs.containsKey(hash)) issue('REF_NOT_FOUND', path);
  }

  void unique(List values, String path) {
    if (values.toSet().length != values.length) {
      issue('DUPLICATE_REFERENCE', path);
    }
  }

  Q q(dynamic x) => Q.fromJson(Map<String, dynamic>.from(x as Map));
  Q start(dynamic c) => q(c['timelineRange']['start']);
  Q duration(dynamic c) => q(c['timelineRange']['duration']);
  Q end(dynamic c) => start(c) + duration(c);
  for (final s in d['sequences']) {
    for (final t in s['tracks']) {
      tracks[t['id']] = t;
      sequenceFor[t['id']] = s;
      for (final c in t['items']) {
        if (c['source'] != null) {
          clips[c['id']] = c;
          sequenceFor[c['id']] = s;
        }
      }
    }
  }
  for (final im in d['imageDocuments']) {
    for (final l in im['layers']) {
      layers[l['id']] = l;
    }
  }
  bool localRef(Map source, String table, String path) {
    final current = indexes[table]?[source['id']];
    if (current != null && current['version'] == source['version']) return true;
    final historical = (d['retainedSources'] as List).any(
      (x) =>
          x['kind'] == source['kind'] &&
          x['id'] == source['id'] &&
          x['version'] == source['version'],
    );
    if (!historical) {
      issue(current == null ? 'REF_NOT_FOUND' : 'SOURCE_VERSION_MISSING', path);
    }
    return false;
  }

  for (final retained in d['retainedSources']) {
    blob(retained['definitionBlobHash'], '/retainedSources/definitionBlobHash');
    for (final h in retained['dependencyBlobHashes']) {
      blob(h, '/retainedSources/dependencyBlobHashes');
    }
  }
  final retainedKeys = <String>{};
  for (final x in d['retainedSources']) {
    if (!retainedKeys.add('${x['kind']}:${x['id']}:${x['version']}')) {
      issue('DUPLICATE_REFERENCE', '/retainedSources');
    }
  }
  for (final a in d['assets']) {
    ref('rightsRecords', a['rightsId'], '/assets/rightsId');
    blob(
      a['originalBlobHash'],
      '/assets/originalBlobHash',
      nullable: a['externalLocator'] != null || a['status'] != 'ready',
    );
    if (a['rightsId'] != null &&
        indexes['rightsRecords']!.containsKey(a['rightsId']) &&
        !(indexes['rightsRecords']![a['rightsId']]['assetIds'] as List)
            .contains(a['id'])) {
      issue('RIGHTS_REFERENCE_MISMATCH', '/assets/rightsId');
    }
    for (final st in a['streams']) {
      if (q(st['timeBase']) <= Q.of(0) || q(st['duration']) < Q.of(0)) {
        issue('INVALID_RANGE', '/assets/streams');
      }
    }
    for (final p in a['proxyRefs']) {
      blob(p['blobHash'], '/assets/proxyRefs/blobHash');
      blob(p['ptsMapBlobHash'], '/assets/proxyRefs/ptsMapBlobHash');
      if (p['sourceVersion'] != a['version']) {
        issue('SOURCE_VERSION_MISSING', '/assets/proxyRefs/sourceVersion');
      }
    }
  }
  for (final right in d['rightsRecords']) {
    unique(right['assetIds'] as List, '/rightsRecords/assetIds');
    for (final id in right['assetIds']) {
      ref('assets', id, '/rightsRecords/assetIds');
      if (indexes['assets']!.containsKey(id) &&
          indexes['assets']![id]['rightsId'] != right['id']) {
        issue('RIGHTS_REFERENCE_MISMATCH', '/rightsRecords/assetIds');
      }
    }
    blob(
      right['evidenceBlobHash'],
      '/rightsRecords/evidenceBlobHash',
      nullable: true,
    );
  }
  final nesting = <dynamic, List<dynamic>>{};
  for (final s in d['sequences']) {
    nesting[s['id']] = [];
    unique(s['markerIds'] as List, '/sequences/markerIds');
    for (final id in s['markerIds']) {
      ref('markers', id, '/sequences/markerIds');
      if (indexes['markers']!.containsKey(id) &&
          indexes['markers']![id]['sequenceId'] != s['id']) {
        issue('PARENT_MISMATCH', '/sequences/markerIds');
      }
    }
    if (indexes['audioBuses']![s['masterBusId']]?['outputBusId'] != null) {
      issue('AUDIO_MASTER_INVALID', '/sequences/masterBusId');
    }
    for (final t in s['tracks']) {
      for (final c in t['items']) {
        if (c['source'] == null) continue;
        final source = c['source'] as Map, kind = source['kind'];
        final table = {
          'asset': 'assets',
          'sequence': 'sequences',
          'imageDocument': 'imageDocuments',
        }[kind]!;
        final current = localRef(source, table, '/clips/source');
        final sr = c['sourceRange'],
            sourceStart = q(sr['start']),
            sourceDuration = q(sr['duration']);
        if (sourceStart < Q.of(0) || sourceDuration <= Q.of(0)) {
          issue('INVALID_RANGE', '/clips/sourceRange');
        }
        if (c['timeMap']['kind'] == 'linear') {
          final rate = q(c['timeMap']['rate']);
          if (rate <= Q.of(0) || rate * duration(c) != sourceDuration) {
            issue('TIME_MAP_MISMATCH', '/clips/timeMap');
          }
        } else {
          final knots = c['timeMap']['knots'] as List;
          if (q(knots.first['u']) != Q.of(0) ||
              q(knots.first['v']) != Q.of(0) ||
              q(knots.last['u']) != duration(c) ||
              q(knots.last['v']) != sourceDuration) {
            issue('TIME_MAP_MISMATCH', '/clips/timeMap');
          }
          for (var i = 1; i < knots.length; i++) {
            if (q(knots[i]['u']) <= q(knots[i - 1]['u']) ||
                q(knots[i]['v']) <= q(knots[i - 1]['v'])) {
              issue('TIME_MAP_MISMATCH', '/clips/timeMap');
            }
          }
        }
        if (kind == 'asset' && current) {
          final a = indexes['assets']![source['id']],
              streams = (a['streams'] as List)
                  .where((x) => x['id'] == source['streamId'])
                  .toList();
          if (streams.length != 1 || streams.single['type'] != t['kind']) {
            issue('SOURCE_STREAM_MISMATCH', '/clips/source/streamId');
          } else if (sourceStart + sourceDuration >
              q(streams.single['duration'])) {
            issue('SOURCE_OUT_OF_RANGE', '/clips/sourceRange');
          }
        } else if (kind != 'asset') {
          if (source['streamId'] != null) {
            issue('SOURCE_STREAM_MISMATCH', '/clips/source/streamId');
          }
          if (kind == 'sequence') {
            if (current) nesting[s['id']]!.add(source['id']);
            if (current &&
                sourceStart + sourceDuration >
                    q(indexes[table]![source['id']]['duration'])) {
              issue('SOURCE_OUT_OF_RANGE', '/clips/sourceRange');
            }
          }
        }
        unique(c['lockedFields'] as List, '/clips/lockedFields');
        ref(
          'linkGroups',
          c['linkGroupId'],
          '/clips/linkGroupId',
          nullable: true,
        );
        ref(
          'selectionGroups',
          c['selectionGroupId'],
          '/clips/selectionGroupId',
          nullable: true,
        );
        ref('shots', c['shotId'], '/clips/shotId', nullable: true);
        ref(
          'generationRecords',
          c['provenanceId'],
          '/clips/provenanceId',
          nullable: true,
        );
      }
    }
  }
  final nestStates = <String>{};
  void nest(dynamic id, Set<dynamic> visiting, int depth) {
    if (depth > 8) {
      issue('NEST_DEPTH', '/sequences');
      return;
    }
    if (visiting.contains(id)) {
      issue('REFERENCE_CYCLE', '/sequences');
      return;
    }
    if (!nestStates.add('$id:$depth')) return;
    for (final child in nesting[id] ?? []) {
      nest(child, {...visiting, id}, depth + 1);
    }
  }

  for (final id in nesting.keys) {
    nest(id, {}, 1);
  }
  final masters = {for (final s in d['sequences']) s['masterBusId']};
  for (final b in d['audioBuses']) {
    unique(b['inputBusIds'] as List, '/audioBuses/inputBusIds');
    for (final id in b['inputBusIds']) {
      ref('audioBuses', id, '/audioBuses/inputBusIds');
      if (indexes['audioBuses']!.containsKey(id) &&
          indexes['audioBuses']![id]['outputBusId'] != b['id']) {
        issue('AUDIO_ROUTE_MISMATCH', '/audioBuses/inputBusIds');
      }
    }
    if (b['outputBusId'] == null) {
      if (!masters.contains(b['id'])) {
        issue('AUDIO_MASTER_INVALID', '/audioBuses/outputBusId');
      }
    } else if (indexes['audioBuses']!.containsKey(b['outputBusId']) &&
        !(indexes['audioBuses']![b['outputBusId']]['inputBusIds'] as List)
            .contains(b['id'])) {
      issue('AUDIO_ROUTE_MISMATCH', '/audioBuses/outputBusId');
    }
  }
  final windows = <dynamic, List<TimeRange>>{};
  for (final transition in d['transitions']) {
    final left = clips[transition['leftClipId']],
        right = clips[transition['rightClipId']],
        track = tracks[transition['trackId']];
    if (left == null || right == null || track == null) {
      issue('REF_NOT_FOUND', '/transitions');
      continue;
    }
    final cut = q(transition['cut']),
        before = q(transition['before']),
        after = q(transition['after']);
    if (track['sequenceId'] != transition['sequenceId'] ||
        left['trackId'] != track['id'] ||
        right['trackId'] != track['id'] ||
        end(left) != cut ||
        start(right) != cut) {
      issue('TRANSITION_NOT_ADJACENT', '/transitions');
    }
    if (before < Q.of(0) ||
        after < Q.of(0) ||
        before + after <= Q.of(0) ||
        before > duration(left) ||
        after > duration(right)) {
      issue('TRANSITION_RANGE', '/transitions');
    }
    if ((transition['kind'] == 'audioEqualPower') !=
        (track['kind'] == 'audio')) {
      issue('TRANSITION_TRACK_MISMATCH', '/transitions');
    }
    if (before + after > Q.of(0)) {
      final window = TimeRange(cut - before, before + after);
      for (final clip in [left, right]) {
        final previous = windows.putIfAbsent(clip['id'], () => []);
        for (final old in previous) {
          if (window.start < old.end && old.start < window.end) {
            issue('TRANSITION_WINDOW_OVERLAP', '/transitions');
          }
        }
        previous.add(window);
      }
    }
    if (transition['missingHandlePolicy'] == 'reject') {
      for (final pair in [
        [left, after, true],
        [right, before, false],
      ]) {
        final clip = pair[0] as Map,
            need = pair[1] as Q,
            tail = pair[2] as bool;
        final src = clip['source'];
        if (src['kind'] != 'asset' || clip['timeMap']['kind'] != 'linear') {
          continue;
        }
        final asset = indexes['assets']![src['id']];
        if (asset == null || asset['version'] != src['version']) continue;
        final streams = (asset['streams'] as List).where(
          (s) => s['id'] == src['streamId'],
        );
        if (streams.length != 1) continue;
        final available = tail
            ? q(streams.single['duration']) -
                  q(clip['sourceRange']['start']) -
                  q(clip['sourceRange']['duration'])
            : q(clip['sourceRange']['start']);
        if (available < need * q(clip['timeMap']['rate'])) {
          issue('TRANSITION_HANDLE_MISSING', '/transitions');
        }
      }
    }
  }
  for (final g in d['linkGroups']) {
    final members = g['members'] as List,
        ids = members.map((x) => x['clipId']).toList();
    unique(ids, '/linkGroups/members');
    final anchor = clips[g['anchorClipId']];
    if (anchor == null || !ids.contains(g['anchorClipId'])) {
      issue('REF_NOT_FOUND', '/linkGroups/anchorClipId');
      continue;
    }
    for (final member in members) {
      final c = clips[member['clipId']];
      if (c == null) {
        issue('REF_NOT_FOUND', '/linkGroups/members');
        continue;
      }
      if (c['linkGroupId'] != g['id'] ||
          sequenceFor[c['id']]['id'] != sequenceFor[anchor['id']]['id']) {
        issue('LINK_MEMBERSHIP_MISMATCH', '/linkGroups');
      }
      if (g['syncPolicy'] != 'allowOutOfSync' &&
          start(c) - start(anchor) != q(member['offset'])) {
        issue('LINK_OFFSET_MISMATCH', '/linkGroups/members');
      }
    }
  }
  for (final c in clips.values) {
    if (c['linkGroupId'] != null &&
        indexes['linkGroups']!.containsKey(c['linkGroupId']) &&
        !(indexes['linkGroups']![c['linkGroupId']]['members'] as List).any(
          (x) => x['clipId'] == c['id'],
        )) {
      issue('LINK_MEMBERSHIP_MISMATCH', '/clips/linkGroupId');
    }
  }
  for (final g in d['selectionGroups']) {
    unique(g['memberClipIds'] as List, '/selectionGroups/memberClipIds');
    for (final id in g['memberClipIds']) {
      if (clips[id] == null) {
        issue('REF_NOT_FOUND', '/selectionGroups/memberClipIds');
      } else if (clips[id]['selectionGroupId'] != g['id']) {
        issue('GROUP_MEMBERSHIP_MISMATCH', '/selectionGroups');
      }
    }
  }
  for (final c in clips.values) {
    if (c['selectionGroupId'] != null &&
        indexes['selectionGroups']!.containsKey(c['selectionGroupId']) &&
        !(indexes['selectionGroups']![c['selectionGroupId']]['memberClipIds']
                as List)
            .contains(c['id'])) {
      issue('GROUP_MEMBERSHIP_MISMATCH', '/clips/selectionGroupId');
    }
  }
  Map? owner(Map o) => switch (o['kind']) {
    'clip' => clips[o['id']],
    'track' => tracks[o['id']],
    'sequence' => indexes['sequences']![o['id']],
    'caption' => indexes['captions']![o['id']],
    'imageLayer' => layers[o['id']],
    'audioBus' => indexes['audioBuses']![o['id']],
    _ => null,
  };
  void effects(List ids, String kind, dynamic id, String path) {
    unique(ids, path);
    for (final e in ids) {
      ref('effects', e, path);
      final effect = indexes['effects']![e];
      if (effect != null &&
          (effect['owner']['kind'] != kind || effect['owner']['id'] != id)) {
        issue('EFFECT_OWNER_MISMATCH', path);
      }
    }
  }

  for (final c in clips.values) {
    effects(c['effectIds'] as List, 'clip', c['id'], '/clips/effectIds');
  }
  for (final b in d['audioBuses']) {
    effects(
      b['effectIds'] as List,
      'audioBus',
      b['id'],
      '/audioBuses/effectIds',
    );
  }
  for (final effect in d['effects']) {
    final own = owner(effect['owner'] as Map);
    if (own == null) {
      issue('REF_NOT_FOUND', '/effects/owner');
      continue;
    }
    if (own['effectIds'] is List &&
        !(own['effectIds'] as List).contains(effect['id'])) {
      issue('EFFECT_OWNER_MISMATCH', '/effects/owner');
    }
    final durationValue = own['timelineRange']?['duration'] ?? own['duration'];
    final points = <String>{};
    for (final key in effect['keyframes']) {
      final time = q(key['localTime']);
      if (time < Q.of(0) ||
          (durationValue != null && time > q(durationValue))) {
        issue('KEYFRAME_OUT_OF_RANGE', '/effects/keyframes');
      }
      if (!points.add('${key['param']}:${time.toJson()}')) {
        issue('DUPLICATE_KEYFRAME', '/effects/keyframes');
      }
      if (!(effect['parameters'] as Map).containsKey(key['param'])) {
        issue('KEYFRAME_PARAMETER_MISSING', '/effects/keyframes');
      }
    }
    if (effect['type'] == 'mask') {
      blob(effect['parameters']['blobHash'], '/effects/parameters/blobHash');
    }
    if (effect['type'] == 'textStyle') {
      ref(
        'fontRefs',
        effect['parameters']['fontRef'],
        '/effects/parameters/fontRef',
      );
    }
  }
  for (final c in d['captions']) {
    if (tracks[c['trackId']]?['kind'] != 'caption') {
      issue('CAPTION_TRACK_MISMATCH', '/captions/trackId');
    }
    if (c['styleEffectId'] != null) {
      ref('effects', c['styleEffectId'], '/captions/styleEffectId');
      final e = indexes['effects']![c['styleEffectId']];
      if (e != null &&
          (e['owner']['id'] != c['id'] ||
              e['owner']['kind'] != 'caption' ||
              e['type'] != 'textStyle')) {
        issue('EFFECT_OWNER_MISMATCH', '/captions/styleEffectId');
      }
    }
    final anchor = c['anchor'];
    if (anchor['kind'] == 'absolute') {
      if (anchor['clipId'] != null || anchor['range'] != null) {
        issue('ANCHOR_INVALID', '/captions/anchor');
      }
    } else {
      final clip = clips[anchor['clipId']];
      if (clip == null || anchor['range'] == null) {
        issue('REF_NOT_FOUND', '/captions/anchor');
      } else {
        final ar = anchor['range'];
        final limit = anchor['kind'] == 'source'
            ? q(clip['sourceRange']['duration'])
            : duration(clip);
        if (q(ar['start']) < Q.of(0) ||
            q(ar['start']) + q(ar['duration']) > limit) {
          issue('ANCHOR_OUT_OF_RANGE', '/captions/anchor');
        }
      }
    }
  }
  for (final m in d['markers']) {
    ref('sequences', m['sequenceId'], '/markers/sequenceId');
    if (q(m['time']) < Q.of(0) || q(m['duration']) < Q.of(0)) {
      issue('INVALID_RANGE', '/markers');
    }
    if (m['anchor']['kind'] == 'clipLocal') {
      if (clips[m['anchor']['clipId']] == null) {
        issue('REF_NOT_FOUND', '/markers/anchor');
      }
    } else if (m['anchor']['clipId'] != null) {
      issue('ANCHOR_INVALID', '/markers/anchor');
    }
  }
  // Story and image references are project data too, even when local editing is
  // intentionally read-only. Unknown plugins/extensions remain opaque/preserved.
  for (final im in d['imageDocuments']) {
    final ownLayers = {for (final l in im['layers']) l['id']: l};
    unique(im['rootLayerIds'] as List, '/imageDocuments/rootLayerIds');
    for (final id in im['rootLayerIds']) {
      if (ownLayers[id] == null || ownLayers[id]['parentId'] != null) {
        issue('PARENT_MISMATCH', '/imageDocuments/rootLayerIds');
      }
    }
    final parentDone = <dynamic>{},
        roots = (im['rootLayerIds'] as List).toSet();
    for (final l in ownLayers.values) {
      if (l['parentId'] != null && !ownLayers.containsKey(l['parentId'])) {
        issue('REF_NOT_FOUND', '/imageDocuments/layers/parentId');
      }
      if (l['parentId'] == null && !roots.contains(l['id'])) {
        issue('PARENT_MISMATCH', '/imageDocuments/layers');
      }
      var p = l['id'];
      final seen = <dynamic>{};
      while (p != null && ownLayers.containsKey(p) && !parentDone.contains(p)) {
        if (!seen.add(p)) {
          issue('REFERENCE_CYCLE', '/imageDocuments/layers');
          break;
        }
        p = ownLayers[p]['parentId'];
      }
      parentDone.addAll(seen);
      effects(
        l['effectIds'] as List,
        'imageLayer',
        l['id'],
        '/imageDocuments/layers/effectIds',
      );
      blob(l['maskRef'], '/imageDocuments/layers/maskRef', nullable: true);
      if (l['sourceRef'] != null) {
        localRef(
          {...l['sourceRef'], 'kind': 'asset'},
          'assets',
          '/imageDocuments/layers/sourceRef',
        );
      }
    }
    for (final id in im['fontRefs']) {
      ref('fontRefs', id, '/imageDocuments/fontRefs');
    }
  }
  ref('fontRefs', d['defaultFontRef'], '/defaultFontRef', nullable: true);
  void entityRef(dynamic value, String table, String path) {
    if (value == null) return;
    if (table == 'assets') {
      localRef({...value, 'kind': 'asset'}, table, path);
      return;
    }
    final target = indexes[table]?[value['id']];
    if (target == null) {
      issue('REF_NOT_FOUND', path);
    } else if (target['version'] != value['version']) {
      issue('SOURCE_VERSION_MISSING', path);
    }
  }

  void references(List list, String path) {
    for (final x in list) {
      entityRef(x['assetRef'], 'assets', path);
      ref('rightsRecords', x['rightsId'], path);
    }
  }

  for (final b in d['briefs']) {
    references(b['referenceRefs'] as List, '/briefs/referenceRefs');
  }
  for (final c in d['characters']) {
    entityRef(c['appearanceRef'], 'assets', '/characters/appearanceRef');
    ref('rightsRecords', c['rightsId'], '/characters/rightsId');
  }
  for (final s in d['scripts']) {
    ref('briefs', s['briefId'], '/scripts/briefId');
    for (final id in s['sceneIds']) {
      ref('scenes', id, '/scripts/sceneIds');
      if (indexes['scenes']![id] != null &&
          indexes['scenes']![id]['scriptId'] != s['id']) {
        issue('PARENT_MISMATCH', '/scripts/sceneIds');
      }
    }
  }
  for (final s in d['scenes']) {
    ref('scripts', s['scriptId'], '/scenes/scriptId');
    for (final id in s['characterIds']) {
      ref('characters', id, '/scenes/characterIds');
    }
    for (final id in s['shotIds']) {
      ref('shots', id, '/scenes/shotIds');
      if (indexes['shots']![id] != null &&
          indexes['shots']![id]['sceneId'] != s['id']) {
        issue('PARENT_MISMATCH', '/scenes/shotIds');
      }
    }
  }
  final candidates = {
    for (final record in d['generationRecords'])
      for (final id in record['candidateIds']) id,
  };
  for (final c in clips.values) {
    if (c['candidateId'] != null && !candidates.contains(c['candidateId'])) {
      issue('REF_NOT_FOUND', '/clips/candidateId');
    }
  }
  for (final s in d['shots']) {
    ref('scenes', s['sceneId'], '/shots/sceneId', nullable: true);
    for (final x in s['subjectRefs']) {
      // EntityRef has no kind discriminator. Subjects may reference a local
      // character OR asset/image/other declared entity, not an invented enum.
      final tables = _entityTables
          .where((t) => indexes[t]!.containsKey(x['id']))
          .toList();
      if (tables.isEmpty) {
        issue('REF_NOT_FOUND', '/shots/subjectRefs');
      } else {
        entityRef(x, tables.first, '/shots/subjectRefs');
      }
    }
    for (final x in s['continuity']['characterRefs']) {
      entityRef(x, 'characters', '/shots/continuity');
    }
    for (final x in s['continuity']['propRefs']) {
      entityRef(x, 'assets', '/shots/continuity');
    }
    entityRef(s['firstFrameRef'], 'assets', '/shots/firstFrameRef');
    entityRef(s['lastFrameRef'], 'assets', '/shots/lastFrameRef');
    references(s['referenceRefs'] as List, '/shots/referenceRefs');
    if (s['selectedCandidateId'] != null &&
        !candidates.contains(s['selectedCandidateId'])) {
      issue('REF_NOT_FOUND', '/shots/selectedCandidateId');
    }
  }
  for (final g in d['generationRecords']) {
    for (final x in g['inputAssetRefs']) {
      entityRef(x, 'assets', '/generationRecords/inputAssetRefs');
    }
    for (final x in g['outputAssetRefs']) {
      entityRef(x, 'assets', '/generationRecords/outputAssetRefs');
    }
  }
}
