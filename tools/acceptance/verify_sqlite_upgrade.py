#!/usr/bin/env python3
"""Real old-v4/new-v6 store compatibility, not an App or physical fault test."""
import argparse
import datetime
import hashlib
import json
import os
from pathlib import Path
import subprocess
import tempfile
from urllib.parse import urljoin

ROOT = Path(__file__).resolve().parents[2]
BASE = 'dff15f2c5ecd75ac5a1da9d089f3025545b727f3'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--baseline-commit', default=BASE)
    parser.add_argument('--baseline-schema', type=int, choices=[4,5], default=4)
    parser.add_argument('--baseline-library-dir', type=Path)
    parser.add_argument('--library-dir', type=Path, required=True)
    parser.add_argument('--legacy-library', type=Path, default=Path('/lib/x86_64-linux-gnu/libsqlite3.so.0'))
    parser.add_argument('--report', type=Path, required=True)
    args = parser.parse_args()
    checks = []
    with tempfile.TemporaryDirectory(prefix='sqlite-real-upgrade-') as scratch:
        scratch = Path(scratch)
        names = subprocess.check_output(['git', 'ls-tree', '-r', '--name-only', args.baseline_commit, 'packages/studio_store/lib'], cwd=ROOT, text=True).splitlines()
        for name in names:
            target = scratch / name
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(subprocess.check_output(['git', 'show', f'{args.baseline_commit}:{name}'], cwd=ROOT))
        config_path = ROOT / '.dart_tool/package_config.json'
        config = json.loads(config_path.read_text())
        for package in config['packages']:
            package['rootUri'] = urljoin(config_path.as_uri(), package['rootUri'])
            if package['name'] == 'studio_store':
                package['rootUri'] = (scratch / 'packages/studio_store').as_uri() + '/'
        (scratch / 'legacy-config.json').write_text(json.dumps(config))
        legacy_lib = scratch / 'legacy-library'
        legacy_lib.mkdir()
        (legacy_lib / 'libsqlite3.so').symlink_to(args.legacy_library.resolve(strict=True))
        source = '''import 'dart:convert';
import 'package:studio_store/studio_store.dart';
import 'package:studio_document/studio_document.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:studio_harness/studio_harness.dart';
import 'package:studio_harness/testing_fixtures.dart';
void main(List<String> args) {
 final ns=Namespace('studio','local','upgrade');
 final repo=DocumentRepository.open(args[0],ns);
 if(args[1]=='old') {
 repo.create(ProjectDocument.empty(namespace:ns,projectId:'p',title:'actual-v4-store'));
 final session=SessionRef(namespace:ns,id:'session'),plan=HarnessPlan(planFixture(ns));
 repo.registerHarnessPlan(session,'p',plan,coordinatorBoot:'old',nowMs:0);
 repo.claimHarnessTask(session,plan.hash,'a',deviceFixture('legacy',{'compute.digest'}),PlacementRequirement(),coordinatorBoot:'old',nowMs:0,leaseMs:500);
 }
 if(repo.read('p')!.title!='actual-v4-store') throw StateError('Title lost');
 repo.close();final db=sqlite3.open(args[0]);
 final result={'version':db.select('SELECT sqlite_version() AS v').single['v'],'schema':db.userVersion,'integrity':db.select('PRAGMA integrity_check').single.values.single};
 if(args[1]=='new') { final deadline=db.select('SELECT attempt_deadline_ms FROM harness_steps').single['attempt_deadline_ms']; if(deadline!=int.parse(args[2])) throw StateError('Legacy lease deadline lost'); result['legacyLeaseDeadlineMs']=deadline; }
 db.dispose();print(jsonEncode(result));
}'''
        (scratch / 'fixture.dart').write_text(source)
        database = scratch / 'project.sqlite'
        for stage, config_file, library in [('old', scratch / 'legacy-config.json', args.baseline_library_dir or legacy_lib), ('new', config_path, args.library_dir)]:
            env = dict(os.environ, LD_LIBRARY_PATH=str(library.resolve()))
            command = ['dart', f'--packages={config_file}', str(scratch / 'fixture.dart'), str(database), stage, str(500 if args.baseline_schema == 4 else 1000)]
            result = subprocess.run(command, env=env, text=True, capture_output=True, cwd=ROOT)
            if result.returncode != 0:
                raise RuntimeError(f'{stage} fixture failed: {result.stderr}')
            value = json.loads(result.stdout)
            assert value['schema'] == (args.baseline_schema if stage == 'old' else 6)
            assert value['integrity'] == 'ok'
            checks.append({'stage': stage, 'command': command, 'actual': value})
        # The current code must NOT quietly accept the old system runtime.
        env = dict(os.environ, LD_LIBRARY_PATH=str(legacy_lib))
        result = subprocess.run(['dart', f'--packages={config_path}', str(scratch / 'fixture.dart'), str(database), 'new'], env=env, text=True, capture_output=True, cwd=ROOT)
        assert result.returncode != 0 and 'SQLITE_RUNTIME_NOT_APPROVED' in result.stderr
        checks.append({'stage': 'old-runtime-rejected-by-default', 'exitCode': result.returncode, 'expectedError': 'SQLITE_RUNTIME_NOT_APPROVED'})
    report = {'scopeStatus': 'passed', 'scope': f'Linux actual historical v{args.baseline_schema} store -> current v6 on approved SQLite; library-level only',
              'baselineCommit': args.baseline_commit, 'checkedAt': datetime.datetime.now(datetime.timezone(datetime.timedelta(hours=8))).isoformat(),
              'checks': checks, 'librarySha256': hashlib.sha256((args.library_dir / 'libsqlite3.so.0').read_bytes()).hexdigest(),
              'fullTaskComplete': False, 'platformQualification': False}
    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.report.write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n')
    print(json.dumps(report, ensure_ascii=False, indent=2))


if __name__ == '__main__':
    main()
