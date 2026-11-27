import 'package:studio_contracts/studio_contracts.dart';
import 'package:studio_image_editor/studio_image_editor.dart';
import 'package:test/test.dart';

/// Increment 2.64 official first I-043 slice: source-coordinate
/// round-trip, locked-mask refine, and erase-layer accept/undo. This
/// file does not invent auto-segmentation or a real inpainting
/// engine, does not claim V-011=image-erase, does not rewrite I-026
/// templates or graphics-library tests, does not start I-044/I-045,
/// I-061, I-055, or I-035, and does not mark I-037, I-038, V-007,
/// V-020, I-054, I-051, I-046, I-041, I-040, I-053, I-056, I-057,
/// I-052, I-039, or V-026 complete. InversePatch kind stays
/// restoreSnapshot. Project user_version stays 9.
Matcher code(String c) =>
    throwsA(isA<StudioException>().having((e) => e.code, 'code', c));

void main() {
  test('eight orientations and crop padding round-trip within 0.5 source pixels; the official ROI golden maps (600,300) to (512,256)', () {
    final mapper = officialRoiMapper();
    expect(mapper.resizedWidth, 1024);
    expect(mapper.resizedHeight, 512);
    expect(mapper.padLeft, 0);
    expect(mapper.padTop, 0);
    final model = mapper.uprightToModel(const SrcPoint(600, 300));
    expect(model.x, closeTo(512, 1e-9));
    expect(model.y, closeTo(256, 1e-9));
    final back = mapper.modelToUpright(model);
    expect(back.x, closeTo(600, 1e-9));
    expect(back.y, closeTo(300, 1e-9));

    for (var orientation = 1; orientation <= 8; orientation++) {
      final oriented = officialRoiMapper(orientation: orientation);
      const upright = SrcPoint(600.5, 300.5);
      final raw = oriented.uprightToRaw(upright);
      final recovered = oriented.modelToRaw(oriented.rawToModel(raw));
      expect(
        recovered.distanceTo(raw),
        lessThanOrEqualTo(0.5),
        reason: 'orientation $orientation',
      );
      expect(
        oriented.rawToUpright(raw).distanceTo(upright),
        lessThanOrEqualTo(0.5),
        reason: 'upright $orientation',
      );
    }
  });

  test('a locked mask tile is not overwritten; accept is one undoable transaction and does not delete the original; a late cancel does not write user layers', () {
    const hash =
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
    final session = EraseLayerSession(originalHash: hash);
    session.refine(
      sourceFrameHash: hash,
      lockedTileIds: const ['tile-locked'],
      uprightPoints: const [SrcPoint(600.5, 300.5)],
    );
    expect(session.mask.version, 2);
    expect(session.mask.uprightPoints, isNotEmpty);
    expect(
      () => session.refine(
        sourceFrameHash: hash,
        lockedTileIds: const [],
        targetTileIds: const ['tile-locked'],
      ),
      code('MASK_LOCK_CONFLICT'),
    );
    expect(session.mask.version, 2);
    expect(
      () => session.refine(
        sourceFrameHash:
            'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
        lockedTileIds: const [],
      ),
      code('MASK_SOURCE_CHANGED'),
    );

    final accepted = session.accept(mode: EraseMode.alphaOnly);
    expect(accepted.transactionCount, 1);
    expect(accepted.newLayerAttached, isTrue);
    expect(accepted.originalHash, hash);
    expect(accepted.calledInpaint, isFalse);
    expect(session.originalDeleted, isFalse);
    session.undo();
    expect(session.attachedLayerId, isNull);
    expect(session.userLayersWritten, 0);
    expect(session.originalDeleted, isFalse);
    expect(session.originalHash, hash);

    session.lateCancel();
    expect(session.quarantined, isTrue);
    expect(session.userLayersWritten, 0);
    expect(session.documentWrites, 0);
    expect(session.v011Claimed, isFalse);
  });

  test('text selection without a grounder is refused; alpha-only does not call inpaint; a missing pack is not relabeled as intelligent classic inpaint; a binary mask is not matting', () {
    const hash =
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
    final session = EraseLayerSession(originalHash: hash);
    expect(
      () => session.groundWithText(grounderInstalled: false),
      code('GROUNDING_UNAVAILABLE'),
    );
    expect(
      () => session.claimLlmBoxesAsGrounding(),
      code('GROUNDING_UNAVAILABLE'),
    );
    expect(
      () => session.claimBinaryMaskAsMatting(),
      code('UNSUPPORTED_EDIT_TECHNIQUE'),
    );
    expect(
      () => session.claimConfidenceAsPhysicalAlpha(),
      code('UNSUPPORTED_EDIT_TECHNIQUE'),
    );

    final alpha = session.propose(mode: EraseMode.alphaOnly);
    expect(alpha.calledInpaint, isFalse);
    expect(alpha.newLayerAttached, isFalse);
    expect(alpha.binaryMaskTreatedAsMatting, isFalse);
    expect(alpha.inferredBackgroundIsFact, isFalse);
    expect(
      () => session.propose(
        mode: EraseMode.removeAndFill,
        packVerified: false,
        labelClassicAsIntelligent: true,
      ),
      code('UNSUPPORTED_EDIT_TECHNIQUE'),
    );
    expect(
      () => session.propose(mode: EraseMode.removeAndFill, packVerified: false),
      code('MODEL_ABI_UNVERIFIED'),
    );
    expect(session.autoSegmentationInvented, isFalse);
    expect(session.inpaintEngineInvented, isFalse);
    expect(session.v011Claimed, isFalse);
    expect(session.submitted, isFalse);
    expect(session.paidApiCalled, isFalse);
  });
}
