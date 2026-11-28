# ADR 0264 — combined G1–G5 run against one fresh late C2 binary

Status: accepted Increment 3.65 combined G1–G5 qualification.
Base 113ea94fd84106d5d624f9885fe3dc530a2c8d15 was clean and matched
origin/feat/studio-foundation-20261125 before editing.
Follow late v1 C2/C6/C7, the 3.64 and 3.65 late-v1 supplements, acceptance v1
P5, App v1 A6.1–A6.7, and ADRs 0257–0263.

A fresh disposable-cache G1 of default, ordinary opt-in, and one isolated late
fixture, followed by G4/G5 of all twelve C6 rows in fresh contexts, was executed
against a single late main hash
`935288c577714cac1ae695479edac7c16957d97284aa40de92941391c29312bb`.
That digest matches the historical 3.60 late fixture because no studio_web
source has changed since 3.60; the C2 binary is the freshly built 3.65
artifact, not the historical 3.60 output path. It does not match the 3.59 L01
hash `afba0ef81607dd4986381f04bd1e38369c76c22f5d3179843189fa7fda03ef29`.
Already-qualified G2/G3 transports were reused and not requalified.
Historical 3.59/3.60/3.64 contracts stay frozen. N01–N02, NG0–NG5, B01–B11,
and the 3.59/3.60 qualifications were not rerun as those historical suites.

Combined G1–G5 is claimed. fullA6AcceptanceComplete remains false; a passing
combined run still does not, by itself, set that flag. The P5 A6.1–A6.7 audit
remains required, and I-037 installation, production publisher roots,
cross-namespace import, and production FTS/RAG stay open.
