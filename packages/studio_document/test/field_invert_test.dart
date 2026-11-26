import 'package:studio_contracts/studio_contracts.dart';
import 'package:studio_document/studio_document.dart';
import 'package:test/test.dart';

import 'edit_algebra_test.dart' as algebra;
import 'multi_move_test.dart' as move;
import 'persistent_audio_test.dart' show avFixture;

Matcher code(String c) =>
    throwsA(isA<StudioException>().having((e) => e.code, 'code', c));

Map cueOf(ProjectDocument p, [String id = 'cue-1']) =>
    (p.toJson()['captions'] as List).cast<Map>().singleWhere(
      (c) => c['id'] == id,
    );

List<Map> media(ProjectDocument p) => [
  for (final t in p.toJson()['sequences'][0]['tracks'])
    for (final c in t['items'])
      if (c['source'] != null) c as Map,
];

Q startOf(ProjectDocument p, String id) => Q.fromJson(
  media(p).singleWhere((c) => c['id'] == id)['timelineRange']['start'],
);

void main() {
  test(
    'ignores version-only diffs and restores a caption after an unrelated move',
    () {
      var p = avFixture();
      final a = algebra.firstId(p);
      p = move.change(p, SplitClip(a, Q.of(1), 'right'));
      final afterSplit = p;
      p = move.change(
        p,
        SetCaptions(
          CaptionStore([
            CaptionCue(
              'cue-left',
              TimeRange(Q.of(0), Q.of(1, 2)),
              'hello',
              manualFields: {'text', 'timing'},
            ),
          ]),
        ),
      );
      final afterCaptions = p;
      p = move.change(p, MoveClip('right', Q.of(1, 2)));
      expect(startOf(p, 'right'), Q.of(3, 2));
      expect(cueOf(p, 'cue-left')['text'], 'hello');
      final changes = documentFieldChanges(
        afterCaptions.toJson()..remove('revision'),
        p.toJson()..remove('revision'),
      );
      // Move of the right remnant should not list the left cue as changed.
      expect(
        changes.any(
          (c) => c.path.any((s) => s is Map && s['id'] == 'cue-left'),
        ),
        isFalse,
      );
      final captionChanges = documentFieldChanges(
        afterSplit.toJson()..remove('revision'),
        afterCaptions.toJson()..remove('revision'),
      );
      expect(fieldInvertConflicts(p.toJson(), captionChanges), isFalse);
      final restored = ProjectDocument.fromJson(
        applyFieldInvert(p.toJson(), captionChanges)
          ..['revision'] = p.revision.toString(),
      );
      expect(restored.toJson()['captions'], isEmpty);
      expect(startOf(restored, 'right'), Q.of(3, 2));
    },
  );

  test('followed clipLocal cue conflicts atomically and leaves the document unchanged', () {
    var p = avFixture();
    final a = algebra.firstId(p);
    p = move.change(
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
    final afterCaptions = p;
    p = move.change(p, MoveClip(a, Q.of(1, 2)));
    expect(Q.fromJson(cueOf(p)['timelineRange']['start']), Q.of(1, 2));
    final captionChanges = documentFieldChanges(
      avFixture().toJson()..remove('revision'),
      afterCaptions.toJson()..remove('revision'),
    );
    expect(fieldInvertConflicts(p.toJson(), captionChanges), isTrue);
    final raw = Map<String, dynamic>.from(p.toJson());
    expect(
      () => applyFieldInvert(p.toJson(), captionChanges),
      code('UNDO_CONFLICT'),
    );
    expect(p.toJson(), raw);
  });

  test('version-only maps produce no field changes', () {
    final a = {'id': 'x', 'version': '1', 'title': 'same'};
    final b = {'id': 'x', 'version': '9', 'title': 'same'};
    expect(documentFieldChanges(a, b), isEmpty);
  });

  test('applyFieldInvert removes an added caption track and cue', () {
    var p = avFixture();
    final before = p;
    p = move.change(
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
    final changes = documentFieldChanges(before.toJson(), p.toJson());
    final out = applyFieldInvert(p.toJson(), changes);
    expect(out['captions'], isEmpty);
    expect(
      (out['sequences'][0]['tracks'] as List).any(
        (t) => t['kind'] == 'caption',
      ),
      isFalse,
    );
  });
}
