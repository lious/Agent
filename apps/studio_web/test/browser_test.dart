@TestOn('browser')
library;

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:studio_contracts/studio_contracts.dart';
import 'package:studio_document/studio_document.dart';
import 'package:studio_harness/studio_harness.dart';
import 'package:studio_harness/builtin_compute.dart';
import 'package:studio_web/browser_store.dart';
import 'package:studio_web/main.dart';

import 'package:studio_harness/testing_fixtures.dart';

void main() {
  test('REAL Chrome IndexedDB edit/transaction ACK/idempotency/parallel CAS/reopen and exact >2^53 revisions', () async {
    final ns = Namespace('studio', 'local', 'browser-test'),
        name = 'test-${DateTime.now().microsecondsSinceEpoch}',
        a = await BrowserProjectStore.open(
          'exact-${DateTime.now().microsecondsSinceEpoch}',
          Namespace('studio', 'local', 'browser-test'),
        );
    final seed = ProjectDocument.empty(
      namespace: ns,
      projectId: 'p',
      title: 'before',
    ).withTitle('before', BigInt.parse('9007199254740993'));
    await a.openProject(seed);
    final saved = await a.edit(
      'p',
      const RenameProject('after'),
      commandId: 'rename',
      expectedRevision: seed.revision,
    );
    expect(saved.revision, BigInt.parse('9007199254740994'));
    await a.edit(
      'p',
      const RenameProject('after'),
      commandId: 'rename',
      expectedRevision: seed.revision,
    );
    expect((await a.read('p')).revision, saved.revision);
    await expectLater(
      a.edit(
        'p',
        const RenameProject('different'),
        commandId: 'rename',
        expectedRevision: seed.revision,
      ),
      throwsA(
        isA<StudioException>().having(
          (e) => e.code,
          'code',
          'IDEMPOTENCY_CONFLICT',
        ),
      ),
    );
    a.close();
    final first = await BrowserProjectStore.open(name, ns),
        second = await BrowserProjectStore.open(name, ns);
    await first.openProject(
      ProjectDocument.empty(namespace: ns, projectId: 'p', title: 'x'),
    );
    final results = await Future.wait([
      first
          .edit(
            'p',
            const RenameProject('one'),
            commandId: 'one',
            expectedRevision: BigInt.zero,
          )
          .then<Object>((p) => p, onError: (Object e) => e),
      second
          .edit(
            'p',
            const RenameProject('two'),
            commandId: 'two',
            expectedRevision: BigInt.zero,
          )
          .then<Object>((p) => p, onError: (Object e) => e),
    ]);
    expect(results.whereType<ProjectDocument>(), hasLength(1));
    expect(
      results.whereType<StudioException>().single.code,
      'REVISION_CONFLICT',
    );
    first.close();
    second.close();
    final reopened = await BrowserProjectStore.open(name, ns);
    expect((await reopened.read('p')).revision, BigInt.one);
    reopened.close();
  });
  test('REAL Chrome shared subtitle, PCM and same-session placement/lease/compute code run without dart:io or FFI', () {
    final cue = CaptionCue(
          'cue',
          TimeRange(Q.of(101, 1000), Q.of(1)),
          '你好🙂 שלום\nline',
        ),
        srt = CaptionFormats.encode(CaptionStore([cue]), CaptionFormat.srt);
    expect(
      CaptionFormats.decode(srt, CaptionFormat.srt).captions.cues.single.text,
      cue.text,
    );
    final mix = mix48k(AudioBusGraph([AudioBus(id: 'm', inputs: [])], 'm'), [
      PcmInput(
        busId: 'm',
        samples: Float32List.fromList([0.5, -0.5]),
        channels: 1,
      ),
    ]);
    expect(mix.interleavedStereo.length, 4);
    final ns = Namespace('studio', 'local', 'devices'),
        plan = HarnessPlan(
          planFixture(Namespace('studio', 'local', 'devices')),
        ),
        session = SessionRef(
          namespace: Namespace('studio', 'local', 'devices'),
          id: 'session',
        );
    expect(harnessNamespace(ns), plan.toJson()['ns']);
    expect(
      placeTask(session, plan, 'a', [
        deviceFixture('chrome', {'compute.digest'}, platform: 'web'),
      ], PlacementRequirement())!.id,
      'chrome',
    );
    expect(
      BuiltinCompute.execute(
        BuiltinCompute.pin('core.pcm-rms').cast<String, dynamic>(),
        {
          'samples': [0.5, -0.5],
        },
      )['rms'],
      0.5,
    );
    final lease = TaskLease(
      sessionId: 'session',
      nodeId: 'a',
      deviceId: 'chrome',
      planHash: plan.hash,
      inputHash: 'b' * 64,
      coordinatorBoot: 'boot',
      fence: BigInt.parse('9007199254740993'),
      cancelEpoch: BigInt.zero,
      untilMs: 1000,
    );
    expect(
      taskLeaseFromJson(lease.toJson().cast<String, dynamic>()).fence,
      lease.fence,
    );
  });
  testWidgets('REAL Chrome Flutter Web editor commits title to local storage', (
    tester,
  ) async {
    await tester.pumpWidget(const WebStudioApp());
    await tester.pumpAndSettle();
    for (
      var i = 0;
      i < 100 && find.byKey(const Key('title')).evaluate().isEmpty;
      i++
    ) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }
    expect(find.byKey(const Key('title')), findsOneWidget);
    await tester.enterText(find.byKey(const Key('title')), 'Actual web edit');
    await tester.tap(find.byKey(const Key('rename')));
    for (
      var i = 0;
      i < 100 && find.text('Revision 1').evaluate().isEmpty;
      i++
    ) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }
    expect(find.text('Revision 1'), findsOneWidget);
    expect(find.byKey(const Key('error')), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
}
