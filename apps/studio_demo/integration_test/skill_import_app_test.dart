// NEW actual existing-App composition integration, not old adapter qualification.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:studio_sdk/studio_sdk.dart';
import 'package:studio_demo/skill_import_host.dart';

import '../../../packages/studio_assets/test/skills/signed_import/fixture.dart'
    as fixtures;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'existing Linux App owner + GTK source + immutable needsReview preview has no project/store writes',
    (tester) async {
      final root = Directory(
        Platform.environment['STUDIO_COMPOSITION_FIXTURES']!,
      );
      final workspace = StudioWorkspace.open(
        profile: AppProfile(
          appId: 'studio_demo',
          region: 'local',
          features: {'project.metadata', 'media.local'},
        ),
        databasePath: '${root.path}/app.sqlite',
        tenantId: 'local',
        workspaceId: 'default',
      );
      await tester.pumpWidget(SkillImportHost(workspace: workspace));
      for (var i = 0; i < 60; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        if (find.byKey(const Key('skill-choose')).evaluate().isNotEmpty &&
            tester
                    .widget<FilledButton>(find.byKey(const Key('skill-choose')))
                    .onPressed !=
                null) {
          break;
        }
      }
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('skill-choose')))
            .onPressed,
        isNotNull,
      );
      final fixture = fixtures.PackFixture();
      fixture.film['namespace'] = workspace.current.namespace.toJson();
      final path = '${root.path}/public-pack.json';
      File(path).writeAsBytesSync(fixture.envelope([]));

      final projectBefore = workspace.current.canonicalJson;
      Map<String, String> files() => {
        for (final f in root.listSync(recursive: true).whereType<File>())
          if (!f.path.endsWith('-shm'))
            f.path: base64.encode(f.readAsBytesSync()),
      };
      final before = files();
      List<String> paths() =>
          root
              .listSync(recursive: true)
              .map((e) => e.path)
              .where((p) => !p.endsWith('-shm'))
              .toList()
            ..sort();
      final pathsBefore = paths();
      final helper = Platform.environment['STUDIO_COMPOSITION_GTK_HELPER']!;
      final driver = (await tester.runAsync(
        () => Process.start('python3', [helper, 'select', path]),
      ))!;
      final out = driver.stdout.drain<void>(),
          err = driver.stderr.transform(utf8.decoder).join();
      await tester.tap(find.byKey(const Key('skill-choose')));
      await tester.pump();
      await tester.runAsync(() async {
        expect(
          await driver.exitCode.timeout(const Duration(seconds: 25)),
          0,
          reason: await err,
        );
        await out;
      });
      for (
        var i = 0;
        i < 80 && find.text('trustState: needsReview').evaluate().isEmpty;
        i++
      ) {
        await tester.pump(const Duration(milliseconds: 100));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
      }
      expect(find.text('trustState: needsReview'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('skill-acknowledge')))
            .onPressed,
        null,
      );
      await tester.tap(find.byKey(const Key('skill-dismiss')));
      await tester.pump();
      expect(find.textContaining('trustState:'), findsNothing);
      expect(workspace.current.canonicalJson, projectBefore);
      expect(files(), before);
      expect(paths(), pathsBefore);
      File(Platform.environment['STUDIO_COMPOSITION_LINUX_RESULT']!)
          .writeAsStringSync(
            jsonEncode({
              'passed': true,
              'actualApp':
                  'SkillImportHost + unchanged FoundationApp/StudioWorkspace',
              'namespace': workspace.current.namespace.toJson(),
              'trustState': 'needsReview',
              'ackDisabled': true,
              'projectUnchanged': true,
              'databaseCasShelfFilesUnchanged': true,
              'excludedTransientFiles': ['*-shm'],
              'profile': 'isolated box GTK 3 / Xvfb; empty production roots; unknown clock',
            }),
          );
      await tester.pumpWidget(const SizedBox());
      workspace.close();
    },
  );
}
