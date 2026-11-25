#!/usr/bin/env python3
"""Reproducible foundation checks, not a declaration that the whole task is done."""
import argparse
import datetime
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
MEDIA_TASKS = {'I-004','I-005','I-006','I-011','I-012','I-013','I-014','I-015','I-021','I-024','I-025','V-002','V-005'}
TESTS = {
    'I-001': ['packages/studio_contracts/test', 'packages/studio_sdk/test'],
    'I-002': ['packages/studio_document/test'],
    'I-003': ['packages/studio_store/test'],
}


def run(command, cwd=ROOT, timeout=240, environment=None):
    try:
        process = subprocess.run(command, cwd=cwd, env=environment, text=True,
                                 stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=timeout)
        code, output = process.returncode, process.stdout
    except subprocess.TimeoutExpired as error:
        code = 124
        output = error.stdout or b''
        if isinstance(output, bytes):
            output = output.decode('utf-8', errors='replace')
        output += '\nTIMEOUT: command exceeded scoped verification deadline\n'
    except OSError as error:
        code, output = 127, str(error)
    return {'command': command, 'cwd': str(Path(cwd).relative_to(ROOT)) or '.',
            'exitCode': code, 'output': output,
            'outputSha256': hashlib.sha256(output.encode()).hexdigest()}


def test_count(output):
    count = 0
    for line in output.splitlines():
        try:
            event = json.loads(line)
        except ValueError:
            continue
        if event.get('type') == 'testDone' and not event.get('hidden', False) and not event.get('skipped', False):
            count += 1
    return count


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('task', choices=sorted(set(TESTS) | MEDIA_TASKS))
    parser.add_argument('--profile', choices=['linux-dev'], required=True)
    parser.add_argument('--report', type=Path, required=True)
    args = parser.parse_args()
    if args.task in MEDIA_TASKS:
        code = subprocess.call([sys.executable, str(ROOT/'tools/acceptance/run_local_video.py'), '--profile', args.profile, '--report', str(args.report)], cwd=ROOT)
        if args.report.exists():
            value=json.loads(args.report.read_text());value['taskId']=args.task;value['taskStatus']='partial';args.report.write_text(json.dumps(value,ensure_ascii=False,indent=2)+'\n')
        return code
    flutter = shutil.which('flutter')
    dart = shutil.which('dart')
    if not flutter or not dart:
        parser.error('flutter and dart must be on PATH; see docs/implementation/README.md')
    records = []
    if args.task == 'I-001':
        records.append(run([dart, 'format', '--output=none', '--set-exit-if-changed',
                            'packages', 'apps/studio_demo/lib', 'apps/image_demo/lib',
                            'tools/spikes/toolchain/ffi_probe.dart']))
        records.append(run([flutter, 'analyze']))
    records.append(run([dart, 'test', *TESTS[args.task], '--reporter=json']))
    if args.task == 'I-001':
        records.append(run([flutter, 'test', 'test', '--reporter=json'], ROOT / 'packages/studio_editor_ui'))
    success = all(r['exitCode'] == 0 for r in records)
    report = {
        'taskId': args.task, 'profile': args.profile,
        'checkedAt': datetime.datetime.now(datetime.timezone(datetime.timedelta(hours=8))).isoformat(),
        'timezone': 'Asia/Shanghai', 'scopeStatus': 'passed' if success else 'failed',
        'fullTaskComplete': False, 'taskStatus': 'partial',
        'testsExecuted': sum(test_count(r['output']) for r in records),
        'toolchain': json.loads(subprocess.check_output([flutter, '--version', '--machine'], text=True)),
        'checks': records,
        'notValidated': ['iOS', 'iPadOS', 'Android', 'macOS', 'Windows', 'Web',
                         'production media pipeline', 'model inference', 'paid or remote APIs'],
    }
    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.report.write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n')
    print(f"{args.task}: scope={report['scopeStatus']} tests={report['testsExecuted']} fullTaskComplete=false")
    return 0 if success else 1


if __name__ == '__main__':
    sys.exit(main())
