import 'package:studio_contracts/studio_contracts.dart';

import 'studio_document.dart';

/// Complete business admission for the explicitly supported single-video-track
/// local slice. Other valid project features remain preserved/readable, not writable.
void requireLocalEditingWritable(ProjectDocument project) {
  final d = project.toJson();
  requireDissolveProfile(d);
  for (final table in [
    'imageDocuments',
    'briefs',
    'scripts',
    'scenes',
    'characters',
    'shots',
    'generationRecords',
    'fontRefs',
    'modelRefs',
    'retainedSources',
  ]) {
    if ((d[table] as List).isNotEmpty) {
      throw StudioException('FEATURE_NOT_IMPLEMENTED', table);
    }
  }
  requireAdmittedRequiredFeatures(d);
  if ((d['extensions'] as Map).isNotEmpty || d['defaultFontRef'] != null) {
    throw const StudioException('FEATURE_NOT_IMPLEMENTED');
  }
  final sequences = d['sequences'] as List, buses = d['audioBuses'] as List;
  if (sequences.isEmpty ||
      sequences[0]['id'] != d['rootSequenceId'] ||
      buses.isEmpty) {
    throw const StudioException('FEATURE_NOT_IMPLEMENTED');
  }
  final s = sequences[0];
  for (final raw in buses) {
    if ((raw['effectIds'] as List).isNotEmpty) {
      throw const StudioException('AUDIO_EFFECT_NOT_IMPLEMENTED');
    }
  }
  // Official writable slice now admits a bounded bus DAG. Cycles, mismatches
  // and an invalid master refuse the whole graph rather than a partial route.
  final graph = AudioBusGraph([
    for (final raw in buses)
      AudioBus.fromJson(Map<String, dynamic>.from(raw as Map)),
  ], s['masterBusId'] as String);
  requireWritableMarkers(d);
  final consumed = <String>{
    for (final seq in sequences)
      for (final t in seq['tracks'])
        for (final c in t['items'])
          if (c['source'] != null)
            for (final id in c['effectIds'] as List) id as String,
  };
  if ((d['effects'] as List).any(
    (e) =>
        !consumed.contains(e['id']) && !isAdmittedSequenceLumaWipe(d, e as Map),
  )) {
    throw const StudioException('UNSUPPORTED_EDIT_TECHNIQUE');
  }
  requireLumaWipeProfile(d);
  final assets = {for (final a in d['assets'] as List) a['id']: a};
  final blobs = {for (final v in d['blobs'] as List) v['hash']: v};
  if (blobs.length != (d['blobs'] as List).length) {
    throw const StudioException('DUPLICATE_BLOB');
  }
  for (final blob in blobs.values) {
    if (!{'original', 'proxy', 'ptsMap'}.contains(blob['role']) ||
        (blob['role'] == 'original' &&
            blob['packagePath'] !=
                'originals/${(blob['hash'] as String).substring(7)}') ||
        BigInt.parse(blob['bytes'] as String) <= BigInt.zero) {
      throw const StudioException('BLOB_METADATA_INVALID');
    }
  }
  if (blobs.values
          .where((b) => b['role'] == 'proxy')
          .fold<BigInt>(BigInt.zero, (n, b) => n + BigInt.parse(b['bytes'])) >
      BigInt.from(64 * 1024 * 1024)) {
    throw const StudioException('PROXY_CACHE_QUOTA');
  }
  final rights = {for (final v in d['rightsRecords'] as List) v['id']: v};
  for (final a in assets.values) {
    if (a['kind'] != 'video' ||
        a['status'] != 'ready' ||
        a['externalLocator'] != null) {
      throw const StudioException('FEATURE_NOT_IMPLEMENTED');
    }
    if ((a['proxyRefs'] as List).length > 1) {
      throw const StudioException('PROXY_METADATA_INVALID');
    }
    for (final p in a['proxyRefs']) {
      validatePreviewProxyMetadata(a, p, blobs);
    }
    if (blobs[a['originalBlobHash']]?['role'] != 'original') {
      throw const StudioException('PROXY_METADATA_INVALID');
    }
    if (!rights.containsKey(a['rightsId']) ||
        !blobs.containsKey(a['originalBlobHash'])) {
      throw const StudioException('REF_NOT_FOUND');
    }
    if (!(rights[a['rightsId']]['assetIds'] as List).contains(a['id'])) {
      throw const StudioException('RIGHTS_REFERENCE_MISMATCH');
    }
    if (a['originalBlobHash'] != a['contentFingerprint']) {
      throw const StudioException('ASSET_FINGERPRINT_MISMATCH');
    }
    final streams = a['streams'] as List;
    if (!streams.any((v) => v['type'] == 'video')) {
      throw const StudioException('VIDEO_STREAM_REQUIRED');
    }
    for (final st in streams) {
      if (Q.fromJson(st['timeBase']) <= Q.of(0) ||
          Q.fromJson(st['duration']) <= Q.of(0)) {
        throw const StudioException('INVALID_RANGE');
      }
    }
  }
  final usedDerived = <String>{
    for (final a in assets.values)
      for (final p in a['proxyRefs']) ...[
        p['blobHash'] as String,
        p['ptsMapBlobHash'] as String,
      ],
  };
  for (final b in blobs.values) {
    if (b['role'] != 'original' && !usedDerived.contains(b['hash'])) {
      throw const StudioException('PROXY_RESOURCE_UNREFERENCED');
    }
  }
  final tracks = [
    for (final seq in sequences) ...seq['tracks'] as List,
  ];
  for (final seq in sequences) {
    final seqTracks = seq['tracks'] as List;
    final video = seqTracks.where((t) => t['kind'] == 'video').toList(),
        captionTracks = seqTracks.where((t) => t['kind'] == 'caption').toList(),
        audioTracks = seqTracks.where((t) => t['kind'] == 'audio').toList();
    if (video.length > 1 ||
        captionTracks.length > 1 ||
        audioTracks.length > 1 ||
        video.length + captionTracks.length + audioTracks.length !=
            seqTracks.length ||
        (video.isNotEmpty && seqTracks[0]['kind'] != 'video')) {
      throw const StudioException('FEATURE_NOT_IMPLEMENTED');
    }
  }
  final video = tracks.where((t) => t['kind'] == 'video').toList(),
      captionTracks = [
        for (final t in s['tracks'] as List)
          if (t['kind'] == 'caption') t,
      ],
      audioTracks = tracks.where((t) => t['kind'] == 'audio').toList();
  for (final t in tracks) {
    if (t['kind'] == 'audio') {
      final busId = t['busId'] as String?;
      if (busId == null || !graph.buses.containsKey(busId)) {
        throw const StudioException('AUDIO_BUS_MISSING');
      }
      if (!graph.pathToMaster(busId).contains(graph.masterId)) {
        throw const StudioException('AUDIO_BUS_UNROUTED');
      }
    } else if (t['busId'] != null ||
        t['muted'] != false ||
        t['solo'] != false) {
      throw const StudioException('FEATURE_NOT_IMPLEMENTED');
    }
  }
  final cues = <CaptionCue>[];
  for (final c in d['captions'] as List) {
    if (captionTracks.isEmpty || c['trackId'] != captionTracks.single['id']) {
      throw const StudioException('CAPTION_TRACK_MISMATCH');
    }
    if ((c['manualFields'] as List).toSet().length !=
        (c['manualFields'] as List).length) {
      throw const StudioException('CAPTION_MANUAL_FIELDS_INVALID');
    }
    cues.add(CaptionCue.fromProjectJson(c as Map<String, dynamic>));
  }
  CaptionStore(cues);
  requireSelectionGroupProfile(d);
  for (final group in d['linkGroups']) {
    if ((group['syncPolicy'] != 'preserve' &&
            group['syncPolicy'] != 'allowOutOfSync') ||
        (group['members'] as List).length != 2) {
      throw const StudioException('LINK_MODE_NOT_IMPLEMENTED');
    }
    final kinds = <String>[];
    for (final member in group['members']) {
      final ts = tracks.where(
        (t) => (t['items'] as List).any((c) => c['id'] == member['clipId']),
      );
      if (ts.length != 1) {
        throw const StudioException('LINK_MEMBERSHIP_MISMATCH');
      }
      kinds.add(ts.single['kind'] as String);
    }
    if (!kinds.contains('video') || !kinds.contains('audio')) {
      throw const StudioException('LINK_MODE_NOT_IMPLEMENTED');
    }
  }
  for (final track in [...video, ...audioTracks]) {
    for (final c in track['items']) {
      if (c['source'] == null) continue;
      final source = c['source'];
      if ((source['kind'] != 'asset' && source['kind'] != 'sequence') ||
          c['timeMap']['kind'] != 'linear' ||
          c['shotId'] != null ||
          c['candidateId'] != null ||
          c['provenanceId'] != null) {
        throw const StudioException('FEATURE_NOT_IMPLEMENTED');
      }
      if (track['kind'] == 'audio') {
        admittedAudioClipEffects(d, c as Map);
      } else {
        clipOpacityQ16(d, c as Map);
      }
      final rate = Q.fromJson(c['timeMap']['rate']);
      final tr = c['timelineRange'], sr = c['sourceRange'];
      final start = Q.fromJson(sr['start']),
          duration = Q.fromJson(sr['duration']);
      if (rate <= Q.of(0) ||
          start < Q.of(0) ||
          duration <= Q.of(0) ||
          rate * Q.fromJson(tr['duration']) != duration) {
        throw const StudioException('TIME_MAP_MISMATCH');
      }
      if (source['kind'] == 'sequence') {
        if (source['streamId'] != null) {
          throw const StudioException('SOURCE_STREAM_MISMATCH');
        }
        final child = [
          for (final seq in sequences)
            if (seq['id'] == source['id']) seq,
        ];
        if (child.length != 1) throw const StudioException('REF_NOT_FOUND');
        if (child.single['version'] != source['version']) {
          throw const StudioException('SOURCE_VERSION_MISSING');
        }
        if (start + duration > Q.fromJson(child.single['duration'])) {
          throw const StudioException('SOURCE_OUT_OF_RANGE');
        }
        continue;
      }
      final a = assets[source['id']];
      if (a == null) throw const StudioException('REF_NOT_FOUND');
      if (a['version'] != source['version']) {
        throw const StudioException('SOURCE_VERSION_MISSING');
      }
      final streams = (a['streams'] as List).where(
        (v) => v['id'] == source['streamId'] && v['type'] == track['kind'],
      );
      if (streams.length != 1) throw const StudioException('REF_NOT_FOUND');
      if (start + duration > Q.fromJson(streams.single['duration'])) {
        throw const StudioException('SOURCE_OUT_OF_RANGE');
      }
    }
  }
}

/// Narrow executable transition profile. Schema/semantic validation still owns
/// adjacency, handle sufficiency and nonoverlapping windows (including imports).
void requireDissolveProfile(Map<String, dynamic> d) {
  final seq = d['sequences'][0];
  final fps = FrameRate(seq['frameRate']['n'], seq['frameRate']['d']);
  final tracks = {for (final t in seq['tracks']) t['id']: t};
  final clips = {
    for (final t in seq['tracks'])
      for (final c in t['items']) c['id']: c,
  };
  final pairs = <String>{};
  for (final t in d['transitions']) {
    if (!pairs.add('${t['leftClipId']}:${t['rightClipId']}')) {
      throw const StudioException('TRANSITION_PROFILE_UNSUPPORTED');
    }
    if (t['kind'] != 'dissolve' ||
        t['curve'] != 'linear' ||
        t['missingHandlePolicy'] != 'reject') {
      throw const StudioException('TRANSITION_PROFILE_UNSUPPORTED');
    }
    final track = tracks[t['trackId']];
    if (track == null || track['kind'] != 'video' || track['muted'] == true) {
      throw const StudioException('TRANSITION_PROFILE_UNSUPPORTED');
    }
    for (final c in [clips[t['leftClipId']], clips[t['rightClipId']]]) {
      if (c == null ||
          c['source'] == null ||
          c['source']['kind'] != 'asset' ||
          c['enabled'] != true ||
          c['timeMap']['kind'] != 'linear' ||
          Q.fromJson(c['timeMap']['rate']) != Q.of(1)) {
        throw const StudioException('TRANSITION_PROFILE_UNSUPPORTED');
      }
    }
    for (final k in ['cut', 'before', 'after']) {
      final q = Q.fromJson(t[k]);
      if (fps.quantize(q, Rounding.tiesToEven) != q) {
        throw const StudioException('TRANSITION_NOT_ON_FRAME');
      }
    }
  }
}

/// Admitted selection groups only affect selection/move/copy closure. They are
/// not AV links and must remain bidirectionally consistent.
void requireSelectionGroupProfile(Map<String, dynamic> d) {
  final clips = {
    for (final seq in d['sequences'] as List)
      for (final t in seq['tracks'] as List)
      for (final c in t['items'])
        if (c['source'] != null) c['id']: c,
  };
  final seen = <String>{};
  for (final g in d['selectionGroups']) {
    final members = List<String>.from(g['memberClipIds'] as List);
    if (members.isEmpty || members.toSet().length != members.length) {
      throw const StudioException('GROUP_MEMBERSHIP_MISMATCH');
    }
    for (final id in members) {
      if (!seen.add(id)) {
        throw const StudioException('GROUP_MEMBERSHIP_MISMATCH');
      }
      final c = clips[id];
      if (c == null || c['selectionGroupId'] != g['id']) {
        throw const StudioException('GROUP_MEMBERSHIP_MISMATCH');
      }
    }
  }
  for (final c in clips.values) {
    final group = c['selectionGroupId'];
    if (group != null &&
        !(d['selectionGroups'] as List).any(
          (g) =>
              g['id'] == group &&
              (g['memberClipIds'] as List).contains(c['id']),
        )) {
      throw const StudioException('GROUP_MEMBERSHIP_MISMATCH');
    }
  }
}
