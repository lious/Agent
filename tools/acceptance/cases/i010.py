#!/usr/bin/env python3
"""Selected I-010 sidecar official-acceptance checks. Does not declare the task complete."""
import argparse
import json
import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--profile', default='linux-dev')
    parser.add_argument('--report', type=Path)
    args = parser.parse_args()
    env = os.environ.copy()
    env['PATH'] = '/workspace/toolchains/flutter/bin:' + env.get('PATH', '')
    env['LD_LIBRARY_PATH'] = '/workspace/toolchains/sqlite-3.54.1' + (
        (':' + env['LD_LIBRARY_PATH']) if env.get('LD_LIBRARY_PATH') else ''
    )
    env.setdefault('STUDIO_MEDIA_LIBRARY', '/workspace/agent-media-native-peer/libstudio_media.so')
    commands = [
        (['dart', 'test',
          'packages/studio_document/test/captions/formats/official_sidecar_acceptance_test.dart',
          'packages/studio_document/test/captions/formats/font_coverage_fallback_test.dart',
          'packages/studio_document/test/captions/formats/ass_export_font_policy_test.dart',
          'packages/studio_document/test/caption_test.dart',
          'packages/studio_store/test/caption_transactions_test.dart',
          'packages/studio_sdk/test/caption_official_sidecar_path_test.dart',
          'packages/studio_sdk/test/caption_font_coverage_test.dart',
          'packages/studio_sdk/test/caption_ass_export_test.dart',
          '--reporter=json'], ROOT, 'document-sdk'),
        (['flutter', 'test',
          'test/caption_official_sidecar_path_ui_test.dart',
          'test/caption_font_coverage_ui_test.dart',
          'test/caption_ass_export_ui_test.dart',
          'test/caption_ui_test.dart',
          '--reporter=json'], ROOT / 'packages/studio_editor_ui', 'ui'),
    ]
    records = []
    failed = False
    for command, cwd, name in commands:
        proc = subprocess.run(command, cwd=cwd, env=env, text=True,
                              stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        records.append({'name': name, 'command': command, 'exitCode': proc.returncode})
        if proc.returncode:
            failed = True
            sys.stderr.write(proc.stdout[-4000:])
    report = {
        'taskId': 'I-010',
        'profile': args.profile,
        'scopeStatus': 'failed' if failed else 'passed',
        'fullTaskComplete': False,
        'taskStatus': 'partial',
        'checks': records,
        'notValidated': [
            'source-interval crop',
            'MP4 or preview text burn-in',
            'deterministic font shaping',
            'lossless arbitrary ASS effects',
            'I-005 complete invert/section-3 matrix',
        ],
    }
    if args.report:
        args.report.parent.mkdir(parents=True, exist_ok=True)
        args.report.write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n')
    print('I-010 selected official sidecar acceptance: scope=%s fullTaskComplete=false' % report['scopeStatus'])
    return 1 if failed else 0


if __name__ == '__main__':
    sys.exit(main())
