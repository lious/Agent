import 'package:studio_peer_ui/studio_peer_ui.dart';

import 'dart:async';
import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:studio_sdk/studio_sdk.dart';

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
  final _peerHash = TextEditingController();
  String? _peerAdoptionId;
  BigInt? _peerAdoptionRevision;
  bool _gcConfirmed = false;
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
    WidgetsBinding.instance.addObserver(this);
    _persistenceSubscription = widget.workspace.persistenceEvents.listen((_) {
      if (mounted) setState(() {});
    });
  }

  void _refresh() {
    _project = widget.workspace.current;
    _title.text = _project.title;
    if (!_clips.any((c) => c['id'] == _selected)) _selected = null;
    if (!(_project.toJson()['captions'] as List).any(
      (c) => c['id'] == _captionSelected,
    )) {
      _captionSelected = null;
    }
  }

  void _act(ProjectDocument Function() action) {
    try {
      action();
      setState(() {
        _refresh();
        _error = null;
      });
    } on StudioException catch (e) {
      setState(() => _error = e.code);
    }
  }

  Future<void> _run(Future<String> Function() action) async {
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
    return tracks.isEmpty
        ? []
        : (tracks[0]['items'] as List)
              .where((c) => c['source'] != null)
              .toList();
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

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      try {
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
      'Local video · single track · no audio export',
      style: TextStyle(fontSize: 22),
    ),
    const Text(
      'CFR, 1×, Rec.709 limited, even canvas ≤2048. No scaling/effects/preview yet. Rights unknown = warning, not authorization. No media uploads.',
    ),
    _path('import-path', 'Selected local video path', _input),
    CheckboxListTile(
      value: _videoOnly,
      title: const Text('If source has audio, explicitly import video only'),
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
            : () => setState(() => _selected = c['id'] as String),
      ),
    _path(
      'edit-frames',
      'Positive frames (split: local offset; trim: remove from out)',
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
                    '${DateTime.now().microsecondsSinceEpoch}-split',
                  );
                }),
          child: const Text('Split'),
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
                    ripple: true,
                  ),
                ),
          child: const Text('Ripple trim out'),
        ),
        OutlinedButton(
          key: const Key('delete'),
          onPressed: _busy || _selected == null
              ? null
              : () => _edit(() => DeleteClip(_selected!, ripple: true)),
          child: const Text('Ripple delete'),
        ),
      ],
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
                  );
                  return 'MP4 exported from frozen revision ${receipt['revision']} · ${receipt['frames']} frames';
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
    if (_busy) const LinearProgressIndicator(),
    Text(_status, key: const Key('operation-status')),
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
      ],
    ),
    for (final cue in _cues)
      ListTile(
        key: Key('cue-${cue.id}'),
        selected: cue.id == _captionSelected,
        title: Text(cue.text),
        subtitle: Text('${cue.range.start} → ${cue.range.end}'),
        onTap: _busy
            ? null
            : () => setState(() {
                _captionSelected = cue.id;
                _captionText.text = cue.text;
              }),
      ),
    const Text(
      'Deterministic single caption-track overlap rejection. Video timing edits while cues exist are refused until synchronized caption ripple is implemented. No silent text loss.',
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
            child: ListView(
              children: [
                PeerPanel(
                  storageScope: widget.workspace.peerStorageScope,
                  lockPath: widget.workspace.peerIdentityLockPath,
                  createSession: widget.workspace.createMetadataComputeSession,
                  listRecovery: widget.workspace.recoverableMetadataSessions,
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
                  decoration: const InputDecoration(labelText: 'Project title'),
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
                      child: const Text('Undo latest'),
                    ),
                  ],
                ),
                Text(_persistenceText, key: const Key('persistence-status')),
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
                ExpansionTile(
                  key: const Key('caption-panel'),
                  title: const Text('Caption editor'),
                  children: _captionControls(),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
