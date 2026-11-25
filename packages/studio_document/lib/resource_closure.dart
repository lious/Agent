import 'package:studio_contracts/studio_contracts.dart';

import 'studio_document.dart';

/// Registered core references only. Hash-looking text in opaque data is NOT an
/// edge. This reports metadata closure, never decoder/font/plugin qualification.
Map<String, dynamic> projectResourceClosure(ProjectDocument project) {
  final d = project.toJson(),
      blobs = {for (final b in project.toJson()['blobs']) b['hash']: b};
  final uses = <String, List<Map<String, dynamic>>>{};
  final issues = <Map<String, dynamic>>[];
  void edge(dynamic hash, String path, Set<String>? roles) {
    if (hash == null) return;
    uses.putIfAbsent(hash as String, () => []).add({
      'path': path,
      'expectedRoles': roles?.toList(),
    });
    if (!blobs.containsKey(hash)) {
      issues.add({
        'code': 'MISSING_RESOURCE_DECLARATION',
        'path': path,
        'hash': hash,
      });
    } else if (roles != null && !roles.contains(blobs[hash]['role'])) {
      issues.add({
        'code': 'RESOURCE_ROLE_MISMATCH',
        'path': path,
        'hash': hash,
      });
    }
  }

  if ((d['extensions'] as Map).isNotEmpty) {
    issues.add({
      'code': 'UNRESOLVED_EXTENSION_CLOSURE',
      'path': '/extensions',
      'detail': 'Includes unknown library/LUT/provider data; preserved opaque, no registered walker.',
    });
  }
  for (var i = 0; i < (d['assets'] as List).length; i++) {
    final a = d['assets'][i];
    edge(a['originalBlobHash'], '/assets/$i/originalBlobHash', {
      'original',
      'generated',
    });
    if (a['externalLocator'] != null || a['originalBlobHash'] == null) {
      issues.add({'code': 'EXTERNAL_MEDIA_UNRESOLVED', 'path': '/assets/$i'});
    }
    for (final p in a['proxyRefs']) {
      edge(p['blobHash'], '/assets/$i/proxyRefs/blobHash', {'proxy'});
      edge(p['ptsMapBlobHash'], '/assets/$i/proxyRefs/ptsMapBlobHash', {
        'ptsMap',
      });
    }
  }
  for (var i = 0; i < (d['fontRefs'] as List).length; i++) {
    final f = d['fontRefs'][i];
    edge(f['hash'], '/fontRefs/$i/hash', {'font'});
  }
  for (var i = 0; i < (d['rightsRecords'] as List).length; i++) {
    edge(
      d['rightsRecords'][i]['evidenceBlobHash'],
      '/rightsRecords/$i/evidenceBlobHash',
      {'evidence'},
    );
  }
  const coreEffects = {
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
  for (var i = 0; i < (d['effects'] as List).length; i++) {
    final e = d['effects'][i];
    if (!coreEffects.contains(e['type']) ||
        (e['extensions'] as Map).isNotEmpty) {
      issues.add({
        'code': 'UNRESOLVED_EXTENSION_CLOSURE',
        'path': '/effects/$i',
        'detail': 'Unregistered effect/LUT walker; parameters remain opaque.',
      });
    }
    if (e['type'] == 'mask') {
      edge(e['parameters']['blobHash'], '/effects/$i/parameters/blobHash', {
        'mask',
      });
    }
  }
  for (var i = 0; i < (d['imageDocuments'] as List).length; i++) {
    final im = d['imageDocuments'][i];
    for (var j = 0; j < (im['layers'] as List).length; j++) {
      edge(im['layers'][j]['maskRef'], '/imageDocuments/$i/layers/$j/maskRef', {
        'mask',
      });
    }
  }
  for (var i = 0; i < (d['retainedSources'] as List).length; i++) {
    final r = d['retainedSources'][i];
    edge(r['definitionBlobHash'], '/retainedSources/$i/definitionBlobHash', {
      'snapshot',
    });
    for (final h in r['dependencyBlobHashes']) {
      edge(h, '/retainedSources/$i/dependencyBlobHashes', null);
    }
    issues.add({
      'code': 'UNRESOLVED_RETAINED_DEFINITION_CLOSURE',
      'path': '/retainedSources/$i',
      'detail': 'Declared dependencies preserved; recursive definition interpretation not qualified.',
    });
  }
  final resources = <Map<String, dynamic>>[];
  for (final b in blobs.values) {
    resources.add({
      ...Map<String, dynamic>.from(b),
      'uses': uses[b['hash']] ?? <dynamic>[],
      'formatQualification': 'notRun',
      'renderExecutable': false,
    });
  }
  return {
    'projectHash': project.hash,
    'resources': resources,
    'issues': issues,
    'registeredClosure': issues.isEmpty,
    'renderExecutable': false,
    'sourceCompleteness': 'unqualified',
    'reproductionComplete': false,
    'modelRefs': d['modelRefs'],
    'warnings': [
      for (final f in d['fontRefs'])
        {
          'code': 'FONT_REDISTRIBUTION_FACT',
          'fontId': f['id'],
          'embedAllowed': f['embedAllowed'],
          'licenseRef': f['licenseRef'],
          'permissionInferred': false,
        },
      if ((d['modelRefs'] as List).isNotEmpty)
        {
          'code': 'MODELS_REFERENCED_NOT_DOWNLOADED',
          'impact': 'reproGeneration',
        },
    ],
  };
}

/// Narrow registered fork profile: core media/image/font/effect references.
/// No recursive string replacement, provider IDs or opaque library IDs touched.
ProjectDocument forkResourceProject(
  ProjectDocument project,
  Namespace target, {
  required String Function() newId,
}) {
  if (!(projectResourceClosure(project)['registeredClosure'] as bool)) {
    throw const StudioException('UNRESOLVED_EXTENSION_CLOSURE');
  }
  final d = project.toJson();
  for (final table in [
    'retainedSources',
    'briefs',
    'scripts',
    'scenes',
    'characters',
    'shots',
    'generationRecords',
    'linkGroups',
    'selectionGroups',
    'markers',
    'captions',
    'transitions',
  ]) {
    if ((d[table] as List).isNotEmpty) {
      throw StudioException('RESOURCE_FORK_PROFILE_NOT_IMPLEMENTED', table);
    }
  }
  final ids = <String, String>{};
  void define(Map x) {
    ids[x['id'] as String] = newId();
  }

  final rootId = d['projectId'] as String;
  ids[rootId] = newId();
  for (final table in [
    'assets',
    'sequences',
    'effects',
    'audioBuses',
    'rightsRecords',
    'imageDocuments',
    'fontRefs',
  ]) {
    for (final x in d[table]) {
      define(x as Map);
    }
  }
  for (final a in d['assets']) {
    for (final st in a['streams']) {
      define(st as Map);
    }
  }
  for (final s in d['sequences']) {
    for (final t in s['tracks']) {
      define(t as Map);
      for (final c in t['items']) {
        define(c as Map);
      }
    }
  }
  for (final im in d['imageDocuments']) {
    for (final l in im['layers']) {
      define(l as Map);
    }
  }
  dynamic id(dynamic value) => value == null
      ? null
      : ids[value] ??
            (throw const StudioException(
              'RESOURCE_FORK_REFERENCE_UNREGISTERED',
            ));
  void field(Map x, String key) {
    if (x.containsKey(key)) x[key] = id(x[key]);
  }

  void list(Map x, String key) {
    x[key] = (x[key] as List).map(id).toList();
  }

  for (final table in [
    'assets',
    'sequences',
    'effects',
    'audioBuses',
    'rightsRecords',
    'imageDocuments',
    'fontRefs',
  ]) {
    for (final x in d[table]) {
      field(x as Map, 'id');
    }
  }
  for (final a in d['assets']) {
    field(a, 'rightsId');
    for (final st in a['streams']) {
      field(st, 'id');
    }
  }
  for (final s in d['sequences']) {
    field(s, 'masterBusId');
    for (final t in s['tracks']) {
      field(t, 'id');
      field(t, 'sequenceId');
      field(t, 'busId');
      for (final c in t['items']) {
        field(c, 'id');
        field(c, 'trackId');
        if (c['source'] != null) {
          field(c['source'], 'id');
          field(c['source'], 'streamId');
          list(c, 'effectIds');
          for (final k in [
            'linkGroupId',
            'selectionGroupId',
            'shotId',
            'candidateId',
            'provenanceId',
          ]) {
            if (c[k] != null) {
              throw const StudioException(
                'RESOURCE_FORK_PROFILE_NOT_IMPLEMENTED',
              );
            }
          }
        }
      }
    }
  }
  for (final b in d['audioBuses']) {
    field(b, 'outputBusId');
    list(b, 'inputBusIds');
    list(b, 'effectIds');
  }
  for (final e in d['effects']) {
    field(e['owner'], 'id');
    if (e['type'] == 'textStyle') field(e['parameters'], 'fontRef');
  }
  for (final r in d['rightsRecords']) {
    list(r, 'assetIds');
  }
  for (final im in d['imageDocuments']) {
    list(im, 'rootLayerIds');
    list(im, 'fontRefs');
    for (final l in im['layers']) {
      field(l, 'id');
      field(l, 'parentId');
      list(l, 'effectIds');
      if (l['sourceRef'] != null) field(l['sourceRef'], 'id');
    }
  }
  d['projectId'] = ids[rootId];
  d['rootSequenceId'] = id(d['rootSequenceId']);
  d['defaultFontRef'] = id(d['defaultFontRef']);
  d['namespace'] = target.toJson();
  d['revision'] = '0';
  return ProjectDocument.fromJson(d);
}
