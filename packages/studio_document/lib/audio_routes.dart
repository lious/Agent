part of 'edit_algebra.dart';

/// One official command that replaces the audio bus graph and optional track
/// routes as a single group. A cycle or lock conflict leaves the document
/// unchanged: no subset of the routes is committed.
final class SetAudioBusRoutes extends EditOperation {
  SetAudioBusRoutes({
    required List<Map<String, dynamic>> buses,
    required this.masterId,
    Map<String, String> trackBusIds = const {},
  }) : buses = List<Map<String, dynamic>>.unmodifiable([
         for (final bus in buses)
           Map<String, dynamic>.from(jsonDecode(jsonEncode(bus)) as Map),
       ]),
       trackBusIds = Map<String, String>.unmodifiable(trackBusIds) {
    if (masterId.isEmpty) {
      throw const StudioException('AUDIO_MASTER_INVALID');
    }
    AudioBusGraph([
      for (final bus in this.buses)
        AudioBus.fromJson(Map<String, dynamic>.from(bus)),
    ], masterId);
    if (this.buses.any((b) => (b['effectIds'] as List).isNotEmpty)) {
      throw const StudioException('AUDIO_EFFECT_NOT_IMPLEMENTED');
    }
  }
  final List<Map<String, dynamic>> buses;
  final String masterId;
  final Map<String, String> trackBusIds;
  @override
  Map<String, Object?> toJson() => {
    'kind': 'setAudioBusRoutes',
    'masterId': masterId,
    'buses': buses,
    'trackBusIds': trackBusIds,
  };
}

ProjectDocument _setAudioBusRoutes(
  ProjectDocument before,
  SetAudioBusRoutes operation,
  VersionAllocator nextVersion,
) {
  // Validate the intended graph first so a cycle never writes a partial list.
  final graph = AudioBusGraph([
    for (final bus in operation.buses)
      AudioBus.fromJson(Map<String, dynamic>.from(bus)),
  ], operation.masterId);
  final d = before.toJson(), sequences = d['sequences'] as List;
  if (sequences.length != 1 ||
      sequences[0]['masterBusId'] != operation.masterId) {
    throw const StudioException('AUDIO_MASTER_INVALID');
  }
  final tracks = sequences[0]['tracks'] as List;
  final byId = {for (final t in tracks) t['id'] as String: t};
  for (final entry in operation.trackBusIds.entries) {
    final track = byId[entry.key];
    if (track == null) {
      throw const StudioException('TRACK_NOT_FOUND');
    }
    if (track['kind'] != 'audio') {
      throw const StudioException('FEATURE_NOT_IMPLEMENTED');
    }
    if (track['locked'] == true && track['busId'] != entry.value) {
      throw const StudioException('FIELD_LOCKED');
    }
    if (!graph.buses.containsKey(entry.value)) {
      throw const StudioException('AUDIO_BUS_MISSING');
    }
    if (!graph.pathToMaster(entry.value).contains(graph.masterId)) {
      throw const StudioException('AUDIO_BUS_UNROUTED');
    }
  }
  final currentBuses = d['audioBuses'] as List;
  var changed = jsonEncode(currentBuses) != jsonEncode(operation.buses);
  final nextTracks = [
    for (final track in tracks) Map<String, dynamic>.from(track as Map),
  ];
  for (final track in nextTracks) {
    final nextBus = operation.trackBusIds[track['id']];
    if (nextBus != null && track['busId'] != nextBus) {
      track['busId'] = nextBus;
      changed = true;
    }
  }
  if (!changed) return before;
  d['audioBuses'] = [
    for (final bus in operation.buses) Map<String, dynamic>.from(bus),
  ];
  sequences[0]['tracks'] = nextTracks;
  sequences[0]['version'] = nextVersion(sequences[0]['id'] as String);
  final result = ProjectDocument.fromJson(d);
  requireLocalEditingWritable(result);
  return result;
}
