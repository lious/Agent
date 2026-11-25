import 'package:studio_document/studio_document.dart';
import 'package:studio_contracts/studio_contracts.dart';
import 'package:test/test.dart';

Matcher code(String c) =>
    throwsA(isA<StudioException>().having((e) => e.code, 'code', c));
void main() {
  test('SRT/VTT actual Unicode, RTL, emoji, linebreak, escaped markup and millisecond non-frame times roundtrip', () {
    final store = CaptionStore([
      CaptionCue(
        'x',
        TimeRange(Q.of(101, 1000), Q.of(799, 1000)),
        '你好🙂 שלום\n<script>&literal',
      ),
      CaptionCue('y', TimeRange(Q.of(900, 1000), Q.of(1)), 'Arabic العربية'),
    ]);
    for (final format in [CaptionFormat.srt, CaptionFormat.vtt]) {
      final text = CaptionFormats.encode(store, format),
          decoded = CaptionFormats.decode(text, format);
      expect(decoded.warnings, isEmpty);
      expect(
        decoded.captions.cues.map((c) => c.text),
        store.cues.map((c) => c.text),
      );
      for (var i = 0; i < store.cues.length; i++) {
        expect(decoded.captions.cues[i].range.start, store.cues[i].range.start);
        expect(decoded.captions.cues[i].range.end, store.cues[i].range.end);
      }
    }
  });
  test('manual text/timing protected from automatic update; split duplicates text and exact source retime retains flags', () {
    final cue = CaptionCue(
      'c',
      TimeRange(Q.of(1), Q.of(2)),
      'original',
    ).editText('manual');
    expect(
      () => cue.editText('ASR', automatic: true),
      code('MANUAL_FIELD_LOCKED'),
    );
    final halves = cue.split(Q.of(7, 4), 'right');
    expect(halves.map((c) => c.text), ['manual', 'manual']);
    expect(halves.first.range.end, halves.last.range.start);
    final trimmed = cue.trim(TimeRange(Q.of(3, 2), Q.of(1)));
    expect(trimmed.range.duration, Q.of(1));
    expect(
      () => trimmed.trim(trimmed.range, automatic: true),
      code('MANUAL_FIELD_LOCKED'),
    );
    final mapped = cue.mapSource(
      timelineStart: Q.of(10),
      sourceStart: Q.of(0),
      rate: Q.of(2),
    );
    expect(mapped.range.start, Q.of(21, 2));
    expect(mapped.range.duration, Q.of(1));
    expect(mapped.manualFields, contains('text'));
  });
  test('overlap policy is deterministic reject; touching half-open cues allowed and IDs unique', () {
    final a = CaptionCue('a', TimeRange(Q.of(0), Q.of(1)), 'a'),
        b = CaptionCue('b', TimeRange(Q.of(1), Q.of(1)), 'b');
    expect(CaptionStore([b, a]).cues.map((c) => c.id), ['a', 'b']);
    expect(
      () => CaptionStore([
        a,
        CaptionCue('c', TimeRange(Q.of(1, 2), Q.of(1)), 'c'),
      ]),
      code('CAPTION_OVERLAP'),
    );
    expect(() => CaptionStore([a, a]), code('DUPLICATE_ID'));
  });
  test('static ASS parses exact centiseconds, commas and newline, reports dropped styles and overrides without execution', () {
    final input =
        '[Events]\nFormat: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text\nDialogue: 0,0:00:00.01,0:00:01.23,Default,,0,0,0,,{\\pos(1,2)}hi,🙂\\Nשלום';
    final decoded = CaptionFormats.decode(input, CaptionFormat.ass);
    expect(decoded.captions.cues.single.text, 'hi,🙂\nשלום');
    expect(decoded.captions.cues.single.range.start, Q.of(1, 100));
    expect(
      decoded.warnings,
      containsAll(['ASS_STYLE_FONT_NOT_RENDERED', 'ASS_OVERRIDE_DROPPED']),
    );
    expect(
      () => CaptionFormats.encode(decoded.captions, CaptionFormat.ass),
      code('ASS_EXPORT_FONT_POLICY_REQUIRED'),
    );
  });
  test('unsupported VTT style/settings warn; malicious/malformed/oversize/quantization input refused', () {
    final decoded = CaptionFormats.decode(
      'WEBVTT\n\nSTYLE\n::cue {color:red}\n\n00:00.001 --> 00:00.100 align:start\n<b>hi</b>',
      CaptionFormat.vtt,
    );
    expect(
      decoded.warnings,
      containsAll([
        'WEBVTT_METADATA_DROPPED',
        'WEBVTT_CUE_SETTINGS_DROPPED',
        'SUBTITLE_MARKUP_DROPPED',
      ]),
    );
    expect(decoded.captions.cues.single.text, 'hi');
    expect(
      () => CaptionFormats.decode(
        '1\n00:00:99,000 --> 00:01:00,000\nx',
        CaptionFormat.srt,
      ),
      code('SUBTITLE_TIMECODE'),
    );
    expect(
      () =>
          CaptionFormats.decode('x' * (4 * 1024 * 1024 + 1), CaptionFormat.srt),
      code('SUBTITLE_RESOURCE_LIMIT'),
    );
    expect(
      () => CaptionFormats.encode(
        CaptionStore([
          CaptionCue('a', TimeRange(Q.of(1, 10000), Q.of(1, 10000)), 'x'),
        ]),
        CaptionFormat.srt,
      ),
      code('SUBTITLE_TIME_QUANTIZATION'),
    );
  });
  test('seeded rational millisecond vectors roundtrip without frame quantization or accumulating rounding', () {
    for (var i = 1; i <= 250; i++) {
      final start = Q.of(i * 37, 1000),
          duration = Q.of(i % 37 + 1, 1000),
          c = CaptionCue('c', TimeRange(start, duration), '$i 🙂');
      final r = CaptionFormats.decode(
        CaptionFormats.encode(CaptionStore([c]), CaptionFormat.vtt),
        CaptionFormat.vtt,
      ).captions.cues.single;
      expect(r.range.start, start);
      expect(r.range.end, start + duration);
    }
  });
}
