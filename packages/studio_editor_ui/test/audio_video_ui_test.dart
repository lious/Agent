import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studio_editor_ui/studio_editor_ui.dart';
import 'package:studio_sdk/studio_sdk.dart';

void main() {
  testWidgets(
    'REAL user UI embedded audio import acknowledgement, persisted master gain/archive fork and explicit AAC export',
    (tester) async {
      final dir = Directory.systemTemp.createTempSync('video-ui-');
      final w = StudioWorkspace.open(
        profile: AppProfile(
          appId: 'studio',
          region: 'local',
          features: {'project.metadata', 'media.local'},
        ),
        databasePath: '${dir.path}/db.sqlite',
        tenantId: 'local',
        workspaceId: 'widget',
        mediaLibraryPath: Platform.environment['STUDIO_MEDIA_LIBRARY'],
        mediaRootPath: '${dir.path}/media',
      );
      addTearDown(() async {
        w.close();
        dir.deleteSync(recursive: true);
        await tester.binding.setSurfaceSize(null);
      });
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
        await tester.enterText(find.byKey(Key(key)), text);
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
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('error')), findsNothing);
        expect(done(), true, reason: '$key timed out');
      }

      final av = File('${dir.path}/tone.mp4');
      final made = Process.runSync('ffmpeg', [
        '-v',
        'error',
        '-i',
        Platform.environment['STUDIO_TEST_VIDEO']!,
        '-f',
        'lavfi',
        '-i',
        'sine=frequency=1000:sample_rate=44100',
        '-t',
        '3',
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
      expect(made.exitCode, 0, reason: '${made.stderr}');
      await enter('import-path', av.path);
      await tap('import-video-only');
      await asyncTap('import-video', () => w.current.revision == BigInt.one);
      final clips =
          w.current.toJson()['sequences'][0]['tracks'][0]['items'] as List;
      await tap('clip-${clips.first['id']}');
      await enter('preview-time-ms', '1500');
      await asyncTap(
        'seek-source-frame',
        () => w.sourcePreviewCache.entries == 1,
      );
      expect(find.byKey(const Key('source-preview')), findsOneWidget);
      // Status is below this lazily built ListView viewport. Verify the actual
      // decoded image rather than asserting text that has not been built.
      final shown = tester.widget<RawImage>(
        find.byKey(const Key('source-preview')),
      );
      expect(shown.image!.width, 128);
      expect(shown.image!.height, 72);
      await tap('split');
      expect(find.byKey(const Key('source-preview')), findsNothing);
      expect(w.current.revision, BigInt.two);
      await enter('edit-frames', '15');
      await tap('trim');
      expect(w.current.revision, BigInt.from(3));
      await tap('undo');
      expect(w.current.revision, BigInt.from(4));
      await enter('master-gain-db', '-6');
      await tap('save-master-audio');
      expect(w.current.toJson()['audioBuses'][0]['gainDb'], -6);
      expect(w.current.revision, BigInt.from(5));
      final archive = File('${dir.path}/ui.studio-project');
      await enter('archive-path', archive.path);
      await asyncTap(
        'save-archive',
        () =>
            w.persistence(target: archive).targetSavedRevision ==
            w.current.revision,
      );
      await locate('persistence-status');
      expect(find.textContaining('explicit save 5'), findsOneWidget);
      final old = w.projectId;
      await asyncTap('restore-archive', () => w.projectId != old);
      expect(w.current.toJson()['audioBuses'][0]['gainDb'], -6);
      await tap('export-embedded-audio');
      final output = File('${dir.path}/ui.mp4');
      await enter('export-path', output.path);
      await asyncTap('export-video', output.existsSync);
      await locate('operation-status');
      expect(find.textContaining('90 frames'), findsOneWidget);
      final audio = (w.media!.probe(output)['streams'] as List)
          .where((s) => s['type'] == 'audio')
          .single;
      expect(audio['codec'], 'aac');
      expect(audio['sampleRate'], 48000);
      expect(audio['channels'], 2);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
    skip:
        Platform.environment['STUDIO_MEDIA_LIBRARY'] == null ||
        Platform.environment['STUDIO_TEST_VIDEO'] == null,
  );
  testWidgets(
    'REAL user UI persistent AV clips linked edit/mute/unlink/archive fork and default AAC export',
    (tester) async {
      final dir = Directory.systemTemp.createTempSync('video-ui-');
      final w = StudioWorkspace.open(
        profile: AppProfile(
          appId: 'studio',
          region: 'local',
          features: {'project.metadata', 'media.local'},
        ),
        databasePath: '${dir.path}/db.sqlite',
        tenantId: 'local',
        workspaceId: 'widget',
        mediaLibraryPath: Platform.environment['STUDIO_MEDIA_LIBRARY'],
        mediaRootPath: '${dir.path}/media',
      );
      addTearDown(() async {
        w.close();
        dir.deleteSync(recursive: true);
        await tester.binding.setSurfaceSize(null);
      });
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
        await tester.enterText(find.byKey(Key(key)), text);
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
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('error')), findsNothing);
        expect(done(), true, reason: '$key timed out');
      }

      final av = File('${dir.path}/tone.mp4');
      final made = Process.runSync('ffmpeg', [
        '-v',
        'error',
        '-i',
        Platform.environment['STUDIO_TEST_VIDEO']!,
        '-f',
        'lavfi',
        '-i',
        'sine=frequency=1000:sample_rate=44100',
        '-t',
        '3',
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
      expect(made.exitCode, 0, reason: '${made.stderr}');
      await enter('import-path', av.path);
      await tap('import-video-only');
      await asyncTap('import-video', () => w.current.revision == BigInt.one);
      final clips =
          w.current.toJson()['sequences'][0]['tracks'][0]['items'] as List;
      await tap('clip-${clips.first['id']}');
      await enter('preview-time-ms', '1500');
      await asyncTap(
        'seek-source-frame',
        () => w.sourcePreviewCache.entries == 1,
      );
      expect(find.byKey(const Key('source-preview')), findsOneWidget);
      // Status is below this lazily built ListView viewport. Verify the actual
      // decoded image rather than asserting text that has not been built.
      final shown = tester.widget<RawImage>(
        find.byKey(const Key('source-preview')),
      );
      expect(shown.image!.width, 128);
      expect(shown.image!.height, 72);
      await tap('extract-persistent-audio');
      expect(w.current.toJson()['linkGroups'].length, 1);
      expect(w.current.revision, BigInt.two);
      await tap('split');
      expect(find.byKey(const Key('source-preview')), findsNothing);
      expect(w.current.revision, BigInt.from(3));
      await enter('edit-frames', '15');
      await tap('trim');
      expect(w.current.revision, BigInt.from(4));
      await tap('undo');
      expect(w.current.revision, BigInt.from(5));
      await enter('master-gain-db', '-6');
      await tap('save-master-audio');
      expect(w.current.toJson()['audioBuses'][0]['gainDb'], -6);
      expect(w.current.revision, BigInt.from(6));
      final archive = File('${dir.path}/ui.studio-project');
      await enter('archive-path', archive.path);
      await asyncTap(
        'save-archive',
        () =>
            w.persistence(target: archive).targetSavedRevision ==
            w.current.revision,
      );
      await locate('persistence-status');
      expect(find.textContaining('explicit save 6'), findsOneWidget);
      final old = w.projectId;
      await asyncTap('restore-archive', () => w.projectId != old);
      expect(w.current.toJson()['audioBuses'][0]['gainDb'], -6);
      expect(w.current.toJson()['linkGroups'].length, 2);
      final audioTrack = (w.current.toJson()['sequences'][0]['tracks'] as List)
          .singleWhere((t) => t['kind'] == 'audio');
      await tap('audio-track-mute-${audioTrack['id']}');
      expect(
        (w.current.toJson()['sequences'][0]['tracks'] as List).last['muted'],
        isTrue,
      );
      await tap('audio-track-mute-${audioTrack['id']}');
      final firstVideo = w.current
          .toJson()['sequences'][0]['tracks'][0]['items'][0];
      await tap('clip-${firstVideo['id']}');
      await tap('unlink-persistent-audio');
      expect(w.current.toJson()['linkGroups'].length, 1);
      expect(
        (w.current.toJson()['sequences'][0]['tracks'] as List)
            .singleWhere((t) => t['kind'] == 'audio')['items']
            .length,
        2,
      );

      final output = File('${dir.path}/ui.mp4');
      await enter('export-path', output.path);
      await asyncTap('export-video', output.existsSync);
      await locate('operation-status');
      expect(find.textContaining('90 frames'), findsOneWidget);
      final audio = (w.media!.probe(output)['streams'] as List)
          .where((s) => s['type'] == 'audio')
          .single;
      expect(audio['codec'], 'aac');
      expect(audio['sampleRate'], 48000);
      expect(audio['channels'], 2);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
    skip:
        Platform.environment['STUDIO_MEDIA_LIBRARY'] == null ||
        Platform.environment['STUDIO_TEST_VIDEO'] == null,
  );
}
