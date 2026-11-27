import 'dart:convert';

import 'package:studio_contracts/studio_contracts.dart';
import 'package:studio_document/studio_document.dart';
import 'package:test/test.dart';

import '../../persistent_audio_test.dart' show avFixture;

Matcher throwsCode(String code) =>
    throwsA(isA<StudioException>().having((e) => e.code, 'code', code));

String content(ProjectDocument p) =>
    contentHash(p.toJson()..remove('revision'));

List<Map> tracks(ProjectDocument p) =>
    (p.toJson()['sequences'][0]['tracks'] as List).cast<Map>();

Map trackOf(ProjectDocument p, String id) =>
    tracks(p).singleWhere((t) => t['id'] == id);

String videoId(ProjectDocument p) =>
    tracks(p)
            .firstWhere((t) => t['kind'] == 'video')['items']
            .firstWhere((c) => c['source'] != null)['id']
        as String;

int nextOrder(ProjectDocument p) {
  final orders = [for (final t in tracks(p)) t['order'] as int];
  return orders.reduce((a, b) => a > b ? a : b) + 1;
}

Map<String, dynamic> audioTrack(
  ProjectDocument p, {
  required String id,
  required int order,
  String busId = 'bus-master',
}) {
  final root = p.toJson()['sequences'][0] as Map;
  return {
    'id': id,
    'sequenceId': root['id'],
    'name': 'Audio $id',
    'kind': 'audio',
    'order': order,
    'locked': false,
    'muted': false,
    'solo': false,
    'syncLock': true,
    'targeted': false,
    'busId': busId,
    'items': <Map<String, dynamic>>[],
  };
}

({
  Map<String, dynamic> asset,
  Map<String, dynamic> blob,
  Map<String, dynamic> rights,
})
independentAudio(ProjectDocument p) {
  final source = avFixture().toJson();
  final audio = (source['assets'][0]['streams'] as List)
      .cast<Map>()
      .singleWhere((s) => s['type'] == 'audio');
  final blob = Map<String, dynamic>.from(source['blobs'][0] as Map);
  final stream = Map<String, dynamic>.from(audio)
    ..['id'] = 'independent-stream';
  final asset = <String, dynamic>{
    'id': 'independent-audio',
    'version': '1',
    'name': 'Bed',
    'kind': 'audio',
    'originalBlobHash': blob['hash'],
    'externalLocator': null,
    'streams': [stream],
    'proxyRefs': <Map>[],
    'rightsId': 'independent-right',
    'contentFingerprint': blob['hash'],
    'status': 'ready',
  };
  final rights = Map<String, dynamic>.from(source['rightsRecords'][0] as Map)
    ..['id'] = 'independent-right'
    ..['assetIds'] = ['independent-audio'];
  return (asset: asset, blob: blob, rights: rights);
}

void main() {
  var serial = 0;
  ProjectDocument edit(ProjectDocument p, EditOperation op) => applyEdit(
    p,
    op,
    newId: () => 'i009-${serial++}',
    nextVersion: (_) => '${serial++}',
  );

  setUp(() => serial = 0);

  test('AddTrack opens an audio lane; extract uses that lane and does not invent another', () {
    var p = avFixture();
    p = edit(
      p,
      AddTrack(audioTrack(p, id: 'track-audio-1', order: nextOrder(p))),
    );
    expect(tracks(p).where((t) => t['kind'] == 'audio'), hasLength(1));
    expect(trackOf(p, 'track-audio-1')['items'], isEmpty);
    final extracted = edit(p, ExtractAudioClip(videoId(p), 'audio-stream'));
    expect(tracks(extracted).where((t) => t['kind'] == 'audio'), hasLength(1));
    expect(trackOf(extracted, 'track-audio-1')['items'], isNotEmpty);
    expect(extracted.toJson()['linkGroups'], isNotEmpty);
  });

  test('AppendAudioAsset imports a standalone kind=audio clip onto a new track without linking or copying the blob', () {
    var p = avFixture();
    p = edit(
      p,
      AddTrack(audioTrack(p, id: 'track-audio-1', order: nextOrder(p))),
    );
    p = edit(
      p,
      AddTrack(audioTrack(p, id: 'track-audio-2', order: nextOrder(p))),
    );
    final imported = independentAudio(p);
    final blobsBefore = (p.toJson()['blobs'] as List).length;
    final startHash = content(p);
    p = edit(
      p,
      AppendAudioAsset(
        asset: imported.asset,
        blob: imported.blob,
        rights: imported.rights,
        clipId: 'independent-clip',
        targetTrackId: 'track-audio-2',
      ),
    );
    expect(content(p), isNot(startHash));
    expect((p.toJson()['blobs'] as List).length, blobsBefore);
    expect(
      (p.toJson()['assets'] as List).where(
        (a) => a['id'] == 'independent-audio',
      ),
      hasLength(1),
    );
    expect(
      (p.toJson()['assets'] as List).singleWhere(
        (a) => a['id'] == 'independent-audio',
      )['kind'],
      'audio',
    );
    final clip = (trackOf(p, 'track-audio-2')['items'] as List)
        .cast<Map>()
        .singleWhere((c) => c['source'] != null);
    expect(clip['id'], 'independent-clip');
    expect(clip['source']['id'], 'independent-audio');
    expect(clip['source']['streamId'], 'independent-stream');
    expect(clip['linkGroupId'], isNull);
    expect(p.toJson()['linkGroups'], isEmpty);
    expect(Q.fromJson(clip['timelineRange']['start']), Q.of(0));
    expect(Q.fromJson(clip['timelineRange']['duration']), Q.of(3));
    expect(trackOf(p, 'track-audio-1')['items'], isEmpty);

    // Source media stays when the importing lane is removed.
    final cleared = edit(
      p,
      RemoveTrack('track-audio-2', contentPolicy: 'removeContents'),
    );
    expect(
      (cleared.toJson()['sequences'][0]['tracks'] as List).where(
        (t) => t['id'] == 'track-audio-2',
      ),
      isEmpty,
    );
    expect(
      (cleared.toJson()['assets'] as List).where(
        (a) => a['id'] == 'independent-audio',
      ),
      hasLength(1),
    );
    expect(
      (cleared.toJson()['blobs'] as List).length,
      (p.toJson()['blobs'] as List).length,
    );
  });

  test(
    'audio AddTrack and AppendAudioAsset refusals leave the document unchanged',
    () {
      var p = avFixture();
      p = edit(
        p,
        AddTrack(audioTrack(p, id: 'track-audio-1', order: nextOrder(p))),
      );
      final imported = independentAudio(p);
      final startHash = content(p);
      final raw = jsonEncode(p.toJson());
      expect(
        () => edit(
          p,
          AddTrack(
            audioTrack(p, id: 'track-caption', order: nextOrder(p))
              ..['kind'] = 'caption'
              ..['busId'] = null,
          ),
        ),
        throwsCode('FEATURE_NOT_IMPLEMENTED'),
      );
      expect(
        () => edit(
          p,
          AddTrack(
            audioTrack(
              p,
              id: 'track-audio-x',
              order: nextOrder(p),
              busId: 'missing-bus',
            ),
          ),
        ),
        throwsCode('AUDIO_BUS_MISSING'),
      );
      expect(
        () => edit(
          p,
          AddTrack({
            ...audioTrack(p, id: 'track-audio-y', order: nextOrder(p)),
            'busId': null,
          }),
        ),
        throwsCode('AUDIO_BUS_MISSING'),
      );
      expect(
        () => edit(
          p,
          AppendAudioAsset(
            asset: {...imported.asset, 'kind': 'video'},
            blob: imported.blob,
            rights: imported.rights,
            clipId: 'independent-clip',
            targetTrackId: 'track-audio-1',
          ),
        ),
        throwsCode('FEATURE_NOT_IMPLEMENTED'),
      );
      expect(
        () => edit(
          p,
          AppendAudioAsset(
            asset: imported.asset,
            blob: imported.blob,
            rights: imported.rights,
            clipId: 'independent-clip',
            targetTrackId: 'missing-track',
          ),
        ),
        throwsCode('TRACK_NOT_FOUND'),
      );
      final video =
          tracks(p).firstWhere((t) => t['kind'] == 'video')['id'] as String;
      expect(
        () => edit(
          p,
          AppendAudioAsset(
            asset: imported.asset,
            blob: imported.blob,
            rights: imported.rights,
            clipId: 'independent-clip',
            targetTrackId: video,
          ),
        ),
        throwsCode('TRACK_KIND_MISMATCH'),
      );
      final locked = edit(p, SetTrackState('track-audio-1', locked: true));
      expect(
        () => edit(
          locked,
          AppendAudioAsset(
            asset: imported.asset,
            blob: imported.blob,
            rights: imported.rights,
            clipId: 'independent-clip',
            targetTrackId: 'track-audio-1',
          ),
        ),
        throwsCode('FIELD_LOCKED'),
      );
      expect(content(p), startHash);
      expect(jsonEncode(p.toJson()), raw);
    },
  );
}
