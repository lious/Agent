import 'dart:convert';
import 'dart:io';

import 'package:studio_sdk/studio_sdk.dart';

Future<ResourcePreservationSession> installDissolveFixture(
  StudioWorkspace w,
  Directory root, {
  String blackSize = '128x72',
  bool preserveOnly = false,
}) async {
  w.openDemo();
  Future<File> make(String color) async {
    final f = File('${root.path}/$color.mp4');
    final r = await Process.run('ffmpeg', [
      '-v',
      'error',
      '-f',
      'lavfi',
      '-i',
      'color=c=$color:s=${color == 'black' ? blackSize : '128x72'}:r=30:d=3',
      '-vf',
      'setparams=color_primaries=bt709:color_trc=bt709:colorspace=bt709:range=limited',
      '-c:v',
      'libx264',
      '-pix_fmt',
      'yuv420p',
      '-color_primaries',
      'bt709',
      '-color_trc',
      'bt709',
      '-colorspace',
      'bt709',
      '-color_range',
      'tv',
      f.path,
    ]);
    if (r.exitCode != 0) throw StateError('${r.stderr}');
    return f;
  }

  final white = await make('white'), black = await make('black');
  await w.importVideo(
    LocalFileGrant.fromUserSelection(white),
    expectedRevision: w.current.revision,
    acknowledgeVideoOnly: true,
  );
  final other = StudioWorkspace.open(
    profile: AppProfile(
      appId: 'studio',
      region: 'local',
      features: {'project.metadata', 'media.local'},
    ),
    databasePath: '${root.path}/other-db',
    tenantId: 'local',
    workspaceId: 'other',
    mediaLibraryPath: Platform.environment['STUDIO_MEDIA_LIBRARY'],
    mediaRootPath: '${root.path}/other-media',
  );
  late Map<String, dynamic> b;
  try {
    other.openDemo();
    await other.importVideo(
      LocalFileGrant.fromUserSelection(black),
      expectedRevision: other.current.revision,
      acknowledgeVideoOnly: true,
    );
    b = other.current.toJson();
  } finally {
    other.close();
  }
  final d = w.current.toJson(),
      seq = d['sequences'][0],
      track = seq['tracks'][0],
      left = track['items'][0];
  left['timelineRange'] = {
    'start': Q.of(0).toJson(),
    'duration': Q.of(1).toJson(),
  };
  left['sourceRange'] = {
    'start': Q.of(1, 2).toJson(),
    'duration': Q.of(1).toJson(),
  };
  final right = b['sequences'][0]['tracks'][0]['items'][0];
  right['trackId'] = track['id'];
  right['timelineRange'] = {
    'start': Q.of(1).toJson(),
    'duration': Q.of(1).toJson(),
  };
  right['sourceRange'] = {
    'start': Q.of(1).toJson(),
    'duration': Q.of(1).toJson(),
  };
  track['items'] = [left, right];
  seq['duration'] = Q.of(2).toJson();
  for (final key in ['assets', 'blobs', 'rightsRecords']) {
    (d[key] as List).addAll(b[key] as List);
  }
  final file = File('${root.path}/two-source.json')
    ..writeAsStringSync(jsonEncode(d));
  final session = await ResourcePreservationSession.openJson(
    LocalFileGrant.fromUserSelection(file),
  );
  await session.attach(LocalFileGrant.fromUserSelection(white));
  await session.attach(LocalFileGrant.fromUserSelection(black));
  if (!preserveOnly) {
    await w.adoptPreservedResources(
      session,
      expectedCollectionReviewHash: session.collectionReviewHash,
      expectedActiveHash: w.current.hash,
      confirmed: true,
    );
  }
  return session;
}
