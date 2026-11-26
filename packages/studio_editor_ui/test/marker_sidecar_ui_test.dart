import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studio_editor_ui/studio_editor_ui.dart';
import 'package:studio_sdk/studio_sdk.dart';

void main() {
  testWidgets(
    'workbench exports and imports official studio.markers.sidecar, refuses silent drops and unknown fields',
    (tester) async {
      final dir = Directory.systemTemp.createTempSync('marker-sidecar-ui-');
      var w = StudioWorkspace.open(
        profile: AppProfile(
          appId: 'studio',
          region: 'local',
          features: {'project.metadata'},
        ),
        databasePath: '${dir.path}/db',
        tenantId: 'local',
        workspaceId: 'markers',
      );
      addTearDown(() async {
        w.close();
        dir.deleteSync(recursive: true);
        await tester.binding.setSurfaceSize(null);
      });
      await tester.binding.setSurfaceSize(const Size(1100, 2200));
      await tester.pumpWidget(FoundationApp(workspace: w));
      await tester.pumpAndSettle();

      Future<void> locate(String key) async {
        final f = find.byKey(Key(key));
        await tester.ensureVisible(f);
        await tester.pumpAndSettle();
        expect(f.hitTestable(), findsOneWidget);
      }

      Future<void> enter(String key, String value) async {
        await locate(key);
        await tester.enterText(find.byKey(Key(key)), value);
      }

      Future<void> tap(String key) async {
        await locate(key);
        await tester.tap(find.byKey(Key(key)));
        await tester.pump();
      }

      Future<void> settleUntil(bool Function() done) async {
        for (var n = 0; n < 400; n++) {
          if (done()) {
            return;
          }
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)),
          );
          await tester.pump(const Duration(milliseconds: 16));
        }
        fail('workbench operation did not finish');
      }

      await tap('marker-panel');
      await tester.pumpAndSettle();
      await enter('marker-label', 'stay-label');
      await enter('marker-time', '0');
      await enter('marker-duration', '0');
      await tap('marker-add');
      await enter('marker-label', 'span-label');
      await enter('marker-time', '500');
      await enter('marker-duration', '500');
      await tap('marker-ripple');
      await tap('marker-add');
      expect(w.current.toJson()['markers'], hasLength(2));
      final original = {
        for (final m in w.current.toJson()['markers'] as List)
          m['id'] as String: Map<String, dynamic>.from(m as Map),
      };

      final sidecar = File('${dir.path}/markers.studio-markers.json');
      await enter('marker-sidecar-path', sidecar.path);
      await tap('marker-export-sidecar');
      await settleUntil(() => sidecar.existsSync());
      expect(find.byKey(const Key('error')), findsNothing);
      final bytes = sidecar.readAsBytesSync();
      expect(bytes.take(3).toList(), isNot([0xef, 0xbb, 0xbf]));
      final envelope = jsonDecode(utf8.decode(bytes)) as Map;
      expect(envelope['format'], 'studio.markers.sidecar');
      expect(envelope['formatVersion'], '1.0.0');
      expect(envelope['markers'], hasLength(2));
      expect({
        for (final m in envelope['markers'] as List) m['id'] as String,
      }, original.keys.toSet());

      final stayId = original.keys.firstWhere(
        (id) => original[id]!['label'] == 'stay-label',
      );
      await tap('marker-$stayId');
      await tap('marker-delete');
      expect(w.current.toJson()['markers'], hasLength(1));
      expect(
        (w.current.toJson()['markers'] as List).single['label'],
        isNot('stay-label'),
      );

      await tap('marker-import-sidecar');
      await settleUntil(() => w.current.toJson()['markers'].length == 2);
      expect(find.byKey(const Key('error')), findsNothing);
      expect(w.current.toJson()['markers'], hasLength(2));
      for (final id in original.keys) {
        final restored = (w.current.toJson()['markers'] as List)
            .cast<Map>()
            .singleWhere((m) => m['id'] == id);
        expect(restored, original[id]);
      }

      final bad = File('${dir.path}/bad.studio-markers.json');
      bad.writeAsStringSync(
        jsonEncode({...envelope, 'chapterTitle': 'must-not-be-stripped'}),
      );
      await enter('marker-sidecar-path', bad.path);
      final before = contentHash(w.current.toJson()..remove('revision'));
      await tap('marker-import-sidecar');
      await settleUntil(
        () => find.text('MARKER_SIDECAR_UNSUPPORTED').evaluate().isNotEmpty,
      );
      expect(find.text('MARKER_SIDECAR_UNSUPPORTED'), findsOneWidget);
      expect(contentHash(w.current.toJson()..remove('revision')), before);
    },
  );
}
