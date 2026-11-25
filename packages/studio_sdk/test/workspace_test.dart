import 'dart:io';

import 'package:studio_sdk/studio_sdk.dart';
import 'package:test/test.dart';

void main() {
  test(
    'two host profiles share implementation, never session/project scope',
    () {
      final dir = Directory.systemTemp.createTempSync('studio-sdk-');
      final a = StudioWorkspace.open(
        profile: AppProfile(
          appId: 'image',
          region: 'local',
          features: {'project.metadata'},
        ),
        databasePath: '${dir.path}/both.sqlite',
        tenantId: 't',
        workspaceId: 'w',
      );
      final b = StudioWorkspace.open(
        profile: AppProfile(
          appId: 'studio',
          region: 'local',
          features: {'project.metadata'},
        ),
        databasePath: '${dir.path}/both.sqlite',
        tenantId: 't',
        workspaceId: 'w',
      );
      try {
        a.openDemo();
        b.openDemo();
        expect(a.peerStorageScope, isNot(b.peerStorageScope));
        expect(a.peerIdentityLockPath, b.peerIdentityLockPath);
        a.rename('Image title', expectedRevision: BigInt.zero);
        expect(a.current.title, 'Image title');
        expect(b.current.title, 'Untitled');
        final session = SessionRef(
          namespace: Namespace('image', 't', 'w'),
          id: 's1',
        );
        expect(
          () => session.requireScope(Namespace('studio', 't', 'w')),
          throwsA(isA<StudioException>()),
        );
      } finally {
        a.close();
        b.close();
        dir.deleteSync(recursive: true);
      }
    },
  );
  test(
    'local metadata sessions share one real namespace executor slot',
    () async {
      final directory = Directory.systemTemp.createTempSync('session-slot-');
      final workspace = StudioWorkspace.open(
        profile: AppProfile(
          appId: 'studio',
          region: 'local',
          features: {'project.metadata'},
        ),
        databasePath: '${directory.path}/db',
        tenantId: 't',
        workspaceId: 'w',
      );
      workspace.openDemo();
      final first = workspace.createMetadataComputeSession('first'),
          second = workspace.createMetadataComputeSession('second');
      try {
        final running = first.runLocalNode('digest-0');
        await expectLater(
          second.runLocalNode('digest-0'),
          throwsA(
            isA<StudioException>().having(
              (e) => e.code,
              'code',
              'DEVICE_RESOURCE_BUSY',
            ),
          ),
        );
        await running;
        await second.runLocalNode('digest-0');
        expect(first.statuses['digest-0'], 'committed');
        expect(second.statuses['digest-0'], 'committed');
        expect(workspace.current.revision, BigInt.zero);
      } finally {
        await first.close();
        await second.close();
        workspace.close();
        directory.deleteSync(recursive: true);
      }
    },
  );
  test('disabled profile cannot open writable project metadata', () {
    final workspace = StudioWorkspace.open(
      profile: AppProfile(appId: 'disabled', region: 'local', features: {}),
      databasePath: ':memory:',
      tenantId: 't',
      workspaceId: 'w',
    );
    try {
      for (final action in <void Function()>[
        () => workspace.createMetadataComputeSession('denied-session'),
        () => workspace.receivedPeerBlob('0' * 64),
      ]) {
        expect(
          action,
          throwsA(
            isA<StudioException>().having(
              (e) => e.code,
              'code',
              'CAPABILITY_UNAVAILABLE',
            ),
          ),
        );
      }
      expect(
        () => workspace.openDemo(),
        throwsA(
          isA<StudioException>().having(
            (e) => e.code,
            'code',
            'CAPABILITY_UNAVAILABLE',
          ),
        ),
      );
    } finally {
      workspace.close();
    }
  });
  test(
    'facade requires revision the user actually saw, not latest DB revision',
    () {
      final workspace = StudioWorkspace.open(
        profile: AppProfile(
          appId: 'studio',
          region: 'local',
          features: {'project.metadata'},
        ),
        databasePath: ':memory:',
        tenantId: 't',
        workspaceId: 'w',
      );
      try {
        workspace.openDemo();
        workspace.rename('User edit', expectedRevision: BigInt.zero);
        expect(
          () => workspace.rename(
            'Stale overwrite',
            expectedRevision: BigInt.zero,
          ),
          throwsA(
            isA<StudioException>().having(
              (e) => e.code,
              'code',
              'REVISION_CONFLICT',
            ),
          ),
        );
        expect(workspace.current.title, 'User edit');
      } finally {
        workspace.close();
      }
    },
  );
}
