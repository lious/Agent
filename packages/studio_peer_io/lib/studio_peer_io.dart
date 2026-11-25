/// Native HTTPS adapter. Pure document/Harness and Web never import dart:io.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:studio_store/studio_store.dart';

String certificateFingerprint(X509Certificate certificate) =>
    sha256.convert(certificate.der).toString();

void _boundedJson(Object? root) {
  final pending = <(Object?, int)>[(root, 0)];
  var count = 0;
  while (pending.isNotEmpty) {
    final (value, depth) = pending.removeLast();
    if (++count > 100000 || depth > 32) {
      throw const StudioException('PEER_INPUT_LIMIT');
    }
    if (value is Map) {
      if (value.length > 10000) throw const StudioException('PEER_INPUT_LIMIT');
      for (final entry in value.entries) {
        if (entry.key is! String || (entry.key as String).length > 128) {
          throw const StudioException('PEER_INPUT_LIMIT');
        }
        pending.add((entry.value, depth + 1));
      }
    } else if (value is List) {
      if (value.length > 480000) {
        throw const StudioException('PEER_INPUT_LIMIT');
      }
      for (final item in value) {
        pending.add((item, depth + 1));
      }
    } else if (value is num && !value.isFinite) {
      throw const StudioException('PEER_INPUT_LIMIT');
    } else if (value is String && value.length > 1024 * 1024) {
      throw const StudioException('PEER_INPUT_LIMIT');
    }
  }
}

Future<List<int>> _readBounded(
  Stream<List<int>> stream,
  int maximum,
  Duration timeout,
) async {
  final iterator = StreamIterator(stream),
      clock = Stopwatch()..start(),
      bytes = <int>[];
  try {
    while (true) {
      final remaining = timeout - clock.elapsed;
      if (remaining <= Duration.zero) {
        throw TimeoutException('Peer body deadline');
      }
      if (!await iterator.moveNext().timeout(remaining)) break;
      if (bytes.length + iterator.current.length > maximum) {
        throw const StudioException('PEER_INPUT_LIMIT');
      }
      bytes.addAll(iterator.current);
    }
    return bytes;
  } finally {
    await iterator.cancel();
  }
}

/// The host provides a context with identity key + trusted client CA/certificates.
/// No badCertificateCallback, anonymous task route, pairing route, HTTP listener,
/// TLS termination proxy/header identity, discovery or relay fallback exists.
/// Keys must remain in platform-owned identity storage. PEM is test-only here;
/// OS keystore integration is a separate platform qualification gate.
final class PeerTlsServer {
  PeerTlsServer._(
    this._server,
    this._repository,
    this.coordinatorBoot,
    this._clock,
    this._wallClock,
    this._inputs,
  ) {
    _server.listen((request) {
      unawaited(_handle(request));
    }, onError: (Object error) {});
  }
  final HttpServer _server;
  final DocumentRepository _repository;
  final String coordinatorBoot;
  final int Function() _clock, _wallClock;
  final Map<String, Object?> _inputs;
  int _active = 0;
  int get port => _server.port;
  static Future<PeerTlsServer> bind({
    required DocumentRepository repository,
    required SecurityContext context,
    required String coordinatorBoot,
    required int Function() monotonicMs,
    required int Function() wallMs,
    required Map<String, Object?> inputsByHash,
    InternetAddress? address,
    int port = 0,
    bool allowLan = false,
  }) async {
    context.minimumTlsProtocolVersion = TlsProtocolVersion.tls1_2;
    final bindAddress = address ?? InternetAddress.loopbackIPv4;
    if (!bindAddress.isLoopback && !allowLan) {
      throw const StudioException('PEER_LAN_NOT_ENABLED');
    }
    // Freeze inputs; do not let caller mutation change a hash-bound response.
    final inputs = jsonDecode(jsonEncode(inputsByHash)) as Map<String, dynamic>;
    _boundedJson(inputs);
    final server = await HttpServer.bindSecure(
      bindAddress,
      port,
      context,
      requestClientCertificate: true,
    );
    server.idleTimeout = const Duration(seconds: 10);
    return PeerTlsServer._(
      server,
      repository,
      coordinatorBoot,
      monotonicMs,
      wallMs,
      Map.unmodifiable(inputs),
    );
  }

  Future<void> close() => _server.close(force: true);
  Future<void> _handle(HttpRequest request) async {
    var admitted = false;
    try {
      if (request.certificate == null) {
        throw const StudioException('PEER_CERTIFICATE_REQUIRED');
      }
      if (request.method != 'POST' ||
          request.uri.path != '/studio/peer/v1' ||
          request.uri.hasQuery) {
        throw const StudioException('PEER_ROUTE_NOT_ALLOWED');
      }
      if (request.headers.contentType?.mimeType != 'application/json') {
        throw const StudioException('PEER_CONTENT_TYPE');
      }
      if (_active >= 4) throw const StudioException('PEER_BUSY');
      _active++;
      admitted = true;
      final bytes = await _readBounded(
        request,
        1024 * 1024,
        const Duration(seconds: 5),
      );
      final body = jsonDecode(utf8.decode(bytes));
      _boundedJson(body);
      if (body is! Map<String, dynamic>) {
        throw const StudioException('PEER_SCHEMA');
      }
      final response = _repository.executePeerRequest(
        certificateFingerprint(request.certificate!),
        body,
        coordinatorBoot: coordinatorBoot,
        nowMs: _clock(),
        wallMs: _wallClock(),
        inputsByHash: _inputs,
      );
      request.response.headers.contentType = ContentType.json;
      request.response.headers.set(HttpHeaders.cacheControlHeader, 'no-store');
      request.response.write(jsonEncode({'ok': true, 'value': response}));
    } catch (error) {
      request.response.statusCode = error is StudioException ? 403 : 400;
      request.response.headers.contentType = ContentType.json;
      // Never leak database paths, PEM, TLS keys, raw request or internal stack.
      request.response.write(
        jsonEncode({
          'ok': false,
          'error': error is StudioException
              ? error.code
              : 'PEER_INVALID_REQUEST',
        }),
      );
    } finally {
      if (admitted) _active--;
      try {
        await request.response.close();
      } on Exception {
        /* disconnected peer */
      }
    }
  }
}

/// Pinned mutually authenticated HTTPS client. Only caller-selected direct URL;
/// no redirect, proxy, HTTP downgrade, cloud relay or certificate bypass.
final class PeerTlsClient {
  PeerTlsClient({
    required SecurityContext context,
    required this.endpoint,
    required this.serverFingerprint,
  }) : _client = HttpClient(context: context) {
    if (endpoint.scheme != 'https' ||
        endpoint.host.isEmpty ||
        !endpoint.hasAuthority ||
        endpoint.userInfo.isNotEmpty ||
        endpoint.hasQuery ||
        endpoint.hasFragment ||
        endpoint.path != '/studio/peer/v1' ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(serverFingerprint)) {
      throw const StudioException('PEER_ENDPOINT_INVALID');
    }
    context.minimumTlsProtocolVersion = TlsProtocolVersion.tls1_2;
    _client.findProxy = (_) => 'DIRECT';
    _client.connectionFactory = (uri, proxyHost, proxyPort) async {
      if (proxyHost != null ||
          proxyPort != null ||
          uri.host != endpoint.host ||
          uri.port != endpoint.port ||
          uri.scheme != 'https') {
        throw const StudioException('PEER_ENDPOINT_INVALID');
      }
      final task = await SecureSocket.startConnect(
        uri.host,
        uri.port,
        context: context,
      );
      final verified = task.socket.then((socket) {
        final certificate = socket.peerCertificate;
        if (certificate == null ||
            certificateFingerprint(certificate) != serverFingerprint) {
          socket.destroy();
          throw const StudioException('PEER_SERVER_PIN_MISMATCH');
        }
        return socket;
      });
      return ConnectionTask.fromSocket(verified, task.cancel);
    };
    _client.connectionTimeout = const Duration(seconds: 5);
    _client.autoUncompress = false;
  }
  final HttpClient _client;
  final Uri endpoint;
  final String serverFingerprint;
  void close() => _client.close(force: true);
  Future<Map<String, dynamic>> send(Map<String, dynamic> message) async {
    _boundedJson(message);
    final encoded = utf8.encode(jsonEncode(message));
    if (encoded.length > 1024 * 1024) {
      throw const StudioException('PEER_INPUT_LIMIT');
    }
    try {
      // The connectionFactory returns only a successfully validated/pinned TLS
      // socket, before HttpClient can write ANY HTTP header or task bytes.
      final request = await _client.postUrl(endpoint);
      request.followRedirects = false;
      request.headers.contentType = ContentType.json;
      request.add(encoded);
      final response = await request.close().timeout(
        const Duration(seconds: 10),
      );
      final bytes = await _readBounded(
        response,
        2 * 1024 * 1024,
        const Duration(seconds: 5),
      );
      final value = jsonDecode(utf8.decode(bytes));
      _boundedJson(value);
      if (value is! Map<String, dynamic>) {
        throw const StudioException('PEER_SCHEMA');
      }
      if (response.statusCode != 200 || value['ok'] != true) {
        throw StudioException(
          value['error'] is String
              ? value['error'] as String
              : 'PEER_REQUEST_REJECTED',
        );
      }
      return value['value'] as Map<String, dynamic>;
    } on SocketException {
      throw const StudioException('DIRECT_UNREACHABLE');
    } on HandshakeException {
      throw const StudioException('PEER_TLS_REJECTED');
    } on TimeoutException {
      throw const StudioException('DIRECT_UNREACHABLE');
    }
  }
}
