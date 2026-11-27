import 'package:studio_assets/studio_assets.dart';
import 'package:studio_contracts/studio_contracts.dart';
import 'package:test/test.dart';

/// Increment 2.40 official I-037 leftover 「SOFT_CAMERA_CONTROL告警」
/// at the already-specified s8f camera.dollyZoom / promptSuggestion
/// bound. This file does not invent hard physical camera control or a
/// new I-008 effect plugin, does not start external-skill privilege
/// escalation, and does not rewrite the Increment 2.38 / 2.39 suites
/// or the frozen I-036 fts5Enabled==false assertions.
Matcher code(String c) =>
    throwsA(isA<StudioException>().having((e) => e.code, 'code', c));

CameraSkillMapping wanPrompt() => CameraSkillMapping(
  providerProfileId: 'wan',
  fieldPath: 'camera.dollyZoom',
  handling: CameraMappingHandling.promptSuggestion,
  parameterName: 'motionPrompt',
  warningCode: softCameraControl,
  required: false,
);

CameraSkillMapping hardApi() => CameraSkillMapping(
  providerProfileId: 'rig',
  fieldPath: 'camera.dollyZoom',
  handling: CameraMappingHandling.api,
  parameterName: 'focalLength',
  required: true,
);

void main() {
  test('camera.dollyZoom compiles to the official soft prompt and SOFT_CAMERA_CONTROL, not a digital zoom or project write', () {
    final compiler = CraftSkillCompiler();
    final proposal = compiler.compileCameraCraft(
      request: CameraCraftRequest(
        providerProfileId: 'wan',
        capabilityMappings: [wanPrompt()],
      ),
    );
    expect(compiler.documentWrites, 0);
    expect(proposal.documentWrites, 0);
    expect(proposal.softWarnings, [softCameraControl]);
    expect(proposal.shotDesignPatchGroups, [
      {
        'kind': 'promptSuggestion',
        'text': dollyZoomBackSuggestion,
        'skillId': 'camera.dollyZoom',
        'providerProfileId': 'wan',
      },
    ]);
    expect(proposal.editPatchGroups, isEmpty);
    expect(proposal.commands, isEmpty);
    expect(
      proposal.shotDesignPatchGroups.every(
        (g) =>
            g['kind'] != 'transform2d' &&
            g['kind'] != 'setEffect' &&
            g['kind'] != 'digitalZoom',
      ),
      isTrue,
    );
    expect(proposal.inverseKind, 'restoreSnapshot');

    final forward = compiler.compileCameraCraft(
      request: CameraCraftRequest(
        direction: DollyZoomDirection.forwardZoomOut,
        providerProfileId: 'wan',
        capabilityMappings: [wanPrompt()],
      ),
    );
    expect(forward.softWarnings, [softCameraControl]);
    expect(
      forward.shotDesignPatchGroups.single['text'],
      dollyZoomForwardSuggestion,
    );
    expect(forward.commands, isEmpty);
  });

  test('required hard physical camera control without capability is CAPABILITY_UNSATISFIED and does not emit digital zoom', () {
    final compiler = CraftSkillCompiler();
    expect(
      () => compiler.compileCameraCraft(
        request: CameraCraftRequest(
          providerProfileId: 'rig',
          capabilityMappings: [hardApi()],
        ),
      ),
      code(capabilityUnsatisfied),
    );
    expect(compiler.documentWrites, 0);
    expect(
      () => compiler.compileCameraCraft(
        request: CameraCraftRequest(
          providerProfileId: 'rig',
          capabilityMappings: [hardApi()],
          hasPhysicalCameraControl: false,
        ),
      ),
      code(capabilityUnsatisfied),
    );
  });

  test('a missing provider mapping is CAPABILITY_UNSATISFIED; a skill does not invent a physical camera operator', () {
    final compiler = CraftSkillCompiler();
    expect(
      () => compiler.compileCameraCraft(
        request: CameraCraftRequest(
          providerProfileId: 'unknown-model',
          capabilityMappings: [wanPrompt()],
        ),
      ),
      code(capabilityUnsatisfied),
    );
    expect(
      () => compiler.compileCameraCraft(
        request: CameraCraftRequest(
          skillId: 'camera.unknownRig',
          providerProfileId: 'wan',
          capabilityMappings: [wanPrompt()],
        ),
      ),
      code('UNSUPPORTED_EDIT_TECHNIQUE'),
    );
    expect(compiler.documentWrites, 0);
  });
}
