part of 'studio_media.dart';

/// Offline file execution, not a device AudioSink or presented-sample clock.
/// One decoded region + final PCM file, <=120s stereo;1024-frame Dart DSP blocks.
Map<String, dynamic> _prepareAudio(
  NativeMedia media,
  Map<String, dynamic> recipe,
  int epoch,
) {
  void check() {
    if (media.cancelEpoch != epoch) throw const StudioException('CANCELED');
  }

  final count = recipe['sampleCount'] as int;
  if (Endian.host != Endian.little) {
    throw const StudioException('PCM_ENDIAN_UNSUPPORTED');
  }
  if (count < 1 || count > 120 * 48000) {
    throw const StudioException('AUDIO_EXPORT_DURATION_LIMIT');
  }
  final segments = (recipe['segments'] as List).cast<Map<String, dynamic>>();
  if (segments.length > 128) throw const StudioException('AUDIO_SEGMENT_LIMIT');
  final graph = AudioBusGraph(
    (recipe['buses'] as List)
        .map((b) => AudioBus.fromJson(Map<String, dynamic>.from(b as Map)))
        .toList(),
    recipe['masterId'] as String,
  );
  final dir = Directory(recipe['directory'] as String),
      mixed = File('${dir.path}/mix.f32');
  if (mixed.existsSync()) throw const StudioException('PCM_OUTPUT_MUST_BE_NEW');
  final file = mixed.openSync(mode: FileMode.write);
  final zeros = Uint8List(1024 * 8);
  var cursor = 0;
  var peak = 0.0;
  var committed = false;
  final regions = <Map<String, dynamic>>[];
  void silenceUntil(int n) {
    while (cursor < n) {
      check();
      final frames = math.min(1024, n - cursor);
      file.writeFromSync(zeros, 0, frames * 8);
      cursor += frames;
    }
  }

  try {
    for (final segment in segments) {
      check();
      final start = segment['destStart'] as int,
          n = segment['sampleCount'] as int;
      if (start < cursor || n < 1 || start + n > count) {
        throw const StudioException('AUDIO_SEGMENT_RANGE');
      }
      silenceUntil(start);
      if (segment['streamIndex'] == null) {
        silenceUntil(start + n);
        continue;
      }
      final decoded = File('${dir.path}/region.f32');
      RandomAccessFile? source;
      try {
        regions.add(
          media._call(
            'sm_decode_audio',
            jsonEncode({
              'path': segment['path'],
              'outputPath': decoded.path,
              'streamIndex': segment['streamIndex'],
              'startSample': segment['startSample'],
              'sampleCount': n,
            }),
          ),
        );
        check();
        source = decoded.openSync();
        for (var at = 0; at < n; at += 1024) {
          check();
          final frames = math.min(1024, n - at),
              bytes = source.readSync(frames * 8);
          if (bytes.length != frames * 8) {
            throw const StudioException('PCM_READ_FAILED');
          }
          final raw = bytes.buffer.asFloat32List(
            bytes.offsetInBytes,
            frames * 2,
          );
          final result = mix48k(graph, [
            PcmInput(
              busId: (segment['busId'] as String?) ?? graph.masterId,
              samples: raw,
              channels: 2,
            ),
          ]);
          peak = math.max(peak, result.peak);
          file.writeFromSync(result.interleavedStereo.buffer.asUint8List());
          cursor += frames;
        }
      } finally {
        source?.closeSync();
        if (decoded.existsSync()) decoded.deleteSync();
      }
    }
    silenceUntil(count);
    file.flushSync();
    check();
    committed = true;
    return {
      'path': mixed.path,
      'sampleCount': count,
      'peak': peak,
      'warnings': [if (peak > 1) 'CLIPPING_RISK'],
      'regions': regions,
    };
  } finally {
    try {
      file.closeSync();
    } finally {
      if (!committed && mixed.existsSync()) mixed.deleteSync();
    }
  }
}
