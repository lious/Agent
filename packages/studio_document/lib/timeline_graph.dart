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
  ]);
  final String clipId;
  final String? assetId, sourceVersion;
  final Q sourceTime;
  final int opacityQ16;
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
      'streamIndex': streamIndex,
      if ((clip['effectIds'] as List).isNotEmpty &&
          (_document['effects'] as List).any(
            (e) =>
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

  TimelineVideoPoint sample(Q time) {
    _requireTime(time);
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
      );
    }
    return TimelineVideoPoint('gap', null, null, Q.of(0));
  }
}
