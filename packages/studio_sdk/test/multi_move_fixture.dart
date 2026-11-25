import 'dart:convert';
import 'dart:io';

import 'package:studio_sdk/studio_sdk.dart';

StudioWorkspace openMoveWorkspace(Directory dir) => StudioWorkspace.open(
  profile: AppProfile(
    appId: 'studio',
    region: 'local',
    features: {'project.metadata', 'media.local'},
  ),
  databasePath: '${dir.path}/db',
  tenantId: 'local',
  workspaceId: 'multi-move',
  mediaLibraryPath: Platform.environment['STUDIO_MEDIA_LIBRARY'],
  mediaRootPath: '${dir.path}/media',
);
List<Map> moveVideos(ProjectDocument p) =>
    (p.toJson()['sequences'][0]['tracks'][0]['items'] as List)
        .where((c) => c['source'] != null)
        .cast<Map>()
        .toList();
Future<void> installLinkedMoveFixture(StudioWorkspace w, Directory root) async {
  w.openDemo();
  final av = File('${root.path}/av.mp4');
  final made = await Process.run('ffmpeg', [
    '-v',
    'error',
    '-i',
    Platform.environment['STUDIO_TEST_VIDEO']!,
    '-f',
    'lavfi',
    '-i',
    'sine=frequency=997:sample_rate=44100:duration=3',
    '-map',
    '0:v:0',
    '-map',
    '1:a:0',
    '-c:v',
    'copy',
    '-c:a',
    'aac',
    av.path,
  ]);
  if (made.exitCode != 0) throw StateError('${made.stderr}');
  await w.importVideo(
    LocalFileGrant.fromUserSelection(av),
    expectedRevision: w.current.revision,
    acknowledgeVideoOnly: true,
  );
  final first = moveVideos(w.current).first['id'] as String;
  w.edit(
    SplitClip(first, Q.of(3, 2), 'right'),
    expectedRevision: w.current.revision,
  );
  final stream =
      (w.current.toJson()['assets'][0]['streams'] as List).singleWhere(
            (s) => s['type'] == 'audio',
          )['id']
          as String;
  for (final c in moveVideos(w.current)) {
    w.edit(
      ExtractAudioClip(c['id'] as String, stream),
      expectedRevision: w.current.revision,
    );
  }
}

Future<void> adoptMoveMetadata(
  StudioWorkspace w,
  Directory root,
  void Function(Map<String, dynamic>) mutate,
) async {
  final d = w.current.toJson();
  mutate(d);
  final file = File('${root.path}/modified.json')
    ..writeAsStringSync(jsonEncode(d));
  final session = await ResourcePreservationSession.openJson(
    LocalFileGrant.fromUserSelection(file),
  );
  await session.attach(
    LocalFileGrant.fromUserSelection(File('${root.path}/av.mp4')),
  );
  await w.adoptPreservedResources(
    session,
    expectedCollectionReviewHash: session.collectionReviewHash,
    expectedActiveHash: w.current.hash,
    confirmed: true,
  );
}
