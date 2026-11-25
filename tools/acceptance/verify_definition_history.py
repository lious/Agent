#!/usr/bin/env python3
"""Actual old libraries -> unchanged current schema9, plus isolated crash barrier.
Not an App test; no database outside owned temporary fixtures is opened.
"""
import argparse
import datetime
import hashlib
import json
import os
from pathlib import Path
import select
import shutil
import subprocess
import tempfile
from urllib.parse import urljoin

ROOT = Path(__file__).resolve().parents[2]
BASE = '06a254506c7eae2e585e363978eede4cd40cf851'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--report', type=Path, required=True)
    args = parser.parse_args()
    checks = []
    with tempfile.TemporaryDirectory(prefix='definition-compat-') as scratch:
        scratch = Path(scratch)
        config_path = ROOT / '.dart_tool/package_config.json'
        config = json.loads(config_path.read_text())
        for p in config['packages']:
            p['rootUri'] = urljoin(config_path.as_uri(), p['rootUri'])
        old_config = json.loads(json.dumps(config))
        # Both old store AND old edit algebra. Reusing the new document package
        # would conceal the actual pre-fix same-sequence-version audio history.
        for package in ['studio_store', 'studio_document']:
            folder = f'packages/{package}/lib'
            names = subprocess.check_output(['git', 'ls-tree', '-r', '--name-only', BASE, folder], cwd=ROOT, text=True).splitlines()
            for name in names:
                p = scratch / 'old' / name
                p.parent.mkdir(parents=True, exist_ok=True)
                p.write_bytes(subprocess.check_output(['git', 'show', f'{BASE}:{name}'], cwd=ROOT))
            next(p for p in old_config['packages'] if p['name'] == package)['rootUri'] = (scratch / 'old' / 'packages' / package).as_uri() + '/'
        (scratch / 'old-config.json').write_text(json.dumps(old_config))
        old_source = """import 'dart:convert';
import 'package:studio_store/studio_store.dart';
import 'package:studio_document/studio_document.dart';
void main(List<String> a) {
 final ns=Namespace('studio','local','compat');
 final r=DocumentRepository.open(a[0],ns);
 r.create(ProjectDocument.empty(namespace:ns,projectId:'p',title:'old'));
 final w=r.acquireWriter('p','owner',expectedEpoch:0);
 r.edit(writer:w,commandId:'legacy-gain',receiptKey:'legacy-gain',expectedRevision:BigInt.zero,operation:const SetMasterAudio(gainDb:-6));
 final p=r.read('p')!;
 if(p.toJson()['sequences'][0]['version']!='0') throw StateError('not original legacy history');
 print(jsonEncode({'actualOldStoreAndDocument':true,'revision':p.revision.toString(),'sequenceVersion':'0','gain':p.toJson()['audioBuses'][0]['gainDb']}));
 r.close();
}
"""
        (scratch / 'old.dart').write_text(old_source)

        def run(command):
            result = subprocess.run(command, cwd=ROOT, env=os.environ.copy(), text=True, capture_output=True, timeout=120)
            if result.returncode:
                raise RuntimeError(f'{command}: {result.stderr}')
            return json.loads(result.stdout)

        probe = ROOT / 'packages/studio_store/tool/definition_history_probe.dart'
        for name in ['normal', 'crash']:
            db = scratch / name
            actual = run(['dart', f'--packages={scratch / "old-config.json"}', str(scratch / 'old.dart'), str(db)])
            checks.append({'stage': f'{name}-actual-old', 'actual': actual})
        checks.append({'stage': 'unchanged-current-normal', 'actual': run(['dart', f'--packages={config_path}', str(probe), str(scratch / 'normal'), 'normal'])})

        # Fixture-only source mirror: one blocking barrier after actual semantic
        # history checks/legacy registration, before pins/head/COMMIT. Production
        # source has NO fault hook/env bypass. The exact instrumentation is recorded.
        mirror = scratch / 'mirror/packages/studio_store'
        shutil.copytree(ROOT / 'packages/studio_store/lib', mirror / 'lib')
        store = mirror / 'lib/studio_store.dart'
        source = store.read_text()
        target = '        _pinBlobs(after);'
        assert source.count(target) == 1
        barrier = r"""        fixtureIo.File('/dev/stdout').writeAsStringSync('HISTORY_VERIFIED_UNCOMMITTED\n',mode:fixtureIo.FileMode.writeOnly);
        fixtureIo.stdin.readByteSync();
"""
        source = "import 'dart:io' as fixtureIo;\n" + source
        source = source.replace(target, barrier + target)
        store.write_text(source)
        crash_config = json.loads(json.dumps(config))
        next(p for p in crash_config['packages'] if p['name'] == 'studio_store')['rootUri'] = mirror.as_uri() + '/'
        crash_config_path = scratch / 'crash-config.json'
        crash_config_path.write_text(json.dumps(crash_config))
        command = ['dart', f'--packages={crash_config_path}', str(probe), str(scratch / 'crash'), 'kill']
        proc = subprocess.Popen(command, cwd=ROOT, env=os.environ.copy(), stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        try:
            if not select.select([proc.stdout], [], [], 90)[0]:
                raise RuntimeError('crash fixture barrier timeout')
            ready = proc.stdout.readline().strip()
            if ready != 'HISTORY_VERIFIED_UNCOMMITTED':
                raise RuntimeError(f'barrier failed: {ready}: {proc.stderr.read()}')
            proc.kill()
            proc.communicate(timeout=15)
            assert proc.returncode == -9
        finally:
            if proc.poll() is None:
                proc.kill()
                proc.communicate()
        checks.append({'stage': 'actual-SIGKILL', 'exitCode': proc.returncode, 'barrier': ready,
                       'instrumentedMirrorOnly': True, 'instrumentedSourceSha256': hashlib.sha256(source.encode()).hexdigest(),
                       'instrumentation': 'dart:io fixture alias plus blocking stdout/stdin barrier before _pinBlobs(after); after real history/legacy registration; no other code changes'})
        checks.append({'stage': 'unmodified-current-crash-reopen', 'actual': run(['dart', f'--packages={config_path}', str(probe), str(scratch / 'crash'), 'recover'])})
    report = {'checkedAt': datetime.datetime.now().astimezone().isoformat(), 'timezone': 'Asia/Shanghai',
              'baselineCommit': BASE, 'scope': 'Real old studio_store AND studio_document schema9 legacy audio history; current compatibility/undo/reopen plus real SIGKILL in explicitly instrumented temp mirror; not App/platform qualification',
              'checks': checks, 'result': 'passed', 'fullTaskComplete': False}
    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.report.write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps(report, indent=2))


if __name__ == '__main__':
    main()
