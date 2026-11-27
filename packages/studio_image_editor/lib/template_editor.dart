import 'package:studio_contracts/studio_contracts.dart';

import 'graphic_asset.dart';
import 'graphic_repository.dart';
import 'image_codes.dart';
import 'template_catalog.dart';
import 'template_pack.dart';
import 'template_service.dart';
import 'template_validator.dart';

/// Testable template / library editor session. This is the I-026 UI
/// controller: create, rename, tag, search, instantiate, rebind, and
/// deliver. It is not a Flutter widget tree and not V-003 GPU qualification.
final class TemplateEditorSession {
  TemplateEditorSession({
    required this.repository,
    required this.namespace,
    TemplateService? templates,
  }) : templates = templates ?? TemplateService();

  final GraphicRepository repository;
  final Namespace namespace;
  final TemplateService templates;
  final TemplateValidator validator = const TemplateValidator();

  Instantiation? current;
  TemplatePack? currentPack;
  String? selectedSlotId;
  int _n = 0;

  GraphicPin createGraphic(GraphicDraft draft, String rightsEpoch) {
    validator.validateAsset(draft.asset);
    return repository.publish(draft, null, rightsEpoch);
  }

  GraphicPin rename(GraphicPin pin, String name) {
    requireGraphicName(name);
    return repository.renameOrRefine(
      pin,
      (name: name, tags: null),
      '${pin.version}',
    );
  }

  GraphicPin retag(GraphicPin pin, List<String> tags) {
    return repository.renameOrRefine(
      pin,
      (name: null, tags: tags),
      '${pin.version}',
    );
  }

  GraphicPage search({String text = '', List<String> tags = const []}) {
    return repository.search(
      namespace: repository.store.namespace,
      text: text,
      tags: tags,
    );
  }

  Instantiation instantiateOfficial(
    String templateId, {
    List<TemplateBinding> bindings = const [],
    bool allowDraft = false,
  }) {
    final pack = OfficialTemplateCatalog.byId(templateId);
    _n++;
    currentPack = pack;
    current = templates.instantiate(
      pack: pack,
      instanceId: 'inst-$_n',
      documentId: 'doc-$_n',
      namespace: namespace,
      bindings: bindings,
      allowDraft: allowDraft,
    );
    selectedSlotId = pack.slots.first.id;
    return current!;
  }

  Instantiation instantiateStored({
    required String templateId,
    required String version,
    required List<TemplateBinding> bindings,
    required bool metadataRecognized,
  }) {
    validator.requireKnownTemplate(metadataRecognized: metadataRecognized);
    final pack = repository.loadTemplate(templateId, version);
    _n++;
    currentPack = pack;
    current = templates.instantiate(
      pack: pack,
      instanceId: 'inst-$_n',
      documentId: 'doc-$_n',
      namespace: namespace,
      bindings: bindings,
    );
    selectedSlotId = pack.slots.isEmpty ? null : pack.slots.first.id;
    return current!;
  }

  void selectSlot(String slotId) {
    selectedSlotId = slotId;
  }

  void rebindSelected({String? assetHash, String? text}) {
    final inst = current;
    final pack = currentPack;
    if (inst == null || pack == null || selectedSlotId == null) {
      throw const StudioException('INVALID_ID', 'selection');
    }
    validator.requireKnownTemplate(metadataRecognized: true);
    templates.rebind(
      document: inst.document,
      pack: pack,
      instance: inst.instance,
      slotId: selectedSlotId!,
      assetHash: assetHash,
      text: text,
    );
  }

  void refuseFlatten() {
    throw const StudioException(flattenForbidden);
  }

  /// Required empty slots may stay as a draft. Delivery is blocked.
  void requestDelivery() {
    final inst = current;
    final pack = currentPack;
    if (inst == null || pack == null) {
      throw const StudioException('INVALID_ID', 'instance');
    }
    for (final slot in pack.slots.where((s) => s.required)) {
      if (slot.kind == SlotKind.text) continue;
      final binding = inst.instance.bindings.where((b) => b.slotId == slot.id);
      final hash = binding.isEmpty ? null : binding.first.assetHash;
      if (hash == null || hash == _empty) {
        throw StudioException(requiredSlotEmpty, slot.id);
      }
    }
  }

  /// Using a graphic in the editor does not grant public redistribution.
  bool usingGrantsRedistribution(String rightsId) =>
      repository.selectionGrantsRedistribution(rightsId);
}

const _empty =
    '0000000000000000000000000000000000000000000000000000000000000000';
