#!/usr/bin/env python3
"""Positive real Chrome DTLS/SCTP qualification, separate from fail-closed tests.
Exit2 means direct candidate preflight is blocked, NEVER a successful transport.
No browser flags, ICE servers, proxies, policy edits, or downloads are added.
"""
import argparse
import datetime
import hashlib
import json
import os
from pathlib import Path
import shutil
import sys
from run_task import ROOT, run, test_count
from run_local_video import skipped


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--report', type=Path, required=True)
    args = parser.parse_args()
    flutter = shutil.which('flutter')
    if not flutter:
        parser.error('Pinned Flutter SDK required on PATH')
    command = [flutter, 'test', '--platform', 'chrome',
               'test/qualification/rtc_direct_qualification.dart', '--reporter=json']
    record = run(command, cwd=ROOT / 'apps/studio_web',
                 environment=os.environ.copy(), timeout=180)
    omitted = skipped(record['output'])
    passed = record['exitCode'] == 0 and test_count(record['output']) >= 3 and omitted == 0
    blocked = not passed and 'RTC_DIRECT_CANDIDATES_UNAVAILABLE' in record['output']
    status = 'passed' if passed else ('blocked' if blocked else 'failed')
    sources = [p for p in (ROOT / 'apps/studio_web').rglob('*')
               if p.is_file() and not any(x in p.parts for x in ['build', '.dart_tool'])]
    report = {
        'schemaVersion': '1.0.0', 'scopeStatus': status,
        'checkedAt': datetime.datetime.now(datetime.timezone(datetime.timedelta(hours=8))).isoformat(),
        'timezone': 'Asia/Shanghai', 'positiveEncryptedTransportPassed': passed,
        'physicalDeviceQualification': False, 'fullTaskComplete': False,
        'skippedTests': omitted, 'checks': [record],
        'blocker': 'Direct-only host ICE candidates unavailable; no fallback attempted' if blocked else None,
        'sourceHashes': {str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(sources)},
        'notValidated': ['physical devices', 'native WebRTC bridge', 'browser worker durable reconnect outbox',
                         'mobile/background/OS-sleep clocks', 'Web blob transfer'],
    }
    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.report.write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n')
    print(f'positiveEncryptedTransport={status} actualExitCode={record["exitCode"]} skipped={omitted} physicalDevices=false')
    return 0 if passed else (2 if blocked else 1)


if __name__ == '__main__':
    sys.exit(main())
