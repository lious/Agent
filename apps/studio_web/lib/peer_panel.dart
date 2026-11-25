import 'dart:async';
import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:studio_contracts/studio_contracts.dart';
import 'package:studio_document/strict_json.dart';

import 'browser_store.dart';
import 'browser_compute.dart';
import 'rtc_peer.dart';

class WebPeerPanel extends StatefulWidget {
  const WebPeerPanel({
    super.key,
    required this.store,
    required this.projectId,
    this.identityDatabase = 'studio-web-rtc-device-v1',
  });
  final BrowserProjectStore store;
  final String projectId, identityDatabase;
  @override
  State<WebPeerPanel> createState() => _WebPeerPanelState();
}

class _WebPeerPanelState extends State<WebPeerPanel> {
  RtcIdentity? _identity;
  RtcPeerLink? _link;
  BrowserComputeCoordinator? _coordinator;
  Map<String, dynamic>? _invitation;
  final _fingerprint = TextEditingController(),
      _signal = TextEditingController(),
      _output = TextEditingController();
  bool _consent = false, _busy = false;
  String _status = 'No identity loaded; no connection or task enabled.';
  Future<void> _run(Future<String> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final message = await action();
      if (mounted) setState(() => _status = message);
    } catch (e) {
      if (mounted) setState(() => _status = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _requireConsent() {
    if (!_consent || _identity == null) {
      throw const StudioException('PEER_EXPLICIT_CONSENT_REQUIRED');
    }
  }

  Map<String, dynamic> _readSignal() => Map<String, dynamic>.from(
    readStrictJson(utf8.encode(_signal.text), maxBytes: 70000) as Map,
  );
  Future<String> _stop() async {
    try {
      await _coordinator?.revoke();
      _coordinator = null;
      return 'Grant durably revoked; transport closed. No authority is restored automatically.';
    } finally {
      _link?.close();
      _link = null;
      _invitation = null;
      _consent = false;
    }
  }

  Widget _button(String key, String label, Future<String> Function() action) =>
      OutlinedButton(
        key: Key(key),
        onPressed: _busy ? null : () => unawaited(_run(action)),
        child: Text(label),
      );
  @override
  Widget build(BuildContext context) => ExpansionTile(
    key: const Key('web-peer-panel'),
    title: const Text('Trusted direct WebRTC session · browser preview'),
    children: [
      const Text(
        'Browser↔browser only; native bridge not installed. Manual signaling, host-only ICE, NO STUN/TURN/cloud fallback. Share address-bearing SDP only with the independently confirmed device. Foreground metadata-only free CPU tasks; not media/model execution or physical-device qualification.',
      ),
      _button('rtc-identity', 'Load/create persistent browser DTLS identity', () async {
        _identity = await RtcIdentity.loadOrCreate(widget.identityDatabase);
        return 'Browser identity loaded. Independently compare FULL SHA256 on both devices.';
      }),
      SelectableText(
        _identity?.fingerprint ?? '',
        key: const Key('rtc-fingerprint'),
      ),
      TextField(
        key: const Key('rtc-confirmed-fingerprint'),
        controller: _fingerprint,
        enabled: !_busy && _link == null,
        decoration: const InputDecoration(
          labelText: 'Independently confirmed remote FULL SHA256 (not just copied from SDP)',
        ),
      ),
      CheckboxListTile(
        key: const Key('rtc-consent'),
        value: _consent,
        onChanged: _busy
            ? null
            : (v) {
                setState(() => _consent = v ?? false);
                if (v != true && _link != null) unawaited(_run(_stop));
              },
        title: const Text(
          'Explicitly allow this device to exchange frozen project metadata for the selected two-node session',
        ),
      ),
      _button(
        'rtc-offer',
        'Owner: approve peer + create manual offer',
        () async {
          _requireConsent();
          if (_link != null || _coordinator != null) {
            throw const StudioException('RTC_SIGNALING_STATE');
          }
          final fp = normalizeFingerprint(_fingerprint.text.trim());
          final c = await BrowserComputeCoordinator.create(
            widget.store,
            widget.projectId,
            _identity!.fingerprint,
          );
          _coordinator = c;
          await c.approve(fp, metadataConsent: _consent);
          final link = RtcPeerLink(_identity!);
          _link = link;
          link.onRequest = c.executePeerRequest;
          _output.text = jsonEncode({
            'rtc': await link.createOffer(),
            'invitation': c.invitation(),
          });
          return 'Owner offer ready. Send manually; no remote task has run.';
        },
      ),
      TextField(
        key: const Key('rtc-input'),
        controller: _signal,
        enabled: !_busy,
        minLines: 2,
        maxLines: 5,
        decoration: const InputDecoration(
          labelText: 'Paste paired device public signaling JSON',
        ),
      ),
      _button('rtc-answer', 'Worker: verify owner + create manual answer', () async {
        _requireConsent();
        if (_link != null) throw const StudioException('RTC_SIGNALING_STATE');
        final signal = _readSignal();
        if (signal.length != 2 ||
            signal['rtc'] is! Map ||
            signal['invitation'] is! Map) {
          throw const StudioException('RTC_PROTOCOL');
        }
        final invite = Map<String, dynamic>.from(signal['invitation'] as Map);
        if (invite['runtimePin'] != browserRuntimePin) {
          throw const StudioException('RUNTIME_PIN_MISMATCH');
        }
        final link = RtcPeerLink(_identity!);
        _link = link;
        try {
          final answer = await link.answer(
            Map<String, dynamic>.from(signal['rtc'] as Map),
            independentlyConfirmedFingerprint: _fingerprint.text.trim(),
          );
          _invitation = invite;
          _output.text = jsonEncode({'rtc': answer});
        } catch (_) {
          link.close();
          _link = null;
          rethrow;
        }
        return 'Verified answer ready. Send manually to owner; then explicitly run the invited node.';
      }),
      _button('rtc-connect', 'Owner: verify answer + connect', () async {
        _requireConsent();
        if (_coordinator == null || _link == null) {
          throw const StudioException('RTC_SIGNALING_STATE');
        }
        final answer = _readSignal();
        if (answer.length != 1 || answer['rtc'] is! Map) {
          throw const StudioException('RTC_PROTOCOL');
        }
        await _link!.acceptAnswer(
          Map<String, dynamic>.from(answer['rtc'] as Map),
          independentlyConfirmedFingerprint: _fingerprint.text.trim(),
        );
        await _link!.waitReady();
        return 'Authenticated DTLS direct channel open. No relay fallback.';
      }),
      TextField(
        key: const Key('rtc-output'),
        controller: _output,
        readOnly: true,
        minLines: 2,
        maxLines: 5,
        decoration: const InputDecoration(
          labelText: 'Public signaling output (manual exchange; includes address hints)',
        ),
      ),
      _button(
        'rtc-run-remote',
        'Worker: execute approved node on THIS device',
        () async {
          _requireConsent();
          if (_link == null || _invitation == null) {
            throw const StudioException('RTC_SIGNALING_STATE');
          }
          final receipt = await runBrowserPeerDigest(
            _link!,
            _invitation!,
            operationId: newPeerId(),
            metadataConsent: _consent,
          );
          return 'Remote node committed to owner SAME session: $receipt';
        },
      ),
      _button('rtc-run-local', 'Owner: run second node in SAME session', () async {
        if (_coordinator == null) {
          throw const StudioException('RTC_SIGNALING_STATE');
        }
        return 'Local node committed SAME session: ${await _coordinator!.runLocal()}';
      }),
      _button('rtc-receipts', 'Read durable session receipts', () async {
        if (_coordinator == null) {
          throw const StudioException('RTC_SIGNALING_STATE');
        }
        final s = await _coordinator!.status();
        return 'SAME session ${_coordinator!.id}: ${(s['steps'] as Map).map((k, v) => MapEntry(k, v['state']['status']))}; candidates=${(s['outbox'] as Map).length}';
      }),
      _button('rtc-history', 'Inspect saved session receipts (read-only)', () async {
        if (_identity == null) {
          throw const StudioException('PEER_EXPLICIT_CONSENT_REQUIRED');
        }
        final history = await widget.store.peerTransaction(
          widget.projectId,
          (_, r) => {
            'sessions': {
              for (final e in (r['sessions'] as Map).entries)
                if (e.value['owner'] == _identity!.fingerprint &&
                    e.value['projectId'] == widget.projectId)
                  e.key: {
                    'planHash': e.value['planHash'],
                    'revoked': e.value['grant']?['revoked'],
                    'candidates': (e.value['outbox'] as Map).length,
                  },
            },
          },
        );
        return 'Saved receipts only; NO coordinator/permission resumed: ${jsonEncode(history)}';
      }),
      _button('rtc-revoke', 'Revoke session + close direct connection', _stop),
      SelectableText(_status, key: const Key('rtc-status')),
    ],
  );
  @override
  void dispose() {
    _link?.close();
    _fingerprint.dispose();
    _signal.dispose();
    _output.dispose();
    super.dispose();
  }
}
