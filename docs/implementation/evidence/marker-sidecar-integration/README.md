# Marker sidecar integration onto feat/studio-foundation-20261125

Integration of already-verified Increments M.1 (`6cfe464`) and M.2 (`67821dfe`) from `feat/studio-marker-sidecar` onto the shared feature branch tip `6732b081` (Increment 1.82). This is not a new 1.83 editing command and does not rewrite the original 104-spec snapshot.

Carried ADRs: `docs/adr/m001-marker-sidecar-v1.md`, `docs/adr/m002-marker-sidecar-workbench.md`. Integration ADR: `docs/adr/m003-marker-sidecar-integration.md`. Carried evidence directories `evidence/marker-sidecar/` and `evidence/marker-sidecar-workbench/` are kept; this directory records the re-run on the integrated tip.

Contract unchanged: `studio.markers.sidecar`, UTF-8 JSON no BOM, `.studio-markers.json`, workbench keys `marker-sidecar-path` / `marker-import-sidecar` / `marker-export-sidecar`. Increment 1.81 Slip and Increment 1.82 Roll production paths and buttons stay intact.
