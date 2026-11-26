import 'package:studio_contracts/studio_contracts.dart';
import 'package:studio_document/studio_document.dart';
import 'package:test/test.dart';

Matcher code(String c) =>
    throwsA(isA<StudioException>().having((e) => e.code, 'code', c));

AssFontLayoutPolicy policy({
  String requested = 'StudioTestSans',
  Set<String> available = const {'StudioTestSans', 'StudioTestNoto'},
  List<String> fallbacks = const ['StudioTestNoto'],
}) => AssFontLayoutPolicy(
  requestedFontFamily: requested,
  availableFontFamilies: available,
  fallbackFontFamilies: fallbacks,
);

CaptionStore storeFor(List<(Q, Q, String)> cues) => CaptionStore([
  for (var i = 0; i < cues.length; i++)
    CaptionCue('c$i', TimeRange(cues[i].$1, cues[i].$2), cues[i].$3),
]);

void main() {
  test('ASS export with a registered font policy roundtrips emoji, RTL, newline, escaped braces and non-frame centisecond times', () {
    final store = storeFor([
      (Q.of(1, 100), Q.of(122, 100), '你好🙂 {literal}\\hello\nשלום'),
      (Q.of(2), Q.of(1, 100), 'Arabic العربية'),
    ]);
    final exported = CaptionFormats.export(
      store,
      CaptionFormat.ass,
      fontPolicy: policy(),
    );
    expect(exported.warnings, isEmpty);
    expect(exported.text, contains('Fontname'));
    expect(exported.text, contains('StudioTestSans'));
    expect(exported.text, isNot(contains('{\\pos')));
    final decoded = CaptionFormats.decode(exported.text, CaptionFormat.ass);
    expect(
      decoded.captions.cues.map((c) => c.text),
      store.cues.map((c) => c.text),
    );
    for (var i = 0; i < store.cues.length; i++) {
      expect(decoded.captions.cues[i].range.start, store.cues[i].range.start);
      expect(decoded.captions.cues[i].range.end, store.cues[i].range.end);
    }
    // 0.01s and 1.23s are exact centiseconds and not 30 fps frame times.
    expect(store.cues.first.range.start, isNot(Q.of(0)));
    expect(
      store.cues.first.range.start.n *
          BigInt.from(30) %
          store.cues.first.range.start.d,
      isNot(BigInt.zero),
    );
  });

  test('ASS encode without a font policy remains refused; an invalid or empty policy does not invent a font', () {
    final store = storeFor([(Q.of(1, 100), Q.of(1, 100), 'x')]);
    expect(
      () => CaptionFormats.encode(store, CaptionFormat.ass),
      code('ASS_EXPORT_FONT_POLICY_REQUIRED'),
    );
    expect(
      () => policy(requested: '', available: const {'StudioTestSans'}),
      code('ASS_FONT_POLICY_INVALID'),
    );
    expect(
      () => policy(
        requested: 'MissingFont',
        available: const {'StudioTestSans'},
        fallbacks: const [],
      ),
      // resolve happens at export; constructor allows a missing requested name
      returnsNormally,
    );
    expect(
      () => CaptionFormats.encode(
        store,
        CaptionFormat.ass,
        fontPolicy: policy(
          requested: 'MissingFont',
          available: const {'StudioTestSans'},
          fallbacks: const [],
        ),
      ),
      code('ASS_FONT_UNAVAILABLE'),
    );
  });

  test('missing requested font lists the substitute and layout change; the sidecar never writes the missing family as if it were present', () {
    final store = storeFor([(Q.of(1, 100), Q.of(1), 'hi')]);
    final exported = CaptionFormats.export(
      store,
      CaptionFormat.ass,
      fontPolicy: policy(
        requested: 'MissingLicensedFont',
        fallbacks: const ['StudioTestNoto', 'StudioTestSans'],
        available: const {'StudioTestNoto'},
      ),
    );
    expect(
      exported.warnings,
      containsAll([
        'ASS_FONT_SUBSTITUTED:MissingLicensedFont->StudioTestNoto',
        'ASS_LAYOUT_MAY_CHANGE',
      ]),
    );
    expect(exported.text, contains('StudioTestNoto'));
    expect(
      exported.text,
      isNot(contains('Style: Default,MissingLicensedFont,')),
    );
    expect(
      exported.text,
      contains('requested MissingLicensedFont is unavailable'),
    );
    expect(exported.text, contains('wrote StudioTestNoto'));
    expect(exported.text, contains('layout may change'));
    final decoded = CaptionFormats.decode(
      exported.text,
      CaptionFormat.ass,
      fontPolicy: policy(
        requested: 'MissingLicensedFont',
        fallbacks: const ['StudioTestNoto'],
        available: const {'StudioTestNoto'},
      ),
    );
    expect(decoded.warnings, contains('ASS_STYLE_FONT_NOT_RENDERED'));
    expect(
      decoded.warnings,
      isNot(
        contains('ASS_FONT_SUBSTITUTED:MissingLicensedFont->StudioTestNoto'),
      ),
    );
    // The written Style uses the substitute, which is registered, so import
    // must not pretend the missing requested font was used or rendered.
    expect(decoded.captions.cues.single.text, 'hi');
  });

  test('static ASS import still reports dropped styles and overrides; a policy lists a substitute without claiming the original font was rendered', () {
    final input =
        '[V4+ Styles]\nFormat: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding\nStyle: Default,MissingLicensedFont,48,&H00FFFFFF,&H000000FF,&H00000000,&H00000000,0,0,0,0,100,100,0,0,1,2,0,2,10,10,10,1\n\n[Events]\nFormat: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text\nDialogue: 0,0:00:00.01,0:00:01.23,Default,,0,0,0,,{\\pos(1,2)}hi,🙂\\Nשלום';
    final withoutPolicy = CaptionFormats.decode(input, CaptionFormat.ass);
    expect(withoutPolicy.captions.cues.single.text, 'hi,🙂\nשלום');
    expect(withoutPolicy.captions.cues.single.range.start, Q.of(1, 100));
    expect(
      withoutPolicy.warnings,
      containsAll([
        'ASS_STYLE_FONT_NOT_RENDERED',
        'ASS_OVERRIDE_DROPPED',
        'ASS_STYLE_FONT_UNRESOLVED:MissingLicensedFont',
      ]),
    );
    final withPolicy = CaptionFormats.decode(
      input,
      CaptionFormat.ass,
      fontPolicy: policy(
        requested: 'MissingLicensedFont',
        fallbacks: const ['StudioTestNoto'],
        available: const {'StudioTestNoto'},
      ),
    );
    expect(withPolicy.captions.cues.single.text, 'hi,🙂\nשלום');
    expect(
      withPolicy.warnings,
      containsAll([
        'ASS_STYLE_FONT_NOT_RENDERED',
        'ASS_OVERRIDE_DROPPED',
        'ASS_FONT_SUBSTITUTED:MissingLicensedFont->StudioTestNoto',
        'ASS_LAYOUT_MAY_CHANGE',
      ]),
    );
    expect(
      withPolicy.warnings,
      isNot(contains('ASS_STYLE_FONT_UNRESOLVED:MissingLicensedFont')),
    );
  });

  test('seeded exact centisecond vectors roundtrip without frame quantization; collapsed sub-centisecond ranges are refused', () {
    for (var i = 1; i <= 250; i++) {
      final start = Q.of(i * 37, 100),
          duration = Q.of(i % 37 + 1, 100),
          c = CaptionCue('c', TimeRange(start, duration), '$i 🙂');
      final r = CaptionFormats.decode(
        CaptionFormats.encode(
          CaptionStore([c]),
          CaptionFormat.ass,
          fontPolicy: policy(),
        ),
        CaptionFormat.ass,
      ).captions.cues.single;
      expect(r.range.start, start);
      expect(r.range.end, start + duration);
    }
    expect(
      () => CaptionFormats.encode(
        storeFor([(Q.of(1, 1000), Q.of(1, 1000), 'x')]),
        CaptionFormat.ass,
        fontPolicy: policy(),
      ),
      code('SUBTITLE_TIME_QUANTIZATION'),
    );
  });
}
