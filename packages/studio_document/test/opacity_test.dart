import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:studio_document/studio_document.dart';
import 'package:studio_contracts/studio_contracts.dart';

import 'persistent_audio_test.dart' show avFixture;

void main() {
  late ProjectDocument p;
  var serial = 0;
  final versions = <String, int>{};
  ProjectDocument edit(ProjectDocument d, EditOperation op) => applyEdit(
    d,
    op,
    newId: () => 'opacity-${serial++}',
    nextVersion: (id) =>
        '${versions.update(id, (v) => v + 1, ifAbsent: () => 20)}',
  );
  Map<String, dynamic> clip(ProjectDocument d) =>
      (d.toJson()['sequences'][0]['tracks'][0]['items'] as List).firstWhere(
        (c) => c['source'] != null,
      ) as Map<String, dynamic>;
  setUp(() {
    p = ProjectDocument.fromJson(
      jsonDecode(File('fixtures/project/local-video.json').readAsStringSync())
          as Map<String, dynamic>,
    );
    serial = 0;
    versions.clear();
  });
  test('static opacity creates immutable effect/clip/sequence versions, exact Q16, identity/noop and input bounds', () {
    final c = clip(p), id = c['id'] as String;
    final old = p.hash;
    expect(edit(p, SetClipOpacity(id, 1)).hash, old);
    final a = edit(p, SetClipOpacity(id, .5)),
        b = edit(a, SetClipOpacity(id, .25));
    expect(p.hash, old);
    expect(p.toJson()['effects'], isEmpty);
    expect(clipOpacityQ16(a.toJson(), clip(a)), 32768);
    expect(clipOpacityQ16(b.toJson(), clip(b)), 16384);
    expect(
      a.toJson()['effects'][0]['version'],
      isNot(b.toJson()['effects'][0]['version']),
    );
    expect(clip(a)['version'], isNot(clip(b)['version']));
    expect(
      a.toJson()['sequences'][0]['version'],
      isNot(b.toJson()['sequences'][0]['version']),
    );
    expect(edit(b, SetClipOpacity(id, .25)).hash, b.hash);
    for (final n in [-.01, 1.01, double.nan, double.infinity]) {
      expect(
        () => edit(b, SetClipOpacity(id, n)),
        throwsA(
          isA<StudioException>().having((e) => e.code, 'code', 'OPACITY_RANGE'),
        ),
      );
    }
  });
  test('split clones owner, trim preserves node, deleting removes current orphan only', () {
    final a = edit(p, SetClipOpacity(clip(p)['id'] as String, .5));
    final hash = a.hash;
    final split = edit(
      a,
      SplitClip(clip(a)['id'] as String, Q.of(1), 'opacity-right'),
    );
    final d = split.toJson(),
        items = (d['sequences'][0]['tracks'][0]['items'] as List)
            .where((c) => c['source'] != null)
            .toList();
    expect(d['effects'].length, 2);
    for (final c in items) {
      final effect = (d['effects'] as List).singleWhere(
        (e) => e['id'] == c['effectIds'][0],
      );
      expect(effect['owner']['id'], c['id']);
      expect(clipOpacityQ16(d, c as Map<String, dynamic>), 32768);
    }
    final trimmed = edit(split, TrimClip('opacity-right', 'in', Q.of(1, 30)));
    final removed = edit(trimmed, DeleteClip('opacity-right'));
    expect(removed.toJson()['effects'].length, 1);
    expect(a.hash, hash);
    expect(a.toJson()['effects'].length, 1);
  });
  test('linked audio extraction does not inherit visual node, linked split owns independent video effects', () {
    p = avFixture();
    var a = edit(p, SetClipOpacity(clip(p)['id'] as String, .5));
    a = edit(a, ExtractAudioClip(clip(a)['id'] as String, 'audio-stream'));
    expect(
      a.toJson()['sequences'][0]['tracks'][1]['items'][0]['effectIds'],
      isEmpty,
    );
    a = edit(a, SplitClip(clip(a)['id'] as String, Q.of(1), 'linked-right'));
    expect(a.toJson()['effects'].length, 2);
    expect(a.toJson()['linkGroups'].length, 2);
  });
  test('locks, unknown effect versions and extensions never become writable by replacing semantics', () {
    var a = edit(p, SetClipOpacity(clip(p)['id'] as String, .5));
    for (final lock in ['*', 'effectIds', 'effectIds.0', 'effects.value']) {
      final d = a.toJson();
      d['sequences'][0]['tracks'][0]['items'][0]['lockedFields'] = [lock];
      expect(
        () => edit(
          ProjectDocument.fromJson(d),
          SetClipOpacity(clip(a)['id'] as String, .25),
        ),
        throwsA(isA<StudioException>()),
      );
    }
    for (final field in ['pluginVersion', 'extensions']) {
      final d = a.toJson();
      d['effects'][0][field] = field == 'pluginVersion'
          ? '9.0.0'
          : {'future': true};
      expect(
        () => requireLocalEditingWritable(ProjectDocument.fromJson(d)),
        throwsA(isA<StudioException>()),
      );
    }
  });
}
