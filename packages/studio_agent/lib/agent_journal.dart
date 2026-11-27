import 'package:studio_contracts/studio_contracts.dart';

/// Durable, in-memory journal. Private reasoning chains are never stored.
/// This is not I-011 crash reconstruction and is not a SQLite snapshot.
final class JournalEntry {
  JournalEntry({
    required this.id,
    required this.kind,
    required this.commandId,
    required this.payload,
    required this.at,
  }) {
    requireId(id);
    requireId(commandId);
  }

  final String id, kind, commandId;
  final Map<String, Object?> payload;
  final DateTime at;
}

final class AgentJournal {
  final List<JournalEntry> _entries = [];
  final Set<String> _commandIds = {};

  bool get persistsReasoning => false;

  List<JournalEntry> get entries => List.unmodifiable(_entries);

  void append({
    required String id,
    required String kind,
    required String commandId,
    required Map<String, Object?> payload,
    required DateTime at,
  }) {
    if (kind == 'reasoning' || payload.containsKey('reasoning')) {
      // Drop hidden chain-of-thought. Keep only a marker that it was omitted.
      payload = Map<String, Object?>.from(payload)..remove('reasoning');
      if (kind == 'reasoning') {
        kind = 'reasoningOmitted';
      }
    }
    if (_commandIds.contains(commandId) && kind != 'reasoningOmitted') {
      // Idempotent append: identical command ids are not replayed.
      return;
    }
    _commandIds.add(commandId);
    _entries.add(
      JournalEntry(
        id: id,
        kind: kind,
        commandId: commandId,
        payload: Map.unmodifiable(payload),
        at: at.toUtc(),
      ),
    );
  }

  bool containsKind(String kind) => _entries.any((e) => e.kind == kind);

  bool payloadContains(String needle) => _entries.any(
    (e) => e.payload.values.any((v) => v.toString().contains(needle)),
  );
}
