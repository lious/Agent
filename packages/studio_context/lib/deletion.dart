import 'package:studio_contracts/studio_contracts.dart';

import 'compaction.dart';
import 'context_codes.dart';
import 'reducer.dart';

enum RemoteDeletionState {
  notRequested,
  queued,
  acknowledged,
  notSupported,
  failed,
  unknown,
}

final class RemoteDeletionStatus {
  RemoteDeletionStatus({
    required this.provider,
    required this.requestOrFileIdRef,
    required this.state,
  });

  final String provider, requestOrFileIdRef;
  final RemoteDeletionState state;

  /// Acknowledged is not proof the provider erased training or backups.
  bool get claimedGloballyErased => false;
}

final class PrivacyReport {
  PrivacyReport({
    required this.privacyEpoch,
    required this.purgedLocalRefs,
    required this.retractedIntentIds,
    required this.remoteCopies,
    required this.projectRevision,
    this.warnings = const [],
  });

  final int privacyEpoch, projectRevision;
  final List<String> purgedLocalRefs, retractedIntentIds;
  final List<RemoteDeletionStatus> remoteCopies;
  final List<String> warnings;
}

final class AssetRef {
  AssetRef(this.id, this.label);
  final String id, label;
  var deleted = false;
}

/// Forgetting barrier: purge a turn body, report provider limits, and
/// refuse guessed asset deletion. This does not roll back Project revisions.
final class DeletionBarrier {
  DeletionBarrier({
    required this.reducer,
    required this.store,
    this.projectRevision = 22,
  });

  final EffectiveIntentReducer reducer;
  final CompactionStore store;
  int projectRevision;
  final remoteCopies = <String, RemoteDeletionStatus>{};
  final assets = <String, AssetRef>{};

  void registerRemoteCopy(RemoteDeletionStatus status) {
    remoteCopies[status.requestOrFileIdRef] = status;
  }

  void registerAsset(AssetRef asset) => assets[asset.id] = asset;

  PrivacyReport purgeTurn(String turnId, {required Set<String> bodyIds}) {
    reducer.privacyEpoch += 1;
    final purged = <String>[];
    final retracted = <String>[];
    for (final id in bodyIds) {
      final body = reducer.bodies[id];
      if (body == null) continue;
      body.text = null;
      body.state = BodyState.purged;
      purged.add(id);
    }
    for (final intent in reducer.intents.values) {
      final solely = intent.sourceTurnIds.length == 1 &&
          intent.sourceTurnIds.single == turnId;
      final valuePurged =
          intent.valueRef != null && bodyIds.contains(intent.valueRef);
      if (solely || valuePurged) {
        intent.status = IntentStatus.purged;
        intent.valueRef = null;
        intent.retiredAtSeq = reducer.headSeq;
        retracted.add(intent.id);
      }
    }
    store.revokeStale();
    // Project revision is unchanged by a chat-body purge.
    final remotes = [
      for (final copy in remoteCopies.values)
        if (bodyIds.contains(copy.requestOrFileIdRef) ||
            copy.state != RemoteDeletionState.notRequested)
          RemoteDeletionStatus(
            provider: copy.provider,
            requestOrFileIdRef: copy.requestOrFileIdRef,
            state: copy.state == RemoteDeletionState.notRequested
                ? RemoteDeletionState.notSupported
                : copy.state,
          ),
    ];
    return PrivacyReport(
      privacyEpoch: reducer.privacyEpoch,
      purgedLocalRefs: purged,
      retractedIntentIds: retracted,
      remoteCopies: remotes,
      projectRevision: projectRevision,
      warnings: [
        for (final r in remotes)
          if (r.state == RemoteDeletionState.notSupported ||
              r.state == RemoteDeletionState.acknowledged)
            'provider-body-not-guaranteed-erased:${r.provider}',
      ],
    );
  }

  /// Ambiguous natural-language references must not delete assets.
  void deleteAssetByReference(String phrase, List<AssetRef> candidates) {
    if (candidates.length != 1) {
      throw StudioException(referenceAmbiguous, phrase);
    }
    final chosen = candidates.single;
    final asset = assets[chosen.id];
    if (asset == null) throw StudioException('ASSET_NOT_FOUND', chosen.id);
    asset.deleted = true;
  }
}
