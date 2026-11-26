import 'dart:convert';

import 'package:studio_contracts/studio_contracts.dart';
import 'package:studio_document/studio_document.dart';
import 'package:test/test.dart';

import 'edit_algebra_test.dart' as algebra;
import 'multi_move_test.dart' as move;
import 'persistent_audio_test.dart' show avFixture;

Matcher code(String c) =>
    throwsA(isA<StudioException>().having((e) => e.code, 'code', c));

List<Map> media(ProjectDocument p) => [
  for (final t in p.toJson()['sequences'][0]['tracks'])
    for (final c in t['items'])
      if (c['source'] != null) c as Map,
];

Q startOf(ProjectDocument p, String id) => Q.fromJson(
  media(p).singleWhere((c) => c['id'] == id)['timelineRange']['start'],
);

Map cueOf(ProjectDocument p, [String id = 'cue-1']) =>
    (p.toJson()['captions'] as List).cast<Map>().singleWhere(
      (c) => c['id'] == id,
    );

List<Map> markersOf(ProjectDocument p) =>
    (p.toJson()['markers'] as List).cast<Map>();

String content(ProjectDocument p) =>
    contentHash(p.toJson()..remove('revision'));

void assertPure(ProjectDocument before, void Function() action) {
  final start = content(before);
  final raw = jsonEncode(before.toJson());
  action();
  expect(content(before), start);
  expect(jsonEncode(before.toJson()), raw);
}

TimelineMarker absolute(
  ProjectDocument p,
  String id, {
  required Q time,
  String label = 'mark',
}) => TimelineMarker(
  id,
  sequenceId: p.toJson()['rootSequenceId'] as String,
  label: label,
  time: time,
);

ProjectDocument captions(ProjectDocument p) => move.change(
  p,
  SetCaptions(
    CaptionStore([
      CaptionCue(
        'cue-1',
        TimeRange(Q.of(0), Q.of(1, 2)),
        'hello',
        manualFields: {'text', 'timing'},
      ),
    ]),
  ),
);

void main() {
  test(
    'inverting SetMarkers after an unrelated move restores markers only',
    () {
      var p = avFixture();
      final a = algebra.firstId(p);
      p = move.change(p, SplitClip(a, Q.of(1), 'right'));
      p = captions(p);
      final beforeMarkers = p;
      p = move.change(
        p,
        SetMarkers(
          MarkerStore([absolute(p, 'mark-1', time: Q.of(2), label: 'later')]),
        ),
      );
      final afterMarkers = p;
      p = move.change(p, MoveClip('right', Q.of(1, 2)));
      expect(startOf(p, 'right'), Q.of(3, 2));
      expect(markersOf(p).single['label'], 'later');
      final changes = documentFieldChanges(
        beforeMarkers.toJson()..remove('revision'),
        afterMarkers.toJson()..remove('revision'),
      );
      expect(fieldInvertConflicts(p.toJson(), changes), isFalse);
      final restored = ProjectDocument.fromJson(
        applyFieldInvert(p.toJson(), changes)
          ..['revision'] = p.revision.toString(),
      );
      expect(markersOf(restored), isEmpty);
      expect(cueOf(restored)['text'], 'hello');
      expect(startOf(restored, 'right'), Q.of(3, 2));
    },
  );

  test('a later edit to the same markers is a whole-group conflict', () {
    var p = avFixture();
    final a = algebra.firstId(p);
    p = move.change(p, SplitClip(a, Q.of(1), 'right'));
    p = captions(p);
    final beforeMarkers = p;
    p = move.change(
      p,
      SetMarkers(
        MarkerStore([absolute(p, 'mark-1', time: Q.of(2), label: 'later')]),
      ),
    );
    final afterMarkers = p;
    p = move.change(
      p,
      SetMarkers(
        MarkerStore([absolute(p, 'mark-1', time: Q.of(2), label: 'changed')]),
      ),
    );
    final changes = documentFieldChanges(
      beforeMarkers.toJson()..remove('revision'),
      afterMarkers.toJson()..remove('revision'),
    );
    expect(fieldInvertConflicts(p.toJson(), changes), isTrue);
    assertPure(p, () {
      expect(
        () => applyFieldInvert(p.toJson(), changes),
        code('UNDO_CONFLICT'),
      );
    });
    expect(markersOf(p).single['label'], 'changed');
    expect(cueOf(p)['text'], 'hello');
  });

  test(
    'inverting a later SetMarkers keeps an earlier marker and moved remnant',
    () {
      var p = avFixture();
      final a = algebra.firstId(p);
      p = move.change(p, SplitClip(a, Q.of(1), 'right'));
      p = captions(p);
      p = move.change(
        p,
        SetMarkers(
          MarkerStore([
            absolute(p, 'mark-keep', time: Q.of(1, 5), label: 'keep'),
          ]),
        ),
      );
      final beforeSecond = p;
      p = move.change(
        p,
        SetMarkers(
          MarkerStore([
            TimelineMarker.fromJson(
              Map<String, dynamic>.from(markersOf(p).single),
            ),
            absolute(p, 'mark-drop', time: Q.of(2), label: 'drop'),
          ]),
        ),
      );
      final afterSecond = p;
      p = move.change(p, MoveClip('right', Q.of(1, 2)));
      final changes = documentFieldChanges(
        beforeSecond.toJson()..remove('revision'),
        afterSecond.toJson()..remove('revision'),
      );
      expect(fieldInvertConflicts(p.toJson(), changes), isFalse);
      final restored = ProjectDocument.fromJson(
        applyFieldInvert(p.toJson(), changes)
          ..['revision'] = p.revision.toString(),
      );
      expect(markersOf(restored).map((m) => m['label']).toSet(), {'keep'});
      expect(cueOf(restored)['text'], 'hello');
      expect(startOf(restored, 'right'), Q.of(3, 2));
    },
  );

  test(
    'followed clipLocal marker after a host move conflicts and stays put',
    () {
      var p = avFixture();
      final a = algebra.firstId(p);
      p = captions(p);
      final hostDur = Q.fromJson(media(p).first['timelineRange']['duration']);
      final beforeMarkers = p;
      p = move.change(
        p,
        SetMarkers(
          MarkerStore([
            absolute(
              p,
              'follow',
              time: Q.of(1, 2),
              label: 'follow',
            ).anchoredToClip(a, Q.of(0), hostDur),
          ]),
        ),
      );
      final afterMarkers = p;
      p = move.change(p, MoveClip(a, Q.of(1)));
      expect(Q.fromJson(markersOf(p).single['time']), Q.of(3, 2));
      final changes = documentFieldChanges(
        beforeMarkers.toJson()..remove('revision'),
        afterMarkers.toJson()..remove('revision'),
      );
      expect(fieldInvertConflicts(p.toJson(), changes), isTrue);
      assertPure(p, () {
        expect(
          () => applyFieldInvert(p.toJson(), changes),
          code('UNDO_CONFLICT'),
        );
      });
      expect(Q.fromJson(markersOf(p).single['time']), Q.of(3, 2));
      expect(startOf(p, a), Q.of(1));
      expect(cueOf(p)['text'], 'hello');
    },
  );
}
