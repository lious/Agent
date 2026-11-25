import 'dart:convert';
import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:studio_sdk/studio_sdk.dart';

/// Separate from editable workspace; no project admission or renderer port.
class ResourcePreservationPanel extends StatefulWidget {
  const ResourcePreservationPanel({
    super.key,
    required this.targetNamespace,
    this.workspace,
    this.onAdopted,
  });
  final Namespace targetNamespace;
  final StudioWorkspace? workspace;
  final VoidCallback? onAdopted;
  @override
  State<ResourcePreservationPanel> createState() =>
      _ResourcePreservationPanelState();
}

class _ResourcePreservationPanelState extends State<ResourcePreservationPanel> {
  final _input = TextEditingController(),
      _resource = TextEditingController(),
      _output = TextEditingController();
  ResourcePreservationSession? _session;
  bool _busy = false, _adopting = false;
  String? _consent, _error;
  String _status =
      'No resource snapshot loaded. Separate READ-ONLY file view; active workspace unchanged.';
  int _page = 0;
  @override
  void dispose() {
    _session?.cancelPending();
    if (_adopting) widget.workspace?.cancelResourceImport();
    _input.dispose();
    _resource.dispose();
    _output.dispose();
    super.dispose();
  }

  Future<void> _run(Future<String> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final status = await action();
      if (mounted) setState(() => _status = status);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<String> _load(bool archive) async {
    final grant = LocalFileGrant.fromUserSelection(File(_input.text));
    final next = archive
        ? await ResourcePreservationSession.openArchive(grant)
        : await ResourcePreservationSession.openJson(grant);
    _session = next;
    _consent = null;
    _page = 0;
    return 'Loaded read-only resource snapshot ${next.project.projectId} / ${next.project.hash}; no SQLite/CAS write or media/font/plugin execution.';
  }

  @override
  Widget build(BuildContext context) {
    final session = _session;
    final text = session == null
        ? 'No report'
        : const JsonEncoder.withIndent('  ').convert(session.report);
    final pages = (text.length + 4095) ~/ 4096;
    final page = _page.clamp(0, pages - 1);
    final start = page * 4096, end = (start + 4096).clamp(0, text.length);
    return ExpansionTile(
      key: const Key('resource-preservation-panel'),
      title: const Text(
        'Inspect/preserve resources (read-only until explicit fork)',
      ),
      children: [
        const Text(
          'Explicit files only. Hash/size integrity is NOT font/LUT/image decoding, license verification or render support. Unknown LUT/library/plugins/extensions stay opaque; unregistered closure blocks complete packaging/fork. No models downloaded, no locator followed or cloud upload. Inspection/preservation do not write CAS/database; only the explicitly confirmed writable-fork action does. New output paths only; existing files never overwritten. Volume free-space/ENOSPC qualification is not provided.',
        ),
        TextField(
          key: const Key('resource-project-input'),
          controller: _input,
          decoration: const InputDecoration(
            labelText: 'Explicit project JSON or resource ZIP path',
          ),
        ),
        OutlinedButton(
          key: const Key('resource-load-json'),
          onPressed: _busy ? null : () => _run(() => _load(false)),
          child: const Text('Load JSON read-only'),
        ),
        OutlinedButton(
          key: const Key('resource-open-archive'),
          onPressed: _busy ? null : () => _run(() => _load(true)),
          child: const Text('Reopen resource archive read-only'),
        ),
        TextField(
          key: const Key('resource-file-input'),
          controller: _resource,
          decoration: const InputDecoration(
            labelText:
                'Explicit declared resource file; matched by actual SHA256',
          ),
        ),
        OutlinedButton(
          key: const Key('resource-attach'),
          onPressed: _busy || session == null
              ? null
              : () => _run(() async {
                  final hash = await session.attach(
                    LocalFileGrant.fromUserSelection(File(_resource.text)),
                  );
                  _consent = null;
                  _page = 0;
                  return 'Collected $hash in bounded memory; byte integrity only, no format/render admission.';
                }),
          child: const Text('Collect explicitly selected declared file'),
        ),
        TextField(
          key: const Key('resource-output'),
          controller: _output,
          decoration: const InputDecoration(
            labelText: 'New local output path (JSON or ZIP)',
          ),
        ),
        OutlinedButton(
          key: const Key('resource-save-json'),
          onPressed: _busy || session == null
              ? null
              : () => _run(() async {
                  await session.saveMetadata(File(_output.text));
                  return 'Saved metadata JSON only; not a self-contained media project.';
                }),
          child: const Text('Save metadata only (including opaque data)'),
        ),
        CheckboxListTile(
          key: const Key('resource-collect-consent'),
          value: session != null && _consent == session.collectionReviewHash,
          onChanged: _busy || session == null
              ? null
              : (v) => setState(
                  () => _consent = v == true
                      ? session.collectionReviewHash
                      : null,
                ),
          title: const Text(
            'Locally package these explicitly collected bytes; font/license restrictions and unknown rights remain warnings, NOT fabricated permission or sharing consent. No upload.',
          ),
        ),
        OutlinedButton(
          key: const Key('resource-save-archive'),
          onPressed:
              _busy ||
                  session == null ||
                  _consent != session.collectionReviewHash
              ? null
              : () => _run(() async {
                  final review = _consent!;
                  _consent = null;
                  await session.saveArchive(
                    File(_output.text),
                    confirmedCollection: true,
                    expectedCollectionReviewHash: review,
                  );
                  return 'Saved resource-preservation ZIP; all declared bytes integrity-checked. NOT qualified self-contained/renderable. Reopen in this READ-ONLY panel.';
                }),
          child: const Text('Archive declared resources (no execution)'),
        ),
        OutlinedButton(
          key: const Key('resource-fork'),
          onPressed: _busy || session == null
              ? null
              : () => _run(() async {
                  _session = session.fork(widget.targetNamespace);
                  _consent = null;
                  _page = 0;
                  return 'Forked registered media/image/font profile to new IDs/revision0 in memory; save explicitly. No editor/approval/job adoption; origin mapping not persisted in this slice.';
                }),
          child: const Text('Fork registered resource profile (read-only)'),
        ),
        if (widget.workspace != null)
          OutlinedButton(
            key: const Key('resource-adopt-writable'),
            onPressed:
                _busy ||
                    session == null ||
                    _consent != session.collectionReviewHash
                ? null
                : () => _run(() async {
                    final review = _consent!;
                    _consent = null;
                    _adopting = true;
                    try {
                      final next = await widget.workspace!
                          .adoptPreservedResources(
                            session,
                            expectedCollectionReviewHash: review,
                            expectedActiveHash: widget.workspace!.current.hash,
                            confirmed: true,
                          );
                      widget.onAdopted?.call();
                      return 'Opened new writable project ${next.projectId}; original retained, native source facts/first-frame qualified and ImportMap persisted. Unsupported content is never dropped. Full-file decode/export still checked at execution.';
                    } finally {
                      _adopting = false;
                    }
                  }),
            child: const Text(
              'Qualify and open NEW writable fork (supported renderer only)',
            ),
          ),
        OutlinedButton(
          key: const Key('resource-cancel'),
          onPressed: session == null
              ? null
              : () {
                  session.cancelPending();
                  if (_adopting) widget.workspace?.cancelResourceImport();
                },
          child: const Text('Cancel pending archive/import before publication'),
        ),
        if (_busy) const LinearProgressIndicator(key: Key('resource-busy')),
        if (_error != null) Text(_error!, key: const Key('resource-error')),
        Text(_status, key: const Key('resource-status')),
        Text(
          'Report page ${page + 1}/$pages; missing bytes and metadata issues separate. Formats remain unqualified.',
        ),
        SelectableText(
          text.substring(start, end),
          key: const Key('resource-report'),
        ),
        Row(
          children: [
            TextButton(
              onPressed: page == 0
                  ? null
                  : () => setState(() => _page = page - 1),
              child: const Text('Previous resource page'),
            ),
            TextButton(
              onPressed: page + 1 >= pages
                  ? null
                  : () => setState(() => _page = page + 1),
              child: const Text('Next resource page'),
            ),
          ],
        ),
      ],
    );
  }
}
