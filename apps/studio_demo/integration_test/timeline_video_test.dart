import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:studio_editor_ui/studio_editor_ui.dart';
import 'package:studio_sdk/studio_sdk.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  // Real application frames continue between test-driver interactions; manual
  // pumps must not be mistaken for an autonomous live presentation loop.
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  testWidgets(
    'REAL Pulse user UI extracts, auditions, pauses, seeks, rebinds and stops audio timeline',
    (tester) async {
      final dir = Directory.systemTemp.createTempSync('ui-pulse-');
      final w = StudioWorkspace.open(
        profile: AppProfile(
          appId: 'studio',
          region: 'local',
          features: {'project.metadata', 'media.local'},
        ),
        databasePath: '${dir.path}/db',
        tenantId: 'local',
        workspaceId: 'pulse-ui',
        mediaLibraryPath: Platform.environment['STUDIO_MEDIA_LIBRARY'],
        mediaRootPath: '${dir.path}/media',
      );
      addTearDown(() async {
        w.close();
        dir.deleteSync(recursive: true);
        await tester.binding.setSurfaceSize(null);
      });
      final boundary = NativeMedia.open(
        Platform.environment['STUDIO_MEDIA_LIBRARY']!,
        Namespace('studio', 'local', 'native-ui-boundary'),
      );
      try {
        final missing = File('${dir.path}/not-a-selected-file');
        final refused = throwsA(
          isA<StudioException>().having(
            (e) => e.code,
            'code',
            'LOCAL_FILE_REQUIRED',
          ),
        );
        expect(() => boundary.probe(missing), refused);
        await expectLater(boundary.probeAsync(missing), refused);
      } finally {
        boundary.close();
      }
      await tester.binding.setSurfaceSize(const Size(1100, 1700));
      await tester.pumpWidget(FoundationApp(workspace: w));
      Future<void> locate(String key) async {
        if (find.byKey(Key(key)).evaluate().isEmpty) {
          tester
              .state<ScrollableState>(find.byType(Scrollable).first)
              .position
              .jumpTo(0);
          await tester.pump();
          await tester.scrollUntilVisible(
            find.byKey(Key(key)),
            250,
            scrollable: find.byType(Scrollable).first,
            maxScrolls: 50,
          );
        }
        await Scrollable.ensureVisible(
          tester.element(find.byKey(Key(key))),
          alignment: 0.2,
        );
        await tester.pump();
      }

      Future<void> tap(String key) async {
        await locate(key);
        await Scrollable.ensureVisible(
          tester.element(find.byKey(Key(key))),
          alignment: 0.2,
        );
        await tester.pump();
        await tester.tap(find.byKey(Key(key)));
        await tester.pump();
      }

      Future<void> enter(String key, String text) async {
        await locate(key);
        await Scrollable.ensureVisible(
          tester.element(find.byKey(Key(key))),
          alignment: 0.2,
        );
        await tester.pump();
        // Native test driver retains focusedEditable after a button takes focus.
        // Reset only the driver cache; assert the actual controller value.
        FocusManager.instance.primaryFocus?.unfocus();
        tester.binding.focusedEditable = null;
        await tester.pump();
        await tester.enterText(find.byKey(Key(key)), text);
        expect(
          tester.widget<TextField>(find.byKey(Key(key))).controller!.text,
          text,
        );
      }

      Future<void> asyncTap(String key, bool Function() done) async {
        await locate(key);
        await Scrollable.ensureVisible(
          tester.element(find.byKey(Key(key))),
          alignment: 0.2,
        );
        await tester.pump();
        await tester.runAsync(() async {
          await tester.tap(find.byKey(Key(key)));
          final until = DateTime.now().add(const Duration(seconds: 20));
          while (!done() && DateTime.now().isBefore(until)) {
            await Future<void>.delayed(const Duration(milliseconds: 20));
          }
          await Future<void>.delayed(const Duration(milliseconds: 20));
        });
        // Codec completion can arrive after the SDK cache entry. Advance real
        // engine IO and widget frames instead of spinning fake time while the
        // indeterminate busy animation is still correctly active.
        for (var n = 0; n < 200; n++) {
          await tester.pump(const Duration(milliseconds: 16));
          if (find.byKey(const Key('media-busy')).evaluate().isEmpty) break;
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)),
          );
        }
        expect(find.byKey(const Key('media-busy')), findsNothing);
        await tester.pump();
        expect(find.byKey(const Key('error')), findsNothing);
        expect(done(), true, reason: '$key timed out: ${w.timelinePlayback}');
      }

      final av = File('${dir.path}/tone.mp4');
      final made = Process.runSync('ffmpeg', [
        '-v',
        'error',
        '-stream_loop',
        '2',
        '-i',
        Platform.environment['STUDIO_TEST_VIDEO']!,
        '-f',
        'lavfi',
        '-i',
        'sine=frequency=1000:sample_rate=44100',
        '-t',
        '9',
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
      expect(made.exitCode, 0);
      await enter('import-path', av.path);
      await tap('import-video-only');
      await asyncTap('import-video', () => w.current.revision == BigInt.one);
      final clip = w.current.toJson()['sequences'][0]['tracks'][0]['items'][0];
      await tap('clip-${clip['id']}');
      await tap('extract-persistent-audio');
      await asyncTap('build-timeline-proxies', () => w.previewProxyCount == 1);
      Future<void> videoAt(int sample) async {
        for (var i = 0; i < 200; i++) {
          await tester.pump(const Duration(milliseconds: 16));
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 10)),
          );
          if (find.byKey(const Key('timeline-preview')).evaluate().isNotEmpty &&
              (sample < 0 ||
                  tester
                      .widget<Text>(
                        find.byKey(const Key('timeline-video-status')),
                      )
                      .data!
                      .contains('sample $sample ·'))) {
            return;
          }
        }
        fail(
          'real video not committed for sample $sample: ${w.timelinePlayback}',
        );
      }

      Future<String> pixelsHash() async {
        final image = tester
            .widget<RawImage>(find.byKey(const Key('timeline-preview')))
            .image!
            .clone();
        try {
          final bytes = await tester.runAsync(() => image.toByteData());
          return rawBytesHash(bytes!.buffer.asUint8List());
        } finally {
          image.dispose();
        }
      }

      await enter('timeline-sink', 'studio_test');
      await asyncTap(
        'play-timeline',
        () =>
            w.timelinePlayback['clockValid'] == true &&
            (w.timelinePlayback['presentedSample'] as int) > 4800,
      );
      await videoAt(-1);
      debugPrint(
        'AV_UI_FIRST ${w.timelinePlayback} ${tester.widget<Text>(find.byKey(const Key('timeline-video-status'))).data}',
      );
      expect(
        w.timelinePlayback['state'],
        'playing',
        reason: 'must render before EOF, not only after the clock stops',
      );
      await asyncTap(
        'pause-timeline',
        () => w.timelinePlayback['state'] == 'paused',
      );
      final firstSample = w.timelinePlayback['presentedSample'] as int;
      await videoAt(firstSample);
      // Do not read GPU pixels concurrently with live image replacement. The
      // renderer itself remains fullyLive; sample two confirmed paused frames
      // around real autonomous playback, never synthesize time from a pump.
      final movingHash = await pixelsHash();
      await asyncTap(
        'resume-timeline',
        () =>
            w.timelinePlayback['state'] == 'playing' &&
            (w.timelinePlayback['presentedSample'] as int) >=
                firstSample + 24000,
      );
      await asyncTap(
        'pause-timeline',
        () => w.timelinePlayback['state'] == 'paused',
      );
      await videoAt(w.timelinePlayback['presentedSample'] as int);
      expect(
        await pixelsHash(),
        isNot(movingHash),
        reason: 'actual UI pixels must change across real autonomous AudioSink progress',
      );
      debugPrint(
        'AV_UI_MOVING ${tester.widget<Text>(find.byKey(const Key('timeline-video-status'))).data}',
      );
      await enter('timeline-seek-ms', '0');
      final zeroEpoch = w.timelinePlayback['epoch'] as int;
      await asyncTap(
        'seek-timeline',
        () =>
            w.timelinePlayback['epoch'] > zeroEpoch &&
            w.timelinePlayback['state'] == 'paused' &&
            w.timelinePlayback['clockValid'] == true,
      );
      await videoAt(0);
      final zeroHash = await pixelsHash();
      await enter('timeline-seek-ms', '500');
      final epoch = w.timelinePlayback['epoch'] as int;
      await asyncTap(
        'seek-timeline',
        () =>
            w.timelinePlayback['epoch'] > epoch &&
            w.timelinePlayback['state'] == 'paused' &&
            w.timelinePlayback['clockValid'] == true,
      );
      expect(w.timelinePlayback['presentedSample'], 24000);
      await videoAt(24000);
      expect(await pixelsHash(), isNot(zeroHash));
      debugPrint(
        'AV_UI_SEEK ${tester.widget<Text>(find.byKey(const Key('timeline-video-status'))).data}',
      );
      await enter('timeline-sink', 'second');
      await asyncTap(
        'rebind-timeline',
        () =>
            w.timelinePlayback['sink'] == 'second' &&
            w.timelinePlayback['state'] == 'paused' &&
            w.timelinePlayback['clockValid'] == true,
      );
      await asyncTap(
        'resume-timeline',
        () =>
            w.timelinePlayback['state'] == 'playing' &&
            (w.timelinePlayback['presentedSample'] as int) > 26000,
      );
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.runAsync(() async {
        final deadline = DateTime.now().add(const Duration(seconds: 4));
        while (w.timelinePlayback['state'] != 'paused') {
          if (DateTime.now().isAfter(deadline)) {
            fail('real lifecycle cork timeout');
          }
          await Future<void>.delayed(const Duration(milliseconds: 20));
        }
      });
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      expect(w.timelinePlayback['state'], 'paused'); // No automatic resume.
      await locate('timeline-audio-clock');
      expect(find.textContaining('confirmed sample'), findsOneWidget);
      await tap('stop-timeline');
      expect(w.timelinePlayback['state'], 'stopped');
      await tester.pump(const Duration(milliseconds: 32));
      expect(find.byKey(const Key('timeline-preview')), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
