#!/usr/bin/env python3
"""Increment 3.63 official N01-N02 profile qualification. Does not requalify NG0-NG3."""
import hashlib, json, os, re, shutil, subprocess, sys, tempfile, time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = Path('/workspace/skill-import-app-363')
FLUTTER = Path('/workspace/toolchains/flutter/bin/flutter')
SQLITE = '/workspace/toolchains/sqlite-3.54.1'
CASES = [
    'N01-enter', 'N01-space', 'N01-semantics',
    'N02-preview-navigation', 'N02-preview-dispose',
    'N02-read-navigation', 'N02-read-dispose',
]
# flutter-test / dart-tooling endpoints inherited on this box, never App import.
HARNESS_REMOTE = {
    ('10.0.0.2', '53'),           # resolv.conf nameserver
    ('169.254.169.254', '80'),    # Flutter tool metadata probe
    ('198.18.0.1', '443'),        # Flutter/Dart tooling via inherited egress
}

def sha256(path):
    with open(path, 'rb') as f:
        return hashlib.file_digest(f, 'sha256').hexdigest()

def line_time(line):
    m = re.match(r'^(\d+\.\d+)\s', line)
    return float(m.group(1)) if m else None

def inet_target(line):
    ip = re.search(r'inet_addr\("([^"]+)"\)', line)
    port = re.search(r'htons\((\d+)\)', line)
    if ip and port:
        return ip.group(1), port.group(1)
    return None

def analyze(text, protected, baseline, end, pid_of_file):
    endpoints, harness, unexpected, writes, app_remote = set(), [], [], [], []
    app_pids = set()
    # First pass: pids that touch the protected sqlite
    for fname, chunk in pid_of_file.items():
        if protected in chunk and 'app.sqlite' in chunk:
            m = re.search(r'trace\.(\d+)$', fname)
            if m:
                app_pids.add(m.group(1))
    for fname, chunk in pid_of_file.items():
        pid = re.search(r'trace\.(\d+)$', fname)
        pid = pid.group(1) if pid else fname
        for line in chunk.splitlines():
            if ('connect(' in line or 'bind(' in line):
                if 'AF_UNIX' in line or 'sun_path=' in line:
                    m = re.search(r'\{sa_family=AF_UNIX[^}]*\}', line)
                    endpoints.add(m.group(0) if m else 'AF_UNIX')
                elif 'AF_INET' in line or 'AF_INET6' in line:
                    if re.search(r'127\.0\.0\.1|::1', line):
                        endpoints.add('loopback')
                    else:
                        tgt = inet_target(line)
                        if tgt in HARNESS_REMOTE and pid not in app_pids:
                            harness.append({'pid': pid, 'line': line.strip(), 'target': list(tgt)})
                            endpoints.add('harness:' + tgt[0] + ':' + tgt[1])
                        elif pid in app_pids:
                            app_remote.append(line.strip())
                        else:
                            unexpected.append({'pid': pid, 'line': line.strip(), 'target': list(tgt) if tgt else None})
            # protected writes inside the observation window
            ts = line_time(line)
            if protected not in line:
                continue
            if '-shm' in line:
                continue
            if ts is None or baseline is None or end is None:
                continue
            if not (baseline < ts <= end):
                continue
            if 'readlink(' in line:
                continue
            if any(tok in line for tok in (
                'openat(', 'creat(', 'mkdir(', 'rename(', 'unlink(',
                'write(', 'pwrite', 'truncate(', 'chmod(', 'symlink(', 'linkat(',
            )):
                if 'openat(' in line and 'O_RDONLY' in line and 'O_CREAT' not in line:
                    continue
                writes.append(line.strip())
    return {
        'endpoints': sorted(endpoints),
        'harnessRemote': harness[:40],
        'unexpectedRemote': unexpected[:40],
        'appRemote': app_remote[:40],
        'protectedWritesInWindow': writes[:40],
        'appPids': sorted(app_pids),
    }

def start_xvfb():
    proc = subprocess.Popen(
        ['Xvfb', '-displayfd', '1', '-screen', '0', '1920x1200x24', '-nolisten', 'tcp'],
        stdout=subprocess.PIPE, text=True, stderr=subprocess.DEVNULL,
    )
    number = proc.stdout.readline().strip()
    if not number:
        proc.terminate()
        raise SystemExit('Xvfb failed')
    return proc, ':' + number

def stop_xvfb(proc):
    proc.terminate()
    try:
        proc.wait(timeout=10)
    except subprocess.TimeoutExpired:
        proc.kill()

def run_case(case, lock, env_base):
    xvfb, display = start_xvfb()
    work = Path(tempfile.mkdtemp(prefix=f'skill-native-363-{case}-'))
    app = work / 'app'
    pack = work / 'pack' / 'public-pack.json'
    result = OUT / 'results' / f'{case}.json'
    traces = OUT / 'traces' / case
    app.mkdir(); pack.parent.mkdir()
    result.parent.mkdir(parents=True, exist_ok=True)
    if traces.exists():
        shutil.rmtree(traces)
    traces.mkdir(parents=True)
    env = dict(env_base)
    env.update({
        'DISPLAY': display,
        'GTK_USE_PORTAL': '0',
        'XDG_CONFIG_HOME': str(work / 'config'),
        'XDG_DATA_HOME': str(work / 'data'),
        'XDG_CACHE_HOME': str(work / 'cache'),
        'STUDIO_NATIVE_CASE': case,
        'STUDIO_NATIVE_WORKSPACE': str(app),
        'STUDIO_NATIVE_PACK': str(pack),
        'STUDIO_NATIVE_RESULT': str(result),
        'STUDIO_NATIVE_GTK_HELPER': str(ROOT / 'tools/acceptance/skill_source/gtk_choose.py'),
        'LD_LIBRARY_PATH': SQLITE + (':' + env['LD_LIBRARY_PATH'] if env.get('LD_LIBRARY_PATH') else ''),
    })
    cmd = [
        '/usr/bin/strace', '-ff', '-ttt', '-yy', '-e', 'trace=network,file',
        '-o', str(traces / 'trace'),
        str(FLUTTER), 'test',
        'integration_test/skill_import_app_native_test.dart',
        '-d', 'linux', '--no-pub',
        '--dart-define=STUDIO_SIGNED_IMPORT_SODIUM_PATH=' + lock['devBinary'],
        '--dart-define=STUDIO_SIGNED_IMPORT_SODIUM_SHA256=' + lock['devBinarySha256'],
    ]
    print('+', case, 'display', display, flush=True)
    try:
        proc = subprocess.run(
            cmd, cwd=ROOT / 'apps/studio_demo', env=env,
            text=True, capture_output=True, timeout=240,
        )
    finally:
        stop_xvfb(xvfb)
    (OUT / 'logs').mkdir(parents=True, exist_ok=True)
    (OUT / 'logs' / f'{case}.log').write_text(proc.stdout + '\n--- stderr ---\n' + proc.stderr)
    pid_of_file = {}
    text = ''
    files = list(traces.glob('trace*'))
    for p in files:
        chunk = p.read_text(errors='replace')
        pid_of_file[p.name] = chunk
        text += chunk
    case_result = json.loads(result.read_text()) if result.exists() else {}
    analysis = analyze(
        text, str(app),
        case_result.get('baselineUnix'),
        case_result.get('observationEndUnix'),
        pid_of_file,
    )
    loss = ('detach: ' in text) or ('??? ' in text and 'exited' not in text)
    passed = (
        proc.returncode == 0
        and case_result.get('passed') is True
        and not analysis['unexpectedRemote']
        and not analysis['appRemote']
        and not analysis['protectedWritesInWindow']
        and not loss
        and bool(files)
        and case_result.get('baselineUnix') is not None
        and case_result.get('observationEndUnix') is not None
    )
    summary = {
        'case': case,
        'passed': passed,
        'returncode': proc.returncode,
        'result': case_result,
        'traceFiles': len(files),
        'traceBytes': sum(p.stat().st_size for p in files),
        'traceDataLoss': loss,
        'workspace': str(app),
        **analysis,
    }
    shutil.rmtree(work, ignore_errors=True)
    return summary, proc.stdout, proc.stderr

def main():
    OUT.mkdir(exist_ok=True)
    lock = json.loads((ROOT / 'packages/studio_assets/third_party/sodium/backend-lock.json').read_text())
    summaries = []
    failed = False
    for case in CASES:
        summary, stdout, stderr = run_case(case, lock, os.environ)
        summaries.append(summary)
        print(json.dumps({k: summary[k] for k in ('case', 'passed', 'returncode')}, indent=2), flush=True)
        if not summary['passed']:
            failed = True
            sys.stderr.write((stderr or stdout)[-6000:] + '\n')
    bundle = ROOT / 'apps/studio_demo/build/linux/x64/debug/bundle'
    debug = {'note': 'debug integration artifacts, not a 3.62 release-artifact requalification'}
    if bundle.exists():
        exe = bundle / 'studio_demo'
        flutter_so = bundle / 'lib' / 'libflutter_linux_gtk.so'
        app_so = bundle / 'lib' / 'libapp.so'
        debug.update({
            'executableSha256': sha256(exe) if exe.exists() else None,
            'flutterEngineSha256': sha256(flutter_so) if flutter_so.exists() else None,
            'appSha256': sha256(app_so) if app_so.exists() else None,
            'bundleFiles': sorted(str(p.relative_to(bundle)) for p in bundle.rglob('*') if p.is_file())[:80],
        })
    report = {
        'increment': '3.63',
        'passed': not failed and len(summaries) == len(CASES),
        'qualifiedNativeRows': [s['case'] for s in summaries if s['passed']],
        'summaries': summaries,
        'debugIntegration': debug,
        'strace': {'tool': '/usr/bin/strace', 'flags': ['-ff', '-ttt', '-yy', '-e', 'trace=network,file']},
        'harnessRemoteAllowlist': [list(x) for x in sorted(HARNESS_REMOTE)],
        'combinedAcceptanceClaimed': False,
        'fullA6AcceptanceComplete': False,
    }
    (OUT / 'profiles.json').write_text(json.dumps(report, indent=2) + '\n')
    if failed or len(summaries) != len(CASES):
        raise SystemExit('native profile qualification failed')

if __name__ == '__main__':
    main()
