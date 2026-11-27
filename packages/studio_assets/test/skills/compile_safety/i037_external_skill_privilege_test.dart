import 'package:studio_assets/studio_assets.dart';
import 'package:studio_contracts/studio_contracts.dart';
import 'package:studio_document/studio_document.dart';
import 'package:test/test.dart';

/// Increment 2.41 official I-037 leftover 「外部技能不能提权/绕审批」
/// at the already-specified s8f import/execute bound. This file does
/// not invent an executable-script privilege path, a signed-pack
/// trust-chain importer, production FTS/RAG, hard physical camera
/// control, or a new I-008 effect plugin, and does not rewrite the
/// Increment 2.38 / 2.39 / 2.40 suites or the frozen I-036
/// fts5Enabled==false assertions.
Matcher code(String c) =>
    throwsA(isA<StudioException>().having((e) => e.code, 'code', c));

const hashA =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

SkillPackage lumaSkill() => SkillPackage(
  id: 'skill-ext',
  version: '1.0.0',
  contentHash: hashA,
  contentType: filmCraftContentType,
  pluginType: lumaWipeEffectType,
  pluginVersion: lumaWipePluginVersion,
);

ExternalSkillRequest request({
  bool signed = false,
  bool userConfirmed = false,
  bool claimedApproved = false,
  List<String> requiredTools = const ['project.proposeEdit'],
  List<ExternalSkillStep> steps = const [],
  bool introducesUnreviewedOperator = false,
  bool hasRemoteRef = false,
  bool hasDynamicCode = false,
  bool hasShellStep = false,
  bool hasNetworkUrlTool = false,
  bool hasInstallModelStep = false,
  String pluginType = lumaWipeEffectType,
}) => ExternalSkillRequest(
  skillId: 'skill-ext',
  contentHash: hashA,
  pluginType: pluginType,
  introducesUnreviewedOperator: introducesUnreviewedOperator,
  requiredTools: requiredTools,
  steps: steps,
  signed: signed,
  userConfirmed: userConfirmed,
  claimedApproved: claimedApproved,
  hasRemoteRef: hasRemoteRef,
  hasDynamicCode: hasDynamicCode,
  hasShellStep: hasShellStep,
  hasNetworkUrlTool: hasNetworkUrlTool,
  hasInstallModelStep: hasInstallModelStep,
);

SkillExecutionScope grant({
  Set<String> installed = const {
    'stage.proposeShot',
    'project.proposeEdit',
    'media.analyze',
  },
  Set<String> session = const {'project.proposeEdit', 'media.analyze'},
  Set<String> branch = const {'project.proposeEdit'},
}) => SkillExecutionScope(
  installedAllowlist: installed,
  sessionGrant: session,
  branchScope: branch,
);

void main() {
  test('an unsigned external skill can be previewed as untrusted knowledge and does not add tools or write a project', () {
    final compiler = CraftSkillCompiler();
    final preview = compiler.previewExternalSkill(request());
    expect(preview.untrusted, isTrue);
    expect(preview.addedTools, isEmpty);
    expect(preview.documentWrites, 0);
    expect(compiler.documentWrites, 0);
    expect(preview.requiredApprovals, ['userConfirm']);
    expect(preview.skillSnapshotHash, hashA);

    final signedPreview = compiler.previewExternalSkill(request(signed: true));
    expect(signedPreview.untrusted, isFalse);
    expect(signedPreview.addedTools, isEmpty);
    expect(signedPreview.requiredApprovals, ['userConfirm']);
  });

  test('a skill signature or claimedApproved flag is not user approval; execute still requires confirmation', () {
    final compiler = CraftSkillCompiler();
    final scope = grant();
    expect(
      () => compiler.compileExternalSkill(
        skill: lumaSkill(),
        request: request(signed: true, claimedApproved: true),
        scope: scope,
      ),
      code(skillApprovalRequired),
    );
    expect(compiler.documentWrites, 0);

    final proposal = compiler.compileExternalSkill(
      skill: lumaSkill(),
      request: request(
        signed: true,
        claimedApproved: true,
        userConfirmed: true,
      ),
      scope: scope,
    );
    expect(proposal.documentWrites, 0);
    expect(compiler.documentWrites, 0);
    expect(proposal.inverseKind, 'restoreSnapshot');
    expect(proposal.operator.enabled, isTrue);
  });

  test('a skill cannot enlarge the tool grant; shell, remote ref, network URL, dynamic code, and model-install steps are refused', () {
    final compiler = CraftSkillCompiler();
    final scope = grant();
    expect(
      () => compiler.compileExternalSkill(
        skill: lumaSkill(),
        request: request(
          userConfirmed: true,
          requiredTools: ['project.proposeEdit', 'media.analyze'],
        ),
        scope: scope,
      ),
      code(skillToolNotAllowed),
    );
    expect(scope.allowedTools, {'project.proposeEdit'});
    expect(compiler.documentWrites, 0);

    expect(
      () => compiler.previewExternalSkill(request(hasShellStep: true)),
      code('UNSUPPORTED_EDIT_TECHNIQUE'),
    );
    expect(
      () => compiler.previewExternalSkill(request(hasRemoteRef: true)),
      code('UNSUPPORTED_EDIT_TECHNIQUE'),
    );
    expect(
      () => compiler.previewExternalSkill(request(hasNetworkUrlTool: true)),
      code('UNSUPPORTED_EDIT_TECHNIQUE'),
    );
    expect(
      () => compiler.previewExternalSkill(request(hasDynamicCode: true)),
      code('UNSUPPORTED_EDIT_TECHNIQUE'),
    );
    expect(
      () => compiler.previewExternalSkill(request(hasInstallModelStep: true)),
      code('UNSUPPORTED_EDIT_TECHNIQUE'),
    );
    expect(
      () => compiler.previewExternalSkill(request(requiredTools: ['shell'])),
      code('UNSUPPORTED_EDIT_TECHNIQUE'),
    );
    expect(
      () => compiler.previewExternalSkill(
        request(introducesUnreviewedOperator: true),
      ),
      code('UNSUPPORTED_EDIT_TECHNIQUE'),
    );
    final tooMany = [
      for (var i = 0; i < 17; i++)
        ExternalSkillStep(id: 'step-$i', toolId: 'project.proposeEdit'),
    ];
    expect(
      () => compiler.previewExternalSkill(request(steps: tooMany)),
      code(skillPlanInvalid),
    );
    expect(
      () => compiler.previewExternalSkill(
        request(
          steps: [
            ExternalSkillStep(
              id: 'a',
              toolId: 'project.proposeEdit',
              dependsOn: ['b'],
            ),
            ExternalSkillStep(
              id: 'b',
              toolId: 'project.proposeEdit',
              dependsOn: ['a'],
            ),
          ],
        ),
      ),
      code(skillPlanInvalid),
    );
    expect(compiler.documentWrites, 0);
  });
}
