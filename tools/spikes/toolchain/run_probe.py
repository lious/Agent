#!/usr/bin/env python3
"""Three clean Linux Flutter build/start and C++20 C-ABI probes. No FFmpeg/model."""
import argparse
import datetime
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / 'tools/acceptance'))
from run_task import run  # noqa: E402


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--profile', choices=['linux-dev'], required=True)
    parser.add_argument('--report', type=Path, required=True)
    args = parser.parse_args()
    flutter, dart = shutil.which('flutter'), shutil.which('dart')
    if not flutter or not dart:
        parser.error('flutter and dart must be on PATH')
    records = []
    success = True
    for repetition in range(1, 4):
        # Build trees are fresh each time, with no reliance on old object files.
        with tempfile.TemporaryDirectory(prefix='studio-abi-') as build:
            for cmd in [
                ['cmake', '-S', 'tools/spikes/toolchain', '-B', build, '-G', 'Ninja'],
                ['cmake', '--build', build],
                [dart, 'run', 'tools/spikes/toolchain/ffi_probe.dart', f'{build}/libstudio_probe.so'],
            ]:
                r = run(cmd)
                r['repetition'] = repetition
                records.append(r)
                if r['exitCode']:
                    success = False
                    break
        if not success:
            break
        for app in ['studio_demo', 'image_demo']:
            app_path = ROOT / 'apps' / app
            for cmd in [[flutter, 'clean'], [flutter, 'pub', 'get', '--enforce-lockfile'],
                        [flutter, 'build', 'linux', '--release']]:
                r = run(cmd, app_path)
                r.update(repetition=repetition, app=app)
                records.append(r)
                if r['exitCode']:
                    success = False
                    break
            if not success:
                break
            with tempfile.TemporaryDirectory(prefix='studio-smoke-data-') as data:
                env = dict(os.environ, STUDIO_DEMO_DATA_DIR=data, LIBGL_ALWAYS_SOFTWARE='1')
                binary = app_path / 'build/linux/x64/release/bundle' / app
                r = run(['xvfb-run', '-a', str(binary), '--smoke-test'], app_path,
                        timeout=45, environment=env)
                r.update(repetition=repetition, app=app)
                r['firstFrameObserved'] = f'STUDIO_SMOKE_OK {app} revision=0' in r['output']
                success = success and r['exitCode'] == 0 and r['firstFrameObserved']
                records.append(r)
            if not success:
                break
        if not success:
            break
    report = {
        'taskId': 'V-001', 'profile': args.profile,
        'checkedAt': datetime.datetime.now(datetime.timezone(datetime.timedelta(hours=8))).isoformat(),
        'timezone': 'Asia/Shanghai', 'scopeStatus': 'passed' if success else 'failed',
        'taskStatus': 'partial', 'fullTaskComplete': False,
        'toolchain': json.loads(subprocess.check_output([flutter, '--version', '--machine'], text=True)),
        'host': subprocess.check_output(['uname', '-srm'], text=True).strip(),
        'checks': records, 'primaryReleaseDeviceFrozen': False,
        'notValidated': ['all non-Linux platforms', 'P0 real target device', 'FFmpeg',
                         'hardware codecs/textures/audio', 'store distribution', 'model inference'],
    }
    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.report.write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n')
    print(f"V-001: Linux scoped probe {'passed' if success else 'failed'}; full task remains partial")
    return 0 if success else 1


if __name__ == '__main__':
    sys.exit(main())
