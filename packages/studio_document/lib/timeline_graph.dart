import 'package:studio_contracts/studio_contracts.dart';

import 'studio_document.dart';

/// Admitted single-video-track graph with scalar/keyframed opacity over black.
/// Not the complete multi-track/all-parameters/GPU RenderGraph.
/// Selection and source mapping use exact project rationals and half-open ranges.
final class TimelineVideoPoint {
  const TimelineVideoPoint(
    this.clipId,
    this.assetId,
    this.sourceVersion,
    this.sourceTime, [
    this.opacityQ16 = 65536,
    this.transform2d,
    this.secondary,
    this.mixQ16 = 0,
    this.rasterEffects,
    this.lumaWipe,
  ]);
  final String clipId;
  final String? assetId, sourceVersion;
  final Q sourceTime;
  final int opacityQ16;
  final TimelineVideoPoint? secondary;
  final int mixQ16;
  final Map<String, double>? transform2d;
  final Map<String, Map<String, double>>? rasterEffects;
  final LumaWipeSample? lumaWipe;
  bool get isGap => assetId == null;
}

final class TimelineVideoGraph {
  TimelineVideoGraph(ProjectDocument project) : snapshotHash = project.hash {
    requireLocalEditingWritable(project);
    final d = project.toJson(), s = d['sequences'][0];
    if ((d['captions'] as List).isNotEmpty) {
      throw const StudioException('CAPTION_RENDER_POLICY_NOT_IMPLEMENTED');
    }
    duration = Q.fromJson(s['duration']);
    final bg = s['backgroundRGBA'] as List;
    if (bg.length != 4 ||
        bg[0] != 0 ||
        bg[1] != 0 ||
        bg[2] != 0 ||
        bg[3] != 1) {
      throw const StudioException('TIMELINE_BACKGROUND_UNSUPPORTED');
    }
    final canvas = s['canvas'];
    if (Q.fromJson(canvas['pixelAspect']) != Q.of(1)) {
      throw const StudioException('TIMELINE_PIXEL_ASPECT_UNSUPPORTED');
    }
    final width = canvas['width'] as int, height = canvas['height'] as int;
    final longest = width > height ? width : height;
    previewWidth = longest <= 128
        ? width
        : (width * 128 ~/ longest).clamp(1, 128);
    previewHeight = longest <= 128
        ? height
        : (height * 128 ~/ longest).clamp(1, 128);
    _document = d;
    _frameRate = FrameRate(s['frameRate']['n'], s['frameRate']['d']);
    final assets = {for (final a in d['assets']) a['id']: a};
    final tracks = (s['tracks'] as List)
        .where((t) => t['kind'] == 'video')
        .toList();
    _items = tracks.isEmpty
        ? []
        : List<Map<String, dynamic>>.from(
            (tracks.single['items'] as List).map(
              (v) => Map<String, dynamic>.from(v as Map),
            ),
          );
    for (final clip in _items) {
      for (final field in ['start', 'duration']) {
        final t = Q.fromJson(clip['timelineRange'][field]);
        if (_frameRate.quantize(t, Rounding.tiesToEven) != t) {
          throw const StudioException('TIMELINE_FRAME_GRID_UNSUPPORTED');
        }
      }
      if (clip['source'] != null) {
        final source = clip['source'], asset = assets[source['id']];
        final stream = (asset['streams'] as List).singleWhere(
          (s) => s['id'] == source['streamId'],
        );
        if (stream['width'] != canvas['width'] ||
            stream['height'] != canvas['height']) {
          throw const StudioException('TIMELINE_SCALING_UNSUPPORTED');
        }
      }
      if (clip['source'] != null &&
          Q.fromJson(clip['timeMap']['rate']) != Q.of(1)) {
        throw const StudioException('RETIME_RENDER_NOT_IMPLEMENTED');
      }
    }
  }
  final String snapshotHash;
  late final Q duration;
  late final Map<String, dynamic> _document;
  late final FrameRate _frameRate;
  late final int previewWidth, previewHeight;
  late final List<Map<String, dynamic>> _items;

  /// Same admitted source/range nodes as preview, compiled for the original-file
  /// native encoder. Never encodes the reduced proxy/Flutter framebuffer.
  Map<String, dynamic> encoderSegment(
    String clipId, {
    required String originalPath,
    required int streamIndex,
    required FrameRate frameRate,
  }) {
    final clip = _items.singleWhere((c) => c['id'] == clipId);
    if (clip['source'] == null || clip['enabled'] == false) {
      throw const StudioException('GRAPH_SOURCE_REQUIRED');
    }
    return {
      'path': originalPath,
      'startFrame': frameRate
          .frameIndex(
            Q.fromJson(clip['timelineRange']['start']),
            Rounding.tiesToEven,
          )
          .toInt(),
      'frameCount': frameRate
          .frameIndex(
            Q.fromJson(clip['timelineRange']['duration']),
            Rounding.tiesToEven,
          )
          .toInt(),
      'sourceStart': Q.fromJson(clip['sourceRange']['start']).toJson(),
      ...transformRecipeFields(
        transformScheduleRange(
          _document,
          clip,
          frameRate,
          Q.of(0),
          frameRate
              .frameIndex(
                Q.fromJson(clip['timelineRange']['duration']),
                Rounding.tiesToEven,
              )
              .toInt(),
        ),
      ),
      'rasterEffects': ?clipRasterEffects(_document, clip),
      'streamIndex': streamIndex,
      if ((clip['effectIds'] as List).isNotEmpty &&
          (_document['effects'] as List).any(
            (e) =>
                e['type'] == 'opacity' &&
                (clip['effectIds'] as List).contains(e['id']) &&
                (e['keyframes'] as List).isNotEmpty,
          ))
        'opacityFramesQ16': opacityScheduleQ16(_document, clip, frameRate)
      else if (clipOpacityQ16(_document, clip) != 65536)
        'opacityQ16': clipOpacityQ16(_document, clip),
    };
  }

  /// A presentation sample, phased to the same delivery frame as the encoder.
  /// Exact source-time queries retain their original semantics via [sample].
  TimelineVideoPoint sampleFrame(Q time) {
    _requireTime(time);
    return sample(_frameRate.quantize(time, Rounding.floor));
  }

  void _requireTime(Q time) {
    if (time < Q.of(0) || time >= duration) {
      throw const StudioException('TIMELINE_TIME_OUT_OF_RANGE');
    }
  }

  TimelineVideoPoint _clipPoint(Map c, Q time) => TimelineVideoPoint(
    c['id'] as String,
    c['source']['id'] as String,
    c['source']['version'] as String,
    Q.fromJson(c['sourceRange']['start']) +
        (time - Q.fromJson(c['timelineRange']['start'])) *
            Q.fromJson(c['timeMap']['rate']),
    clipOpacityQ16(
      _document,
      c,
      time - Q.fromJson(c['timelineRange']['start']),
    ),
    clipTransform2d(
      _document,
      c,
      time - Q.fromJson(c['timelineRange']['start']),
    ),
    null,
    0,
    clipRasterEffects(_document, c),
  );

  /// Split only at delivery-grid boundaries; composite intervals have at most2
  /// decoded sources. source metadata/path verification stays in the SDK.
  List<Map<String, dynamic>> compileDissolves(
    Map<String, Map<String, dynamic>> byClip,
  ) {
    final total = _frameRate.frameIndex(duration, Rounding.tiesToEven);
    if (total < BigInt.one || total > BigInt.from(120000)) {
      throw const StudioException('RENDER_FRAME_LIMIT');
    }
    final boundaries = <Q>{Q.of(0), duration};
    for (final c in _items) {
      final start = Q.fromJson(c['timelineRange']['start']);
      boundaries.add(start);
      boundaries.add(start + Q.fromJson(c['timelineRange']['duration']));
    }
    for (final t in _document['transitions']) {
      if (t['enabled'] == true) {
        boundaries.add(Q.fromJson(t['cut']) - Q.fromJson(t['before']));
        boundaries.add(Q.fromJson(t['cut']) + Q.fromJson(t['after']));
      }
    }
    for (final e in lumaWipeEffects(_document)) {
      if (e['enabled'] == true) {
        final p = e['parameters'] as Map;
        final cut = lumaParamTime(p, 'cut'),
            before = lumaParamTime(p, 'before'),
            after = lumaParamTime(p, 'after');
        boundaries.add(cut - before);
        boundaries.add(cut + after);
      }
    }
    final times = boundaries.toList()..sort();
    Map<String, dynamic> node(TimelineVideoPoint p, Q time, int count) {
      final clip = _items.singleWhere((c) => c['id'] == p.clipId),
          base = byClip[p.clipId];
      if (base == null) throw const StudioException('GRAPH_SOURCE_REQUIRED');
      final values = opacityScheduleRangeQ16(
        _document,
        clip,
        _frameRate,
        time - Q.fromJson(clip['timelineRange']['start']),
        count,
      );
      return {
        'path': base['path'],
        'streamIndex': base['streamIndex'],
        'sourceStart': p.sourceTime.toJson(),
        ...transformRecipeFields(
          transformScheduleRange(
            _document,
            clip,
            _frameRate,
            time - Q.fromJson(clip['timelineRange']['start']),
            count,
          ),
        ),
        if (p.rasterEffects != null) 'rasterEffects': p.rasterEffects,
        if (values.every((v) => v == values.first))
          'opacityQ16': values.first
        else
          'opacityFramesQ16': values,
      };
    }

    final result = <Map<String, dynamic>>[];
    for (var i = 0; i < times.length - 1; i++) {
      final time = times[i], end = times[i + 1];
      if (time >= duration || end <= time) continue;
      final point = sample(time);
      if (point.isGap) continue;
      final count = _frameRate
          .frameIndex(end - time, Rounding.tiesToEven)
          .toInt();
      final recipe = {
        'startFrame': _frameRate.frameIndex(time, Rounding.tiesToEven).toInt(),
        'frameCount': count,
        ...node(point, time, count),
      };
      if (point.secondary != null) {
        recipe['secondary'] = node(point.secondary!, time, count);
        if (point.lumaWipe != null) {
          final effect = lumaWipeEffects(_document).singleWhere(
            (e) =>
                e['enabled'] == true &&
                e['parameters']['leftClipId'] == point.clipId &&
                e['parameters']['rightClipId'] == point.secondary!.clipId,
          );
          final p = effect['parameters'] as Map;
          // Never emit mixFramesQ16: a dissolve consumer must not silently
          // blend this pair.
          recipe['lumaWipe'] = {
            'softness': (p['softness'] as num).toDouble(),
            'invert': p['invert'] as bool,
            'progress': [
              for (var f = 0; f < count; f++)
                lumaWipeProgress(
                  time + _frameRate.frameTime(BigInt.from(f)),
                  lumaParamTime(p, 'cut'),
                  lumaParamTime(p, 'before'),
                  lumaParamTime(p, 'after'),
                ).toJson(),
            ],
          };
        } else {
          final transition = (_document['transitions'] as List).singleWhere(
            (t) =>
                t['enabled'] == true &&
                t['leftClipId'] == point.clipId &&
                t['rightClipId'] == point.secondary!.clipId,
          );
          final start =
                  Q.fromJson(transition['cut']) -
                  Q.fromJson(transition['before']),
              length =
                  Q.fromJson(transition['before']) +
                  Q.fromJson(transition['after']);
          recipe['mixFramesQ16'] = [
            for (var f = 0; f < count; f++)
              dissolveMixQ16(
                time + _frameRate.frameTime(BigInt.from(f)) - start,
                length,
              ),
          ];
        }
      }
      result.add(recipe);
    }
    return result;
  }

  TimelineVideoPoint sample(Q time) {
    _requireTime(time);
    for (final t in _document['transitions']) {
      if (t['enabled'] != true) continue;
      final begin = Q.fromJson(t['cut']) - Q.fromJson(t['before']),
          length = Q.fromJson(t['before']) + Q.fromJson(t['after']);
      if (time >= begin && time < begin + length) {
        final left = _items.singleWhere((c) => c['id'] == t['leftClipId']),
            right = _items.singleWhere((c) => c['id'] == t['rightClipId']);
        final a = _clipPoint(left, time), b = _clipPoint(right, time);
        return TimelineVideoPoint(
          a.clipId,
          a.assetId,
          a.sourceVersion,
          a.sourceTime,
          a.opacityQ16,
          a.transform2d,
          b,
          dissolveMixQ16(time - begin, length),
          a.rasterEffects,
        );
      }
    }
    for (final e in lumaWipeEffects(_document)) {
      if (e['enabled'] != true) continue;
      final p = e['parameters'] as Map;
      final cut = lumaParamTime(p, 'cut'),
          before = lumaParamTime(p, 'before'),
          after = lumaParamTime(p, 'after');
      final begin = cut - before, length = before + after;
      if (time >= begin && time < begin + length) {
        final left = _items.singleWhere((c) => c['id'] == p['leftClipId']),
            right = _items.singleWhere((c) => c['id'] == p['rightClipId']);
        final a = _clipPoint(left, time), b = _clipPoint(right, time);
        return TimelineVideoPoint(
          a.clipId,
          a.assetId,
          a.sourceVersion,
          a.sourceTime,
          a.opacityQ16,
          a.transform2d,
          b,
          0,
          a.rasterEffects,
          LumaWipeSample(
            progress: lumaWipeProgress(time, cut, before, after),
            softness: (p['softness'] as num).toDouble(),
            invert: p['invert'] as bool,
          ),
        );
      }
    }
    for (final c in _items) {
      final range = c['timelineRange'],
          start = Q.fromJson(range['start']),
          length = Q.fromJson(range['duration']);
      if (time < start || time >= start + length) continue;
      if (c['enabled'] == false) continue;
      final source = c['source'];
      if (source == null) {
        return TimelineVideoPoint(c['id'] as String, null, null, Q.of(0));
      }
      return TimelineVideoPoint(
        c['id'] as String,
        source['id'] as String,
        source['version'] as String,
        Q.fromJson(c['sourceRange']['start']) +
            (time - start) * Q.fromJson(c['timeMap']['rate']),
        clipOpacityQ16(_document, c, time - start),
        clipTransform2d(_document, c, time - start),
        null,
        0,
        clipRasterEffects(_document, c),
      );
    }
    return TimelineVideoPoint('gap', null, null, Q.of(0));
  }
}

int dissolveMixQ16(Q elapsed, Q duration) {
  final x = elapsed / duration;
  return ((x.n * BigInt.from(65536)) ~/ x.d).toInt();
}
