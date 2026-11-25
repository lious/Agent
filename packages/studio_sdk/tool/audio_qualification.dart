import 'dart:convert';
import 'dart:io';

import 'package:studio_sdk/studio_sdk.dart';

Future<void> main(List<String> args) async {
  final root = Directory(args[0]).absolute, library = args[1];
  final workspace = StudioWorkspace.open(
    profile: AppProfile(
      appId: 'studio',
      region: 'local',
      features: {'project.metadata', 'media.local'},
    ),
    databasePath: '${root.path}/project.db',
    tenantId: 'synthetic',
    workspaceId: 'audio-p0',
    mediaLibraryPath: library,
    mediaRootPath: '${root.path}/media',
  );
  try {
    workspace.openDemo();
    await workspace.importVideo(
      LocalFileGrant.fromUserSelection(File('${root.path}/input.mp4')),
      expectedRevision: BigInt.zero,
      acknowledgeVideoOnly: true,
    );
    workspace.saveManaged();
    final revision = workspace.current.revision, hash = workspace.current.hash;
    final out = File('${root.path}/export.mp4');
    final future = workspace.exportVideo(out, includeEmbeddedAudio: true);
    workspace.rename(
      'edit DURING frozen A/V export',
      expectedRevision: revision,
    );
    final receipt = await future;
    if (receipt['revision'] != revision.toString() ||
        receipt['snapshotHash'] != hash ||
        receipt['audioSamples'] != 2880000) {
      throw StateError('Frozen export receipt mismatch');
    }
    final facts = workspace.media!.probe(out),
        caps = workspace.media!.capabilities;
    File('${root.path}/sdk-result.json').writeAsStringSync(
      jsonEncode({
        'receipt': receipt,
        'facts': facts,
        'nativeCodecProfile': caps,
        'currentRevision': workspace.current.revision.toString(),
        'frozenRevision': revision.toString(),
        'fullTaskComplete': false,
      }),
    );
  } finally {
    workspace.close();
  }
}
