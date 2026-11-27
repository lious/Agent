import 'package:studio_agent/studio_agent.dart';
import 'package:studio_contracts/studio_contracts.dart';
import 'package:test/test.dart';

Matcher code(String value) =>
    throwsA(isA<StudioException>().having((e) => e.code, 'code', value));

const digestA = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const digestB = 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
const sigA = '1111111111111111111111111111111111111111111111111111111111111111';
const sigB = '2222222222222222222222222222222222222222222222222222222222222222';

ModelPackManifest manifest({
  String packId = 'qwen3-1p7b-q4',
  String operatorId = 'fake.echo',
  String digest = digestA,
  String signature = sigA,
  bool offlineOnly = true,
}) {
  return ModelPackManifest(
    packId: packId,
    operatorId: operatorId,
    digestSha256: digest,
    signatureSha256: signature,
    contextTokens: 4096,
    outputTokens: 512,
    offlineOnly: offlineOnly,
  );
}

void main() {
  test('bad signature is refused and does not load a handle', () {
    final registry = ModelPackRegistry(trustedSignatures: {'qwen3-1p7b-q4': sigA});
    registry.registerCatalog(manifest());
    expect(
      () => registry.admit(
        packId: 'qwen3-1p7b-q4',
        providedSignature: sigB,
        providedDigest: digestA,
      ),
      code(modelPackBadSignature),
    );
    expect(registry.loadedPack, isNull);
  });

  test('bad digest is refused', () {
    final registry = ModelPackRegistry(trustedSignatures: {'qwen3-1p7b-q4': sigA});
    registry.registerCatalog(manifest());
    expect(
      () => registry.admit(
        packId: 'qwen3-1p7b-q4',
        providedSignature: sigA,
        providedDigest: digestB,
      ),
      code(modelPackBadSignature),
    );
  });

  test('unsupported operator is refused', () {
    final registry = ModelPackRegistry(
      allowedOperators: {'fake.echo'},
      trustedSignatures: {'pack-x': sigA},
    );
    registry.registerCatalog(
      manifest(packId: 'pack-x', operatorId: 'vendor.unknown'),
    );
    expect(
      () => registry.admit(
        packId: 'pack-x',
        providedSignature: sigA,
        providedDigest: digestA,
      ),
      code(operatorUnsupported),
    );
  });

  test('missing catalog pack is MODEL_PACK_MISSING', () {
    final registry = ModelPackRegistry();
    expect(
      () => registry.admit(
        packId: 'absent-pack',
        providedSignature: sigA,
        providedDigest: digestA,
      ),
      code(modelPackMissing),
    );
  });

  test('offlineOnly admission performs zero network requests', () {
    final registry = ModelPackRegistry(trustedSignatures: {'qwen3-1p7b-q4': sigA});
    registry.registerCatalog(manifest());
    expect(registry.networkRequestCount, 0);
    registry.admit(
      packId: 'qwen3-1p7b-q4',
      providedSignature: sigA,
      providedDigest: digestA,
    );
    expect(registry.networkRequestCount, 0);
    expect(registry.loadedPack, isNotNull);
  });

  test('shared allocation is counted once and double-count is refused', () {
    final registry = ModelPackRegistry(trustedSignatures: {'qwen3-1p7b-q4': sigA});
    registry.registerCatalog(manifest());
    final handle = registry.admit(
      packId: 'qwen3-1p7b-q4',
      providedSignature: sigA,
      providedDigest: digestA,
      shared: true,
      units: 2,
    );
    expect(registry.sharedUnits('qwen3-1p7b-q4'), 2);
    expect(
      () => registry.forbidDoubleCount(
        ResourceLease(
          leaseId: handle.leaseId,
          packId: handle.packId,
          shared: true,
          units: 2,
        ),
      ),
      code(leaseDoubleCount),
    );
    expect(registry.sharedUnits('qwen3-1p7b-q4'), 2);
    registry.release(handle);
    expect(registry.sharedUnits('qwen3-1p7b-q4'), 0);
  });

  test('process restart rejects stale handles and does not read old pointers', () {
    final registry = ModelPackRegistry(trustedSignatures: {'qwen3-1p7b-q4': sigA});
    registry.registerCatalog(manifest());
    final handle = registry.admit(
      packId: 'qwen3-1p7b-q4',
      providedSignature: sigA,
      providedDigest: digestA,
    );
    registry.simulateProcessRestart();
    expect(registry.loadedPack, isNull);
    expect(() => registry.requireLive(handle), code(stalePointer));
    expect(() => registry.release(handle), code(stalePointer));
  });
}
