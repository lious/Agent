import 'dart:io';

import 'package:sqlite3/sqlite3.dart';
import 'package:studio_sdk/studio_sdk.dart';
import 'package:studio_store/blob_store.dart';
import 'package:studio_store/project_archive.dart';
import 'package:test/test.dart';

/// Increment 1.92 official I-013 remainingAcceptance clause
/// 「凭据/已删正文不入包」 on the already-admitted workspace archive
/// publication path. This file does not rewrite save_test.dart,
/// save_crash_test.dart, files_test.dart, or 1.84–1.91 suites.
const deletedBody = 'DeletedBody-1913-secret';
const visibleTitle = 'VisibleTitle-1913';

void main() {
  test('workspace archive of the current revision excludes superseded body and session credentials', () async {
    final dir = Directory.systemTemp.createTempSync('i013-sdk-archive-');
    final w = StudioWorkspace.open(
      profile: AppProfile(
        appId: 'test',
        region: 'local',
        features: {'project.metadata'},
      ),
      databasePath: '${dir.path}/db.sqlite',
      tenantId: 'local',
      workspaceId: 'i013-archive',
    );
    try {
      w.openDemo();
      w.rename(deletedBody, expectedRevision: BigInt.zero);
      w.rename(visibleTitle, expectedRevision: BigInt.one);
      expect(w.current.title, visibleTitle);
      expect(w.current.revision, BigInt.two);
      final db = sqlite3.open('${dir.path}/db.sqlite');
      final stored = db
          .select('SELECT json FROM snapshots')
          .map((row) => row['json'] as String)
          .join('\n');
      db.dispose();
      expect(stored, contains(deletedBody));
      expect(stored, contains(visibleTitle));

      final archiveFile = File('${dir.path}/project.archive');
      await ProjectArchive().save(
        w.current,
        BlobStore(Directory('${dir.path}/cas'), w.current.namespace),
        archiveFile,
      );
      final opened = ProjectArchive().open(archiveFile);
      expect(opened.project.hash, w.current.hash);
      expect(opened.project.title, visibleTitle);
      expect(opened.project.revision, BigInt.two);
      expect(opened.project.canonicalJson, contains(visibleTitle));
      expect(opened.project.canonicalJson, isNot(contains(deletedBody)));
      // verifyBytes requires sessionArchive == null; a successful open is
      // the already-admitted refusal of credentials/session payloads.
    } finally {
      w.close();
      dir.deleteSync(recursive: true);
    }
  });
}
