#!/usr/bin/env python3
"""Real Linux dev slice only: native codecs, Dart transactions, and Flutter UI.
Never upgrades any of the 87 full-task statuses to complete.
"""
import argparse
import datetime
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
from run_task import ROOT, run, test_count


def skipped(output):
    count = 0
    for line in output.splitlines():
        try:
            event = json.loads(line)
        except ValueError:
            continue
        count += bool(event.get('type') == 'testDone' and event.get('skipped') and not event.get('hidden'))
    return count


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--profile', choices=['linux-dev'], required=True)
    parser.add_argument('--report', type=Path, required=True)
    parser.add_argument('--native-build', type=Path, default=Path('/tmp/studio-media-native-dev'))
    args = parser.parse_args()
    args.native_build = args.native_build.absolute()
    if ROOT == args.native_build or ROOT in args.native_build.parents:
        parser.error('native build must be outside checkout (no binary delivery)')
    environment = os.environ.copy()
    flutter, dart = shutil.which('flutter'), shutil.which('dart')
    if not flutter or not dart:
        parser.error('Official pinned Flutter/Dart must be on PATH')
    directory = ROOT / 'artifacts/local-video'
    directory.mkdir(parents=True, exist_ok=True)
    fixture = directory / 'input.mp4'
    records = []
    def check(command, **options):
        record = run([str(x) for x in command], environment=environment, **options)
        records.append(record)
        print(f"exit={record['exitCode']} {' '.join(record['command'][:5])}", flush=True)
        return record['exitCode'] == 0
    ok = check(['cmake', '-S', 'native/studio_media', '-B', args.native_build, '-G', 'Ninja'])
    if ok:
        ok = check(['cmake', '--build', args.native_build])
    if ok:
        ok = check(['ctest', '--test-dir', args.native_build, '--output-on-failure'])
    ok = check(['ffmpeg', '-v', 'error', '-f', 'lavfi', '-i', 'testsrc2=size=320x180:rate=30:duration=3',
                '-vf', 'setparams=color_primaries=bt709:color_trc=bt709:colorspace=bt709:range=limited',
                '-c:v', 'libx264', '-pix_fmt', 'yuv420p', '-an', '-y', fixture]) and ok
    environment['STUDIO_MEDIA_LIBRARY'] = str(args.native_build / 'libstudio_media.so')
    environment['STUDIO_TEST_VIDEO'] = str(fixture)
    for command, options in [
        ([dart, 'format', '--output=none', '--set-exit-if-changed', 'packages', 'apps/studio_demo/lib', 'apps/image_demo/lib'], {}),
        ([flutter, 'analyze'], {}),
        ([dart, 'test', 'packages/studio_contracts/test', 'packages/studio_document/test',
          'packages/studio_store/test', 'packages/studio_sdk/test', '--reporter=json'], {}),
        ([flutter, 'test', 'test', '--reporter=json'], {'cwd': ROOT / 'packages/studio_editor_ui'}),
        ([sys.executable, '-m', 'unittest', 'discover', '-s', 'tools/tests', '-v'], {}),
        (['sha256sum', '--quiet', '-c', 'SHA256SUMS'], {'cwd': ROOT / 'docs/studio'}),
        ([flutter, '--version', '--machine'], {}),
        (['pkg-config', '--modversion', 'libavformat', 'libavcodec', 'libavutil', 'libswscale', 'sqlite3'], {}),
        ([dart, 'run', 'packages/studio_media/tool/probe.dart', environment['STUDIO_MEDIA_LIBRARY'], fixture], {}),
    ]:
        ok = check(command, **options) and ok
    test_records = [r for r in records if '--reporter=json' in r['command']]
    skipped_tests = sum(skipped(r['output']) for r in test_records)
    ok = ok and skipped_tests == 0
    names = subprocess.check_output(['git', 'ls-files', '--cached', '--others', '--exclude-standard'], cwd=ROOT, text=True).splitlines()
    source_hashes = {name: hashlib.sha256((ROOT / name).read_bytes()).hexdigest() for name in sorted(names)
                     if (name.startswith(('packages/', 'native/', 'tools/')) or name in ['pubspec.yaml', 'pubspec.lock'])
                     and (ROOT / name).is_file()}
    report = {
        'profile': args.profile, 'timezone': 'Asia/Shanghai',
        'checkedAt': datetime.datetime.now(datetime.timezone(datetime.timedelta(hours=8))).isoformat(),
        'scopeStatus': 'passed' if ok else 'failed', 'fullTaskComplete': False,
        'scope': 'Synthetic silent CFR Rec709 H264 plus durable checkpoints, serial archive receipts and 50 SIGKILL save recoveries; Linux dev only',
        'testsExecuted': sum(test_count(r['output']) for r in test_records), 'skippedTests': skipped_tests,
        'nativeCTestCases': 3, 'sourceHashes': source_hashes, 'checks': records,
        'notValidated': ['all 87 full acceptance contracts', '1080p Main L4/AAC qualification', 'audio export',
                         'GPU or hardware adapters', 'full RenderGraph', 'random seek/cache/proxy', 'non-Linux platforms',
                         'physical power-loss/disk-full/non-Linux provider durability faults', 'model inference', 'paid/remote services'],
    }
    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.report.write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n')
    print(f"scope={report['scopeStatus']} tests={report['testsExecuted']} skipped={skipped_tests} fullTaskComplete=false")
    return 0 if ok else 1


if __name__ == '__main__':
    sys.exit(main())
