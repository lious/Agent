import 'dart:convert';

import 'package:studio_contracts/studio_contracts.dart';

/// DEV-PURE V-026 untrusted glTF admission. This is not a glTF runtime,
/// not a preview-consistency qualification, and not I-061 Preview3DPort.
final class AdmissionReport {
  AdmissionReport({
    required this.admitted,
    required this.networkRequestCount,
    required this.unknownNodesRetained,
    required this.unsupportedExtensions,
    this.refusalCode,
  });

  final bool admitted;
  final int networkRequestCount;
  final List<String> unknownNodesRetained;
  final List<String> unsupportedExtensions;
  final String? refusalCode;

  bool get autoFetchExternalUrl => false;
  bool get runtimeInvented => false;
  bool get previewConsistencyClaimed => false;
  bool get previewed => false;
  bool get v026GltfPreviewClaimed => false;
  bool get i061Started => false;
  bool get nerfOpened => false;
}

final class UntrustedGltfAdmission {
  static const allowedExtensions = <String>{};

  int documentWrites = 0;
  bool runtimeInvented = false;
  bool previewConsistencyClaimed = false;
  bool v026GltfPreviewClaimed = false;
  bool i061Started = false;
  bool paidApiCalled = false;

  /// Admit or refuse a synthetic glTF JSON document. External URIs are
  /// never fetched. Unsupported extensions are refused, not dropped.
  AdmissionReport admit(Object input) {
    documentWrites = 0;
    try {
      return _admit(input);
    } on StudioException catch (error) {
      return AdmissionReport(
        admitted: false,
        networkRequestCount: 0,
        unknownNodesRetained: const [],
        unsupportedExtensions: const [],
        refusalCode: error.code,
      );
    } on Object {
      return AdmissionReport(
        admitted: false,
        networkRequestCount: 0,
        unknownNodesRetained: const [],
        unsupportedExtensions: const [],
        refusalCode: 'DAMAGED_INPUT',
      );
    }
  }

  AdmissionReport _admit(Object input) {
    final decoded = _decode(input);
    if (decoded is! Map) {
      throw const StudioException('DAMAGED_INPUT', 'gltf');
    }
    final document = Map<Object?, Object?>.from(decoded);

    final uris = _collectUris(document);
    for (final uri in uris) {
      if (_isExternalUrl(uri) || _isPathTraversal(uri)) {
        throw const StudioException('EXTERNAL_URL_FORBIDDEN', 'gltfUri');
      }
    }

    final extensions = {
      ..._stringList(document['extensionsUsed']),
      ..._stringList(document['extensionsRequired']),
    };
    final unsupported = extensions
        .where((name) => !allowedExtensions.contains(name))
        .toList();
    if (unsupported.isNotEmpty) {
      throw StudioException('EXTENSION_UNSUPPORTED', unsupported.join(','));
    }

    if (!_structurallySound(document)) {
      throw const StudioException('DAMAGED_INPUT', 'gltf');
    }

    final unknown = _unknownNodes(document);
    return AdmissionReport(
      admitted: true,
      networkRequestCount: 0,
      unknownNodesRetained: unknown,
      unsupportedExtensions: const [],
    );
  }

  Object? _decode(Object input) {
    if (input is Map) {
      return input;
    }
    if (input is String) {
      return jsonDecode(input);
    }
    if (input is List<int>) {
      return jsonDecode(utf8.decode(input, allowMalformed: false));
    }
    throw const StudioException('DAMAGED_INPUT', 'gltf');
  }

  List<String> _collectUris(Map<Object?, Object?> document) {
    final uris = <String>[];
    void walk(Object? node) {
      if (node is Map) {
        final uri = node['uri'];
        if (uri is String) {
          uris.add(uri);
        }
        for (final value in node.values) {
          walk(value);
        }
      } else if (node is List) {
        for (final value in node) {
          walk(value);
        }
      }
    }

    walk(document);
    return uris;
  }

  bool _isExternalUrl(String uri) {
    final trimmed = uri.trim();
    final lower = trimmed.toLowerCase();
    if (lower.startsWith('data:')) return false;
    if (lower.startsWith('//')) return true;
    final parsed = Uri.tryParse(trimmed);
    return parsed != null &&
        parsed.hasScheme &&
        parsed.scheme.toLowerCase() != 'data';
  }

  bool _isPathTraversal(String uri) {
    final normalized = uri.replaceAll(r'\', '/');
    return normalized.contains('../') ||
        normalized.contains('..\\') ||
        normalized == '..' ||
        normalized.startsWith('/');
  }

  List<String> _stringList(Object? value) {
    if (value == null) return const [];
    if (value is! List) {
      throw const StudioException('DAMAGED_INPUT', 'extensions');
    }
    return [
      for (final item in value)
        if (item is String)
          item
        else
          throw const StudioException('DAMAGED_INPUT', 'extensions'),
    ];
  }

  bool _structurallySound(Map<Object?, Object?> document) {
    final asset = document['asset'];
    if (asset is! Map || asset['version'] is! String) return false;
    for (final key in [
      'buffers',
      'bufferViews',
      'accessors',
      'images',
      'meshes',
      'nodes',
    ]) {
      final value = document[key];
      if (!document.containsKey(key)) {
        continue;
      }
      if (value is! List) return false;
      for (final item in value) {
        if (item is! Map) return false;
        final count = item['count'];
        if (count is int && count < 0) return false;
        final byteLength = item['byteLength'];
        if (byteLength is int && byteLength < 0) return false;
        if (byteLength is int && byteLength > 10 * 1024 * 1024) return false;
      }
    }
    return true;
  }

  List<String> _unknownNodes(Map<Object?, Object?> document) {
    const known = {
      'asset',
      'buffers',
      'bufferViews',
      'accessors',
      'images',
      'meshes',
      'nodes',
      'scenes',
      'scene',
      'materials',
      'textures',
      'samplers',
      'cameras',
      'skins',
      'animations',
      'extensionsUsed',
      'extensionsRequired',
      'extensions',
      'extras',
    };
    return [
      for (final key in document.keys)
        if (key is String && !known.contains(key)) key,
    ];
  }
}

/// A tiny local-only core glTF 2.0 document. This is a synthetic
/// admission fixture, not a preview-consistency sample.
const localCoreGltf = '''
{"asset":{"version":"2.0"},"buffers":[{"byteLength":4,"uri":"data:application/octet-stream;base64,AAAAAA=="}]}
''';
