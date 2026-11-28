# Locked verifier port — Linux DEV only

The optional `studio_signed_skill_import.dart` entrypoint uses libsodium **1.0.22**,
ISC (LICENSE retained), `crypto_sign_verify_detached` (Pure Ed25519) and
`crypto_core_ed25519_is_valid_point` (strict canonical prime-subgroup points).
It does not implement curve arithmetic, Ed25519ph, key discovery or installation.

Source archive and exact SHA256: `backend-lock.json`. API reference:
https://doc.libsodium.org/public-key_cryptography/public-key_signatures
Sources checked 2026-11-28 (Asia/Shanghai). No signing private key is needed to
build or use this verifier. Test-only fixture seeds are public deterministic
values, not user credentials or production publisher keys.

Reproduce the tested host dependency outside the repository (about 2 MiB source):

```sh
curl -fL https://download.libsodium.org/libsodium/releases/libsodium-1.0.22.tar.gz -o /workspace/libsodium-1.0.22.tar.gz
echo 'adbdd8f16149e81ac6078a03aca6fc03b592b89ef7b5ed83841c086191be3349  /workspace/libsodium-1.0.22.tar.gz' | sha256sum -c -
mkdir -p /workspace/toolchains/sodium-1.0.22-src
tar -xzf /workspace/libsodium-1.0.22.tar.gz -C /workspace/toolchains/sodium-1.0.22-src --strip-components=1
cd /workspace/toolchains/sodium-1.0.22-src
./configure --prefix=/workspace/toolchains/sodium-1.0.22 --disable-static
make -j4 && make install
sha256sum /workspace/toolchains/sodium-1.0.22/lib/libsodium.so.26.4.0
```

The binary hash in the lock records THIS qualified Linux x86_64 DEV build. It
is not a portable/reproducible-build assertion: compiler/path/toolchain changes
can change it. Another App release must pin its own immutable deployed artifact
in trusted configuration and independently rerun backend/import tests before
claiming that artifact. The loader rejects symlink paths and a hash/version
mismatch. Immutable trusted deployment is required; this is not protection from
a local attacker controlling the host or changing a binary during dlopen.
The importer never downloads, builds, installs or updates a backend at runtime.
No Web, macOS, iOS, XS, hardware, provider or production deployment is qualified.

Tests (from packages/studio_assets):

```sh
dart test test/skills/signed_import
dart analyze
```

Tests require the qualified native artifact (no silent skip or permissive fake
backend). `STUDIO_SODIUM_LIBRARY` can select a relocated copy with the SAME pinned
binary hash, not a replacement verifier. Backend corpus provenance is under
`test/skills/signed_import/vectors/README.md`.

## Trusted App composition boundary

Construct `BuildTimeSignaturePolicy` only alongside the installed `AppProfile`;
never parse it from the selected envelope. The `disabled(profile, namespace)`
factory has zero trusted keys. Actual publisher roots require independent App
release provisioning; the deterministic test roots must never ship as trust.
`FilmSkillRepository` requires that concrete pinned backend, a trusted App
snapshot callback, and an `ImportUserActionPort` retained by the App UI. Only
App code handling explicit consent may mint its one-use gesture. Register none
of these policy/UI constructors as model tools. `importPack` accepts a captured
byte capability, target namespace, and the identical installed policy object;
a keyid/signed/claimedApproved field cannot replace those composition roots.

This is an executable in-memory import/preview and acknowledgment service, NOT
a wired file-picker/UI or durable skill installation. Referenced argument/template
blobs, renderer support, entities and runSkill expansion are not resolved or
executed here. Current grants and normal compiler/runtime gates remain required
for every future execution; the preview/ack record is not their ApprovalReceipt.
