import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:studio_contracts/studio_contracts.dart';
import 'package:studio_document/studio_document.dart';

Map<String, dynamic> validateProxyResourceBytes(
  Map asset,
  Map proxy,
  List<int> mapBytes,
  List<int> raw,
) {
  if (mapBytes.length > 1024 * 1024 ||
      rawBytesHash(mapBytes) != proxy['ptsMapBlobHash']) {
    throw const StudioException('PROXY_MAP_HASH_MISMATCH');
  }
  final manifest = readStrictJson(mapBytes, maxBytes: 1024 * 1024);
  if (manifest is! Map<String, dynamic>) {
    throw const StudioException('PROXY_MAP_INVALID');
  }
  final facts = validatePreviewPtsMap(manifest, asset, proxy);
  if (rawBytesHash(raw) != proxy['blobHash'] || raw.length != facts['bytes']) {
    throw const StudioException('PROXY_BLOB_HASH_MISMATCH');
  }
  final n = proxy['width'] * proxy['height'] * 4 as int;
  final data = raw is Uint8List ? raw : Uint8List.fromList(raw);
  for (var i = 0; i < (manifest['frameHashes'] as List).length; i++) {
    if (sha256
            .convert(Uint8List.sublistView(data, i * n, (i + 1) * n))
            .toString() !=
        manifest['frameHashes'][i]) {
      throw const StudioException('PROXY_FRAME_HASH_MISMATCH');
    }
  }
  return facts;
}

Future<void> validateProxyResources(
  ProjectDocument project,
  Future<List<int>> Function(String hash) read,
) async {
  for (final asset in project.toJson()['assets']) {
    for (final proxy in asset['proxyRefs']) {
      validateProxyResourceBytes(
        asset,
        proxy,
        await read(proxy['ptsMapBlobHash']),
        await read(proxy['blobHash']),
      );
    }
  }
}
