import 'dart:io';

import 'package:studio_sdk/studio_sdk.dart';
import 'package:test/test.dart';

/// Increment 1.95 official I-021 remainingAcceptance wording
/// 「取消epoch前帧不回流预览」 at the already-admitted StudioWorkspace
/// source-preview bound. cancelSourcePreview increments the preview epoch
/// and an in-flight previewAssetSource is refused as PREVIEW_SUPERSEDED
/// without inserting that frame into the source-preview cache. A later
/// legal preview still succeeds. This file does not rewrite
/// source_preview_test.dart, frame_proxy_test.dart, or officialize
/// 20-point seek, VFR/nonzero PTS mapping, or cache-budget wording.
Matcher code(String c) =>
    throwsA(isA<StudioException>().having((e) => e.code, 'code', c));

void main() {
  final library = Platform.environment['STUDIO_MEDIA_LIBRARY'],
      fixture = Platform.environment['STUDIO_TEST_VIDEO'];

  late Directory root;
  late StudioWorkspace workspace;
  late String assetId;

  setUp(() async {
    root = Directory.systemTemp.createTempSync('i021-cancel-preview-');
    workspace = StudioWorkspace.open(
      profile: AppProfile(
        appId: 'studio',
        region: 'local',
        features: {'project.metadata', 'media.local'},
      ),
      databasePath: '${root.path}/db',
      tenantId: 'local',
      workspaceId: 'i021-cancel-preview',
      mediaLibraryPath: library,
      mediaRootPath: '${root.path}/media',
    );
    workspace.openDemo();
    await workspace.importVideo(
      LocalFileGrant.fromUserSelection(File(fixture!)),
      expectedRevision: BigInt.zero,
    );
    assetId = workspace.current.toJson()['assets'][0]['id'] as String;
  });
  tearDown(() {
    workspace.close();
    root.deleteSync(recursive: true);
  });

  test('cancelSourcePreview refuses an in-flight preview and does not cache that frame', () async {
    final retained = await workspace.previewAssetSource(assetId, Q.of(0));
    final bytes = workspace.sourcePreviewCache.bytes;
    final entries = workspace.sourcePreviewCache.entries;
    expect(entries, 1);
    expect(identical(await workspace.previewAssetSource(assetId, Q.of(0)), retained), isTrue);

    final pending = workspace.previewAssetSource(assetId, Q.of(1));
    workspace.cancelSourcePreview();
    await expectLater(pending, code('PREVIEW_SUPERSEDED'));
    expect(workspace.sourcePreviewCache.bytes, bytes);
    expect(workspace.sourcePreviewCache.entries, entries);
    expect(identical(await workspace.previewAssetSource(assetId, Q.of(0)), retained), isTrue);
  });

  test('a later preview after cancel succeeds and does not return a canceled-epoch frame', () async {
    final retained = await workspace.previewAssetSource(assetId, Q.of(0));
    final pending = workspace.previewAssetSource(assetId, Q.of(3, 2));
    workspace.cancelSourcePreview();
    await expectLater(pending, code('PREVIEW_SUPERSEDED'));

    final later = await workspace.previewAssetSource(assetId, Q.of(3, 2));
    expect(later.pts, greaterThan(retained.pts));
    expect(identical(await workspace.previewAssetSource(assetId, Q.of(0)), retained), isTrue);
    expect(identical(await workspace.previewAssetSource(assetId, Q.of(3, 2)), later), isTrue);
    expect(workspace.sourcePreviewCache.entries, 2);
    expect(
      workspace.sourcePreviewCache.bytes,
      lessThanOrEqualTo(workspace.sourcePreviewCache.budgetBytes),
    );
  });
}
