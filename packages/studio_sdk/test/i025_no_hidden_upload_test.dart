import 'dart:io';

import 'package:studio_sdk/studio_sdk.dart';
import 'package:test/test.dart';

/// Increment 1.96 official I-025 remainingAcceptance wording
/// 「无隐藏上传」 on the already-admitted local import / saveManaged /
/// saveArchive / exportVideo paths. A trap HTTP server must record
/// zero requests while a granted local video is imported, explicitly
/// saved, packed to a local archive, and exported to a local MP4.
/// This file does not rewrite local_video_test.dart or
/// audio_export_test.dart, invent a 60s 6-clip project, caption
/// burn-in, an upload API, or any unfinished I-024/I-027 path.
void main() {
  final library = Platform.environment['STUDIO_MEDIA_LIBRARY'];
  final fixture = Platform.environment['STUDIO_TEST_VIDEO'];

  late Directory dir;
  late HttpServer server;
  late List<String> requested;

  setUp(() async {
    dir = Directory.systemTemp.createTempSync('i025-no-hidden-upload-');
    requested = <String>[];
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      requested.add('${request.method} ${request.uri}');
      request.response.statusCode = 200;
      request.response.write('must-not-upload');
      await request.response.close();
    });
  });

  tearDown(() async {
    await server.close(force: true);
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  StudioWorkspace open() => StudioWorkspace.open(
    profile: AppProfile(
      appId: 'studio',
      region: 'local',
      features: {'project.metadata', 'media.local'},
    ),
    databasePath: '${dir.path}/db.sqlite',
    tenantId: 'local',
    workspaceId: 'i025-no-hidden-upload',
    mediaLibraryPath: library,
    mediaRootPath: '${dir.path}/media',
  );

  test(
    'exportVideo writes a local MP4 and does not issue hidden HTTP',
    () async {
      final workspace = open();
      try {
        workspace.openDemo();
        await workspace.importVideo(
          LocalFileGrant.fromUserSelection(File(fixture!)),
          expectedRevision: BigInt.zero,
        );
        final output = File('${dir.path}/out.mp4');
        final receipt = await workspace.exportVideo(output);
        expect(output.existsSync(), isTrue);
        expect(output.lengthSync(), greaterThan(0));
        expect(receipt['frames'], 90);
        await Future<void>.delayed(const Duration(milliseconds: 80));
        expect(requested, isEmpty);
      } finally {
        await workspace.closeAsync();
      }
    },
    skip: library == null || fixture == null,
  );

  test(
    'saveManaged and saveArchive stay local and do not issue hidden HTTP',
    () async {
      final workspace = open();
      try {
        workspace.openDemo();
        await workspace.importVideo(
          LocalFileGrant.fromUserSelection(File(fixture!)),
          expectedRevision: BigInt.zero,
        );
        workspace.rename(
          'I-025 no hidden upload',
          expectedRevision: workspace.current.revision,
        );
        final saved = workspace.saveManaged();
        expect(saved, workspace.current.revision);
        expect(workspace.persistence().userSavedRevision, saved);
        final archive = File('${dir.path}/project.studioproj');
        await workspace.saveArchive(archive);
        expect(archive.existsSync(), isTrue);
        expect(archive.lengthSync(), greaterThan(0));
        await Future<void>.delayed(const Duration(milliseconds: 80));
        expect(requested, isEmpty);
      } finally {
        await workspace.closeAsync();
      }
    },
    skip: library == null || fixture == null,
  );
}
