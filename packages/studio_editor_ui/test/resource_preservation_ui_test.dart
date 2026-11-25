import 'dart:io';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:studio_sdk/studio_sdk.dart';
import 'package:studio_editor_ui/resource_preservation_panel.dart';

import '../../studio_sdk/test/resource_fixture.dart';

void main() {
  testWidgets(
    'REAL UI resource JSON load/collect/confirm/archive/reopen/fork leaves editable workspace and CAS unchanged',
    (tester) async {
      final dir = Directory.systemTemp.createTempSync('resource-ui-');
      final w = StudioWorkspace.open(
        profile: AppProfile(
          appId: 'studio',
          region: 'local',
          features: {'project.metadata', 'media.local'},
        ),
        databasePath: '${dir.path}/db',
        tenantId: 'local',
        workspaceId: 'active',
        mediaLibraryPath: Platform.environment['STUDIO_MEDIA_LIBRARY'],
        mediaRootPath: '${dir.path}/media',
      );
      w.openDemo();
      final before = w.current.hash, inventory = w.namespaceStorageInventory();
      final font = fixtureFont(),
          mask = File('${dir.path}/mask.png')..writeAsBytesSync(fixtureMask()),
          video = File(Platform.environment['STUDIO_TEST_VIDEO']!);
      final d = resourceFixture(font.readAsBytesSync(), mask.readAsBytesSync()),
          input = File('${dir.path}/project.json')
            ..writeAsStringSync(
              jsonEncode(
                resourceFixture(font.readAsBytesSync(), mask.readAsBytesSync()),
              ),
            );
      addTearDown(() async {
        w.close();
        dir.deleteSync(recursive: true);
        await tester.binding.setSurfaceSize(null);
      });
      await tester.binding.setSurfaceSize(const Size(1100, 1500));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ResourcePreservationPanel(
                targetNamespace: w.current.namespace,
              ),
            ),
          ),
        ),
      );
      Future<void> locate(String key) async {
        await tester.ensureVisible(find.byKey(Key(key)));
        await tester.pumpAndSettle();
      }

      Future<void> enter(String key, String text) async {
        await locate(key);
        await tester.enterText(find.byKey(Key(key)), text);
        await tester.pump();
      }

      Future<void> tap(String key) async {
        await locate(key);
        await tester.runAsync(() async {
          await tester.tap(find.byKey(Key(key)));
        });
        await tester.pump();
        for (
          var i = 0;
          i < 500 &&
              find.byKey(const Key('resource-busy')).evaluate().isNotEmpty;
          i++
        ) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)),
          );
          await tester.pump();
        }
        expect(find.byKey(const Key('resource-busy')), findsNothing);
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('resource-error')), findsNothing);
      }

      await tap('resource-preservation-panel');
      await enter('resource-project-input', input.path);
      await tap('resource-load-json');
      for (final f in [font, mask, video]) {
        await enter('resource-file-input', f.path);
        await tap('resource-attach');
      }
      final zip = File('${dir.path}/project.zip');
      await enter('resource-output', zip.path);
      await locate('resource-save-archive');
      expect(
        tester
            .widget<OutlinedButton>(
              find.byKey(const Key('resource-save-archive')),
            )
            .onPressed,
        isNull,
      );
      await tap('resource-collect-consent');
      await tap('resource-save-archive');
      await tester.runAsync(() async {
        expect(
          (await ResourcePreservationSession.openArchive(
            LocalFileGrant.fromUserSelection(zip),
          )).project.toJson(),
          d,
        );
      });
      await enter('resource-project-input', zip.path);
      await tap('resource-open-archive');
      await tap('resource-fork');
      await locate('resource-save-archive');
      expect(
        tester
            .widget<OutlinedButton>(
              find.byKey(const Key('resource-save-archive')),
            )
            .onPressed,
        isNull,
      );
      await enter('resource-output', '${dir.path}/fork.zip');
      await tap('resource-collect-consent');
      await tap('resource-save-archive');
      await tester.runAsync(() async {
        final fork = await ResourcePreservationSession.openArchive(
          LocalFileGrant.fromUserSelection(File('${dir.path}/fork.zip')),
        );
        expect(fork.project.projectId, isNot(d['projectId']));
        expect(fork.project.namespace, w.current.namespace);
      });
      expect(w.current.hash, before);
      expect(w.namespaceStorageInventory(), inventory);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'REAL UI explicit native qualification and writable fork switches workspace with durable ImportMap',
    (tester) async {
      final dir = Directory.systemTemp.createTempSync('resource-adopt-ui-');
      final w = StudioWorkspace.open(
        profile: AppProfile(
          appId: 'studio',
          region: 'local',
          features: {'project.metadata', 'media.local'},
        ),
        databasePath: '${dir.path}/db',
        tenantId: 'local',
        workspaceId: 'active',
        mediaLibraryPath: Platform.environment['STUDIO_MEDIA_LIBRARY'],
        mediaRootPath: '${dir.path}/media',
      );
      addTearDown(() async {
        w.close();
        dir.deleteSync(recursive: true);
        await tester.binding.setSurfaceSize(null);
      });
      w.openDemo();
      await tester.runAsync(
        () => w.importVideo(
          LocalFileGrant.fromUserSelection(
            File(Platform.environment['STUDIO_TEST_VIDEO']!),
          ),
          expectedRevision: w.current.revision,
        ),
      );
      final before = w.current,
          input = File('${dir.path}/source.json')
            ..writeAsStringSync(w.current.canonicalJson);
      await tester.binding.setSurfaceSize(const Size(1100, 1500));
      var adopted = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ResourcePreservationPanel(
                targetNamespace: w.current.namespace,
                workspace: w,
                onAdopted: () => adopted++,
              ),
            ),
          ),
        ),
      );
      Future<void> locate(String key) async {
        await tester.ensureVisible(find.byKey(Key(key)));
        await tester.pumpAndSettle();
      }

      Future<void> enter(String key, String text) async {
        await locate(key);
        await tester.enterText(find.byKey(Key(key)), text);
        await tester.pump();
      }

      Future<void> tap(String key) async {
        await locate(key);
        await tester.runAsync(() => tester.tap(find.byKey(Key(key))));
        await tester.pump();
        for (
          var i = 0;
          i < 500 &&
              find.byKey(const Key('resource-busy')).evaluate().isNotEmpty;
          i++
        ) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)),
          );
          await tester.pump();
        }
        expect(find.byKey(const Key('resource-busy')), findsNothing);
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('resource-error')), findsNothing);
      }

      await tap('resource-preservation-panel');
      await enter('resource-project-input', input.path);
      await tap('resource-load-json');
      await enter(
        'resource-file-input',
        Platform.environment['STUDIO_TEST_VIDEO']!,
      );
      await tap('resource-attach');
      await locate('resource-adopt-writable');
      expect(
        tester
            .widget<OutlinedButton>(
              find.byKey(const Key('resource-adopt-writable')),
            )
            .onPressed,
        isNull,
      );
      await tap('resource-collect-consent');
      await tap('resource-adopt-writable');
      expect(adopted, 1);
      expect(w.current.projectId, isNot(before.projectId));
      expect(w.currentImportMap!['origin']['snapshotHash'], before.hash);
      expect(w.currentImportMap!['local']['projectId'], w.current.projectId);
      w.rename(
        'editable via standard coordinator',
        expectedRevision: w.current.revision,
      );
      expect(w.current.revision, BigInt.one);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
