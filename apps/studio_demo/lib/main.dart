import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:studio_sdk/studio_sdk.dart';
import 'package:studio_editor_ui/studio_editor_ui.dart';

void main(List<String> args) {
  WidgetsFlutterBinding.ensureInitialized();
  final root =
      Platform.environment['STUDIO_DEMO_DATA_DIR'] ??
      '${Directory.systemTemp.path}/studio-foundation-demo';
  Directory(root).createSync(recursive: true);
  final workspace = StudioWorkspace.open(
    profile: AppProfile(
      appId: 'studio_demo',
      region: 'local',
      features: {'project.metadata', 'media.local'},
    ),
    mediaLibraryPath: Platform.environment['STUDIO_MEDIA_LIBRARY'],
    mediaRootPath: Platform.environment.containsKey('STUDIO_MEDIA_LIBRARY')
        ? '$root/media'
        : null,
    databasePath: '$root/studio_demo.sqlite',
    tenantId: 'local',
    workspaceId: 'default',
  );
  runApp(FoundationApp(workspace: workspace));
  if (args.contains('--smoke-test')) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      stdout.writeln(
        'STUDIO_SMOKE_OK ${workspace.profile.appId} revision=${workspace.current.revision}',
      );
      workspace.close();
      exit(0);
    });
  }
}
