import 'package:studio_context/studio_context.dart';
import 'package:studio_contracts/studio_contracts.dart';
import 'package:test/test.dart';

Matcher throwsCode(String code) =>
    throwsA(isA<StudioException>().having((e) => e.code, 'code', code));

IntentScope projectScope() => IntentScope(ScopeKind.project, const ['proj']);

EffectiveIntentReducer moodReducer() {
  final reducer = EffectiveIntentReducer(branchId: 'branch-main');
  reducer.putBody(InputBody(id: 'body-calm', text: 'calm'));
  reducer.putBody(InputBody(id: 'body-tense', text: 'tense'));
  reducer.putBody(InputBody(id: 'body-user-new', text: 'warm-restraint'));
  return reducer;
}

void main() {
  test('s10a mood path: supersede, purge does not revive the old value, stale snapshot cannot publish', () {
    final reducer = moodReducer();
    final store = CompactionStore(reducer);
    final barrier = DeletionBarrier(reducer: reducer, store: store);

    reducer.apply(
      DeclareIntent(
        newId: 'mood1',
        scope: projectScope(),
        key: '/direction/mood',
        valueRef: 'body-calm',
        sourceTurnIds: const ['t1'],
        idempotencyKey: 'decl-mood1',
        expectedHeadSeq: 0,
      ),
    );
    reducer.apply(
      SupersedeIntent(
        oldId: 'mood1',
        oldVersion: 1,
        newId: 'mood2',
        newValueRef: 'body-tense',
        sourceTurnIds: const ['t2'],
        idempotencyKey: 'sup-mood2',
        expectedHeadSeq: 1,
      ),
    );
    expect(reducer.current('/direction/mood', projectScope())!.id, 'mood2');
    expect(reducer.intents['mood1']!.status, IntentStatus.superseded);

    final draft = store.buildDraft(id: 'snap-41');
    expect(draft.watermark, 2);
    expect(draft.privacyEpoch, 1);
    store.publish(
      draft,
      expectedHead: 2,
      expectedPrivacyEpoch: 1,
      expectedDigest: draft.intentDigest,
    );

    final report = barrier.purgeTurn('t2', bodyIds: {'body-tense'});
    expect(reducer.intents['mood2']!.status, IntentStatus.purged);
    expect(reducer.intents['mood2']!.valueRef, isNull);
    expect(reducer.current('/direction/mood', projectScope()), isNull);
    expect(reducer.intents['mood1']!.status, IntentStatus.superseded);
    expect(report.projectRevision, 22);

    expect(
      () => store.publish(
        draft,
        expectedHead: 2,
        expectedPrivacyEpoch: 1,
        expectedDigest: draft.intentDigest,
      ),
      throwsCode(snapshotStale),
    );
    expect(
      () => store.compile(snapshot: store.snapshots['snap-41']),
      throwsCode(snapshotStale),
    );

    reducer.apply(
      DeclareIntent(
        newId: 'mood3',
        scope: projectScope(),
        key: '/direction/mood',
        valueRef: 'body-user-new',
        sourceTurnIds: const ['t3'],
        idempotencyKey: 'decl-mood3',
        expectedHeadSeq: 2,
      ),
    );
    final compiled = store.compile();
    expect(compiled.values['/direction/mood'], 'warm-restraint');
    expect(compiled.intentIds, ['mood3']);
    expect(compiled.values.containsValue('calm'), isFalse);
    expect(compiled.values.containsValue('tense'), isFalse);
    expect(compiled.privacyEpoch, 2);
  });

  test('1000 events of change and delete never revive a retired constraint', () {
    final reducer = EffectiveIntentReducer(branchId: 'branch-load');
    final store = CompactionStore(reducer);
    final scope = projectScope();
    final retiredValues = <String>{};
    var expectSeq = 0;
    for (var i = 0; i < 1000; i++) {
      final bodyId = 'body-$i';
      reducer.putBody(InputBody(id: bodyId, text: 'value-$i'));
      if (i == 0) {
        reducer.apply(
          DeclareIntent(
            newId: 'intent-0',
            scope: scope,
            key: '/direction/mood',
            valueRef: bodyId,
            sourceTurnIds: ['turn-$i'],
            idempotencyKey: 'k-$i',
            expectedHeadSeq: expectSeq,
          ),
        );
        expectSeq++;
        continue;
      }
      final kind = i % 5;
      if (kind == 4) {
        final current = reducer.current('/direction/mood', scope);
        if (current != null) {
          retiredValues.add(reducer.bodies[current.valueRef]!.text!);
          reducer.apply(
            RetractIntent(
              targetId: current.id,
              targetVersion: current.version,
              idempotencyKey: 'k-$i',
              expectedHeadSeq: expectSeq,
            ),
          );
          expectSeq++;
          reducer.apply(
            DeclareIntent(
              newId: 'intent-$i',
              scope: scope,
              key: '/direction/mood',
              valueRef: bodyId,
              sourceTurnIds: ['turn-$i'],
              idempotencyKey: 'k-$i-b',
              expectedHeadSeq: expectSeq,
            ),
          );
          expectSeq++;
        }
      } else {
        final current = reducer.current('/direction/mood', scope);
        if (current != null) {
          retiredValues.add(reducer.bodies[current.valueRef]!.text!);
          reducer.apply(
            SupersedeIntent(
              oldId: current.id,
              oldVersion: current.version,
              newId: 'intent-$i',
              newValueRef: bodyId,
              sourceTurnIds: ['turn-$i'],
              idempotencyKey: 'k-$i',
              expectedHeadSeq: expectSeq,
            ),
          );
          expectSeq++;
        }
      }
    }
    final compiled = store.compile();
    final currentValue = compiled.values['/direction/mood'];
    expect(currentValue, isNotNull);
    expect(retiredValues.contains(currentValue), isFalse);
    var revived = 0;
    for (final value in retiredValues) {
      if (compiled.values['/direction/mood'] == value) revived++;
    }
    expect(revived, 0);
    for (final intent in reducer.intents.values) {
      if (intent.status == IntentStatus.superseded ||
          intent.status == IntentStatus.retracted ||
          intent.status == IntentStatus.purged) {
        expect(compiled.intentIds.contains(intent.id), isFalse);
      }
    }
  });

  test('a watermark or privacy-epoch change requires a snapshot rebuild', () {
    final reducer = moodReducer();
    final store = CompactionStore(reducer);
    reducer.apply(
      DeclareIntent(
        newId: 'mood1',
        scope: projectScope(),
        key: '/direction/mood',
        valueRef: 'body-calm',
        sourceTurnIds: const ['t1'],
        idempotencyKey: 'd1',
        expectedHeadSeq: 0,
      ),
    );
    final draft = store.buildDraft(id: 'snap-w');
    store.publish(
      draft,
      expectedHead: 1,
      expectedPrivacyEpoch: 1,
      expectedDigest: draft.intentDigest,
    );
    reducer.apply(
      SupersedeIntent(
        oldId: 'mood1',
        oldVersion: 1,
        newId: 'mood2',
        newValueRef: 'body-tense',
        sourceTurnIds: const ['t2'],
        idempotencyKey: 's2',
        expectedHeadSeq: 1,
      ),
    );
    expect(
      () => store.publish(
        draft,
        expectedHead: 1,
        expectedPrivacyEpoch: 1,
        expectedDigest: draft.intentDigest,
      ),
      throwsCode(snapshotStale),
    );
    reducer.privacyEpoch = 9;
    store.revokeStale();
    expect(
      () => store.compile(snapshot: store.snapshots['snap-w']),
      throwsCode(snapshotStale),
    );
    final rebuilt = store.buildDraft(id: 'snap-w2');
    expect(rebuilt.privacyEpoch, 9);
    expect(rebuilt.watermark, 2);
    store.publish(
      rebuilt,
      expectedHead: 2,
      expectedPrivacyEpoch: 9,
      expectedDigest: rebuilt.intentDigest,
    );
  });

  test('already-uploaded provider bodies are only reported, never claimed erased', () {
    final reducer = moodReducer();
    final store = CompactionStore(reducer);
    final barrier = DeletionBarrier(reducer: reducer, store: store);
    reducer.apply(
      DeclareIntent(
        newId: 'mood1',
        scope: projectScope(),
        key: '/direction/mood',
        valueRef: 'body-calm',
        sourceTurnIds: const ['t1'],
        idempotencyKey: 'd1',
        expectedHeadSeq: 0,
      ),
    );
    barrier.registerRemoteCopy(
      RemoteDeletionStatus(
        provider: 'cloud-text',
        requestOrFileIdRef: 'body-calm',
        state: RemoteDeletionState.notSupported,
      ),
    );
    final report = barrier.purgeTurn('t1', bodyIds: {'body-calm'});
    expect(report.remoteCopies, isNotEmpty);
    expect(
      report.remoteCopies.every((r) => !r.claimedGloballyErased),
      isTrue,
    );
    expect(
      report.remoteCopies.first.state,
      RemoteDeletionState.notSupported,
    );
    expect(
      report.warnings.any((w) => w.contains('not-guaranteed-erased')),
      isTrue,
    );
  });

  test('retract does not revive an earlier value; purged bodies cannot be restored; head conflicts do not half-write', () {
    final reducer = moodReducer();
    final store = CompactionStore(reducer);
    reducer.apply(
      DeclareIntent(
        newId: 'mood1',
        scope: projectScope(),
        key: '/direction/mood',
        valueRef: 'body-calm',
        sourceTurnIds: const ['t1'],
        idempotencyKey: 'd1',
        expectedHeadSeq: 0,
      ),
    );
    reducer.apply(
      SupersedeIntent(
        oldId: 'mood1',
        oldVersion: 1,
        newId: 'mood2',
        newValueRef: 'body-tense',
        sourceTurnIds: const ['t2'],
        idempotencyKey: 's2',
        expectedHeadSeq: 1,
      ),
    );
    reducer.apply(
      RetractIntent(
        targetId: 'mood2',
        targetVersion: 1,
        idempotencyKey: 'r2',
        expectedHeadSeq: 2,
      ),
    );
    expect(reducer.current('/direction/mood', projectScope()), isNull);
    expect(reducer.intents['mood1']!.status, IntentStatus.superseded);
    expect(store.compile().values.containsKey('/direction/mood'), isFalse);

    final restored = reducer.apply(
      RestoreIntentAsNew(
        newId: 'mood-new',
        sourceId: 'mood1',
        valueRef: 'body-calm',
        sourceTurnIds: const ['t4'],
        idempotencyKey: 'restore-explicit',
        expectedHeadSeq: 3,
      ),
    );
    expect(restored.activated, ['mood-new']);
    expect(store.compile().values['/direction/mood'], 'calm');

    DeletionBarrier(reducer: reducer, store: store)
        .purgeTurn('t1', bodyIds: {'body-calm'});
    expect(
      () => reducer.apply(
        RestoreIntentAsNew(
          newId: 'mood-purged',
          sourceId: 'mood-new',
          valueRef: 'body-calm',
          sourceTurnIds: const ['t5'],
          idempotencyKey: 'restore-purged',
          expectedHeadSeq: reducer.headSeq,
        ),
      ),
      throwsCode(purgedBodyUnrecoverable),
    );
    expect(store.compile().values.containsKey('/direction/mood'), isFalse);

    final head = reducer.headSeq;
    final digest = reducer.intentDigest();
    expect(
      () => reducer.apply(
        DeclareIntent(
          newId: 'mood-stale',
          scope: projectScope(),
          key: '/direction/tone',
          valueRef: 'body-user-new',
          sourceTurnIds: const ['t6'],
          idempotencyKey: 'stale-head',
          expectedHeadSeq: 0,
        ),
      ),
      throwsCode(intentHeadConflict),
    );
    expect(reducer.headSeq, head);
    expect(reducer.intentDigest(), digest);
    expect(reducer.intents.containsKey('mood-stale'), isFalse);

    final summary = store.compile(
      chatSummaryClaims: const ['the mood should still be tense from earlier chat'],
    );
    expect(summary.values.containsValue('tense'), isFalse);
    expect(summary.droppedClaimIds, isNotEmpty);
  });

  test('ambiguous asset references are refused and do not mutate the project', () {
    final reducer = moodReducer();
    final store = CompactionStore(reducer);
    final barrier = DeletionBarrier(reducer: reducer, store: store);
    barrier.registerAsset(AssetRef('asset-ann', 'Ann'));
    barrier.registerAsset(AssetRef('asset-bea', 'Bea'));
    expect(
      () => barrier.deleteAssetByReference('删掉她', [
        barrier.assets['asset-ann']!,
        barrier.assets['asset-bea']!,
      ]),
      throwsCode(referenceAmbiguous),
    );
    expect(barrier.assets['asset-ann']!.deleted, isFalse);
    expect(barrier.assets['asset-bea']!.deleted, isFalse);
    expect(barrier.projectRevision, 22);
  });
}
