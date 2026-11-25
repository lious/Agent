import 'dart:io';

import 'package:studio_sdk/studio_sdk.dart';
import 'package:test/test.dart';

import 'multi_move_fixture.dart';

void main() {
  for (final frames in [1, 29]) {
    test(
      'fractional linked move +$frames frames retains exact MP4/AAC endpoints and shared pixels',
      () async {
        final dir = Directory.systemTemp.createTempSync('pointer-fractional-');
        final w = openMoveWorkspace(dir);
        try {
          await installLinkedMoveFixture(w, dir);
          final ids = moveVideos(w.current).map((c) => c['id'] as String);
          final g = w.beginGesture(
            MoveClips(ids, Q.of(frames, 30)),
            expectedRevision: w.current.revision,
          );
          final ghost = await w.previewGestureAt(g, Q.of(frames, 30));
          w.commitGesture(g);
          final result = await w.exportVideo(
            File('${dir.path}/fractional.mp4'),
            captureFrames: [frames],
          );
          expect(result['audio'], 'aac');
          expect(result['audioSamples'], (90 + frames) * 1600);
          expect(result['preEncoderSamples'][0]['rgba'], ghost.rgba);
          w.undo(expectedRevision: w.current.revision);
          expect(
            Q.fromJson(moveVideos(w.current).first['timelineRange']['start']),
            Q.of(0),
          );
        } finally {
          await w.closeAsync();
          dir.deleteSync(recursive: true);
        }
      },
    );
  }
}
