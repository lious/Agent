import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:studio_contracts/studio_contracts.dart';
import 'package:uuid/uuid.dart';

String publicCertificateFingerprint(String pem) {
  final match = RegExp(
    r'^-----BEGIN CERTIFICATE-----\s+([A-Za-z0-9+/=\s]+)-----END CERTIFICATE-----\s*$',
  ).firstMatch(pem);
  if (match == null || pem.length > 16384) {
    throw const StudioException('IDENTITY_CERTIFICATE_INVALID');
  }
  try {
    return sha256
        .convert(base64.decode(match[1]!.replaceAll(RegExp(r'\s'), '')))
        .toString();
  } catch (_) {
    throw const StudioException('IDENTITY_CERTIFICATE_INVALID');
  }
}

/// Real OS Secret Service/Keychain plugin, not a plaintext-file fallback. Initial
/// generation currently Linux/OpenSSL only. Private PEM is confined to process
/// memory and the OS store; it is NEVER in export, project DB, arguments or logs.
/// This is encrypted at-rest storage, not a nonextractable hardware-backed key.
final class NativeIdentity {
  NativeIdentity._(
    this.deviceId,
    this.bindAddress,
    this.certificatePem,
    this._key,
  );
  final String deviceId, bindAddress, certificatePem, _key;
  String get fingerprint => publicCertificateFingerprint(certificatePem);
  Map<String, Object> publicOffer() => {
    'schemaVersion': '1.0.0',
    'deviceId': deviceId,
    'certificatePem': certificatePem,
    'fingerprint': fingerprint,
  };
  static Future<void> _queue = Future<void>.value();
  static Future<NativeIdentity> open({
    required String storageScope,
    required String lockPath,
    required String bindAddress,
  }) async {
    if (!Platform.isLinux) {
      throw const StudioException('IDENTITY_PLATFORM_NOT_QUALIFIED');
    }
    if (InternetAddress.tryParse(bindAddress) == null ||
        storageScope.length > 128) {
      throw const StudioException('IDENTITY_SCOPE_INVALID');
    }
    final key =
        'studio.peer.identity.v1.${sha256.convert(utf8.encode(storageScope))}';
    final prior = _queue, done = Completer<void>();
    _queue = done.future;
    await prior;
    RandomAccessFile? lock;
    var locked = false;
    try {
      final file = File(lockPath);
      await file.parent.create(recursive: true);
      lock = await file.open(mode: FileMode.append);
      await lock.lock(FileLock.blockingExclusive);
      locked = true;
      const storage = FlutterSecureStorage();
      final existing = await storage.read(key: key);
      if (existing != null) {
        final data = jsonDecode(existing) as Map<String, dynamic>;
        if (data['schemaVersion'] != '1.0.0' ||
            data['scope'] != storageScope ||
            data['bindAddress'] != bindAddress) {
          throw const StudioException('IDENTITY_SCOPE_OR_ADDRESS_CHANGED');
        }
        final identity = NativeIdentity._(
          data['deviceId'] as String,
          bindAddress,
          data['certificatePem'] as String,
          data['privateKeyPem'] as String,
        );
        identity.context();
        return identity;
      }
      final id = 'device-${const Uuid().v4()}';
      final generated = await Process.run('openssl', [
        'genpkey',
        '-algorithm',
        'EC',
        '-pkeyopt',
        'ec_paramgen_curve:P-256',
      ]).timeout(const Duration(seconds: 15));
      if (generated.exitCode != 0) {
        throw const StudioException('IDENTITY_GENERATION_FAILED');
      }
      final privateKey = generated.stdout as String;
      final process = await Process.start('openssl', [
        'req',
        '-new',
        '-x509',
        '-key',
        '/dev/stdin',
        '-sha256',
        '-days',
        '365',
        '-subj',
        '/CN=$id',
        '-addext',
        'basicConstraints=critical,CA:FALSE',
        '-addext',
        'extendedKeyUsage=serverAuth,clientAuth',
        '-addext',
        'subjectAltName=IP:$bindAddress',
      ]);
      final certificate = process.stdout.transform(utf8.decoder).join(),
          discarded = process.stderr.drain<void>();
      process.stdin.write(privateKey);
      await process.stdin.close();
      final exit = await process.exitCode.timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          process.kill();
          return -1;
        },
      );
      await discarded;
      if (exit != 0) throw const StudioException('IDENTITY_GENERATION_FAILED');
      final identity = NativeIdentity._(
        id,
        bindAddress,
        await certificate,
        privateKey,
      );
      identity.context();
      final stored = jsonEncode({
        'schemaVersion': '1.0.0',
        'scope': storageScope,
        'deviceId': id,
        'bindAddress': bindAddress,
        'certificatePem': identity.certificatePem,
        'privateKeyPem': privateKey,
      });
      await storage.write(key: key, value: stored);
      // ACK only after actual OS storage readback. Never replace a locked/corrupt
      // identity with a fresh one, nor fall back to a plaintext project file.
      if (await storage.read(key: key) != stored) {
        throw const StudioException('IDENTITY_STORE_WRITE_FAILED');
      }
      return identity;
    } on StudioException {
      rethrow;
    } catch (_) {
      throw const StudioException('IDENTITY_STORE_OR_GENERATION_UNAVAILABLE');
    } finally {
      try {
        if (lock != null) {
          try {
            if (locked) await lock.unlock();
          } finally {
            await lock.close();
          }
        }
      } finally {
        done.complete();
      }
    }
  }

  SecurityContext context({List<String> trustedCertificates = const []}) {
    final context = SecurityContext(withTrustedRoots: false)
      ..useCertificateChainBytes(utf8.encode(certificatePem))
      ..usePrivateKeyBytes(utf8.encode(_key));
    for (final pem in trustedCertificates) {
      publicCertificateFingerprint(pem);
      context.setTrustedCertificatesBytes(utf8.encode(pem));
      context.setClientAuthoritiesBytes(utf8.encode(pem));
    }
    return context;
  }
}
