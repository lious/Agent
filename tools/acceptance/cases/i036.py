#!/usr/bin/env python3
"""Selected I-036 CharacterPack/Voice/Rights library checks. Does not declare the task complete."""
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
    commands = [
        (['dart', 'analyze', 'packages/studio_assets'], ROOT, 'analyzer'),
        (['dart', 'test',
          'packages/studio_assets/test/assets/character_versions/i036_character_pack_library_test.dart',
          '--reporter=json'], ROOT, 'character-library'),
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
        'taskId': 'I-036',
        'profile': args.profile,
        'scopeStatus': 'failed' if failed else 'passed',
        'fullTaskComplete': False,
        'taskStatus': 'partial',
        'checks': records,
        'notValidated': [
            '@ mention search and CharacterPromptInjector',
            'Project.Character materialize / appearanceRef attach',
            'offline lease / online realPerson cloud rights check',
            'library GC of unreferenced versions',
            'voice cloning (I-049 / I-050)',
            'LoRA training or weight download',
            'craft_fts on this frozen SQLite build (no SQLITE_ENABLE_FTS5)',
            'paid or remote APIs',
        ],
    }
    if args.report:
        args.report.parent.mkdir(parents=True, exist_ok=True)
        args.report.write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n')
    print('I-036 selected character library acceptance: scope=%s fullTaskComplete=false' % report['scopeStatus'])
    return 1 if failed else 0


if __name__ == '__main__':
    sys.exit(main())
