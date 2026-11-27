import 'package:studio_contracts/studio_contracts.dart';

import 'context_codes.dart';
import 'hashing.dart';
import 'reducer.dart';

enum SnapshotStatus { draft, published, revoked, purged }

/// A published or draft compaction watermark. This is not a chat
/// summary and must not be treated as a fact database.
final class CompactionSnapshot {
  CompactionSnapshot({
    required this.id,
    required this.branchId,
    required this.watermark,
    required this.privacyEpoch,
    required this.intentDigest,
    required this.status,
    required this.effectiveIntentIds,
    this.claimTexts = const [],
    this.legacyUntrusted = false,
  });

  final String id, branchId, intentDigest;
  final int watermark, privacyEpoch;
  SnapshotStatus status;
  final List<String> effectiveIntentIds;
  final List<String> claimTexts;
  final bool legacyUntrusted;
}

final class CompiledContext {
  CompiledContext({
    required this.intentIds,
    required this.values,
    required this.privacyEpoch,
    required this.watermark,
    this.droppedClaimIds = const [],
  });

  final List<String> intentIds;
  final Map<String, String> values;
  final int privacyEpoch, watermark;
  final List<String> droppedClaimIds;
}

/// Deterministic compiler and watermarked snapshot store. A privacy-epoch
/// or watermark mismatch discards the snapshot and requires a rebuild.
final class CompactionStore {
  CompactionStore(this.reducer);
  final EffectiveIntentReducer reducer;
  final snapshots = <String, CompactionSnapshot>{};

  CompactionSnapshot buildDraft({required String id}) {
    requireId(id);
    return CompactionSnapshot(
      id: id,
      branchId: reducer.branchId,
      watermark: reducer.headSeq,
      privacyEpoch: reducer.privacyEpoch,
      intentDigest: reducer.intentDigest(),
      status: SnapshotStatus.draft,
      effectiveIntentIds: [for (final i in reducer.active()) i.id],
    );
  }

  CompactionSnapshot publish(
    CompactionSnapshot draft, {
    required int expectedHead,
    required int expectedPrivacyEpoch,
    required String expectedDigest,
  }) {
    if (draft.status != SnapshotStatus.draft) {
      throw StudioException(snapshotStale, draft.id);
    }
    if (expectedHead != reducer.headSeq ||
        expectedPrivacyEpoch != reducer.privacyEpoch ||
        expectedDigest != reducer.intentDigest() ||
        draft.privacyEpoch != reducer.privacyEpoch ||
        draft.watermark != expectedHead ||
        draft.intentDigest != expectedDigest) {
      throw StudioException(snapshotStale, draft.id);
    }
    final published = CompactionSnapshot(
      id: draft.id,
      branchId: draft.branchId,
      watermark: draft.watermark,
      privacyEpoch: draft.privacyEpoch,
      intentDigest: draft.intentDigest,
      status: SnapshotStatus.published,
      effectiveIntentIds: List.of(draft.effectiveIntentIds),
    );
    snapshots[published.id] = published;
    return published;
  }

  void revokeStale() {
    for (final snap in snapshots.values) {
      if (snap.privacyEpoch != reducer.privacyEpoch) {
        snap.status = SnapshotStatus.revoked;
      }
    }
  }

  /// Compile current effective intent from the reducer ledger, optionally
  /// starting from a published snapshot plus tail. Free-text chat summaries
  /// and legacy-untrusted claims are dropped and cannot revive retired values.
  CompiledContext compile({
    CompactionSnapshot? snapshot,
    List<String> chatSummaryClaims = const [],
  }) {
    if (snapshot != null) {
      if (snapshot.privacyEpoch != reducer.privacyEpoch ||
          snapshot.status == SnapshotStatus.revoked ||
          snapshot.status == SnapshotStatus.purged ||
          snapshot.legacyUntrusted) {
        throw StudioException(snapshotStale, snapshot.id);
      }
    }
    final values = <String, String>{};
    final ids = <String>[];
    for (final intent in reducer.active()) {
      final body = intent.valueRef == null
          ? null
          : reducer.bodies[intent.valueRef];
      if (body == null || body.state == BodyState.purged || body.text == null) {
        continue;
      }
      ids.add(intent.id);
      values[intent.fieldPath] = body.text!;
    }
    final dropped = <String>[];
    for (final claim in chatSummaryClaims) {
      // A chat summary is never applied as a current constraint.
      dropped.add(fingerprintString(claim));
    }
    return CompiledContext(
      intentIds: ids,
      values: values,
      privacyEpoch: reducer.privacyEpoch,
      watermark: reducer.headSeq,
      droppedClaimIds: dropped,
    );
  }
}
