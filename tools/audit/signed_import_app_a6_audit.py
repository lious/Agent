#!/usr/bin/env python3
"""Increment 3.66 official P5 / A6.1-A6.7 audit against recorded evidence only.

Does not re-execute historical runtimes or rewrite frozen 3.59-3.65 contracts.
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
L01_HIST = 'afba0ef81607dd4986381f04bd1e38369c76c22f5d3179843189fa7fda03ef29'
L023 = '935288c577714cac1ae695479edac7c16957d97284aa40de92941391c29312bb'

P5_CASES = {
    'B01': ROOT / 'docs/implementation/evidence/signed-import-app-fixture/B01.json',
    'B02': ROOT / 'docs/implementation/evidence/signed-import-app-fixture/B02.json',
    'B03': ROOT / 'docs/implementation/evidence/signed-import-app-fixture/B03.json',
    'B04': ROOT / 'docs/implementation/evidence/signed-import-app-fixture/B04.json',
    'B05': ROOT / 'docs/implementation/evidence/signed-import-app-lifecycle/B05.json',
    'B06-reload': ROOT / 'docs/implementation/evidence/signed-import-app-lifecycle/B06-reload.json',
    'B06-away-back': ROOT / 'docs/implementation/evidence/signed-import-app-lifecycle/B06-away-back.json',
    'B06-dispose': ROOT / 'docs/implementation/evidence/signed-import-app-lifecycle/B06-dispose.json',
    'B07-reading-navigation': ROOT / 'docs/implementation/evidence/signed-import-app-lifecycle/B07-reading-navigation.json',
    'B07-reading-handler-only': ROOT / 'docs/implementation/evidence/signed-import-app-lifecycle/B07-reading-handler-only.json',
    'B08-real-hidden': ROOT / 'docs/implementation/evidence/signed-import-app-lifecycle/B08-real-hidden.json',
    'B08-framework-inactive': ROOT / 'docs/implementation/evidence/signed-import-app-lifecycle/B08-framework-inactive.json',
    'B08-framework-hidden': ROOT / 'docs/implementation/evidence/signed-import-app-lifecycle/B08-framework-hidden.json',
    'B08-framework-paused': ROOT / 'docs/implementation/evidence/signed-import-app-lifecycle/B08-framework-paused.json',
    'B08-framework-detached': ROOT / 'docs/implementation/evidence/signed-import-app-lifecycle/B08-framework-detached.json',
    'B09-profile': ROOT / 'docs/implementation/evidence/signed-import-app-late-state/B09-profile.json',
    'B09-epoch': ROOT / 'docs/implementation/evidence/signed-import-app-late-state/B09-epoch.json',
    'B09-key-removal': ROOT / 'docs/implementation/evidence/signed-import-app-late-state/B09-key-removal.json',
    'B09-installed': ROOT / 'docs/implementation/evidence/signed-import-app-late-state/B09-installed.json',
    'B09-session': ROOT / 'docs/implementation/evidence/signed-import-app-late-state/B09-session.json',
    'B09-branch': ROOT / 'docs/implementation/evidence/signed-import-app-late-state/B09-branch.json',
    'B09-owner': ROOT / 'docs/implementation/evidence/signed-import-app-late-state/B09-owner.json',
    'B09-aba': ROOT / 'docs/implementation/evidence/signed-import-app-late-state/B09-aba.json',
    'B10': ROOT / 'docs/implementation/evidence/signed-import-app-late-state/B10.json',
    'B11-backward': ROOT / 'docs/implementation/evidence/signed-import-app-late-state/B11-backward.json',
    'B11-confidence': ROOT / 'docs/implementation/evidence/signed-import-app-late-state/B11-confidence.json',
    'B11-rollback': ROOT / 'docs/implementation/evidence/signed-import-app-late-state/B11-rollback.json',
}

C6 = [
    'L01-widget-dispose', 'L01-context',
    'L02-open-cancel', 'L02-open-dispose', 'L02-open-context',
    'L02-length-cancel', 'L02-length-dispose', 'L02-length-context',
    'L02-read-cancel', 'L02-read-dispose', 'L02-read-context',
    'L03-null-close-context',
]
N_ROWS = [
    'N01-enter', 'N01-space', 'N01-semantics',
    'N02-preview-navigation', 'N02-preview-dispose',
    'N02-read-navigation', 'N02-read-dispose',
]


def load(path: Path):
    return json.loads(path.read_text())


def audit():
    rows = []
    for case_id, path in P5_CASES.items():
        result = load(path)
        passed = result.get('passed') is True
        prefix = case_id.split('-')[0]
        slice_by_prefix = {
            'B01': '3.55', 'B02': '3.55', 'B03': '3.55', 'B04': '3.55',
            'B05': '3.56', 'B06': '3.56', 'B07': '3.56', 'B08': '3.56',
            'B09': '3.57', 'B10': '3.57', 'B11': '3.57',
        }
        rows.append({
            'caseId': case_id,
            'family': prefix,
            'evidence': str(path.relative_to(ROOT)),
            'passed': passed,
            'qualificationSlice': slice_by_prefix[prefix],
        })
        if not passed:
            raise SystemExit(f'frozen P5 case did not record passed=true: {case_id}')

    combined = load(ROOT / 'docs/implementation/evidence/signed-import-app-combined/contract.json')
    combined_run = load(ROOT / 'docs/implementation/evidence/signed-import-app-combined/combined.json')
    if not (combined['combinedG1G5Complete'] and combined_run['passed'] and combined['lateMainSha256'] == L023):
        raise SystemExit('3.65 combined G1-G5 contract is not the expected recorded pass')
    if combined['lateMainEqualsHistoricalL01'] or combined['historicalArtifactReusedAsC2'] is True:
        raise SystemExit('3.65 C2 binary record is inconsistent')
    if combined['fullA6AcceptanceComplete'] is not False:
        raise SystemExit('frozen 3.65 contract must remain fullA6AcceptanceComplete=false')

    late_rows = []
    for case_id in C6:
        path = ROOT / 'docs/implementation/evidence/signed-import-app-combined/results' / f'{case_id}.json'
        result = load(path)
        passed = (
            result.get('passed') is True
            and result.get('c2LateMainSha256') == L023
            and result.get('servedAssetSha256', {}).get('/main.dart.js') == L023
        )
        late_rows.append({
            'caseId': case_id,
            'evidence': str(path.relative_to(ROOT)),
            'passed': passed,
            'qualificationSlice': '3.65',
            'c2LateMainSha256': result.get('c2LateMainSha256'),
        })
        if not passed:
            raise SystemExit(f'combined C6 row missing or failed: {case_id}')

    hist_l01 = load(ROOT / 'docs/implementation/evidence/signed-import-app-pending-factory/artifacts.json')
    hist_l023 = load(ROOT / 'docs/implementation/evidence/signed-import-app-late-reader/artifacts.json')
    if hist_l01['builds']['late-phase']['mainSha256'] != L01_HIST:
        raise SystemExit('historical 3.59 late hash changed')
    if hist_l023['builds']['late-phase']['mainSha256'] != L023:
        raise SystemExit('historical 3.60 late hash changed')

    native = load(ROOT / 'docs/implementation/evidence/signed-import-app-native-profiles/contract.json')
    profiles = load(ROOT / 'docs/implementation/evidence/signed-import-app-native-profiles/profiles.json')
    if native['qualifiedNativeRows'] != N_ROWS or not profiles['passed'] or profiles['fullA6AcceptanceComplete'] is not False:
        raise SystemExit('3.63 native profile contract is not the expected recorded pass')
    native_rows = []
    by_case = {item['case']: item for item in profiles['summaries']}
    for case_id in N_ROWS:
        item = by_case[case_id]
        passed = item.get('passed') is True
        native_rows.append({
            'caseId': case_id,
            'evidence': 'docs/implementation/evidence/signed-import-app-native-profiles/profiles.json',
            'passed': passed,
            'qualificationSlice': '3.63',
        })
        if not passed:
            raise SystemExit(f'native row missing or failed: {case_id}')
    if native.get('osAssistiveDeviceClaimed') is not False:
        raise SystemExit('native contract must not claim OS assistive-device qualification')

    a61_remainders_361 = 'N01 positive native input/ack remains pending'
    dispositions = {
        'A6.1': {
            'status': 'met-with-recorded-limits',
            'remainderIn361': a61_remainders_361,
            'remainderClosedBy': '3.63 N01-enter/space/semantics on SkillImportHost.testImport with actual GTK chooser',
            'evidence': [
                'docs/implementation/evidence/signed-import-source-adapters/linux-results.json',
                'docs/implementation/evidence/signed-import-app-composition/linux.json',
                'docs/implementation/evidence/signed-import-app-native-profiles/profiles.json',
            ],
            'notes': (
                '3.51 recorded five actual GTK selections (regular, same-file reselection, '
                'cancel, cap, over-cap) on isolated box Xvfb as the official adapter-level '
                'chooser evidence (ADR 0250). 3.53 recorded one existing-App needsReview GTK '
                'capture and dismiss. 3.63 recorded official existing-App positive fixture '
                'capture and acknowledgment, closing the 3.61 A6.1 remainder. Not desktop '
                'portal, user-Mac, or production-chooser qualification.'
            ),
        },
        'A6.2': {
            'status': 'met-with-recorded-limits',
            'remainderIn361': '3.53 readiness negatives plus recorded B File/CSP/storage flows; no new requalification listed',
            'remainderClosedBy': 'no additional 3.61 remainder; 3.55-3.57 B File/CSP flows and 3.53 web profiles remain the recorded evidence',
            'evidence': [
                'docs/implementation/evidence/signed-import-app-composition/README.md',
                'docs/implementation/evidence/signed-import-source-adapters/web-results.json',
                'docs/implementation/evidence/signed-import-app-fixture/B01.json',
                'docs/implementation/evidence/signed-import-app-lifecycle/B05.json',
            ],
            'notes': (
                '3.53 recorded four compiled WebStudioApp profiles (normal, missing backend, '
                'CSP-blocked backend, SRI-tampered backend) with Choose disabled on backend '
                'failure. B01-B11 recorded actual compiled-App File selection, cancel/'
                'reselect, CSP/SRI, and no URL fetch. 3.51 recorded selected File size/slice '
                'fixtures (0/1/64KiB+/-1/4MiB+/-1 and Blob slices) at the compiled adapter/'
                'Chrome File boundary, which A6 requires be qualified before App preview '
                'controls. CDP File is not manual OS-dialog testing.'
            ),
        },
        'A6.3': {
            'status': 'met-with-recorded-limits',
            'remainderIn361': 'Existing cap/deadline/fence dependencies; L01 and G3/L02/L03 recorded; no aggregate promotion',
            'remainderClosedBy': '3.65 combined G1-G5 placed L01-L03 on one C2 binary; A6.3 test-only fake-stream suite remains the 3.51/3.52 recorded dependency',
            'evidence': [
                'docs/implementation/evidence/signed-import-source-adapters/README.md',
                'docs/implementation/evidence/import-composition-live-fence/README.md',
                'docs/implementation/evidence/signed-import-app-combined/combined.json',
            ],
            'notes': (
                'A6.3 is explicitly TESTS ONLY. 3.51 recorded 24/24 Dart cases covering '
                'cap-1/cap/cap+1, lying length/growth, partial reads, faults, and exact '
                '29999/30000ms deadlines. 3.52 recorded the live-App fence at each await. '
                'L01-L03 combined rows cover delayed factory and controlled non-cancellable '
                'open/length/read/close with dispose/scope/cancel and natural null. These '
                'are controlled-port or test-only streams, not real File qualification.'
            ),
        },
        'A6.4': {
            'status': 'met-with-recorded-limits',
            'remainderIn361': 'native trusted host/keyboard/semantics and its exclusion proof remain pending',
            'remainderClosedBy': '3.62 NG0-NG3 release exclusion and 3.63 N01 keyboard/semantics',
            'evidence': [
                'docs/implementation/evidence/signed-import-app-composition/README.md',
                'docs/implementation/evidence/signed-import-app-fixture/B01.json',
                'docs/implementation/evidence/signed-import-app-fixture/README.md',
                'docs/implementation/evidence/signed-import-app-native-prereq/README.md',
                'docs/implementation/evidence/signed-import-app-native-profiles/README.md',
            ],
            'notes': (
                '3.53 recorded 18 owner/widget cases including literal bounded rendering, '
                'trust labels, accessibility action, and default empty-roots/unknown-clock '
                'needsReview. B01 recorded exact fixture report hashes, requiredTools, and '
                'license warnings with verifiedReportObserved. B03 and N01-semantics use '
                'framework/standard semantics activation, not OS assistive-device '
                'qualification (ADR 0254; native contract osAssistiveDeviceClaimed=false). '
                'Isolated public fixture roots/time are used only for positive acknowledgment.'
            ),
        },
        'A6.5': {
            'status': 'met-with-recorded-limits',
            'remainderIn361': 'N01/N02 native counterparts remain pending',
            'remainderClosedBy': '3.63 seven official N01-N02 profiles',
            'evidence': [
                'docs/implementation/evidence/signed-import-app-fixture/README.md',
                'docs/implementation/evidence/signed-import-app-lifecycle/README.md',
                'docs/implementation/evidence/signed-import-app-late-state/README.md',
                'docs/implementation/evidence/signed-import-app-native-profiles/README.md',
            ],
            'notes': (
                'B01-B11 recorded separate one-use acknowledgment, rebuild/message non-'
                'acknowledgment, cancel/reselect, navigation/reload, pagehide, visibility, '
                'owner/grant/time staleness, and zero document writes/execution authority '
                'with no ApprovalReceipt. N01-N02 recorded the official native positive, '
                'repeat-refusal, navigation, dispose, and late-read counterparts.'
            ),
        },
        'A6.6': {
            'status': 'met-with-recorded-limits',
            'remainderIn361': '3.53 native byte snapshots alone do not satisfy new native continuous-observation transport',
            'remainderClosedBy': '3.63 Directory.watch plus strace observation window on protected roots',
            'evidence': [
                'docs/implementation/evidence/signed-import-app-composition/linux.json',
                'docs/implementation/evidence/signed-import-app-combined/contract.json',
                'docs/implementation/evidence/signed-import-app-native-profiles/README.md',
                'docs/implementation/evidence/signed-import-app-native-profiles/contract.json',
            ],
            'notes': (
                'Browser B and combined L rows recorded CSP, startup-versus-component '
                'requests, IDB/local/session snapshot equality, and no component writes. '
                '3.53 recorded native project/database/CAS/shelf file-byte snapshots with '
                'transient SQLite -shm excluded. 3.63 added continuous Directory.watch and '
                'strace judged only inside the recorded window. casShelfConfigured=false; '
                'CAS/shelf absence is proven by no such service being supplied, not by '
                'invented APIs.'
            ),
        },
        'A6.7': {
            'status': 'met-with-recorded-limits',
            'remainderIn361': 'new native seam/transport/analyzer/build/profile obligations have not run; combined closure not asserted',
            'remainderClosedBy': '3.62 Linux release exclusion builds and analyzer/format; 3.63 native profile compile/analyzer/format; 3.65 combined G1 and this 3.66 audit',
            'evidence': [
                'docs/implementation/evidence/signed-import-app-native-prereq/README.md',
                'docs/implementation/evidence/signed-import-app-native-profiles/README.md',
                'docs/implementation/evidence/signed-import-app-combined/README.md',
            ],
            'notes': (
                'Each implementing slice recorded analyzer/format and the relevant App '
                'compile or integration compile. 3.62 recorded three Linux release '
                'artifacts and sentinel scans; 3.63 profile execution used debug JIT '
                '(no libapp.so) against those frozen release exclusion artifacts. Web '
                'G1 release/CSP/source-map builds were recorded per browser slice and '
                'again for the 3.65 combined run. No skip or fake backend-success path '
                'is treated as acceptance. This audit is the official combined A6 '
                'closure check; it does not rerun those compiles.'
            ),
        },
    }

    non_claims = [
        'OS assistive-device or screen-reader qualification (B03 and N01-semantics are framework/standard semantics only)',
        'manual OS file-dialog testing (CDP File and box GTK_USE_PORTAL=0 Xvfb are the recorded browser/Linux boundaries)',
        'desktop portal chooser qualification',
        'OS lifecycle or device delivery (B08 framework injections qualify only the framework observer boundary; B08-real-hidden is actual tab visibility)',
        'real File qualification of L02-L03 (controlled-port test readers only)',
        'durable installation',
        'production publisher roots or clock provisioning',
        'cross-namespace import (B09-owner keeps namespace/store unchanged; the product flow stays unopened)',
        'production FTS/RAG',
        'device, model, provider, paid-API, or store-release acceptance',
        'user Mac or XS',
        'I-037 remaining product acceptance (P5:153-154: completing these rows still does not close I-037)',
    ]

    outstanding_a6_obligations = [
        name for name, item in dispositions.items() if not str(item['status']).startswith('met')
    ]
    full_a6 = (
        all(row['passed'] for row in rows)
        and all(row['passed'] for row in late_rows)
        and all(row['passed'] for row in native_rows)
        and combined['combinedG1G5Complete'] is True
        and not outstanding_a6_obligations
        and all(item['remainderClosedBy'] for item in dispositions.values())
    )

    report = {
        'increment': '3.66',
        'base': '0d1c66a8dacafc085681f47bdecb56fce7b206c2',
        'kind': 'official-p5-a6-audit-against-recorded-evidence',
        'newRuntimeExecutions': 0,
        'historicalSuitesRequalified': False,
        'l01Rerun': False,
        'b01B11Rerun': False,
        'l02L03HistoricalRerun': False,
        'g3SuiteRerun': False,
        'combinedG1G5Rerun': False,
        'n01N02Requalified': False,
        'ng0Ng5Requalified': False,
        'frozenEvidenceConflictFound': False,
        'combinedG1G5Complete': True,
        'combinedG1G5DoesNotByItselfSetFullA6': True,
        'fullA6AcceptanceComplete': full_a6,
        'i037RemainsPartial': True,
        'p5RowCoverageComplete': all(row['passed'] for row in rows + late_rows + native_rows),
        'p5BrowserCases': rows,
        'combinedC6Rows': late_rows,
        'nativeRows': native_rows,
        'lateC2MainSha256': L023,
        'historicalL01LateMainSha256': L01_HIST,
        'c2BinaryIsFresh365BuildNotHistorical360Path': True,
        'dispositions361Updated': dispositions,
        'outstandingA61ToA67Obligations': outstanding_a6_obligations,
        'recordedNonClaims': non_claims,
        'historicalContractsLeftUnchanged': [
            'docs/implementation/evidence/signed-import-app-combined/contract.json',
            'docs/implementation/evidence/signed-import-app-combined-plan/contract.json',
            'docs/implementation/evidence/signed-import-app-native-profiles/contract.json',
            'docs/implementation/evidence/signed-import-app-pending-factory/contract.json',
            'docs/implementation/evidence/signed-import-app-late-reader/contract.json',
        ],
    }
    if not full_a6:
        raise SystemExit('audit did not honestly complete official A6; not writing a true flag')
    return report


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    report = audit()
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps({
        'fullA6AcceptanceComplete': report['fullA6AcceptanceComplete'],
        'p5RowCoverageComplete': report['p5RowCoverageComplete'],
        'outstandingA61ToA67Obligations': report['outstandingA61ToA67Obligations'],
        'browserRows': len(report['p5BrowserCases']),
        'combinedRows': len(report['combinedC6Rows']),
        'nativeRows': len(report['nativeRows']),
    }, indent=2))


if __name__ == '__main__':
    main()
