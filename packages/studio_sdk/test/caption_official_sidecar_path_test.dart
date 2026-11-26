import 'dart:io';

import 'package:studio_sdk/studio_sdk.dart';
import 'package:test/test.dart';

Matcher code(String c) =>
    throwsA(isA<StudioException>().having((e) => e.code, 'code', c));

AssFontLayoutPolicy policy() => AssFontLayoutPolicy(
  requestedFontFamily: 'StudioTestNoto',
  availableFontFamilies: const {'StudioTestNoto'},
);

void main() {
  late Directory root;
  late StudioWorkspace w;
  setUp(() async {
    root = Directory.systemTemp.createTempSync('caption-official-sidecar-');
    w = StudioWorkspace.open(
      profile: AppProfile(
        appId: 'studio',
        region: 'local',
        features: {'project.metadata'},
      ),
      databasePath: '${root.path}/db',
      tenantId: 'local',
      workspaceId: 'official-sidecar',
    );
    w.openDemo();
  });
  tearDown(() async {
    await w.closeAsync();
    root.deleteSync(recursive: true);
  });

  test('official persist path refuses overlapping sidecar import as CAPTION_OVERLAP without a partial commit', () async {
    final baseline = w.current.revision;
    expect(w.current.toJson()['captions'], isEmpty);

    final overlapping = File('${root.path}/overlap.srt')
      ..writeAsStringSync(
        '1\n00:00:00,000 --> 00:00:01,500\nleft\n\n'
        '2\n00:00:01,000 --> 00:00:02,000\nright\n',
      );
    await expectLater(
      w.importCaptions(
        LocalFileGrant.fromUserSelection(overlapping),
        CaptionFormat.srt,
        expectedRevision: baseline,
      ),
      throwsA(
        isA<StudioException>().having((e) => e.code, 'code', 'CAPTION_OVERLAP'),
      ),
    );
    expect(w.current.revision, baseline);
    expect(w.current.toJson()['captions'], isEmpty);

    w.edit(
      SetCaptions(
        CaptionStore([
          CaptionCue('existing', TimeRange(Q.of(0), Q.of(2)), 'existing'),
        ]),
      ),
      expectedRevision: w.current.revision,
    );
    final afterExisting = w.current.revision;
    final conflict = File('${root.path}/conflict.vtt')
      ..writeAsStringSync('WEBVTT\n\n00:00:01.000 --> 00:00:03.000\nnew\n');
    await expectLater(
      w.importCaptions(
        LocalFileGrant.fromUserSelection(conflict),
        CaptionFormat.vtt,
        expectedRevision: afterExisting,
      ),
      throwsA(
        isA<StudioException>().having((e) => e.code, 'code', 'CAPTION_OVERLAP'),
      ),
    );
    expect(w.current.revision, afterExisting);
    expect((w.current.toJson()['captions'] as List).single['text'], 'existing');

    final touching = File('${root.path}/touching.srt')
      ..writeAsStringSync('1\n00:00:02,000 --> 00:00:03,000\ntouch\n');
    final imported = await w.importCaptions(
      LocalFileGrant.fromUserSelection(touching),
      CaptionFormat.srt,
      expectedRevision: afterExisting,
    );
    expect(imported.warnings, isEmpty);
    expect(
      (w.current.toJson()['captions'] as List).map((c) => c['text']),
      containsAll(['existing', 'touch']),
    );
  });

  test('official persist path lists unsupported ASS style fields and keeps official cue text and times', () async {
    final inbound = File('${root.path}/styled.ass')
      ..writeAsStringSync(
        '[V4+ Styles]\n'
        'Format: Name, Fontname, Fontsize, PrimaryColour, Bold, Italic, Alignment, MarginV\n'
        'Style: Title,StudioTestNoto,72,&H000000FF,1,1,8,40\n\n'
        '[Events]\n'
        'Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text\n'
        'Dialogue: 1,0:00:00.01,0:00:01.23,Title,narrator,10,10,40,Karaoke,你好🙂\\Nשלום\n',
      );
    final imported = await w.importCaptions(
      LocalFileGrant.fromUserSelection(inbound),
      CaptionFormat.ass,
      expectedRevision: w.current.revision,
      fontPolicy: policy(),
    );
    expect(
      imported.warnings,
      containsAll([
        'ASS_STYLE_FONT_NOT_RENDERED',
        'ASS_STYLE_FIELDS_DROPPED',
        'ASS_EVENT_STYLE_DROPPED',
      ]),
    );
    final cue = (w.current.toJson()['captions'] as List).single;
    expect(cue['text'], '你好🙂\nשלום');
    expect(cue['styleEffectId'], isNull);
  });
}
