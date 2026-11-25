import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:studio_editor_ui/studio_editor_ui.dart';
import 'package:studio_sdk/studio_sdk.dart';
import 'package:studio_store/studio_store.dart';

import '../../studio_sdk/test/multi_move_fixture.dart';
import '../../studio_sdk/test/dissolve_fixture.dart';

void main() {
  testWidgets(
    'REAL pointer linked drag: native ghost, cancel/error isolation, one SQL history, reopen/fork/AAC MP4',
    (tester) async {
      final dir = Directory.systemTemp.createTempSync('pointer-ui-');
      final workspace = openMoveWorkspace(dir);
      addTearDown(() async {
        workspace.close();
        dir.deleteSync(recursive: true);
        await tester.binding.setSurfaceSize(null);
      });
      await tester.binding.setSurfaceSize(const Size(1100, 1700));
      await tester.runAsync(() => installLinkedMoveFixture(workspace, dir));
      await tester.pumpWidget(FoundationApp(workspace: workspace));
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
            maxScrolls: 100,
          );
        }
        await Scrollable.ensureVisible(tester.element(f), alignment: .5);
        await tester.pumpAndSettle();
        expect(f.hitTestable(), findsOneWidget);
      }

      Future<void> tap(String key) async {
        await locate(key);
        await tester.tap(find.byKey(Key(key)));
        await tester.pump();
      }

      Future<void> enter(String key, String value) async {
        await locate(key);
        await tester.enterText(find.byKey(Key(key)), value);
      }

      Future<void> settleIO(String busy) async {
        for (var n = 0; n < 400; n++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)),
          );
          await tester.pump(const Duration(milliseconds: 16));
          if (find.byKey(Key(busy)).evaluate().isEmpty) break;
        }
        expect(find.byKey(Key(busy)), findsNothing);
        await tester.pumpAndSettle();
      }

      Future<void> waitFor(bool Function() predicate) async {
        for (var i = 0; i < 300 && !predicate(); i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)),
          );
          await tester.pump(const Duration(milliseconds: 16));
        }
        if (!predicate()) {
          tester
              .state<ScrollableState>(find.byType(Scrollable).first)
              .position
              .jumpTo(0);
          await tester.pump();
          debugPrint(
            'UI FAILURE: ${tester.widgetList<Text>(find.byType(Text)).map((t) => t.data).join(' | ')}',
          );
        }
        expect(predicate(), true);
      }

      Future<Offset> point() async {
        await locate('pointer-zoom');
        tester
            .state<ScrollableState>(
              find
                  .descendant(
                    of: find.byKey(const Key('pointer-scrollbar')),
                    matching: find.byType(Scrollable),
                  )
                  .first,
            )
            .position
            .jumpTo(0);
        await tester.pumpAndSettle();
        return tester.getTopLeft(find.byKey(const Key('pointer-surface'))) +
            const Offset(60, 60);
      }

      Future<TestGesture> begin(Offset start, double dx) async {
        final drag = await tester.startGesture(start);
        await tester.pump();
        await drag.moveTo(start + Offset(dx, 0));
        await tester.pump();
        return drag;
      }

      final ids = moveVideos(workspace.current)
          .map((c) => c['id'] as String)
          .toList();
      for (final id in ids) {
        await tap('multi-select-$id');
      }
      final original = workspace.current;
      var start = await point();
      // No pointer displacement / no recognizer acceptance means no event.
      await tester.tapAt(start);
      await tester.pumpAndSettle();
      expect(workspace.current.hash, original.hash);
      var drag = await begin(start, 96);
      await waitFor(
        () =>
            find.byKey(const Key('pointer-native-ghost')).evaluate().isNotEmpty,
      );
      expect(workspace.current.hash, original.hash);
      expect(find.byKey(const Key('pointer-gesture-active')), findsOneWidget);
      // Latest valid ghost, followed by Escape, must never release the old image.
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      await drag.up();
      await tester.pumpAndSettle();
      expect(workspace.current.hash, original.hash);
      expect(find.byKey(const Key('pointer-native-ghost')), findsNothing);
      // A valid candidate followed by a negative boundary invalidates it immediately.
      drag = await begin(start, 96);
      await drag.moveTo(start - const Offset(40, 0));
      await tester.pump();
      await drag.up();
      await tester.pumpAndSettle();
      expect(workspace.current.hash, original.hash);
      expect(find.byKey(const Key('pointer-native-ghost')), findsNothing);
      // Platform cancellation and secondary-pointer preemption do not write.
      drag = await begin(start, 96);
      await drag.cancel();
      await tester.pumpAndSettle();
      expect(workspace.current.hash, original.hash);
      drag = await begin(start, 96);
      final second = await tester.startGesture(
        start + const Offset(10, 5),
        pointer: 7,
      );
      await second.up();
      await drag.up();
      await tester.pumpAndSettle();
      expect(workspace.current.hash, original.hash);
      // Pointer outside the captured track/viewport cannot commit.
      drag = await begin(start, 96);
      await drag.moveTo(start + const Offset(100, 80));
      await drag.up();
      await tester.pumpAndSettle();
      expect(workspace.current.hash, original.hash);
      // Scroll signal preempts even a valid in-flight native preview.
      drag = await begin(start, 96);
      await tester.sendEventToBinding(
        PointerScrollEvent(position: start, scrollDelta: const Offset(100, 0)),
      );
      await drag.up();
      await tester.pumpAndSettle();
      expect(workspace.current.hash, original.hash);
      // Re-find after actual horizontal scrolling; visual measured coordinates include offset.
      final horizontal = tester.state<ScrollableState>(
        find
            .descendant(
              of: find.byKey(const Key('pointer-scrollbar')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      horizontal.position.jumpTo(0);
      await tester.pumpAndSettle();
      start = await point();
      // Forced late SQL rollback closes capture; no automatic retry of an old ghost.
      final db = sqlite3.open('${dir.path}/db');
      db.execute(
        "CREATE TRIGGER pointer_fail BEFORE INSERT ON events BEGIN SELECT RAISE(ABORT,'fixture'); END",
      );
      drag = await begin(start, 96);
      await drag.up();
      await waitFor(
        () =>
            find.byKey(const Key('pointer-gesture-active')).evaluate().isEmpty,
      );
      expect(workspace.current.hash, original.hash);
      expect(find.text('LOCAL_COMMIT_FAILED'), findsOneWidget);
      db.execute('DROP TRIGGER pointer_fail');
      db.dispose();
      // Many real physical updates coalesce into one persistent command.
      drag = await begin(start, 40);
      for (final x in [55.0, 75.0, 96.0]) {
        await drag.moveTo(start + Offset(x, 0));
        await tester.pump();
      }
      await waitFor(
        () =>
            find.byKey(const Key('pointer-native-ghost')).evaluate().isNotEmpty,
      );
      expect(workspace.current.hash, original.hash);
      await drag.up();
      await waitFor(
        () => workspace.current.revision == original.revision + BigInt.one,
      );
      final moved = workspace.current;
      for (final clip in moveVideos(moved)) {
        final old = moveVideos(original)
            .singleWhere((c) => c['id'] == clip['id']);
        expect(
          Q.fromJson(clip['timelineRange']['start']) -
              Q.fromJson(old['timelineRange']['start']),
          Q.of(29, 30),
        );
      }
      await tap('undo');
      expect(
        workspace.current.toJson()['sequences'],
        original.toJson()['sequences'],
      );
      await tap('redo');
      expect(
        workspace.current.toJson()['sequences'],
        moved.toJson()['sequences'],
      );
      final project = workspace.projectId;
      await tester.pumpWidget(const SizedBox());
      workspace.openDemo();
      expect(
        workspace.current.toJson()['sequences'],
        moved.toJson()['sequences'],
      );
      await tester.pumpWidget(FoundationApp(workspace: workspace));
      final archive = File('${dir.path}/pointer.studio-project');
      await enter('archive-path', archive.path);
      await tap('save-archive');
      await settleIO('media-busy');
      await tap('restore-archive');
      await settleIO('media-busy');
      expect(workspace.projectId, isNot(project));
      final output = File('${dir.path}/pointer.mp4');
      await enter('export-path', output.path);
      await tap('export-video');
      await settleIO('media-busy');
      await waitFor(() => output.existsSync());
      if (!output.existsSync()) {
        for (final e in find.byKey(const Key('error')).evaluate()) {
          debugPrint('EXPORT ERROR: ${(e.widget as Text).data}');
        }
      }
      expect(output.lengthSync(), greaterThan(1000));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(
        () => workspace.closeAsync().timeout(const Duration(seconds: 5)),
      );
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
  testWidgets(
    'REAL Shift selection, snap feedback, zoom/scroll mapping, zero/focus/ancestor preemption, linked locks and collision',
    (tester) async {
      final dir = Directory.systemTemp.createTempSync('pointer-matrix-');
      final w = openMoveWorkspace(dir);
      addTearDown(() async {
        w.close();
        dir.deleteSync(recursive: true);
        await tester.binding.setSurfaceSize(null);
      });
      await tester.binding.setSurfaceSize(const Size(1100, 1700));
      await tester.runAsync(() => installLinkedMoveFixture(w, dir));
      await tester.pumpWidget(FoundationApp(workspace: w));
      Future<void> show() async {
        final f = find.byKey(const Key('pointer-zoom'));
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
            maxScrolls: 100,
          );
        }
        await Scrollable.ensureVisible(tester.element(f), alignment: .5);
        await tester.pumpAndSettle();
      }

      Offset p(double x) =>
          tester.getTopLeft(find.byKey(const Key('pointer-surface'))) +
          Offset(x, 60);
      Future<TestGesture> begin(double x, double dx) async {
        final g = await tester.startGesture(p(x));
        await tester.pump();
        await g.moveTo(p(x) + Offset(dx, 0));
        await tester.pump();
        return g;
      }

      Future<void> waitFor(bool Function() condition) async {
        for (var i = 0; i < 300 && !condition(); i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)),
          );
          await tester.pump(const Duration(milliseconds: 16));
        }
        expect(condition(), true);
      }

      await show();
      final original = w.current;
      await tester.tapAt(p(60));
      await tester.pump();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.tapAt(p(210));
      await tester.pump();
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      var g = await begin(60, 100);
      await g.up();
      await waitFor(() => w.current.revision == original.revision + BigInt.one);
      for (final c in moveVideos(w.current)) {
        final old = moveVideos(original).singleWhere((o) => o['id'] == c['id']);
        expect(
          Q.fromJson(c['timelineRange']['start']) -
              Q.fromJson(old['timelineRange']['start']),
          Q.of(1),
        );
      }
      // Four logical pixels short of zero: exact resolver snaps BOTH linked pairs.
      g = await begin(160, -96);
      expect(find.textContaining('Snap playhead'), findsOneWidget);
      await g.up();
      await waitFor(() => w.current.revision == original.revision + BigInt.two);
      for (final c in moveVideos(w.current)) {
        final old = moveVideos(original).singleWhere((o) => o['id'] == c['id']);
        for (final field in [
          'timelineRange',
          'sourceRange',
          'linkGroupId',
          'effectIds',
        ]) {
          expect(c[field], old[field]);
        }
      }
      final unchanged = w.current.hash;
      g = await begin(60, 40);
      await g.moveTo(p(60));
      await tester.pump();
      await g.up();
      await tester.pumpAndSettle();
      expect(w.current.hash, unchanged);
      g = await begin(60, 96);
      FocusManager.instance.primaryFocus!.unfocus();
      await tester.pump();
      await g.up();
      await tester.pumpAndSettle();
      expect(w.current.hash, unchanged);
      g = await begin(60, 96);
      final ancestor = tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position;
      ancestor.jumpTo(ancestor.pixels + 20);
      await tester.pump();
      await g.up();
      await tester.pumpAndSettle();
      expect(w.current.hash, unchanged);
      await show();
      g = await begin(60, 96);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      await g.up();
      await tester.pumpAndSettle();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      expect(w.current.hash, unchanged);
      // Real slider event changes rendered scale; hardware scroll changes measured content offset.
      final slider = find.byKey(const Key('pointer-zoom'));
      await tester.tapAt(
        tester.getTopLeft(slider) +
            Offset(tester.getSize(slider).width * .6, 24),
      );
      await tester.pumpAndSettle();
      final zoom = tester.widget<Slider>(slider).value.round();
      expect(zoom, greaterThan(100));
      await tester.sendEventToBinding(
        PointerScrollEvent(position: p(60), scrollDelta: const Offset(25, 0)),
      );
      await tester.pumpAndSettle();
      final horizontal = tester.state<ScrollableState>(
        find
            .descendant(
              of: find.byKey(const Key('pointer-scrollbar')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(horizontal.position.pixels, greaterThan(0));
      final base = w.current;
      g = await begin(60, zoom / 2);
      await g.up();
      await waitFor(() => w.current.revision == base.revision + BigInt.one);
      for (final c in moveVideos(w.current)) {
        final old = moveVideos(base).singleWhere((o) => o['id'] == c['id']);
        expect(
          Q.fromJson(c['timelineRange']['start']) -
              Q.fromJson(old['timelineRange']['start']),
          Q.of(1, 2),
        );
      }
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(
        () => adoptMoveMetadata(w, dir, (d) {
          d['sequences'][0]['tracks'][1]['locked'] = true;
        }),
      );
      await tester.pumpWidget(FoundationApp(workspace: w));
      await show();
      final locked = w.current.hash;
      g = await begin(60, 96);
      await g.up();
      await tester.pumpAndSettle();
      expect(w.current.hash, locked);
      expect(find.text('FIELD_LOCKED'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(
        () => adoptMoveMetadata(w, dir, (d) {
          d['sequences'][0]['tracks'][1]['locked'] = false;
        }),
      );
      await tester.pumpWidget(FoundationApp(workspace: w));
      await show();
      final beforeCollision = w.current.hash;
      // A valid positive candidate, then a collision, cannot release the earlier ghost.
      final start = p(260);
      g = await begin(260, 100);
      await g.moveTo(start - const Offset(50, 0));
      await tester.pump();
      expect(find.text('COLLISION'), findsOneWidget);
      await g.up();
      await tester.pumpAndSettle();
      expect(w.current.hash, beforeCollision);
      expect(find.byKey(const Key('pointer-native-ghost')), findsNothing);
      // Fence acquired by another DB connection AFTER a valid native ghost.
      g = await begin(260, 100);
      await waitFor(
        () =>
            find.byKey(const Key('pointer-native-ghost')).evaluate().isNotEmpty,
      );
      final repository = DocumentRepository.open(
        '${dir.path}/db',
        w.current.namespace,
      );
      repository.acquireWriter(
        w.projectId,
        'fixture-other',
        expectedEpoch: repository.writerEpoch(w.projectId),
      );
      await g.up();
      await waitFor(
        () =>
            find.byKey(const Key('pointer-gesture-active')).evaluate().isEmpty,
      );
      expect(find.text('WRITER_FENCED'), findsOneWidget);
      expect(w.current.hash, beforeCollision);
      w.openDemo();
      repository.close();
      g = await begin(260, 100);
      await waitFor(
        () =>
            find.byKey(const Key('pointer-native-ghost')).evaluate().isNotEmpty,
      );
      w.rename(
        'fixture external revision',
        expectedRevision: w.current.revision,
      );
      final externalHash = w.current.hash;
      await g.up();
      await waitFor(
        () =>
            find.byKey(const Key('pointer-gesture-active')).evaluate().isEmpty,
      );
      expect(w.current.hash, externalHash);
      expect(find.byKey(const Key('pointer-native-ghost')), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(() => w.closeAsync());
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
  testWidgets(
    'REAL pointer dissolve endpoint refuses; selected pair preserves exact handles and cut',
    (tester) async {
      final dir = Directory.systemTemp.createTempSync('pointer-dissolve-');
      final w = openMoveWorkspace(dir);
      addTearDown(() async {
        w.close();
        dir.deleteSync(recursive: true);
        await tester.binding.setSurfaceSize(null);
      });
      await tester.binding.setSurfaceSize(const Size(1100, 1700));
      await tester.runAsync(() => installDissolveFixture(w, dir));
      final ids = moveVideos(w.current).map((c) => c['id'] as String).toList();
      w.setDissolve(
        ids.first,
        ids.last,
        Q.of(1, 5),
        Q.of(1, 5),
        expectedRevision: w.current.revision,
      );
      final before = w.current;
      await tester.pumpWidget(FoundationApp(workspace: w));
      final zoom = find.byKey(const Key('pointer-zoom'));
      await tester.scrollUntilVisible(
        zoom,
        250,
        scrollable: find.byType(Scrollable).first,
        maxScrolls: 100,
      );
      await Scrollable.ensureVisible(tester.element(zoom), alignment: .5);
      await tester.pumpAndSettle();
      Offset p(double x) =>
          tester.getTopLeft(find.byKey(const Key('pointer-surface'))) +
          Offset(x, 60);
      var g = await tester.startGesture(p(60));
      await g.moveTo(p(156));
      await tester.pump();
      await g.up();
      await tester.pumpAndSettle();
      expect(w.current.hash, before.hash);
      expect(find.text('TRANSITION_MOVE_REQUIRES_BOTH'), findsOneWidget);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.tapAt(p(160));
      await tester.pump();
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      g = await tester.startGesture(p(60));
      await g.moveTo(p(160));
      await tester.pump();
      await g.up();
      for (var i = 0; i < 300 && w.current.hash == before.hash; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(w.current.revision, before.revision + BigInt.one);
      final t = w.current.toJson()['transitions'][0],
          old = before.toJson()['transitions'][0];
      expect(Q.fromJson(t['cut']), Q.of(2));
      expect(t['before'], old['before']);
      expect(t['after'], old['after']);
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(() => w.closeAsync());
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
