import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studio_editor_ui/studio_editor_ui.dart';
import 'package:studio_sdk/studio_sdk.dart';

/// Increment 1.97 official I-025 remainingAcceptance wording
/// 「60秒6clip工程：手改字幕/trim/撤销/保存重开后等值」 on the already-admitted
/// FoundationApp import / split / caption-add / caption-edit / trim /
/// undo / save-managed / reopen controls. The 60s source is the admitted
/// local video looped with the already-used ffmpeg recipe; this is
/// document equality after those edits, not caption burn-in and not
/// export. This file uses the already-admitted locate() helper and does
/// not rewrite foundation_app_test.dart, local_video_ui_test.dart, or
/// caption_ui_test.dart, and does not invent a caption-burn path, a 60s
/// export, or new commands.
void main() {
  testWidgets(
    'sixty-second six-clip caption trim undo save-managed reopen stays equal',
    (tester) async {
      final dir = Directory.systemTemp.createTempSync('i025-60s-6clip-ui-');
      final source = File('${dir.path}/sixty.mp4');
      final made = await tester.runAsync(
        () => Process.run('ffmpeg', [
          '-y',
          '-v',
          'error',
          '-stream_loop',
          '19',
          '-i',
          Platform.environment['STUDIO_TEST_VIDEO']!,
          '-t',
          '60',
          '-c',
          'copy',
          source.path,
        ]),
      );
      expect(made!.exitCode, 0, reason: made.stderr.toString());

      final profile = AppProfile(
        appId: 'studio',
        region: 'local',
        features: {'project.metadata', 'media.local'},
      );
      const databasePathName = 'db.sqlite';
      var w = StudioWorkspace.open(
        profile: profile,
        databasePath: '${dir.path}/$databasePathName',
        tenantId: 'local',
        workspaceId: 'i025-60s-6clip-ui',
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
          alignment: 0.5,
        );
        await tester.pumpAndSettle();
        expect(find.byKey(Key(key)).hitTestable(), findsOneWidget);
      }

      Future<void> tap(String key) async {
        await locate(key);
        await tester.ensureVisible(find.byKey(Key(key)));
        await tester.tap(find.byKey(Key(key)));
        await tester.pump();
      }

      Future<void> enter(String key, String text) async {
        await locate(key);
        await tester.ensureVisible(find.byKey(Key(key)));
        await tester.enterText(find.byKey(Key(key)), text);
      }

      Future<void> asyncTap(String key, bool Function() done) async {
        await locate(key);
        await tester.ensureVisible(find.byKey(Key(key)));
        await tester.runAsync(() async {
          await tester.tap(find.byKey(Key(key)));
          final until = DateTime.now().add(const Duration(seconds: 20));
          while (!done() && DateTime.now().isBefore(until)) {
            await Future<void>.delayed(const Duration(milliseconds: 20));
          }
          await Future<void>.delayed(const Duration(milliseconds: 20));
        });
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

      List<Map<String, dynamic>> videos() {
        final items =
            (w.current.toJson()['sequences'][0]['tracks'][0]['items'] as List)
                .cast<Map>()
                .map((item) => Map<String, dynamic>.from(item))
                .toList()
              ..sort(
                (a, b) => Q
                    .fromJson(a['timelineRange']['start'])
                    .compareTo(Q.fromJson(b['timelineRange']['start'])),
              );
        return items;
      }

      String contents(ProjectDocument p) =>
          contentHash(p.toJson()..remove('revision'));

      await enter('import-path', source.path);
      await asyncTap('import-video', () => w.current.revision == BigInt.one);
      expect(
        Q.fromJson(w.current.toJson()['sequences'][0]['duration']),
        Q.of(60),
      );

      await enter('edit-frames', '300');
      for (var i = 0; i < 5; i++) {
        final remaining = videos().last['id'] as String;
        await tap('clip-$remaining');
        await tap('split');
        expect(videos(), hasLength(i + 2));
      }
      final packed = videos();
      expect(packed, hasLength(6));
      expect(
        Q.fromJson(w.current.toJson()['sequences'][0]['duration']),
        Q.of(60),
      );
      for (var i = 0; i < 6; i++) {
        expect(Q.fromJson(packed[i]['timelineRange']['start']), Q.of(10 * i));
        expect(Q.fromJson(packed[i]['timelineRange']['duration']), Q.of(10));
      }

      await tap('caption-panel');
      await enter('caption-text', 'first draft');
      await enter('caption-start', '0');
      await enter('caption-duration', '2000');
      await tap('caption-add');
      final cueId = w.current.toJson()['captions'][0]['id'] as String;
      await tap('cue-$cueId');
      await enter('caption-text', 'hand edited');
      await tap('caption-edit');
      expect(w.current.toJson()['captions'][0]['text'], 'hand edited');

      final afterCaptions = contents(w.current);
      await enter('edit-frames', '30');
      await tap('clip-${videos().last['id']}');
      await tap('trim');
      expect(contents(w.current), isNot(afterCaptions));
      await tap('undo');
      expect(contents(w.current), afterCaptions);
      expect(videos(), hasLength(6));
      expect(
        Q.fromJson(w.current.toJson()['sequences'][0]['duration']),
        Q.of(60),
      );
      expect(w.current.toJson()['captions'][0]['text'], 'hand edited');

      await tap('save-managed');
      expect(w.persistence().userSavedRevision, w.current.revision);
      final savedHash = w.current.hash;
      final savedContents = contents(w.current);
      final databasePath = '${dir.path}/$databasePathName';

      await tester.pumpWidget(const SizedBox());
      w.close();
      w = StudioWorkspace.open(
        profile: profile,
        databasePath: databasePath,
        tenantId: 'local',
        workspaceId: 'i025-60s-6clip-ui',
        mediaLibraryPath: Platform.environment['STUDIO_MEDIA_LIBRARY'],
        mediaRootPath: '${dir.path}/media',
      );
      await tester.pumpWidget(FoundationApp(workspace: w));
      await locate('revision');
      expect(w.current.hash, savedHash);
      expect(contents(w.current), savedContents);
      expect(videos(), hasLength(6));
      expect(
        Q.fromJson(w.current.toJson()['sequences'][0]['duration']),
        Q.of(60),
      );
      expect(w.current.toJson()['captions'][0]['text'], 'hand edited');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
    skip:
        Platform.environment['STUDIO_MEDIA_LIBRARY'] == null ||
        Platform.environment['STUDIO_TEST_VIDEO'] == null,
  );
}
