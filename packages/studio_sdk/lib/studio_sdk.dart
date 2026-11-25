import 'package:studio_store/studio_store.dart';
import 'package:studio_document/studio_document.dart';
import 'package:uuid/uuid.dart';
export 'package:studio_contracts/studio_contracts.dart';
export 'package:studio_document/studio_document.dart';
export 'package:studio_harness/studio_harness.dart';

export 'ports.dart';

/// Composition root for both hosts. No media, model, payment or upload port is
/// implicitly installed. All mutating calls use the same repository coordinator.
final class StudioWorkspace {
  StudioWorkspace.open({
    required this.profile,
    required String databasePath,
    required String tenantId,
    required String workspaceId,
  }) : _repository = DocumentRepository.open(
         databasePath,
         profile.namespace(tenantId, workspaceId),
       );
  final AppProfile profile;
  final DocumentRepository _repository;
  final _uuid = const Uuid();
  WriterToken? _writer;
  void _requireMetadata() {
    if (!profile.features.contains('project.metadata')) {
      throw const StudioException('CAPABILITY_UNAVAILABLE');
    }
  }

  ProjectDocument openDemo() {
    _requireMetadata();
    var project = _repository.read('demo-project');
    if (project == null) {
      project = ProjectDocument.empty(
        namespace: _repository.namespace,
        projectId: 'demo-project',
        title: 'Untitled',
      );
      _repository.create(project);
    }
    _writer = _repository.acquireWriter(
      project.projectId,
      _uuid.v7(),
      expectedEpoch: _repository.writerEpoch(project.projectId),
    );
    return project;
  }

  ProjectDocument get current => _repository.read('demo-project')!;
  bool get canUndo => _repository.latestCommandId('demo-project') != null;
  ProjectDocument rename(String title, {required BigInt expectedRevision}) {
    _requireMetadata();
    if (_writer == null) throw const StudioException('PROJECT_NOT_OPEN');
    final id = _uuid.v7();
    _repository.rename(
      writer: _writer!,
      commandId: id,
      receiptKey: id,
      expectedRevision: expectedRevision,
      title: title,
    );
    return current;
  }

  ProjectDocument undo({required BigInt expectedRevision}) {
    _requireMetadata();
    if (_writer == null) throw const StudioException('PROJECT_NOT_OPEN');
    final target = _repository.latestCommandId('demo-project');
    if (target == null) throw const StudioException('NOTHING_TO_UNDO');
    final id = _uuid.v7();
    _repository.undoLatest(
      writer: _writer!,
      commandId: id,
      receiptKey: id,
      expectedRevision: expectedRevision,
      targetCommandId: target,
    );
    return current;
  }

  void close() => _repository.close();
}
