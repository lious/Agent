import 'dart:convert';

import 'package:studio_contracts/studio_contracts.dart';
import 'package:studio_document/studio_document.dart';
import 'package:test/test.dart';

import '../s3_opened_matrix_test.dart'
    show s3Abc, f, content, startOf, videoA, media;

Matcher throwsCode(String code) =>
    throwsA(isA<StudioException>().having((e) => e.code, 'code', code));

Map trackOf(ProjectDocument p, String id) =>
    (p.toJson()['sequences'][0]['tracks'] as List).cast<Map>().singleWhere(
      (t) => t['id'] == id,
    );

Map<String, dynamic> videoTemplate(ProjectDocument p, {required String id, required int order}) {
  final root = p.toJson()['sequences'][0] as Map;
  return {
    'id': id,
    'sequenceId': root['id'],
    'name': 'Video 2',
    'kind': 'video',
    'order': order,
    'locked': false,
    'muted': false,
    'solo': false,
    'syncLock': true,
    'targeted': false,
    'busId': null,
    'items': [],
  };
}

int nextOrder(ProjectDocument p) {
  final orders = [
    for (final t in p.toJson()['sequences'][0]['tracks'] as List)
      t['order'] as int,
  ];
  return orders.reduce((a, b) => a > b ? a : b) + 1;
}

void main() {
  var serial = 0;
  ProjectDocument edit(ProjectDocument p, EditOperation op) => applyEdit(
    p,
    op,
    newId: () => 'addtrk-${serial++}',
    nextVersion: (_) => '${serial++}',
  );

  setUp(() => serial = 0);

  test('AddTrack opens an empty video lane; Paste A+C at 0 keeps the 150-frame gap and does not copy blobs', () {
    var p = s3Abc();
    final a = videoA(p);
    final origin = p.toJson()['sequences'][0]['tracks'][0]['id'] as String;
    final added = videoTemplate(p, id: 'track-video-2', order: nextOrder(p));
    final beforeHash = content(p);
    p = edit(p, AddTrack(added));
    expect(content(p), isNot(beforeHash));
    expect(trackOf(p, 'track-video-2')['items'], isEmpty);
    expect(startOf(p, a), Q.of(0));
    expect(startOf(p, 's3-c'), f(300));

    final pasted = edit(
      p,
      PasteClips(
        buildClipboard(p, [a, 's3-c']),
        at: Q.of(0),
        targetTrackMap: {origin: 'track-video-2'},
      ),
    );
    final copies =
        media(pasted).where((c) => c['trackId'] == 'track-video-2').toList()
          ..sort(
            (x, y) => Q
                .fromJson(x['timelineRange']['start'])
                .compareTo(Q.fromJson(y['timelineRange']['start'])),
          );
    expect(copies, hasLength(2));
    expect(Q.fromJson(copies[0]['timelineRange']['start']), Q.of(0));
    expect(Q.fromJson(copies[1]['timelineRange']['start']), f(300));
    expect(
      Q.fromJson(copies[1]['timelineRange']['start']) -
          Q.fromJson(copies[0]['timelineRange']['start']),
      f(300),
    );
    expect(startOf(pasted, a), Q.of(0));
    expect(startOf(pasted, 's3-b'), f(150));
    expect(startOf(pasted, 's3-c'), f(300));
    expect(
      jsonEncode(pasted.toJson()['assets']),
      jsonEncode(p.toJson()['assets']),
    );
    expect(
      jsonEncode(pasted.toJson()['blobs']),
      jsonEncode(p.toJson()['blobs']),
    );
  });

  test('AddTrack refusals leave the document unchanged', () {
    final p = s3Abc();
    final startHash = content(p);
    final raw = jsonEncode(p.toJson());
    final order = nextOrder(p);
    final good = videoTemplate(p, id: 'track-video-2', order: order);

    expect(
      () =>
          edit(p, AddTrack({...good, 'kind': 'audio', 'busId': 'bus-master'})),
      throwsCode('FEATURE_NOT_IMPLEMENTED'),
    );
    expect(
      () => edit(p, AddTrack({...good, 'kind': 'caption'})),
      throwsCode('FEATURE_NOT_IMPLEMENTED'),
    );
    expect(
      () => edit(p, AddTrack({...good, 'muted': true})),
      throwsCode('FEATURE_NOT_IMPLEMENTED'),
    );
    expect(
      () => edit(p, AddTrack({...good, 'solo': true})),
      throwsCode('FEATURE_NOT_IMPLEMENTED'),
    );
    expect(
      () => edit(
        p,
        AddTrack({
          ...good,
          'id': p.toJson()['sequences'][0]['tracks'][0]['id'],
        }),
      ),
      throwsCode('DUPLICATE_ID'),
    );
    expect(
      () => edit(
        p,
        AddTrack({
          ...good,
          'order': trackOf(
            p,
            p.toJson()['sequences'][0]['tracks'][0]['id'] as String,
          )['order'],
        }),
      ),
      throwsCode('DUPLICATE_ORDER'),
    );
    expect(
      () => edit(p, AddTrack({...good, 'sequenceId': 'other-sequence'})),
      throwsCode('PARENT_MISMATCH'),
    );
    expect(
      () => edit(
        p,
        AddTrack({
          ...good,
          'items': [
            {
              'id': 'smuggled-clip',
              'trackId': 'track-video-2',
              'timelineRange': {
                'start': Q.of(0).toJson(),
                'duration': Q.of(1).toJson(),
              },
            },
          ],
        }),
      ),
      throwsCode('INVALID_TRACK_STATE'),
    );
    expect(content(p), startHash);
    expect(jsonEncode(p.toJson()), raw);
  });

  test('RemoveTrack rejectIfNotEmpty keeps a populated lane; removeContents drops only that lane and not source media', () {
    var p = s3Abc();
    final a = videoA(p);
    final origin = p.toJson()['sequences'][0]['tracks'][0]['id'] as String;
    p = edit(
      p,
      AddTrack(videoTemplate(p, id: 'track-video-2', order: nextOrder(p))),
    );
    expect(
      () => edit(p, RemoveTrack(origin)),
      throwsCode('FEATURE_NOT_IMPLEMENTED'),
    );
    expect(
      () => edit(p, RemoveTrack(origin, contentPolicy: 'removeContents')),
      throwsCode('FEATURE_NOT_IMPLEMENTED'),
    );

    final startHash = content(p);
    final emptied = edit(p, RemoveTrack('track-video-2'));
    expect(
      (emptied.toJson()['sequences'][0]['tracks'] as List).where(
        (t) => t['id'] == 'track-video-2',
      ),
      isEmpty,
    );
    expect(startOf(emptied, a), Q.of(0));

    p = edit(
      p,
      PasteClips(
        buildClipboard(p, [a, 's3-c']),
        at: Q.of(0),
        targetTrackMap: {origin: 'track-video-2'},
      ),
    );
    expect(
      () => edit(p, RemoveTrack('track-video-2')),
      throwsCode('INVALID_TRACK_STATE'),
    );
    expect(trackOf(p, 'track-video-2')['items'], isNotEmpty);

    final locked = edit(p, SetTrackState('track-video-2', locked: true));
    expect(
      () => edit(
        locked,
        RemoveTrack('track-video-2', contentPolicy: 'removeContents'),
      ),
      throwsCode('FIELD_LOCKED'),
    );
    expect(trackOf(locked, 'track-video-2')['items'], isNotEmpty);

    final cleared = edit(
      p,
      RemoveTrack('track-video-2', contentPolicy: 'removeContents'),
    );
    expect(
      (cleared.toJson()['sequences'][0]['tracks'] as List).where(
        (t) => t['id'] == 'track-video-2',
      ),
      isEmpty,
    );
    expect(startOf(cleared, a), Q.of(0));
    expect(startOf(cleared, 's3-c'), f(300));
    expect(
      jsonEncode(cleared.toJson()['assets']),
      jsonEncode(p.toJson()['assets']),
    );
    expect(content(p), isNot(startHash));
  });
}
