// Owned test fixture only: readiness barrier with an uncommitted real gesture.
import 'dart:io';

import 'package:studio_sdk/studio_sdk.dart';

void main(List<String> args) {
  final root = args.single;
  final w = StudioWorkspace.open(
    profile: AppProfile(
      appId: 'studio',
      region: 'local',
      features: {'project.metadata', 'media.local'},
    ),
    databasePath: '$root/db',
    tenantId: 'local',
    workspaceId: 'gestures',
    mediaLibraryPath: Platform.environment['STUDIO_MEDIA_LIBRARY'],
    mediaRootPath: '$root/media',
  );
  w.openDemo();
  final id =
      w.current.toJson()['sequences'][0]['tracks'][0]['items'][0]['id']
          as String;
  final g = w.beginGesture(
    SetClipOpacity(id, .7),
    expectedRevision: w.current.revision,
  );
  for (var n = 0; n < 100; n++) {
    w.updateGesture(g, SetClipOpacity(id, .2 + n * .001));
  }
  File('/dev/stdout').writeAsStringSync('GHOST_READY\n');
  stdin.readLineSync(); // Parent kills this Linux fixture with SIGKILL.
  w.close();
}
