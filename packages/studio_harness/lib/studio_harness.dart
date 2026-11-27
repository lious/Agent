import 'package:studio_contracts/studio_contracts.dart';

export 'approval.dart';
export 'budget.dart';
export 'device_scheduler.dart';
export 'mailbox.dart';
export 'roles.dart';
export 'reconcile.dart';
export 'session_store.dart';

/// A scoped reference is a value, not permission to execute a tool or edit a project.
final class SessionRef {
  SessionRef({required this.namespace, required this.id}) {
    requireId(id);
  }
  final Namespace namespace;
  final String id;
  void requireScope(Namespace authenticated) {
    if (namespace != authenticated) {
      throw const StudioException('NAMESPACE_MISMATCH');
    }
  }
}

/// No model/paid provider implementation is installed by this foundation release.
abstract interface class ProposalPort {
  Future<SessionRef> openSession(Namespace authenticated, String id);
}
