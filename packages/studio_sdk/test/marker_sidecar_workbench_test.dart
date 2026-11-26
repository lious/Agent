import 'dart:convert';
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
  test('workbench APIs export and import official sidecar, including clipLocal, and refuse unknown fields', () async {
    final root = Directory.systemTemp.createTempSync('marker-sidecar-wb-');
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
    final originalStay = Map<String, dynamic>.from(markerOf(w.current, 'stay'));
    final originalFollow = Map<String, dynamic>.from(
      markerOf(w.current, 'follow'),
    );
    final sidecar = File('${root.path}/markers.studio-markers.json');
    final exportedRevision = w.exportMarkers(sidecar);
    expect(exportedRevision, w.current.revision);
    expect(
      sidecar.readAsBytesSync().take(3).toList(),
      isNot([0xef, 0xbb, 0xbf]),
    );
    final envelope = jsonDecode(sidecar.readAsStringSync()) as Map;
    expect(envelope['format'], MarkerSidecar.formatName);
    expect((envelope['markers'] as List), hasLength(2));

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
    await w.importMarkers(
      LocalFileGrant.fromUserSelection(sidecar),
      expectedRevision: w.current.revision,
    );
    expect(markerOf(w.current, 'stay'), originalStay);
    expect(markerOf(w.current, 'follow'), originalFollow);
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

    final bad = File('${root.path}/bad.studio-markers.json');
    bad.writeAsStringSync(
      jsonEncode({...envelope, 'chapterTitle': 'must-not-be-stripped'}),
    );
    final before = w.current.hash;
    expect(
      () => w.importMarkers(
        LocalFileGrant.fromUserSelection(bad),
        expectedRevision: w.current.revision,
      ),
      code('MARKER_SIDECAR_UNSUPPORTED'),
    );
    expect(w.current.hash, before);
  });
}
