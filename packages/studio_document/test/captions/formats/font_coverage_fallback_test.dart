import 'package:studio_contracts/studio_contracts.dart';
import 'package:studio_document/studio_document.dart';
import 'package:test/test.dart';

Matcher code(String c) =>
    throwsA(isA<StudioException>().having((e) => e.code, 'code', c));

const mixed = '你好🙂 שלום';

AssFontLayoutPolicy policy({
  String requested = 'StudioTestSans',
  Set<String> available = const {'StudioTestSans', 'StudioTestNoto'},
  List<String> fallbacks = const ['StudioTestNoto'],
  Map<String, Set<String>> scriptCoverage = const {},
}) => AssFontLayoutPolicy(
  requestedFontFamily: requested,
  availableFontFamilies: available,
  fallbackFontFamilies: fallbacks,
  scriptCoverage: scriptCoverage,
);

Map<String, Set<String>> coveringNoto({Set<String> sans = const {'Latn'}}) => {
  'StudioTestSans': sans,
  'StudioTestNoto': const {'Latn', 'Han', 'Hebr', 'Arab', 'Zsye'},
};

CaptionStore store([String text = mixed]) =>
    CaptionStore([CaptionCue('c', TimeRange(Q.of(1, 100), Q.of(1)), text)]);

void main() {
  test('declared coverage substitutes a Latin-only requested font for CJK, emoji and RTL, and never writes it as if it covered those scripts', () {
    expect(assDeclaredScriptsIn(mixed), {'Han', 'Hebr', 'Zsye'});
    final exported = CaptionFormats.export(
      store(),
      CaptionFormat.ass,
      fontPolicy: policy(scriptCoverage: coveringNoto()),
    );
    expect(
      exported.warnings,
      containsAll([
        'ASS_FONT_COVERAGE_SUBSTITUTED:StudioTestSans->StudioTestNoto:Han,Hebr,Zsye',
        'ASS_LAYOUT_MAY_CHANGE',
      ]),
    );
    expect(
      exported.warnings,
      isNot(contains(startsWith('ASS_FONT_SUBSTITUTED:'))),
    );
    expect(exported.text, contains('Style: Default,StudioTestNoto,'));
    expect(exported.text, isNot(contains('Style: Default,StudioTestSans,')));
    expect(
      exported.text,
      contains('does not declare coverage of the sidecar text'),
    );
    expect(exported.text, contains('not deterministic shaping'));
    expect(
      CaptionFormats.decode(
        exported.text,
        CaptionFormat.ass,
      ).captions.cues.single.text,
      mixed,
    );
  });

  test('name-only policy without declared coverage keeps last-batch family fallback and does not invent coverage warnings', () {
    final available = policy();
    final exported = CaptionFormats.export(
      store(),
      CaptionFormat.ass,
      fontPolicy: available,
    );
    expect(exported.warnings, isEmpty);
    expect(exported.text, contains('Style: Default,StudioTestSans,'));
    expect(
      () => CaptionFormats.encode(store(), CaptionFormat.ass),
      code('ASS_EXPORT_FONT_POLICY_REQUIRED'),
    );
  });

  test('a requested family that already declares coverage of the sidecar text is written unchanged', () {
    final exported = CaptionFormats.export(
      store(),
      CaptionFormat.ass,
      fontPolicy: policy(
        requested: 'StudioTestNoto',
        scriptCoverage: coveringNoto(),
      ),
    );
    expect(exported.warnings, isEmpty);
    expect(exported.text, contains('Style: Default,StudioTestNoto,'));
  });

  test('declared coverage with no covering registered fallback is refused rather than silently writing the original family', () {
    expect(
      () => CaptionFormats.encode(
        store(),
        CaptionFormat.ass,
        fontPolicy: policy(
          fallbacks: const [],
          available: const {'StudioTestSans'},
          scriptCoverage: const {
            'StudioTestSans': {'Latn'},
          },
        ),
      ),
      throwsA(
        isA<StudioException>()
            .having((e) => e.code, 'code', 'ASS_FONT_COVERAGE_UNAVAILABLE')
            .having((e) => e.path, 'path', 'Han,Hebr,Zsye'),
      ),
    );
  });

  test('missing family plus incomplete name fallback lists the final covering substitute, not the uncovered intermediate family as the original font', () {
    final exported = CaptionFormats.export(
      store(),
      CaptionFormat.ass,
      fontPolicy: policy(
        requested: 'MissingLicensedFont',
        fallbacks: const ['StudioTestSans', 'StudioTestNoto'],
        scriptCoverage: coveringNoto(),
      ),
    );
    expect(
      exported.warnings,
      containsAll([
        'ASS_FONT_SUBSTITUTED:MissingLicensedFont->StudioTestNoto',
        'ASS_FONT_COVERAGE_SUBSTITUTED:StudioTestSans->StudioTestNoto:Han,Hebr,Zsye',
        'ASS_LAYOUT_MAY_CHANGE',
      ]),
    );
    expect(exported.text, contains('Style: Default,StudioTestNoto,'));
    expect(
      exported.text,
      isNot(contains('Style: Default,MissingLicensedFont,')),
    );
    expect(exported.text, isNot(contains('Style: Default,StudioTestSans,')));
  });

  test('import with declared coverage lists a style-font coverage substitute without claiming rendering, and an invalid coverage map is refused', () {
    final input =
        '[V4+ Styles]\nFormat: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding\nStyle: Default,StudioTestSans,48,&H00FFFFFF,&H000000FF,&H00000000,&H00000000,0,0,0,0,100,100,0,0,1,2,0,2,10,10,10,1\n\n[Events]\nFormat: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text\nDialogue: 0,0:00:00.01,0:00:01.00,Default,,0,0,0,,你好🙂\\Nשלום';
    final decoded = CaptionFormats.decode(
      input,
      CaptionFormat.ass,
      fontPolicy: policy(scriptCoverage: coveringNoto()),
    );
    expect(decoded.captions.cues.single.text, '你好🙂\nשלום');
    expect(
      decoded.warnings,
      containsAll([
        'ASS_STYLE_FONT_NOT_RENDERED',
        'ASS_FONT_COVERAGE_SUBSTITUTED:StudioTestSans->StudioTestNoto:Han,Hebr,Zsye',
        'ASS_LAYOUT_MAY_CHANGE',
      ]),
    );
    expect(
      () => policy(
        scriptCoverage: const {
          'StudioTestSans': {'NotAScript'},
        },
      ),
      code('ASS_FONT_POLICY_INVALID'),
    );
  });
}
