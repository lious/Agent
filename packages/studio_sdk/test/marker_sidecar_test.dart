import 'dart:io';

import 'package:studio_sdk/studio_sdk.dart';
import 'package:test/test.dart';

import 'multi_move_fixture.dart';

Matcher code(String c) =>
    throwsA(isA<StudioException>().having((e) => e.code, 'code', c));

String sequenceId(ProjectDocument p) => p.toJson()['rootSequenceId'] as String;

String videoId(ProjectDocument p) => moveVideos(p).first['id'] as String;

Q clipStart(ProjectDocument p) =>
    Q.fromJson(moveVideos(p).first['timelineRange']['start']);

Q clipDuration(ProjectDocument p) =>
    Q.fromJson(moveVideos(p).first['timelineRange']['duration']);

Map markerOf(ProjectDocument p, String id) => (p.toJson()['markers'] as List)
    .cast<Map>()
    .singleWhere((m) => m['id'] == id);

Future<void> installSingleClip(StudioWorkspace w, Directory root) async {
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
  if (made.exitCode != 0) {
    throw StateError('${made.stderr}');
  }
  await w.importVideo(
    LocalFileGrant.fromUserSelection(av),
    expectedRevision: w.current.revision,
    acknowledgeVideoOnly: true,
  );
}

void main() {
  test('persist path: official sidecar export/import round-trips, refuses silent drops, no MP4 mux', () async {
    final root = Directory.systemTemp.createTempSync('marker-sidecar-sdk-');
    addTearDown(() => root.deleteSync(recursive: true));
    final w = openMoveWorkspace(root);
    addTearDown(w.close);
    await installSingleClip(w, root);
    final host = videoId(w.current);
    final seq = sequenceId(w.current);
    w.edit(
      SetMarkers(
        MarkerStore([
          TimelineMarker(
            'stay',
            sequenceId: seq,
            label: 'stay-label',
            time: Q.of(0),
            colorRGBA: const [0, 0.5, 1, 1],
          ),
          TimelineMarker(
            'follow',
            sequenceId: seq,
            label: 'follow-label',
            time: Q.of(1, 2),
            duration: Q.of(1, 4),
          ).anchoredToClip(host, clipStart(w.current), clipDuration(w.current)),
        ]),
      ),
      expectedRevision: w.current.revision,
    );
    final original = w.current;
    final sidecar = File('${root.path}/markers.studio-markers.json');
    sidecar.writeAsStringSync(MarkerSidecar.export(original.toJson()));
    expect(
      sidecar.readAsBytesSync().take(3).toList(),
      isNot([0xef, 0xbb, 0xbf]),
    );

    w.edit(
      SetMarkers(
        MarkerStore([
          TimelineMarker(
            'other',
            sequenceId: seq,
            label: 'should-not-remain',
            time: Q.of(1),
          ),
        ]),
      ),
      expectedRevision: w.current.revision,
    );
    expect(markerOf(w.current, 'other')['label'], 'should-not-remain');
    expect(
      () => MarkerSidecar.import(
        '{"format":"text/csv","formatVersion":"1.0.0","markers":[]}',
        w.current.toJson(),
      ),
      code('MARKER_SIDECAR_INVALID'),
    );
    final restored = MarkerSidecar.import(
      sidecar.readAsBytesSync(),
      w.current.toJson(),
    );
    w.edit(SetMarkers(restored), expectedRevision: w.current.revision);
    expect(
      {for (final m in w.current.toJson()['markers']) m['id']},
      {'stay', 'follow'},
    );
    expect(markerOf(w.current, 'stay'), markerOf(original, 'stay'));
    expect(markerOf(w.current, 'follow'), markerOf(original, 'follow'));
    expect(markerOf(w.current, 'stay')['label'], 'stay-label');
    expect(markerOf(w.current, 'follow')['anchor'], {
      'kind': 'clipLocal',
      'clipId': host,
    });
    expect(
      () => (w.current.toJson()['markers'] as List).singleWhere(
        (m) => m['id'] == 'other',
      ),
      throwsStateError,
    );

    final archive = File('${root.path}/markers.studio-project');
    await w.saveArchive(archive);
    await w.restoreArchive(LocalFileGrant.fromUserSelection(archive));
    expect(markerOf(w.current, 'follow')['anchor']['kind'], 'clipLocal');
    expect(markerOf(w.current, 'stay')['label'], 'stay-label');
  });
}
