"""Evidence-only provenance/coverage audit. Never builds or runs an App."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[2]
BASE = '7c616a4aab245505f3fdd9fac15095fd640f5e3b'
GROUPS = [
    ('fixture', 'c30441a71e0285bd597ac85c1fa7357822678c8a', 4),
    ('lifecycle', '2a137beb9ef088aaf855a343a7a3d3c56694c525', 11),
    ('late-state', 'f42d46d30f9dc88f9a15106022ba34c3cea5d69b', 12),
    ('pending-factory', 'e499a223995bf067edbf506bb8e45d681a5b8ad6', 2),
    ('late-reader', BASE, 10),
]
PREFIX = 'docs/implementation/evidence/signed-import-app-'


def git_bytes(ref, path):
    return subprocess.check_output(['git', 'show', ref + ':' + path], cwd=ROOT)


def digest(data):
    return hashlib.sha256(data).hexdigest()


def require(value, message):
    if not value:
        raise ValueError(message)


def inspect_group(name, ref, count):
    folder = PREFIX + name + '/'
    names = subprocess.check_output(
        ['git', 'ls-tree', '-r', '--name-only', ref, '--', folder], cwd=ROOT,
        text=True).splitlines()
    frozen = {p: git_bytes(ref, p) for p in names}
    for p, data in frozen.items():
        require((ROOT / p).read_bytes() == data, 'frozen evidence edited: ' + p)
    artifacts = json.loads(frozen[folder + 'artifacts.json'])
    contract = json.loads(frozen[folder + 'contract.json'])
    require(artifacts['passed'], name + ': artifact proof not recorded passed')
    require(not contract['fullA6AcceptanceComplete'], name + ': scope enlarged')
    for p, sha in artifacts['sourceSha256'].items():
        require(digest(git_bytes(ref, p)) == sha, name + ': source provenance ' + p)
    for target, build in artifacts['builds'].items():
        fixture = target not in ('default', 'opt-in')
        require(build['fixtureSentinelsPresent'] == fixture, name + ': sentinel scope')
        require(build['testEntrypointInSourceMap'] == fixture, name + ': map scope')
    case_paths = sorted(p for p in names if Path(p).stem.startswith(('B', 'L')) and p.endswith('.json'))
    require(len(case_paths) == count, name + ': incorrect case count')
    records = []
    for path in case_paths:
        result = json.loads(frozen[path])
        case = Path(path).stem
        require(result['caseId'] == case, case + ': case identity')
        require(result['passed'] and result['storageSnapshotUnchanged'], case + ': recorded result')
        require(result.get('noComponentWrites', result.get('noImportWrites')) is True, case + ': write witness')
        require(not result['exceptions'] and not result['violations'], case + ': runtime/CSP errors')
        require(not result.get('nativeTraceDataLoss', False), case + ': trace data loss')
        require(result['sri'] in result['csp'], case + ': SRI/CSP mismatch')
        require("'unsafe-inline'" not in result['csp'] and "'unsafe-eval'" not in result['csp'], case + ': unsafe policy')
        sha = result['servedAssetSha256']['/main.dart.js']
        matches = [k for k, b in artifacts['builds'].items() if b['mainSha256'] == sha]
        require(len(matches) == 1 and matches[0] not in ('default', 'opt-in'), case + ': served binary provenance')
        lock = json.loads(git_bytes(ref, 'packages/studio_assets/third_party/sodium_web/backend-lock.json'))
        require(result['servedAssetSha256'][lock['appAssetPath']] == lock['sourceSha256'], case + ': locked vendor')
        if name == 'fixture':
            require(result['noAutoAcknowledgment'], case + ': automatic acknowledgment')
            require(result['oneUseAcknowledgment'] == (case != 'B04'), case + ': one-shot scope')
        else:
            require(result.get('noAcknowledgmentAccepted', result.get('noAcknowledgment')) is True, case + ': acknowledgment')
        records.append({'caseId': case, 'evidencePath': path,
                        'evidenceSha256': digest(frozen[path]), 'recordedPassed': True,
                        'artifactTarget': matches[0], 'mainSha256': sha})
    return {'name': name, 'qualificationCommit': ref, 'recordedCaseCount': count,
            'recordedBuildCount': len(artifacts['builds']),
            'sourceHashesChecked': len(artifacts['sourceSha256']),
            'frozenFilesSha256': {p: digest(data) for p, data in frozen.items()},
            'cases': records}


def audit():
    groups = [inspect_group(*group) for group in GROUPS]
    cases = [c for g in groups for c in g['cases']]
    late = [c for c in cases if c['caseId'].startswith('L')]
    require(len(cases) == 39 and len(late) == 12, 'coverage cardinality')
    def observer(ref):
        source = git_bytes(ref, 'apps/studio_web/lib/main.dart').decode()
        return source[source.index('  void _recordFixtureRepository('):source.index('  BrowserProjectStore?')].encode()
    require(observer(GROUPS[3][1]) == observer(BASE), 'passive L01 observer changed')
    docs = sorted((ROOT / 'docs/adr').glob('02*.md'))
    adrs = {str(p.relative_to(ROOT)): digest(p.read_bytes()) for p in docs
            if 248 <= int(p.name[:4]) <= 259}
    require(len(adrs) == 12, 'ADR dependency coverage')
    return {'increment': '3.61', 'base': BASE, 'kind': 'frozen-evidence-integrity-audit-only',
            'auditChecksPassed': True, 'newRuntimeExecutions': 0,
            'currentRuntimeRequalified': False, 'l01Rerun': False,
            'frozenEvidenceConflictFound': False, 'fullA6AcceptanceComplete': False,
            'allLateRuntimeGatesComplete': False,
            'historicalBrowserProfileCount': len(cases), 'historicalLateProfileCount': len(late),
            'historicalBuildRecordCount': sum(g['recordedBuildCount'] for g in groups),
            'lateFixtureBinarySha256': sorted({c['mainSha256'] for c in late}),
            'unchangedL01ObserverSha256': digest(observer(BASE)),
            'combinedConditionStatus': 'OPEN: C2 one-binary/C7 combined evidence not established by versioned union',
            'qualifiedNativeRows': [], 'plannedNativeRows': ['N01', 'N02'],
            'adrSha256': adrs, 'groups': groups}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path)
    args = parser.parse_args()
    text = json.dumps(audit(), indent=2) + '\n'
    if args.output:
        args.output.write_text(text)
    else:
        print(text, end='')
