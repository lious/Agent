import 'dart:convert';
import 'dart:io';

import 'package:studio_contracts/studio_contracts.dart';
import 'package:studio_document/studio_document.dart';
import 'package:test/test.dart';

/// Increment 2.99 official I-008 / s4 leftover: the local write path
/// does not refuse an `Asset.kind=image` clip by stream lookup or
/// `VIDEO_STREAM_REQUIRED`.
///
/// This file does not rewrite frozen I-008 suites, Increment 2.96
/// StillImageClipAdmission, or Increment 2.98 document-semantics tests.
/// It does not invent an unregistered plugin or claim a V-003
/// measurement. InversePatch kind stays restoreSnapshot. Project
/// user_version stays 9. I-008 stays partial.
Matcher code(String c) =>
    throwsA(isA<StudioException>().having((e) => e.code, 'code', c));

Map<String, dynamic> localVideo() =>
    jsonDecode(File('fixtures/project/local-video.json').readAsStringSync())
        as Map<String, dynamic>;

ProjectDocument imageAssetClip({String? streamId}) {
  final document = localVideo();
  document['assets'][0]['kind'] = 'image';
  document['assets'][0]['streams'] = [];
  document['sequences'][0]['tracks'][0]['items'][0]['source']['streamId'] =
      streamId;
  return ProjectDocument.fromJson(document);
}

void main() {
  test('an image asset clip with a null streamId is locally writable', () {
    requireLocalEditingWritable(imageAssetClip());
  });

  test('an image asset clip with a streamId is SOURCE_STREAM_MISMATCH, not VIDEO_STREAM_REQUIRED', () {
    expect(
      () =>
          requireLocalEditingWritable(imageAssetClip(streamId: 'video-stream')),
      code('SOURCE_STREAM_MISMATCH'),
    );
  });
}
