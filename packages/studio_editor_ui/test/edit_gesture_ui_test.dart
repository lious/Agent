import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studio_editor_ui/studio_editor_ui.dart';
import 'package:studio_sdk/studio_sdk.dart';

import '../../studio_sdk/test/dissolve_fixture.dart';

void main() {
  testWidgets(
    'REAL drag40 -> one undo; native ghost image; Escape, pointer CANCEL and scroll arena loss have no commit',
    (tester) async {
      final dir = Directory.systemTemp.createTempSync('gesture-ui-');
      final w = StudioWorkspace.open(
        profile: AppProfile(
          appId: 'studio',
          region: 'local',
          features: {'project.metadata', 'media.local'},
        ),
        databasePath: '${dir.path}/db',
        tenantId: 'local',
        workspaceId: 'gesture-ui',
        mediaLibraryPath: Platform.environment['STUDIO_MEDIA_LIBRARY'],
        mediaRootPath: '${dir.path}/media',
      );
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox());
        await w.closeAsync();
        dir.deleteSync(recursive: true);
        await tester.binding.setSurfaceSize(null);
      });
      await tester.binding.setSurfaceSize(const Size(1100, 1700));
      await tester.runAsync(() => installDissolveFixture(w, dir));
      await tester.pumpWidget(FoundationApp(workspace: w));
      Future<void> locate(String key) async {
        final f = find.byKey(Key(key));
        if (f.evaluate().isEmpty) {
          tester
              .state<ScrollableState>(find.byType(Scrollable).first)
              .position
              .jumpTo(0);
          await tester.pump();
          await tester.scrollUntilVisible(
            f,
            250,
            scrollable: find.byType(Scrollable).first,
            maxScrolls: 60,
          );
        }
        await Scrollable.ensureVisible(tester.element(f), alignment: .5);
        await tester.pumpAndSettle();
        expect(f.hitTestable(), findsOneWidget);
      }

      Future<void> tap(String key) async {
        await locate(key);
        await tester.tap(find.byKey(Key(key)));
        await tester.pumpAndSettle();
      }

      final id =
          w.current.toJson()['sequences'][0]['tracks'][0]['items'][0]['id']
              as String;
      await tap('clip-$id');
      await locate('opacity-gesture-slider');
      final slider = find.byKey(const Key('opacity-gesture-slider'));
      final base = w.current;
      final unchanged = await tester.startGesture(
        tester.getRect(slider).centerRight - const Offset(2, 0),
      );
      await tester.pump(const Duration(milliseconds: 150));
      expect(find.byKey(const Key('gesture-active')), findsOneWidget);
      await unchanged.up();
      await tester.pumpAndSettle();
      expect(w.current.hash, base.hash);
      final drag = await tester.startGesture(
        tester.getRect(slider).centerRight - const Offset(30, 0),
      );
      for (var n = 0; n < 40; n++) {
        await drag.moveBy(const Offset(-5, 0));
        await tester.pump(const Duration(milliseconds: 5));
      }
      expect(w.current.hash, base.hash);
      expect(find.byKey(const Key('gesture-active')), findsOneWidget);
      for (
        var n = 0;
        n < 100 && find.byKey(const Key('gesture-preview')).evaluate().isEmpty;
        n++
      ) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(find.byKey(const Key('gesture-preview')), findsOneWidget);
      await drag.up();
      await tester.pumpAndSettle();
      expect(w.current.revision, base.revision + BigInt.one);
      expect(w.current.toJson()['effects'].length, 1);
      await tap('undo');
      expect(w.current.toJson()['effects'], isEmpty);
      await tap('redo');
      final restored = w.current.hash;
      await locate('opacity-gesture-slider');
      final escape = await tester.startGesture(tester.getCenter(slider));
      await escape.moveBy(const Offset(-40, 0));
      await tester.pump();
      expect(find.byKey(const Key('gesture-active')), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      await escape.up();
      await tester.pumpAndSettle();
      expect(w.current.hash, restored);
      expect(find.byKey(const Key('gesture-active')), findsNothing);
      final cancel = await tester.startGesture(tester.getCenter(slider));
      await cancel.moveBy(const Offset(-40, 0));
      await tester.pump();
      await cancel.cancel();
      await tester.pumpAndSettle();
      expect(w.current.hash, restored);
      expect(find.byKey(const Key('gesture-active')), findsNothing);
      // Hold long enough for tap-down to stage a ghost, then lose horizontal drag
      // recognition to the ancestor vertical scroll. No physical UP yet.
      final scroll = await tester.startGesture(tester.getCenter(slider));
      await tester.pump(const Duration(milliseconds: 150));
      expect(find.byKey(const Key('gesture-active')), findsOneWidget);
      await scroll.moveBy(const Offset(0, -100));
      await tester.pump();
      await scroll.up();
      await tester.pumpAndSettle();
      expect(w.current.hash, restored);
      expect(find.byKey(const Key('gesture-active')), findsNothing);
      expect(find.byKey(const Key('error')), findsNothing);
      await locate('opacity-gesture-slider');
      final db = sqlite3.open('${dir.path}/db');
      db.execute(
        "CREATE TRIGGER gesture_ui_fail BEFORE INSERT ON events BEGIN SELECT RAISE(ABORT,'gesture fixture'); END",
      );
      try {
        final fault = await tester.startGesture(tester.getCenter(slider));
        await fault.moveBy(const Offset(-40, 0));
        await tester.pump();
        await fault.up();
        await tester.pumpAndSettle();
        expect(w.current.hash, restored);
        expect(find.text('Gesture: LOCAL_COMMIT_FAILED'), findsOneWidget);
        expect(find.byKey(const Key('gesture-active')), findsOneWidget);
      } finally {
        db.execute('DROP TRIGGER gesture_ui_fail');
        db.dispose();
      }
      await tap('cancel-edit-gesture');
      expect(w.current.hash, restored);
      expect(find.byKey(const Key('gesture-active')), findsNothing);
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
