# Locked browser dependency — opt-in only

libsodium.js 0.8.4 combined browser-sumo, ISC, expected core 1.0.22. Exact bytes
and both digests are in `backend-lock.json`. Retain both upstream license files.
The historical candidate lock is NOT rewritten as implementation evidence.

The App packages these exact files into an immutable same-origin asset root:
- `web/vendor/studio-signed-import/sodium-0.8.4-sumo.js` -> the identical absolute
  path `/vendor/studio-signed-import/sodium-0.8.4-sumo.js`;
- `web/signed_import_bootstrap.js` -> an App-owned script path.

Check SHA256 **and** SHA384 before packaging. No re-minifying, floating npm,
CDN, altered path, service-worker substitution, fetch/eval or unsigned retry.
The trusted App loads its bootstrap with its own fixed SRI, before compiled Dart,
and serves the W2 CSP as an HTTP header:

```
default-src 'none'; script-src 'self' 'sha384-mMeApJgV3qm7BJusi9ualkYZcdoTJBRsmYEZdzYa+yNWz+UH12DXh6SwImc6IO2V' 'wasm-unsafe-eval'; connect-src 'self'; object-src 'none'; base-uri 'none'
```

Only the bootstrap loads the vendor script, with the locked SRI attribute BEFORE
execution. Missing or failed bootstrap/crypto produces no repository, even for
unsigned data. Await `createWebSignedSkillRepository(currentApp, trustedUi)` from
`studio_signed_skill_import_web.dart`. Do NOT queue selected tokens while waiting,
cache a pre-await App snapshot, deserialize policies from packs, or interpret
readiness as user consent. Default publisher roots are empty.

Only Dart compiled to JS, main realm, the recorded Chrome/Linux test-host profile
is independently qualified. The artifact is combined JS/WebAssembly; the tests
make NO claim about which internal implementation path ran. Other engines,
Dart-to-Wasm, workers, file pickers/UI, production publisher provisioning and
persistence are not qualified or wired here. App-origin/bootstrap integrity is
trusted deployment, NOT XSS attestation. Fail terminally, never relax CSP.

Reproduce the independent browser suite from repository root:

```
python3 packages/studio_assets/test/skills/signed_import_web/make_fixtures.py --check
python3 tools/acceptance/run_signed_import_web.py
```

The runner verifies the locked artifact before any execution, uses fresh browser
profiles and loopback HTTP, and orders real production-bridge crypto tests before
the actual compiled importer. `--no-sandbox` is solely for the isolated container
Chrome process, not a web-security/CSP/certificate disable flag. No signed-in
profile, user computer, paid service, native signer in browser or fake backend is
used. Fixture generation is offline TEST ONLY using documented PUBLIC seeds.
