import 'dart:async';
import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studio_document/studio_document.dart';
import 'package:studio_contracts/studio_contracts.dart' show Namespace;
import 'package:studio_editor_ui/project_inspector.dart';

Future<void> inspectTap(WidgetTester tester, String key) async {
  await tester.ensureVisible(find.byKey(Key(key)));
  await tester.tap(find.byKey(Key(key)));
  await tester.pumpAndSettle();
}

Widget inspectorHost({Future<List<int>> Function()? load}) => MaterialApp(
  home: Scaffold(
    body: SingleChildScrollView(
      child: ProjectInspectorPanel(loadSelectedBytes: load),
    ),
  ),
);

void inspectorCases() {
  Map<String, dynamic> fixture() =>
      ProjectDocument.empty(
          namespace: Namespace('studio', 'local', 'inspection'),
          projectId: 'inspect-project',
          title: 'Foreign metadata snapshot',
        ).toJson()
        ..['extensions'] = {
          'unknown.plugin': {
            'opaque': ['not executed', '/never/open/this'],
          },
        };

  testWidgets(
    'readonly pasted snapshot and exact opaque payload remain isolated; reference search does not resolve resources',
    (tester) async {
      final value = fixture(), before = contentHash(fixture());
      await tester.pumpWidget(inspectorHost());
      await inspectTap(tester, 'schema-inspector');
      await tester.enterText(
        find.byKey(const Key('inspect-json')),
        jsonEncode(value),
      );
      await inspectTap(tester, 'inspect-validate');
      expect(
        find.textContaining('READ ONLY · Foreign metadata snapshot'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Blob bytes/provenance NOT verified'),
        findsOneWidget,
      );
      await tester.enterText(
        find.byKey(const Key('inspect-reference')),
        'sequence-main',
      );
      await inspectTap(tester, 'inspect-find');
      expect(
        find.text('1 matching metadata objects: /sequences/0'),
        findsOneWidget,
      );
      await tester.enterText(
        find.byKey(const Key('inspect-reference')),
        '/never/open/this',
      );
      await inspectTap(tester, 'inspect-find');
      expect(find.text('0 matching metadata objects: '), findsOneWidget);
      expect(contentHash(value), before);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'readonly inspector rejects duplicate JSON, future Schema, invalid FK and excess bytes without replacing good snapshot',
    (tester) async {
      final value = fixture();
      await tester.pumpWidget(inspectorHost());
      await inspectTap(tester, 'schema-inspector');
      for (final input in [
        jsonEncode(value),
        '{"title":1,"title":2}',
        jsonEncode({...value, 'schemaVersion': '99.0.0'}),
        jsonEncode({...value, 'rootSequenceId': 'missing'}),
      ]) {
        await tester.enterText(find.byKey(const Key('inspect-json')), input);
        await inspectTap(tester, 'inspect-validate');
        expect(
          find.textContaining('READ ONLY · Foreign metadata snapshot'),
          findsOneWidget,
        );
      }
      expect(find.byKey(const Key('inspect-error')), findsOneWidget);
      // The loader bypasses TextField's character cap; the independent byte cap
      // must still fail before a candidate can replace the last inspection.
      await tester.pumpWidget(
        inspectorHost(
          load: () async =>
              List.filled(ProjectInspectorPanel.maxInputBytes + 1, 32),
        ),
      );
      await inspectTap(tester, 'inspect-load');
      expect(find.textContaining('DOCUMENT_LIMIT'), findsOneWidget);
      expect(
        find.textContaining('READ ONLY · Foreign metadata snapshot'),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'readonly pending selected loader cannot update a disposed view',
    (tester) async {
      final pending = Completer<List<int>>();
      await tester.pumpWidget(inspectorHost(load: () => pending.future));
      await inspectTap(tester, 'schema-inspector');
      await tester.ensureVisible(find.byKey(const Key('inspect-load')));
      await tester.tap(find.byKey(const Key('inspect-load')));
      await tester.pump();
      expect(find.byKey(const Key('inspect-loading')), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      pending.complete(utf8.encode(jsonEncode(fixture())));
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );
}
