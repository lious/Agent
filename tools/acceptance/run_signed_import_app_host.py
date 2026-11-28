#!/usr/bin/env python3
"""Independent actual Flutter App-host CSP gate, NOT source-adapter or UI consent acceptance.
Fresh Chrome profiles, loopback HTTP only. No paid APIs, deploy or old runtime suites.
"""
import argparse
import base64
import hashlib
import http.server
import json
import os
from pathlib import Path
import secrets
import signal
import subprocess
import tempfile
import threading
from urllib.parse import unquote, urlsplit

ROOT = Path(__file__).resolve().parents[2]
HELPERS = ROOT / 'tools/acceptance/signed_import_app_host'
APP = ROOT / 'apps/studio_web'
LOCK = json.loads((ROOT / 'packages/studio_assets/third_party/sodium_web/backend-lock.json').read_text())


def sri(data):
    return 'sha384-' + base64.b64encode(hashlib.sha384(data).digest()).decode()


def qualify(args):
    args.output.mkdir(parents=True, exist_ok=True)
    output = args.output.resolve()
    web = output / 'web-host'
    vendor = (ROOT / 'packages/studio_assets/web' / LOCK['appAssetPath'].lstrip('/')).read_bytes()
    # Hashes BEFORE any vendor code can execute, never a post-execution check.
    assert hashlib.sha256(vendor).hexdigest() == LOCK['sourceSha256']
    assert len(vendor) == LOCK['sourceBytes'] and sri(vendor) == LOCK['sri']
    subprocess.run([args.flutter, 'build', 'web', '--release', '--no-web-resources-cdn',
                    '--output=' + str(web)], cwd=APP, check=True)
    flutter_bootstrap = (web / 'flutter_bootstrap.js').read_bytes()
    assert b'"useLocalCanvasKit":true' in flutter_bootstrap
    assert b'serviceWorkerSettings' not in (APP / 'web/flutter_bootstrap.js').read_bytes()
    assert b'<base' not in (web / 'index.html').read_bytes()
    signed_bootstrap = (ROOT / 'packages/studio_assets/web/signed_import_bootstrap.js').read_bytes()
    probe = (HELPERS / 'host_probe.js').read_bytes()
    static = {'/host_probe.js': probe, '/signed_import_bootstrap.js': signed_bootstrap,
              '/flutter_bootstrap.js': flutter_bootstrap, LOCK['appAssetPath']: vendor}
    modes = ['normal', 'sri-tamper', 'csp-vendor-block', 'missing-vendor', 'wrong-style-nonce', 'missing-style-nonce']
    reports, used_nonces = [], []
    for mode in modes:
        nonce = secrets.token_urlsafe(16)
        assert len(base64.urlsafe_b64decode(nonce + '==')) >= 16
        used_nonces.append(nonce)
        served_nonce = secrets.token_urlsafe(16) if mode == 'wrong-style-nonce' else nonce
        # Start with the ACTUAL compiled App index, not a substitute App/main.
        index = (web / 'index.html').read_text()
        meta = '' if mode == 'missing-style-nonce' else '<meta name="app-style-nonce" content="' + served_nonce + '">'
        index = index.replace('</head>', meta + '</head>')
        scripts = ''.join('<script src="' + path + '" integrity="' + sri(static[path]) + '"></script>'
                          for path in ['/host_probe.js', '/signed_import_bootstrap.js', '/flutter_bootstrap.js'])
        index = index.replace('<script src="/flutter_bootstrap.js" async></script>', scripts)
        assert scripts in index
        policy = ("default-src 'none'; script-src 'self' '" + LOCK['sri'] + "' 'wasm-unsafe-eval'; "
                  "connect-src 'self'; object-src 'none'; base-uri 'none'; font-src 'self'; "
                  "img-src 'self'; style-src 'self' 'nonce-" + nonce + "'; worker-src 'none'; "
                  "form-action 'none'; frame-ancestors 'none'")
        requests = []
        seen_hashes = {}
        class Handler(http.server.BaseHTTPRequestHandler):
            def do_GET(self):
                path = unquote(urlsplit(self.path).path)
                requests.append(path)
                if path == '/':
                    body, mime = index.encode(), 'text/html'
                elif mode == 'missing-vendor' and path == LOCK['appAssetPath']:
                    self.send_response(404); self.end_headers(); return
                elif path in static:
                    body, mime = static[path], 'text/javascript'
                    if mode == 'sri-tamper' and path == LOCK['appAssetPath']:
                        body += b'\nwindow.vendorTamperExecuted=true;\n'
                else:
                    file = (web / path.lstrip('/')).resolve()
                    if not file.is_relative_to(web) or not file.is_file():
                        self.send_response(404); self.end_headers(); return
                    body = file.read_bytes()
                    mime = 'application/wasm' if file.suffix == '.wasm' else 'text/javascript' if file.suffix == '.js' else 'application/octet-stream'
                seen_hashes[path] = hashlib.sha256(body).hexdigest()
                self.send_response(200)
                self.send_header('Content-Type', mime)
                self.send_header('Content-Security-Policy', policy)
                if mode == 'csp-vendor-block':
                    # Intersect with another policy excluding ONLY vendor JS.
                    # Normal W2 policy stays unchanged; no disabled web security.
                    origin = f'http://127.0.0.1:{self.server.server_port}'
                    allowed = ['/host_probe.js', '/signed_import_bootstrap.js', '/flutter_bootstrap.js',
                               '/main.dart.js', '/canvaskit/']
                    self.send_header('Content-Security-Policy', "script-src 'wasm-unsafe-eval' " + ' '.join(origin + p for p in allowed))
                self.send_header('Cache-Control', 'no-store')
                self.end_headers()
                try:
                    self.wfile.write(body)
                except (BrokenPipeError, ConnectionResetError):
                    pass  # Expected when a terminal negative profile closes.
            def log_message(self, *unused):
                pass
        server = http.server.ThreadingHTTPServer(('127.0.0.1', 0), Handler)
        threading.Thread(target=server.serve_forever, daemon=True).start()
        try:
            with tempfile.TemporaryDirectory(prefix='signed-import-app-host-', ignore_cleanup_errors=True) as profile:
                with (output / (mode + '.chrome.log')).open('w') as errors:
                    chrome = subprocess.Popen([args.chrome, '--headless=new', '--no-sandbox',
                        '--remote-debugging-port=0', '--user-data-dir=' + profile,
                        '--no-first-run', '--no-default-browser-check', '--disable-background-networking',
                        '--disable-sync', '--disable-component-update', 'about:blank'],
                        stdout=subprocess.DEVNULL, stderr=errors, start_new_session=True)
                    try:
                        subprocess.run(['node', str(HELPERS / 'browser_probe.cjs'),
                            str(Path(profile) / 'DevToolsActivePort'),
                            f'http://127.0.0.1:{server.server_port}/?mode={mode}',
                            str(output / (mode + '.json'))], check=True, timeout=40)
                    finally:
                        os.killpg(chrome.pid, signal.SIGTERM)
                        chrome.wait(timeout=10)
        finally:
            server.shutdown(); server.server_close()
        result = json.loads((output / (mode + '.json')).read_text())
        origin = f'http://127.0.0.1:{server.server_port}'
        remote = [r for r in result['requests'] if not r['url'].startswith(origin + '/')]
        violations = result['violations']
        if mode == 'normal':
            passed = result['firstFrame'] and result['views'] == 1 and result['backendState'] == 'ready' and not violations and not result['errors'] and not result['failures'] and not result['exceptions'] and result['nonceStyles'] and all(result['nonceStyles'])
        elif mode in ['sri-tamper', 'missing-vendor']:
            passed = result['firstFrame'] and result['backendState'] == 'failed' and not violations
        elif mode == 'csp-vendor-block':
            passed = result['firstFrame'] and result['backendState'] == 'failed' and any(LOCK['appAssetPath'] in v['blocked'] for v in violations)
        else:
            passed = any('style-src' in v['directive'] for v in violations)
        passed = bool(passed and not remote and not result['registrations'] and not result['baseElements'] and not result['vendorTamperExecuted'] and result['secureContext'])
        result.update(passed=passed, csp=policy, remoteRequests=remote, serverRequests=requests,
                      servedAssetSha256=seen_hashes, styleNonceBytes=16)
        reports.append(result)
        (output / (mode + '.json')).write_text(json.dumps(result, indent=2) + '\n')
        print(mode, 'PASS' if passed else 'FAIL', flush=True)
        if not passed:
            break  # Never skip/fake-success around a failed host gate.
    summary = dict(kind='actualAppHostCspQualificationOnly', passed=len(reports) == len(modes) and all(r['passed'] for r in reports),
        base='5a02ca7ec6d8d5dbfd8bd1f530c3ca3f9872e922',
        flutter=json.loads(subprocess.check_output([args.flutter, '--version', '--machine'], text=True)),
        chrome=subprocess.check_output([args.chrome, '--version'], text=True).strip(),
        mode='Flutter release Dart-to-JS / main-realm CanvasKit / --no-web-resources-cdn',
        compiledMainSha256=hashlib.sha256((web / 'main.dart.js').read_bytes()).hexdigest(),
        appBootstrapSha256=hashlib.sha256(flutter_bootstrap).hexdigest(),
        sourceBootstrapSha256=hashlib.sha256((APP / 'web/flutter_bootstrap.js').read_bytes()).hexdigest(),
        uniqueStyleNonces=len(set(used_nonces)), vendorSha256=LOCK['sourceSha256'], sri=LOCK['sri'],
        sourceAdaptersQualified=False, selectionPreviewConsentImplemented=False, reports=reports)
    (output / 'summary.json').write_text(json.dumps(summary, indent=2) + '\n')
    return 0 if summary['passed'] else 1


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--flutter', default='/workspace/toolchains/flutter/bin/flutter')
    parser.add_argument('--chrome', default='/usr/bin/google-chrome')
    parser.add_argument('--output', type=Path, default=Path('/workspace/signed-import-app-host-350'))
    raise SystemExit(qualify(parser.parse_args()))
