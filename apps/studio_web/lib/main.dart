import 'package:studio_editor_ui/project_inspector.dart';

import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;
import 'package:material_ui/material_ui.dart';
import 'package:studio_contracts/studio_contracts.dart';
import 'package:studio_document/studio_document.dart';

import 'browser_store.dart';

import 'package:studio_assets/studio_signed_skill_import_web.dart';

import 'skill_import_panel.dart';
import 'skill_source_web.dart';
import 'peer_panel.dart';
import 'import_fixture_composition.dart';

void main() => runApp(const WebStudioApp());

class WebStudioApp extends StatefulWidget {
  const WebStudioApp({super.key}) : importFixture = null;
  const WebStudioApp.testImport({super.key, required this.importFixture});
  final AppImportFixtureConfiguration? importFixture;
  @override
  State<WebStudioApp> createState() => _WebStudioState();
}

class _WebStudioState extends State<WebStudioApp> {
  final _skillProfile = AppProfile(
    appId: 'studio',
    region: 'local',
    features: {'project.metadata'},
  );
  late final _skillPolicy = BuildTimeSignaturePolicy.disabled(
    _skillProfile,
    Namespace('studio', 'local', 'web'),
  );
  AppImportFixtureConfiguration? _fixture;
  BuildTimeSignaturePolicy? _fixturePolicy;
  final _importLifetime = ImportCompositionLifetime();
  BrowserProjectStore? _store;
  ProjectDocument? _project;
  final _title = TextEditingController(),
      _text = TextEditingController(),
      _subtitle = TextEditingController();
  String? _error;
  int _command = 0;
  int _fixtureRebuilds = 0;
  bool _fixturePanelMounted = true;
  String _fixtureLifecycle = 'none';
  @override
  void initState() {
    super.initState();
    _fixture = widget.importFixture;
    unawaited(_open());
  }

  @override
  void didUpdateWidget(covariant WebStudioApp oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(_fixture, widget.importFixture)) {
      _importLifetime.invalidateBeforePublication();
      _fixture = widget.importFixture;
      _fixturePolicy = null;
    }
  }

  void _injectFixtureLifecycle(AppLifecycleState state) {
    if (!(_fixture?.lifecycleTestControls ?? false)) return;
    setState(() => _fixtureLifecycle = state.name);
    WidgetsBinding.instance.handleAppLifecycleStateChanged(state);
    Timer(const Duration(milliseconds: 150), () {
      if (!mounted) return;
      WidgetsBinding.instance.handleAppLifecycleStateChanged(
        AppLifecycleState.resumed,
      );
      setState(() => _fixtureLifecycle = '${state.name} -> resumed');
    });
  }

  Future<void> _open() async {
    try {
      final ns = Namespace('studio', 'local', 'web');
      final store = await BrowserProjectStore.open('studio-web-dev-v1', ns);
      final project = await store.openProject(
        ProjectDocument.empty(
          namespace: ns,
          projectId: 'demo-project',
          title: 'Web project',
        ),
      );
      if (!mounted) {
        store.close();
        return;
      }
      setState(() {
        _store = store;
        _project = project;
        _title.text = project.title;
      });
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  Future<void> _edit(EditOperation operation) async {
    try {
      final p = await _store!.edit(
        _project!.projectId,
        operation,
        commandId:
            'browser-${DateTime.now().microsecondsSinceEpoch}-${++_command}',
        expectedRevision: _project!.revision,
      );
      if (mounted) {
        setState(() {
          _project = p;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  List<CaptionCue> get _cues => (_project!.toJson()['captions'] as List)
      .map((c) => CaptionCue.fromProjectJson(c as Map<String, dynamic>))
      .toList();
  void _decode() {
    try {
      final imported = CaptionFormats.decode(_subtitle.text, CaptionFormat.srt);
      if (imported.warnings.isNotEmpty) {
        throw StudioException(
          'IMPORT_LOSS_CONFIRMATION_REQUIRED',
          imported.warnings.join(','),
        );
      }
      unawaited(_edit(SetCaptions(imported.captions)));
    } catch (e) {
      setState(() => _error = '$e');
    }
  }

  void _download() {
    final blob = web.Blob(
      [_project!.canonicalJson.toJS].toJS,
      web.BlobPropertyBag(type: 'application/json'),
    );
    final url = web.URL.createObjectURL(blob);
    final a = web.HTMLAnchorElement()
      ..href = url
      ..download = 'studio-project-metadata.json';
    a.click();
    Timer(const Duration(seconds: 1), () => web.URL.revokeObjectURL(url));
  }

  @override
  void dispose() {
    _importLifetime.invalidateBeforePublication();
    _store?.close();
    _title.dispose();
    _text.dispose();
    _subtitle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    home: Scaffold(
      appBar: AppBar(
        title: const Text('Studio Web · editable local-first preview'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: ListView(
          children: [
            const Text(
              'Browser IndexedDB metadata/caption editing only. No media renderer, model or paid service. Peer networking requires separate explicit WebRTC pairing below. Browser storage can be evicted: export JSON; this is not a complete portable media archive.',
            ),
            const ProjectInspectorPanel(),
            if (_fixture != null) ...[
              Text('Fixture App rebuild: $_fixtureRebuilds'),
              TextButton(
                onPressed: () => setState(() => ++_fixtureRebuilds),
                child: const Text('Rebuild fixture App'),
              ),
            ],
            if (_fixture?.lifecycleTestControls ?? false) ...[
              Text('Fixture lifecycle: $_fixtureLifecycle'),
              for (final state in [
                AppLifecycleState.inactive,
                AppLifecycleState.hidden,
                AppLifecycleState.paused,
                AppLifecycleState.detached,
              ])
                TextButton(
                  onPressed: () => _injectFixtureLifecycle(state),
                  child: Text('Inject fixture lifecycle ${state.name}'),
                ),
              TextButton(
                onPressed: () {
                  _importLifetime.invalidateBeforePublication();
                  setState(() => _fixturePanelMounted = false);
                },
                child: const Text('Unmount fixture import panel'),
              ),
            ],
            if (const bool.fromEnvironment('STUDIO_SIGNED_IMPORT_PREVIEW') &&
                _project != null &&
                _fixturePanelMounted)
              SkillImportPanel(
                ownerIdentity: _project!.projectId,
                ownerLifetime: _importLifetime,
                currentApp: () => ImportAppSnapshot(
                  profile: _skillProfile,
                  namespace: _project!.namespace.toJson(),
                  policy: _fixture == null
                      ? _skillPolicy
                      : (_fixturePolicy ??= _fixture!.policyForOwner(
                          _skillProfile,
                          _project!.namespace,
                        )),
                  nowSeconds:
                      _fixture?.nowSeconds ??
                      DateTime.now().millisecondsSinceEpoch ~/ 1000,
                  clockConfident: _fixture?.clockConfident ?? false,
                  clockRollback: _fixture?.clockRollback ?? false,
                  installedAllowlist: {},
                  sessionGrant: {},
                  branchScope: {},
                ),
                createRepository: createWebSignedSkillRepository,
                chooseSource: (capture, guard, selected) =>
                    _fixture?.chooseSourceForTest?.call(
                      capture,
                      guard,
                      selected,
                    ) ??
                    chooseWebSkillSource(
                      capture,
                      currentAppStillValid: guard,
                      onSelected: selected,
                    ),
              ),
            if (_project == null)
              const Text('Opening local browser project…')
            else ...[
              Text(
                'Revision ${_project!.revision}',
                key: const Key('revision'),
              ),
              TextField(
                key: const Key('title'),
                controller: _title,
                decoration: const InputDecoration(labelText: 'Project title'),
              ),
              FilledButton(
                key: const Key('rename'),
                onPressed: () => unawaited(_edit(RenameProject(_title.text))),
                child: const Text('Commit title to IndexedDB'),
              ),
              TextField(
                key: const Key('caption-text'),
                controller: _text,
                decoration: const InputDecoration(
                  labelText: 'New one-second cue text',
                ),
              ),
              FilledButton(
                key: const Key('add-caption'),
                onPressed: () => unawaited(
                  _edit(
                    SetCaptions(
                      CaptionStore([
                        ..._cues,
                        CaptionCue(
                          'cue-${DateTime.now().microsecondsSinceEpoch}',
                          TimeRange(
                            _cues.isEmpty ? Q.of(0) : _cues.last.range.end,
                            Q.of(1),
                          ),
                          _text.text,
                          manualFields: {'text', 'timing'},
                        ),
                      ]),
                    ),
                  ),
                ),
                child: const Text('Add caption'),
              ),
              for (final cue in _cues) Text(cue.text),
              TextField(
                key: const Key('subtitle'),
                controller: _subtitle,
                minLines: 3,
                maxLines: 8,
                decoration: const InputDecoration(
                  labelText: 'SRT text (explicit replace current cue set)',
                ),
              ),
              OutlinedButton(
                key: const Key('import-srt'),
                onPressed: _decode,
                child: const Text('Replace captions from SRT'),
              ),
              OutlinedButton(
                key: const Key('export-vtt'),
                onPressed: () {
                  try {
                    setState(
                      () => _subtitle.text = CaptionFormats.encode(
                        CaptionStore(_cues),
                        CaptionFormat.vtt,
                      ),
                    );
                  } catch (e) {
                    setState(() => _error = '$e');
                  }
                },
                child: const Text('Show WebVTT'),
              ),
              WebPeerPanel(store: _store!, projectId: _project!.projectId),
              OutlinedButton(
                onPressed: _download,
                child: const Text('Download project JSON metadata'),
              ),
            ],
            if (_error != null) Text(_error!, key: const Key('error')),
          ],
        ),
      ),
    ),
  );
}
