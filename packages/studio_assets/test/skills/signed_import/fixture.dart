// TEST ONLY: public deterministic signing material, not user credentials.
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:studio_assets/craft/signed_import/importer.dart';
import 'package:studio_assets/craft/signed_import/strict_json.dart';

Map<String, dynamic> clone(Map<String, dynamic> x) =>
    jsonDecode(jsonEncode(x)) as Map<String, dynamic>;
const ns = {'appId': 'studio', 'tenantId': 'test', 'workspaceId': 'local'};

final class FixtureSigner {
  FixtureSigner(int fixtureNumber) {
    final lock = jsonDecode(
      File('third_party/sodium/backend-lock.json').readAsStringSync(),
    ) as Map;
    _lib = DynamicLibrary.open(
      Platform.environment['STUDIO_SODIUM_LIBRARY'] ??
          lock['devBinary'] as String,
    );
    _pk = calloc<Uint8>(32);
    _sk = calloc<Uint8>(64);
    final seed = calloc<Uint8>(32);
    try {
      seed
          .asTypedList(32)
          .setAll(0, List.generate(32, (i) => (i + fixtureNumber) % 256));
      final make = _lib
          .lookupFunction<
            Int32 Function(Pointer<Uint8>, Pointer<Uint8>, Pointer<Uint8>),
            int Function(Pointer<Uint8>, Pointer<Uint8>, Pointer<Uint8>)
          >('crypto_sign_seed_keypair');
      if (make(_pk, _sk, seed) != 0) throw StateError('fixture keypair');
      key = List<int>.unmodifiable(_pk.asTypedList(32));
    } finally {
      calloc.free(seed);
    }
  }
  late final DynamicLibrary _lib;
  late final Pointer<Uint8> _pk, _sk;
  late final List<int> key;
  List<int> sign(List<int> message) {
    final sig = calloc<Uint8>(64),
        data = calloc<Uint8>(message.isEmpty ? 1 : message.length);
    try {
      data.asTypedList(message.length).setAll(0, message);
      final sign = _lib
          .lookupFunction<
            Int32 Function(
              Pointer<Uint8>,
              Pointer<Uint64>,
              Pointer<Uint8>,
              Uint64,
              Pointer<Uint8>,
            ),
            int Function(
              Pointer<Uint8>,
              Pointer<Uint64>,
              Pointer<Uint8>,
              int,
              Pointer<Uint8>,
            )
          >('crypto_sign_detached');
      if (sign(sig, nullptr, data, message.length, _sk) != 0) {
        throw StateError('fixture signature');
      }
      return List<int>.of(sig.asTypedList(64));
    } finally {
      calloc.free(sig);
      calloc.free(data);
    }
  }

  void dispose() {
    calloc.free(_pk);
    calloc.free(_sk);
  }

  Map<String, dynamic> trusted({
    bool revoked = false,
    int before = 10,
    int after = 10000,
  }) => {
    'publicKeyBase64': base64.encode(key),
    'keyFingerprint': digest(key),
    'role': 'filmCraftPublisher',
    'notBefore': before,
    'notAfter': after,
    'revoked': revoked,
  };
}

Map<String, dynamic> policy(List<FixtureSigner> signers, {int threshold = 1}) =>
    {
      'policyVersion': 'filmcraft-import-v1',
      'policyEpoch': 1,
      'appId': 'studio',
      'namespace': ns,
      'threshold': threshold,
      'trustedSigners': [for (final s in signers) s.trusted()],
      'maxEnvelopeBytes': 4194304,
      'maxPayloadBytes': 2097152,
      'maxFileBytes': 1048576,
    };

final class PackFixture {
  Map<String, dynamic> film = {
    'schemaVersion': '1.0.0',
    'id': 'camera.test',
    'version': '1.0.0',
    'namespace': ns,
    'family': 'camera_craft',
    'title': '测试镜头',
    'tags': [],
    'narrativeUses': [],
    'counterExamples': [],
    'parameterSlots': [],
    'capabilityMappings': [],
    'steps': [
      {
        'id': 'a',
        'action': 'analyze',
        'dependsOn': [],
        'toolId': 'media.analyze',
        'argumentsTemplateHash': 'sha256:${'0' * 64}',
        'outputSchemaHash': 'sha256:${'1' * 64}',
        'budgetPolicy': 'inheritOnly',
      },
    ],
    'requiredTools': ['media.analyze'],
    'requiredFeatures': [],
    'reviewChecks': [],
    'license': {
      'codeLicense': 'unknown',
      'weightLicense': null,
      'termsHash': 'sha256:${'0' * 64}',
      'attributionText': 'unverified test assertion',
      'sourceUrls': ['https://example.invalid/never-fetched'],
    },
    'provenanceRefs': [],
    'signatureRef': null,
    'testFixturesHash': '',
  };
  Map<String, dynamic> manifest = {
    'version': '1.0.0',
    'contentType': 'filmCraft',
    'requiredTools': ['media.analyze'],
    'inputSchema': {
      'type': 'object',
      'properties': {},
      'required': [],
      'additionalProperties': false,
    },
    'outputSchema': {'type': 'string'},
    'testFixtures': {},
    'payloadPath': 'film-skill.json',
  };
  Map<String, dynamic> fixtures = {
    'cases': [
      {'input': {}, 'expectedOutput': 'ok'},
    ],
  };
  Map<String, List<int>>? rawFiles;
  Map<String, dynamic> payload() {
    final fixtureBytes = utf8.encode(jsonEncode(fixtures)),
        fh = digest(fixtureBytes);
    film['testFixturesHash'] = fh;
    manifest['testFixtures'] = {'path': 'test-fixtures.json', 'sha256': fh};
    final files =
        rawFiles ??
        {
          'film-skill.json': utf8.encode(jsonEncode(film)),
          'skill-manifest.json': utf8.encode(jsonEncode(manifest)),
          'test-fixtures.json': fixtureBytes,
        };
    return {
      'schemaVersion': '1.0.0',
      'contentType': 'filmCraft',
      'skillId': 'camera.test',
      'version': '1.0.0',
      'manifestHash': digest(files['skill-manifest.json']!),
      'entrypoint': 'film-skill.json',
      'files': [
        for (final e in files.entries)
          {
            'path': e.key,
            'mediaType': 'application/json',
            'byteLength': e.value.length,
            'sha256': digest(e.value),
            'data': base64.encode(e.value),
          },
      ],
      'licenseEvidence': [],
    };
  }

  Uint8List envelope(
    List<FixtureSigner> signers, {
    Map<String, dynamic>? content,
    List<int>? rawBody,
    String type = signedSkillPayloadType,
    bool url = false,
    Map<String, Object?> extras = const {},
  }) {
    final body = rawBody ?? utf8.encode(jsonEncode(content ?? payload()));
    String encode(List<int> b) =>
        url ? base64Url.encode(b).replaceAll('=', '') : base64.encode(b);
    return Uint8List.fromList(
      utf8.encode(
        jsonEncode({
          'payloadType': type,
          'payload': encode(body),
          'signatures': [
            for (final s in signers)
              {
                'keyid': 'untrusted-hint',
                'sig': encode(s.sign(dssePae(type, body))),
              },
          ],
          ...extras,
        }),
      ),
    );
  }
}
