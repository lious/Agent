import 'package:studio_contracts/studio_contracts.dart';

import 'time.dart';

/// Plain, absolute-time caption subset. Rich styles/word alignments/anchors are
/// deliberately rejected on project admission until their editing is implemented.
final class CaptionCue {
  CaptionCue(
    this.id,
    this.range,
    this.text, {
    this.language = 'und',
    Set<String> manualFields = const {},
  }) : manualFields = Set.unmodifiable(manualFields) {
    requireId(id);
    if (range.start < Q.of(0) ||
        text.length > 4096 ||
        text.contains('\u0000') ||
        !RegExp(r'^[A-Za-z]{2,8}(-[A-Za-z0-9]{1,8})*$').hasMatch(language) ||
        !manualFields.every(['text', 'timing', 'style', 'speaker'].contains)) {
      throw const StudioException('CAPTION_INVALID');
    }
  }
  final String id, text, language;
  final TimeRange range;
  final Set<String> manualFields;
  CaptionCue editText(String value, {bool automatic = false}) {
    if (automatic && manualFields.contains('text') && value != text) {
      throw const StudioException('MANUAL_FIELD_LOCKED');
    }
    return CaptionCue(
      id,
      range,
      value,
      language: language,
      manualFields: {...manualFields, if (!automatic) 'text'},
    );
  }

  CaptionCue trim(TimeRange selection, {bool automatic = false}) {
    if (automatic && manualFields.contains('timing')) {
      throw const StudioException('MANUAL_FIELD_LOCKED');
    }
    final r = range.intersect(selection);
    if (r == null) throw const StudioException('CAPTION_EMPTY_TRIM');
    return CaptionCue(
      id,
      r,
      text,
      language: language,
      manualFields: {...manualFields, if (!automatic) 'timing'},
    );
  }

  List<CaptionCue> split(Q at, String rightId) {
    if (at <= range.start || at >= range.end) {
      throw const StudioException('CAPTION_SPLIT_RANGE');
    }
    return [
      CaptionCue(
        id,
        TimeRange(range.start, at - range.start),
        text,
        language: language,
        manualFields: {...manualFields, 'timing'},
      ),
      CaptionCue(
        rightId,
        TimeRange(at, range.end - at),
        text,
        language: language,
        manualFields: {...manualFields, 'timing'},
      ),
    ];
  }

  /// Explicit source-coordinate mapping, not frame snapping. Existing manual text
  /// and timing ownership flags survive. Applying a map to a project is separate.
  CaptionCue mapSource({
    required Q timelineStart,
    required Q sourceStart,
    required Q rate,
  }) {
    if (rate <= Q.of(0)) throw const StudioException('TIME_MAP_MISMATCH');
    return CaptionCue(
      id,
      TimeRange(
        timelineStart + (range.start - sourceStart) / rate,
        range.duration / rate,
      ),
      text,
      language: language,
      manualFields: manualFields,
    );
  }

  Map<String, Object?> toProjectJson(String trackId, {String version = '1'}) =>
      {
        'id': id,
        'version': version,
        'trackId': trackId,
        'timelineRange': {
          'start': range.start.toJson(),
          'duration': range.duration.toJson(),
        },
        'text': text,
        'language': language,
        'styleEffectId': null,
        'anchor': {'kind': 'absolute', 'clipId': null, 'range': null},
        'manualFields': manualFields.toList()..sort(),
        'words': <Object>[],
        'speakerId': null,
      };
  factory CaptionCue.fromProjectJson(Map<String, dynamic> c) {
    if (c['styleEffectId'] != null ||
        c['speakerId'] != null ||
        (c['words'] as List).isNotEmpty ||
        c['anchor']['kind'] != 'absolute' ||
        c['anchor']['clipId'] != null ||
        c['anchor']['range'] != null) {
      throw const StudioException('CAPTION_RICH_EDIT_NOT_IMPLEMENTED');
    }
    return CaptionCue(
      c['id'] as String,
      TimeRange(
        Q.fromJson(c['timelineRange']['start']),
        Q.fromJson(c['timelineRange']['duration']),
      ),
      c['text'] as String,
      language: c['language'] as String,
      manualFields: Set<String>.from(c['manualFields'] as List),
    );
  }
}

final class CaptionStore {
  CaptionStore(List<CaptionCue> values)
    : cues = List.unmodifiable(
        values.toList()..sort((a, b) {
          final n = a.range.start.compareTo(b.range.start);
          return n == 0 ? a.id.compareTo(b.id) : n;
        }),
      ) {
    if (values.length > 10000) {
      throw const StudioException('CAPTION_RESOURCE_LIMIT');
    }
    if (values.map((c) => c.id).toSet().length != values.length) {
      throw const StudioException('DUPLICATE_ID');
    }
    for (var i = 1; i < cues.length; i++) {
      if (cues[i - 1].range.overlaps(cues[i].range)) {
        throw const StudioException('CAPTION_OVERLAP');
      }
    }
  }
  final List<CaptionCue> cues;
}

enum CaptionFormat { srt, vtt, ass }

final class CaptionImport {
  CaptionImport(List<CaptionCue> values, Set<String> warnings)
    : captions = CaptionStore(values),
      warnings = Set.unmodifiable(warnings);
  final CaptionStore captions;
  final Set<String> warnings;
}

final class CaptionFormats {
  static Q _time(String raw, {bool ass = false}) {
    final match = RegExp(
      ass
          ? r'^(\d{1,6}):([0-5]\d):([0-5]\d)\.(\d{2})$'
          : r'^(?:(\d{1,6}):)?([0-5]\d):([0-5]\d)[.,](\d{3})$',
    ).firstMatch(raw);
    if (match == null) throw const StudioException('SUBTITLE_TIMECODE');
    final scale = ass ? 100 : 1000,
        h = int.parse(match[1] ?? '0'),
        m = int.parse(match[2]!),
        s = int.parse(match[3]!),
        f = int.parse(match[4]!);
    return Q.of((h * 3600 + m * 60 + s) * scale + f, scale);
  }

  static String _text(String raw, Set<String> warnings) {
    if (RegExp(r'<[^>]*>').hasMatch(raw)) {
      warnings.add('SUBTITLE_MARKUP_DROPPED');
    }
    return raw
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&amp;', '&');
  }

  static CaptionImport decode(String input, CaptionFormat format) {
    if (input.length > 4 * 1024 * 1024) {
      throw const StudioException('SUBTITLE_RESOURCE_LIMIT');
    }
    input = input
        .replaceFirst(RegExp('^\ufeff'), '')
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n');
    final cues = <CaptionCue>[], warnings = <String>{};
    void add(Q start, Q end, String text) {
      if (cues.length >= 10000) {
        throw const StudioException('CAPTION_RESOURCE_LIMIT');
      }
      cues.add(
        CaptionCue(
          'cue-${cues.length + 1}',
          TimeRange(start, end - start),
          text,
        ),
      );
    }

    if (format == CaptionFormat.ass) {
      warnings.add('ASS_STYLE_FONT_NOT_RENDERED');
      var events = false, formatSeen = false;
      for (final line in input.split('\n')) {
        if (line.startsWith('[')) {
          events = line.trim() == '[Events]';
          continue;
        }
        if (!events || line.trim().isEmpty || line.startsWith(';')) continue;
        if (line.startsWith('Format:')) {
          if (line.substring(7).replaceAll(' ', '') !=
              'Layer,Start,End,Style,Name,MarginL,MarginR,MarginV,Effect,Text') {
            throw const StudioException('ASS_FORMAT_UNSUPPORTED');
          }
          formatSeen = true;
          continue;
        }
        if (!line.startsWith('Dialogue:')) {
          warnings.add('ASS_EVENT_DROPPED');
          continue;
        }
        if (!formatSeen) throw const StudioException('ASS_FORMAT_REQUIRED');
        final fields = line.substring(9).trimLeft().split(',');
        if (fields.length < 10) {
          throw const StudioException('ASS_DIALOGUE_INVALID');
        }
        var text = fields.sublist(9).join(',');
        if (RegExp(r'\{[^}]*\}').hasMatch(text)) {
          warnings.add('ASS_OVERRIDE_DROPPED');
        }
        text = text
            .replaceAll(RegExp(r'\{[^}]*\}'), '')
            .replaceAll(r'\N', '\n')
            .replaceAll(r'\n', '\n')
            .replaceAll(r'\h', '\u00a0');
        add(
          _time(fields[1].trim(), ass: true),
          _time(fields[2].trim(), ass: true),
          text,
        );
      }
      return CaptionImport(cues, warnings);
    }
    if (format == CaptionFormat.vtt) {
      if (!RegExp(r'^WEBVTT(?:[^\n]*)\n(?:\n|$)').hasMatch('$input\n')) {
        throw const StudioException('WEBVTT_HEADER_REQUIRED');
      }
      final first = input.indexOf('\n');
      input = first < 0 ? '' : input.substring(first + 1);
    }
    for (final block in input.split(RegExp(r'\n[ \t]*\n+'))) {
      final lines = block
          .replaceFirst(RegExp(r'^\n+'), '')
          .replaceFirst(RegExp(r'\n+$'), '')
          .split('\n');
      if (lines.every((s) => s.isEmpty)) continue;
      if (format == CaptionFormat.vtt &&
          (lines[0].startsWith('NOTE') ||
              lines[0] == 'STYLE' ||
              lines[0] == 'REGION')) {
        warnings.add('WEBVTT_METADATA_DROPPED');
        continue;
      }
      final timeLine = lines[0].contains('-->') ? 0 : 1;
      if (lines.length <= timeLine) {
        throw const StudioException('SUBTITLE_CUE_INVALID');
      }
      final m = RegExp(r'^(\S+)\s+-->\s+(\S+)(.*)$')
          .firstMatch(lines[timeLine]);
      if (m == null) throw const StudioException('SUBTITLE_TIMECODE');
      if (m[3]!.trim().isNotEmpty) warnings.add('WEBVTT_CUE_SETTINGS_DROPPED');
      add(
        _time(m[1]!),
        _time(m[2]!),
        _text(lines.skip(timeLine + 1).join('\n'), warnings),
      );
    }
    return CaptionImport(cues, warnings);
  }

  /// ASS export requires registered font/style layout and is intentionally absent;
  /// parsing the static text subset does not claim deterministic ASS rendering.
  static String encode(CaptionStore store, CaptionFormat format) {
    if (format == CaptionFormat.ass) {
      throw const StudioException('ASS_EXPORT_FONT_POLICY_REQUIRED');
    }
    String clock(BigInt ms) {
      if (ms > BigInt.from(3599999999999)) {
        throw const StudioException('SUBTITLE_TIMECODE_RANGE');
      }
      final t = ms.toInt(),
          h = t ~/ 3600000,
          m = t ~/ 60000 % 60,
          s = t ~/ 1000 % 60,
          f = t % 1000;
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}${format == CaptionFormat.srt ? ',' : '.'}${f.toString().padLeft(3, '0')}';
    }

    final out = StringBuffer(format == CaptionFormat.vtt ? 'WEBVTT\n\n' : '');
    var index = 0;
    for (final c in store.cues) {
      final start = sampleIndex(c.range.start, 1000, Rounding.tiesToEven),
          end = sampleIndex(c.range.end, 1000, Rounding.tiesToEven);
      if (end <= start) {
        throw const StudioException('SUBTITLE_TIME_QUANTIZATION');
      }
      if (c.text.startsWith('\n') ||
          c.text.endsWith('\n') ||
          c.text.contains('\n\n')) {
        throw const StudioException('SUBTITLE_BLANK_LINE_UNREPRESENTABLE');
      }
      final text = c.text
          .replaceAll('&', '&amp;')
          .replaceAll('<', '&lt;')
          .replaceAll('>', '&gt;');
      out.writeln('${++index}\n${clock(start)} --> ${clock(end)}\n$text\n');
    }
    return out.toString();
  }
}
