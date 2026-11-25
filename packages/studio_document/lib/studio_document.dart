export 'effect_registry.dart';
export 'definition_fingerprint.dart';
export 'resource_closure.dart';
export 'preview_proxy.dart';
export 'timeline_graph.dart';

import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:json_canonicalizer/json_canonicalizer.dart';
import 'package:studio_contracts/studio_contracts.dart';

import 'time.dart';
import 'validator.dart';
export 'time.dart';
export 'caption.dart';
export 'audio_bus.dart';
export 'validator.dart';
export 'strict_json.dart';
export 'edit_algebra.dart';
export 'local_admission.dart';

String contentHash(Object? value) =>
    'sha256:${sha256.convert(canonicalizeUtf8(value))}';

/// Validated immutable JSON value. Callers receive detached copies, never live state.
/// Validation is not full media/resource/capability admission (see ADR-0001).
final class ProjectDocument {
  ProjectDocument._(this._canonical);
  factory ProjectDocument.fromJson(Map<String, dynamic> value) {
    var count = 0;
    void bounded(dynamic x, int depth) {
      if (depth > 64 || ++count > 1000000) {
        throw const StudioException('DOCUMENT_LIMIT');
      }
      if (x is Map) {
        for (final v in x.values) {
          bounded(v, depth + 1);
        }
      }
      if (x is List) {
        for (final v in x) {
          bounded(v, depth + 1);
        }
      }
    }

    bounded(value, 0);
    final canonical = canonicalize(value);
    if (utf8.encode(canonical).length > 32 * 1024 * 1024) {
      throw const StudioException('DOCUMENT_LIMIT');
    }
    final copy = jsonDecode(canonical) as Map<String, dynamic>;
    final issues = DocumentValidator().validate(copy);
    if (issues.isNotEmpty) {
      throw StudioException(issues.first.code, issues.first.path);
    }
    return ProjectDocument._(canonical);
  }
  factory ProjectDocument.empty({
    required Namespace namespace,
    required String projectId,
    required String title,
  }) {
    requireId(projectId);
    final q0 = Q.of(0).toJson(), q1 = Q.of(1).toJson();
    return ProjectDocument.fromJson({
      'schemaVersion': '2.0.0',
      'minReaderVersion': '2.0.0',
      'projectId': projectId,
      'namespace': namespace.toJson(),
      'revision': '0',
      'title': title,
      'rootSequenceId': 'sequence-main',
      'sequences': [
        {
          'id': 'sequence-main',
          'name': 'Main',
          'version': '0',
          'canvas': {'width': 720, 'height': 1280, 'pixelAspect': q1},
          'frameRate': {'n': 30000, 'd': 1001},
          'sampleRate': 48000,
          'workingColor': 'linear-rec709',
          'outputColor': 'rec709',
          'backgroundRGBA': [0, 0, 0, 1],
          'duration': q0,
          'tracks': [],
          'markerIds': [],
          'masterBusId': 'bus-master',
        },
      ],
      'audioBuses': [
        {
          'id': 'bus-master',
          'name': 'Master',
          'inputBusIds': [],
          'gainDb': 0,
          'pan': 0,
          'effectIds': [],
          'muted': false,
          'solo': false,
          'outputBusId': null,
        },
      ],
      for (final name in [
        'assets',
        'blobs',
        'effects',
        'transitions',
        'captions',
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
        'modelRefs',
        'retainedSources',
      ])
        name: [],
      'defaultFontRef': null,
      'requiredFeatures': [],
      'extensions': {},
    });
  }
  final String _canonical;
  String get canonicalJson => _canonical;
  Map<String, dynamic> toJson() =>
      jsonDecode(_canonical) as Map<String, dynamic>;
  String get projectId => toJson()['projectId'] as String;
  String get title => toJson()['title'] as String;
  BigInt get revision => BigInt.parse(toJson()['revision'] as String);
  Namespace get namespace {
    final n = toJson()['namespace'];
    return Namespace(
      n['appId'] as String,
      n['tenantId'] as String,
      n['workspaceId'] as String,
    );
  }

  String get hash => contentHash(toJson());
  ProjectDocument withTitle(String title, BigInt revision) {
    if (revision.isNegative || revision > maxI64) {
      throw const StudioException('REVISION_OVERFLOW');
    }
    return ProjectDocument.fromJson(
      toJson()
        ..['title'] = title
        ..['revision'] = revision.toString(),
    );
  }

  /// Narrow write admission: only the empty project format produced by this release.
  /// This prevents incomplete media semantics from being mistaken for safe editing.
  void requireFoundationWritable() {
    final actual = toJson()..['revision'] = '0';
    final baseline = ProjectDocument.empty(
      namespace: namespace,
      projectId: projectId,
      title: title,
    ).toJson();
    if (canonicalize(actual) != canonicalize(baseline)) {
      throw const StudioException('FEATURE_NOT_IMPLEMENTED');
    }
  }
}

String rawBytesHash(List<int> bytes) => 'sha256:${sha256.convert(bytes)}';
