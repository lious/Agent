# ADR 0263 — combined G1–G5 / late C2 same-binary binding

Status: accepted Increment 3.64 plan/evidence binding before any combined run.
Base 79109119861569d1b32093f8ba2f0ad67f7ba58d was clean and matched
origin/feat/studio-foundation-20261125 before editing.
Follow late v1 C2/C6/C7, the 3.64 late-v1 supplement, acceptance v1 P5,
App v1 A6.1–A6.7, the 3.61 audit, and ADRs 0257–0262.

Combined G1–G5 and full A6 are not claimed. The late C2 condition — one late-phase
fixture binary for all twelve C6 profiles — is not satisfied by the frozen 3.59
and 3.60 late main hashes
`afba0ef81607dd4986381f04bd1e38369c76c22f5d3179843189fa7fda03ef29` and
`935288c577714cac1ae695479edac7c16957d97284aa40de92941391c29312bb`.
Byte-identical L01 observer methods and independently qualified G2/G3/NG0–NG5
and N01–N02 rows do not establish that binary or combined C7 evidence.

This ADR specifies the next increment's combined run: a fresh G1 of default,
ordinary opt-in, and one isolated late fixture from frozen inputs; G4 of all
twelve C6 rows in fresh contexts against that single new late main hash; and
per-row G5 observations. Historical 3.59/3.60 contracts stay frozen. Do not
rerun B01–B11 or N01–N02 unless a genuine frozen-evidence conflict requires it.
A passing combined G1–G5 run does not automatically set fullA6AcceptanceComplete.
