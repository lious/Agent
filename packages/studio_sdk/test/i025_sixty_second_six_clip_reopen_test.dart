import 'dart:io';

import 'package:studio_sdk/studio_sdk.dart';
import 'package:test/test.dart';

/// Increment 1.97 official I-025 remainingAcceptance wording
/// 「60秒6clip工程：手改字幕/trim/撤销/保存重开后等值」 on the already-admitted
/// import / SplitClip / TrimClip / SetCaptions / undo / saveManaged /
/// reopen path. The 60s source is the admitted local video looped with
/// the already-used ffmpeg recipe; this is document equality after those
/// edits, not caption burn-in and not export. This file does not rewrite
/// local_video_test.dart, local_video_ui_test.dart, save_test.dart, or
/// caption_split_trim_test.dart, and does not invent a caption-burn path,
/// a 60s export, or new commands.
void main() {
  final library = Platform.environment['STUDIO_MEDIA_LIBRARY'];
  final fixture = Platform.environment['STUDIO_TEST_VIDEO'];

  late Directory dir;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('i025-60s-6clip-');
  });

  tearDown(() async {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  StudioWorkspace open() => StudioWorkspace.open(
    profile: AppProfile(
      appId: 'studio',
      region: 'local',
      features: {'project.metadata', 'media.local'},
    ),
    databasePath: '${dir.path}/db.sqlite',
    tenantId: 'local',
    workspaceId: 'i025-60s-6clip',
    mediaLibraryPath: library,
    mediaRootPath: '${dir.path}/media',
  );

  Future<File> loopedSixtySecondSource() async {
    final out = File('${dir.path}/sixty.mp4');
    final made = await Process.run('ffmpeg', [
      '-y',
      '-v',
      'error',
      '-stream_loop',
      '19',
      '-i',
      fixture!,
      '-t',
      '60',
      '-c',
      'copy',
      out.path,
    ]);
    expect(made.exitCode, 0, reason: made.stderr.toString());
    return out;
  }

  Future<void> importSixty(StudioWorkspace workspace) async {
    workspace.openDemo();
    final source = await loopedSixtySecondSource();
    await workspace.importVideo(
      LocalFileGrant.fromUserSelection(source),
      expectedRevision: BigInt.zero,
    );
  }

  List<Map<String, dynamic>> videos(ProjectDocument p) {
    final items =
        (p.toJson()['sequences'][0]['tracks'][0]['items'] as List)
            .cast<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList()
          ..sort(
            (a, b) => Q
                .fromJson(a['timelineRange']['start'])
                .compareTo(Q.fromJson(b['timelineRange']['start'])),
          );
    return items;
  }

  String contents(ProjectDocument p) =>
      contentHash(p.toJson()..remove('revision'));

  Future<void> splitIntoSix(StudioWorkspace workspace) async {
    var remaining = videos(workspace.current).single['id'] as String;
    for (var i = 1; i <= 5; i++) {
      final rightId = 'clip-${i + 1}';
      workspace.edit(
        SplitClip(remaining, Q.of(10 * i), rightId),
        expectedRevision: workspace.current.revision,
      );
      remaining = rightId;
    }
  }

  void handEditCaptions(StudioWorkspace workspace, {required String text}) {
    workspace.edit(
      SetCaptions(
        CaptionStore([
          CaptionCue(
            'cue-a',
            TimeRange(Q.of(0), Q.of(2)),
            text,
            manualFields: {'text', 'timing'},
          ),
          CaptionCue(
            'cue-b',
            TimeRange(Q.of(25), Q.of(2)),
            'middle cue',
            manualFields: {'text', 'timing'},
          ),
        ]),
      ),
      expectedRevision: workspace.current.revision,
    );
  }

  void expectSixPackedClips(ProjectDocument p, {required Q duration}) {
    final clips = videos(p);
    expect(clips, hasLength(6));
    expect(Q.fromJson(p.toJson()['sequences'][0]['duration']), duration);
    for (var i = 0; i < 5; i++) {
      expect(Q.fromJson(clips[i]['timelineRange']['start']), Q.of(10 * i));
      expect(Q.fromJson(clips[i]['timelineRange']['duration']), Q.of(10));
    }
  }

  test(
    'caption trim undo then saveManaged reopen equals the post-undo document',
    () async {
      var workspace = open();
      try {
        await importSixty(workspace);
        await splitIntoSix(workspace);
        expectSixPackedClips(workspace.current, duration: Q.of(60));
        expect(
          Q.fromJson(
            videos(workspace.current).last['timelineRange']['duration'],
          ),
          Q.of(10),
        );
        handEditCaptions(workspace, text: 'first draft');
        handEditCaptions(workspace, text: 'hand edited');
        expectSixPackedClips(workspace.current, duration: Q.of(60));
        final afterCaptions = contents(workspace.current);
        final lastId = videos(workspace.current).last['id'] as String;
        workspace.edit(
          TrimClip(lastId, 'out', Q.of(-1), ripple: true),
          expectedRevision: workspace.current.revision,
        );
        expect(contents(workspace.current), isNot(afterCaptions));
        final trimmed = videos(workspace.current)
            .firstWhere((clip) => clip['id'] == lastId);
        expect(Q.fromJson(trimmed['timelineRange']['duration']), Q.of(9));
        expect(
          Q.fromJson(workspace.current.toJson()['sequences'][0]['duration']),
          Q.of(59),
        );
        workspace.undo(expectedRevision: workspace.current.revision);
        expect(contents(workspace.current), afterCaptions);
        expectSixPackedClips(workspace.current, duration: Q.of(60));
        expect(
          (workspace.current.toJson()['captions'] as List)
              .cast<Map>()
              .singleWhere((cue) => cue['id'] == 'cue-a')['text'],
          'hand edited',
        );
        final saved = workspace.current;
        workspace.saveManaged();
        expect(workspace.persistence().userSavedRevision, saved.revision);
        final savedHash = saved.hash;
        final savedContents = contents(saved);
        await workspace.closeAsync();
        workspace = open();
        final reopened = workspace.openDemo();
        expect(reopened.hash, savedHash);
        expect(contents(reopened), savedContents);
        expectSixPackedClips(reopened, duration: Q.of(60));
        expect(
          (reopened.toJson()['captions'] as List).cast<Map>().singleWhere(
            (cue) => cue['id'] == 'cue-a',
          )['text'],
          'hand edited',
        );
        expect(
          (reopened.toJson()['captions'] as List).cast<Map>().singleWhere(
            (cue) => cue['id'] == 'cue-b',
          )['text'],
          'middle cue',
        );
      } finally {
        await workspace.closeAsync();
      }
    },
    skip: library == null || fixture == null,
  );

  test(
    'caption and trim saveManaged reopen equals the trimmed six-clip document',
    () async {
      var workspace = open();
      try {
        await importSixty(workspace);
        await splitIntoSix(workspace);
        handEditCaptions(workspace, text: 'first draft');
        handEditCaptions(workspace, text: 'hand edited');
        final lastId = videos(workspace.current).last['id'] as String;
        workspace.edit(
          TrimClip(lastId, 'out', Q.of(-1), ripple: true),
          expectedRevision: workspace.current.revision,
        );
        expect(
          Q.fromJson(workspace.current.toJson()['sequences'][0]['duration']),
          Q.of(59),
        );
        expect(
          Q.fromJson(
            videos(workspace.current).firstWhere(
              (clip) => clip['id'] == lastId,
            )['timelineRange']['duration'],
          ),
          Q.of(9),
        );
        final saved = workspace.current;
        workspace.saveManaged();
        final savedHash = saved.hash;
        final savedContents = contents(saved);
        await workspace.closeAsync();
        workspace = open();
        final reopened = workspace.openDemo();
        expect(reopened.hash, savedHash);
        expect(contents(reopened), savedContents);
        final clips = videos(reopened);
        expect(clips, hasLength(6));
        expect(
          Q.fromJson(reopened.toJson()['sequences'][0]['duration']),
          Q.of(59),
        );
        expect(Q.fromJson(clips.last['timelineRange']['duration']), Q.of(9));
        expect(
          (reopened.toJson()['captions'] as List).cast<Map>().singleWhere(
            (cue) => cue['id'] == 'cue-a',
          )['text'],
          'hand edited',
        );
      } finally {
        await workspace.closeAsync();
      }
    },
    skip: library == null || fixture == null,
  );
}
