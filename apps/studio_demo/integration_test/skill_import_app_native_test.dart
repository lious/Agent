// TEST ENTRYPOINT ONLY. Official N01-N02 profiles; not combined G1-G5 or A6.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:studio_assets/craft/signed_import/strict_json.dart';
import 'package:studio_assets/studio_signed_skill_import.dart';
import 'package:studio_demo/import_fixture_composition.dart';
import 'package:studio_demo/skill_import_host.dart';
import 'package:studio_sdk/studio_sdk.dart';

import '../../../packages/studio_assets/test/skills/signed_import/fixture.dart'
    as fixtures;
import '../test/import_native_reader.dart';

const chooseKey = Key('skill-choose');
const ackKey = Key('skill-acknowledge');
const trustKey = Key('skill-trust');
const statusKey = Key('skill-status');
const navigateKey = Key('fixture-navigate');
const rebuildKey = Key('fixture-rebuild');
const unmountKey = Key('fixture-unmount');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final id = Platform.environment['STUDIO_NATIVE_CASE']!;
  testWidgets('official native profile $id', (tester) async {
    await runProfile(tester, id);
  });
}

Future<void> runProfile(WidgetTester tester, String id) async {
  final workspaceDir = Directory(
    Platform.environment['STUDIO_NATIVE_WORKSPACE']!,
  );
  workspaceDir.createSync(recursive: true);
  final packPath = Platform.environment['STUDIO_NATIVE_PACK']!;
  final resultPath = Platform.environment['STUDIO_NATIVE_RESULT']!;
  final helper = Platform.environment['STUDIO_NATIVE_GTK_HELPER'];
  final notes = <String, Object?>{};
  final watchEvents = <String>[];
  final subs = <StreamSubscription<FileSystemEvent>>[];

  final workspace = StudioWorkspace.open(
    profile: AppProfile(
      appId: 'studio_demo',
      region: 'local',
      features: {'project.metadata', 'media.local'},
    ),
    databasePath: '${workspaceDir.path}/app.sqlite',
    tenantId: 'local',
    workspaceId: 'default',
  );
  notes['casConfigured'] = false;
  notes['shelfConfigured'] = false;
  notes['casShelfAbsence'] = 'StudioWorkspace opened without mediaLibraryPath/mediaRootPath; no CAS/shelf root was created';

  final lifetime = ImportCompositionLifetime();
  final reader = NativeReaderController(observe: (_) {});
  final usesReader = id.startsWith('N02-read');
  final usesGtk = !usesReader;
  final showChrome = id.startsWith('N02');

  final fixture = NativeImportFixtureConfiguration(
    nowSeconds: 1000,
    clockConfident: true,
    lifetime: lifetime,
    policyForOwner: nativePolicy,
    chooseSourceForTest: usesReader ? reader.choose : null,
    readerControlsForTest: usesReader ? reader : null,
  );

  await tester.pumpWidget(
    NativeMatrixApp(
      workspace: workspace,
      fixture: fixture,
      lifetime: lifetime,
      showChrome: showChrome,
    ),
  );
  await waitReady(tester);

  notes['namespace'] = workspace.current.namespace.toJson();
  final signed = signOfficialPack(workspace, packPath);
  notes['expectedHashes'] = signed;

  final projectBefore = workspace.current.canonicalJson;
  final revisionBefore = workspace.current.revision;
  final inventoryBefore = inventory(workspaceDir);
  notes['projectRevisionBefore'] = revisionBefore.toString();
  notes['baselineUnix'] = DateTime.now().microsecondsSinceEpoch / 1e6;
  notes['protectedRoot'] = workspaceDir.path;

  await tester.runAsync(() async {
    void listen(Directory root) {
      subs.add(
        root.watch(recursive: true).listen((event) {
          if (event.path.endsWith('-shm')) return;
          watchEvents.add('${event.type} ${event.path}');
        }),
      );
    }

    listen(workspaceDir);
  });

  String? chooseFocus;
  String? ackFocus;
  try {
    if (usesReader) {
      reader.arm();
      await tester.tap(find.byKey(chooseKey));
      await tester.pump();
      await waitHeld(tester, reader);
      notes['readerInput'] = 'tester.tap Choose on armed NativeReaderController; not N01 keyboard/GTK evidence';
      if (id == 'N02-read-navigation') {
        await tester.tap(find.byKey(navigateKey));
        await tester.pumpAndSettle();
        expect(find.text('Fixture route'), findsWidgets);
        await popFixture(tester);
        await tester.pumpAndSettle();
      } else {
        await tester.tap(find.byKey(unmountKey));
        await tester.pumpAndSettle();
        expect(find.byKey(chooseKey), findsNothing);
      }
      notes['readerAfterRetirement'] = reader.snapshot;
      // Retirement cancels the capture future (outcome null) while the first
      // read stays held and busy until the test controller releases close.
      expect(reader.snapshot['outcome'], 'null');
      expect(reader.snapshot['busy'], true);
      expect(reader.snapshot['held'], true);
      expect((reader.snapshot['counts'] as Map)['closeCompleted'], isNull);
      expect((reader.snapshot['counts'] as Map)['outcomeBytes'], isNull);
      expect((reader.snapshot['counts'] as Map)['eof'], isNull);
      expect((reader.snapshot['counts'] as Map)['selections'], 1);
      reader.release();
      await tester.runAsync(() async {
        for (var i = 0; i < 80 && reader.snapshot['busy'] == true; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 50));
        }
      });
      await tester.pump();
      expect(reader.snapshot['watchdogFired'], false);
      expect(reader.snapshot['outcome'], 'null');
      expect(reader.snapshot['busy'], false);
      final counts = Map<String, int>.from(reader.snapshot['counts'] as Map);
      expect(counts['selections'], 1);
      expect(counts['selected'], 1);
      expect(counts['openStarted'], 1);
      expect(counts['lengthStarted'], 1);
      expect(counts['readStarted'], 1);
      expect(counts['outcomeNull'], 1);
      expect(counts['quiescent'], 1);
      expect(counts['closeCompleted'], 1);
      expect(counts['outcomeBytes'], isNull);
      expect(counts['eof'], isNull);
      notes['readerSnapshot'] = reader.snapshot;
    } else {
      final window = await appWindow(tester);
      notes['appWindow'] = window;
      final driver = usesGtk
          ? await tester.runAsync(
              () => Process.start('python3', [helper!, 'select', packPath]),
            )
          : null;
      Future<void>? driverOut;
      Future<String>? driverErr;
      if (driver != null) {
        driverOut = driver.stdout.drain<void>();
        driverErr = driver.stderr.transform(utf8.decoder).join();
      }
      await tabUntil(tester, window, 'skill-choose');
      chooseFocus = focusedLabel(tester);
      notes['chooseFocusKey'] = focusedKey();
      notes['chooseFocusLabel'] = chooseFocus;
      expect(chooseFocus, 'Choose skill source');
      expect(
        tester.widget<FilledButton>(find.byKey(chooseKey)).onPressed,
        isNotNull,
      );
      await xdotool(tester, ['key', '--window', window, 'Return']);
      await waitText(tester, 'trustState: verified');
      if (driver != null) {
        final helperDrain = await tester.runAsync(() async {
          final code = await driver.exitCode.timeout(
            const Duration(seconds: 25),
          );
          await driverOut;
          return <String, Object>{
            'code': code,
            'stderr': await driverErr ?? '',
          };
        });
        final helperCode = helperDrain!['code'];
        notes['gtkHelperExit'] = helperCode;
        notes['gtkHelperStderr'] = helperDrain['stderr'];
        // A late xdotool BadWindow after the dialog has already accepted the
        // file is helper cleanup, not a failed selection: the verified report
        // is already on screen.
        if (helperCode != 0 &&
            find.text('trustState: verified').evaluate().isEmpty) {
          fail(
            'GTK helper failed before a verified report: ${notes['gtkHelperStderr']}',
          );
        }
      }
      expect(find.text('trustState: verified'), findsOneWidget);
      expect(
        find.text('envelopeHash: ${signed['envelopeHash']}'),
        findsOneWidget,
      );
      expect(
        find.text('payloadHash: ${signed['payloadHash']}'),
        findsOneWidget,
      );
      expect(
        find.text('contentHash: ${signed['contentHash']}'),
        findsOneWidget,
      );
      expect(
        find.text('permissionDiffHash: ${signed['permissionDiffHash']}'),
        findsOneWidget,
      );
      expect(find.textContaining('missingTools'), findsOneWidget);
      expect(
        tester.widget<FilledButton>(find.byKey(ackKey)).onPressed,
        isNotNull,
        reason: 'verified report must not auto-acknowledge',
      );
      expect(find.textContaining('Preview acknowledged only'), findsNothing);
      notes['inputMethod'] = 'xdotool Tab/Return on actual focused Flutter control; GTK helper filled the Open File path';

      if (id == 'N02-preview-navigation') {
        await tester.tap(find.byKey(navigateKey));
        await tester.pumpAndSettle();
        expect(find.text('Fixture route'), findsWidgets);
        expect(find.text('trustState: verified'), findsNothing);
        await popFixture(tester);
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(rebuildKey));
        await tester.pumpAndSettle();
        expect(find.text('trustState: verified'), findsNothing);
        expect(
          tester.widget<FilledButton>(find.byKey(ackKey)).onPressed,
          isNull,
        );
        expect(find.textContaining('Preview acknowledged only'), findsNothing);
        notes['retirement'] = 'invalidateBeforePublication then Navigator.push; pop/rebuild did not revive';
      } else if (id == 'N02-preview-dispose') {
        await tester.tap(find.byKey(unmountKey));
        await tester.pumpAndSettle();
        expect(find.byKey(chooseKey), findsNothing);
        expect(find.text('trustState: verified'), findsNothing);
        expect(find.textContaining('Preview acknowledged only'), findsNothing);
        notes['retirement'] =
            'actual host unmount disposed the session; no late report or ack';
      } else if (id == 'N01-semantics') {
        final handle = tester.ensureSemantics();
        final node = tester.getSemantics(find.byKey(ackKey));
        final data = node.getSemanticsData();
        notes['semantics'] = {
          'id': node.id,
          'label': node.label,
          'enabled': data.flagsCollection.isEnabled.toBoolOrNull() == true,
          'hasTap': data.hasAction(SemanticsAction.tap),
          'method': 'framework-standard-semantics SemanticsAction.tap; not OS assistive-device qualification',
        };
        expect(data.hasAction(SemanticsAction.tap), isTrue);
        expect(data.flagsCollection.isEnabled.toBoolOrNull(), isTrue);
        node.owner!.performAction(node.id, SemanticsAction.tap);
        await waitText(tester, 'Preview acknowledged only');
        expect(
          find.textContaining('Preview acknowledged only'),
          findsOneWidget,
        );
        expect(find.textContaining('documentWrites=0'), findsWidgets);
        expect(find.textContaining('executionAuthority=false'), findsWidgets);
        // Repeat keyboard/pointer/semantics must not create a second summary.
        notes['focusAfterAck'] = focusedKey();
        if (focusedKey() == 'skill-acknowledge') {
          await xdotool(tester, ['key', '--window', window, 'Return']);
          await tester.pumpAndSettle();
          await xdotool(tester, ['key', '--window', window, 'space']);
          await tester.pumpAndSettle();
        }
        final after = tester.getSemantics(find.byKey(ackKey));
        final afterData = after.getSemanticsData();
        notes['semanticsAfter'] = {
          'id': after.id,
          'enabled': afterData.flagsCollection.isEnabled.toBoolOrNull() == true,
          'hasTap': afterData.hasAction(SemanticsAction.tap),
        };
        after.owner?.performAction(after.id, SemanticsAction.tap);
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(ackKey));
        await tester.pumpAndSettle();
        expect(
          find.textContaining('Preview acknowledged only'),
          findsOneWidget,
        );
        expect(
          tester.widget<FilledButton>(find.byKey(ackKey)).onPressed,
          isNull,
        );
        handle.dispose();
        notes['ackFocusLabel'] = ackFocus;
      } else {
        await tabUntil(tester, window, 'skill-acknowledge');
        ackFocus = focusedLabel(tester);
        notes['ackFocusKey'] = focusedKey();
        notes['ackFocusLabel'] = ackFocus;
        expect(ackFocus, 'Acknowledge preview only');
        final key = id == 'N01-space' ? 'space' : 'Return';
        await xdotool(tester, ['windowfocus', '--sync', window]);
        expect(focusedKey(), 'skill-acknowledge');
        await xdotool(tester, ['key', '--window', window, key]);
        await waitText(tester, 'Preview acknowledged only');
        expect(
          find.textContaining('Preview acknowledged only'),
          findsOneWidget,
        );
        expect(find.textContaining('documentWrites=0'), findsWidgets);
        expect(find.textContaining('executionAuthority=false'), findsWidgets);
        // After acknowledgment the control is disabled and usually leaves tab
        // traversal. Do not send Return/Space unless it is still the focused
        // control; otherwise Choose would legally start a new pick.
        notes['focusAfterAck'] = focusedKey();
        if (focusedKey() == 'skill-acknowledge') {
          await xdotool(tester, ['key', '--window', window, key]);
          await tester.pumpAndSettle();
        }
        await tester.tap(find.byKey(ackKey));
        await tester.pumpAndSettle();
        expect(
          find.textContaining('Preview acknowledged only'),
          findsOneWidget,
        );
        expect(
          tester.widget<FilledButton>(find.byKey(ackKey)).onPressed,
          isNull,
        );
      }
    }

    expect(workspace.current.canonicalJson, projectBefore);
    expect(workspace.current.revision, revisionBefore);
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 300));
      for (final sub in subs) {
        await sub.cancel();
      }
    });
    expect(
      watchEvents,
      isEmpty,
      reason: 'protected-root watch events: $watchEvents',
    );
    expect(inventory(workspaceDir), inventoryBefore);
    notes['watchEvents'] = watchEvents;
    notes['observationEndUnix'] = DateTime.now().microsecondsSinceEpoch / 1e6;
    notes['passed'] = true;
  } catch (e, s) {
    notes['observationEndUnix'] = DateTime.now().microsecondsSinceEpoch / 1e6;
    notes['passed'] = false;
    notes['error'] = e.toString();
    notes['stack'] = s.toString();
    notes['watchEvents'] = watchEvents;
    writeResult(resultPath, {'case': id, ...notes});
    rethrow;
  }

  writeResult(resultPath, {'case': id, ...notes});
  await tester.pumpWidget(const SizedBox());
  workspace.close();
}

void writeResult(String path, Map<String, Object?> notes) {
  Object? encode(Object? value) {
    if (value == null || value is num || value is bool || value is String) {
      return value;
    }
    if (value is BigInt) return value.toString();
    if (value is Iterable) return value.map(encode).toList();
    if (value is Map) {
      return {
        for (final entry in value.entries)
          entry.key.toString(): encode(entry.value),
      };
    }
    return value.toString();
  }

  File(path).writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert(encode(notes)),
  );
}

BuildTimeSignaturePolicy nativePolicy(
  AppProfile profile,
  Namespace namespace,
) => BuildTimeSignaturePolicy({
  'policyVersion': 'filmcraft-import-v1',
  'policyEpoch': 1,
  'appId': profile.appId,
  'namespace': namespace.toJson(),
  'threshold': 1,
  'trustedSigners': [
    {
      'publicKeyBase64': 'ebVWLo/mVPlAeLES6KmLp5AfhTrmlb7X4OORC60ElmQ=',
      'keyFingerprint': 'sha256:65b60673d6ed884bf01c2c222d82ada0740f29ac3355d6a925c81f17f47a27b8',
      'role': 'filmCraftPublisher',
      'notBefore': 10,
      'notAfter': 10000,
      'revoked': false,
    },
  ],
  'maxEnvelopeBytes': 4194304,
  'maxPayloadBytes': 2097152,
  'maxFileBytes': 1048576,
});

Map<String, String> signOfficialPack(
  StudioWorkspace workspace,
  String packPath,
) {
  final previous = Directory.current;
  Directory.current = Directory(
    '${Directory.current.path}/../../packages/studio_assets',
  );
  try {
    final signer = fixtures.FixtureSigner(1);
    final pack = fixtures.PackFixture();
    pack.film['namespace'] = workspace.current.namespace.toJson();
    pack.film['requiredTools'] = ['media.analyze'];
    pack.manifest['requiredTools'] = ['media.analyze'];
    final payload = pack.payload();
    final payloadBytes = utf8.encode(jsonEncode(payload));
    final filmBytes = utf8.encode(jsonEncode(pack.film));
    final envelope = pack.envelope([signer], content: payload);
    File(packPath).parent.createSync(recursive: true);
    File(packPath).writeAsBytesSync(envelope);
    signer.dispose();
    final tools = ['media.analyze'];
    final diff = {'requiredTools': tools, 'missingTools': tools};
    return {
      'envelopeHash': digest(envelope),
      'payloadHash': digest(payloadBytes),
      'contentHash': digest(filmBytes),
      'permissionDiffHash': digest(utf8.encode(jsonEncode(diff))),
    };
  } finally {
    Directory.current = previous;
  }
}

Map<String, String> inventory(Directory root) => {
  for (final f in root.listSync(recursive: true).whereType<File>())
    if (!f.path.endsWith('-shm')) f.path: digest(f.readAsBytesSync()),
};

Future<void> waitReady(WidgetTester tester) async {
  for (var i = 0; i < 80; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    if (find.byKey(chooseKey).evaluate().isNotEmpty &&
        tester.widget<FilledButton>(find.byKey(chooseKey)).onPressed != null) {
      return;
    }
  }
  fail('Choose never became ready');
}

Future<void> waitText(WidgetTester tester, String text) async {
  for (var i = 0; i < 160; i++) {
    if (find.text(text).evaluate().isNotEmpty ||
        find.textContaining(text).evaluate().isNotEmpty) {
      return;
    }
    await tester.pump(const Duration(milliseconds: 100));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
  }
  fail('never saw $text; status=${_textOf(tester, statusKey)}');
}

String? _textOf(WidgetTester tester, Key key) {
  if (find.byKey(key).evaluate().isEmpty) return null;
  return tester.widget<Text>(find.byKey(key)).data;
}

Future<void> waitHeld(
  WidgetTester tester,
  NativeReaderController controller,
) async {
  for (var i = 0; i < 80; i++) {
    if (controller.snapshot['held'] == true) return;
    await tester.pump(const Duration(milliseconds: 50));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
  }
  fail('controlled reader never held: ${controller.snapshot}');
}

Future<void> popFixture(WidgetTester tester) async {
  final nav = Navigator.of(tester.element(find.text('Fixture route').first));
  nav.pop();
  await tester.pumpAndSettle();
}

Future<String> appWindow(WidgetTester tester) async {
  final id = await tester.runAsync(() async {
    for (var i = 0; i < 80; i++) {
      final result = await Process.run('xdotool', [
        'search',
        '--onlyvisible',
        '--name',
        'studio_demo',
      ]);
      final stdout = result.stdout.toString().trim();
      if (result.exitCode == 0 && stdout.isNotEmpty) {
        return stdout.split('\n').last;
      }
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    throw TestFailure('Flutter App window never appeared');
  });
  return id!;
}

Future<void> xdotool(WidgetTester tester, List<String> args) async {
  await tester.runAsync(() async {
    final result = await Process.run('xdotool', args);
    if (result.exitCode != 0) {
      throw TestFailure('xdotool $args failed: ${result.stderr}');
    }
    await Future<void>.delayed(const Duration(milliseconds: 150));
  });
  await tester.pump();
}

Future<void> tabUntil(
  WidgetTester tester,
  String window,
  String want, {
  int max = 24,
  bool allowDisabled = false,
}) async {
  await xdotool(tester, ['windowfocus', '--sync', window]);
  for (var i = 0; i <= max; i++) {
    await tester.pump();
    if (focusedKey() == want) return;
    if (i == max) {
      fail(
        'focused ${focusedKey()} / ${focusedLabel(tester)} after $max tabs, wanted $want',
      );
    }
    await xdotool(tester, ['key', '--window', window, 'Tab']);
  }
}

String? focusedKey() {
  final context = FocusManager.instance.primaryFocus?.context;
  if (context == null) return null;
  if (context.widget.key is ValueKey<String>) {
    return (context.widget.key as ValueKey<String>).value;
  }
  String? found;
  context.visitAncestorElements((element) {
    final key = element.widget.key;
    if (key is ValueKey<String>) {
      found = key.value;
      return false;
    }
    return true;
  });
  return found;
}

String? focusedLabel(WidgetTester tester) {
  final key = focusedKey();
  if (key == null) return null;
  final finder = find.byKey(Key(key));
  if (finder.evaluate().isEmpty) return key;
  final texts = find.descendant(of: finder, matching: find.byType(Text));
  if (texts.evaluate().isEmpty) return key;
  return tester.widget<Text>(texts.first).data ?? key;
}

class NativeMatrixApp extends StatelessWidget {
  const NativeMatrixApp({
    super.key,
    required this.workspace,
    required this.fixture,
    required this.lifetime,
    required this.showChrome,
  });
  final StudioWorkspace workspace;
  final NativeImportFixtureConfiguration fixture;
  final ImportCompositionLifetime lifetime;
  final bool showChrome;

  @override
  Widget build(BuildContext context) => MaterialApp(
    home: NativeMatrixShell(
      workspace: workspace,
      fixture: fixture,
      lifetime: lifetime,
      showChrome: showChrome,
    ),
  );
}

class NativeMatrixShell extends StatefulWidget {
  const NativeMatrixShell({
    super.key,
    required this.workspace,
    required this.fixture,
    required this.lifetime,
    required this.showChrome,
  });
  final StudioWorkspace workspace;
  final NativeImportFixtureConfiguration fixture;
  final ImportCompositionLifetime lifetime;
  final bool showChrome;

  @override
  State<NativeMatrixShell> createState() => _NativeMatrixShellState();
}

class _NativeMatrixShellState extends State<NativeMatrixShell> {
  bool _hostMounted = true;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Column(
      children: [
        if (widget.showChrome)
          Wrap(
            spacing: 8,
            children: [
              FilledButton(
                key: navigateKey,
                onPressed: () {
                  widget.lifetime.invalidateBeforePublication();
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      settings: const RouteSettings(name: '/fixture-route'),
                      builder: (_) => Scaffold(
                        appBar: AppBar(title: const Text('Fixture route')),
                        body: const Text('Fixture route'),
                      ),
                    ),
                  );
                },
                child: const Text('Navigate fixture route'),
              ),
              FilledButton(
                key: rebuildKey,
                onPressed: () => setState(() {}),
                child: const Text('Rebuild fixture host'),
              ),
              FilledButton(
                key: unmountKey,
                onPressed: () => setState(() => _hostMounted = false),
                child: const Text('Unmount fixture host'),
              ),
            ],
          ),
        Expanded(
          child: _hostMounted
              ? SkillImportHost.testImport(
                  workspace: widget.workspace,
                  importFixture: widget.fixture,
                  wrapMaterialApp: false,
                )
              : const SizedBox.shrink(),
        ),
      ],
    ),
  );
}
