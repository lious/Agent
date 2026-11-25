import 'package:studio_contracts/studio_contracts.dart';

import 'studio_document.dart';

/// Versioned derived-resource recipe; never a new field in the closed root.
final previewProxyPipelineHash = contentHash({
  'pipeline': 'rgba128-pts-v1',
  'mapProtocol': 'studio.preview-pts',
  'mapVersion': 1,
  'pixelFormat': 'rgba8888',
  'colorPolicy': 'rec709-sdr-preview-v1',
});
const previewProxyColorPolicy = 'rec709-sdr-preview-v1';

void validatePreviewProxyMetadata(Map asset, Map proxy, Map blobs) {
  final raw = blobs[proxy['blobHash']], map = blobs[proxy['ptsMapBlobHash']];
  final video = (asset['streams'] as List).where((v) => v['type'] == 'video');
  if (video.length != 1 ||
      proxy['pipelineHash'] != previewProxyPipelineHash ||
      proxy['colorPolicy'] != previewProxyColorPolicy ||
      proxy['sourceVersion'] != asset['version'] ||
      contentHash(proxy['frameRate']) !=
          contentHash(video.single['nominalFrameRate']) ||
      video.single['variableFrameRate'] != false ||
      raw == null ||
      map == null ||
      raw['role'] != 'proxy' ||
      map['role'] != 'ptsMap' ||
      raw['hash'] == map['hash'] ||
      raw['packagePath'] !=
          "proxies/${(raw['hash'] as String).substring(7)}.rgba" ||
      map['packagePath'] !=
          "proxies/${(map['hash'] as String).substring(7)}.pts.json" ||
      proxy['width'] < 2 ||
      proxy['width'] > 128 ||
      proxy['height'] < 2 ||
      proxy['height'] > 128 ||
      BigInt.parse(raw['bytes']) > BigInt.from(64 * 1024 * 1024) ||
      BigInt.parse(map['bytes']) > BigInt.from(1024 * 1024)) {
    throw const StudioException('PROXY_METADATA_INVALID');
  }
}

/// Structural + exact CFR source-time contract. Byte/hash validation is performed
/// by the CAS/archive reader, not inferred from JSON metadata admission.
Map<String, dynamic> validatePreviewPtsMap(
  Map<String, dynamic> value,
  Map asset,
  Map proxy,
) {
  if (value.keys.toSet().difference({
        'protocol',
        'version',
        'sourceHash',
        'pipelineHash',
        'rgbaHash',
        'facts',
        'frameHashes',
      }).isNotEmpty ||
      value.length != 7 ||
      value['protocol'] != 'studio.preview-pts' ||
      value['version'] != 1 ||
      value['sourceHash'] != asset['originalBlobHash'] ||
      value['rgbaHash'] != proxy['blobHash'] ||
      value['pipelineHash'] != previewProxyPipelineHash ||
      value['facts'] is! Map ||
      value['frameHashes'] is! List) {
    throw const StudioException('PROXY_MAP_INVALID');
  }
  final facts = Map<String, dynamic>.from(value['facts'] as Map),
      frames = facts['frames'],
      hashes = value['frameHashes'] as List;
  final stream = (asset['streams'] as List).singleWhere(
    (v) => v['type'] == 'video',
  );
  if (facts.length != 8 ||
      facts.keys.toSet().difference({
        'schema',
        'pipeline',
        'width',
        'height',
        'bytes',
        'startPts',
        'timeBase',
        'frames',
      }).isNotEmpty ||
      proxy['width'] is! int ||
      proxy['height'] is! int ||
      proxy['width'] < 2 ||
      proxy['width'] > 128 ||
      proxy['height'] < 2 ||
      proxy['height'] > 128) {
    throw const StudioException('PROXY_MAP_INVALID');
  }
  final rate = proxy['frameRate'];
  final fps = Q.of(rate['n'] as int, rate['d'] as int);
  final tb = Q.fromJson(facts['timeBase']);
  if (facts['schema'] != 1 ||
      facts['pipeline'] != 'rgba128-pts-v1' ||
      facts['width'] != proxy['width'] ||
      facts['height'] != proxy['height'] ||
      tb != Q.fromJson(stream['timeBase']) ||
      facts['startPts'] != stream['startPTS'] ||
      frames is! List ||
      frames.isEmpty ||
      frames.length > 2048 ||
      hashes.length != frames.length ||
      hashes.any(
        (h) => h is! String || !RegExp(r'^[a-f0-9]{64}$').hasMatch(h),
      ) ||
      facts['bytes'] != proxy['width'] * proxy['height'] * 4 * frames.length) {
    throw const StudioException('PROXY_MAP_INVALID');
  }
  BigInt integer(dynamic v) {
    if (v is! String || !RegExp(r'^(0|-?[1-9][0-9]{0,18})$').hasMatch(v)) {
      throw const StudioException('PROXY_MAP_INVALID');
    }
    final n = BigInt.parse(v);
    if (n < -(BigInt.one << 63) || n >= (BigInt.one << 63)) {
      throw const StudioException('PROXY_MAP_INVALID');
    }
    return n;
  }

  final origin = integer(facts['startPts']);
  for (var i = 0; i < frames.length; i++) {
    final f = frames[i];
    if (f is! Map ||
        f.length != 2 ||
        !f.containsKey('pts') ||
        !f.containsKey('duration')) {
      throw const StudioException('PROXY_MAP_INVALID');
    }
    final p = integer(f['pts']), duration = integer(f['duration']);
    if (Q(p - origin, BigInt.one) * tb != Q.of(i) / fps ||
        Q(duration, BigInt.one) * tb != Q.of(1) / fps ||
        p + duration >= (BigInt.one << 63)) {
      throw const StudioException('PROXY_MAP_INVALID');
    }
  }
  if (Q.of(frames.length) / fps != Q.fromJson(stream['duration'])) {
    throw const StudioException('PROXY_MAP_INVALID');
  }
  return facts;
}
