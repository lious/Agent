import 'package:studio_contracts/studio_contracts.dart';
import 'package:studio_render_node_probe/studio_render_node_probe.dart';
import 'package:test/test.dart';

/// Increment 2.97 official I-022 / s4 leftover: RenderNode is a closed
/// union; node outputs are required; the graph is acyclic; node
/// fingerprints participate in the cache key, which must not be only
/// the source filename.
///
/// This file does not claim a V-003 measurement, does not invent a
/// FrameLease or LUT runtime, and does not re-qualify Increment 2.90
/// RenderRecipeAdmission, Increment 2.92 PreviewExportConsistencyAdmission,
/// Increment 2.96 StillImageClipAdmission, I-024 export suites, or
/// ADR 0023/0024 CPU consumers. InversePatch kind stays
/// restoreSnapshot. Project user_version stays 9. I-022 stays partial.
Matcher code(String c) =>
    throwsA(isA<StudioException>().having((e) => e.code, 'code', c));

const _outputs = {
  'extent': '1920x1080',
  'pixelFormat': 'rgba16f',
  'color': 'linear709',
  'alphaMode': 'premultiplied',
};

RenderNodeDraft source({List<String> inputs = const []}) => RenderNodeDraft(
  id: 'src',
  kind: 'SourceNode',
  identity: const {
    'assetVersion': 'v1',
    'streamId': 'v0',
    'sourceAt': '0',
    'decoderLease': 'lease-1',
  },
  extent: _outputs['extent'],
  pixelFormat: _outputs['pixelFormat'],
  color: _outputs['color'],
  alphaMode: _outputs['alphaMode'],
  inputIds: inputs,
  fingerprint: 'fp-src',
);

RenderNodeDraft output({List<String> inputs = const ['src']}) =>
    RenderNodeDraft(
      id: 'out',
      kind: 'OutputNode',
      identity: const {'presetId': 'delivery-h264'},
      extent: _outputs['extent'],
      pixelFormat: _outputs['pixelFormat'],
      color: _outputs['color'],
      alphaMode: _outputs['alphaMode'],
      inputIds: inputs,
      fingerprint: 'fp-out',
    );

void main() {
  test('a closed-union acyclic graph with required outputs and fingerprints in the cache key is admitted', () {
    final admission = RenderNodeGraphAdmission();
    final receipt = admission.admit(
      RenderNodeGraphRequest(
        nodes: [source(), output()],
        cacheKey: 'fp-src|fp-out|preset',
      ),
    );
    expect(receipt.closedUnion, isTrue);
    expect(receipt.acyclic, isTrue);
    expect(receipt.fingerprintInCacheKey, isTrue);
  });

  test('an unknown kind, missing outputs, and a cycle are refused', () {
    final admission = RenderNodeGraphAdmission();
    expect(
      () => admission.admit(
        RenderNodeGraphRequest(
          nodes: [
            const RenderNodeDraft(
              id: 'x',
              kind: 'UnknownNode',
              extent: '1x1',
              pixelFormat: 'rgba8',
              color: '709',
              alphaMode: 'opaque',
              fingerprint: 'fp',
            ),
          ],
          cacheKey: 'fp',
        ),
      ),
      code('RENDER_NODE_UNKNOWN'),
    );
    expect(
      () => admission.admit(
        RenderNodeGraphRequest(
          nodes: [
            const RenderNodeDraft(
              id: 'src',
              kind: 'SourceNode',
              identity: {
                'assetVersion': 'v1',
                'streamId': 'v0',
                'sourceAt': '0',
                'decoderLease': 'lease-1',
              },
              fingerprint: 'fp-src',
            ),
          ],
          cacheKey: 'fp-src',
        ),
      ),
      code('RENDER_NODE_OUTPUT_REQUIRED'),
    );
    expect(
      () => admission.admit(
        RenderNodeGraphRequest(
          nodes: [
            source(inputs: ['out']),
            output(inputs: ['src']),
          ],
          cacheKey: 'fp-src|fp-out',
        ),
      ),
      code('RENDER_GRAPH_CYCLE'),
    );
  });

  test(
    'a filename-only cache key is refused; node fingerprints must participate',
    () {
      final admission = RenderNodeGraphAdmission();
      expect(
        () => admission.admit(
          RenderNodeGraphRequest(
            nodes: [source(), output()],
            cacheKey: 'clip.mp4',
            cacheKeyIsSourceFilenameOnly: true,
          ),
        ),
        code('CACHE_KEY_FILENAME_ONLY'),
      );
      expect(
        () => admission.admit(
          RenderNodeGraphRequest(
            nodes: [source(), output()],
            cacheKey: 'clip.mp4',
          ),
        ),
        code('CACHE_KEY_FILENAME_ONLY'),
      );
    },
  );

  test('a V-003 measurement, FrameLease, LUT runtime, and already-official recipe or consistency admissions stay closed', () {
    final admission = RenderNodeGraphAdmission();
    expect(admission.v003Claimed, isFalse);
    expect(admission.frameLeaseInvented, isFalse);
    expect(admission.lutRuntimeInvented, isFalse);
    expect(admission.renderRecipeRequalified, isFalse);
    expect(admission.previewExportRequalified, isFalse);
    expect(admission.stillImageRequalified, isFalse);
    expect(admission.muxerInvented, isFalse);
    expect(admission.i024Rewritten, isFalse);
    expect(admission.paidApiCalled, isFalse);
  });
}
