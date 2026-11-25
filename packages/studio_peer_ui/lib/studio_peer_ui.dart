import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:material_ui/material_ui.dart';
import 'package:studio_peer_io/studio_peer_io.dart';
import 'package:studio_peer_io/compute_session.dart';
import 'package:studio_contracts/studio_contracts.dart';
import 'package:studio_document/studio_document.dart' show rawBytesHash;
import 'package:uuid/uuid.dart';

import 'native_identity.dart';
export 'native_identity.dart';

/// Explicit human pairing UI. No listener, key generation or metadata transfer
/// occurs on startup. Public offer/invitation never contains private PEM.
class PeerPanel extends StatefulWidget {
  const PeerPanel({
    super.key,
    required this.storageScope,
    required this.lockPath,
    required this.createSession,
    required this.listRecovery,
    required this.recoverSession,
  });
  final String storageScope, lockPath;
  final ComputeSessionCoordinator Function(String id) createSession;
  final List<Map<String, dynamic>> Function(String ownerFingerprint)
  listRecovery;
  final ComputeSessionCoordinator Function(
    String sessionId,
    String planHash,
    String ownerFingerprint,
  )
  recoverSession;
  @override
  State<PeerPanel> createState() => _PeerPanelState();
}

class _PeerPanelState extends State<PeerPanel> {
  final _address = TextEditingController(text: '127.0.0.1'),
      _paste = TextEditingController(),
      _confirm = TextEditingController(),
      _public = TextEditingController(),
      _node = TextEditingController(text: 'digest-0');
  final _sourceFile = TextEditingController(),
      _recovery = TextEditingController();
  bool _recoveryConsent = false;
  List<int>? _frozenBlob;
  String? _preparedPath;
  bool _blobConsent = false;
  NativeIdentity? _identity;
  ComputeSessionCoordinator? _session;
  bool _consent = false, _lan = false, _busy = false;
  String _status =
      'No peer endpoint enabled. Linux identity provisioning only; no relay/cloud fallback.';
  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } catch (e) {
      if (mounted) {
        setState(
          () => _status = e is StudioException ? e.code : 'PEER_ACTION_FAILED',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Map<String, dynamic> _parse() {
    if (_paste.text.length > 32768) {
      throw const StudioException('PEER_INPUT_LIMIT');
    }
    final value = jsonDecode(_paste.text) as Map<String, dynamic>;
    if (value['schemaVersion'] != '1.0.0') {
      throw const StudioException('PEER_PROTOCOL_VERSION');
    }
    final fingerprint = publicCertificateFingerprint(
      value['certificatePem'] as String,
    );
    if (_confirm.text.trim() != fingerprint) {
      throw const StudioException('PAIRING_CONFIRMATION_MISMATCH');
    }
    if (value['runtimePin'] != nativeMetadataRuntimePin) {
      throw const StudioException('PEER_RUNTIME_NOT_QUALIFIED');
    }
    return value;
  }

  Future<void> _load() async {
    final identity = await NativeIdentity.open(
      storageScope: widget.storageScope,
      lockPath: widget.lockPath,
      bindAddress: _address.text.trim(),
    );
    if (mounted) {
      setState(() {
        _identity = identity;
        _public.text = jsonEncode({
          ...identity.publicOffer(),
          'runtimePin': nativeMetadataRuntimePin,
        });
        _status = 'Identity loaded from OS secure storage. Independently compare full fingerprints on both devices.';
      });
    }
  }

  Future<void> _host() async {
    if (!_consent || _identity == null) {
      throw const StudioException('PEER_EXPLICIT_CONSENT_REQUIRED');
    }
    if (_session?.isListening ?? false) {
      throw const StudioException('SESSION_ALREADY_LISTENING');
    }
    final peer = _parse(),
        fingerprint = publicCertificateFingerprint(
          peer['certificatePem'] as String,
        ),
        address = InternetAddress(_identity!.bindAddress);
    if (!address.isLoopback && !_lan) {
      throw const StudioException('PEER_LAN_NOT_ENABLED');
    }
    final session =
        _session ?? widget.createSession('session-${const Uuid().v4()}');
    session.enableRecovery(_identity!.fingerprint);
    _session = session;
    try {
      // User explicitly grants the selected fixed node, not all project files.
      final nodes = {_node.text.trim()};
      session.grant(
        fingerprint: fingerprint,
        deviceId: peer['deviceId'] as String,
        nodes: nodes,
        allowedBlobs: _blobConsent && peer['blobOffer'] is Map
            ? {
                (peer['blobOffer'] as Map)['hash'] as String:
                    (peer['blobOffer'] as Map)['size'] as int,
              }
            : const {},
      );
      final port = await session.listen(
        _identity!.context(
          trustedCertificates: [peer['certificatePem'] as String],
        ),
        address,
        allowLan: _lan,
      );
      if (!mounted) {
        await session.close();
        return;
      }
      final endpoint = Uri(
        scheme: 'https',
        host: address.address,
        port: port,
        path: '/studio/peer/v1',
      ).toString();
      setState(() {
        _public.text = jsonEncode(
          session.invitation(
            endpoint: endpoint,
            certificatePem: _identity!.certificatePem,
            nodes: nodes,
          ),
        );
        _status =
            'Session ${session.id}: encrypted direct listener; grant expires in 10min. ${session.statuses}';
      });
    } catch (_) {
      await session.close();
      _session = null;
      rethrow;
    }
  }

  Future<void> _work() async {
    if (!_consent || _identity == null) {
      throw const StudioException('PEER_EXPLICIT_CONSENT_REQUIRED');
    }
    final invite = _parse();
    if (invite['granteeFingerprint'] != _identity!.fingerprint) {
      throw const StudioException('PEER_NOT_AUTHORIZED');
    }
    final client = PeerTlsClient(
      context: _identity!.context(
        trustedCertificates: [invite['certificatePem'] as String],
      ),
      endpoint: Uri.parse(invite['endpoint'] as String),
      serverFingerprint: _confirm.text.trim(),
    );
    try {
      final receipt = await runPeerDigest(
        client,
        invite,
        _node.text.trim(),
        operationId: 'ui-${const Uuid().v4()}',
      );
      if (mounted) {
        setState(
          () => _status =
              'Candidate persisted: ${receipt['resultHash']}. No project edit or paid operation.',
        );
      }
    } finally {
      client.close();
    }
  }

  Future<void> _prepareBlob() async {
    if (_identity == null) throw const StudioException('IDENTITY_REQUIRED');
    final file = File(_sourceFile.text.trim());
    if (await file.length() > 16 * 1024 * 1024) {
      throw const StudioException('PEER_BLOB_QUOTA');
    }
    final builder = BytesBuilder(copy: false);
    await for (final part in file.openRead(0, 16 * 1024 * 1024 + 1)) {
      builder.add(part);
    }
    final bytes = builder.takeBytes();
    if (bytes.length > 16 * 1024 * 1024) {
      throw const StudioException('PEER_BLOB_QUOTA');
    }
    if (!mounted) return;
    _frozenBlob = bytes.asUnmodifiableView();
    _preparedPath = file.path;
    setState(() {
      _public.text = jsonEncode({
        ..._identity!.publicOffer(),
        'runtimePin': nativeMetadataRuntimePin,
        'blobOffer': {
          'hash': rawBytesHash(bytes).substring(7),
          'size': bytes.length,
        },
      });
      _status =
          'Frozen selected blob ${rawBytesHash(bytes)} (${bytes.length} bytes). Only public hash/size offered; nothing sent.';
    });
  }

  Future<void> _uploadBlob() async {
    if (!_consent ||
        _identity == null ||
        _frozenBlob == null ||
        _preparedPath != _sourceFile.text.trim()) {
      throw const StudioException('PEER_BLOB_EXPLICIT_SOURCE_REQUIRED');
    }
    final invite = _parse();
    if (invite['granteeFingerprint'] != _identity!.fingerprint) {
      throw const StudioException('PEER_NOT_AUTHORIZED');
    }
    final client = PeerTlsClient(
      context: _identity!.context(
        trustedCertificates: [invite['certificatePem'] as String],
      ),
      endpoint: Uri.parse(invite['endpoint'] as String),
      serverFingerprint: _confirm.text.trim(),
    );
    try {
      final receipt = await uploadPeerBlob(
        client,
        invite,
        _node.text.trim(),
        _frozenBlob!,
        operationId: 'blob-${const Uuid().v4()}',
      );
      if (mounted) {
        setState(
          () => _status =
              'Verified peer inbox committed ${receipt['blobHash']}; not automatically attached to a project.',
        );
      }
    } finally {
      client.close();
    }
  }

  @override
  void dispose() {
    unawaited(
      _session?.close().catchError((Object _) {}) ?? Future<void>.value(),
    );
    for (final c in [
      _address,
      _paste,
      _confirm,
      _public,
      _node,
      _sourceFile,
      _recovery,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ExpansionTile(
    title: const Text('Trusted peer session · Linux preview'),
    children: [
      Text(_status, key: const Key('peer-status')),
      TextField(
        key: const Key('peer-bind'),
        controller: _address,
        decoration: const InputDecoration(
          labelText: 'Identity/listener IP (immutable until explicit identity rotation)',
        ),
      ),
      FilledButton(
        key: const Key('peer-identity'),
        onPressed: _busy ? null : () => unawaited(_run(_load)),
        child: const Text('Create/load OS-stored device identity'),
      ),
      if (_identity != null)
        SelectableText(
          'Local certificate SHA256: ${_identity!.fingerprint}',
          key: const Key('peer-fingerprint'),
        ),
      TextField(
        key: const Key('peer-public'),
        controller: _public,
        readOnly: true,
        minLines: 2,
        maxLines: 4,
        decoration: const InputDecoration(
          labelText:
              'PUBLIC identity offer / scoped invitation (copy manually)',
        ),
      ),
      TextField(
        key: const Key('peer-paste'),
        controller: _paste,
        minLines: 2,
        maxLines: 4,
        decoration: const InputDecoration(
          labelText: 'Paste other device PUBLIC offer or invitation',
        ),
      ),
      TextField(
        key: const Key('peer-confirm'),
        controller: _confirm,
        decoration: const InputDecoration(
          labelText: 'Independently confirmed full remote certificate SHA256 (never autofilled)',
        ),
      ),
      TextField(
        key: const Key('peer-node'),
        controller: _node,
        decoration: const InputDecoration(
          labelText:
              'Exact node grant: digest-0 project metadata / digest-1 captions',
        ),
      ),
      CheckboxListTile(
        key: const Key('peer-consent'),
        value: _consent,
        onChanged: (v) => setState(() => _consent = v ?? false),
        title: const Text(
          'I verified the peer/runtime and permit this exact metadata CPU task (≤64KiB; no model/cloud/paid service). Blob receive requires separate consent.',
        ),
      ),
      CheckboxListTile(
        value: _lan,
        onChanged: (v) => setState(() => _lan = v ?? false),
        title: const Text(
          'Explicitly enable selected LAN IP (no NAT/relay guarantee)',
        ),
      ),
      CheckboxListTile(
        key: const Key('peer-blob-consent'),
        value: _blobConsent,
        onChanged: (v) => setState(() => _blobConsent = v ?? false),
        title: const Text(
          'Separately accept exact incoming blob hash/size in pasted offer (≤16MiB). Inbox only, not automatic project import.',
        ),
      ),
      TextField(
        key: const Key('peer-file'),
        controller: _sourceFile,
        decoration: const InputDecoration(
          labelText: 'Explicit local source file to freeze/offer (path never transmitted)',
        ),
      ),
      OutlinedButton(
        key: const Key('peer-blob-prepare'),
        onPressed: _busy ? null : () => unawaited(_run(_prepareBlob)),
        child: const Text('Freeze selected file + offer public hash/size'),
      ),
      OutlinedButton(
        key: const Key('peer-blob-upload'),
        onPressed: _busy ? null : () => unawaited(_run(_uploadBlob)),
        child: const Text('Send/resume exact granted blob to paired device'),
      ),
      FilledButton(
        key: const Key('peer-host'),
        onPressed: _busy ? null : () => unawaited(_run(_host)),
        child: const Text('Approve peer + start scoped session'),
      ),
      FilledButton(
        key: const Key('peer-work'),
        onPressed: _busy ? null : () => unawaited(_run(_work)),
        child: const Text('Run invited task on this device'),
      ),
      OutlinedButton(
        key: const Key('peer-local'),
        onPressed: _busy
            ? null
            : () => unawaited(
                _run(() async {
                  final session = _session;
                  if (session == null) {
                    throw const StudioException('SESSION_NOT_STARTED');
                  }
                  final node = _node.text.trim() == 'digest-0'
                      ? 'digest-1'
                      : 'digest-0';
                  final hash = await session.runLocalNode(node);
                  if (mounted) {
                    setState(
                      () => _status =
                          'Local $node candidate $hash; ${session.statuses}',
                    );
                  }
                }),
              ),
        child: const Text('Run other node locally in the SAME session'),
      ),
      OutlinedButton(
        key: const Key('peer-refresh'),
        onPressed: () => setState(
          () => _status = 'Persisted receipts: ${_session?.statuses}',
        ),
        child: const Text('Refresh session receipts'),
      ),
      OutlinedButton(
        key: const Key('peer-list-recovery'),
        onPressed: _busy
            ? null
            : () => unawaited(
                _run(() async {
                  if (_identity == null) {
                    throw const StudioException('IDENTITY_REQUIRED');
                  }
                  final entries = widget.listRecovery(_identity!.fingerprint);
                  setState(() {
                    _recovery.text = entries.isEmpty
                        ? ''
                        : jsonEncode(entries.first);
                    _status =
                        'Owner-bound persisted sessions (choose explicitly): ${jsonEncode(entries)}';
                  });
                }),
              ),
        child: const Text('List saved SAME-session recovery choices'),
      ),
      TextField(
        key: const Key('peer-recovery-choice'),
        controller: _recovery,
        decoration: const InputDecoration(
          labelText: 'Chosen sessionId/planHash JSON (no automatic restore)',
        ),
      ),
      CheckboxListTile(
        key: const Key('peer-recovery-consent'),
        value: _recoveryConsent,
        onChanged: (v) => setState(() => _recoveryConsent = v ?? false),
        title: const Text(
          'Explicitly recover this session and REVOKE every previous peer grant; no automatic permission renewal',
        ),
      ),
      OutlinedButton(
        key: const Key('peer-recover'),
        onPressed: _busy
            ? null
            : () => unawaited(
                _run(() async {
                  if (!_recoveryConsent || _identity == null) {
                    throw const StudioException(
                      'RECOVERY_EXPLICIT_CONSENT_REQUIRED',
                    );
                  }
                  if (_session != null) {
                    throw const StudioException(
                      'SESSION_CLOSE_BEFORE_RECOVERY',
                    );
                  }
                  if (_recovery.text.length > 4096) {
                    throw const StudioException('PEER_INPUT_LIMIT');
                  }
                  final choice =
                      jsonDecode(_recovery.text) as Map<String, dynamic>;
                  if (choice.length != 2) {
                    throw const StudioException('RECOVERY_CHOICE_INVALID');
                  }
                  final recovered = widget.recoverSession(
                    choice['sessionId'] as String,
                    choice['planHash'] as String,
                    _identity!.fingerprint,
                  );
                  setState(() {
                    _session = recovered;
                    _recoveryConsent = false;
                    _consent = false;
                    _blobConsent = false;
                    _status =
                        'Recovered SAME session ${recovered.id}, old grants revoked. No listener or peer authorization restored. ${recovered.statuses}';
                  });
                }),
              ),
        child: const Text('Recover chosen SAME session (no peer renewal)'),
      ),
      OutlinedButton(
        key: const Key('peer-revoke'),
        onPressed: _busy
            ? null
            : () => unawaited(
                _run(() async {
                  final previous = _session;
                  _session = null;
                  await previous?.close();
                  if (mounted) {
                    setState(
                      () => _status = 'Grant revoked; listener closed. Old results are fenced.',
                    );
                  }
                }),
              ),
        child: const Text('Revoke peer and stop listener'),
      ),
    ],
  );
}
