import 'package:studio_contracts/studio_contracts.dart';
import 'package:studio_harness/studio_harness.dart';
import 'package:test/test.dart';

Matcher throwsCode(String code) =>
    throwsA(isA<StudioException>().having((e) => e.code, 'code', code));

void main() {
  final nsA = Namespace('studio', 'local', 'app-a');
  final nsB = Namespace('studio', 'local', 'app-b');

  SessionStore store() {
    final s = SessionStore(namespace: nsA);
    s.createSession(
      id: 'session-1',
      projectId: 'project-1',
      title: 'edit A',
      branchId: 'branch-main',
    );
    return s;
  }

  test('rename updates the title; an empty title is refused and leaves the record unchanged', () {
    final s = store();
    expect(s.session('session-1').title, 'edit A');
    s.renameSession('session-1', 'cut B');
    expect(s.session('session-1').title, 'cut B');
    expect(s.searchSessions('cut'), hasLength(1));
    expect(s.searchSessions('edit'), isEmpty);
    expect(
      () => s.renameSession('session-1', ''),
      throwsCode('INVALID_SESSION_TITLE'),
    );
    expect(s.session('session-1').title, 'cut B');
    expect(s.session('session-1').status, SessionStatus.active);
  });

  test('archive hides the session from the default list and title search, and refuses later writes', () {
    final s = store();
    s.createSession(
      id: 'session-2',
      projectId: 'project-1',
      title: 'edit B',
      branchId: 'branch-two',
    );
    s.append(
      id: 'msg-1',
      sessionId: 'session-1',
      branchId: 'branch-main',
      turnId: 'turn-1',
      role: MessageRole.user,
      expectedBranchHead: 0,
      expectedPrivacyEpoch: 1,
      body: 'hello',
    );
    expect(s.listSessions(), hasLength(2));
    s.archiveSession('session-1');
    expect(s.session('session-1').status, SessionStatus.archived);
    expect(s.listSessions().map((e) => e.id), ['session-2']);
    expect(s.searchSessions('edit').map((e) => e.id), ['session-2']);
    expect(s.searchSessions('edit', includeArchived: true).map((e) => e.id), [
      'session-1',
      'session-2',
    ]);
    expect(s.listSessions(includeArchived: true).map((e) => e.id), [
      'session-1',
      'session-2',
    ]);
    // The same namespace can still open the archived record.
    expect(s.openSession(nsA, 'session-1').id, 'session-1');
    expect(
      () => s.append(
        id: 'msg-2',
        sessionId: 'session-1',
        branchId: 'branch-main',
        turnId: 'turn-2',
        role: MessageRole.user,
        expectedBranchHead: 1,
        expectedPrivacyEpoch: 1,
        body: 'later',
      ),
      throwsCode('SESSION_ARCHIVED'),
    );
    expect(s.branch('branch-main').headEventSeq, 1);
    expect(
      () => s.forkBranch(
        sessionId: 'session-1',
        parentBranchId: 'branch-main',
        newBranchId: 'branch-fork',
        name: 'fork',
        atEventSeq: 1,
      ),
      throwsCode('SESSION_ARCHIVED'),
    );
    expect(s.listSessions().map((e) => e.id), ['session-2']);
    // Archive is idempotent and does not invent a second record.
    s.archiveSession('session-1');
    expect(
      s.listSessions(includeArchived: true).where((e) => e.id == 'session-1'),
      hasLength(1),
    );
  });

  test('a session cannot be listed, renamed, or archived from another app namespace', () {
    final s = store();
    final other = SessionStore(namespace: nsB);
    expect(() => other.session('session-1'), throwsCode('SESSION_NOT_FOUND'));
    expect(
      () => other.openSession(nsB, 'session-1'),
      throwsCode('SESSION_NOT_FOUND'),
    );
    expect(
      () => other.openSession(nsA, 'session-1'),
      throwsCode('NAMESPACE_MISMATCH'),
    );
    expect(
      () => other.renameSession('session-1', 'stolen'),
      throwsCode('SESSION_NOT_FOUND'),
    );
    expect(
      () => other.archiveSession('session-1'),
      throwsCode('SESSION_NOT_FOUND'),
    );
    expect(other.listSessions(), isEmpty);
    expect(other.searchSessions('edit'), isEmpty);
    expect(s.session('session-1').title, 'edit A');
    expect(s.session('session-1').status, SessionStatus.active);
  });
}
