import 'package:studio_contracts/studio_contracts.dart';
import 'package:studio_document/studio_document.dart';

/// Future adapter seams only. No implementation is installed in this release.
/// Capability IDs are obtained by host permission UI, never interpreted as paths.
abstract interface class MediaEnginePort {
  Future<ImportEditPlan> planImport({
    required Namespace namespace,
    required String localFileCapabilityId,
    required ProjectDocument base,
  });
  Future<LocalExportReceipt> export({
    required ProjectDocument frozenSnapshot,
    required String presetId,
    required String localOutputCapabilityId,
  });
}

abstract interface class ImportEditPlan {
  Namespace get namespace;
  BigInt get expectedRevision;
  String get previewHash;
}

abstract interface class LocalExportReceipt {
  String get jobId;
  String get renderedSnapshotHash;
  String get outputHash;
}

/// .studioproj packaging/restoration is separate from the working SQLite DB.
abstract interface class ProjectArchivePort {
  Future<void> save({
    required ProjectDocument frozenSnapshot,
    required String localOutputCapabilityId,
  });
  Future<ProjectDocument> restore({
    required Namespace targetNamespace,
    required String localFileCapabilityId,
  });
}
