import 'dart:typed_data';

import 'package:studio_contracts/studio_contracts.dart';

import 'audio_bus.dart';
import 'time.dart';

/// Compile official mix sources from a project document and already-decoded
/// 48k PCM. Muted / silent tracks and disabled clips are omitted, not mixed.
List<PcmInput> compileOfficialMixInputs({
  required Map<String, dynamic> project,
  required Map<String, Float32List> pcmByClipId,
  Map<String, GainEnvelope> clipAutomation = const {},
  Set<String> sourceAnchoredClipIds = const {},
}) {
  final sequences = project['sequences'] as List;
  if (sequences.length != 1) {
    throw const StudioException('FEATURE_NOT_IMPLEMENTED');
  }
  final sequence = sequences.single;
  final graph = AudioBusGraph([
    for (final raw in project['audioBuses'] as List)
      AudioBus.fromJson(Map<String, dynamic>.from(raw as Map)),
  ], sequence['masterBusId'] as String);
  final inputs = <PcmInput>[];
  for (final track in sequence['tracks'] as List) {
    if (track['kind'] != 'audio') continue;
    if (track['muted'] == true) continue;
    final busId = track['busId'] as String?;
    if (busId == null || !graph.buses.containsKey(busId)) {
      throw const StudioException('AUDIO_BUS_MISSING');
    }
    if (!graph.pathToMaster(busId).contains(graph.masterId)) {
      throw const StudioException('AUDIO_BUS_UNROUTED');
    }
    for (final clip in track['items'] as List) {
      if (clip['source'] == null || clip['enabled'] == false) continue;
      final id = clip['id'] as String;
      final samples = pcmByClipId[id];
      if (samples == null) {
        throw const StudioException('AUDIO_PCM_INVALID');
      }
      final timeMap = clip['timeMap'] as Map;
      if (timeMap['kind'] != 'linear') {
        throw const StudioException('FEATURE_NOT_IMPLEMENTED');
      }
      final rate = Q.fromJson(timeMap['rate']);
      inputs.add(
        PcmInput(
          busId: busId,
          samples: samples,
          channels: 2,
          automation: clipAutomation[id],
          clipStart: Q.fromJson(clip['timelineRange']['start']),
          sourceStart: Q.fromJson(clip['sourceRange']['start']),
          rate: rate,
          sourceAnchored: sourceAnchoredClipIds.contains(id),
        ),
      );
    }
  }
  return List<PcmInput>.unmodifiable(inputs);
}
