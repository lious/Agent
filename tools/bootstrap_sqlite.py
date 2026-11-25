#!/usr/bin/env python3
"""Build isolated official SQLite 3.54.1 for Linux tests; never replaces system SQLite.
Published source hash: https://sqlite.org/changes.html#version_3_54_1
WAL reset fix: https://sqlite.org/wal.html#the_wal_reset_bug
"""
import argparse
import hashlib
import io
import json
from pathlib import Path
import platform
import subprocess
import urllib.request
import zipfile

VERSION = '3.54.1'
SOURCE_ID = '2026-10-16 14:45:20 555e07ef33f69a0957d24d8e555b702464a131d6f1607f4c3c1e4551e8e6ca76'
URL = 'https://sqlite.org/2026/sqlite-amalgamation-3540100.zip'
SHA3 = 'e2b869d3003b33c942b7dd7063604fbc53553e1b66609570df39b9b7b558ee81'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--directory', type=Path, required=True)
    args = parser.parse_args()
    if platform.system() != 'Linux':
        parser.error('Linux source build only; other platform binaries NOT qualified')
    root = args.directory.resolve()
    checkout = Path(__file__).resolve().parents[1]
    if root == checkout or checkout in root.parents:
        parser.error('SDK build must stay outside source checkout')
    with urllib.request.urlopen(URL, timeout=60) as response:
        archive = response.read(6_000_001)
    if len(archive) > 6_000_000:
        raise ValueError('Unexpected source archive size')
    with zipfile.ZipFile(io.BytesIO(archive)) as archive_file:
        member = archive_file.getinfo('sqlite-amalgamation-3540100/sqlite3.c')
        if member.file_size > 15_000_000:
            raise ValueError('Unexpected uncompressed source size')
        source = archive_file.read(member)
    if hashlib.sha3_256(source).hexdigest() != SHA3:
        raise ValueError('Official source SHA3-256 mismatch: refusing to compile')
    root.mkdir(parents=True, exist_ok=True)
    (root / 'sqlite3.c').write_bytes(source)
    command = ['cc', '-O2', '-fPIC', '-shared', '-DSQLITE_THREADSAFE=1',
               '-DSQLITE_DEFAULT_FOREIGN_KEYS=1', '-DSQLITE_DQS=0', str(root / 'sqlite3.c'),
               '-Wl,-soname,libsqlite3.so.0', '-lpthread', '-ldl', '-lm', '-o', str(root / 'libsqlite3.so.0-stage')]
    subprocess.run(command, check=True)
    (root / 'libsqlite3.so.0-stage').replace(root / 'libsqlite3.so.0')
    link = root / 'libsqlite3.so'
    if link.is_symlink():
        link.unlink()
    link.symlink_to('libsqlite3.so.0')
    provenance = {'version': VERSION, 'sourceId': SOURCE_ID, 'officialUrl': URL,
                  'sourceSha3_256': SHA3, 'librarySha256': hashlib.sha256((root / 'libsqlite3.so.0').read_bytes()).hexdigest(),
                  'compiler': subprocess.check_output(['cc', '--version'], text=True), 'command': command,
                  'systemSQLiteReplaced': False, 'allPlatformQualification': False}
    (root / 'provenance.json').write_text(json.dumps(provenance, indent=2) + '\n')
    print(json.dumps(provenance, indent=2))


if __name__ == '__main__':
    main()
