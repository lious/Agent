#!/usr/bin/env python3
"""Increment 3.65 official combined G1-G5 run. Does not reuse historical late hashes
as the C2 binary, requalify N01-N02/NG0-NG5, or rewrite 3.59/3.60 contracts."""
import base64, hashlib, http.server, json, os, secrets, shutil, signal, subprocess, sys, tempfile, threading
from pathlib import Path
from urllib.parse import unquote, urlsplit

from late_host_gate import VendorResponseGate

ROOT = Path(__file__).resolve().parents[2]
OUT = Path('/workspace/skill-import-app-365')
HIST_L01 = 'afba0ef81607dd4986381f04bd1e38369c76c22f5d3179843189fa7fda03ef29'
HIST_L023 = '935288c577714cac1ae695479edac7c16957d97284aa40de92941391c29312bb'
C6 = [
    'L01-widget-dispose', 'L01-context',
    'L02-open-cancel', 'L02-open-dispose', 'L02-open-context',
    'L02-length-cancel', 'L02-length-dispose', 'L02-length-context',
    'L02-read-cancel', 'L02-read-dispose', 'L02-read-context',
    'L03-null-close-context',
]
SENTINELS = [
    'ebVWLo/mVPlAeLES6KmLp5AfhTrmlb7X4OORC60ElmQ=',
    'sha256:65b60673d6ed884bf01c2c222d82ada0740f29ac3355d6a925c81f17f47a27b8',
    'Fixture transition:', 'Apply fixture transition ', 'Fixture owner facts:',
    'profileChanged=', 'data-signed-import-fixture-repository',
    'data-signed-import-late-reader', 'Arm fixture reader ', 'Release fixture reader',
]


def sri(b):
    return 'sha384-' + base64.b64encode(hashlib.sha384(b).digest()).decode()


def sha256_file(path):
    with open(path, 'rb') as f:
        return hashlib.file_digest(f, 'sha256').hexdigest()


def sha256_bytes(b):
    return hashlib.sha256(b).hexdigest()


def source_hashes():
    inputs = [
        *sorted((ROOT / 'apps/studio_web/lib').glob('*.dart')),
        ROOT / 'apps/studio_web/test/import_late_phase_entrypoint.dart',
        ROOT / 'apps/studio_web/test/import_late_reader.dart',
        ROOT / 'pubspec.lock',
        ROOT / 'packages/studio_assets/third_party/sodium_web/backend-lock.json',
        ROOT / 'packages/studio_assets/web/signed_import_bootstrap.js',
        ROOT / 'packages/studio_assets/third_party/sodium_web/LICENSE.core',
    ]
    return {str(p.relative_to(ROOT)): sha256_file(p) for p in inputs}


def preflight(lock, vendor):
    assert sha256_bytes(vendor) == lock['sourceSha256'] and sri(vendor) == lock['sri'] and len(vendor) == lock['sourceBytes']
    assert all(
        '/test/' not in line and 'import_fixture_entrypoint' not in line
        for p in (ROOT / 'apps/studio_web/lib').glob('*.dart')
        for line in p.read_text().splitlines() if line.startswith('import ')
    )
    entry = (ROOT / 'apps/studio_web/test/import_late_phase_entrypoint.dart').read_text()
    assert 'nowSeconds: 1000' in entry and 'clockConfident: true' in entry
    assert 'data-signed-import-late-reader' in entry
    assert 'importFixture = null' in (ROOT / 'apps/studio_web/lib/main.dart').read_text()


def build_g1(lock):
    OUT.mkdir(exist_ok=True)
    hashes = source_hashes()
    cache = ROOT / 'apps/studio_web/.dart_tool/flutter_build'
    assert not cache.is_symlink()
    if cache.exists():
        shutil.rmtree(cache)
    builds = {}
    for name, target, optin in [
        ('default', 'lib/main.dart', False),
        ('opt-in', 'lib/main.dart', True),
        ('late-phase', 'test/import_late_phase_entrypoint.dart', True),
    ]:
        dest = OUT / (name + '-app')
        if dest.exists():
            shutil.rmtree(dest)
        command = [
            '/workspace/toolchains/flutter/bin/flutter', 'build', 'web', '--release',
            '--csp', '--source-maps', '--no-web-resources-cdn', '--no-wasm-dry-run',
            '--target=' + target, '--output=' + str(dest),
        ]
        if optin:
            command += ['--dart-define=STUDIO_SIGNED_IMPORT_PREVIEW=true']
        print('+', ' '.join(command), flush=True)
        subprocess.run(command, cwd=ROOT / 'apps/studio_web', check=True)
        js = (dest / 'main.dart.js').read_text()
        source_map = (dest / 'main.dart.js.map').read_text()
        fixture = name == 'late-phase'
        assert all((x in js) == fixture for x in SENTINELS)
        assert ('import_late_phase_entrypoint.dart' in source_map) == fixture
        assert ('import_late_reader.dart' in source_map) == fixture
        assert 'data-signed-import-fixture-reader' not in js
        builds[name] = {
            'target': target,
            'optIn': optin,
            'sourceMapSha256': sha256_bytes(source_map.encode()),
            'mainSha256': sha256_bytes(js.encode()),
            'fixtureSentinelsPresent': fixture,
            'testEntrypointInSourceMap': fixture,
            'heldReaderSentinelPresent': False,
        }
    assert hashes == source_hashes(), 'source changed during G1 build'
    late = builds['late-phase']['mainSha256']
    # Fresh build required. A digest that happens to match 3.60 is a reproducible
    # rebuild of current sources, not adoption of the historical 3.60 artifact path.
    artifacts = {
        'passed': True,
        'increment': '3.65',
        'verifiedArtifactReuse': False,
        'freshDisposableCache': True,
        'builds': builds,
        'sourceSha256': hashes,
        'defaultSourceUsesNullFixture': True,
        'fixtureClockDefinedOnlyInTestEntrypoint': True,
        'lateMainSha256': late,
        'historicalLateHashes': {'L01': HIST_L01, 'L02-L03': HIST_L023},
        'lateMainEqualsHistoricalL01': late == HIST_L01,
        'lateMainEqualsHistoricalL023': late == HIST_L023,
        'c2BinaryIsFreshBuild': True,
        'c2BinaryPath': str(OUT / 'late-phase-app' / 'main.dart.js'),
        'historicalArtifactReusedAsC2': False,
    }
    (OUT / 'artifacts.json').write_text(json.dumps(artifacts, indent=2) + '\n')
    if late == HIST_L01:
        raise SystemExit('fresh late fixture unexpectedly matched the 3.59 L01 hash; refusing to treat that historical binary as C2 without a distinct combined build record')
    return artifacts


def serve_and_run(mode, lock, vendor):
    web = OUT / 'late-phase-app'
    static = {
        '/signed_import_bootstrap.js': (ROOT / 'packages/studio_assets/web/signed_import_bootstrap.js').read_bytes(),
        '/flutter_bootstrap.js': (web / 'flutter_bootstrap.js').read_bytes(),
        lock['appAssetPath']: vendor,
    }
    nonce = secrets.token_urlsafe(16)
    index = (web / 'index.html').read_text().replace('</head>', '<meta name="app-style-nonce" content="' + nonce + '"></head>')
    scripts = ''.join('<script src="' + p + '" integrity="' + sri(static[p]) + '"></script>' for p in ['/signed_import_bootstrap.js', '/flutter_bootstrap.js'])
    index = index.replace('<script src="/flutter_bootstrap.js" async></script>', scripts)
    assert scripts in index and '<base' not in index
    policy = (
        "default-src 'none'; script-src 'self' '" + lock['sri'] + "' 'wasm-unsafe-eval'; "
        "connect-src 'self'; object-src 'none'; base-uri 'none'; font-src 'self'; img-src 'self'; "
        "style-src 'self' 'nonce-" + nonce + "'; worker-src 'none'; form-action 'none'; frame-ancestors 'none'"
    )
    hashes = {}
    document_responses = []
    gate_results = []
    control = None
    if mode.startswith('L01-'):
        control = OUT / 'controls' / mode
        control.mkdir(parents=True, exist_ok=True)
        for filename in ['held.json', 'release.json']:
            (control / filename).unlink(missing_ok=True)

    class Host(http.server.BaseHTTPRequestHandler):
        def do_GET(self):
            p = unquote(urlsplit(self.path).path)
            active_index, active_policy = index, policy
            if p == '/':
                response_nonce = secrets.token_urlsafe(16)
                active_index = index.replace(nonce, response_nonce)
                active_policy = policy.replace(nonce, response_nonce)
                document_responses.append({
                    'nonce': response_nonce,
                    'csp': active_policy,
                    'indexSha256': sha256_bytes(active_index.encode()),
                })
            if p == '/away.html':
                data, mime = b'<!doctype html><title>Fixture navigation destination</title>', 'text/html'
            elif p == '/':
                data, mime = active_index.encode(), 'text/html'
            elif p in static:
                data, mime = static[p], 'text/javascript'
            else:
                f = (web / p.lstrip('/')).resolve()
                if not f.is_relative_to(web) or not f.is_file():
                    self.send_response(404)
                    self.end_headers()
                    return
                data = f.read_bytes()
                mime = 'application/wasm' if f.suffix == '.wasm' else 'text/javascript' if f.suffix == '.js' else 'application/octet-stream'
            if p == lock['appAssetPath'] and control is not None:
                gate_results.append(VendorResponseGate(control, mode).wait_for_release())
            hashes[p] = sha256_bytes(data)
            self.send_response(200)
            self.send_header('Content-Type', mime)
            self.send_header('Content-Security-Policy', active_policy)
            self.end_headers()
            self.wfile.write(data)

        def log_message(self, *_):
            pass

    server = http.server.ThreadingHTTPServer(('127.0.0.1', 0), Host)
    threading.Thread(target=server.serve_forever, daemon=True).start()
    try:
        with tempfile.TemporaryDirectory(prefix='skill-combined-365-') as profile:
            display = subprocess.Popen(
                ['Xvfb', '-displayfd', '1', '-screen', '0', '1920x1200x24', '-nolisten', 'tcp'],
                stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True,
            )
            number = display.stdout.readline().strip()
            if not number:
                raise RuntimeError('Xvfb failed')
            env = dict(
                os.environ, DISPLAY=':' + number, GTK_USE_PORTAL='0',
                XDG_CONFIG_HOME=profile + '/config', XDG_DATA_HOME=profile + '/data',
                XDG_CACHE_HOME=profile + '/cache',
            )
            chrome = subprocess.Popen(
                [
                    '/usr/bin/google-chrome', '--ozone-platform=x11', '--window-size=1920,1200',
                    '--no-sandbox', '--disable-background-networking', '--disable-dev-shm-usage',
                    '--no-first-run', '--no-default-browser-check', '--remote-debugging-port=0',
                    '--user-data-dir=' + profile + '/chrome', 'about:blank',
                ],
                stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True, env=env,
            )
            result_path = OUT / 'results' / (mode + '.json')
            result_path.parent.mkdir(parents=True, exist_ok=True)
            try:
                if mode.startswith('L01-'):
                    cmd = [
                        'node', str(ROOT / 'tools/acceptance/import_late_phase/browser.cjs'),
                        profile + '/chrome/DevToolsActivePort',
                        f'http://127.0.0.1:{server.server_port}/',
                        str(result_path), mode, str(control),
                    ]
                else:
                    cmd = [
                        'node', str(ROOT / 'tools/acceptance/import_late_reader/browser.cjs'),
                        profile + '/chrome/DevToolsActivePort',
                        f'http://127.0.0.1:{server.server_port}/',
                        str(result_path), mode,
                    ]
                print('+', mode, flush=True)
                subprocess.run(cmd, check=True, timeout=120, env=env)
            finally:
                os.killpg(chrome.pid, signal.SIGTERM)
                chrome.wait(timeout=10)
                display.terminate()
                display.wait(timeout=10)
    finally:
        server.shutdown()
        server.server_close()
    if mode.startswith('L01-'):
        assert len(gate_results) == 1 and gate_results[0]['released'] and not gate_results[0]['watchdogFired'], gate_results
    result = json.loads(result_path.read_text())
    if mode.startswith('L01-'):
        result['vendorBodyGate'] = gate_results[0]
    result.update(
        csp=document_responses[0]['csp'],
        documentResponses=document_responses,
        servedAssetSha256=hashes,
        sri=lock['sri'],
        combinedIncrement='3.65',
        c2LateMainSha256=json.loads((OUT / 'artifacts.json').read_text())['lateMainSha256'],
    )
    result_path.write_text(json.dumps(result, indent=2) + '\n')
    if not result.get('passed'):
        raise SystemExit(mode + ' failed')
    return result


def main():
    OUT.mkdir(exist_ok=True)
    (OUT / 'results').mkdir(exist_ok=True)
    lock = json.loads((ROOT / 'packages/studio_assets/third_party/sodium_web/backend-lock.json').read_text())
    vendor = (ROOT / 'packages/studio_assets/web' / lock['appAssetPath'].lstrip('/')).read_bytes()
    preflight(lock, vendor)
    g1_only = '--g1-only' in sys.argv
    if '--skip-g1' not in sys.argv:
        artifacts = build_g1(lock)
    else:
        artifacts = json.loads((OUT / 'artifacts.json').read_text())
        assert artifacts.get('c2BinaryIsFreshBuild') and artifacts.get('lateMainSha256')
    print(json.dumps({
        'g1': True,
        'lateMainSha256': artifacts['lateMainSha256'],
        'lateMainEqualsHistoricalL01': artifacts['lateMainEqualsHistoricalL01'],
        'lateMainEqualsHistoricalL023': artifacts['lateMainEqualsHistoricalL023'],
    }, indent=2), flush=True)
    if g1_only:
        return
    summaries = []
    for mode in C6:
        result = serve_and_run(mode, lock, vendor)
        summaries.append({
            'caseId': mode,
            'passed': bool(result.get('passed')),
            'noComponentWrites': result.get('noComponentWrites'),
            'storageSnapshotUnchanged': result.get('storageSnapshotUnchanged'),
            'noAcknowledgmentAccepted': result.get('noAcknowledgmentAccepted'),
            'exceptions': result.get('exceptions'),
            'violations': result.get('violations'),
        })
    report = {
        'increment': '3.65',
        'passed': all(s['passed'] for s in summaries) and len(summaries) == len(C6),
        'combinedG1G5Complete': all(s['passed'] for s in summaries) and len(summaries) == len(C6),
        'fullA6AcceptanceComplete': False,
        'combinedAcceptanceClaimed': all(s['passed'] for s in summaries) and len(summaries) == len(C6),
        'lateMainSha256': artifacts['lateMainSha256'],
        'historicalLateHashesNotUsedAsC2Path': True,
        'summaries': summaries,
        'c6': C6,
    }
    (OUT / 'combined.json').write_text(json.dumps(report, indent=2) + '\n')
    if not report['passed']:
        raise SystemExit('combined G4/G5 failed')


if __name__ == '__main__':
    main()
