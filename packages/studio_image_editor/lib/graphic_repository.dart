import 'dart:convert';
import 'dart:typed_data';

import 'package:studio_contracts/studio_contracts.dart';

import 'graphic_asset.dart';
import 'graphics_library_store.dart';
import 'image_codes.dart';
import 'template_pack.dart';

final class GraphicDraft {
  GraphicDraft({
    required this.asset,
    this.shared = false,
    this.rightsEpoch = '0',
  });

  final GraphicAsset asset;
  final bool shared;
  final String rightsEpoch;
}

/// Private graphics-library repository. Publishing a new version never
/// changes an existing project pin. This is not a permission grant.
final class GraphicRepository {
  GraphicRepository(this.store);

  final GraphicsLibraryStore store;

  static GraphicRepository open(String root, Namespace namespace) =>
      GraphicRepository(GraphicsLibraryStore.open(root, namespace));

  void close() => store.close();

  void registerRights({
    required String rightsId,
    required String epoch,
    required List<String> allowedUses,
    required bool redistributable,
  }) {
    store.putRights(
      rightsId: rightsId,
      epoch: epoch,
      allowedUses: allowedUses,
      redistributable: redistributable,
    );
  }

  GraphicPin publish(
    GraphicDraft draft,
    String? expectedHead,
    String rightsEpoch,
  ) {
    final asset = draft.asset;
    if (asset.namespace != store.namespace) {
      throw const StudioException('NAMESPACE_MISMATCH');
    }
    requireGraphicName(asset.name);
    final rights = store.rights(asset.rightsId);
    if (rights == null) {
      throw const StudioException(rightsRequired, 'rights');
    }
    if (rights['epoch'] != rightsEpoch) {
      throw const StudioException(rightsRequired, 'rightsEpoch');
    }
    if (draft.shared && rights['redistributable'] != true) {
      throw const StudioException(rightsRequired, 'redistribute');
    }
    final current = store.headVersion('graphic', asset.id);
    if ((expectedHead ?? '') != (current ?? '')) {
      throw const StudioException(templateVersionConflict, 'expectedHead');
    }
    if (current != null) {
      final currentNum = int.parse(current);
      if (asset.version != currentNum + 1) {
        throw const StudioException(templateVersionConflict, 'version');
      }
    } else if (asset.version != 1) {
      throw const StudioException(templateVersionConflict, 'version');
    }
    final hash = asset.bodyHash();
    final bytes = Uint8List.fromList(utf8.encode(jsonEncode(asset.toJson())));
    store.putCas(hash, bytes);
    store.insertVersion(
      kind: 'graphic',
      id: asset.id,
      version: '${asset.version}',
      bodyHash: hash,
    );
    store.setHead(kind: 'graphic', id: asset.id, version: '${asset.version}');
    return GraphicPin(id: asset.id, version: asset.version, hash: hash);
  }

  GraphicPin publishTemplate(
    TemplatePack pack,
    String? expectedHead,
  ) {
    requireGraphicName(pack.name);
    final current = store.headVersion('template', pack.id);
    if ((expectedHead ?? '') != (current ?? '')) {
      throw const StudioException(templateVersionConflict, 'expectedHead');
    }
    final hash = pack.packHash();
    final bytes = Uint8List.fromList(utf8.encode(jsonEncode(pack.toJson())));
    store.putCas(hash, bytes);
    store.insertVersion(
      kind: 'template',
      id: pack.id,
      version: pack.version,
      bodyHash: hash,
    );
    store.setHead(kind: 'template', id: pack.id, version: pack.version);
    return GraphicPin(
      id: pack.id,
      version: _semverOrdinal(pack.version),
      hash: hash,
      kind: 'template',
    );
  }

  GraphicAsset load(String id, int version) {
    final row = store.versionRow('graphic', id, '$version');
    if (row == null) {
      throw StudioException('RESOURCE_MISSING', id);
    }
    final body = jsonDecode(utf8.decode(store.readCas(row['body_hash'] as String)))
        as Map;
    return GraphicAsset.fromJson(Map<String, Object?>.from(body));
  }

  TemplatePack loadTemplate(String id, String version) {
    final row = store.versionRow('template', id, version);
    if (row == null) {
      throw StudioException('RESOURCE_MISSING', id);
    }
    final body = jsonDecode(utf8.decode(store.readCas(row['body_hash'] as String)))
        as Map;
    return TemplatePack.fromJson(Map<String, Object?>.from(body));
  }

  GraphicPin pinToProject({
    required String projectId,
    required GraphicPin pin,
  }) {
    store.pin(
      projectId: projectId,
      kind: pin.kind,
      id: pin.id,
      version: pin.kind == 'template' ? _storedTemplateVersion(pin) : '${pin.version}',
      hash: pin.hash,
    );
    return pin;
  }

  GraphicPin? projectPin(String projectId, String id, {String kind = 'graphic'}) {
    final row = store.projectPin(projectId, kind, id);
    if (row == null) return null;
    return GraphicPin(
      id: row['id'] as String,
      version: int.parse(row['version'] as String),
      hash: row['hash'] as String,
      kind: kind,
    );
  }

  /// Upgrade only the named project's pin. Other project pins stay put.
  GraphicPin upgradeProject({
    required String projectId,
    required GraphicPin newPin,
  }) {
    return pinToProject(projectId: projectId, pin: newPin);
  }

  GraphicPage search({
    required Namespace namespace,
    List<String> tags = const [],
    String text = '',
    String? cursor,
    int limit = 32,
  }) {
    if (namespace != store.namespace) {
      return GraphicPage(items: const []);
    }
    final wanted = [
      for (final t in tags)
        if (t.trim().isNotEmpty) t.trim().toLowerCase(),
    ];
    final needle = text.trim().toLowerCase();
    final items = <GraphicPin>[];
    for (final row in store.versionsInNamespace()) {
      if (row['kind'] != 'graphic') continue;
      final asset = load(row['id'] as String, int.parse(row['version'] as String));
      if (wanted.isNotEmpty && !wanted.every(asset.tags.contains)) continue;
      if (needle.isNotEmpty && !asset.name.toLowerCase().contains(needle)) {
        continue;
      }
      items.add(
        GraphicPin(
          id: asset.id,
          version: asset.version,
          hash: row['body_hash'] as String,
        ),
      );
    }
    final start = int.tryParse(cursor ?? '0') ?? 0;
    final slice = items.skip(start).take(limit).toList();
    final next = start + slice.length < items.length ? '${start + slice.length}' : null;
    return GraphicPage(items: slice, nextCursor: next);
  }

  GraphicPin renameOrRefine(
    GraphicPin pin,
    ({String? name, List<String>? tags}) changes,
    String? expectedHead,
  ) {
    final current = load(pin.id, pin.version);
    final next = current.copyWith(
      version: current.version + 1,
      name: changes.name ?? current.name,
      tags: changes.tags ?? current.tags,
    );
    return publish(
      GraphicDraft(asset: next, rightsEpoch: store.rights(current.rightsId)?['epoch'] as String? ?? '0'),
      expectedHead ?? '${current.version}',
      store.rights(current.rightsId)?['epoch'] as String? ?? '0',
    );
  }

  /// Selecting or pinning a graphic is not a redistribution grant.
  bool selectionGrantsRedistribution(String rightsId) => false;

  static int _semverOrdinal(String version) {
    final parts = version.split('.');
    final major = int.parse(parts[0]);
    final minor = parts.length > 1 ? int.parse(parts[1]) : 0;
    final patch = parts.length > 2 ? int.parse(parts[2]) : 0;
    return major * 1000000 + minor * 1000 + patch;
  }

  String _storedTemplateVersion(GraphicPin pin) {
    final row = store.versionRow('template', pin.id, store.headVersion('template', pin.id) ?? '');
    if (row != null && row['body_hash'] == pin.hash) {
      return row['version'] as String;
    }
    final head = store.headVersion('template', pin.id);
    return head ?? '1.0.0';
  }
}
