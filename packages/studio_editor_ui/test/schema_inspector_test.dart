import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studio_editor_ui/project_inspector.dart';
import 'package:studio_editor_ui/studio_editor_ui.dart';
import 'package:studio_sdk/studio_sdk.dart';

import 'inspector_cases.dart';

File richFixture() {
  var root = Directory.current;
  while (!File('${root.path}/fixtures/project/semantic-rich.json')
      .existsSync()) {
    if (root.parent.path == root.path) throw StateError('fixture not found');
    root = root.parent;
  }
  return File('${root.path}/fixtures/project/semantic-rich.json');
}

void main() {
  inspectorCases();
  testWidgets(
    'full rich Schema readonly view exposes all root sections and exact nested/opaque values without mutation',
    (tester) async {
      final document = ProjectDocument.fromJson(
        readStrictJson(richFixture().readAsBytesSync()) as Map<String, dynamic>,
      );
      final hash = document.hash;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ProjectInspectorView(document: document),
            ),
          ),
        ),
      );
      final select = tester.widget<DropdownButton<String>>(
        find.byKey(const Key('inspect-section')),
      );
      expect(
        select.items!.map((i) => i.value).toSet(),
        document.toJson().keys.toSet(),
      );
      // Actual menu interaction selects opaque extensions; no plugin is loaded.
      await tester.tap(find.byKey(const Key('inspect-section')));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('extensions'),
        -150,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.text('extensions').last);
      await tester.pumpAndSettle();
      final detail = tester
          .widget<SelectableText>(find.byKey(const Key('inspect-detail')))
          .data!;
      expect(detail, contains('opaque.test'));
      expect(document.hash, hash);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'native explicit JSON file inspection preserves active SQLite head and survives closing/reopening workspace',
    (tester) async {
      final dir = Directory.systemTemp.createTempSync('readonly-ui-');
      final path = '${dir.path}/db';
      final profile = AppProfile(
        appId: 'studio',
        region: 'local',
        features: {'project.metadata'},
      );
      var workspace = StudioWorkspace.open(
        profile: profile,
        databasePath: path,
        tenantId: 'local',
        workspaceId: 'inspect-native',
      );
      addTearDown(() {
        workspace.close();
        dir.deleteSync(recursive: true);
      });
      await tester.pumpWidget(FoundationApp(workspace: workspace));
      final hash = workspace.current.hash;
      await tester.scrollUntilVisible(
        find.byKey(const Key('inspect-path')),
        500,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.enterText(
        find.byKey(const Key('inspect-path')),
        richFixture().path,
      );
      await inspectTap(tester, 'schema-inspector');
      await tester.ensureVisible(find.byKey(const Key('inspect-load')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('inspect-load')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('inspect-load')).hitTestable(),
        findsOneWidget,
      );
      await tester.runAsync(() async {
        await tester.tap(find.byKey(const Key('inspect-load')));
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      for (var i = 0; i < 100; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        if (find.byKey(const Key('inspect-loading')).evaluate().isEmpty) break;
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
      }
      expect(find.byKey(const Key('inspect-loading')), findsNothing);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('inspect-snapshot')), findsOneWidget);
      expect(workspace.current.hash, hash);
      expect(workspace.current.revision, BigInt.zero);
      expect(workspace.canUndo, false);
      await tester.pumpWidget(const SizedBox());
      workspace.close();
      workspace = StudioWorkspace.open(
        profile: profile,
        databasePath: path,
        tenantId: 'local',
        workspaceId: 'inspect-native',
      );
      expect(workspace.openDemo().hash, hash);
    },
  );
}
