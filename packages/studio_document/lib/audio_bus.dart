import 'dart:math' as math;
import 'dart:typed_data';

import 'package:studio_contracts/studio_contracts.dart';

import 'time.dart';

double _bounded(double value, double lo, double hi) {
  if (!value.isFinite || value < lo || value > hi) {
    throw const StudioException('AUDIO_PARAMETER_RANGE');
  }
  return value;
}

double gainAmplitude(double db) =>
    math.pow(10, _bounded(db, -96, 12) / 20).toDouble();
List<double> monoPan(double p) {
  _bounded(p, -1, 1);
  return [math.cos((p + 1) * math.pi / 4), math.sin((p + 1) * math.pi / 4)];
}

List<double> stereoBalance(double p) {
  _bounded(p, -1, 1);
  return [p > 0 ? 1 - p : 1, p < 0 ? 1 + p : 1];
}

final class AudioBus {
  AudioBus({
    required this.id,
    required List<String> inputs,
    this.output,
    this.gainDb = 0,
    this.pan = 0,
    this.muted = false,
    this.solo = false,
  }) : inputs = List.unmodifiable(inputs) {
    requireId(id);
    _bounded(gainDb, -96, 12);
    _bounded(pan, -1, 1);
    if (inputs.toSet().length != inputs.length) {
      throw const StudioException('DUPLICATE_AUDIO_ROUTE');
    }
  }
  final String id;
  final List<String> inputs;
  final String? output;
  final double gainDb, pan;
  final bool muted, solo;
  factory AudioBus.fromJson(Map<String, dynamic> b) {
    if ((b['effectIds'] as List).isNotEmpty) {
      throw const StudioException('AUDIO_EFFECT_NOT_IMPLEMENTED');
    }
    return AudioBus(
      id: b['id'] as String,
      inputs: List<String>.from(b['inputBusIds'] as List),
      output: b['outputBusId'] as String?,
      gainDb: (b['gainDb'] as num).toDouble(),
      pan: (b['pan'] as num).toDouble(),
      muted: b['muted'] as bool,
      solo: b['solo'] as bool,
    );
  }
}

/// Validates the entire graph, including unused components; recipe is immutable,
/// topologically ordered upstream-to-master, not dependent on input list order.
final class AudioBusGraph {
  AudioBusGraph(List<AudioBus> values, this.masterId)
    : buses = Map.unmodifiable({for (final b in values) b.id: b}) {
    if (values.length > 64) {
      throw const StudioException('AUDIO_GRAPH_RESOURCE_LIMIT');
    }
    if (values.length != buses.length) {
      throw const StudioException('DUPLICATE_ID');
    }
    if (!buses.containsKey(masterId) || buses[masterId]!.output != null) {
      throw const StudioException('AUDIO_MASTER_INVALID');
    }
    for (final b in values) {
      if (b.output != null &&
          !(buses[b.output]?.inputs.contains(b.id) ?? false)) {
        throw const StudioException('AUDIO_ROUTE_MISMATCH');
      }
      for (final input in b.inputs) {
        if (!buses.containsKey(input) || buses[input]!.output != b.id) {
          throw const StudioException('AUDIO_ROUTE_MISMATCH');
        }
      }
    }
    final visiting = <String>{}, done = <String>{};
    void visit(String id) {
      if (visiting.contains(id)) {
        throw const StudioException('AUDIO_ROUTE_CYCLE');
      }
      if (done.contains(id)) return;
      visiting.add(id);
      for (final child in buses[id]!.inputs) {
        visit(child);
      }
      visiting.remove(id);
      done.add(id);
    }

    for (final id in buses.keys) {
      visit(id);
    }
    final order = <String>[];
    void append(String id) {
      final children = buses[id]!.inputs.toList()..sort();
      for (final child in children) {
        append(child);
      }
      order.add(id);
    }

    append(masterId);
    recipe = List.unmodifiable(order);
  }
  final Map<String, AudioBus> buses;
  final String masterId;
  late final List<String> recipe;
  List<String> pathToMaster(String id) {
    if (!buses.containsKey(id)) {
      throw const StudioException('AUDIO_BUS_MISSING');
    }
    final path = <String>[];
    String? cursor = id;
    while (cursor != null) {
      path.add(cursor);
      cursor = buses[cursor]!.output;
    }
    return path;
  }
}

enum GainInterpolation { hold, linear }

final class GainPoint {
  GainPoint(
    this.time,
    this.db, {
    this.interpolation = GainInterpolation.linear,
  }) {
    if (time < Q.of(0)) throw const StudioException('INVALID_RANGE');
    _bounded(db, -96, 12);
  }
  final Q time;
  final double db;
  final GainInterpolation interpolation;
}

/// Keyframes stay in owner-local coordinates. Source anchored curves are mapped
/// through the exact linear TimeMap before sampling; no accumulated rounded clock.
final class GainEnvelope {
  GainEnvelope(List<GainPoint> values) : points = List.unmodifiable(values) {
    if (values.isEmpty) throw const StudioException('EMPTY_GAIN_ENVELOPE');
    for (var i = 1; i < values.length; i++) {
      if (values[i].time <= values[i - 1].time) {
        throw const StudioException('GAIN_TIME_ORDER');
      }
    }
  }
  final List<GainPoint> points;
  double at(Q time) {
    if (time <= points.first.time) return points.first.db;
    for (var i = 1; i < points.length; i++) {
      final a = points[i - 1], b = points[i];
      if (time < b.time) {
        if (a.interpolation == GainInterpolation.hold) return a.db;
        final q = (time - a.time) / (b.time - a.time);
        return a.db + (b.db - a.db) * q.n.toDouble() / q.d.toDouble();
      }
    }
    return points.last.db;
  }

  double atTimeline(
    Q time, {
    required Q clipStart,
    required Q sourceStart,
    required Q rate,
    bool sourceAnchored = false,
  }) {
    if (rate <= Q.of(0)) throw const StudioException('TIME_MAP_MISMATCH');
    return at(
      sourceAnchored
          ? sourceStart + (time - clipStart) * rate
          : time - clipStart,
    );
  }
}

/// Proposed AUTO layer only. It never mutates/replaces original manual points.
/// Each ramp uses the exact sequence->clip-local transform; overlaps take MIN dB.
/// manualProtected ranges are explicitly music-clip-local, not sequence coordinates.
final class DuckingProposal {
  DuckingProposal._(this.clipDuration, this.envelopes, this.warnings);
  final Q clipDuration;
  final List<GainEnvelope> envelopes;
  final List<String> warnings;
  double at(Q localTime) {
    if (localTime < Q.of(0) || localTime > clipDuration) return 0;
    return envelopes.fold(0.0, (v, e) => math.min(v, e.at(localTime)));
  }

  static DuckingProposal plan({
    required TimeRange clip,
    required List<TimeRange> speech,
    List<TimeRange> manualProtected = const [],
    bool trackLocked = false,
    bool gainLocked = false,
  }) {
    if (trackLocked) throw const StudioException('TRACK_LOCKED');
    if (gainLocked) throw const StudioException('MANUAL_LOCKED');
    final envelopes = <GainEnvelope>[], warnings = <String>[];
    for (final s in speech) {
      final a = s.start - clip.start - Q.of(1, 5),
          b = s.start - clip.start - Q.of(1, 20),
          c = s.end - clip.start,
          d = c + Q.of(3, 10);
      if (d <= Q.of(0) || a >= clip.duration) continue;
      final influence = TimeRange(a, d - a);
      if (manualProtected.any(influence.overlaps)) {
        warnings.add('MANUAL_REGION_SKIPPED');
        continue;
      }
      double value(Q t) {
        if (t < a || t >= d) return 0;
        if (t < b) {
          final q = (t - a) / (b - a);
          return -9 * q.n.toDouble() / q.d.toDouble();
        }
        if (t <= c) return -9;
        final q = (d - t) / (d - c);
        return -9 * q.n.toDouble() / q.d.toDouble();
      }

      final times = {
        Q.of(0),
        clip.duration,
        for (final t in [a, b, c, d])
          if (t > Q.of(0) && t < clip.duration) t,
      }.toList()..sort();
      envelopes.add(
        GainEnvelope([for (final t in times) GainPoint(t, value(t))]),
      );
    }
    return DuckingProposal._(
      clip.duration,
      List.unmodifiable(envelopes),
      List.unmodifiable(warnings),
    );
  }
}

/// CPU reference mixer for already-decoded 48k PCM. It is NOT a decoder,
/// resampler, output clock, time-stretcher, limiter or AAC encoder (I-023/I-024).
final class PcmInput {
  PcmInput({
    required this.busId,
    required Float32List samples,
    required this.channels,
    this.gainDb = 0,
    this.pan = 0,
    this.muted = false,
    this.solo = false,
  }) : samples = Float32List.fromList(samples).asUnmodifiableView() {
    if (channels != 1 && channels != 2) {
      throw const StudioException('AUDIO_LAYOUT_UNSUPPORTED');
    }
    if (samples.length % channels != 0 || samples.any((v) => !v.isFinite)) {
      throw const StudioException('AUDIO_PCM_INVALID');
    }
    _bounded(gainDb, -96, 12);
    _bounded(pan, -1, 1);
  }
  final String busId;
  final Float32List samples;
  final int channels;
  final double gainDb, pan;
  final bool muted, solo;
}

final class MixedAudio {
  MixedAudio(this.interleavedStereo, this.peak)
    : warnings = List.unmodifiable(
        peak > 1 ? ['CLIPPING_RISK'] : const <String>[],
      );
  final Float32List interleavedStereo;
  final double peak;
  final List<String> warnings;
}

MixedAudio mix48k(
  AudioBusGraph graph,
  List<PcmInput> inputs, {
  Map<String, GainEnvelope> automation = const {},
}) {
  final frames = inputs.isEmpty
      ? 0
      : inputs.first.samples.length ~/ inputs.first.channels;
  if (frames > 60 * 48000 ||
      frames * 2 * 8 * graph.recipe.length > 256 * 1024 * 1024) {
    throw const StudioException('AUDIO_BLOCK_RESOURCE_LIMIT');
  }
  for (final input in inputs) {
    if (input.samples.length ~/ input.channels != frames) {
      throw const StudioException('AUDIO_LENGTH_MISMATCH');
    }
    final path = graph.pathToMaster(input.busId);
    if (!path.contains(graph.masterId) && !input.muted) {
      throw const StudioException('AUDIO_BUS_UNROUTED');
    }
  }
  for (final id in automation.keys) {
    if (!graph.buses.containsKey(id)) {
      throw const StudioException('AUDIO_BUS_MISSING');
    }
  }
  final anySolo =
          graph.recipe.any((id) => graph.buses[id]!.solo) ||
          inputs.any((i) => i.solo),
      buffers = <String, Float64List>{};
  for (final id in graph.recipe) {
    final bus = graph.buses[id]!, out = Float64List(frames * 2);
    if (!bus.muted) {
      for (final child in bus.inputs) {
        final pcm = buffers[child]!;
        for (var i = 0; i < out.length; i++) {
          out[i] += pcm[i];
        }
      }
      for (final input in inputs.where((i) => i.busId == id && !i.muted)) {
        if (anySolo &&
            !input.solo &&
            !graph
                .pathToMaster(input.busId)
                .any((id) => graph.buses[id]!.solo)) {
          continue;
        }
        final gain = gainAmplitude(input.gainDb),
            pan = input.channels == 1
                ? monoPan(input.pan)
                : stereoBalance(input.pan);
        for (var f = 0; f < frames; f++) {
          out[f * 2] += input.samples[f * input.channels] * gain * pan[0];
          out[f * 2 + 1] +=
              input.samples[f * input.channels +
                  (input.channels == 1 ? 0 : 1)] *
              gain *
              pan[1];
        }
      }
      final pan = stereoBalance(bus.pan),
          gain = gainAmplitude(bus.gainDb),
          curve = automation[id];
      for (var f = 0; f < frames; f++) {
        final g =
            gain *
            (curve == null ? 1 : gainAmplitude(curve.at(Q.of(f, 48000))));
        out[f * 2] *= g * pan[0];
        out[f * 2 + 1] *= g * pan[1];
      }
    }
    buffers[id] = out;
  }
  final output = Float32List(frames * 2), master = buffers[graph.masterId]!;
  var peak = 0.0;
  for (var i = 0; i < output.length; i++) {
    output[i] = master[i];
    if (!output[i].isFinite) throw const StudioException('AUDIO_PCM_INVALID');
    peak = math.max(peak, output[i].abs());
  }
  return MixedAudio(output, peak);
}
