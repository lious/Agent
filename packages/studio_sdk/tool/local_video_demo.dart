import 'dart:convert';
import 'dart:io';

import 'package:studio_sdk/studio_sdk.dart';

/// Reproducible developer demo. Input is explicitly selected on this CLI; never
/// invoke this host-only path interface from an untrusted model tool.
Future<void> main(List<String> args) async {
  if (args.length != 4) {
    stderr.writeln(
      'Usage: local_video_demo.dart <native-library> <synthetic-video> <new-workspace-dir> <output.mp4>',
    );
    exitCode = 2;
    return;
  }
  final root = Directory(args[2]).absolute..createSync(recursive: true);
  StudioWorkspace open() => StudioWorkspace.open(
    profile: AppProfile(
      appId: 'studio_demo',
      region: 'local',
      features: {'project.metadata', 'media.local'},
    ),
    databasePath: '${root.path}/workspace.sqlite',
    tenantId: 'local',
    workspaceId: 'demo',
    mediaLibraryPath: args[0],
    mediaRootPath: '${root.path}/media',
  );
  var w = open();
  try {
    w.openDemo();
    if ((w.current.toJson()['assets'] as List).isNotEmpty) {
      throw const StudioException('DEMO_REQUIRES_EMPTY_PROJECT');
    }
    await w.importVideo(
      LocalFileGrant.fromUserSelection(File(args[1])),
      expectedRevision: w.current.revision,
    );
    final id =
        w.current.toJson()['sequences'][0]['tracks'][0]['items'][0]['id']
            as String;
    w.edit(
      SplitClip(id, Q.of(1), 'demo-right'),
      expectedRevision: w.current.revision,
    );
    w.edit(DeleteClip(id, ripple: true), expectedRevision: w.current.revision);
    w.edit(
      TrimClip('demo-right', 'out', Q.of(-1, 2), ripple: true),
      expectedRevision: w.current.revision,
    );
    w.edit(
      SlipClip('demo-right', Q.of(1, 2)),
      expectedRevision: w.current.revision,
    );
    final archive = File('${root.path}/project.studio-project');
    final revision = await w.saveArchive(archive), hash = w.current.hash;
    w.close();
    w = open();
    if (w.openDemo().hash != hash) {
      throw const StudioException('REOPEN_HASH_MISMATCH');
    }
    final receipt = await w.exportVideo(File(args[3]));
    stdout.writeln(
      jsonEncode({
        'savedRevision': revision.toString(),
        'archive': archive.path,
        'reopenedHash': hash,
        'export': receipt,
      }),
    );
  } finally {
    w.close();
  }
}
