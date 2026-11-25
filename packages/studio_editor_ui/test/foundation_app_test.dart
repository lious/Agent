import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studio_editor_ui/studio_editor_ui.dart';
import 'package:studio_sdk/studio_sdk.dart';

void main() {
  testWidgets(
    'real SQLite title save, validation, undo and reopen in Flutter widget',
    (tester) async {
      final dir = Directory.systemTemp.createTempSync('studio-widget-');
      final path = '${dir.path}/workspace.sqlite';
      final profile = AppProfile(
        appId: 'studio',
        region: 'local',
        features: {'project.metadata'},
      );
      var workspace = StudioWorkspace.open(
        profile: profile,
        databasePath: path,
        tenantId: 'local',
        workspaceId: 'ws',
      );
      addTearDown(() {
        workspace.close();
        dir.deleteSync(recursive: true);
      });
      await tester.pumpWidget(FoundationApp(workspace: workspace));
      expect(find.text('Revision 0'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('title')), 'First title');
      await tester.tap(find.byKey(const Key('save')));
      await tester.pump();
      expect(find.text('Revision 1'), findsOneWidget);
      expect(workspace.current.title, 'First title');
      await tester.enterText(find.byKey(const Key('title')), '');
      await tester.tap(find.byKey(const Key('save')));
      await tester.pump();
      expect(find.text('SCHEMA_SIZE'), findsOneWidget);
      expect(workspace.current.revision, BigInt.one);
      await tester.tap(find.byKey(const Key('undo')));
      await tester.pump();
      expect(find.text('Revision 2'), findsOneWidget);
      expect(workspace.current.title, 'Untitled');
      await tester.pumpWidget(const SizedBox());
      workspace.close();
      workspace = StudioWorkspace.open(
        profile: profile,
        databasePath: path,
        tenantId: 'local',
        workspaceId: 'ws',
      );
      await tester.pumpWidget(FoundationApp(workspace: workspace));
      expect(find.text('Revision 2'), findsOneWidget);
      expect(workspace.current.title, 'Untitled');
    },
  );
}
