import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studio_editor_ui/studio_editor_ui.dart';
import 'package:studio_sdk/studio_sdk.dart';

/// Increment 1.91 official I-012 remainingAcceptance clause
/// 「head继续编辑不伪改userSavedRevision」 on the already-admitted
/// FoundationApp persistence label. This file does not rewrite
/// foundation_app_test.dart or the Increment 1.90 suites.
void main() {
  testWidgets(
    'continued title edits after save-managed keep the explicit-save label at the receipt revision',
    (tester) async {
      final dir = Directory.systemTemp.createTempSync('i012-user-saved-ui-');
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

      Future<String> persistenceText() async {
        await locate('persistence-status');
        return tester
            .widget<Text>(find.byKey(const Key('persistence-status')))
            .data!;
      }

      await tester.pumpWidget(FoundationApp(workspace: workspace));
      expect(find.text('Revision 0'), findsOneWidget);
      await enter('title', 'First title');
      await tap('save');
      expect(workspace.current.revision, BigInt.one);
      expect(workspace.current.title, 'First title');
      expect(workspace.persistence().userSavedRevision, isNull);
      await tap('save-managed');
      expect(workspace.persistence().userSavedRevision, BigInt.one);
      expect(
        await persistenceText(),
        allOf(contains('Durable 1'), contains('explicit save 1')),
      );

      await enter('title', 'Second title');
      await tap('save');
      expect(workspace.current.revision, BigInt.two);
      expect(workspace.current.title, 'Second title');
      expect(workspace.persistence().headRevision, BigInt.two);
      // A later head must not rewrite the explicit-save receipt or label.
      expect(workspace.persistence().userSavedRevision, BigInt.one);
      final afterEdit = await persistenceText();
      expect(afterEdit, contains('explicit save 1'));
      expect(afterEdit, contains('Durable 2'));
      expect(afterEdit, isNot(contains('explicit save 2')));

      await tester.pumpWidget(const SizedBox());
      workspace.close();
      workspace = StudioWorkspace.open(
        profile: profile,
        databasePath: path,
        tenantId: 'local',
        workspaceId: 'ws',
      );
      await tester.pumpWidget(FoundationApp(workspace: workspace));
      await locate('revision');
      expect(find.text('Revision 2'), findsOneWidget);
      expect(workspace.current.title, 'Second title');
      expect(workspace.persistence().userSavedRevision, BigInt.one);
      final reopened = await persistenceText();
      expect(reopened, contains('explicit save 1'));
      expect(reopened, contains('Durable 2'));
      expect(reopened, isNot(contains('explicit save 2')));
      await tester.pumpWidget(const SizedBox());
    },
  );
}
