import 'dart:io';

import 'package:studio_sdk/studio_sdk.dart';
import 'package:test/test.dart';

Matcher code(String c) =>
    throwsA(isA<StudioException>().having((e) => e.code, 'code', c));

AssFontLayoutPolicy coveringPolicy({String requested = 'StudioTestSans'}) =>
    AssFontLayoutPolicy(
      requestedFontFamily: requested,
      availableFontFamilies: const {'StudioTestSans', 'StudioTestNoto'},
      fallbackFontFamilies: const ['StudioTestNoto'],
      scriptCoverage: const {
        'StudioTestSans': {'Latn'},
        'StudioTestNoto': {'Latn', 'Han', 'Hebr', 'Arab', 'Zsye'},
      },
    );

void main() {
  late Directory root;
  late StudioWorkspace w;
  setUp(() async {
    root = Directory.systemTemp.createTempSync('caption-font-coverage-');
    w = StudioWorkspace.open(
      profile: AppProfile(
        appId: 'studio',
        region: 'local',
        features: {'project.metadata', 'media.local'},
      ),
      databasePath: '${root.path}/db',
      tenantId: 'local',
      workspaceId: 'font-coverage',
      mediaLibraryPath: Platform.environment['STUDIO_MEDIA_LIBRARY'],
      mediaRootPath: '${root.path}/media',
    );
    w.openDemo();
  });
  tearDown(() async {
    await w.closeAsync();
    root.deleteSync(recursive: true);
  });

  test('ASS export with declared script coverage lists a substitute, re-ASR still cannot overwrite a hand-edited cue, overlap stays rejected, and MP4 burn-in stays refused', () async {
    w.edit(
      SetCaptions(
        CaptionStore([
          CaptionCue(
            'manual',
            TimeRange(Q.of(1, 100), Q.of(1)),
            '你好🙂 שלום',
            manualFields: {'text', 'timing'},
          ),
        ]),
      ),
      expectedRevision: w.current.revision,
    );
    expect(
      () => w.edit(
        SetCaptions(
          CaptionStore([
            CaptionCue('manual', TimeRange(Q.of(1, 100), Q.of(1)), 'ASR guess'),
          ]),
          automatic: true,
        ),
        expectedRevision: w.current.revision,
      ),
      code('MANUAL_FIELD_LOCKED'),
    );
    expect(
      () => CaptionStore([
        CaptionCue('manual', TimeRange(Q.of(1, 100), Q.of(1)), '你好🙂 שלום'),
        CaptionCue('overlap', TimeRange(Q.of(1, 2), Q.of(1)), 'nope'),
      ]),
      code('CAPTION_OVERLAP'),
    );

    final sidecar = File('${root.path}/cues.ass');
    final written = w.writeCaptionSidecar(
      sidecar,
      CaptionFormat.ass,
      fontPolicy: coveringPolicy(),
    );
    expect(
      written.warnings,
      containsAll([
        'ASS_FONT_COVERAGE_SUBSTITUTED:StudioTestSans->StudioTestNoto:Han,Hebr,Zsye',
        'ASS_LAYOUT_MAY_CHANGE',
      ]),
    );
    expect(
      sidecar.readAsStringSync(),
      contains('Style: Default,StudioTestNoto,'),
    );
    expect(
      sidecar.readAsStringSync(),
      isNot(contains('Style: Default,StudioTestSans,')),
    );

    final inbound = File('${root.path}/inbound.ass')
      ..writeAsStringSync(
        '[V4+ Styles]\n'
        'Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding\n'
        'Style: Default,StudioTestSans,48,&H00FFFFFF,&H000000FF,&H00000000,&H00000000,0,0,0,0,100,100,0,0,1,2,0,2,10,10,10,1\n\n'
        '[Events]\n'
        'Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text\n'
        'Dialogue: 0,0:00:02.00,0:00:02.50,Default,,0,0,0,,مرحبا\n',
      );
    final imported = await w.importCaptions(
      LocalFileGrant.fromUserSelection(inbound),
      CaptionFormat.ass,
      expectedRevision: w.current.revision,
      fontPolicy: coveringPolicy(),
    );
    expect(
      imported.warnings,
      containsAll([
        'ASS_STYLE_FONT_NOT_RENDERED',
        'ASS_FONT_COVERAGE_SUBSTITUTED:StudioTestSans->StudioTestNoto:Arab',
        'ASS_LAYOUT_MAY_CHANGE',
      ]),
    );

    if (w.media == null) {
      fail(
        'STUDIO_MEDIA_LIBRARY is required so MP4 export can stay refused with CAPTION_RENDER_POLICY_NOT_IMPLEMENTED',
      );
    }
    final src = File('${root.path}/src.mp4');
    final made = await Process.run('ffmpeg', [
      '-v',
      'error',
      '-f',
      'lavfi',
      '-i',
      'color=c=black:s=64x36:r=30:d=1',
      '-pix_fmt',
      'yuv420p',
      src.path,
    ]);
    if (made.exitCode != 0) {
      fail('ffmpeg failed: ${made.stderr}');
    }
    await w.importVideo(
      LocalFileGrant.fromUserSelection(src),
      expectedRevision: w.current.revision,
      acknowledgeVideoOnly: true,
    );
    await expectLater(
      w.exportVideo(File('${root.path}/must-not.mp4')),
      code('CAPTION_RENDER_POLICY_NOT_IMPLEMENTED'),
    );
    expect(File('${root.path}/must-not.mp4').existsSync(), false);
  });
}
