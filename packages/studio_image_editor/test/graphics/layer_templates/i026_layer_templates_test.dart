import 'package:studio_contracts/studio_contracts.dart';
import 'package:studio_image_editor/studio_image_editor.dart';
import 'package:test/test.dart';

Matcher code(String value) =>
    throwsA(isA<StudioException>().having((e) => e.code, 'code', value));

const photoHash =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const otherHash =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

final ns = Namespace('studio', 'local', 'image-i026');

List<TemplateBinding> requiredBindings(TemplatePack pack) {
  return [
    for (final slot in pack.slots)
      if (slot.kind != SlotKind.text && slot.required)
        TemplateBinding(slotId: slot.id, assetHash: photoHash),
  ];
}

Instantiation instantiate(
  TemplatePack pack, {
  String? documentId,
  FontRegistry? fonts,
  EffectRegistry? effects,
  List<TemplateBinding>? bindings,
}) {
  return TemplateService(fonts: fonts, effects: effects).instantiate(
    pack: pack,
    instanceId: 'inst-${pack.id}',
    documentId: documentId ?? 'doc-${pack.id}',
    namespace: ns,
    bindings: bindings ?? requiredBindings(pack),
  );
}

void main() {
  test('catalog has ten official layered templates across the planned families', () {
    final packs = OfficialTemplateCatalog.all();
    expect(packs, hasLength(10));
    expect({for (final p in packs) p.id}, hasLength(10));
    expect(
      {for (final p in packs) p.family},
      containsAll(['photo-card', 'paper-collage', 'brand-card']),
    );
    for (final pack in packs) {
      expect(pack.layers.length, greaterThanOrEqualTo(3));
      expect(pack.layers.where((l) => l.kind == LayerKind.text), isNotEmpty);
    }
  });

  test('all ten templates round-trip without flattening and keep structure hash', () {
    final service = TemplateService();
    for (final pack in OfficialTemplateCatalog.all()) {
      final first = instantiate(pack);
      expect(first.document.layers.length, pack.layers.length);
      expect(
        first.instance.generatedLayerIds,
        hasLength(pack.layers.length),
      );
      final before = first.document.structureHash();
      final again = service.roundTrip(first.document, first.instance);
      expect(again.document.layers.length, first.document.layers.length);
      expect(
        [for (final l in again.document.layers) l.id],
        [for (final l in first.document.layers) l.id],
      );
      expect(
        [for (final l in again.document.layers) l.kind],
        [for (final l in first.document.layers) l.kind],
      );
      expect(again.document.structureHash(), before);
      expect(again.document.flatten, code(flattenForbidden));
    }
  });

  test('rebinding a photo slot does not change original source hashes or other layers', () {
    final pack = OfficialTemplateCatalog.byId('tmpl-photo-card-portrait');
    final born = instantiate(pack);
    final photoLayerId = '${born.document.id}-ly-photo';
    final titleBefore = born.document.layer('${born.document.id}-ly-title').text;
    final titleTransform =
        born.document.layer('${born.document.id}-ly-title').transform;
    final original = born.document.originalHash(photoLayerId);
    expect(original, photoHash);
    TemplateService().rebind(
      document: born.document,
      pack: pack,
      instance: born.instance,
      slotId: 'slot-photo',
      assetHash: otherHash,
    );
    expect(born.document.originalHash(photoLayerId), photoHash);
    expect(born.document.layer(photoLayerId).sourceHash, otherHash);
    expect(born.document.layer('${born.document.id}-ly-title').text, titleBefore);
    expect(
      born.document.layer('${born.document.id}-ly-title').transform.tx,
      titleTransform.tx,
    );
    expect(born.document.layers.length, pack.layers.length);
  });

  test('locked layers are not changed by a batch reference grade', () {
    final pack = OfficialTemplateCatalog.byId('tmpl-caption-poster');
    final born = instantiate(pack);
    final locked = born.document.layer('${born.document.id}-ly-photo')
      ..locked = true;
    final unlocked = born.document.layer('${born.document.id}-ly-title');
    final lockedBefore = locked.grade.exposure;
    final changed = TemplateService().applyReferenceGrade(
      born.document,
      const ColorGrade(exposure: 0.5),
    );
    expect(changed, isNot(contains(locked.id)));
    expect(changed, contains(unlocked.id));
    expect(locked.grade.exposure, lockedBefore);
    expect(unlocked.grade.exposure, 0.5);
  });

  test('inferred color cannot be stored as an original fact and style suggestions can be refused', () {
    final pack = OfficialTemplateCatalog.byId('tmpl-product-frame');
    final born = instantiate(pack);
    final service = TemplateService();
    expect(
      () => service.applyReferenceGrade(
        born.document,
        const ColorGrade(exposure: 0.2, inferred: true),
      ),
      code(inferredColorNotFact),
    );
    expect(
      () => service.applyReferenceGrade(
        born.document,
        const ColorGrade(exposure: 0.2),
        refuseSuggestion: true,
      ),
      code(styleSuggestionRefused),
    );
    expect(
      born.document.layer('${born.document.id}-ly-product').grade.exposure,
      0,
    );
  });

  test('missing fonts and effects are explicit degrades and stay on the layer', () {
    final pack = OfficialTemplateCatalog.byId('tmpl-brand-card-logo-top');
    final born = instantiate(
      pack,
      fonts: FontRegistry({'font-sans'}),
      effects: EffectRegistry({}),
    );
    // headline uses font-serif, which is missing; no effect on this pack's
    // layers except none required. Use product-frame for effect.
    final frame = instantiate(
      OfficialTemplateCatalog.byId('tmpl-product-frame'),
      fonts: FontRegistry({'font-sans'}),
      effects: EffectRegistry({}),
    );
    expect(born.degrades.map((d) => d.code), contains(missingFont));
    expect(
      born.document.layer('${born.document.id}-ly-headline').fontId,
      'font-serif',
    );
    expect(frame.degrades.map((d) => d.code), contains(missingEffect));
    expect(
      frame.document.layer('${frame.document.id}-ly-frame').effectId,
      'effect-frame',
    );
  });

  test('slot type mismatches and locked-field rebinds are refused', () {
    final pack = OfficialTemplateCatalog.byId('tmpl-photo-card-square');
    final born = instantiate(pack);
    final service = TemplateService();
    expect(
      () => service.rebind(
        document: born.document,
        pack: pack,
        instance: born.instance,
        slotId: 'slot-caption',
        assetHash: otherHash,
      ),
      code(slotType),
    );
    born.document.layer('${born.document.id}-ly-photo').locked = true;
    expect(
      () => service.rebind(
        document: born.document,
        pack: pack,
        instance: born.instance,
        slotId: 'slot-photo',
        assetHash: otherHash,
      ),
      code(lockedField),
    );
  });
}
