import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

import 'package:web/web.dart' as web;
import 'package:studio_contracts/studio_contracts.dart';
import 'package:studio_document/strict_json.dart';

/// Browser-managed, origin-scoped DTLS private-key HANDLE, never exported PEM.
/// Evicted/expired identity is not silently replaced with a new trusted identity.
final class RtcIdentity {
  RtcIdentity._(this.certificate);
  final web.RTCCertificate certificate;
  String get fingerprint {
    final values = certificate
        .getFingerprints()
        .toDart
        .where((f) => f.algorithm == 'sha-256')
        .toList();
    if (values.length != 1) {
      throw const StudioException('RTC_SHA256_UNAVAILABLE');
    }
    return normalizeFingerprint(values.single.value);
  }

  static Future<RtcIdentity> loadOrCreate(String database) async {
    final c = Completer<web.IDBDatabase>(),
        request = web.window.indexedDB.open(database, 1);
    request.onupgradeneeded = ((web.Event _) {
      (request.result as web.IDBDatabase).createObjectStore('identity');
    }).toJS;
    request.onsuccess = ((web.Event _) {
      final db = request.result as web.IDBDatabase;
      if (c.isCompleted) {
        db.close();
        return;
      }
      c.complete(db);
    }).toJS;
    request.onerror = ((web.Event _) {
      if (!c.isCompleted) {
        c.completeError(const StudioException('RTC_IDENTITY_STORAGE_FAILED'));
      }
    }).toJS;
    request.onblocked = ((web.Event _) {
      if (!c.isCompleted) {
        c.completeError(const StudioException('RTC_IDENTITY_STORAGE_BLOCKED'));
      }
    }).toJS;
    final db = await c.future;
    try {
      final read = Completer<web.RTCCertificate?>(),
          r = db
              .transaction('identity'.toJS)
              .objectStore('identity')
              .get('certificate'.toJS);
      r.onsuccess = ((web.Event _) {
        read.complete(r.result as web.RTCCertificate?);
      }).toJS;
      r.onerror = ((web.Event _) {
        read.completeError(
          const StudioException('RTC_IDENTITY_STORAGE_FAILED'),
        );
      }).toJS;
      final old = await read.future;
      if (old != null) return _validate(old);
      final generated = await web.RTCPeerConnection.generateCertificate(
        {'name': 'ECDSA', 'namedCurve': 'P-256'}.jsify()!,
      ).toDart;
      final done = Completer<RtcIdentity>(),
          tx = db.transaction(
            'identity'.toJS,
            'readwrite',
            web.IDBTransactionOptions(durability: 'strict'),
          );
      final store = tx.objectStore('identity'),
          again = store.get('certificate'.toJS);
      web.RTCCertificate? chosen;
      Object? error;
      again.onsuccess = ((web.Event _) {
        try {
          chosen = again.result as web.RTCCertificate? ?? generated;
          _validate(chosen!);
          if (again.result == null) store.put(chosen, 'certificate'.toJS);
        } catch (e) {
          error = e;
          tx.abort();
        }
      }).toJS;
      tx.oncomplete = ((web.Event _) {
        done.complete(_validate(chosen!));
      }).toJS;
      void abort(web.Event _) {
        if (!done.isCompleted) {
          done.completeError(
            error ?? const StudioException('RTC_IDENTITY_STORAGE_FAILED'),
          );
        }
      }

      tx.onabort = abort.toJS;
      tx.onerror = abort.toJS;
      return await done.future;
    } finally {
      db.close();
    }
  }

  static RtcIdentity _validate(web.RTCCertificate cert) {
    if (cert.expires <= DateTime.now().millisecondsSinceEpoch) {
      throw const StudioException('RTC_IDENTITY_EXPIRED');
    }
    final id = RtcIdentity._(cert);
    id.fingerprint;
    return id;
  }
}

String normalizeFingerprint(String value) {
  final v = value.replaceAll(':', '').toLowerCase();
  if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(v)) {
    throw const StudioException('RTC_FINGERPRINT_INVALID');
  }
  return v;
}

/// Real WebRTC DTLS/SCTP, MANUAL signaling and host-only ICE. No relay/STUN,
/// anonymous socket, custom encryption or native mTLS emulation.
final class RtcPeerLink {
  RtcPeerLink(this.identity)
    : _pc = web.RTCPeerConnection(
        web.RTCConfiguration(
          iceServers: <web.RTCIceServer>[].toJS,
          certificates: [identity.certificate].toJS,
        ),
      ) {
    _pc.ondatachannel = ((web.RTCDataChannelEvent event) {
      _attach(event.channel);
    }).toJS;
    _pc.onconnectionstatechange = ((web.Event _) {
      if (['failed', 'closed'].contains(_pc.connectionState)) close();
    }).toJS;
  }
  final RtcIdentity identity;
  final web.RTCPeerConnection _pc;
  web.RTCDataChannel? _channel;
  String? _remoteFingerprint;
  bool _closed = false;
  int _queued = 0;
  Future<void> _tail = Future.value();
  final _opened = Completer<void>();
  final _pending = <String, Completer<Map<String, dynamic>>>{};
  Future<Map<String, dynamic>> Function(String, Map<String, dynamic>)?
  onRequest;
  String? get remoteFingerprint => _remoteFingerprint;
  bool get isOpen => !_closed && _channel?.readyState == 'open';
  Map<String, Object?> get diagnostics => {
    'closed': _closed,
    'connection': _pc.connectionState,
    'ice': _pc.iceConnectionState,
    'gathering': _pc.iceGatheringState,
    'signaling': _pc.signalingState,
    'channel': _channel?.readyState,
    'localHostCandidates': RegExp(
      r'^a=candidate:',
      multiLine: true,
    ).allMatches(_pc.localDescription?.sdp ?? '').length,
    'remoteHostCandidates': RegExp(
      r'^a=candidate:',
      multiLine: true,
    ).allMatches(_pc.remoteDescription?.sdp ?? '').length,
  };
  bool get usesNoIceServers => _pc.getConfiguration().iceServers.toDart.isEmpty;
  void _attach(web.RTCDataChannel channel) {
    if (_closed ||
        _channel != null ||
        channel.label != 'studio-peer-v1' ||
        !channel.ordered) {
      channel.close();
      close();
      return;
    }
    _channel = channel;
    channel.onopen = ((web.Event _) {
      if (_remoteFingerprint == null) {
        close();
        return;
      }
      if (!_opened.isCompleted) _opened.complete();
    }).toJS;
    channel.onclose = ((web.Event _) {
      close();
    }).toJS;
    channel.onerror = ((web.Event _) {
      close();
    }).toJS;
    channel.onmessage = ((web.MessageEvent e) {
      try {
        if (_remoteFingerprint == null || e.data?.isA<JSString>() != true) {
          throw const StudioException('RTC_PROTOCOL');
        }
        final text = (e.data as JSString).toDart;
        if (text.length > 65536) throw const StudioException('RTC_FRAME_LIMIT');
        final frame = readStrictJson(
          utf8.encode(text),
          maxBytes: 65536,
        ) as Map<String, dynamic>;
        if (frame.length != 3 ||
            !frame.keys.toSet().containsAll({'kind', 'id', 'body'}) ||
            frame['id'] is! String ||
            frame['body'] is! Map) {
          throw const StudioException('RTC_PROTOCOL');
        }
        final id = frame['id'] as String;
        requireId(id);
        if (frame['kind'] == 'response') {
          _pending
              .remove(id)
              ?.complete(Map<String, dynamic>.from(frame['body'] as Map));
          return;
        }
        if ((frame['body'] as Map)['id'] != id) {
          throw const StudioException('RTC_PROTOCOL');
        }
        if (frame['kind'] != 'request' || ++_queued > 8) {
          throw const StudioException('RTC_QUEUE_LIMIT');
        }
        _tail = _tail
            .then((_) async {
              try {
                Map<String, dynamic> response;
                try {
                  if (_closed || onRequest == null) {
                    throw const StudioException('RTC_NOT_AUTHORIZED');
                  }
                  response = {
                    'ok': true,
                    'value': await onRequest!(
                      _remoteFingerprint!,
                      Map<String, dynamic>.from(frame['body'] as Map),
                    ),
                  };
                } on StudioException catch (e) {
                  response = {'ok': false, 'code': e.code};
                } catch (_) {
                  response = {'ok': false, 'code': 'RTC_REQUEST_FAILED'};
                }
                if (!_closed) _send('response', id, response);
              } finally {
                _queued--;
              }
            })
            .catchError((Object _) {
              close();
            });
      } catch (_) {
        close();
      }
    }).toJS;
  }

  Map<String, dynamic> _description() => {
    'protocolVersion': 'studio-rtc-1',
    'type': _pc.localDescription!.type,
    'sdp': _pc.localDescription!.sdp,
    'fingerprint': identity.fingerprint,
  };
  Future<void> _gather() async {
    final deadline = DateTime.now().add(const Duration(seconds: 10));
    while (_pc.iceGatheringState != 'complete') {
      if (_closed || DateTime.now().isAfter(deadline)) {
        close();
        throw const StudioException('RTC_ICE_DIRECT_UNREACHABLE');
      }
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    if (_closed) throw const StudioException('RTC_CLOSED');
  }

  Future<Map<String, dynamic>> createOffer() async {
    if (_closed || _channel != null) {
      throw const StudioException('RTC_SIGNALING_STATE');
    }
    _attach(
      _pc.createDataChannel(
        'studio-peer-v1',
        web.RTCDataChannelInit(ordered: true),
      ),
    );
    final offer = await _pc.createOffer().toDart;
    await _pc
        .setLocalDescription(
          web.RTCLocalSessionDescriptionInit(type: offer!.type, sdp: offer.sdp),
        )
        .toDart;
    await _gather();
    if ((diagnostics['localHostCandidates'] as int) == 0) {
      close();
      throw const StudioException('RTC_DIRECT_CANDIDATES_UNAVAILABLE');
    }
    return _description();
  }

  static void verifyDescription(
    Map<String, dynamic> value,
    String confirmed,
    String type,
  ) {
    if (value.length != 4 ||
        !value.keys.toSet().containsAll({
          'protocolVersion',
          'type',
          'sdp',
          'fingerprint',
        }) ||
        value['fingerprint'] is! String ||
        value['protocolVersion'] != 'studio-rtc-1' ||
        value['type'] != type ||
        value['sdp'] is! String) {
      throw const StudioException('RTC_PROTOCOL');
    }
    final pin = normalizeFingerprint(confirmed);
    if (pin != normalizeFingerprint(value['fingerprint'] as String)) {
      throw const StudioException('RTC_FINGERPRINT_MISMATCH');
    }
    final sdp = value['sdp'] as String;
    if (utf8.encode(sdp).length > 65536) {
      throw const StudioException('RTC_SDP_LIMIT');
    }
    final fps = RegExp(
      r'^a=fingerprint:([^ ]+) ([^\r\n]+)',
      multiLine: true,
    ).allMatches(sdp).toList();
    if (fps.isEmpty ||
        fps.any(
          (f) => f[1] != 'sha-256' || normalizeFingerprint(f[2]!) != pin,
        )) {
      throw const StudioException('RTC_FINGERPRINT_MISMATCH');
    }
    final media = RegExp(
      r'^m=([^ ]+)',
      multiLine: true,
    ).allMatches(sdp).toList();
    if (media.length != 1 ||
        media.single[1] != 'application' ||
        RegExp(
          r'^a=candidate:.* typ (?!host(?: |\r?$))',
          multiLine: true,
        ).hasMatch(sdp) ||
        sdp.contains('a=ice-lite')) {
      throw const StudioException('RTC_DIRECT_ONLY_REQUIRED');
    }
  }

  Future<Map<String, dynamic>> answer(
    Map<String, dynamic> offer, {
    required String independentlyConfirmedFingerprint,
  }) async {
    if (_closed || _remoteFingerprint != null) {
      throw const StudioException('RTC_SIGNALING_STATE');
    }
    verifyDescription(offer, independentlyConfirmedFingerprint, 'offer');
    _remoteFingerprint = normalizeFingerprint(
      independentlyConfirmedFingerprint,
    );
    await _pc
        .setRemoteDescription(
          web.RTCSessionDescriptionInit(
            type: 'offer',
            sdp: offer['sdp'] as String,
          ),
        )
        .toDart;
    final answer = await _pc.createAnswer().toDart;
    await _pc
        .setLocalDescription(
          web.RTCLocalSessionDescriptionInit(
            type: answer!.type,
            sdp: answer.sdp,
          ),
        )
        .toDart;
    await _gather();
    if ((diagnostics['localHostCandidates'] as int) == 0) {
      close();
      throw const StudioException('RTC_DIRECT_CANDIDATES_UNAVAILABLE');
    }
    return _description();
  }

  Future<void> acceptAnswer(
    Map<String, dynamic> answer, {
    required String independentlyConfirmedFingerprint,
  }) async {
    if (_closed || _remoteFingerprint != null) {
      throw const StudioException('RTC_SIGNALING_STATE');
    }
    verifyDescription(answer, independentlyConfirmedFingerprint, 'answer');
    _remoteFingerprint = normalizeFingerprint(
      independentlyConfirmedFingerprint,
    );
    await _pc
        .setRemoteDescription(
          web.RTCSessionDescriptionInit(
            type: 'answer',
            sdp: answer['sdp'] as String,
          ),
        )
        .toDart;
  }

  Future<void> waitReady() async {
    if (_closed) throw const StudioException('RTC_CLOSED');
    await _opened.future.timeout(
      const Duration(seconds: 15),
      onTimeout: () {
        close();
        throw const StudioException('RTC_ICE_DIRECT_UNREACHABLE');
      },
    );
    if (!isOpen) throw const StudioException('RTC_CLOSED');
  }

  void _send(String kind, String id, Map<String, dynamic> body) {
    if (!isOpen) throw const StudioException('RTC_CLOSED');
    final encoded = jsonEncode({'kind': kind, 'id': id, 'body': body});
    final encodedBytes = utf8.encode(encoded).length;
    if (encodedBytes > 65536 ||
        _channel!.bufferedAmount + encodedBytes > 256 * 1024) {
      throw const StudioException('RTC_BACKPRESSURE');
    }
    _channel!.send(encoded.toJS);
  }

  Future<Map<String, dynamic>> request(Map<String, dynamic> request) async {
    await waitReady();
    final id = request['id'] as String;
    requireId(id);
    if (_pending.containsKey(id) || _pending.length >= 8) {
      throw const StudioException('RTC_REQUEST_BUSY');
    }
    final c = Completer<Map<String, dynamic>>();
    _pending[id] = c;
    try {
      _send('request', id, request);
      final response = await c.future.timeout(const Duration(seconds: 10));
      if (response['ok'] != true) {
        throw StudioException(response['code'] as String? ?? 'RTC_PROTOCOL');
      }
      return Map<String, dynamic>.from(response['value'] as Map);
    } finally {
      _pending.remove(id);
    }
  }

  void close() {
    if (_closed) return;
    _closed = true;
    if (!_opened.isCompleted) _opened.complete();
    _channel?.close();
    _pc.close();
    for (final c in _pending.values) {
      if (!c.isCompleted) c.completeError(const StudioException('RTC_CLOSED'));
    }
    _pending.clear();
  }
}
