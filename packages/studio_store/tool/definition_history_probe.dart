// Isolated historical store compatibility/crash qualification, not an App test.
import 'dart:convert';
import 'dart:io';

import 'package:sqlite3/sqlite3.dart';
import 'package:studio_store/studio_store.dart';
import 'package:studio_document/studio_document.dart';

void main(List<String> args) {
  final dir = File(args[0]).parent.resolveSymbolicLinksSync();
  if (!dir.startsWith(
    '${Directory.systemTemp.resolveSymbolicLinksSync()}/definition-compat-',
  )) {
    throw ArgumentError('isolated fixture required');
  }
  final ns = Namespace('studio', 'local', 'compat');
  final repo = DocumentRepository.open(args[0], ns), db = sqlite3.open(args[0]);
  try {
    final p = repo.read('p')!;
    final oldRows = db
        .select('SELECT * FROM entity_versions ORDER BY entity_id,version')
        .map((r) => Map<String, Object?>.from(r))
        .toList();
    final snapshots = db
        .select('SELECT hash,json FROM snapshots')
        .map((r) => Map<String, Object?>.from(r))
        .toList();
    final writer = WriterToken(ns, 'p', 'owner', 1);
    ProjectDocument proposed(double gain) {
      final d = repo.read('p')!.toJson();
      d['sequences'][0]['version'] = '0';
      d['audioBuses'][0]['gainDb'] = gain;
      return ProjectDocument.fromJson(d);
    }

    void refuses(double gain) {
      try {
        repo.checkDefinitionCompatibility(proposed(gain));
      } on StudioException catch (e) {
        if (e.code == 'IMMUTABLE_VERSION_CONFLICT') return;
        rethrow;
      }
      throw StateError('incompatible reuse accepted');
    }

    if (args[1] == 'kill') {
      repo.edit(
        writer: writer,
        commandId: 'killed',
        receiptKey: 'killed',
        expectedRevision: p.revision,
        operation: const SetMasterAudio(gainDb: -9),
      );
      throw StateError('fixture barrier failed');
    }
    if (args[1] == 'recover') {
      if (p.revision != BigInt.one ||
          p.toJson()['audioBuses'][0]['gainDb'] != -6 ||
          db.select('SELECT * FROM entity_versions').length != 1 ||
          db.select("SELECT * FROM commands WHERE id='killed'").isNotEmpty) {
        throw StateError('uncommitted history escaped');
      }
    }
    if (p.toJson()['sequences'][0]['version'] != '0') {
      throw StateError('not actual ambiguous old definition');
    }
    repo.checkDefinitionCompatibility(p);
    refuses(-3);
    refuses(0); // Old alternate state is not general new-write permission.
    repo.undoLatest(
      writer: writer,
      commandId: 'restore',
      receiptKey: 'restore',
      expectedRevision: BigInt.one,
      targetCommandId: 'legacy-gain',
    );
    if (repo.read('p')!.toJson()['audioBuses'][0]['gainDb'] != 0 ||
        repo.read('p')!.toJson()['sequences'][0]['version'] != '0') {
      throw StateError('legacy exact undo rejected/rewritten');
    }
    repo.rename(
      writer: writer,
      commandId: 'rename',
      receiptKey: 'rename',
      expectedRevision: BigInt.two,
      title: 'legacy preserved',
    );
    repo.edit(
      writer: writer,
      commandId: 'gain-new',
      receiptKey: 'gain-new',
      expectedRevision: BigInt.from(3),
      operation: const SetMasterAudio(gainDb: -9),
    );
    refuses(-3);
    for (final row in oldRows) {
      final now = db.select(
        'SELECT * FROM entity_versions WHERE entity_id=? AND version=?',
        [row['entity_id'], row['version']],
      ).single;
      if (jsonEncode(Map<String, Object?>.from(now)) != jsonEncode(row)) {
        throw StateError('legacy raw row changed');
      }
    }
    for (final row in snapshots) {
      if (db.select('SELECT json FROM snapshots WHERE hash=?', [
            row['hash'],
          ]).single['json'] !=
          row['json']) {
        throw StateError('old snapshot changed');
      }
    }
    if (db.select('PRAGMA integrity_check').single.values.single != 'ok') {
      throw StateError('integrity');
    }
    print(
      jsonEncode({
        'mode': args[1],
        'schema': db.userVersion,
        'headRevision': repo.read('p')!.revision.toString(),
        'exactLegacyUndo': true,
        'unknownReuseRefused': true,
        'ambiguousOldStateNotNewWritePermission': true,
        'legacyRowsByteExact': true,
        'oldSnapshotBytesExact': true,
        'integrity': 'ok',
      }),
    );
  } finally {
    repo.close();
    db.dispose();
  }
}
