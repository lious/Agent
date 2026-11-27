import 'layer.dart';
import 'template_pack.dart';

const _emptyHash =
    '0000000000000000000000000000000000000000000000000000000000000000';

ImageLayer _bg(String id) => ImageLayer(
  id: id,
  kind: LayerKind.image,
  name: 'background',
  sourceHash: _emptyHash,
);

ImageLayer _photo(String id) => ImageLayer(
  id: id,
  kind: LayerKind.image,
  name: 'photo',
  sourceHash: _emptyHash,
);

ImageLayer _text(String id, String text, {String fontId = 'font-sans'}) =>
    ImageLayer(
      id: id,
      kind: LayerKind.text,
      name: 'text',
      text: text,
      fontId: fontId,
    );

ImageLayer _deco(String id, {String? effectId}) => ImageLayer(
  id: id,
  kind: LayerKind.decoration,
  name: 'decoration',
  effectId: effectId,
);

ImageLayer _mask(String id) => ImageLayer(
  id: id,
  kind: LayerKind.mask,
  name: 'mask',
  sourceHash: _emptyHash,
);

TemplatePack _pack({
  required String id,
  required String name,
  required String family,
  required int width,
  required int height,
  required List<ImageLayer> layers,
  required List<TemplateSlot> slots,
}) {
  return TemplatePack(
    id: id,
    name: name,
    family: family,
    width: width,
    height: height,
    layers: layers,
    slots: slots,
  );
}

/// Ten official original templates in the photo-card, paper-collage, and
/// brand-card families, plus caption-poster and product-frame. These are
/// not sticker products and are not copied from a third-party site.
final class OfficialTemplateCatalog {
  static List<TemplatePack> all() => [
    _pack(
      id: 'tmpl-photo-card-portrait',
      name: 'Photo card portrait',
      family: 'photo-card',
      width: 1080,
      height: 1350,
      layers: [
        _bg('ly-bg'),
        _photo('ly-photo'),
        _text('ly-title', 'Title'),
        _deco('ly-frame', effectId: 'effect-frame'),
      ],
      slots: [
        TemplateSlot(id: 'slot-photo', layerId: 'ly-photo', kind: SlotKind.image, required: true, safeRect: [80, 80, 920, 1000]),
        TemplateSlot(id: 'slot-title', layerId: 'ly-title', kind: SlotKind.text, required: false, safeRect: [80, 1120, 920, 160], defaultText: 'Title'),
      ],
    ),
    _pack(
      id: 'tmpl-photo-card-square',
      name: 'Photo card square',
      family: 'photo-card',
      width: 1080,
      height: 1080,
      layers: [
        _bg('ly-bg'),
        _photo('ly-photo'),
        _text('ly-caption', 'Caption'),
      ],
      slots: [
        TemplateSlot(id: 'slot-photo', layerId: 'ly-photo', kind: SlotKind.image, required: true, safeRect: [40, 40, 1000, 800]),
        TemplateSlot(id: 'slot-caption', layerId: 'ly-caption', kind: SlotKind.text, required: false, safeRect: [40, 860, 1000, 180], defaultText: 'Caption'),
      ],
    ),
    _pack(
      id: 'tmpl-photo-card-landscape',
      name: 'Photo card landscape',
      family: 'photo-card',
      width: 1920,
      height: 1080,
      layers: [
        _bg('ly-bg'),
        _photo('ly-photo'),
        _text('ly-title', 'Title'),
        _mask('ly-mask'),
      ],
      slots: [
        TemplateSlot(id: 'slot-photo', layerId: 'ly-photo', kind: SlotKind.image, required: true, safeRect: [80, 80, 1200, 920]),
        TemplateSlot(id: 'slot-title', layerId: 'ly-title', kind: SlotKind.text, required: false, safeRect: [1320, 80, 520, 200], defaultText: 'Title'),
      ],
    ),
    _pack(
      id: 'tmpl-paper-collage-2x2',
      name: 'Paper collage 2x2',
      family: 'paper-collage',
      width: 1080,
      height: 1080,
      layers: [
        _bg('ly-bg'),
        _photo('ly-a'),
        _photo('ly-b'),
        _photo('ly-c'),
        _photo('ly-d'),
        _deco('ly-tape'),
        _text('ly-label', 'Collage'),
      ],
      slots: [
        TemplateSlot(id: 'slot-a', layerId: 'ly-a', kind: SlotKind.image, required: true, safeRect: [40, 40, 480, 480]),
        TemplateSlot(id: 'slot-b', layerId: 'ly-b', kind: SlotKind.image, required: true, safeRect: [560, 40, 480, 480]),
        TemplateSlot(id: 'slot-c', layerId: 'ly-c', kind: SlotKind.image, required: true, safeRect: [40, 560, 480, 480]),
        TemplateSlot(id: 'slot-d', layerId: 'ly-d', kind: SlotKind.image, required: true, safeRect: [560, 560, 480, 480]),
        TemplateSlot(id: 'slot-label', layerId: 'ly-label', kind: SlotKind.text, required: false, safeRect: [40, 1040, 1000, 32], defaultText: 'Collage'),
      ],
    ),
    _pack(
      id: 'tmpl-paper-collage-diagonal',
      name: 'Paper collage diagonal',
      family: 'paper-collage',
      width: 1080,
      height: 1350,
      layers: [
        _bg('ly-bg'),
        _photo('ly-fore'),
        _photo('ly-back'),
        _text('ly-note', 'Note'),
        _deco('ly-paper'),
      ],
      slots: [
        TemplateSlot(id: 'slot-fore', layerId: 'ly-fore', kind: SlotKind.image, required: true, safeRect: [120, 80, 840, 700]),
        TemplateSlot(id: 'slot-back', layerId: 'ly-back', kind: SlotKind.image, required: false, safeRect: [80, 720, 400, 500]),
        TemplateSlot(id: 'slot-note', layerId: 'ly-note', kind: SlotKind.text, required: false, safeRect: [520, 720, 480, 500], defaultText: 'Note'),
      ],
    ),
    _pack(
      id: 'tmpl-paper-collage-postcard',
      name: 'Paper collage postcard',
      family: 'paper-collage',
      width: 1600,
      height: 1000,
      layers: [
        _bg('ly-bg'),
        _photo('ly-photo'),
        _text('ly-body', 'Hello'),
        _deco('ly-stamp'),
      ],
      slots: [
        TemplateSlot(id: 'slot-photo', layerId: 'ly-photo', kind: SlotKind.image, required: true, safeRect: [40, 40, 760, 920]),
        TemplateSlot(id: 'slot-body', layerId: 'ly-body', kind: SlotKind.text, required: false, safeRect: [840, 80, 700, 800], defaultText: 'Hello'),
      ],
    ),
    _pack(
      id: 'tmpl-brand-card-logo-top',
      name: 'Brand card logo top',
      family: 'brand-card',
      width: 1080,
      height: 1080,
      layers: [
        _bg('ly-bg'),
        ImageLayer(id: 'ly-logo', kind: LayerKind.graphic, name: 'logo', sourceHash: _emptyHash),
        _text('ly-headline', 'Headline', fontId: 'font-serif'),
        _photo('ly-photo'),
      ],
      slots: [
        TemplateSlot(id: 'slot-logo', layerId: 'ly-logo', kind: SlotKind.graphic, required: true, safeRect: [80, 40, 200, 200]),
        TemplateSlot(id: 'slot-headline', layerId: 'ly-headline', kind: SlotKind.text, required: false, safeRect: [320, 40, 680, 200], defaultText: 'Headline'),
        TemplateSlot(id: 'slot-photo', layerId: 'ly-photo', kind: SlotKind.image, required: true, safeRect: [80, 280, 920, 720]),
      ],
    ),
    _pack(
      id: 'tmpl-brand-card-logo-bottom',
      name: 'Brand card logo bottom',
      family: 'brand-card',
      width: 1080,
      height: 1920,
      layers: [
        _bg('ly-bg'),
        _photo('ly-photo'),
        _text('ly-headline', 'Headline'),
        ImageLayer(id: 'ly-logo', kind: LayerKind.graphic, name: 'logo', sourceHash: _emptyHash),
      ],
      slots: [
        TemplateSlot(id: 'slot-photo', layerId: 'ly-photo', kind: SlotKind.image, required: true, safeRect: [0, 0, 1080, 1400]),
        TemplateSlot(id: 'slot-headline', layerId: 'ly-headline', kind: SlotKind.text, required: false, safeRect: [80, 1440, 920, 200], defaultText: 'Headline'),
        TemplateSlot(id: 'slot-logo', layerId: 'ly-logo', kind: SlotKind.graphic, required: true, safeRect: [80, 1680, 200, 160]),
      ],
    ),
    _pack(
      id: 'tmpl-caption-poster',
      name: 'Caption poster',
      family: 'caption-poster',
      width: 1080,
      height: 1920,
      layers: [
        _bg('ly-bg'),
        _photo('ly-photo'),
        _text('ly-title', 'Title', fontId: 'font-serif'),
        _text('ly-sub', 'Subtitle'),
        _mask('ly-vignette'),
      ],
      slots: [
        TemplateSlot(id: 'slot-photo', layerId: 'ly-photo', kind: SlotKind.image, required: true, safeRect: [0, 0, 1080, 1920]),
        TemplateSlot(id: 'slot-title', layerId: 'ly-title', kind: SlotKind.text, required: false, safeRect: [80, 1400, 920, 200], defaultText: 'Title'),
        TemplateSlot(id: 'slot-sub', layerId: 'ly-sub', kind: SlotKind.text, required: false, safeRect: [80, 1620, 920, 160], defaultText: 'Subtitle'),
      ],
    ),
    _pack(
      id: 'tmpl-product-frame',
      name: 'Product frame',
      family: 'product-frame',
      width: 1080,
      height: 1080,
      layers: [
        _bg('ly-bg'),
        _photo('ly-product'),
        _deco('ly-frame', effectId: 'effect-frame'),
        _text('ly-price', 'Price'),
        ImageLayer(id: 'ly-badge', kind: LayerKind.graphic, name: 'badge', sourceHash: _emptyHash),
      ],
      slots: [
        TemplateSlot(id: 'slot-product', layerId: 'ly-product', kind: SlotKind.image, required: true, safeRect: [120, 80, 840, 760]),
        TemplateSlot(id: 'slot-price', layerId: 'ly-price', kind: SlotKind.text, required: false, safeRect: [120, 880, 400, 120], defaultText: 'Price'),
        TemplateSlot(id: 'slot-badge', layerId: 'ly-badge', kind: SlotKind.graphic, required: false, safeRect: [760, 880, 200, 120]),
      ],
    ),
  ];

  static TemplatePack byId(String id) =>
      all().firstWhere((p) => p.id == id);
}
