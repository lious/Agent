// New App-owner/widget acceptance only. Real importer, public fixture bytes;
// controlled sources are NOT GTK/browser qualification.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' show SemanticsAction;

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:studio_sdk/studio_sdk.dart';
import 'package:studio_assets/studio_signed_skill_import.dart';
import 'package:studio_assets/craft/signed_import/app_session.dart';
import 'package:studio_assets/craft/signed_import/source_capture.dart';
import 'package:studio_demo/skill_import_panel.dart';

import '../../../packages/studio_assets/test/skills/signed_import/fixture.dart'
    as fixtures;

SodiumVerifier backend() {
  final lock = jsonDecode(
    File('../../packages/studio_assets/third_party/sodium/backend-lock.json')
        .readAsStringSync(),
  );
  return SodiumVerifier.loadTrusted(lock['devBinary'], lock['devBinarySha256']);
}

void main() {
  late AppProfile profile;
  late Namespace ns;
  late BuildTimeSignaturePolicy policy;
  late ImportAppSnapshot app;
  ImportAppSnapshot snapshot({
    bool confident = true,
    int now = 1000,
    Set<String> grants = const {},
    bool rollback = false,
  }) => ImportAppSnapshot(
    profile: profile,
    namespace: ns.toJson(),
    policy: policy,
    nowSeconds: now,
    clockConfident: confident,
    clockRollback: rollback,
    installedAllowlist: grants,
    sessionGrant: grants,
    branchScope: grants,
  );
  setUp(() {
    profile = AppProfile(
      appId: 'studio',
      region: 'local',
      features: {'project.metadata'},
    );
    ns = Namespace('studio', 'test', 'local');
    policy = BuildTimeSignaturePolicy.disabled(profile, ns);
    app = snapshot();
  });
  AppImportSession session() => AppImportSession(
    currentApp: () => app,
    capture: SkillSourceCapture(),
    changed: () {},
  );
  Future<FilmSkillRepository> repository(
    ImportAppSnapshot Function() live,
    ImportUserActionPort actions,
  ) async => FilmSkillRepository(backend(), live, actions);
  test('real owner initializes once, previews then explicit ack is non-authorizing and one-shot', () async {
    final s = session();
    expect(s.canChoose, false);
    await s.initialize(repository);
    final bytes = fixtures.PackFixture().envelope([]);
    await s.choose(() async => bytes);
    expect(s.state, 'preview');
    expect(s.report!.trustState, 'unsignedUntrusted');
    expect(s.canAcknowledge, true);
    expect(s.report!.documentWrites, 0);
    expect(s.report!.executionAuthority, false);
    s.acknowledge();
    expect(s.state, 'acknowledged');
    expect(s.report, null);
    expect(s.status, contains('executionAuthority=false'));
    final status = s.status;
    s.acknowledge();
    expect(s.status, status);
    s.dispose();
  });
  for (final drift in [
    'profile',
    'policy',
    'namespace',
    'grants',
    'clockConfidence',
    'rollback',
    'backwardTime',
  ]) {
    test('real typed comparator refuses $drift and retires preview', () async {
      final s = session();
      await s.initialize(repository);
      await s.choose(() async => fixtures.PackFixture().envelope([]));
      switch (drift) {
        case 'profile':
          profile = AppProfile(appId: 'studio', region: 'other', features: {});
          app = snapshot();
        case 'policy':
          policy = BuildTimeSignaturePolicy.disabled(profile, ns);
          app = snapshot();
        case 'namespace':
          ns = Namespace('studio', 'test', 'other');
          app = snapshot();
        case 'grants':
          app = snapshot(grants: {'project.read'});
        case 'clockConfidence':
          app = snapshot(confident: false);
        case 'rollback':
          app = snapshot(rollback: true);
        case 'backwardTime':
          app = snapshot(now: 999);
      }
      s.refresh();
      expect(s.state, 'invalidated');
      expect(s.report, null);
      expect(s.canAcknowledge, false);
      expect(s.canChoose, false);
      s.dispose();
    });
  }
  test('owner retirement precedes ABA publication and cannot revive', () async {
    final s = session();
    await s.initialize(repository);
    s.retire();
    final old = app;
    app = snapshot(grants: {'project.read'});
    app = old;
    expect(s.canChoose, false);
    expect(s.fence(), false);
    s.dispose();
  });
  test('retirement during actual async source awaits prevents importing late bytes', () async {
    final s = session();
    await s.initialize(repository);
    final selected = Completer<SkillSourceReader?>();
    final out = s.choose(
      () => s.capture.choose(
        () => SkillSourceSelection(selected.future),
        currentAppStillValid: s.fence,
        onSelected: s.reading,
      ),
    );
    s.retire();
    selected.complete(null);
    await out;
    expect(s.report, null);
    expect(s.state, 'invalidated');
    s.dispose();
  });
  test(
    'backend startup failure is terminal with no unsigned fallback',
    () async {
      final s = session();
      await s.initialize((_, _) async => throw StateError('private path'));
      expect(s.state, 'unavailable');
      expect(s.canChoose, false);
      expect(s.status, isNot(contains('private')));
      s.dispose();
    },
  );
  test('retired while backend starts cannot publish ready', () async {
    final s = session(), gate = Completer<void>();
    final starting = s.initialize((live, actions) async {
      await gate.future;
      return repository(live, actions);
    });
    s.retire();
    gate.complete();
    await starting;
    expect(s.state, 'invalidated');
    expect(s.canChoose, false);
    s.dispose();
  });
  test(
    'invalid signature is refused in owner without unsigned retry',
    () async {
      final s = session();
      await s.initialize(repository);
      final bad = fixtures.PackFixture().envelope(
        [],
        extras: {
          'signatures': [
            {'keyid': 'hint', 'sig': base64.encode(List.filled(64, 0))},
          ],
        },
      );
      await s.choose(() async => bad);
      expect(s.state, 'ready');
      expect(s.report, null);
      expect(s.canAcknowledge, false);
      s.dispose();
    },
  );
  testWidgets(
    'actual App widgets literal bounded text, full identity, accessibility ack, and no auto acknowledgment',
    (tester) async {
      final semantics = tester.ensureSemantics();

      final pack = fixtures.PackFixture();
      (pack.film['license'] as Map<String, dynamic>)['attributionText'] =
          '${List.filled(300, '😀').join()}<script>bad()</script>';
      final bytes = pack.envelope([]);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SkillImportPanel(
                currentApp: () => app,
                createRepository: repository,
                chooseSource: (capture, guard, selected) {
                  expect(guard(), true);
                  selected();
                  return Future.value(bytes);
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('skill-choose')));
      await tester.pumpAndSettle();
      expect(find.text('trustState: unsignedUntrusted'), findsOneWidget);
      expect(find.textContaining('[truncated]'), findsWidgets);
      expect(find.textContaining('missingTools'), findsOneWidget);
      expect(find.textContaining('envelopeHash:'), findsOneWidget);
      expect(find.textContaining('executionAuthority=false'), findsOneWidget);
      final ack = find.byKey(const Key('skill-acknowledge'));
      await tester.ensureVisible(ack);
      await tester.pumpAndSettle();
      final node = tester.getSemantics(ack);
      expect(node.getSemanticsData().hasAction(SemanticsAction.tap), true);
      node.owner!.performAction(node.id, SemanticsAction.tap);
      await tester.pumpAndSettle();
      expect(find.textContaining('Preview acknowledged only;'), findsOneWidget);
      expect(find.textContaining('trustState:'), findsNothing);
      expect(tester.widget<FilledButton>(ack).onPressed, null);
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), null);
      semantics.dispose();
    },
  );
  testWidgets(
    'actual default unknown clock disables acknowledgment and discard clears target',
    (tester) async {
      app = snapshot(confident: false);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SkillImportPanel(
                currentApp: () => app,
                createRepository: repository,
                chooseSource: (capture, guard, selected) {
                  selected();
                  return Future.value(fixtures.PackFixture().envelope([]));
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('skill-choose')));
      await tester.pumpAndSettle();
      expect(find.text('trustState: needsReview'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('skill-acknowledge')))
            .onPressed,
        null,
      );
      await tester.tap(find.byKey(const Key('skill-dismiss')));
      await tester.pumpAndSettle();
      expect(find.textContaining('trustState:'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'isolated public-root verified report stays preview until separate widget action',
    (tester) async {
      final previous = Directory.current;
      late fixtures.FixtureSigner signer;
      try {
        Directory.current = '../../packages/studio_assets';
        signer = fixtures.FixtureSigner(73);
      } finally {
        Directory.current = previous;
      }
      try {
        policy = BuildTimeSignaturePolicy(fixtures.policy([signer]));
        app = snapshot();
        final pack = fixtures.PackFixture();
        pack.film['title'] = '<script>literalFixture()</script>';
        final bytes = pack.envelope([signer]);
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: SkillImportPanel(
                  currentApp: () => app,
                  createRepository: repository,
                  chooseSource: (capture, guard, selected) {
                    selected();
                    return Future.value(bytes);
                  },
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('skill-choose')));
        await tester.pumpAndSettle();
        expect(find.text('trustState: verified'), findsOneWidget);
        expect(
          find.text('title: <script>literalFixture()</script>'),
          findsOneWidget,
        );
        expect(find.textContaining('Preview acknowledged only;'), findsNothing);
        final ack = find.byKey(const Key('skill-acknowledge'));
        await tester.ensureVisible(ack);
        await tester.pumpAndSettle();
        await tester.tap(ack);
        await tester.pumpAndSettle();
        expect(
          find.textContaining('Preview acknowledged only;'),
          findsOneWidget,
        );
        expect(tester.widget<FilledButton>(ack).onPressed, null);
        await tester.pumpWidget(const SizedBox());
      } finally {
        signer.dispose();
      }
    },
  );
  testWidgets(
    'App cancel widget stays fail-closed while selected source is pending',
    (tester) async {
      final gate = Completer<SkillSourceReader?>();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SkillImportPanel(
                currentApp: () => app,
                createRepository: repository,
                chooseSource: (capture, guard, selected) => capture.choose(
                  () => SkillSourceSelection(gate.future),
                  currentAppStillValid: guard,
                  onSelected: selected,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('skill-choose')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('skill-cancel')));
      await tester.pump();
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('skill-choose')))
            .onPressed,
        null,
      );
      gate.complete(null);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('skill-choose')))
            .onPressed,
        isNotNull,
      );
      expect(find.textContaining('trustState:'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'actual owner identity switch and ABA restoration retire equal-scope preview',
    (tester) async {
      final original = Object();
      var identity = original;
      Widget view() => MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: SkillImportPanel(
              ownerIdentity: identity,
              currentApp: () => app,
              createRepository: repository,
              chooseSource: (capture, guard, selected) {
                selected();
                return Future.value(fixtures.PackFixture().envelope([]));
              },
            ),
          ),
        ),
      );
      await tester.pumpWidget(view());
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('skill-choose')));
      await tester.pumpAndSettle();
      expect(find.text('trustState: unsignedUntrusted'), findsOneWidget);
      identity = Object();
      await tester.pumpWidget(view());
      await tester.pumpAndSettle();
      expect(find.textContaining('trustState:'), findsNothing);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('skill-choose')))
            .onPressed,
        null,
      );
      identity = original;
      await tester.pumpWidget(view());
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('skill-choose')))
            .onPressed,
        null,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );
}
