# Public verification vectors

- RFC 8032 §7.1 tests 1, 2, 3 are transcribed in backend_test.dart from
  https://www.rfc-editor.org/rfc/rfc8032.txt (checked 2026-11-28 Asia/Shanghai).
- `ed25519_test.json`: C2SP Wycheproof, public EddsaVerify corpus, 210 cases,
  retrieved from https://raw.githubusercontent.com/C2SP/wycheproof/main/testvectors_v1/ed25519_test.json
  on 2026-11-28 (Asia/Shanghai). Exact SHA256:
  `ea80ffebac085e21cb9d3e903e7fa2b448d96702da5b31f061d0b83b430b74b3`.
  Apache-2.0 LICENSE retained alongside it. The test checks the pinned hash.

The corpus is ONE framework test containing 210 subcases, not 210 Dart tests.
Additional explicit negatives cover S>=L/S+L, altered messages/signatures,
identity/zero/noncanonical public keys and R points, lengths and artifact pinning.
FixtureSigner uses publicly defined deterministic bytes to produce local test
packs, never user/private publisher credentials. There is no production signer.
