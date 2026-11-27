import 'dart:convert';
import 'dart:io';

import 'package:studio_document/studio_document.dart';
import 'package:test/test.dart';

/// Increment 2.98 official I-008 / s4 leftover: an `Asset.kind=image`
/// clip with `streamId=null` and a static 1x `[0, Clip.duration)`
/// domain is not refused by video stream `availableRange` lookup.
///
/// This file does not rewrite frozen I-008 suites, does not re-qualify
/// Increment 2.96 StillImageClipAdmission or ADR 0108 Ken Burns, and
/// does not invent an unregistered plugin or claim a V-003 measurement.
/// InversePatch kind stays restoreSnapshot. Project user_version stays
/// 9. I-008 stays partial.
Map<String, dynamic> rich() =>
    jsonDecode(File('fixtures/project/semantic-rich.json').readAsStringSync())
        as Map<String, dynamic>;

Map<String, dynamic> imageAssetClip({String? streamId}) {
  final document = rich();
  document['assets'][0]['kind'] = 'image';
  document['assets'][0]['streams'] = [];
  document['sequences'][0]['tracks'][0]['items'][0]['source']['streamId'] =
      streamId;
  return document;
}

void main() {
  test('an image asset clip with a null streamId and a static 1x domain is not refused by video availableRange', () {
    final issues = DocumentValidator().validate(imageAssetClip());
    expect(
      issues.where((issue) => issue.code == 'SOURCE_STREAM_MISMATCH'),
      isEmpty,
    );
    expect(
      issues.where((issue) => issue.code == 'SOURCE_OUT_OF_RANGE'),
      isEmpty,
    );
    expect(issues, isEmpty);
  });

  test('an image asset clip with a streamId is SOURCE_STREAM_MISMATCH', () {
    final issues = DocumentValidator().validate(
      imageAssetClip(streamId: 'video-stream'),
    );
    expect(
      issues.any((issue) => issue.code == 'SOURCE_STREAM_MISMATCH'),
      isTrue,
    );
  });
}
