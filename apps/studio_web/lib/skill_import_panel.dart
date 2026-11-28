// App-private controls. No shared editor/art-page widget API is extended.
import 'dart:async';

import 'import_fixture_composition.dart';

import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'dart:convert';
import 'dart:typed_data';

import 'package:material_ui/material_ui.dart';
import 'package:studio_assets/craft/signed_import/app_session.dart';
import 'package:studio_assets/craft/signed_import/importer.dart';
import 'package:studio_assets/craft/signed_import/source_capture.dart';

class SkillImportPanel extends StatefulWidget {
  const SkillImportPanel({
    super.key,
    this.ownerIdentity,
    this.ownerLifetime,
    required this.currentApp,
    required this.createRepository,
    required this.chooseSource,
  });
  final Object? ownerIdentity;
  final ImportCompositionLifetime? ownerLifetime;
  final ImportAppSnapshot Function() currentApp;
  final ImportRepositoryFactory createRepository;
  final Future<Uint8List?> Function(
    SkillSourceCapture,
    bool Function(),
    void Function(),
  )
  chooseSource;
  @override
  State<SkillImportPanel> createState() => _SkillImportPanelState();
}

class _SkillImportPanelState extends State<SkillImportPanel>
    with WidgetsBindingObserver {
  late final AppImportSession _session;
  late final JSFunction _pagehide;
  void Function()? _unregisterLifetime;
  bool _ownerRetiring = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _session = AppImportSession(
      currentApp: () => widget.currentApp(),
      capture: SkillSourceCapture(),
      changed: () {
        if (mounted && !_ownerRetiring) setState(() {});
      },
    );
    _unregisterLifetime = widget.ownerLifetime?.register(() {
      // Parent publication already rebuilds, or teardown is unmounting the tree.
      // Do not schedule a child rebuild while its owner is being disposed.
      _ownerRetiring = true;
      _session.retire();
    });
    _pagehide = ((web.Event event) {
      _session.retire();
    }).toJS;
    web.window.addEventListener('pagehide', _pagehide);
    unawaited(_session.initialize(widget.createRepository));
  }

  @override
  void didUpdateWidget(covariant SkillImportPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.ownerIdentity != widget.ownerIdentity ||
        !identical(oldWidget.ownerLifetime, widget.ownerLifetime)) {
      _session.retire();
    } else {
      _session.refresh();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if ([
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
      AppLifecycleState.detached,
    ].contains(state)) {
      _session.retire();
    }
  }

  @override
  void dispose() {
    _unregisterLifetime?.call();
    web.window.removeEventListener('pagehide', _pagehide);
    WidgetsBinding.instance.removeObserver(this);
    _session.dispose();
    super.dispose();
  }

  String snippet(Object? value) {
    final text = '$value';
    final chars = text.runes.toList();
    return chars.length <= 256
        ? text
        : '${String.fromCharCodes(chars.take(256))}… [truncated]';
  }

  @override
  Widget build(BuildContext context) {
    final r = _session.report;
    final canChoose = _session.canChoose, canAck = _session.canAcknowledge;
    return Semantics(
      container: true,
      label: 'Skill import preview only',
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Skill import — preview only'),
              const Text(
                'documentWrites=0; executionAuthority=false. Acknowledgment installs nothing and does not approve tool execution. signed=true is not verification or approval.',
              ),
              Text(_session.status, key: const Key('skill-status')),
              Text('State: ${_session.state}', key: const Key('skill-state')),
              Wrap(
                spacing: 8,
                children: [
                  FilledButton(
                    key: const Key('skill-choose'),
                    onPressed: canChoose
                        ? () => unawaited(
                            _session.choose(
                              () => widget.chooseSource(
                                _session.capture,
                                _session.fence,
                                _session.reading,
                              ),
                            ),
                          )
                        : null,
                    child: const Text('Choose skill source'),
                  ),
                  OutlinedButton(
                    key: const Key('skill-dismiss'),
                    onPressed: r != null ? _session.discard : null,
                    child: const Text('Dismiss preview'),
                  ),
                  OutlinedButton(
                    key: const Key('skill-cancel'),
                    onPressed: _session.capture.busy ? _session.cancel : null,
                    child: const Text('Cancel source capture'),
                  ),
                ],
              ),
              if (r != null)
                SizedBox(
                  height: 280,
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'trustState: ${r.trustState}',
                          key: const Key('skill-trust'),
                        ),
                        const Text(
                          'verified means pinned threshold only; unsignedUntrusted is untrusted knowledge; needsReview is NOT verified.',
                        ),
                        Text('namespace: ${jsonEncode(r.namespace)}'),
                        Text('policyEpoch: ${r.policyEpoch}'),
                        Text('envelopeHash: ${r.envelopeHash}'),
                        Text('payloadHash: ${r.payloadHash}'),
                        Text('contentHash: ${r.contentHash}'),
                        Text(
                          'verifiedKeyFingerprints: ${jsonEncode(r.verifiedKeyFingerprints)}',
                        ),
                        Text('requiredTools: ${jsonEncode(r.requiredTools)}'),
                        Text('permissionDiff: ${jsonEncode(r.permissionDiff)}'),
                        Text('permissionDiffHash: ${r.permissionDiffHash}'),
                        const Text(
                          'License declarations/evidence are unverified, not a license grant. allow_with_warning.',
                        ),
                        for (final item in [
                          ...r.licenseFacts.entries,
                          ...r.knowledge.entries,
                        ].take(32))
                          Text('${snippet(item.key)}: ${snippet(item.value)}'),
                        if (r.licenseFacts.length + r.knowledge.length > 32)
                          const Text(
                            'Descriptive snippets limited to 32; full immutable report retained, not changed.',
                          ),
                      ],
                    ),
                  ),
                ),
              FilledButton(
                key: const Key('skill-acknowledge'),
                onPressed: canAck ? _session.acknowledge : null,
                child: const Text('Acknowledge preview only'),
              ),
              if (r != null && !canAck)
                const Text(
                  'Acknowledgment disabled: needsReview, unknown/rollback clock or stale App context. No clock override.',
                ),
            ],
          ),
        ),
      ),
    );
  }
}
