import 'dart:typed_data';

import 'studio_document.dart';

import 'package:studio_contracts/studio_contracts.dart';

/// Definition identity, NOT pixel/audio equivalence or execution qualification.
/// Typed current/frozen media sources and actual core rendering dependencies only.
final class DefinitionFingerprinter {
  DefinitionFingerprinter(this.project, this.bytes);
  final ProjectDocument project;
  final Map<String, Uint8List> bytes;
  final _cache = <String, String>{}, _versions = <String, String>{};
  final _active = <String>{};
  final _resolved = <String, Map<String, String>>{};

  /// Read-only projection of already resolved versioned nodes, not a registry
  /// or render certificate. Used by the existing immutable history contract.
  List<Map<String, String>> get resolvedDefinitions => List.unmodifiable(
    _resolved.values.map((v) => Map<String, String>.unmodifiable(v)),
  );
  final _snapshots = <String, ProjectDocument>{};
  final _documents = Map<ProjectDocument, Map<String, dynamic>>.identity();
  final _hashes = Map<ProjectDocument, String>.identity();
  final _qualifiedContexts = Set<ProjectDocument>.identity();
  final _indexes =
      Map<
        ProjectDocument,
        Map<String, Map<String, Map<String, dynamic>>>
      >.identity();
  Map<String, dynamic> _document(ProjectDocument p) =>
      _documents.putIfAbsent(p, p.toJson);
  String _scope(ProjectDocument p) => _hashes.putIfAbsent(p, () => p.hash);
  Map<String, Map<String, dynamic>> _index(ProjectDocument p, String table) =>
      _indexes
          .putIfAbsent(p, () => {})
          .putIfAbsent(
            table,
            () => {
              for (final entity in _document(p)[table])
                entity['id'] as String: Map<String, dynamic>.from(entity),
            },
          );
  void _requireProfile(ProjectDocument p) {
    if (_qualifiedContexts.contains(p)) return;
    final d = _document(p);
    if ((d['extensions'] as Map).isNotEmpty ||
        (d['requiredFeatures'] as List).isNotEmpty) {
      throw const StudioException('UNRESOLVED_EXTENSION_CLOSURE');
    }
    // Track/sequence effect ordering has no qualified core consumer here.
    // Do not silently omit their owner-only forward dependencies or invent order.
    if ((d['transitions'] as List).isNotEmpty) requireDissolveProfile(d);
    if ((d['effects'] as List).any(
      (e) => e['owner']['kind'] == 'track' || e['owner']['kind'] == 'sequence',
    )) {
      throw const StudioException('DEFINITION_PROFILE_UNQUALIFIED');
    }
    _qualifiedContexts.add(p);
  }

  int _nodes = 0;
  static const profile = 'studio-core-definition-v1';

  void registerSnapshot(ProjectDocument context) {
    for (final entry in {
      'asset': 'assets',
      'sequence': 'sequences',
      'imageDocument': 'imageDocuments',
    }.entries) {
      for (final entity in _document(context)[entry.value]) {
        sourceIn(context, entry.key, entity['id'], entity['version']);
      }
    }
  }

  String source(String kind, String id, String version) =>
      _source(project, kind, id, version, 0, 0);

  String sourceIn(
    ProjectDocument context,
    String kind,
    String id,
    String version,
  ) {
    final a = _document(context), b = _document(project);
    if (contentHash(a['namespace']) != contentHash(b['namespace']) ||
        a['projectId'] != b['projectId']) {
      throw const StudioException('RETAINED_ORIGIN_MISMATCH');
    }
    return _source(context, kind, id, version, 0, 0);
  }

  String _source(
    ProjectDocument context,
    String kind,
    String id,
    String version,
    int nesting,
    int depth,
  ) {
    if (nesting > 8) throw const StudioException('REF_DEPTH_LIMIT');
    final table = {
      'asset': 'assets',
      'sequence': 'sequences',
      'imageDocument': 'imageDocuments',
    }[kind];
    if (table == null) {
      throw const StudioException('DEFINITION_PROFILE_UNQUALIFIED');
    }
    final d = _document(context), value = _index(context, table)[id];
    if (value != null && value['version'] == version) {
      return _node(context, kind, value, nesting, depth);
    }
    final refs = (d['retainedSources'] as List).where(
      (r) => r['kind'] == kind && r['id'] == id && r['version'] == version,
    );
    if (refs.length != 1) throw const StudioException('SOURCE_VERSION_MISSING');
    final ref = refs.single, hash = ref['definitionBlobHash'] as String;
    final data = bytes[hash];
    if (data == null) throw const StudioException('RESOURCE_BYTES_MISSING');
    if (data.length > 1024 * 1024) {
      throw const StudioException('RETAINED_CLOSURE_LIMIT');
    }
    if (rawBytesHash(data) != hash) {
      throw const StudioException('BLOB_HASH_MISMATCH');
    }
    final snapshot = _snapshots.putIfAbsent(hash, () {
      final value = readStrictJson(data, maxBytes: 1024 * 1024);
      if (value is! Map<String, dynamic>) {
        throw const StudioException('RETAINED_SNAPSHOT_INVALID');
      }
      final p = ProjectDocument.fromJson(value);
      if (p.namespace != project.namespace ||
          p.projectId != project.projectId) {
        throw const StudioException('RETAINED_ORIGIN_MISMATCH');
      }
      return p;
    });
    // A retained snapshot must itself contain the exact target, not another alias.
    if (!(_document(snapshot)[table] as List).any(
      (v) => v['id'] == id && v['version'] == version,
    )) {
      throw const StudioException('SOURCE_VERSION_MISSING');
    }
    return _source(snapshot, kind, id, version, nesting, depth + 1);
  }

  String _node(
    ProjectDocument context,
    String kind,
    Map<String, dynamic> entity,
    int nesting,
    int depth,
  ) {
    if (depth > 96 || ++_nodes > 8192) {
      throw const StudioException('DEFINITION_GRAPH_LIMIT');
    }
    final identity =
        '$kind:${entity['id']}@${entity['version'] ?? 'unversioned'}';
    final scoped = '${_scope(context)}/$identity';
    if (_cache.containsKey(scoped)) return _cache[scoped]!;
    if (!_active.add(scoped)) throw const StudioException('REF_CYCLE');
    try {
      final d = _document(context), body = Map<String, dynamic>.from(entity);
      _requireProfile(context);
      final deps = <String, String>{};
      void add(String label, String hash) {
        deps[label] = hash;
      }

      Map<String, dynamic> find(String table, dynamic id) {
        final value = _index(context, table)[id];
        if (value == null) throw const StudioException('REF_NOT_FOUND');
        return value;
      }

      void blob(dynamic hash) {
        if (hash == null) throw const StudioException('RESOURCE_BYTES_MISSING');
        final rows = (d['blobs'] as List).where((v) => v['hash'] == hash);
        if (rows.length != 1) {
          throw const StudioException('MISSING_RESOURCE_DECLARATION');
        }
        final b = rows.single;
        add(
          'blob:$hash',
          contentHash({'hash': hash, 'bytes': b['bytes'], 'role': b['role']}),
        );
      }

      void child(String childKind, Map<String, dynamic> value) => add(
        '$childKind:${value['id']}',
        _node(context, childKind, value, nesting, depth + 1),
      );
      void effect(dynamic id) => child('effect', find('effects', id));
      void font(dynamic id) {
        if (id == null) {
          add('missingFont', contentHash({'missing': true}));
          return;
        }
        final f = find('fontRefs', id);
        blob(f['hash']);
        add('font:$id', contentHash(f));
      }

      void media(dynamic ref) {
        if (ref != null) {
          add(
            'source:${ref['kind']}:${ref['id']}@${ref['version']}',
            _source(
              context,
              ref['kind'],
              ref['id'],
              ref['version'],
              nesting + 1,
              depth + 1,
            ),
          );
        }
      }

      switch (kind) {
        case 'asset':
          blob(body['originalBlobHash']);
        case 'clip':
          body.remove('trackId');
          media(body['source']);
          for (final id in body['effectIds']) {
            effect(id);
          }
        case 'effect':
          const known = {
            'transform2d',
            'crop',
            'opacity',
            'colorBasic',
            'mask',
            'gain',
            'pan',
            'limiter',
            'textStyle',
          };
          if (!known.contains(body['type']) ||
              (body['extensions'] as Map).isNotEmpty) {
            throw const StudioException('UNRESOLVED_EXTENSION_CLOSURE');
          }
          body.remove('owner'); // reverse owner reference, never a render edge
          if (body['type'] == 'mask') blob(body['parameters']['blobHash']);
          if (body['type'] == 'textStyle') font(body['parameters']['fontRef']);
        case 'transitions':
          // Window/leg topology belongs to this node; the containing sequence
          // already closes BOTH clip definitions, including source/effects.
          // Reverse owner IDs are not independently executable sources.
          body.remove('sequenceId');
          body.remove('trackId');
        case 'caption':
          body.remove('trackId');
          if (body['styleEffectId'] != null) {
            effect(body['styleEffectId']);
          } else {
            font(d['defaultFontRef']);
          }
        case 'bus':
          body.remove('outputBusId'); // reverse route; inputBusIds are forward
          for (final id in body['inputBusIds']) {
            child('bus', find('audioBuses', id));
          }
          for (final id in body['effectIds']) {
            effect(id);
          }
        case 'sequence':
          final tracks = <Map<String, dynamic>>[];
          final trackIds = <String>{};
          for (final t in body['tracks']) {
            final track = Map<String, dynamic>.from(t)..remove('sequenceId');
            trackIds.add(track['id']);
            final items = <Map<String, dynamic>>[];
            for (final c in track['items']) {
              final clip = Map<String, dynamic>.from(c)..remove('trackId');
              if (clip['source'] != null) child('clip', clip);
              items.add(clip);
            }
            track['items'] = items;
            tracks.add(track);
            if (track['busId'] != null) {
              child('bus', find('audioBuses', track['busId']));
            }
          }
          body['tracks'] = tracks;
          for (final t in d['transitions']) {
            if (t['sequenceId'] == body['id']) {
              child('transitions', Map<String, dynamic>.from(t));
            }
          }
          child('bus', find('audioBuses', body['masterBusId']));
          // mix48k's actual recipe/solo set includes every declared bus.
          for (final bus in d['audioBuses']) {
            child('bus', Map<String, dynamic>.from(bus));
          }
          for (final cue in d['captions']) {
            if (trackIds.contains(cue['trackId'])) {
              child('caption', Map<String, dynamic>.from(cue));
            }
          }
        case 'imageDocument':
          final layers = <Map<String, dynamic>>[],
              tree = <Map<String, dynamic>>[];
          final children = <String, List<String>>{};
          for (final l in body['layers']) {
            final parent = l['parentId'];
            if (parent != null) {
              children.putIfAbsent(parent, () => []).add(l['id']);
            }
          }
          for (final layer in body['layers']) {
            final l = Map<String, dynamic>.from(layer)..remove('parentId');
            media(l['sourceRef']);
            if (l['kind'] == 'text') font(d['defaultFontRef']);
            if (l['maskRef'] != null) blob(l['maskRef']);
            for (final id in l['effectIds']) {
              effect(id);
            }
            layers.add(l);
            tree.add({
              'id': l['id'],
              'children': children[l['id']] ?? <String>[],
            });
          }
          body['layers'] = layers;
          body['forwardLayerTree'] = tree;
          for (final id in body['fontRefs']) {
            font(id);
          }
        default:
          throw const StudioException('DEFINITION_PROFILE_UNQUALIFIED');
      }
      final keys = deps.keys.toList()..sort();
      final hash = contentHash({
        'profile': profile,
        'kind': kind,
        'definition': body,
        'dependencies': [
          for (final k in keys) {'ref': k, 'hash': deps[k]},
        ],
      });
      if (entity['version'] != null) {
        if (_versions.containsKey(identity) && _versions[identity] != hash) {
          throw const StudioException('IMMUTABLE_VERSION_CONFLICT');
        }
        _versions[identity] = hash;
        _resolved[identity] = {
          'kind': kind,
          'id': entity['id'],
          'version': entity['version'],
          'hash': hash,
        };
      }
      _cache[scoped] = hash;
      return hash;
    } finally {
      _active.remove(scoped);
    }
  }
}

/// Current-head guard only. Does not reinterpret historical SQL hash rows.
void verifyDefinitionTransition(ProjectDocument before, ProjectDocument after) {
  if (before.namespace != after.namespace ||
      before.projectId != after.projectId) {
    throw const StudioException('DOCUMENT_IDENTITY_MISMATCH');
  }
  final a = DefinitionFingerprinter(before, const {}),
      b = DefinitionFingerprinter(after, const {});
  final previous = {for (final s in before.toJson()['sequences']) s['id']: s};
  for (final s in after.toJson()['sequences']) {
    final old = previous[s['id']];
    if (old != null &&
        old['version'] == s['version'] &&
        a.source('sequence', old['id'], old['version']) !=
            b.source('sequence', s['id'], s['version'])) {
      throw const StudioException('IMMUTABLE_VERSION_CONFLICT');
    }
  }
}
