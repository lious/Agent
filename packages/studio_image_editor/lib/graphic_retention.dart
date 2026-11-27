import 'package:studio_contracts/studio_contracts.dart';

import 'graphic_repository.dart';
import 'image_codes.dart';

final class ReferenceImpact {
  ReferenceImpact({
    required this.id,
    required this.version,
    required List<String> projectIds,
  }) : projectIds = List.unmodifiable(projectIds);

  final String id, version;
  final List<String> projectIds;
  bool get blocked => projectIds.isNotEmpty;
}

/// Retention planning. Deleting a head never deletes a referenced version.
/// Ordinary agents have no raw SQL entry.
final class GraphicRetention {
  GraphicRetention(this.repository);
  final GraphicRepository repository;

  ReferenceImpact planDelete({
    required String id,
    required String version,
    String kind = 'graphic',
    String scope = 'version',
  }) {
    final projects = repository.store.projectsPinning(kind, id, version);
    if (projects.isNotEmpty) {
      throw StudioException(graphicInUse, projects.join(','));
    }
    return ReferenceImpact(id: id, version: version, projectIds: const []);
  }

  /// Drop the library head only. Referenced versions remain loadable.
  void deleteHead(String kind, String id) {
    final head = repository.store.headVersion(kind, id);
    if (head == null) return;
    final pinned = repository.store.pinsFor(kind, id);
    if (pinned.any((p) => p['version'] == head)) {
      throw StudioException(
        graphicInUse,
        (pinned.map((p) => p['projectId']).toList()..sort()).join(','),
      );
    }
    repository.store.trash(kind: kind, id: id, version: head);
  }
}
