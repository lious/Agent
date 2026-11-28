# ADR 0262 — N01–N02 profile observation wiring

Status: accepted Increment 3.63 binding before implementation.
Base 91439223878707181e3dadd01786e9d9a60ca892 was clean and matched
origin/feat/studio-foundation-20261125 before editing.
Follow native v1 N3–N6, the 3.63 observation supplement, and ADR 0260–0261.

3.62 qualified NG0–NG3 canaries and release-app smoke-test allowlists. It did
not attach Directory.watch or strace to the seven profiles, or provide
test-only navigation chrome. This ADR binds that attachment without requalifying
those gates or inventing CAS/shelf APIs, OS AT claims, or a product Navigator
surface. Protected roots stay the actual workspace/database (and configured
CAS/shelf if present). Flutter/debug/tool/fixture-signing/trace paths are
harness. Focus inspection uses Flutter Focus/Semantics during xdotool input.

Implement and independently qualify the seven official profiles if they still
form one coherent verified slice. Do not claim combined G1–G5 or full A6, and
do not rerun L01.
