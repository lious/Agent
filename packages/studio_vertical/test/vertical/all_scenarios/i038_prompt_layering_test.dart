import 'package:studio_contracts/studio_contracts.dart';
import 'package:studio_vertical/studio_vertical.dart';
import 'package:test/test.dart';

/// Increment 2.47 official I-038 leftover s8m prompt-layering and
/// override bound. This file does not start quote/apply, paid
/// generation, or SQL vertical.v1, does not invent motion capture or
/// new child-related surfaces, does not invent a PlanGraph
/// manual-lock API, does not mark I-037 or I-038 complete, and does
/// not rewrite the Increment 2.42–2.46 suites or the frozen I-036
/// fts5Enabled==false assertions.
Matcher code(String c) =>
    throwsA(isA<StudioException>().having((e) => e.code, 'code', c));

const templateV1 =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
const templateV2 =
    'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';

PromptLayerRequest request({
  String currentTemplateHash = templateV2,
  String filmContract = 'marketing，交付12秒，9:16',
  String narrative = '本镜只写商品外观',
  String visibleAction = '桌面上的水瓶缓慢旋转',
  List<String> shotCharacterIds = const ['product-a'],
  bool softCameraIntent = false,
  String? requestedNegative,
  bool profileSupportsNegative = false,
  String? positiveRewrite,
  int? seed,
  String userText = '',
  bool userDeclaresProviderField = false,
  bool userDeclaresTool = false,
  bool hasEvalOrDynamicTemplate = false,
  bool templateBindsSecretOrEndpoint = false,
  String? rawOverride,
  String? overrideBaseTemplateHash,
  OverrideDecision overrideDecision = OverrideDecision.undecided,
  bool parameterOutOfRange = false,
  String? lockedCaption,
  String? modelSuggestedCaption,
  String? confirmedPrice,
  bool inferredAsConfirmedFact = false,
  bool ignoreRulesInReferenceFile = false,
  bool rightsRevoked = false,
}) => PromptLayerRequest(
  currentTemplateHash: currentTemplateHash,
  filmContract: filmContract,
  narrative: narrative,
  visibleAction: visibleAction,
  shotCharacterIds: shotCharacterIds,
  softCameraIntent: softCameraIntent,
  requestedNegative: requestedNegative,
  profileSupportsNegative: profileSupportsNegative,
  positiveRewrite: positiveRewrite,
  seed: seed,
  userText: userText,
  userDeclaresProviderField: userDeclaresProviderField,
  userDeclaresTool: userDeclaresTool,
  hasEvalOrDynamicTemplate: hasEvalOrDynamicTemplate,
  templateBindsSecretOrEndpoint: templateBindsSecretOrEndpoint,
  rawOverride: rawOverride,
  overrideBaseTemplateHash: overrideBaseTemplateHash,
  overrideDecision: overrideDecision,
  parameterOutOfRange: parameterOutOfRange,
  lockedCaption: lockedCaption,
  modelSuggestedCaption: modelSuggestedCaption,
  confirmedPrice: confirmedPrice,
  inferredAsConfirmedFact: inferredAsConfirmedFact,
  ignoreRulesInReferenceFile: ignoreRulesInReferenceFile,
  rightsRevoked: rightsRevoked,
);

void main() {
  test('s8m five-layer compile keeps official order, limits this-shot characters, surfaces SOFT_CAMERA_CONTROL, and does not claim prompt-guaranteed edits, promote inferred facts, or submit', () {
    final compiler = PromptLayerCompiler();
    final program = compiler.compile(
      request(
        shotCharacterIds: ['product-a', 'char-1'],
        softCameraIntent: true,
        seed: 7,
        ignoreRulesInReferenceFile: true,
        lockedCaption: '轻装也从容',
        modelSuggestedCaption: '模型想改的字幕',
      ),
    );
    expect(program.layers.map((l) => l.kind), PromptLayerKind.values);
    expect(program.prompt.contains('不把整片叙事塞进单镜'), isTrue);
    expect(program.prompt.contains('本镜叙事'), isTrue);
    expect(program.prompt.contains('char-1'), isTrue);
    expect(program.prompt.contains('确定性EditPlan'), isTrue);
    expect(program.prompt.contains('相似性线索'), isTrue);
    expect(program.prompt.contains('轻装也从容'), isTrue);
    expect(program.prompt.contains('模型想改的字幕'), isFalse);
    expect(program.prompt.contains('不修改工具权限'), isTrue);
    expect(program.softWarnings, [softCameraControl]);
    expect(program.seed, 7);
    expect(program.seedClaimsCrossModelConsistency, isFalse);
    expect(program.promptGuaranteesDeterministicEdit, isFalse);
    expect(program.inferredPromotedToFact, isFalse);
    expect(program.privilegeEscalated, isFalse);
    expect(program.usedEval, isFalse);
    expect(program.compiledHash, hasLength(64));
    expect(program.submitted, isFalse);
    expect(program.documentWrites, 0);
    expect(compiler.documentWrites, 0);

    expect(
      () => compiler.compile(
        request(shotCharacterIds: ['c1', 'c2', 'c3', 'c4', 'c5', 'c6']),
      ),
      code(slotCount),
    );
  });

  test('an undecided stale override is OVERRIDE_REBASE_REQUIRED; keepUserVersion and itemizedDiff do not submit; over-length and out-of-range parameters are refused without silent truncation', () {
    final compiler = PromptLayerCompiler();
    expect(
      () => compiler.compile(
        request(
          rawOverride: '用户保留版正文',
          overrideBaseTemplateHash: templateV1,
          overrideDecision: OverrideDecision.undecided,
        ),
      ),
      code(overrideRebaseRequired),
    );

    final kept = compiler.compile(
      request(
        rawOverride: '用户保留版正文',
        overrideBaseTemplateHash: templateV1,
        overrideDecision: OverrideDecision.keepUserVersion,
      ),
    );
    expect(kept.rawOverride, '用户保留版正文');
    expect(kept.layers.first.text, '用户保留版正文');
    expect(kept.baseTemplateHash, templateV1);
    expect(kept.submitted, isFalse);

    final diff = compiler.compile(
      request(
        rawOverride: '用户保留版正文',
        overrideBaseTemplateHash: templateV1,
        overrideDecision: OverrideDecision.itemizedDiff,
      ),
    );
    expect(diff.itemizedDiff, isNotEmpty);
    expect(diff.submitted, isFalse);
    expect(diff.documentWrites, 0);

    final recompiled = compiler.compile(
      request(
        rawOverride: '用户保留版正文',
        overrideBaseTemplateHash: templateV1,
        overrideDecision: OverrideDecision.recompile,
      ),
    );
    expect(recompiled.layers.first.text.contains('全片合同'), isTrue);
    expect(recompiled.baseTemplateHash, templateV2);
    expect(recompiled.submitted, isFalse);

    expect(
      () => compiler.compile(request(parameterOutOfRange: true)),
      code(parameterRange),
    );
    expect(
      () => compiler.compile(request(filmContract: 'x' * 10001)),
      code(promptTooLong),
    );
    expect(compiler.documentWrites, 0);
  });

  test('unsupported negative, user-declared tools, eval, secret bindings, inferred facts, revoked rights, and a locked caption price conflict are refused and do not submit or escalate privilege', () {
    final compiler = PromptLayerCompiler();
    expect(
      () => compiler.compile(request(requestedNegative: 'text overlay')),
      code(capabilityUnsupported),
    );
    expect(
      () => compiler.compile(request(userDeclaresTool: true)),
      code(toolNotAllowed),
    );
    expect(
      () => compiler.compile(request(userDeclaresProviderField: true)),
      code(toolNotAllowed),
    );
    expect(
      () => compiler.compile(request(hasEvalOrDynamicTemplate: true)),
      code(unsupportedEditTechnique),
    );
    expect(
      () => compiler.compile(request(templateBindsSecretOrEndpoint: true)),
      code(unsupportedEditTechnique),
    );
    expect(
      () => compiler.compile(request(inferredAsConfirmedFact: true)),
      code(unconfirmedFact),
    );
    expect(
      () => compiler.compile(request(rightsRevoked: true)),
      code(rightsRequired),
    );
    expect(
      () => compiler.compile(
        request(lockedCaption: '轻装也从容 79元', confirmedPrice: '69'),
      ),
      code(factBindingConflict),
    );

    final rewritten = compiler.compile(
      request(requestedNegative: 'text overlay', positiveRewrite: '保持画面无文字'),
    );
    expect(rewritten.unsupportedFields, ['negative']);
    expect(rewritten.prompt.contains('text overlay'), isFalse);
    expect(rewritten.prompt.contains('保持画面无文字'), isTrue);
    expect(rewritten.privilegeEscalated, isFalse);
    expect(rewritten.submitted, isFalse);
    expect(compiler.documentWrites, 0);
  });
}
