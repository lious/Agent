import 'dart:io';
import 'dart:convert';

import 'package:test/test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:studio_document/studio_document.dart';
import 'package:studio_store/studio_store.dart';

void main() {
  late Directory dir;
  late DocumentRepository repo;
  late Database db;
  late WriterToken writer;
  const app = 'test';
  final ns = Namespace(app, 'local', 'imports');
  var i = 0;
  String id() => 'new-${++i}';
  setUp(() {
    dir = Directory.systemTemp.createTempSync('import-map-');
    repo = DocumentRepository.open('${dir.path}/db', ns);
    final p = ProjectDocument.empty(
      namespace: ns,
      projectId: 'current',
      title: 'current',
    );
    repo.create(p);
    repo.selectProject('current');
    writer = repo.acquireWriter('current', 'owner', expectedEpoch: 0);
    db = sqlite3.open('${dir.path}/db');
  });
  tearDown(() {
    repo.close();
    db.dispose();
    dir.deleteSync(recursive: true);
  });
  ProjectDocument source() => ProjectDocument.empty(
    namespace: ns,
    projectId: 'source',
    title: 'source',
  );
  ImportedProject adopt() => repo.createResourceFork(
    source: source(),
    activeWriter: writer,
    expectedActiveHash: repo.read('current')!.hash,
    newId: id,
  );
  test('REAL SQL late failure rolls back new project/definitions/pins/map/selection; retry and durable namespace-scoped provenance', () {
    final hash = repo.read('current')!.hash;
    db.execute(
      "CREATE TRIGGER fail_map BEFORE INSERT ON import_maps BEGIN SELECT RAISE(ABORT,'fixture');END",
    );
    expect(adopt, throwsA(isA<SqliteException>()));
    expect(db.select('SELECT * FROM project_heads').length, 1);
    expect(db.select('SELECT * FROM import_maps'), isEmpty);
    expect(repo.selectedProjectId, 'current');
    db.execute('DROP TRIGGER fail_map');
    final p = adopt().project, map = repo.importMap(repo.selectedProjectId!)!;
    expect(repo.read('current')!.hash, hash);
    expect(map['entityIds']['source'], p.projectId);
    repo.close();
    repo = DocumentRepository.open('${dir.path}/db', ns);
    expect(repo.importMap(p.projectId), map);
    final foreign = DocumentRepository.open(
      '${dir.path}/db',
      Namespace(app, 'other', 'imports'),
    );
    expect(foreign.importMap(p.projectId), isNull);
    foreign.close();
    db.execute("UPDATE import_maps SET hash='wrong'");
    expect(() => repo.importMap(p.projectId), throwsA(isA<StudioException>()));
  });
  test('REAL takeover/stale head blocks fork before registration', () {
    repo.acquireWriter('current', 'other', expectedEpoch: writer.epoch);
    expect(adopt, throwsA(isA<StudioException>()));
    expect(db.select('SELECT * FROM project_heads').length, 1);
  });
  test('REAL v8-v9 failure preserves old selected snapshot; migration retry qualifies new table/checksum', () {
    final hash = repo.read('current')!.hash;
    repo.close();
    db.execute('DROP TABLE import_maps');
    db.execute('DELETE FROM schema_migrations WHERE version=9');
    db.userVersion = 8;
    db.execute('CREATE TABLE import_maps(dummy TEXT)');
    expect(
      () => DocumentRepository.open('${dir.path}/db', ns),
      throwsA(isA<SqliteException>()),
    );
    expect(db.userVersion, 8);
    expect(
      db.select('SELECT * FROM schema_migrations WHERE version=9'),
      isEmpty,
    );
    db.execute('DROP TABLE import_maps');
    repo = DocumentRepository.open('${dir.path}/db', ns);
    expect(db.userVersion, 9);
    expect(repo.read('current')!.hash, hash);
    expect(repo.selectedProjectId, 'current');
    expect(db.select('PRAGMA integrity_check').single.values.single, 'ok');
    expect(db.select('PRAGMA foreign_key_check'), isEmpty);
  });
  test('REAL SIGKILL after ImportMap and selected-project change before COMMIT restores old project without half-import', () async {
    final before = repo.read('current')!.hash;
    repo.close();
    final child = await Process.start(Platform.resolvedExecutable, [
      'run',
      'packages/studio_store/tool/resource_import_worker.dart',
      '${dir.path}/db',
    ]);
    final errors = child.stderr.transform(utf8.decoder).join();
    try {
      await child.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .firstWhere((l) => l == 'IMPORTED_UNCOMMITTED')
          .timeout(const Duration(seconds: 20));
      child.kill(ProcessSignal.sigkill);
      expect(
        await child.exitCode,
        -ProcessSignal.sigkill.signalNumber,
        reason: await errors,
      );
      repo = DocumentRepository.open('${dir.path}/db', ns);
      expect(repo.selectedProjectId, 'current');
      expect(repo.read('current')!.hash, before);
      expect(repo.read('crash-fork'), isNull);
      expect(repo.importMap('crash-fork'), isNull);
      expect(db.select('PRAGMA integrity_check').single.values.single, 'ok');
      writer = repo.acquireWriter(
        'current',
        'recovered',
        expectedEpoch: repo.writerEpoch('current'),
      );
      expect(adopt().project.projectId, isNot('current'));
    } finally {
      child.kill(ProcessSignal.sigkill);
      await child.exitCode;
      await errors;
    }
  });
}
