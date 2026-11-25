import 'dart:convert';

/// Stable machine-readable errors; UI copy must not be used for branching.
final class StudioException implements Exception {
  const StudioException(this.code, [this.path = '']);
  final String code;
  final String path;
  @override
  String toString() => '$code${path.isEmpty ? '' : ' at $path'}';
}

void requireId(String value) {
  if (!RegExp(r'^[A-Za-z0-9][A-Za-z0-9._:@-]{0,127}$').hasMatch(value)) {
    throw const StudioException('INVALID_ID');
  }
}

final class Namespace {
  Namespace(this.appId, this.tenantId, this.workspaceId) {
    for (final value in [appId, tenantId, workspaceId]) {
      requireId(value);
    }
  }
  final String appId, tenantId, workspaceId;

  /// Length-delimited JSON tuple: never path concatenation or delimiter joining.
  String get key => jsonEncode([appId, tenantId, workspaceId]);
  Map<String, Object?> toJson() => {
    'appId': appId,
    'tenantId': tenantId,
    'workspaceId': workspaceId,
  };
  @override
  bool operator ==(Object other) => other is Namespace && key == other.key;
  @override
  int get hashCode => key.hashCode;
}

final class AppProfile {
  AppProfile({
    required this.appId,
    required this.region,
    required Set<String> features,
    this.version = '0.1.0',
  }) : features = Set.unmodifiable(features) {
    requireId(appId);
  }
  final String appId, region, version;
  final Set<String> features;
  Namespace namespace(String tenantId, String workspaceId) =>
      Namespace(appId, tenantId, workspaceId);
}
