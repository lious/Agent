import 'dart:io';

import 'package:studio_contracts/studio_contracts.dart';
import 'package:studio_document/studio_document.dart';
import 'package:test/test.dart';

Matcher code(String c) =>
    throwsA(isA<StudioException>().having((e) => e.code, 'code', c));

File golden(String name) {
  final candidates = [
    File('packages/studio_document/test/captions/formats/goldens/$name'),
    File('test/captions/formats/goldens/$name'),
  ];
  return candidates.firstWhere(
    (f) => f.existsSync(),
    orElse: () => candidates.first,
  );
}

AssFontLayoutPolicy officialFontPolicy() => AssFontLayoutPolicy(
  requestedFontFamily: 'StudioTestNoto',
  availableFontFamilies: const {'StudioTestNoto'},
);

void main() {
  test('official SRT/VTT/ASS goldens roundtrip emoji, RTL, newline and non-frame times', () {
    final srtStore = CaptionStore([
      CaptionCue(
        'x',
        TimeRange(Q.of(101, 1000), Q.of(799, 1000)),
        '你好🙂 שלום\n<script>&literal',
      ),
      CaptionCue('y', TimeRange(Q.of(900, 1000), Q.of(1)), 'Arabic العربية'),
    ]);
    final srtText = CaptionFormats.encode(srtStore, CaptionFormat.srt);
    final vttText = CaptionFormats.encode(srtStore, CaptionFormat.vtt);
    expect(srtText, golden('emoji-rtl-newline.srt').readAsStringSync());
    expect(vttText, golden('emoji-rtl-newline.vtt').readAsStringSync());
    for (final entry in {
      CaptionFormat.srt: srtText,
      CaptionFormat.vtt: vttText,
    }.entries) {
      final decoded = CaptionFormats.decode(entry.value, entry.key);
      expect(decoded.warnings, isEmpty);
      expect(
        decoded.captions.cues.map((c) => c.text),
        srtStore.cues.map((c) => c.text),
      );
      for (var i = 0; i < srtStore.cues.length; i++) {
        expect(
          decoded.captions.cues[i].range.start,
          srtStore.cues[i].range.start,
        );
        expect(decoded.captions.cues[i].range.end, srtStore.cues[i].range.end);
      }
    }

    final assStore = CaptionStore([
      CaptionCue(
        'x',
        TimeRange(Q.of(1, 100), Q.of(122, 100)),
        '你好🙂 {hand}\\edit\nשלום',
      ),
      CaptionCue('y', TimeRange(Q.of(123, 100), Q.of(77, 100)), 'العربية'),
    ]);
    final assText = CaptionFormats.encode(
      assStore,
      CaptionFormat.ass,
      fontPolicy: officialFontPolicy(),
    );
    expect(assText, golden('emoji-rtl-newline.ass').readAsStringSync());
    final decodedAss = CaptionFormats.decode(assText, CaptionFormat.ass);
    expect(
      decodedAss.captions.cues.map((c) => c.text),
      assStore.cues.map((c) => c.text),
    );
    for (var i = 0; i < assStore.cues.length; i++) {
      expect(
        decodedAss.captions.cues[i].range.start,
        assStore.cues[i].range.start,
      );
      expect(decodedAss.captions.cues[i].range.end, assStore.cues[i].range.end);
    }
    expect(
      decodedAss.warnings,
      containsAll(['ASS_STYLE_FONT_NOT_RENDERED', 'ASS_STYLE_FIELDS_DROPPED']),
    );
    expect(
      CaptionFormats.encode(
        decodedAss.captions,
        CaptionFormat.ass,
        fontPolicy: officialFontPolicy(),
      ),
      assText,
    );
  });

  test('unsupported ASS style and event fields are listed in the loss report, not silently dropped', () {
    const input =
        '[V4+ Styles]\n'
        'Format: Name, Fontname, Fontsize, PrimaryColour, Bold, Italic, Alignment, MarginV\n'
        'Style: Title,StudioTestNoto,72,&H000000FF,1,1,8,40\n'
        'Style: Default,StudioTestNoto,48,&H00FFFFFF,0,0,2,10\n\n'
        '[Events]\n'
        'Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text\n'
        'Dialogue: 1,0:00:00.01,0:00:01.00,Title,narrator,20,20,40,Karaoke,{\\k10}你好🙂\\Nשלום\n'
        'Comment: 0,0:00:01.00,0:00:02.00,Default,,0,0,0,,ignored\n';
    final decoded = CaptionFormats.decode(input, CaptionFormat.ass);
    expect(decoded.captions.cues.single.text, '你好🙂\nשלום');
    expect(decoded.captions.cues.single.range.start, Q.of(1, 100));
    expect(decoded.captions.cues.single.range.end, Q.of(1));
    expect(
      decoded.warnings,
      containsAll([
        'ASS_STYLE_FONT_NOT_RENDERED',
        'ASS_STYLE_FIELDS_DROPPED',
        'ASS_EVENT_STYLE_DROPPED',
        'ASS_OVERRIDE_DROPPED',
        'ASS_EVENT_DROPPED',
      ]),
    );
    expect(decoded.captions.cues, hasLength(1));
  });

  test('official format path refuses overlapping SRT/VTT/ASS as CAPTION_OVERLAP and allows touching cues', () {
    const touchingSrt =
        '1\n00:00:00,000 --> 00:00:01,000\nleft\n\n2\n00:00:01,000 --> 00:00:02,000\nright\n';
    final touching = CaptionFormats.decode(touchingSrt, CaptionFormat.srt);
    expect(touching.warnings, isEmpty);
    expect(touching.captions.cues.map((c) => c.text), ['left', 'right']);

    const overlapSrt =
        '1\n00:00:00,000 --> 00:00:01,500\nleft\n\n2\n00:00:01,000 --> 00:00:02,000\nright\n';
    expect(
      () => CaptionFormats.decode(overlapSrt, CaptionFormat.srt),
      code('CAPTION_OVERLAP'),
    );

    const overlapVtt =
        'WEBVTT\n\n00:00:00.000 --> 00:00:01.500\nleft\n\n00:00:01.000 --> 00:00:02.000\nright\n';
    expect(
      () => CaptionFormats.decode(overlapVtt, CaptionFormat.vtt),
      code('CAPTION_OVERLAP'),
    );

    const overlapAss =
        '[Events]\n'
        'Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text\n'
        'Dialogue: 0,0:00:00.00,0:00:01.50,Default,,0,0,0,,left\n'
        'Dialogue: 0,0:00:01.00,0:00:02.00,Default,,0,0,0,,right\n';
    expect(
      () => CaptionFormats.decode(overlapAss, CaptionFormat.ass),
      code('CAPTION_OVERLAP'),
    );
  });
}
