import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studio_editor_ui/studio_editor_ui.dart';
import 'package:studio_sdk/studio_sdk.dart';

/// Increment 1.96 official I-025 remainingAcceptance wording
/// 「无隐藏上传」 on the already-admitted FoundationApp import / archive /
/// export controls. A trap HTTP server must record zero requests
/// while a granted local video is imported, archived, and exported
/// to a local MP4. This file uses the already-admitted locate()
/// helper and does not rewrite foundation_app_test.dart or
/// local_video_ui_test.dart, invent a 60s 6-clip project, caption
/// burn-in, or an upload API.
void main() {
  testWidgets(
    'import archive and export stay local and do not issue hidden HTTP',
    (tester) async {
      final dir = Directory.systemTemp.createTempSync(
        'i025-no-hidden-upload-ui-',
      );
      final requested = <String>[];
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((request) async {
        requested.add('${request.method} ${request.uri}');
        request.response.statusCode = 200;
        request.response.write('must-not-upload');
        await request.response.close();
      });
      final w = StudioWorkspace.open(
        profile: AppProfile(
          appId: 'studio',
          region: 'local',
          features: {'project.metadata', 'media.local'},
        ),
        databasePath: '${dir.path}/db.sqlite',
        tenantId: 'local',
        workspaceId: 'i025-no-hidden-upload-ui',
        mediaLibraryPath: Platform.environment['STUDIO_MEDIA_LIBRARY'],
        mediaRootPath: '${dir.path}/media',
      );
      addTearDown(() async {
        await server.close(force: true);
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

      await enter('import-path', Platform.environment['STUDIO_TEST_VIDEO']!);
      await asyncTap('import-video', () => w.current.revision == BigInt.one);
      final archive = File('${dir.path}/ui.studio-project');
      await enter('archive-path', archive.path);
      await asyncTap(
        'save-archive',
        () =>
            w.persistence(target: archive).targetSavedRevision ==
            w.current.revision,
      );
      final output = File('${dir.path}/ui.mp4');
      await enter('export-path', output.path);
      await asyncTap('export-video', output.existsSync);
      expect(output.lengthSync(), greaterThan(0));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 80)),
      );
      expect(requested, isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
    skip:
        Platform.environment['STUDIO_MEDIA_LIBRARY'] == null ||
        Platform.environment['STUDIO_TEST_VIDEO'] == null,
  );
}
