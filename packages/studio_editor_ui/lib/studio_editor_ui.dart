import 'resource_preservation_panel.dart';
import 'project_inspector.dart';

import 'package:studio_peer_ui/studio_peer_ui.dart';

import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';

import 'package:material_ui/material_ui.dart';
import 'package:studio_sdk/studio_sdk.dart';

part 'edit_gesture_controls.dart';
part 'multi_move_controls.dart';
part 'snap_controls.dart';
part 'pointer_timeline.dart';
part 'clipboard_controls.dart';

/// Shared local-video workbench. Unsupported media/operations fail explicitly;
/// this is not the complete timeline, preview, audio mixer, or AI product UI.
class FoundationApp extends StatefulWidget {
  const FoundationApp({super.key, required this.workspace});
  final StudioWorkspace workspace;
  @override
  State<FoundationApp> createState() => _FoundationAppState();
}

class _FoundationAppState extends State<FoundationApp>
    with WidgetsBindingObserver {
  late ProjectDocument _project;
  late TextEditingController _title;
  final _input = TextEditingController(),
      _archive = TextEditingController(),
      _output = TextEditingController(),
      _frames = TextEditingController(text: '30');
  final _captionText = TextEditingController(),
      _captionStart = TextEditingController(text: '0'),
      _captionDuration = TextEditingController(text: '1000'),
      _captionPath = TextEditingController();
  final _markerLabel = TextEditingController(text: 'Marker'),
      _markerTime = TextEditingController(text: '0'),
      _markerDuration = TextEditingController(text: '0'),
      _markerSidecarPath = TextEditingController();
  bool _markerRipple = false;
  String? _markerSelected;
  final _peerHash = TextEditingController();
  final _inspectionPath = TextEditingController();

  Future<List<int>> _readInspectionFile() async {
    final file = LocalFileGrant.fromUserSelection(File(_inspectionPath.text))
        .file;
    if (await FileSystemEntity.type(file.path, followLinks: false) !=
        FileSystemEntityType.file) {
      throw const StudioException('REGULAR_JSON_FILE_REQUIRED');
    }
    final stat = await file.stat();
    if (!Platform.isWindows && (stat.mode & 0xf000) != 0x8000) {
      throw const StudioException('REGULAR_JSON_FILE_REQUIRED');
    }
    final handle = await file.open();
    try {
      if (await handle.length() > ProjectInspectorPanel.maxInputBytes) {
        throw const StudioException('DOCUMENT_LIMIT');
      }
      final bytes = await handle.read(ProjectInspectorPanel.maxInputBytes + 1);
      if (bytes.length > ProjectInspectorPanel.maxInputBytes ||
          (await handle.read(1)).isNotEmpty) {
        throw const StudioException('DOCUMENT_LIMIT');
      }
      return bytes;
    } finally {
      await handle.close();
    }
  }

  final _previewTime = TextEditingController(text: '0');
  final _masterGain = TextEditingController(text: '0');
  final _dissolveBefore = TextEditingController(text: '6');
  final _dissolveAfter = TextEditingController(text: '6');
  final _tx = TextEditingController(text: '0');
  final _ty = TextEditingController(text: '0');
  final _scale = TextEditingController(text: '1');
  final _rotation = TextEditingController(text: '0');
  final _rasterInputs = <String, TextEditingController>{
    for (final e in identityCrop.entries)
      'crop-${e.key}': TextEditingController(text: '${e.value}'),
    for (final e in identityColorBasic.entries)
      'color-${e.key}': TextEditingController(text: '${e.value}'),
  };
  final _opacity = TextEditingController(text: '0.5');
  final _opacityFrame = TextEditingController(text: '0');
  bool _opacityHold = false;
  EditGesture? _gesture;
  final _snapZoom = TextEditingController(text: '100'),
      _snapOrigin = TextEditingController(text: '0'),
      _snapPointer = TextEditingController(text: '96'),
      _snapPlayhead = TextEditingController(text: '30');
  SnappedMovePlan? _snapPlan;
  bool _multiInputInvalid = false;
  bool _snapExpanded = false;
  bool _pointerActive = false;
  final _pasteAt = TextEditingController();
  final _invertCommandId = TextEditingController();
  final _rippleCloseStart = TextEditingController();
  final _rippleCloseDuration = TextEditingController();
  String _collisionMode = 'reject';
  bool _ignoreLinksThisMove = false;
  String? _clipboardError;
  final _multiSelection = <String>{};
  EditGesture? _multiGesture;
  String? _multiError;
  Q? _multiDelta;
  ui.Image? _multiImage;
  bool _multiPreviewBusy = false;
  final _multiFocus = FocusNode();
  final _gestureFocus = FocusNode();
  ui.Image? _gestureImage;
  double _gestureValue = 1, _gestureStartValue = 1;
  int? _gesturePointer;
  bool _gesturePointerReleased = false;
  bool _gestureRendering = false, _gestureDirty = false;
  bool get _hasPersistentAudio =>
      (widget.workspace.current.toJson()['sequences'][0]['tracks'] as List).any(
        (t) => t['kind'] == 'audio',
      );
  bool _includeEmbeddedAudio = false;
  Timer? _playbackTimer;
  Map<String, dynamic> _playback = {'state': 'stopped'};
  final _videoPulse = ValueNotifier<int>(0);
  final _playbackSeek = TextEditingController(text: '0'),
      _playbackSink = TextEditingController();
  bool _timelineEnabled = false, _timelineRendering = false;
  ui.Image? _timelineImage;
  TimelinePreviewFrame? _timelineFrame;
  int _timelineSkippedSourceFrames = 0, _timelineLateCommits = 0;
  int _timelineGeneration = 0,
      _timelineDelivered = 0,
      _timelineDropped = 0,
      _timelineCommitted = 0;
  String? _timelineLastKey;
  void _clearTimelineVideo() {
    _timelineGeneration++;
    _timelineLastKey = null;
    _timelineImage?.dispose();
    _timelineImage = null;
    _timelineFrame = null;
  }

  Future<void> _requestTimelineVideo() async {
    if (!mounted || !_timelineEnabled || _timelineRendering) return;
    final clock = widget.workspace.timelinePlayback;
    if (clock['clockValid'] != true ||
        !{'playing', 'paused', 'finished'}.contains(clock['state'])) {
      if (_timelineImage != null) {
        _clearTimelineVideo();
        _videoPulse.value++;
      }
      return;
    }
    final key =
        '${clock['snapshotHash']}:${clock['playbackGeneration']}:${clock['epoch']}:${clock['presentedSample']}';
    if (key == _timelineLastKey) return;
    _timelineLastKey = key;
    _timelineRendering = true;
    final generation = _timelineGeneration;
    ui.Image? owned;
    var delivered = false, decodeAbandoned = false;
    try {
      final frame = await widget.workspace.renderTimelineFromAudioClock();
      if (frame == null) return;
      final done = Completer<ui.Image>();
      ui.decodeImageFromPixels(
        frame.pixels.rgba,
        frame.pixels.width,
        frame.pixels.height,
        ui.PixelFormat.rgba8888,
        (image) {
          if (decodeAbandoned) {
            image.dispose();
          } else {
            done.complete(image);
          }
        },
      );
      owned = await done.future.timeout(
        const Duration(seconds: 2),
        onTimeout: () =>
            throw const StudioException('TIMELINE_IMAGE_DECODE_TIMEOUT'),
      );
      if (!mounted ||
          generation != _timelineGeneration ||
          !widget.workspace.isTimelineFrameCurrent(frame)) {
        _timelineDropped++;
        return;
      }
      final previous = _timelineFrame;
      if (previous != null &&
          previous.clockEpoch == frame.clockEpoch &&
          previous.assetId == frame.assetId &&
          previous.clipId == frame.clipId &&
          frame.proxyIndex > previous.proxyIndex + 1) {
        _timelineSkippedSourceFrames +=
            frame.proxyIndex - previous.proxyIndex - 1;
      }
      final adopted = owned;
      owned = null;
      _timelineImage?.dispose();
      _timelineImage = adopted;
      _timelineFrame = frame;
      _timelineDelivered++;
      delivered = true;
      _videoPulse.value++;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted &&
            generation == _timelineGeneration &&
            identical(_timelineFrame, frame)) {
          if (widget.workspace.isTimelineFrameCurrent(frame)) {
            _timelineCommitted++;
          } else {
            _timelineLateCommits++;
          }
          _videoPulse.value++;
        }
      });
    } on StudioException catch (e) {
      if (e.code == 'TIMELINE_FRAME_STALE' ||
          generation != _timelineGeneration) {
        _timelineDropped++;
      } else if (mounted) {
        widget.workspace.stopTimelinePlayback();
        setState(() {
          _clearTimelineVideo();
          _error = e.code;
        });
      }
    } catch (_) {
      if (mounted && generation == _timelineGeneration) {
        widget.workspace.stopTimelinePlayback();
        setState(() {
          _clearTimelineVideo();
          _error = 'TIMELINE_PREVIEW_IO_FAILED';
        });
      }
    } finally {
      decodeAbandoned = true;
      owned?.dispose();
      if (!delivered) _timelineLastKey = null;
      _timelineRendering = false;
    }
  }

  void _pollPlayback() {
    if (!mounted) return;
    try {
      final next = widget.workspace.timelinePlayback;
      if (next.toString() != _playback.toString()) {
        _playback = next;
        _videoPulse.value++;
      }
      unawaited(_requestTimelineVideo());
    } on StudioException catch (e) {
      setState(() => _error = e.code);
    }
  }

  void _playbackControl(String op, {int? sample}) {
    if (_pointerActive) {
      setState(() => _error = 'GESTURE_IN_PROGRESS');
      return;
    }
    try {
      if (op == 'seek' || op == 'rebind') {
        _clearTimelineVideo();
      }
      widget.workspace.controlTimelinePlayback(
        op,
        sample: sample,
        sink: op == 'rebind' ? _playbackSink.text : null,
      );
      _pollPlayback();
    } on StudioException catch (e) {
      setState(() => _error = e.code);
    }
  }

  ui.Image? _previewImage;
  String? _peerAdoptionId;
  BigInt? _peerAdoptionRevision;
  bool _gcConfirmed = false;
  String? _proxyDiscardConsent, _proxyRepairConsent;
  final _historyKeep = TextEditingController();
  final _historyName = TextEditingController();
  Map<String, dynamic>? _historyReview;
  bool _historyConsent = false;
  String _historyStatus = 'No retention review. Default: preserveAll.';
  final _diskLimit = TextEditingController();
  String? _diskConsent;
  String _storageView = 'No namespace inventory requested.';
  String? _captionSelected;
  String? _error, _selected;
  String _status =
      'All edits commit to local SQLite; archive save is explicit.';
  bool _busy = false, _videoOnly = false;
  SaveHandle? _saving;
  StreamSubscription<void>? _persistenceSubscription;
  @override
  void initState() {
    super.initState();
    _project = widget.workspace.openDemo();
    _title = TextEditingController(text: _project.title);
    _masterGain.text = '${_project.toJson()['audioBuses'][0]['gainDb']}';
    WidgetsBinding.instance.addObserver(this);
    _playbackTimer = Timer.periodic(
      const Duration(milliseconds: 16),
      (_) => _pollPlayback(),
    );
    _persistenceSubscription = widget.workspace.persistenceEvents.listen((_) {
      if (mounted) setState(() {});
    });
  }

  void _clearPreview() {
    _previewImage?.dispose();
    _previewImage = null;
  }

  void _refresh() {
    if (_project.hash != widget.workspace.current.hash) {
      _clearPreview();
      _clearTimelineVideo();
    }
    _project = widget.workspace.current;
    _title.text = _project.title;
    _masterGain.text = '${_project.toJson()['audioBuses'][0]['gainDb']}';
    if (!_clips.any((c) => c['id'] == _selected)) _selected = null;
    if (!(_project.toJson()['captions'] as List).any(
      (c) => c['id'] == _captionSelected,
    )) {
      _captionSelected = null;
    }
    if (!(_project.toJson()['markers'] as List).any(
      (m) => m['id'] == _markerSelected,
    )) {
      _markerSelected = null;
    }
  }

  void _gestureSetState(VoidCallback action) {
    if (mounted) setState(action);
  }

  void _act(ProjectDocument Function() action) {
    if (_gesture != null || _multiGesture != null || _pointerActive) {
      setState(() => _error = 'GESTURE_IN_PROGRESS');
      return;
    }
    try {
      action();
      setState(() {
        _refresh();
        _error = null;
      });
    } on StudioException catch (e) {
      setState(() => _error = e.code);
    } catch (_) {
      setState(() => _error = 'LOCAL_COMMIT_FAILED');
    }
  }

  Future<void> _run(Future<String> Function() action) async {
    if (_gesture != null || _multiGesture != null || _pointerActive) {
      setState(() => _error = 'GESTURE_IN_PROGRESS');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await action();
      if (mounted) {
        setState(() {
          _refresh();
          _status = result;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = e is StudioException ? e.code : 'LOCAL_IO_FAILED: $e',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  List<dynamic> get _clips {
    final tracks = _project.toJson()['sequences'][0]['tracks'] as List;
    return [
      for (final track in tracks)
        for (final c in track['items'])
          if (c['source'] != null) c,
    ];
  }

  Q _delta() {
    final n = int.tryParse(_frames.text);
    if (n == null || n <= 0 || n > 120000) {
      throw const StudioException('POSITIVE_FRAME_COUNT_REQUIRED');
    }
    final rate = _project.toJson()['sequences'][0]['frameRate'];
    return Q.of(n * (rate['d'] as int), rate['n'] as int);
  }

  void _edit(EditOperation Function() operation) => _act(
    () =>
        widget.workspace.edit(operation(), expectedRevision: _project.revision),
  );

  EditOperation _rollCut() {
    final selected = _clips.singleWhere((c) => c['id'] == _selected);
    final selectedStart = Q.fromJson(selected['timelineRange']['start']);
    final selectedEnd =
        selectedStart + Q.fromJson(selected['timelineRange']['duration']);
    final selectedTrack = selected['trackId'];
    Map? later;
    Map? earlier;
    for (final c in _clips) {
      if (c['id'] == selected['id'] || c['trackId'] != selectedTrack) {
        continue;
      }
      final start = Q.fromJson(c['timelineRange']['start']);
      final end = start + Q.fromJson(c['timelineRange']['duration']);
      if (start == selectedEnd) {
        later = c as Map;
      } else if (end == selectedStart) {
        earlier = c as Map;
      }
    }
    if (later != null) {
      return RollCut(selected['id'] as String, later['id'] as String, _delta());
    }
    if (earlier != null) {
      return RollCut(
        earlier['id'] as String,
        selected['id'] as String,
        _delta(),
      );
    }
    throw const StudioException('NOT_ADJACENT');
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      _cancelGestureUi();
      _cancelMultiMoveUi();
    }
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      try {
        widget.workspace.pauseTimelinePlaybackForLifecycle();
        widget.workspace.flushCheckpoint();
      } catch (error) {
        if (mounted) {
          setState(
            () => _error = error is StudioException
                ? error.code
                : 'CHECKPOINT_FAILED',
          );
        }
      }
    }
  }

  String get _persistenceText {
    final p = widget.workspace.persistence(
      target: _archive.text.isEmpty ? null : File(_archive.text),
    );
    return 'Durable ${p.headRevision} · checkpoint ${p.checkpointRevision ?? "none"} · explicit save ${p.userSavedRevision ?? "none"} · target ${p.targetSavedRevision ?? "none"}${p.packageBehind ? " (package behind)" : ""}';
  }

  Future<String> _saveArchive() async {
    final handle = widget.workspace.requestArchiveSave(File(_archive.text));
    setState(() => _saving = handle);
    final subscription = handle.progress.listen((phase) {
      if (mounted) {
        setState(() => _status = 'Archive ${handle.snapshot.revision}: $phase');
      }
    });
    try {
      final receipt = await handle.result;
      return 'Archive saved at revision ${receipt.snapshot.revision}';
    } finally {
      await subscription.cancel();
      if (mounted) setState(() => _saving = null);
    }
  }

  @override
  void dispose() {
    _pasteAt.dispose();
    _invertCommandId.dispose();
    _rippleCloseStart.dispose();
    _rippleCloseDuration.dispose();
    for (final c in [_snapZoom, _snapOrigin, _snapPointer, _snapPlayhead]) {
      c.dispose();
    }
    final multi = _multiGesture;
    if (multi != null) widget.workspace.cancelGesture(multi);
    _multiImage?.dispose();
    _multiFocus.dispose();
    final gesture = _gesture;
    if (gesture != null) widget.workspace.cancelGesture(gesture);
    _gestureImage?.dispose();
    _gestureFocus.dispose();
    _playbackTimer?.cancel();
    _videoPulse.dispose();
    _clearTimelineVideo();
    widget.workspace.stopTimelinePlayback();
    _playbackSeek.dispose();
    _playbackSink.dispose();
    widget.workspace.cancelSourcePreview();
    _previewImage?.dispose();
    _previewTime.dispose();
    _masterGain.dispose();
    _dissolveBefore.dispose();
    _dissolveAfter.dispose();
    _tx.dispose();
    _ty.dispose();
    _scale.dispose();
    _rotation.dispose();
    for (final c in _rasterInputs.values) {
      c.dispose();
    }
    _opacity.dispose();
    _opacityFrame.dispose();
    _inspectionPath.dispose();
    _diskLimit.dispose();
    _historyKeep.dispose();
    _historyName.dispose();
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_persistenceSubscription?.cancel());
    for (final c in [
      _title,
      _input,
      _archive,
      _output,
      _frames,
      _captionText,
      _captionStart,
      _captionDuration,
      _captionPath,
      _markerLabel,
      _markerTime,
      _markerDuration,
      _markerSidecarPath,
      _peerHash,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Widget _path(String key, String label, TextEditingController controller) =>
      TextField(
        key: Key(key),
        maxLines: key == 'caption-text' ? 3 : 1,
        controller: controller,
        enabled: !_busy,
        decoration: InputDecoration(labelText: label),
      );

  List<Widget> _mediaControls() => [
    const Divider(),
    const Text(
      'Local video · single track · optional offline AAC',
      style: TextStyle(fontSize: 22),
    ),
    const Text(
      'CFR,1×, Rec.709 limited; H264 Main4 gate. Explicit RGBA128 timeline preview uses confirmed audio-service clock, not physical AV qualification. Clip-local hold/linear opacity over black (linear Rec.709 CPU); Source crop → static transform2d → colorBasic → opacity; bilinear linear-light CPU over black. Other effects unsupported. Rights unknown = warning, not authorization. No media uploads.',
    ),
    _path('import-path', 'Selected local video path', _input),
    CheckboxListTile(
      key: const Key('import-video-only'),
      value: _videoOnly,
      title: const Text(
        'Create a video clip only; source audio stays in the asset. Audio export requires separate opt-in.',
      ),
      onChanged: _busy ? null : (v) => setState(() => _videoOnly = v ?? false),
    ),
    FilledButton(
      key: const Key('import-video'),
      onPressed: _busy
          ? null
          : () => _run(() async {
              await widget.workspace.importVideo(
                LocalFileGrant.fromUserSelection(File(_input.text)),
                expectedRevision: _project.revision,
                acknowledgeVideoOnly: _videoOnly,
              );
              return 'Video imported; rights evidence not verified.';
            }),
      child: const Text('Import video'),
    ),
    TextField(
      key: const Key('peer-adopt-hash'),
      controller: _peerHash,
      enabled: !_busy,
      onChanged: (_) {
        _peerAdoptionId = null;
        _peerAdoptionRevision = null;
      },
      decoration: const InputDecoration(
        labelText: 'Received peer inbox raw SHA256 to explicitly adopt as video (no path)',
      ),
    ),
    FilledButton(
      key: const Key('peer-adopt-video'),
      onPressed: _busy
          ? null
          : () => _run(() async {
              _peerAdoptionId ??=
                  'adopt-ui-${DateTime.now().microsecondsSinceEpoch}';
              _peerAdoptionRevision ??= _project.revision;
              await widget.workspace.adoptPeerVideo(
                _peerHash.text.trim(),
                commandId: _peerAdoptionId!,
                expectedRevision: _peerAdoptionRevision!,
                acknowledgeVideoOnly: _videoOnly,
              );
              return 'Peer inbox video adopted into production CAS/project; retry of this intent is idempotent. Rights remain unverified.';
            }),
      child: const Text('Explicitly adopt received video into project'),
    ),
    OutlinedButton(
      onPressed: _busy
          ? null
          : () => setState(() {
              _peerAdoptionId = null;
              _peerAdoptionRevision = null;
            }),
      child: const Text('Start NEW adoption intent at displayed revision'),
    ),
    CheckboxListTile(
      key: const Key('gc-consent'),
      value: _gcConfirmed,
      onChanged: _busy
          ? null
          : (v) => setState(() => _gcConfirmed = v ?? false),
      title: const Text(
        'Explicitly delete only unreferenced managed CAS files and revoked/expired inbox transfers; keep ALL historical project pins',
      ),
    ),
    OutlinedButton(
      key: const Key('collect-local-garbage'),
      onPressed: _busy
          ? null
          : () => _run(() async {
              if (!_gcConfirmed) {
                throw const StudioException('GC_EXPLICIT_CONSENT_REQUIRED');
              }
              final receipt = await widget.workspace.collectLocalGarbage();
              _gcConfirmed = false;
              return 'Controlled local GC: $receipt. SQLite pages may be reused; no physical disk shrink promised.';
            }),
      child: const Text('Collect unreferenced local material (explicit only)'),
    ),
    const Text(
      'Persisted audio clips export automatically; linked edits affect BOTH clips. VIDEO dissolve does not add an audio fade.',
    ),
    OutlinedButton(
      key: const Key('extract-persistent-audio'),
      onPressed: _busy || _selected == null
          ? null
          : () => _edit(() {
              final c = _clips.singleWhere((c) => c['id'] == _selected),
                  asset = (_project.toJson()['assets'] as List).singleWhere(
                    (a) => a['id'] == c['source']['id'],
                  );
              final streams = (asset['streams'] as List)
                  .where((s) => s['type'] == 'audio')
                  .toList();
              if (streams.length != 1) {
                throw const StudioException('AUDIO_STREAM_SELECTION_REQUIRED');
              }
              _includeEmbeddedAudio = false;
              return ExtractAudioClip(
                _selected!,
                streams.single['id'] as String,
              );
            }),
      child: const Text(
        'Create persistent AUDIO clip + explicit AV link from selected video',
      ),
    ),
    OutlinedButton(
      key: const Key('unlink-persistent-audio'),
      onPressed: _busy || _selected == null
          ? null
          : () => _edit(() {
              final c = _clips.singleWhere((c) => c['id'] == _selected);
              if (c['linkGroupId'] == null) {
                throw const StudioException('LINK_GROUP_NOT_FOUND');
              }
              return UnlinkAudioVideo(c['linkGroupId'] as String);
            }),
      child: const Text('Unlink selected pair (keep BOTH clips)'),
    ),
    for (final t in _project.toJson()['sequences'][0]['tracks'] as List)
      if (t['kind'] == 'audio')
        CheckboxListTile(
          key: Key('audio-track-mute-${t['id']}'),
          value: t['muted'] as bool,
          onChanged: _busy
              ? null
              : (v) => _edit(
                  () => SetAudioTrackState(
                    t['id'] as String,
                    muted: v ?? false,
                    solo: t['solo'] as bool,
                  ),
                ),
          title: const Text('Persisted AUDIO track mute'),
        ),
    _path(
      'dissolve-before',
      'VIDEO dissolve before cut (project frames)',
      _dissolveBefore,
    ),
    _path(
      'dissolve-after',
      'VIDEO dissolve after cut (project frames)',
      _dissolveAfter,
    ),
    OutlinedButton(
      key: const Key('set-dissolve'),
      onPressed: _busy || _selected == null
          ? null
          : () => _act(() {
              final seq = _project.toJson()['sequences'][0],
                  fps = FrameRate(seq['frameRate']['n'], seq['frameRate']['d']);
              final left = _clips.singleWhere((c) => c['id'] == _selected);
              final cut =
                  Q.fromJson(left['timelineRange']['start']) +
                  Q.fromJson(left['timelineRange']['duration']);
              final right = _clips
                  .where(
                    (c) =>
                        c['source'] != null &&
                        Q.fromJson(c['timelineRange']['start']) == cut,
                  )
                  .toList();
              if (right.length != 1) {
                throw const StudioException('TRANSITION_NOT_ADJACENT');
              }
              final p = int.tryParse(_dissolveBefore.text),
                  q = int.tryParse(_dissolveAfter.text);
              if (p == null || q == null) {
                throw const StudioException('TRANSITION_RANGE');
              }
              return widget.workspace.setDissolve(
                _selected!,
                right.single['id'] as String,
                fps.frameTime(BigInt.from(p)),
                fps.frameTime(BigInt.from(q)),
                expectedRevision: _project.revision,
              );
            }),
      child: const Text(
        'Dissolve selected LEFT → next; reject missing handles (VIDEO only)',
      ),
    ),
    OutlinedButton(
      key: const Key('remove-dissolve'),
      onPressed: _busy || _selected == null
          ? null
          : () => _act(() {
              final found = (_project.toJson()['transitions'] as List)
                  .where((t) => t['leftClipId'] == _selected)
                  .toList();
              if (found.length != 1) throw const StudioException('NOT_FOUND');
              return widget.workspace.removeDissolve(
                found.single['id'] as String,
                expectedRevision: _project.revision,
              );
            }),
      child: const Text(
        'Remove selected LEFT transition (undoable; edit ranges afterwards)',
      ),
    ),
    _path('transform-x', 'Transform translate X (canvas pixels)', _tx),
    _path('transform-y', 'Transform translate Y (canvas pixels)', _ty),
    _path('transform-scale', 'Transform uniform scale (0,100]', _scale),
    _path(
      'transform-rotation',
      'Transform clockwise degrees; source-center anchor',
      _rotation,
    ),
    OutlinedButton(
      key: const Key('apply-clip-transform'),
      onPressed: _busy || _selected == null
          ? null
          : () => _act(() {
              double read(TextEditingController c) {
                final n = double.tryParse(c.text);
                if (n == null || !n.isFinite) {
                  throw const StudioException(
                    'TRANSFORM_PARAMETERS_UNSUPPORTED',
                  );
                }
                return n;
              }

              return widget.workspace.setClipTransform(_selected!, {
                ...identityTransform2d,
                'translateX': read(_tx),
                'translateY': read(_ty),
                'scaleX': read(_scale),
                'scaleY': read(_scale),
                'rotationDeg': read(_rotation),
              }, expectedRevision: _project.revision);
            }),
      child: const Text('Apply persisted transform (static, bilinear CPU)'),
    ),
    const Text(
      'Crop: original-source normalized edges, half-open pixel-area coverage; no canvas resize. Colour: linear709 exposure → contrast → saturation before opacity/dissolve.',
    ),
    for (final e in _rasterInputs.entries) _path(e.key, e.key, e.value),
    for (final type in ['crop', 'colorBasic'])
      OutlinedButton(
        key: Key('apply-$type'),
        onPressed: _busy || _selected == null
            ? null
            : () => _act(() {
                final defaults = type == 'crop'
                    ? identityCrop
                    : identityColorBasic;
                final params = <String, double>{};
                for (final k in defaults.keys) {
                  final value = double.tryParse(
                    _rasterInputs['${type == 'crop' ? 'crop' : 'color'}-$k']!
                        .text,
                  );
                  if (value == null || !value.isFinite) {
                    throw const StudioException(
                      'RASTER_PARAMETERS_UNSUPPORTED',
                    );
                  }
                  params[k] = value;
                }
                return type == 'crop'
                    ? widget.workspace.setClipCrop(
                        _selected!,
                        params,
                        expectedRevision: _project.revision,
                      )
                    : widget.workspace.setClipColorBasic(
                        _selected!,
                        params,
                        expectedRevision: _project.revision,
                      );
              }),
        child: Text('Apply persisted $type (static CPU)'),
      ),
    _path(
      'clip-opacity-value',
      'Selected VIDEO opacity [0,1], linear Rec.709 over black',
      _opacity,
    ),
    _buildGestureControls(),
    OutlinedButton(
      key: const Key('apply-clip-opacity'),
      onPressed: _busy || _selected == null
          ? null
          : () => _act(() {
              final value = double.tryParse(_opacity.text);
              if (value == null) throw const StudioException('OPACITY_RANGE');
              return widget.workspace.setClipOpacity(
                _selected!,
                value,
                expectedRevision: _project.revision,
              );
            }),
      child: const Text('Apply persisted clip opacity'),
    ),
    _path(
      'opacity-keyframe-frame',
      'Clip-local project frame (0..duration endpoint)',
      _opacityFrame,
    ),
    CheckboxListTile(
      key: const Key('opacity-keyframe-hold'),
      value: _opacityHold,
      onChanged: _busy
          ? null
          : (v) => setState(() => _opacityHold = v ?? false),
      title: const Text('Hold until next key (otherwise linear)'),
    ),
    OutlinedButton(
      key: const Key('set-opacity-keyframe'),
      onPressed: _busy || _selected == null
          ? null
          : () => _act(() {
              final frame = int.tryParse(_opacityFrame.text),
                  value = double.tryParse(_opacity.text);
              if (frame == null || value == null) {
                throw const StudioException('INVALID_KEYFRAME');
              }
              final fps = _project.toJson()['sequences'][0]['frameRate'];
              return widget.workspace.setOpacityKeyframe(
                _selected!,
                FrameRate(fps['n'], fps['d']).frameTime(BigInt.from(frame)),
                value,
                interpolation: _opacityHold ? 'hold' : 'linear',
                expectedRevision: _project.revision,
              );
            }),
      child: const Text('Set / replace opacity keyframe (atomic undo)'),
    ),
    OutlinedButton(
      key: const Key('remove-opacity-keyframe'),
      onPressed: _busy || _selected == null
          ? null
          : () => _act(() {
              final frame = int.tryParse(_opacityFrame.text);
              if (frame == null) {
                throw const StudioException('INVALID_KEYFRAME');
              }
              final fps = _project.toJson()['sequences'][0]['frameRate'];
              return widget.workspace.removeOpacityKeyframe(
                _selected!,
                FrameRate(fps['n'], fps['d']).frameTime(BigInt.from(frame)),
                expectedRevision: _project.revision,
              );
            }),
      child: const Text('Remove opacity keyframe at this local frame'),
    ),
    OutlinedButton(
      key: const Key('preview-clip-opacity'),
      onPressed: _busy || _selected == null
          ? null
          : () => _run(() async {
              final snapshot = _project.hash, selected = _selected;
              final clip = _clips.singleWhere((c) => c['id'] == selected);
              final fps = _project.toJson()['sequences'][0]['frameRate'];
              final local = FrameRate(
                fps['n'],
                fps['d'],
              ).frameTime(BigInt.parse(_opacityFrame.text));
              if (local < Q.of(0) ||
                  local >= Q.fromJson(clip['timelineRange']['duration'])) {
                throw const StudioException('KEYFRAME_ENDPOINT_NOT_RENDERED');
              }
              final frame = await widget.workspace.previewTimelineAt(
                Q.fromJson(clip['timelineRange']['start']) + local,
              );
              final decoded = Completer<ui.Image>();
              var abandoned = false;
              ui.decodeImageFromPixels(
                frame.rgba,
                frame.width,
                frame.height,
                ui.PixelFormat.rgba8888,
                (image) {
                  if (abandoned) {
                    image.dispose();
                  } else {
                    decoded.complete(image);
                  }
                },
              );
              final image = await decoded.future.timeout(
                const Duration(seconds: 2),
                onTimeout: () {
                  abandoned = true;
                  throw const StudioException('TIMELINE_IMAGE_DECODE_TIMEOUT');
                },
              );
              if (!mounted ||
                  widget.workspace.current.hash != snapshot ||
                  selected != _selected) {
                image.dispose();
                throw const StudioException('TIMELINE_FRAME_STALE');
              }
              _previewImage?.dispose();
              _previewImage = image;
              return 'Same-revision CPU transform/opacity preview; originals -> actual YUV420 encoder-input node -> display. Not GPU/physical sync qualification.';
            }),
      child: const Text('Preview selected timeline clip effect'),
    ),
    _PointerTimeline(
      workspace: widget.workspace,
      document: _project,
      selection: _multiSelection,
      collisionMode: _collisionMode,
      includeLinks: !_ignoreLinksThisMove,
      blocked: _busy || _gesture != null || _multiGesture != null,
      onSelection: (ids) => setState(() {
        _multiSelection.clear();
        _multiSelection.addAll(ids);
      }),
      onActive: (active) {
        if (mounted) {
          setState(() {
            _pointerActive = active;
            if (!active && _project.hash != widget.workspace.current.hash) {
              _refresh();
            }
          });
        }
      },
      onCommitted: () => setState(() {
        _refresh();
        _error = null;
      }),
    ),
    _buildMultiMoveControls(),
    _buildCollisionModeControls(),
    _buildClipboardControls(),
    for (final c in _clips)
      ListTile(
        key: Key('clip-${c['id']}'),
        selected: _selected == c['id'],
        title: Text(c['name'] as String),
        subtitle: Text(
          'Start ${Q.fromJson(c['timelineRange']['start'])} · duration ${Q.fromJson(c['timelineRange']['duration'])}',
        ),
        onTap: _busy
            ? null
            : () => setState(() {
                if (_selected != c['id']) {
                  _cancelGestureUi();
                  _cancelMultiMoveUi();
                  _clearPreview();
                }
                _selected = c['id'] as String;
              }),
      ),
    _path(
      'preview-time-ms',
      'Source thumbnail time ms from FIRST source PTS (not timeline position)',
      _previewTime,
    ),
    OutlinedButton(
      key: const Key('seek-source-frame'),
      onPressed: _busy || _selected == null
          ? null
          : () => _run(() async {
              final ms = int.tryParse(_previewTime.text);
              if (ms == null || ms < 0) {
                throw const StudioException('PREVIEW_TIME_INVALID');
              }
              final selection = _selected,
                  projectHash = widget.workspace.current.hash;
              final clip = _clips.singleWhere((c) => c['id'] == selection);
              final frame = await widget.workspace.previewAssetSource(
                clip['source']['id'] as String,
                Q.of(ms, 1000),
              );
              final decoded = Completer<ui.Image>();
              ui.decodeImageFromPixels(
                frame.rgba,
                frame.width,
                frame.height,
                ui.PixelFormat.rgba8888,
                decoded.complete,
              );
              final image = await decoded.future;
              if (!mounted ||
                  selection != _selected ||
                  widget.workspace.current.hash != projectHash) {
                image.dispose();
                throw const StudioException('PREVIEW_SUPERSEDED');
              }
              _previewImage?.dispose();
              _previewImage = image;
              return 'Indexed source thumbnail PTS ${frame.pts}; retained pixel cache ${widget.workspace.sourcePreviewCache.bytes} bytes. Not timeline/effect preview.';
            }),
      child: const Text('Seek selected source + show thumbnail'),
    ),
    if (_previewImage != null)
      RawImage(
        key: const Key('source-preview'),
        image: _previewImage,
        width: 256,
        height: 144,
        fit: BoxFit.contain,
      ),
    _path(
      'edit-frames',
      'Positive frames (split: local offset; trim: remove from out; move: timeline shift)',
      _frames,
    ),
    Wrap(
      spacing: 12,
      children: [
        OutlinedButton(
          key: const Key('split'),
          onPressed: _busy || _selected == null
              ? null
              : () => _edit(() {
                  final c = _clips.singleWhere((c) => c['id'] == _selected);
                  return SplitClip(
                    _selected!,
                    Q.fromJson(c['timelineRange']['start']) + _delta(),
                    widget.workspace.newEntityId(),
                  );
                }),
          child: const Text('Split'),
        ),
        OutlinedButton(
          key: const Key('move'),
          onPressed: _busy || _selected == null
              ? null
              : () => _edit(() => MoveClip(_selected!, _delta())),
          child: const Text('Move'),
        ),
        OutlinedButton(
          key: const Key('trim'),
          onPressed: _busy || _selected == null
              ? null
              : () => _edit(
                  () => TrimClip(
                    _selected!,
                    'out',
                    Q.of(0) - _delta(),
                    ripple: !_hasPersistentAudio,
                  ),
                ),
          child: Text(
            _hasPersistentAudio ? 'Trim out (leave gap)' : 'Ripple trim out',
          ),
        ),
        OutlinedButton(
          key: const Key('delete'),
          onPressed: _busy || _selected == null
              ? null
              : () => _edit(
                  () => DeleteClip(_selected!, ripple: !_hasPersistentAudio),
                ),
          child: Text(
            _hasPersistentAudio ? 'Delete (leave gap)' : 'Ripple delete',
          ),
        ),
        OutlinedButton(
          key: const Key('ripple-delete'),
          onPressed: _busy || (_selected == null && _multiSelection.isEmpty)
              ? null
              : () => _edit(
                  () => RippleDeleteClips(
                    _multiSelection.isNotEmpty ? _multiSelection : [_selected!],
                  ),
                ),
          child: const Text('Ripple delete range'),
        ),
        OutlinedButton(
          key: const Key('ripple-trim'),
          onPressed: _busy || _selected == null
              ? null
              : () => _edit(
                  () => RippleTrimClip(_selected!, 'out', Q.of(0) - _delta()),
                ),
          child: const Text('Ripple trim out'),
        ),
        OutlinedButton(
          key: const Key('ripple-trim-in'),
          onPressed: _busy || _selected == null
              ? null
              : () => _edit(() => RippleTrimClip(_selected!, 'in', _delta())),
          child: const Text('Ripple trim in'),
        ),
        OutlinedButton(
          key: const Key('ripple-trim-out-lengthen'),
          onPressed: _busy || _selected == null
              ? null
              : () => _edit(() => RippleTrimClip(_selected!, 'out', _delta())),
          child: const Text('Ripple trim out lengthen'),
        ),
        OutlinedButton(
          key: const Key('ripple-trim-in-lengthen'),
          onPressed: _busy || _selected == null
              ? null
              : () => _edit(
                  () => RippleTrimClip(_selected!, 'in', Q.of(0) - _delta()),
                ),
          child: const Text('Ripple trim in lengthen'),
        ),
        OutlinedButton(
          key: const Key('slip'),
          onPressed: _busy || _selected == null
              ? null
              : () => _edit(() => SlipClip(_selected!, _delta())),
          child: const Text('Slip'),
        ),
        OutlinedButton(
          key: const Key('roll'),
          onPressed: _busy || _selected == null ? null : () => _edit(_rollCut),
          child: const Text('Roll'),
        ),
        TextField(
          key: const Key('ripple-close-start'),
          controller: _rippleCloseStart,
          decoration: const InputDecoration(
            labelText: 'Ripple close range start seconds',
          ),
        ),
        TextField(
          key: const Key('ripple-close-duration'),
          controller: _rippleCloseDuration,
          decoration: const InputDecoration(
            labelText: 'Ripple close range duration seconds',
          ),
        ),
        OutlinedButton(
          key: const Key('ripple-close-range'),
          onPressed: _busy
              ? null
              : () => _edit(
                  () => RippleDeleteClips(
                    const [],
                    range: TimeRange(
                      _snapDecimal(_rippleCloseStart.text.trim()),
                      _snapDecimal(_rippleCloseDuration.text.trim()),
                    ),
                  ),
                ),
          child: const Text('Ripple close range'),
        ),
      ],
    ),
    ExpansionTile(
      key: const Key('history-retention-panel'),
      title: const Text(
        'Recovery checkpoint retention (explicit, preserveAll default)',
      ),
      children: [
        const Text(
          'Only old recovery-checkpoint index rows can be pruned. ALL undo commands, revisions, snapshots, blob pins, originals and CAS files remain. No disk bytes reclaimed or history eviction promised. Named versions, saves, current/latest recovery points and session project history are protected.',
        ),
        TextField(
          key: const Key('checkpoint-name'),
          controller: _historyName,
          decoration: const InputDecoration(
            labelText: 'Permanent named checkpoint (unique, no overwrite)',
          ),
        ),
        OutlinedButton(
          key: const Key('name-checkpoint'),
          onPressed: _busy
              ? null
              : () => _run(() async {
                  await widget.workspace.nameCurrentCheckpoint(
                    _historyName.text,
                    expectedRevision: widget.workspace.current.revision,
                  );
                  _historyReview = null;
                  _historyConsent = false;
                  return 'Named checkpoint pinned; no overwrite or removal.';
                }),
          child: const Text('Pin named version'),
        ),
        TextField(
          key: const Key('history-keep'),
          controller: _historyKeep,
          decoration: const InputDecoration(
            labelText:
                'Keep latest recovery checkpoints: 1–10000; blank preserveAll',
          ),
          onChanged: (_) => setState(() {
            _historyReview = null;
            _historyConsent = false;
          }),
        ),
        OutlinedButton(
          key: const Key('configure-history-retention'),
          onPressed: _busy
              ? null
              : () => _run(() async {
                  final text = _historyKeep.text;
                  final value = text.isEmpty ? null : int.tryParse(text);
                  if (text.isNotEmpty &&
                      (value == null ||
                          !RegExp(r'^[1-9][0-9]{0,4}$').hasMatch(text))) {
                    throw const StudioException('RETENTION_POLICY_INVALID');
                  }
                  await widget.workspace.configureCheckpointRetention(
                    value,
                    confirmed: true,
                  );
                  _historyReview = null;
                  _historyConsent = false;
                  _historyStatus = 'Policy configured explicitly. Nothing deleted. Run dry-run before confirmation.';
                  return _historyStatus;
                }),
          child: const Text('Explicitly configure policy (no deletion)'),
        ),
        OutlinedButton(
          key: const Key('review-history-retention'),
          onPressed: _busy
              ? null
              : () => _run(() async {
                  final review = await widget.workspace
                      .reviewCheckpointRetention();
                  _historyReview = review;
                  _historyConsent = false;
                  final candidates = review['candidates'] as List;
                  _historyStatus =
                      'Policy ${review['policy']}; named versions (first20): ${(review['labels'] as List).take(20).map((l) => l['name']).join(', ')}; remove ${candidates.length} checkpoint INDEX rows; first20 IDs: ${candidates.take(20).join(', ')}; review ${review['reviewHash']}. All snapshots/pins/files remain.';
                  return 'Read-only retention review ready.';
                }),
          child: const Text('Dry-run checkpoint retention'),
        ),
        Text(_historyStatus, key: const Key('history-retention-review')),
        CheckboxListTile(
          key: const Key('confirm-history-retention'),
          value: _historyConsent,
          onChanged: _busy || _historyReview == null
              ? null
              : (v) => setState(() => _historyConsent = v == true),
          title: const Text(
            'Apply exactly this reviewed checkpoint-index removal; preserve all resource/history pins.',
          ),
        ),
        OutlinedButton(
          key: const Key('apply-history-retention'),
          onPressed: _busy || !_historyConsent || _historyReview == null
              ? null
              : () => _run(() async {
                  final review = _historyReview!;
                  // Consume consent even when the transaction refuses stale review.
                  _historyReview = null;
                  _historyConsent = false;
                  final audit = await widget.workspace.applyCheckpointRetention(
                    reviewHash: review['reviewHash'],
                    expectedRevision: BigInt.parse(review['revision']),
                    confirmed: true,
                  );
                  _historyStatus =
                      'Audited checkpoint index removal: ${(audit['removedCheckpointIds'] as List).length}; ${audit['reviewHash']}. No snapshots/pins/files removed.';
                  return _historyStatus;
                }),
          child: const Text('Apply reviewed checkpoint retention'),
        ),
      ],
    ),
    OutlinedButton(
      key: const Key('history-retention-audits'),
      onPressed: _busy
          ? null
          : () => _act(() {
              final receipts = widget.workspace
                  .checkpointRetentionAuditHistory();
              _historyStatus =
                  'Recent20 local prune audit receipts: ${receipts.map((a) => '${a['reviewHash']}: ${(a['removedCheckpointIds'] as List).length} checkpoint index rows').join('; ')}. No files removed.';
              return widget.workspace.current;
            }),
      child: const Text('Read recent retention audit receipts'),
    ),
    ExpansionTile(
      key: const Key('storage-budget-panel'),
      title: const Text('Namespace storage budget (keep all history)'),
      children: [
        const Text(
          'Logical regular-file bytes in namespace CAS only: includes originals, derived, stages and metadata; excludes DB, archives/exports, filesystem allocation and volume free space. No automatic history deletion. Legacy/shared ownership refuses policy changes.',
        ),
        Text(_storageView, key: const Key('storage-inventory')),
        OutlinedButton(
          key: const Key('refresh-storage-inventory'),
          onPressed: _busy
              ? null
              : () => _act(() {
                  final view = widget.workspace.namespaceStorageInventory();
                  _storageView =
                      '${view['fileBytes']} namespace file bytes; ${view['entries']} entries; policy ${view['policy']}';
                  return widget.workspace.current;
                }),
          child: const Text('Inventory namespace (read-only)'),
        ),
        TextField(
          key: const Key('storage-byte-limit'),
          controller: _diskLimit,
          decoration: const InputDecoration(
            labelText: 'CAS byte limit as decimal bytes; blank means unlimited',
          ),
          onChanged: (_) => setState(() => _diskConsent = null),
        ),
        CheckboxListTile(
          key: const Key('confirm-storage-policy'),
          value: _diskConsent == _diskLimit.text,
          onChanged: _busy
              ? null
              : (value) => setState(
                  () => _diskConsent = value == true ? _diskLimit.text : null,
                ),
          title: const Text(
            'Apply this byte budget; preserve ALL history and originals. No deletion, no upload.',
          ),
        ),
        OutlinedButton(
          key: const Key('apply-storage-policy'),
          onPressed: _busy || _diskConsent != _diskLimit.text
              ? null
              : () => _run(() async {
                  final view = await widget.workspace
                      .configureNamespaceDiskBudget(
                        _diskLimit.text.isEmpty ? null : _diskLimit.text,
                        confirmed: true,
                      );
                  _diskConsent = null;
                  _storageView =
                      '${view['fileBytes']} namespace file bytes; policy ${view['policy']}';
                  return 'Namespace byte budget applied; all history/originals preserved.';
                }),
          child: const Text('Apply namespace byte budget (no deletion)'),
        ),
      ],
    ),
    OutlinedButton(
      key: const Key('build-timeline-proxies'),
      onPressed: _busy
          ? null
          : () => _run(() async {
              final facts = await widget.workspace
                  .buildTimelinePreviewProxies();
              _clearTimelineVideo();
              _timelineEnabled = true;
              return 'Preview proxies ${facts['proxies']} (${facts['bytes']} bytes): built ${facts['built']}, reused ${facts['reused']}; persisted in CAS; export uses originals.';
            }),
      child: const Text('Build timeline video preview proxies'),
    ),
    Wrap(
      children: [
        OutlinedButton(
          key: const Key('cancel-timeline-proxies'),
          onPressed: widget.workspace.cancelPreviewProxyBuild,
          child: const Text('Cancel proxy build'),
        ),
        OutlinedButton(
          key: const Key('clear-timeline-proxies'),
          onPressed: () => setState(() {
            _clearTimelineVideo();
            widget.workspace.clearPreviewProxies();
          }),
          child: const Text('Clear memory cache only (keep persisted proxies)'),
        ),
      ],
    ),
    CheckboxListTile(
      key: const Key('confirm-repair-proxy'),
      value:
          _selected != null &&
          _proxyRepairConsent == '${_project.hash}:$_selected',
      onChanged: _busy || _selected == null
          ? null
          : (v) => setState(
              () => _proxyRepairConsent = v == true
                  ? '${_project.hash}:$_selected'
                  : null,
            ),
      title: const Text(
        'Repair corrupt/missing selected preview CAS from verified originals. Only identical expected hashes and exclusive project ownership; never originals or shared objects. Keep history; durable repair audit remains.',
      ),
    ),
    OutlinedButton(
      key: const Key('repair-selected-proxy'),
      onPressed:
          _busy ||
              _selected == null ||
              _proxyRepairConsent != '${_project.hash}:$_selected'
          ? null
          : () => _run(() async {
              final clip = _clips.singleWhere((c) => c['id'] == _selected);
              final result = await widget.workspace
                  .repairTimelinePreviewProxies(
                    assetId: clip['source']['id'] as String,
                    expectedRevision: _project.revision,
                    confirmed: true,
                  );
              _proxyRepairConsent = null;
              return 'Verified repair: ${result['replaced']} corrupt/missing objects restored; audit ${result['audit']}. History retained.';
            }),
      child: const Text('Repair selected preview CAS (source-qualified)'),
    ),
    CheckboxListTile(
      key: const Key('confirm-discard-proxy'),
      value:
          _selected != null &&
          _proxyDiscardConsent == '${_project.hash}:$_selected',
      onChanged: _busy || _selected == null
          ? null
          : (v) => setState(
              () => _proxyDiscardConsent = v == true
                  ? '${_project.hash}:$_selected'
                  : null,
            ),
      title: const Text(
        'Detach selected asset preview references from current revision only. Keep originals, all CAS bytes and undo/history pins. Missing proxies can be rebuilt; corrupt hash collisions still fail closed.',
      ),
    ),
    OutlinedButton(
      key: const Key('discard-selected-proxy'),
      onPressed:
          _busy ||
              _selected == null ||
              _proxyDiscardConsent != '${_project.hash}:$_selected'
          ? null
          : () => _act(() {
              final clip = _clips.singleWhere((c) => c['id'] == _selected);
              return widget.workspace.discardTimelinePreviewProxies(
                assetId: clip['source']['id'] as String,
                expectedRevision: _project.revision,
                confirmed: true,
              );
            }),
      child: const Text(
        'Detach selected asset preview references (no file deletion)',
      ),
    ),
    CheckboxListTile(
      key: const Key('timeline-video-enabled'),
      value: _timelineEnabled,
      onChanged: (v) => setState(() {
        _clearTimelineVideo();
        _timelineEnabled = v ?? false;
      }),
      title: const Text(
        'Audio-service-clock video preview (RGBA128, single admitted video track; not physical AV qualification)',
      ),
    ),
    ValueListenableBuilder<int>(
      valueListenable: _videoPulse,
      builder: (_, _, _) => Column(
        children: [
          if (_timelineEnabled)
            SizedBox(
              width: 384,
              height: 216,
              child: _timelineImage != null
                  ? RawImage(
                      key: const Key('timeline-preview'),
                      image: _timelineImage,
                      fit: BoxFit.contain,
                    )
                  : const ColoredBox(
                      color: Color(0xff000000),
                      child: Center(
                        child: Text(
                          'Waiting for confirmed AudioSink clock / proxy frame',
                        ),
                      ),
                    ),
            ),
          Text(
            'Video delivered $_timelineDelivered · committed $_timelineCommitted · stale dropped $_timelineDropped · source skipped $_timelineSkippedSourceFrames · late commits $_timelineLateCommits · sample ${_timelineFrame?.clockSample ?? "none"} · epoch ${_timelineFrame?.clockEpoch ?? "none"} · clip ${_timelineFrame?.clipId ?? "none"}',
            key: const Key('timeline-video-status'),
          ),
        ],
      ),
    ),
    const Text(
      'Bounded pre-rendered PCM · local PulseAudio service · optional derived video preview; not physical hearing or AV-sync qualification.',
    ),
    Wrap(
      spacing: 8,
      children: [
        FilledButton(
          key: const Key('play-timeline'),
          onPressed: _busy
              ? null
              : () => _run(() async {
                  await widget.workspace.playTimeline(
                    sink: _playbackSink.text.isEmpty
                        ? null
                        : _playbackSink.text,
                  );
                  _pollPlayback();
                  return 'Audio timeline prepared; waiting for confirmed service clock.';
                }),
          child: const Text('Play audio timeline'),
        ),
        OutlinedButton(
          key: const Key('pause-timeline'),
          onPressed: () => _playbackControl('pause'),
          child: const Text('Pause'),
        ),
        OutlinedButton(
          key: const Key('resume-timeline'),
          onPressed: () => _playbackControl('resume'),
          child: const Text('Resume'),
        ),
        OutlinedButton(
          key: const Key('stop-timeline'),
          onPressed: () {
            widget.workspace.stopTimelinePlayback();
            _pollPlayback();
          },
          child: const Text('Stop'),
        ),
      ],
    ),
    _path(
      'timeline-seek-ms',
      'Audio timeline seek milliseconds (exact48k grid)',
      _playbackSeek,
    ),
    OutlinedButton(
      key: const Key('seek-timeline'),
      onPressed: () {
        final ms = int.tryParse(_playbackSeek.text);
        if (ms == null || ms < 0) {
          setState(() => _error = 'PLAYBACK_RANGE');
          return;
        }
        _playbackControl('seek', sample: ms * 48);
      },
      child: const Text('Seek audio timeline'),
    ),
    _path(
      'timeline-sink',
      'Explicit local PulseAudio sink name (blank default)',
      _playbackSink,
    ),
    OutlinedButton(
      key: const Key('rebind-timeline'),
      onPressed: () => _playbackControl('rebind'),
      child: const Text('Rebind local audio device'),
    ),
    ValueListenableBuilder<int>(
      valueListenable: _videoPulse,
      builder: (_, _, _) => Text(
        'Audio ${_playback['state']} · confirmed sample ${_playback['presentedSample'] ?? 0}/48000 · clock ${_playback['clockValid'] ?? false} · epoch ${_playback['epoch'] ?? 0} · ${_playback['reason'] ?? ''}',
        key: const Key('timeline-audio-clock'),
      ),
    ),
    _path(
      'archive-path',
      'Local .studio-project path (save overwrites; restore creates fork)',
      _archive,
    ),
    Wrap(
      spacing: 12,
      children: [
        FilledButton(
          key: const Key('save-archive'),
          onPressed: _busy ? null : () => _run(_saveArchive),
          child: const Text('Save archive'),
        ),
        OutlinedButton(
          key: const Key('restore-archive'),
          onPressed: _busy
              ? null
              : () => _run(() async {
                  await widget.workspace.restoreArchive(
                    LocalFileGrant.fromUserSelection(File(_archive.text)),
                  );
                  return 'Archive verified and restored as new project; original preserved.';
                }),
          child: const Text('Restore as fork'),
        ),
      ],
    ),
    OutlinedButton(
      key: const Key('cancel-save'),
      onPressed: _saving == null
          ? null
          : () => setState(() => _status = _saving!.cancel()),
      child: const Text('Cancel archive before publication'),
    ),
    for (final op in widget.workspace.pendingSaves)
      ListTile(
        title: Text(
          'Interrupted save ${op['state']} · revision ${op['revision']}',
        ),
        subtitle: const Text(
          'Select the ORIGINAL archive path above to verify publication. No automatic overwrite or journal-path authorization.',
        ),
        trailing: OutlinedButton(
          key: Key('reconcile-${op['id']}'),
          onPressed: _busy || !['publishing', 'uncertain'].contains(op['state'])
              ? null
              : () => _run(() async {
                  final receipt = await widget.workspace.reconcileSave(
                    op['id'] as String,
                    LocalFileGrant.fromUserSelection(File(_archive.text)),
                  );
                  return 'Verified interrupted publication ${receipt.snapshot.revision}; no overwrite.';
                }),
          child: const Text('Verify selected archive'),
        ),
      ),
    const Text(
      'Offline48k stereo via Dart AudioBus + AAC. Persisted AudioClips export automatically; the legacy embedded option below is NOT an AudioClip link. No device playback clock.',
    ),
    _path('master-gain-db', 'Persisted master gain dB [-96,12]', _masterGain),
    OutlinedButton(
      key: const Key('save-master-audio'),
      onPressed: _busy
          ? null
          : () => _act(() {
              final gain = double.tryParse(_masterGain.text);
              if (gain == null || !gain.isFinite) {
                throw const StudioException('AUDIO_PARAMETER_RANGE');
              }
              final b = _project.toJson()['audioBuses'][0];
              return widget.workspace.setMasterAudio(
                gainDb: gain,
                pan: (b['pan'] as num).toDouble(),
                muted: b['muted'] as bool,
                solo: b['solo'] as bool,
                expectedRevision: _project.revision,
              );
            }),
      child: const Text('Save master audio gain'),
    ),
    CheckboxListTile(
      key: const Key('master-audio-mute'),
      value: _project.toJson()['audioBuses'][0]['muted'] as bool,
      onChanged: _busy
          ? null
          : (v) => _act(() {
              final b = _project.toJson()['audioBuses'][0];
              return widget.workspace.setMasterAudio(
                gainDb: (b['gainDb'] as num).toDouble(),
                pan: (b['pan'] as num).toDouble(),
                muted: v ?? false,
                solo: b['solo'] as bool,
                expectedRevision: _project.revision,
              );
            }),
      title: const Text('Persisted master mute'),
    ),
    CheckboxListTile(
      key: const Key('export-embedded-audio'),
      value: _includeEmbeddedAudio,
      onChanged:
          _busy ||
              (_project.toJson()['sequences'][0]['tracks'] as List).any(
                (t) =>
                    t['kind'] == 'audio' &&
                    (t['items'] as List).any((c) => c['source'] != null),
              )
          ? null
          : (v) => setState(() => _includeEmbeddedAudio = v ?? false),
      title: const Text(
        'Explicitly include embedded audio of selected video clips in THIS export (not restored automatically)',
      ),
    ),
    _path(
      'export-path',
      'Local .mp4 destination (overwrites atomically on success)',
      _output,
    ),
    Wrap(
      spacing: 12,
      children: [
        FilledButton(
          key: const Key('export-video'),
          onPressed: _busy
              ? null
              : () => _run(() async {
                  final receipt = await widget.workspace.exportVideo(
                    File(_output.text),
                    includeEmbeddedAudio: _includeEmbeddedAudio,
                  );
                  return 'MP4 exported from frozen revision ${receipt['revision']} · ${receipt['frames']} frames · ${receipt['audio']}';
                }),
          child: const Text('Export MP4'),
        ),
        OutlinedButton(
          key: const Key('cancel-export'),
          onPressed: _busy ? widget.workspace.cancelExport : null,
          child: const Text('Cancel export'),
        ),
      ],
    ),
    Text(_status, key: const Key('operation-status')),
  ];

  List<TimelineMarker> get _markers => (_project.toJson()['markers'] as List)
      .map((m) => TimelineMarker.fromJson(m as Map<String, dynamic>))
      .toList();
  Q _markerMilliseconds(TextEditingController field) {
    final n = int.tryParse(field.text.trim());
    if (n == null || n < 0) {
      throw const StudioException('INVALID_RANGE');
    }
    return Q.of(n, 1000);
  }

  String _markerMillisecondsText(Q time) =>
      (time.n * BigInt.from(1000) ~/ time.d).toString();

  void _setMarkers(
    List<TimelineMarker> Function(List<TimelineMarker>) change,
  ) => _edit(() => SetMarkers(MarkerStore(change(_markers))));

  List<Widget> _markerControls() => [
    const Divider(),
    const Text(
      'Sequence markers · metadata only · never burned into preview or MP4',
      style: TextStyle(fontSize: 20),
    ),
    _path('marker-label', 'Marker label', _markerLabel),
    _path(
      'marker-time',
      'Marker time (milliseconds on the sequence, not frames)',
      _markerTime,
    ),
    _path(
      'marker-duration',
      'Marker duration (milliseconds, 0 is a point)',
      _markerDuration,
    ),
    CheckboxListTile(
      key: const Key('marker-ripple'),
      value: _markerRipple,
      title: const Text(
        'Ripple this marker with interval edits (absolute markers only; off keeps later markers put)',
      ),
      onChanged: _busy
          ? null
          : (v) => setState(() => _markerRipple = v ?? false),
    ),
    Wrap(
      spacing: 8,
      children: [
        OutlinedButton(
          key: const Key('marker-add'),
          onPressed: _busy
              ? null
              : () => _setMarkers(
                  (m) => [
                    ...m,
                    TimelineMarker(
                      'marker-${DateTime.now().microsecondsSinceEpoch}',
                      sequenceId: _project.toJson()['rootSequenceId'] as String,
                      label: _markerLabel.text,
                      time: _markerMilliseconds(_markerTime),
                      duration: _markerMilliseconds(_markerDuration),
                      ripple: _markerRipple,
                    ),
                  ],
                ),
          child: const Text('Add marker'),
        ),
        OutlinedButton(
          key: const Key('marker-add-anchored'),
          onPressed: _busy
              ? null
              : () => _setMarkers((m) {
                  final created = TimelineMarker(
                    'marker-${DateTime.now().microsecondsSinceEpoch}',
                    sequenceId: _project.toJson()['rootSequenceId'] as String,
                    label: _markerLabel.text,
                    time: _markerMilliseconds(_markerTime),
                    duration: _markerMilliseconds(_markerDuration),
                    ripple: _markerRipple,
                  );
                  final id = coveringMarkerHostClipId(
                    _project.toJson(),
                    created.time,
                    created.duration,
                  );
                  if (id == null) {
                    throw const StudioException('ANCHOR_OUT_OF_RANGE');
                  }
                  Map? host;
                  for (final t in _project.toJson()['sequences'][0]['tracks']) {
                    for (final item in t['items']) {
                      if (item['id'] == id) host = item as Map;
                    }
                  }
                  return [
                    ...m,
                    created.anchoredToClip(
                      id,
                      Q.fromJson(host!['timelineRange']['start']),
                      Q.fromJson(host['timelineRange']['duration']),
                    ),
                  ];
                }),
          child: const Text('Add marker on covering clip'),
        ),
        OutlinedButton(
          key: const Key('marker-edit'),
          onPressed: _busy || _markerSelected == null
              ? null
              : () => _setMarkers(
                  (m) => [
                    for (final marker in m)
                      if (marker.id == _markerSelected)
                        marker.edit(
                          label: _markerLabel.text,
                          time: _markerMilliseconds(_markerTime),
                          duration: _markerMilliseconds(_markerDuration),
                          ripple: _markerRipple,
                        )
                      else
                        marker,
                  ],
                ),
          child: const Text('Edit selected marker'),
        ),
        OutlinedButton(
          key: const Key('marker-delete'),
          onPressed: _busy || _markerSelected == null
              ? null
              : () => _setMarkers(
                  (m) => m.where((v) => v.id != _markerSelected).toList(),
                ),
          child: const Text('Delete selected marker'),
        ),
        OutlinedButton(
          key: const Key('marker-follow-clip'),
          onPressed: _busy || _markerSelected == null
              ? null
              : () => _setMarkers((markers) {
                  final selected = markers.singleWhere(
                    (m) => m.id == _markerSelected,
                  );
                  final id = coveringMarkerHostClipId(
                    _project.toJson(),
                    selected.time,
                    selected.duration,
                  );
                  if (id == null) {
                    throw const StudioException('ANCHOR_OUT_OF_RANGE');
                  }
                  Map? host;
                  for (final t in _project.toJson()['sequences'][0]['tracks']) {
                    for (final item in t['items']) {
                      if (item['id'] == id) host = item as Map;
                    }
                  }
                  return [
                    for (final marker in markers)
                      if (marker.id == _markerSelected)
                        marker.anchoredToClip(
                          id,
                          Q.fromJson(host!['timelineRange']['start']),
                          Q.fromJson(host['timelineRange']['duration']),
                        )
                      else
                        marker,
                  ];
                }),
          child: const Text('Anchor selected marker to covering clip'),
        ),
        OutlinedButton(
          key: const Key('marker-make-absolute'),
          onPressed: _busy || _markerSelected == null
              ? null
              : () => _setMarkers(
                  (m) => [
                    for (final marker in m)
                      if (marker.id == _markerSelected)
                        marker.makeAbsolute()
                      else
                        marker,
                  ],
                ),
          child: const Text('Make selected marker absolute'),
        ),
      ],
    ),
    for (final marker in _markers)
      OutlinedButton(
        key: Key('marker-${marker.id}'),
        onPressed: _busy
            ? null
            : () => setState(() {
                _markerSelected = marker.id;
                _markerLabel.text = marker.label;
                _markerTime.text = _markerMillisecondsText(marker.time);
                _markerDuration.text = _markerMillisecondsText(marker.duration);
                _markerRipple = marker.ripple;
              }),
        child: Text(
          marker.anchorKind == 'clipLocal'
              ? '${marker.label} · ${marker.time} · follows ${marker.anchorClipId}'
              : '${marker.label} · ${marker.time} · absolute · ripple ${marker.ripple}',
        ),
      ),
    const Text(
      'New markers are sequence-absolute and stay put unless Ripple this marker is on, or the marker is anchored to a covering clip and follows that host. A ripple or insert interval drops markers wholly inside a closed range (undo restores them) and shifts later ripple=true absolute markers; ripple=false later markers do not move. Insert-move still leaves a source gap. Marker labels are not burned into preview or export. Official workbench import/export uses only studio.markers.sidecar (.studio-markers.json): import replaces all project markers or refuses the whole file; unknown extra fields warn MARKER_SIDECAR_UNSUPPORTED and refuse; a clipLocal host that is missing or no longer covering is not rewritten as absolute. WebVTT chapters, CSV, FCPXML, and MP4 mux stay closed. Split/roll/slip/slide rebinding, new tracks, and auto-close-on-move stay closed.',
    ),
    _path(
      'marker-sidecar-path',
      'Official marker sidecar path (.studio-markers.json; import replaces all project markers; export overwrites atomically; never burned into MP4)',
      _markerSidecarPath,
    ),
    Wrap(
      spacing: 8,
      children: [
        OutlinedButton(
          key: const Key('marker-import-sidecar'),
          onPressed: _busy
              ? null
              : () => _run(() async {
                  final result = await widget.workspace.importMarkers(
                    LocalFileGrant.fromUserSelection(
                      File(_markerSidecarPath.text),
                    ),
                    expectedRevision: _project.revision,
                  );
                  return 'Imported ${result.markers!.markers.length} official markers; warnings: ${result.warnings.join(", ")}';
                }),
          child: const Text('Import official marker sidecar'),
        ),
        OutlinedButton(
          key: const Key('marker-export-sidecar'),
          onPressed: _busy
              ? null
              : () => _run(() async {
                  final r = widget.workspace.exportMarkers(
                    File(_markerSidecarPath.text),
                  );
                  return 'Official marker sidecar exported from revision $r';
                }),
          child: const Text('Export official marker sidecar'),
        ),
      ],
    ),
  ];

  List<CaptionCue> get _cues => (_project.toJson()['captions'] as List)
      .map((c) => CaptionCue.fromProjectJson(c as Map<String, dynamic>))
      .toList();
  Q _captionMilliseconds(TextEditingController field) {
    final n = int.tryParse(field.text);
    if (n == null || n < 0) {
      throw const StudioException('CAPTION_TIME_REQUIRED');
    }
    return Q.of(n, 1000);
  }

  void _setCues(List<CaptionCue> Function(List<CaptionCue>) change) =>
      _edit(() => SetCaptions(CaptionStore(change(_cues))));
  List<Widget> _captionControls() {
    try {
      return _plainCaptionControls();
    } on StudioException catch (error) {
      return [
        Text('Captions read-only: ${error.code}'),
        for (final raw in _project.toJson()['captions'] as List)
          Text(raw['text'] as String),
      ];
    }
  }

  List<Widget> _plainCaptionControls() => [
    const Divider(),
    const Text(
      'Plain captions · SRT/VTT sidecar · no MP4 text rendering',
      style: TextStyle(fontSize: 20),
    ),
    _path('caption-text', 'Caption text', _captionText),
    _path(
      'caption-start',
      'Start / split timestamp (milliseconds, not frames)',
      _captionStart,
    ),
    _path(
      'caption-duration',
      'Duration / trim selection (milliseconds)',
      _captionDuration,
    ),
    Wrap(
      spacing: 8,
      children: [
        OutlinedButton(
          key: const Key('caption-add'),
          onPressed: _busy
              ? null
              : () => _setCues(
                  (c) => [
                    ...c,
                    CaptionCue(
                      'manual-${DateTime.now().microsecondsSinceEpoch}',
                      TimeRange(
                        _captionMilliseconds(_captionStart),
                        _captionMilliseconds(_captionDuration),
                      ),
                      _captionText.text,
                      manualFields: {'text', 'timing'},
                    ),
                  ],
                ),
          child: const Text('Add cue'),
        ),
        OutlinedButton(
          key: const Key('caption-edit'),
          onPressed: _busy || _captionSelected == null
              ? null
              : () => _setCues(
                  (c) => [
                    for (final cue in c)
                      if (cue.id == _captionSelected)
                        cue.editText(_captionText.text)
                      else
                        cue,
                  ],
                ),
          child: const Text('Edit selected text'),
        ),
        OutlinedButton(
          key: const Key('caption-split'),
          onPressed: _busy || _captionSelected == null
              ? null
              : () => _setCues(
                  (c) => [
                    for (final cue in c)
                      if (cue.id == _captionSelected)
                        ...cue.split(
                          _captionMilliseconds(_captionStart),
                          'split-${DateTime.now().microsecondsSinceEpoch}',
                        )
                      else
                        cue,
                  ],
                ),
          child: const Text('Split cue (duplicate text)'),
        ),
        OutlinedButton(
          key: const Key('caption-trim'),
          onPressed: _busy || _captionSelected == null
              ? null
              : () => _setCues(
                  (c) => [
                    for (final cue in c)
                      if (cue.id == _captionSelected)
                        cue.trim(
                          TimeRange(
                            _captionMilliseconds(_captionStart),
                            _captionMilliseconds(_captionDuration),
                          ),
                        )
                      else
                        cue,
                  ],
                ),
          child: const Text('Trim selected cue'),
        ),
        OutlinedButton(
          key: const Key('caption-delete'),
          onPressed: _busy || _captionSelected == null
              ? null
              : () => _setCues(
                  (c) => c.where((v) => v.id != _captionSelected).toList(),
                ),
          child: const Text('Delete selected cue'),
        ),
        OutlinedButton(
          key: const Key('caption-follow-clip'),
          onPressed: _busy || _captionSelected == null
              ? null
              : () => _setCues((cues) {
                  final selected = cues.singleWhere(
                    (c) => c.id == _captionSelected,
                  );
                  final id = coveringCaptionHostClipId(
                    _project.toJson(),
                    selected.range,
                  );
                  if (id == null) {
                    throw const StudioException('ANCHOR_OUT_OF_RANGE');
                  }
                  Map? host;
                  for (final t in _project.toJson()['sequences'][0]['tracks']) {
                    for (final item in t['items']) {
                      if (item['id'] == id) host = item as Map;
                    }
                  }
                  return [
                    for (final cue in cues)
                      if (cue.id == _captionSelected)
                        cue.anchoredToClip(
                          id,
                          Q.fromJson(host!['timelineRange']['start']),
                          Q.fromJson(host['timelineRange']['duration']),
                        )
                      else
                        cue,
                  ];
                }),
          child: const Text('Anchor selected cue to covering clip'),
        ),
        OutlinedButton(
          key: const Key('caption-follow-source'),
          onPressed: _busy || _captionSelected == null
              ? null
              : () => _setCues((cues) {
                  final selected = cues.singleWhere(
                    (c) => c.id == _captionSelected,
                  );
                  final id = coveringCaptionHostClipId(
                    _project.toJson(),
                    selected.range,
                  );
                  if (id == null) {
                    throw const StudioException('ANCHOR_OUT_OF_RANGE');
                  }
                  Map? host;
                  for (final t in _project.toJson()['sequences'][0]['tracks']) {
                    for (final item in t['items']) {
                      if (item['id'] == id) host = item as Map;
                    }
                  }
                  return [
                    for (final cue in cues)
                      if (cue.id == _captionSelected)
                        cue.anchoredToSource(
                          clipId: id,
                          clipStart: Q.fromJson(
                            host!['timelineRange']['start'],
                          ),
                          clipDuration: Q.fromJson(
                            host['timelineRange']['duration'],
                          ),
                          sourceDuration: Q.fromJson(
                            host['sourceRange']['duration'],
                          ),
                          rate: Q.fromJson(host['timeMap']['rate']),
                        )
                      else
                        cue,
                  ];
                }),
          child: const Text('Anchor selected cue to source of covering clip'),
        ),
        OutlinedButton(
          key: const Key('caption-make-absolute'),
          onPressed: _busy || _captionSelected == null
              ? null
              : () => _setCues(
                  (c) => [
                    for (final cue in c)
                      if (cue.id == _captionSelected)
                        cue.makeAbsolute()
                      else
                        cue,
                  ],
                ),
          child: const Text('Make selected cue absolute'),
        ),
      ],
    ),
    for (final cue in _cues)
      ListTile(
        key: Key('cue-${cue.id}'),
        selected: cue.id == _captionSelected,
        title: Text(cue.text),
        subtitle: Text(
          cue.anchorKind == 'source'
              ? '${cue.range.start} → ${cue.range.end} · source of ${cue.anchorClipId}'
              : cue.anchorKind == 'clipLocal'
              ? '${cue.range.start} → ${cue.range.end} · follows ${cue.anchorClipId}'
              : '${cue.range.start} → ${cue.range.end} · absolute',
        ),
        onTap: _busy
            ? null
            : () => setState(() {
                _captionSelected = cue.id;
                _captionText.text = cue.text;
              }),
      ),
    const Text(
      'Deterministic single caption-track overlap rejection. New and imported cues that sit fully on a unique covering clip default to clipLocal and follow that host on MoveClips; cues in a gap or spanning a cut stay absolute. Make selected cue absolute keeps that cue at authored times; Anchor selected cue to covering clip re-attaches an absolute cue as clipLocal. Anchor selected cue to source of covering clip stores a source-window range and reprojects from the host linear time map when that window still covers the cue; an interval that would uncover or crop a source cue refuses the whole command. New cues never default to source. Styles, words, speakers, and MP4 text burn-in remain refused. Ripple and insert interval crop/split of absolute and clipLocal cues stay as already delivered. No silent text loss.',
    ),
    _path(
      'caption-path',
      'Selected subtitle path (import appends; export overwrites atomically)',
      _captionPath,
    ),
    Wrap(
      spacing: 8,
      children: [
        for (final format in CaptionFormat.values)
          OutlinedButton(
            key: Key('caption-import-${format.name}'),
            onPressed: _busy
                ? null
                : () => _run(() async {
                    final result = await widget.workspace.importCaptions(
                      LocalFileGrant.fromUserSelection(File(_captionPath.text)),
                      format,
                      expectedRevision: _project.revision,
                    );
                    return 'Imported ${result.captions.cues.length} cues; warnings: ${result.warnings.join(", ")}';
                  }),
            child: Text('Import ${format.name.toUpperCase()}'),
          ),
        for (final format in [CaptionFormat.srt, CaptionFormat.vtt])
          OutlinedButton(
            key: Key('caption-export-${format.name}'),
            onPressed: _busy
                ? null
                : () => _run(() async {
                    final r = widget.workspace.exportCaptions(
                      File(_captionPath.text),
                      format,
                    );
                    return 'Subtitle sidecar exported from revision $r';
                  }),
            child: Text('Export ${format.name.toUpperCase()}'),
          ),
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Studio Foundation',
    theme: ThemeData(colorSchemeSeed: Colors.indigo),
    home: Scaffold(
      appBar: AppBar(
        title: Text('${widget.workspace.profile.appId} · Foundation'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Stack(
              children: [
                ListView(
                  key: const Key('foundation-scroll'),
                  scrollCacheExtent: const ScrollCacheExtent.pixels(8000),
                  children: [
                    PeerPanel(
                      storageScope: widget.workspace.peerStorageScope,
                      lockPath: widget.workspace.peerIdentityLockPath,
                      createSession:
                          widget.workspace.createMetadataComputeSession,
                      listRecovery:
                          widget.workspace.recoverableMetadataSessions,
                      recoverSession: widget.workspace.recoverMetadataSession,
                    ),
                    const Text(
                      'Project metadata · local SQLite',
                      style: TextStyle(fontSize: 24),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Revision ${_project.revision}',
                      key: const Key('revision'),
                    ),
                    TextField(
                      key: const Key('title'),
                      controller: _title,
                      enabled: !_busy,
                      decoration: const InputDecoration(
                        labelText: 'Project title',
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      children: [
                        FilledButton(
                          key: const Key('save'),
                          onPressed: _busy
                              ? null
                              : () => _act(
                                  () => widget.workspace.rename(
                                    _title.text,
                                    expectedRevision: _project.revision,
                                  ),
                                ),
                          child: const Text('Save title'),
                        ),
                        OutlinedButton(
                          key: const Key('undo'),
                          onPressed: !_busy && widget.workspace.canUndo
                              ? () => _act(
                                  () => widget.workspace.undo(
                                    expectedRevision: _project.revision,
                                  ),
                                )
                              : null,
                          child: const Text('Undo'),
                        ),
                        OutlinedButton(
                          key: const Key('redo'),
                          onPressed: !_busy && widget.workspace.canRedo
                              ? () => _act(
                                  () => widget.workspace.redo(
                                    expectedRevision: _project.revision,
                                  ),
                                )
                              : null,
                          child: const Text('Redo'),
                        ),
                      ],
                    ),
                    Text(
                      _persistenceText,
                      key: const Key('persistence-status'),
                    ),
                    if (widget.workspace.checkpointError != null)
                      const Text(
                        'CHECKPOINT_FAILED: durable edits remain in SQLite; retry checkpoint.',
                        key: Key('checkpoint-error'),
                      ),
                    OutlinedButton(
                      key: const Key('save-managed'),
                      onPressed: _busy
                          ? null
                          : () => _act(() {
                              widget.workspace.saveManaged();
                              return widget.workspace.current;
                            }),
                      child: const Text('Explicit save local checkpoint'),
                    ),
                    if (_error != null)
                      Text(
                        _error!,
                        key: const Key('error'),
                        style: const TextStyle(color: Colors.red),
                      ),
                    if (widget.workspace.media != null)
                      ..._mediaControls()
                    else
                      const Padding(
                        padding: EdgeInsets.only(top: 24),
                        child: Text(
                          'Media adapter not installed. Set STUDIO_MEDIA_LIBRARY to the separately built native adapter. AI generation is not implemented. No media leaves this device.',
                        ),
                      ),
                    TextField(
                      key: const Key('inspect-path'),
                      controller: _inspectionPath,
                      decoration: const InputDecoration(
                        labelText: 'Explicit local project JSON path (inspection only)',
                      ),
                    ),
                    ResourcePreservationPanel(
                      workspace: widget.workspace,
                      onAdopted: () {
                        if (mounted) setState(() {});
                      },
                      targetNamespace: widget.workspace.current.namespace,
                    ),
                    ProjectInspectorPanel(
                      loadSelectedBytes: _readInspectionFile,
                    ),
                    ExpansionTile(
                      key: const Key('caption-panel'),
                      title: const Text('Caption editor'),
                      children: _captionControls(),
                    ),
                    ExpansionTile(
                      key: const Key('marker-panel'),
                      title: const Text('Markers'),
                      children: _markerControls(),
                    ),
                    TextField(
                      key: const Key('invert-command-id'),
                      controller: _invertCommandId,
                      enabled: !_busy,
                      decoration: const InputDecoration(
                        isDense: true,
                        hintText: 'Prior command id',
                      ),
                    ),
                    OutlinedButton(
                      key: const Key('invert-command'),
                      onPressed: _busy
                          ? null
                          : () => _act(
                              () => widget.workspace.invertCommand(
                                _invertCommandId.text.trim(),
                                expectedRevision: _project.revision,
                              ),
                            ),
                      child: const Text('Invert prior command'),
                    ),
                    for (final t
                        in _project.toJson()['sequences'][0]['tracks'] as List)
                      CheckboxListTile(
                        key: Key('${t['kind']}-track-lock-${t['id']}'),
                        value: t['locked'] as bool,
                        onChanged: _busy
                            ? null
                            : (v) => _edit(
                                () => SetTrackState(
                                  t['id'] as String,
                                  locked: v ?? false,
                                ),
                              ),
                        title: Text('Lock ${t['kind']} track'),
                      ),
                  ],
                ),
                if (_busy)
                  const Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: LinearProgressIndicator(key: Key('media-busy')),
                  ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
