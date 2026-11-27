import 'package:studio_contracts/studio_contracts.dart';
import 'package:studio_vertical/studio_vertical.dart';
import 'package:test/test.dart';

/// Increment 2.42 official I-038 first DEV-PURE WorkflowCompiler slice.
/// Officializes a narrowly specified prompt-compiler fixture bound:
/// all six purpose verticals have one legal and one illegal fixture,
/// product facts come only from FactLedger, unauthorized subjects and
/// unsupported firstLast do not submit, and override/template conflicts
/// are not silently applied. This file does not invent paid generation,
/// SQL vertical.v1, production FTS/RAG, a PlanGraph manual-lock API,
/// or a new I-008 effect plugin, and does not mark I-037 complete.
Matcher code(String c) =>
    throwsA(isA<StudioException>().having((e) => e.code, 'code', c));

final ns = Namespace('studio-vertical', 'tenant-a', 'workspace-a');
const sku = 'sku-paper-boat';
const product = 'product-paper-boat';
const factId = 'fact-boat-1';
const subjectLan = 'subject-lan';
final now = DateTime.utc(2026, 11, 28);

FactLedger ledgerWithProduct() {
  final ledger = FactLedger();
  ledger.recordConfirmed(
    ConfirmedFact(id: factId, sku: sku, productId: product),
  );
  return ledger;
}

VerticalBrief brief({
  required String id,
  required VerticalPurpose purpose,
  required List<VerticalInputMode> inputModes,
  String? productId,
  String? scriptBindingId,
  List<String> subjectIds = const [],
  List<String> factIds = const [],
  List<SourceBinding> sourceBindings = const [],
  bool allowNewGeneration = false,
  int? seed,
  Map<String, Object?> requestedParameters = const {},
}) => VerticalBrief(
  id: id,
  namespace: ns,
  purpose: purpose,
  inputModes: inputModes,
  productId: productId,
  scriptBindingId: scriptBindingId,
  subjectIds: subjectIds,
  factIds: factIds,
  sourceBindings: sourceBindings,
  allowNewGeneration: allowNewGeneration,
  seed: seed,
  requestedParameters: requestedParameters,
);

List<SubjectRights> consented() => [
  SubjectRights(subjectId: subjectLan, portraitConsent: true),
];

void main() {
  test('all six purposes have a legal fixture; axes are not mutually exclusive; unsupported params are kept and seed does not claim cross-model consistency', () {
    final compiler = VerticalWorkflowCompiler();
    final facts = ledgerWithProduct();
    final legal = <VerticalPurpose, CompiledShot>{};

    legal[VerticalPurpose.marketing] = compiler.compile(
      brief: brief(
        id: 'brief-marketing',
        purpose: VerticalPurpose.marketing,
        inputModes: [VerticalInputMode.i2v],
        productId: product,
        factIds: [factId],
        allowNewGeneration: true,
        seed: 42,
        requestedParameters: {
          'duration': 5,
          'aspect': '9:16',
          'seed': 42,
          'negative_prompt': 'text overlay',
        },
      ),
      facts: facts,
    );
    legal[VerticalPurpose.showcase] = compiler.compile(
      brief: brief(
        id: 'brief-showcase',
        purpose: VerticalPurpose.showcase,
        inputModes: [VerticalInputMode.mediaMontage],
        productId: product,
        factIds: [factId],
        sourceBindings: [
          SourceBinding(id: 'src-front', role: SourceRole.front),
          SourceBinding(id: 'src-detail', role: SourceRole.detail),
        ],
      ),
      facts: facts,
    );
    legal[VerticalPurpose.story] = compiler.compile(
      brief: brief(
        id: 'brief-story',
        purpose: VerticalPurpose.story,
        inputModes: [VerticalInputMode.script, VerticalInputMode.i2v],
        scriptBindingId: 'script-lan-platform',
        subjectIds: [subjectLan],
        allowNewGeneration: true,
      ),
      facts: facts,
      subjects: consented(),
    );
    legal[VerticalPurpose.social] = compiler.compile(
      brief: brief(
        id: 'brief-social',
        purpose: VerticalPurpose.social,
        inputModes: [VerticalInputMode.i2v],
        allowNewGeneration: true,
      ),
      facts: facts,
    );
    legal[VerticalPurpose.tutorial] = compiler.compile(
      brief: brief(
        id: 'brief-tutorial',
        purpose: VerticalPurpose.tutorial,
        inputModes: [VerticalInputMode.mediaMontage],
      ),
      facts: facts,
    );
    legal[VerticalPurpose.musicVisual] = compiler.compile(
      brief: brief(
        id: 'brief-music',
        purpose: VerticalPurpose.musicVisual,
        inputModes: [VerticalInputMode.mediaMontage],
      ),
      facts: facts,
    );

    expect(legal.keys, VerticalPurpose.values.toSet());
    for (final shot in legal.values) {
      expect(shot.submitted, isFalse);
      expect(shot.documentWrites, 0);
      expect(shot.seedClaimsCrossModelConsistency, isFalse);
    }
    final marketing = legal[VerticalPurpose.marketing]!;
    expect(marketing.unsupportedFields, ['negative_prompt']);
    expect(marketing.requestedParameters['negative_prompt'], 'text overlay');
    expect(marketing.requestedParameters['seed'], 42);
    expect(marketing.seed, 42);
    final story = legal[VerticalPurpose.story]!;
    expect(story.inputModes, [VerticalInputMode.script, VerticalInputMode.i2v]);
    expect(compiler.documentWrites, 0);
  });

  test('product facts are taken only from FactLedger; an LLM confirmed=true claim is UNCONFIRMED_FACT and does not submit', () {
    final compiler = VerticalWorkflowCompiler();
    final empty = FactLedger();
    expect(
      () => compiler.compile(
        brief: brief(
          id: 'brief-mkt-unconfirmed',
          purpose: VerticalPurpose.marketing,
          inputModes: [VerticalInputMode.i2v],
          productId: product,
          factIds: [factId],
          allowNewGeneration: true,
        ),
        facts: empty,
        untrustedFactClaims: {factId: true},
      ),
      code(unconfirmedFact),
    );
    expect(
      () => empty.requireConfirmed(id: factId, productId: product, now: now),
      code(unconfirmedFact),
    );

    expect(
      () => compiler.compile(
        brief: brief(
          id: 'brief-mkt-noproduct',
          purpose: VerticalPurpose.marketing,
          inputModes: [VerticalInputMode.mediaMontage],
        ),
        facts: empty,
      ),
      code(unconfirmedFact),
    );

    final expired = FactLedger();
    expired.recordConfirmed(
      ConfirmedFact(
        id: factId,
        sku: sku,
        productId: product,
        expiresAt: DateTime.utc(2026, 11, 1),
      ),
    );
    expect(
      () => compiler.compile(
        brief: brief(
          id: 'brief-showcase-expired',
          purpose: VerticalPurpose.showcase,
          inputModes: [VerticalInputMode.mediaMontage],
          productId: product,
          factIds: [factId],
          sourceBindings: [
            SourceBinding(id: 'src-front', role: SourceRole.front),
            SourceBinding(id: 'src-detail', role: SourceRole.detail),
          ],
        ),
        facts: expired,
        now: now,
      ),
      code(factExpired),
    );

    final mismatch = FactLedger();
    mismatch.recordConfirmed(
      ConfirmedFact(id: factId, sku: sku, productId: 'product-other'),
    );
    expect(
      () => compiler.compile(
        brief: brief(
          id: 'brief-showcase-sku',
          purpose: VerticalPurpose.showcase,
          inputModes: [VerticalInputMode.mediaMontage],
          productId: product,
          factIds: [factId],
          sourceBindings: [
            SourceBinding(id: 'src-front', role: SourceRole.front),
            SourceBinding(id: 'src-detail', role: SourceRole.detail),
          ],
        ),
        facts: mismatch,
      ),
      code(factSkuMismatch),
    );
    expect(compiler.documentWrites, 0);
  });

  test('unauthorized subjects, unsupported firstLast, and stale overrides are refused without rewrite or submit', () {
    final compiler = VerticalWorkflowCompiler();
    final facts = ledgerWithProduct();

    expect(
      () => compiler.compile(
        brief: brief(
          id: 'brief-story-no-consent',
          purpose: VerticalPurpose.story,
          inputModes: [VerticalInputMode.text],
          subjectIds: [subjectLan],
        ),
        facts: facts,
        subjects: [
          SubjectRights(subjectId: subjectLan, portraitConsent: false),
        ],
      ),
      code(portraitConsentRequired),
    );

    CompiledShot? leaked;
    expect(() {
      leaked = compiler.compile(
        brief: brief(
          id: 'brief-social-firstlast',
          purpose: VerticalPurpose.social,
          inputModes: [VerticalInputMode.firstLast],
          allowNewGeneration: true,
          sourceBindings: [
            SourceBinding(id: 'src-first', role: SourceRole.firstFrame),
            SourceBinding(id: 'src-last', role: SourceRole.lastFrame),
          ],
        ),
        facts: facts,
      );
    }, code(capabilityUnsupported));
    expect(leaked, isNull);

    const stale =
        'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';
    expect(
      () => compiler.compile(
        brief: brief(
          id: 'brief-tutorial-override',
          purpose: VerticalPurpose.tutorial,
          inputModes: [VerticalInputMode.mediaMontage],
        ),
        facts: facts,
        override: PromptOverride(
          baseTemplateHash: stale,
          text: 'rewrite the shot',
        ),
      ),
      code(overrideRebaseRequired),
    );

    expect(
      () => compiler.compile(
        brief: brief(
          id: 'brief-music-i2v-disabled',
          purpose: VerticalPurpose.musicVisual,
          inputModes: [VerticalInputMode.i2v],
        ),
        facts: facts,
      ),
      code(generationDisabled),
    );

    // A matching override on a legal tutorial still does not submit.
    final accepted = compiler.compile(
      brief: brief(
        id: 'brief-tutorial-ok-override',
        purpose: VerticalPurpose.tutorial,
        inputModes: [VerticalInputMode.mediaMontage],
      ),
      facts: facts,
      override: PromptOverride(
        baseTemplateHash: defaultVerticalTemplateHash,
        text: 'keep hard cut',
      ),
    );
    expect(accepted.submitted, isFalse);
    expect(accepted.inputModes, [VerticalInputMode.mediaMontage]);
    expect(accepted.inputModes, isNot(contains(VerticalInputMode.i2v)));
    expect(compiler.documentWrites, 0);
  });
}
