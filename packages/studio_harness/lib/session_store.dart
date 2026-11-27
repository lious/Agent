import 'package:studio_contracts/studio_contracts.dart';

import 'studio_harness.dart';

const toolCallMismatch = 'TOOL_CALL_MISMATCH';
const messageScopeMismatch = 'MESSAGE_SCOPE_MISMATCH';
const untrustedSystem = 'UNTRUSTED_SYSTEM';
const stalePrivacyEpoch = 'STALE_PRIVACY_EPOCH';
const branchHeadConflict = 'BRANCH_HEAD_CONFLICT';

enum SessionStatus { active, archived, trashed }

enum BranchStatus { active, forked }

enum MessageRole { system, user, assistant, tool }

enum MessageStatus { draft, streaming, complete, failed, redacted }

enum ToolCallState { waiting, executed, reconciled }

/// Counted HTTP/tool port used to prove fork/resume never resend a side effect.
final class FakeHttpToolPort {
  int requestCount = 0;
  final executed = <String>{};

  void post(String toolCallId, String payload) {
    requestCount++;
    executed.add(toolCallId);
  }
}

final class SessionRecord {
  SessionRecord({
    required this.id,
    required this.namespace,
    required this.projectId,
    required this.title,
    required this.activeBranchId,
  });

  final String id, projectId, title, activeBranchId;
  final Namespace namespace;
  final status = SessionStatus.active;
}

final class BranchRecord {
  BranchRecord({
    required this.id,
    required this.sessionId,
    required this.name,
    this.parentBranchId,
    this.forkEventSeq,
    this.headEventSeq = 0,
    this.status = BranchStatus.active,
  });

  final String id, sessionId, name;
  final String? parentBranchId;
  final int? forkEventSeq;
  int headEventSeq;
  BranchStatus status;
}

final class WaitingToolCall {
  WaitingToolCall({
    required this.toolCallId,
    required this.runId,
    required this.agentId,
    required this.sessionId,
    required this.branchId,
  });

  final String toolCallId, runId, agentId, sessionId, branchId;
  var state = ToolCallState.waiting;
}

final class HarnessMessage {
  HarnessMessage({
    required this.id,
    required this.sessionId,
    required this.branchId,
    required this.turnId,
    required this.role,
    required this.seq,
    this.runId,
    this.agentId,
    this.toolCallId,
    this.body,
    this.status = MessageStatus.complete,
    this.trusted = true,
    this.privacyEpoch = 1,
  });

  final String id, sessionId, branchId, turnId;
  final MessageRole role;
  final int seq, privacyEpoch;
  final String? runId, agentId, toolCallId;
  String? body;
  MessageStatus status;
  final bool trusted;

  bool get searchable =>
      status != MessageStatus.redacted && body != null && body!.isNotEmpty;
}

final class ResumeReport {
  ResumeReport({
    required this.branchId,
    required this.headEventSeq,
    required this.reconciledToolCallIds,
    required this.httpRequestsOnResume,
  });

  final String branchId;
  final int headEventSeq, httpRequestsOnResume;
  final List<String> reconciledToolCallIds;
}

/// DEV-PURE session/branch/message ledger. This is not workspace schema w5,
/// not Project user_version 9, and not production FTS/RAG.
final class SessionStore {
  SessionStore({required this.namespace, FakeHttpToolPort? http})
    : http = http ?? FakeHttpToolPort();

  final Namespace namespace;
  final FakeHttpToolPort http;
  var privacyEpoch = 1;
  final _sessions = <String, SessionRecord>{};
  final _branches = <String, BranchRecord>{};
  final _messages = <String, HarnessMessage>{};
  final _calls = <String, WaitingToolCall>{};

  SessionRef createSession({
    required String id,
    required String projectId,
    required String title,
    String branchId = 'branch-main',
  }) {
    requireId(id);
    requireId(projectId);
    requireId(branchId);
    if (title.isEmpty) throw const StudioException('INVALID_SESSION_TITLE');
    if (_sessions.containsKey(id)) throw StudioException('DUPLICATE_ID', id);
    _sessions[id] = SessionRecord(
      id: id,
      namespace: namespace,
      projectId: projectId,
      title: title,
      activeBranchId: branchId,
    );
    _branches[branchId] = BranchRecord(
      id: branchId,
      sessionId: id,
      name: 'main',
    );
    return SessionRef(namespace: namespace, id: id);
  }

  SessionRecord session(String id) {
    final s = _sessions[id];
    if (s == null) throw StudioException('SESSION_NOT_FOUND', id);
    if (s.namespace != namespace) {
      throw const StudioException('NAMESPACE_MISMATCH');
    }
    return s;
  }

  BranchRecord branch(String id) {
    final b = _branches[id];
    if (b == null) throw StudioException('BRANCH_NOT_FOUND', id);
    return b;
  }

  /// Open a session only in this store's namespace. A foreign app id is
  /// not readable here and is not imported from a shared cross-app pool.
  SessionRef openSession(Namespace authenticated, String id) {
    if (authenticated != namespace) {
      throw const StudioException('NAMESPACE_MISMATCH');
    }
    return SessionRef(namespace: namespace, id: session(id).id);
  }

  void registerWaitingCall(WaitingToolCall call) {
    requireId(call.toolCallId);
    requireId(call.runId);
    requireId(call.agentId);
    session(call.sessionId);
    branch(call.branchId);
    if (call.sessionId != branch(call.branchId).sessionId) {
      throw StudioException(messageScopeMismatch, call.branchId);
    }
    _calls[call.toolCallId] = call;
  }

  HarnessMessage append({
    required String id,
    required String sessionId,
    required String branchId,
    required String turnId,
    required MessageRole role,
    required int expectedBranchHead,
    required int expectedPrivacyEpoch,
    String? runId,
    String? agentId,
    String? toolCallId,
    String? body,
    bool trusted = true,
  }) {
    requireId(id);
    requireId(sessionId);
    requireId(branchId);
    requireId(turnId);
    final sess = session(sessionId);
    final br = branch(branchId);
    if (br.sessionId != sess.id) {
      throw StudioException(messageScopeMismatch, branchId);
    }
    if (expectedPrivacyEpoch != privacyEpoch) {
      throw StudioException(stalePrivacyEpoch, '$expectedPrivacyEpoch');
    }
    if (expectedBranchHead != br.headEventSeq) {
      throw StudioException(branchHeadConflict, '$expectedBranchHead');
    }
    if (role == MessageRole.system && !trusted) {
      throw const StudioException(untrustedSystem);
    }
    if (role == MessageRole.user && toolCallId != null) {
      throw StudioException(toolCallMismatch, 'user');
    }
    if (role == MessageRole.tool) {
      if (runId == null || toolCallId == null || agentId == null) {
        throw const StudioException(toolCallMismatch, 'missing-ids');
      }
      final waiting = _calls[toolCallId];
      if (waiting == null ||
          waiting.runId != runId ||
          waiting.agentId != agentId ||
          waiting.sessionId != sessionId ||
          waiting.branchId != branchId ||
          waiting.state != ToolCallState.waiting) {
        throw StudioException(toolCallMismatch, toolCallId);
      }
      waiting.state = ToolCallState.executed;
    }
    br.headEventSeq += 1;
    final message = HarnessMessage(
      id: id,
      sessionId: sessionId,
      branchId: branchId,
      turnId: turnId,
      role: role,
      seq: br.headEventSeq,
      runId: runId,
      agentId: agentId,
      toolCallId: toolCallId,
      body: body,
      trusted: trusted,
      privacyEpoch: privacyEpoch,
    );
    _messages[id] = message;
    return message;
  }

  /// Execute a waiting tool over HTTP exactly once.
  void executeHttpTool({required String toolCallId, required String payload}) {
    final call = _calls[toolCallId];
    if (call == null || call.state != ToolCallState.waiting) {
      throw StudioException(toolCallMismatch, toolCallId);
    }
    if (http.executed.contains(toolCallId)) {
      // Already sent; never resend.
      return;
    }
    http.post(toolCallId, payload);
  }

  /// Fork inherits the parent prefix up to [atEventSeq]. The parent is
  /// unchanged. HTTP receipts, approvals, and tool sends are not copied
  /// and not replayed.
  BranchRecord forkBranch({
    required String sessionId,
    required String parentBranchId,
    required String newBranchId,
    required String name,
    required int atEventSeq,
  }) {
    requireId(newBranchId);
    final sess = session(sessionId);
    final parent = branch(parentBranchId);
    if (parent.sessionId != sess.id) {
      throw StudioException(messageScopeMismatch, parentBranchId);
    }
    if (atEventSeq < 0 || atEventSeq > parent.headEventSeq) {
      throw const StudioException('INVALID_RANGE', 'forkEventSeq');
    }
    if (_branches.containsKey(newBranchId)) {
      throw StudioException('DUPLICATE_ID', newBranchId);
    }
    final child = BranchRecord(
      id: newBranchId,
      sessionId: sessionId,
      name: name,
      parentBranchId: parent.id,
      forkEventSeq: atEventSeq,
      headEventSeq: atEventSeq,
      status: BranchStatus.forked,
    );
    _branches[newBranchId] = child;
    return child;
  }

  /// Resume restores the branch projection and reconciles unfinished
  /// calls without resending HTTP tools.
  ResumeReport resumeBranch(String branchId) {
    final br = branch(branchId);
    session(br.sessionId);
    final before = http.requestCount;
    final reconciled = <String>[];
    for (final call in _calls.values) {
      if (call.branchId != branchId &&
          !_visibleOn(branchId, call.branchId, at: br.headEventSeq)) {
        continue;
      }
      if (call.state == ToolCallState.executed ||
          http.executed.contains(call.toolCallId)) {
        if (call.state == ToolCallState.waiting) {
          call.state = ToolCallState.reconciled;
        }
        reconciled.add(call.toolCallId);
      } else if (call.state == ToolCallState.waiting &&
          call.branchId == branchId) {
        // Unfinished: mark reconciled, do not post.
        call.state = ToolCallState.reconciled;
        reconciled.add(call.toolCallId);
      }
    }
    if (http.requestCount != before) {
      throw const StudioException('HTTP_SIDE_EFFECT_REPLAY');
    }
    return ResumeReport(
      branchId: branchId,
      headEventSeq: br.headEventSeq,
      reconciledToolCallIds: reconciled,
      httpRequestsOnResume: http.requestCount - before,
    );
  }

  /// Purge a message body. The event header remains; the text is removed
  /// from the searchable index and cannot be restored by a late append.
  void purgeBody(String messageId) {
    final message = _messages[messageId];
    if (message == null) throw StudioException('MESSAGE_NOT_FOUND', messageId);
    message.body = null;
    message.status = MessageStatus.redacted;
    privacyEpoch += 1;
  }

  List<HarnessMessage> messagesOn(String branchId) {
    final br = branch(branchId);
    final inherited = <HarnessMessage>[];
    if (br.parentBranchId != null && br.forkEventSeq != null) {
      for (final m in _messages.values) {
        if (m.branchId == br.parentBranchId && m.seq <= br.forkEventSeq!) {
          inherited.add(m);
        }
      }
    }
    final own = [
      for (final m in _messages.values)
        if (m.branchId == branchId) m,
    ];
    return [...inherited, ...own]..sort((a, b) => a.seq.compareTo(b.seq));
  }

  /// Search live bodies only. A purged/redacted body is not a hit.
  List<HarnessMessage> search(String query) {
    if (query.isEmpty) return const [];
    final needle = query.toLowerCase();
    return [
      for (final m in _messages.values)
        if (m.searchable && m.body!.toLowerCase().contains(needle)) m,
    ];
  }

  bool _visibleOn(String branchId, String callBranchId, {required int at}) {
    if (callBranchId == branchId) return true;
    final br = _branches[branchId];
    return br?.parentBranchId == callBranchId &&
        br?.forkEventSeq != null &&
        true;
  }
}
