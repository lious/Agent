import 'package:studio_assets/studio_assets.dart';
import 'package:studio_contracts/studio_contracts.dart';
import 'package:studio_document/studio_document.dart';
import 'package:test/test.dart';

/// Increment 2.38 official I-037 first DEV-PURE SkillPackage slice.
/// Officializes leftover acceptance wording 「未注册技法显式拒」 at the
/// already-specified s8f CraftSkillCompiler / RegistryBridge bound.
/// This file does not invent a new I-008 effect plugin, does not
/// rewrite i008_unsupported_edit_technique_test.dart or the frozen
/// I-036 fts5Enabled==false assertions, and does not officialize
/// J/L-cut goldens, SOFT_CAMERA_CONTROL, or external-skill privilege
/// escalation.
Matcher code(String c) =>
    throwsA(isA<StudioException>().having((e) => e.code, 'code', c));

const hashA =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

SkillPackage skill({
  required String pluginType,
  String pluginVersion = '1.0.0',
  String id = 'skill-1',
  String? shaderSource,
  String? ffmpegFilter,
}) => SkillPackage(
  id: id,
  version: '1.0.0',
  contentHash: hashA,
  contentType: filmCraftContentType,
  pluginType: pluginType,
  pluginVersion: pluginVersion,
  shaderSource: shaderSource,
  ffmpegFilter: ffmpegFilter,
);

void main() {
  test('RegistryBridge admits registered lumaWipe on cpu and refuses unregistered or disabled backends', () {
    const bridge = RegistryBridge();
    final admitted = bridge.resolve(
      pluginType: lumaWipeEffectType,
      pluginVersion: lumaWipePluginVersion,
      backend: 'cpu',
    );
    expect(admitted.enabled, isTrue);
    expect(admitted.id, lumaWipeEffectType);
    expect(admitted.requiredFeatures, [lumaWipeRequiredFeature]);

    expect(
      () => bridge.resolve(
        pluginType: lumaWipeEffectType,
        pluginVersion: lumaWipePluginVersion,
        backend: 'web',
      ),
      code('UNSUPPORTED_EDIT_TECHNIQUE'),
    );
    expect(
      () => bridge.resolve(
        pluginType: lumaWipeEffectType,
        pluginVersion: lumaWipePluginVersion,
        backend: 'gpu',
      ),
      code('UNSUPPORTED_EDIT_TECHNIQUE'),
    );
    expect(
      () => bridge.resolve(
        pluginType: 'studio.fx/maskWipe',
        pluginVersion: '1.0.0',
        backend: 'cpu',
      ),
      code('UNSUPPORTED_EDIT_TECHNIQUE'),
    );
    expect(
      () => bridge.resolve(
        pluginType: 'studio.fx/unknownGlow',
        pluginVersion: '1.0.0',
        backend: 'cpu',
      ),
      code('UNSUPPORTED_EDIT_TECHNIQUE'),
    );
  });

  test('an unregistered technique is refused, is not enabled by skill presence, and does not fall back to dissolve', () {
    final compiler = CraftSkillCompiler();
    expect(
      () => compiler.compile(
        skill: skill(pluginType: 'studio.fx/maskWipe'),
        backend: 'cpu',
      ),
      code('UNSUPPORTED_EDIT_TECHNIQUE'),
    );
    expect(compiler.documentWrites, 0);

    expect(
      () => compiler.compile(
        skill: skill(pluginType: lumaWipeEffectType),
        backend: 'web',
      ),
      code('UNSUPPORTED_EDIT_TECHNIQUE'),
    );
    expect(compiler.documentWrites, 0);
  });

  test('a skill cannot register unreviewed shader or FFmpeg filter strings; a registered lumaWipe cpu skill compiles without writing a project', () {
    final compiler = CraftSkillCompiler();
    expect(
      () => compiler.compile(
        skill: skill(
          pluginType: lumaWipeEffectType,
          shaderSource: 'void main() {}',
        ),
        backend: 'cpu',
      ),
      code('UNSUPPORTED_EDIT_TECHNIQUE'),
    );
    expect(
      () => compiler.compile(
        skill: skill(
          pluginType: lumaWipeEffectType,
          ffmpegFilter: 'geq=lum=255',
        ),
        backend: 'cpu',
      ),
      code('UNSUPPORTED_EDIT_TECHNIQUE'),
    );
    expect(compiler.documentWrites, 0);

    final proposal = compiler.compile(
      skill: skill(pluginType: lumaWipeEffectType),
      backend: 'cpu',
    );
    expect(proposal.operator.id, lumaWipeEffectType);
    expect(proposal.requiredFeatures, [lumaWipeRequiredFeature]);
    expect(proposal.fellBackToDissolve, isFalse);
    expect(proposal.documentWrites, 0);
    expect(compiler.documentWrites, 0);
    expect(proposal.editPatchGroups, isEmpty);
  });
}
