import 'package:studio_contracts/studio_contracts.dart';

import 'studio_document.dart';

/// Complete business admission for the explicitly supported single-video-track
/// local slice. Other valid project features remain preserved/readable, not writable.
void requireLocalEditingWritable(ProjectDocument project) {
  final d = project.toJson();
  for (final table in [
    'effects',
    'transitions',
    'captions',
    'markers',
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
    'modelRefs',
    'retainedSources',
    'requiredFeatures',
  ]) {
    if ((d[table] as List).isNotEmpty) {
      throw StudioException('FEATURE_NOT_IMPLEMENTED', table);
    }
  }
  if ((d['extensions'] as Map).isNotEmpty || d['defaultFontRef'] != null) {
    throw const StudioException('FEATURE_NOT_IMPLEMENTED');
  }
  final sequences = d['sequences'] as List, buses = d['audioBuses'] as List;
  if (sequences.length != 1 ||
      sequences.single['id'] != d['rootSequenceId'] ||
      buses.length != 1) {
    throw const StudioException('FEATURE_NOT_IMPLEMENTED');
  }
  final s = sequences.single, b = buses.single;
  if (s['masterBusId'] != b['id'] ||
      b['outputBusId'] != null ||
      (b['inputBusIds'] as List).isNotEmpty ||
      (b['effectIds'] as List).isNotEmpty ||
      b['gainDb'] != 0 ||
      b['pan'] != 0 ||
      b['muted'] != false ||
      b['solo'] != false ||
      (s['markerIds'] as List).isNotEmpty) {
    throw const StudioException('FEATURE_NOT_IMPLEMENTED');
  }
  final assets = {for (final a in d['assets'] as List) a['id']: a};
  final blobs = {for (final v in d['blobs'] as List) v['hash']: v};
  if (blobs.length != (d['blobs'] as List).length) {
    throw const StudioException('DUPLICATE_BLOB');
  }
  for (final blob in blobs.values) {
    if (blob['role'] != 'original' ||
        blob['packagePath'] !=
            'originals/${(blob['hash'] as String).substring(7)}' ||
        BigInt.parse(blob['bytes'] as String) <= BigInt.zero) {
      throw const StudioException('BLOB_METADATA_INVALID');
    }
  }
  final rights = {for (final v in d['rightsRecords'] as List) v['id']: v};
  for (final a in assets.values) {
    if (a['kind'] != 'video' ||
        a['status'] != 'ready' ||
        a['externalLocator'] != null ||
        (a['proxyRefs'] as List).isNotEmpty) {
      throw const StudioException('FEATURE_NOT_IMPLEMENTED');
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
  final tracks = s['tracks'] as List;
  if (tracks.length > 1) throw const StudioException('FEATURE_NOT_IMPLEMENTED');
  if (tracks.isEmpty) return;
  final track = tracks.single;
  if (track['kind'] != 'video' ||
      track['busId'] != null ||
      track['muted'] != false ||
      track['solo'] != false) {
    throw const StudioException('FEATURE_NOT_IMPLEMENTED');
  }
  for (final c in track['items']) {
    if (c['source'] == null) continue;
    if (c['source']['kind'] != 'asset' ||
        c['timeMap']['kind'] != 'linear' ||
        (c['effectIds'] as List).isNotEmpty ||
        c['linkGroupId'] != null ||
        c['selectionGroupId'] != null ||
        c['shotId'] != null ||
        c['candidateId'] != null ||
        c['provenanceId'] != null) {
      throw const StudioException('FEATURE_NOT_IMPLEMENTED');
    }
    final source = c['source'];
    final a = assets[source['id']];
    if (a == null) throw const StudioException('REF_NOT_FOUND');
    if (a['version'] != source['version']) {
      throw const StudioException('SOURCE_VERSION_MISSING');
    }
    final streams = (a['streams'] as List).where(
      (v) => v['id'] == source['streamId'] && v['type'] == 'video',
    );
    if (streams.length != 1) throw const StudioException('REF_NOT_FOUND');
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
    if (start + duration > Q.fromJson(streams.single['duration'])) {
      throw const StudioException('SOURCE_OUT_OF_RANGE');
    }
  }
}
