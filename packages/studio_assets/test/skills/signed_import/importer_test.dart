import 'dart:convert';
import 'dart:typed_data';

import 'package:studio_assets/craft/signed_import/importer.dart';
import 'package:studio_assets/craft/signed_import/schema_check.dart';
import 'package:studio_assets/craft/signed_import/strict_json.dart';
import 'package:studio_contracts/studio_contracts.dart';
import 'package:test/test.dart';

import 'backend_test.dart' show backend;
import 'fixture.dart';

Matcher fails([String? part]) => throwsA(
  isA<StudioException>().having(
    (x) => x.code,
    'code',
    part == null ? startsWith('SKILL_IMPORT_') : equals('SKILL_IMPORT_$part'),
  ),
);

void main() {
  final crypto = backend();
  late FixtureSigner a, b, attacker;
  late PackFixture pack;
  late BuildTimeSignaturePolicy pinned;
  late FilmSkillRepository importer;
  late ImportUserActionPort ui;
  late ImportAppSnapshot state;
  ImportAppSnapshot snapshot({
    BuildTimeSignaturePolicy? p,
    int now = 100,
    bool confident = true,
    bool rollback = false,
    Set<String> grants = const {'media.analyze'},
  }) => ImportAppSnapshot(
    profile: AppProfile(appId: 'studio', region: 'test', features: {}),
    namespace: ns,
    policy: p ?? pinned,
    nowSeconds: now,
    clockConfident: confident,
    clockRollback: rollback,
    installedAllowlist: {'media.analyze'},
    sessionGrant: grants,
    branchScope: {'media.analyze'},
  );
  SkillVerificationReport load({
    Uint8List? bytes,
    BuildTimeSignaturePolicy? policyOverride,
    Map<String, dynamic>? namespace,
  }) => importer.importPack(
    SkillReadToken.capture(bytes ?? pack.envelope([a])),
    namespace ?? ns,
    policyOverride ?? state.policy,
  );
  setUp(() {
    a = FixtureSigner(0);
    b = FixtureSigner(1);
    attacker = FixtureSigner(2);
    pack = PackFixture();
    pinned = BuildTimeSignaturePolicy(policy([a]));
    state = snapshot();
    ui = ImportUserActionPort.forTrustedUi();
    importer = FilmSkillRepository(crypto, () => state, ui);
  });
  tearDown(() {
    a.dispose();
    b.dispose();
    attacker.dispose();
  });

  test(
    'real Ed25519 DSSE preview, separate hashes and one-shot acknowledgment',
    () {
      final bytes = pack.envelope([a]);
      final env = jsonDecode(utf8.decode(bytes)) as Map;
      final report = load(bytes: bytes);
      expect(report.trustState, 'verified');
      expect(report.envelopeHash, digest(bytes));
      expect(
        report.payloadHash,
        digest(base64.decode(env['payload'] as String)),
      );
      expect(report.contentHash, isNot(report.payloadHash));
      expect(report.verifiedKeyFingerprints, [digest(a.key)]);
      expect(report.privilegePreview.untrusted, isFalse);
      expect(report.executionAuthority, isFalse);
      expect(report.documentWrites, 0);
      expect(report.privilegePreview.addedTools, isEmpty);
      final gesture = ui.explicitPreviewConsent(report.previewId),
          ack = importer.acknowledge(gesture);
      expect(ack.payloadHash, report.payloadHash);
      expect(ack.contentHash, report.contentHash);
      expect(ack.permissionDiffHash, report.permissionDiffHash);
      expect(ack.namespace, ns);
      expect(ack.policyEpoch, 1);
      expect(ack.executionAuthority, isFalse);
      expect(ack.documentWrites, 0);
      expect(() => importer.acknowledge(gesture), fails('PREVIEW_STALE'));
    },
  );
  test('capture copies bytes; deeply immutable knowledge/report lists', () {
    final bytes = pack.envelope([a]), token = SkillReadToken.capture(bytes);
    bytes.fillRange(0, bytes.length, 0);
    final r = importer.importPack(token, ns, pinned);
    expect(r.trustState, 'verified');
    expect(() => r.knowledge['title'] = 'hacked', throwsUnsupportedError);
    expect(
      () => (r.knowledge['steps'] as List).clear(),
      throwsUnsupportedError,
    );
    expect(
      () => (r.knowledge['license'] as Map)['codeLicense'] = 'licensed',
      throwsUnsupportedError,
    );
    expect(() => r.verifiedKeyFingerprints.clear(), throwsUnsupportedError);
    expect(() => r.requiredTools.add('shell'), throwsUnsupportedError);
    expect(
      () => r.privilegePreview.requiredApprovals.clear(),
      throwsUnsupportedError,
    );
  });
  test('unsigned empty-root policy stays untrusted; acknowledgment never upgrades it', () {
    pinned = BuildTimeSignaturePolicy(policy([]));
    state = snapshot();
    final r = load(bytes: pack.envelope([]));
    expect(r.trustState, 'unsignedUntrusted');
    expect(r.privilegePreview.untrusted, isTrue);
    expect(
      importer.acknowledge(ui.explicitPreviewConsent(r.previewId)).trustState,
      'unsignedUntrusted',
    );
    expect(() => load(bytes: pack.envelope([a])), fails('SIGNATURE'));
  });
  test(
    'license facts and warnings stay unverified, no extra license approval',
    () {
      final r = load();
      expect(r.licenseFacts['licenseGranted'], isFalse);
      expect(r.licenseFacts['commercialRiskPolicy'], 'allow_with_warning');
      expect(r.licenseFacts['warnings'], contains('LICENSE_EVIDENCE_MISSING'));
      expect(
        (r.licenseFacts['declaredLicense'] as Map)['codeLicense'],
        'unknown',
      );
      expect(r.privilegePreview.requiredApprovals, ['userConfirm']);
    },
  );
  test('permission diff reports missing tools and does not grant them', () {
    state = snapshot(grants: {});
    final r = load();
    expect(r.permissionDiff['missingTools'], ['media.analyze']);
    expect(r.privilegePreview.addedTools, isEmpty);
    expect(
      importer
          .acknowledge(ui.explicitPreviewConsent(r.previewId))
          .executionAuthority,
      isFalse,
    );
  });
  test('UI gesture cannot be replaced by another UI port, ID echo or reused receipt', () {
    final r = load();
    final other = ImportUserActionPort.forTrustedUi();
    expect(
      () => importer.acknowledge(other.explicitPreviewConsent(r.previewId)),
      fails('PREVIEW_STALE'),
    );
    expect(
      () => importer.acknowledge(
        ui.explicitPreviewConsent('model-claimed-confirmed'),
      ),
      fails('PREVIEW_STALE'),
    );
    expect(
      importer
          .acknowledge(ui.explicitPreviewConsent(r.previewId))
          .executionAuthority,
      isFalse,
    );
  });
  test('threshold uses distinct key bytes; ignores forged keyid and unknown envelope fields', () {
    pinned = BuildTimeSignaturePolicy(policy([a, b], threshold: 2));
    state = snapshot();
    final bytes = pack.envelope(
      [a, b],
      extras: {
        'algorithm': 'none',
        'signed': true,
        'trustedKeys': [base64.encode(attacker.key)],
      },
    );
    final env = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
    for (final s in env['signatures'] as List) {
      s['keyid'] = 'same attacker-controlled hint';
      s['unknown'] = true;
    }
    final r = load(bytes: Uint8List.fromList(utf8.encode(jsonEncode(env))));
    expect(r.verifiedKeyFingerprints.length, 2);
    expect(() => load(bytes: pack.envelope([a, a])), fails('SIGNATURE'));
    expect(() => load(bytes: pack.envelope([attacker])), fails('SIGNATURE'));
  });
  test('duplicate configured keys/fingerprints are invalid policy', () {
    final p = policy([a, a], threshold: 2);
    pinned = BuildTimeSignaturePolicy(p);
    state = snapshot();
    expect(() => load(), fails('POLICY'));
  });
  for (final mode in [
    'payload',
    'type',
    'signature',
    'invalid-signed-no-downgrade',
  ]) {
    test('tampering fails closed: $mode', () {
      final env =
          jsonDecode(utf8.decode(pack.envelope([a]))) as Map<String, dynamic>;
      if (mode == 'payload') {
        env['payload'] = base64.encode([
          ...base64.decode(env['payload'] as String),
          32,
        ]);
      }
      if (mode == 'type') env['payloadType'] = 'application/json';
      if (mode == 'signature' || mode == 'invalid-signed-no-downgrade') {
        (env['signatures'] as List).first['sig'] = base64.encode(
          List<int>.filled(64, 0),
        );
      }
      expect(
        () => load(bytes: Uint8List.fromList(utf8.encode(jsonEncode(env)))),
        fails('SIGNATURE'),
      );
    });
  }
  test('actual signed=true claim in payload is not a verification path', () {
    final p = pack.payload()..['signed'] = true;
    expect(() => load(bytes: pack.envelope([a], content: p)), fails('SCHEMA'));
    expect(
      () => load(bytes: pack.envelope([attacker], content: p)),
      fails('SIGNATURE'),
    );
  });
  test('signed byte identity includes whitespace and preserves exact Unicode bytes', () {
    final p = pack.payload(),
        body = utf8.encode(const JsonEncoder.withIndent('  ').convert(p));
    final r = load(bytes: pack.envelope([a], rawBody: body));
    expect(r.payloadHash, digest(body));
    expect(r.knowledge['title'], '测试镜头');
    final env = jsonDecode(
      utf8.decode(pack.envelope([a], rawBody: body)),
    ) as Map<String, dynamic>;
    env['payload'] = base64.encode(utf8.encode(jsonEncode(p)));
    expect(
      () => load(bytes: Uint8List.fromList(utf8.encode(jsonEncode(env)))),
      fails('SIGNATURE'),
    );
  });
  test('DSSE PAE reference bytes and UTF-8 lengths', () {
    expect(
      utf8.decode(
        dssePae('http://example.com/HelloWorld', utf8.encode('hello world')),
      ),
      'DSSEv1 29 http://example.com/HelloWorld 11 hello world',
    );
    expect(utf8.decode(dssePae('片', utf8.encode('镜头'))), 'DSSEv1 3 片 6 镜头');
  });
  test('ordinary and URL-safe padded/unpadded base64, no whitespace or pad-bit aliases', () {
    expect(load(bytes: pack.envelope([a], url: true)).trustState, 'verified');
    for (final text in ['Zg==', 'Zg', '_w==', '/w', '_w']) {
      expect(strictBase64(text, 4), isNotEmpty);
    }
    for (final text in [
      'Zh==',
      'Zh',
      'Zg=',
      'Zg===',
      'Z g==',
      '-_+/',
      'A',
      'AA\n',
      '%41A==',
    ]) {
      expect(() => strictBase64(text, 16), fails('ENCODING'), reason: text);
    }
  });
  for (final raw in [
    '{"x":1,"x":2}',
    '{"x":{"a":1,"\\u0061":2}}',
    '{"x":"\\ud800"}',
    '\ufeff{}',
    '{} true',
    '{"x":NaN}',
    '{"x":1e999}',
    '{"x":01}',
    '{"x":1,}',
  ]) {
    test('strict decoding refuses $raw', () {
      expect(() => strictJson(utf8.encode(raw), 4096), fails('ENCODING'));
    });
  }
  test('duplicate keys refused at envelope, payload and file layers', () {
    final env = utf8.decode(pack.envelope([a]));
    expect(
      () => load(
        bytes: Uint8List.fromList(
          utf8.encode(env.replaceFirst('{', '{"payloadType":"bad",')),
        ),
      ),
      fails('ENCODING'),
    );
    final p = jsonEncode(pack.payload());
    expect(
      () => load(
        bytes: pack.envelope([
          a,
        ], rawBody: utf8.encode(p.replaceFirst('{', '{"skillId":"evil",'))),
      ),
      fails('ENCODING'),
    );
    final files = pack.payload()['files'] as List;
    final f = files.first as Map;
    final raw = utf8
        .decode(base64.decode(f['data'] as String))
        .replaceFirst('{', '{"id":"dup",');
    pack.rawFiles = {
      for (final e in files)
        e['path'] as String: base64.decode(e['data'] as String),
    };
    pack.rawFiles!['film-skill.json'] = utf8.encode(raw);
    expect(() => load(), fails('ENCODING'));
  });
  for (final path in [
    '../film-skill.json',
    '/film-skill.json',
    'C:\\film-skill.json',
    '\\\\host\\file',
    'dir/../film-skill.json',
    'film-skill.json/',
    'Film-Skill.json',
    'film%2dskill.json',
    'film-skill.json\u0000',
  ]) {
    test('path alias refused: ${jsonEncode(path)}', () {
      final p = pack.payload();
      (p['files'] as List).first['path'] = path;
      expect(() => load(bytes: pack.envelope([a], content: p)), fails('PATH'));
    });
  }
  test(
    'duplicate file path, wrong digest and incorrect byte length refused',
    () {
      var p = pack.payload();
      (p['files'] as List)[1]['path'] = 'film-skill.json';
      expect(() => load(bytes: pack.envelope([a], content: p)), fails('PATH'));
      p = pack.payload();
      (p['files'] as List).first['sha256'] = 'sha256:${'f' * 64}';
      expect(() => load(bytes: pack.envelope([a], content: p)), fails('HASH'));
      p = pack.payload();
      (p['files'] as List).first['byteLength'] = 1;
      expect(() => load(bytes: pack.envelope([a], content: p)), fails('HASH'));
    },
  );
  test('all byte/depth/count limits fail without a preview', () {
    expect(() => SkillReadToken.capture(Uint8List(4194305)), fails('LIMIT'));
    expect(
      () => strictJson(utf8.encode('${'[' * 34}0${']' * 34}'), 1024),
      fails('LIMIT'),
    );
    expect(() => strictJson([0xff], 16), fails('ENCODING'));
    final p = pack.payload();
    (p['files'] as List).first['byteLength'] = 1048577;
    expect(() => load(bytes: pack.envelope([a], content: p)), fails());
    final env =
        jsonDecode(utf8.decode(pack.envelope([a]))) as Map<String, dynamic>;
    env['signatures'] = List.generate(
      9,
      (_) => (env['signatures'] as List).first,
    );
    expect(
      () => load(bytes: Uint8List.fromList(utf8.encode(jsonEncode(env)))),
      fails(),
    );
    expect(
      () => strictBase64(base64.encode(Uint8List(2097153)), 2097152),
      fails(),
    );
  });
  test('pending previews bounded and discard releases capacity', () {
    final reports = [for (var i = 0; i < 16; i++) load()];
    expect(reports.map((r) => r.previewId).toSet().length, 16);
    expect(() => load(), fails('LIMIT'));
    importer.discard(reports.first.previewId);
    expect(load().trustState, 'verified');
  });
  for (final mode in [
    'missing-required',
    'unknown-field',
    'id-drift',
    'version-drift',
    'signature-ref',
    'namespace',
    'fixture-hash',
  ]) {
    test('closed FilmSkill refuses $mode', () {
      switch (mode) {
        case 'missing-required':
          pack.film.remove('title');
        case 'unknown-field':
          pack.film['shell'] = 'ignored?';
        case 'id-drift':
          pack.film['id'] = 'other';
        case 'version-drift':
          pack.film['version'] = '2.0.0';
        case 'signature-ref':
          pack.film['signatureRef'] = 'sha256:${'0' * 64}';
        case 'namespace':
          pack.film['namespace'] = {...ns, 'tenantId': 'other'};
        case 'fixture-hash':
          final p = pack.payload();
          pack.film['testFixturesHash'] = 'sha256:${'f' * 64}';
          final rawFiles = {
            for (final f in p['files'] as List)
              f['path'] as String: base64.decode(f['data'] as String),
          };
          rawFiles['film-skill.json'] = utf8.encode(jsonEncode(pack.film));
          pack.rawFiles = rawFiles;
      }
      expect(() => load(), fails());
    });
  }
  for (final schema in [
    {r'$ref': 'https://attacker.invalid/schema'},
    {'type': 'object', 'properties': {}, 'additionalProperties': true},
    {'type': 'string', 'minLength': -1},
    {'type': 'array', 'minItems': 3, 'maxItems': 1},
    {'type': 'invented'},
    {'type': 'string', 'pattern': '.*'},
    {'unknown': true},
    {
      r'$defs': {
        'a': {r'$ref': r'#/$defs/a'},
      },
      r'$ref': r'#/$defs/a',
    },
    {r'$ref': r'#/$defs/missing'},
    {
      'enum': [1, 1],
    },
    {
      'type': 'object',
      'properties': {},
      'required': ['missing'],
      'additionalProperties': false,
    },
    {
      r'$defs': {
        'a': true,
        'b': {r'$ref': r'#/$defs/a'},
      },
      r'$ref': r'#/$defs/b',
    },
  ]) {
    test(
      'manifest schema rejects unsupported/malformed vocabulary ${jsonEncode(schema)}',
      () {
        pack.manifest['inputSchema'] = schema;
        expect(() => load(), fails());
      },
    );
  }
  test(
    'local schema definitions work and fixtures are checked not executed',
    () {
      pack.manifest['outputSchema'] = {
        r'$defs': {
          'result': {'type': 'string', 'minLength': 1},
        },
        r'$ref': r'#/$defs/result',
      };
      expect(load().trustState, 'verified');
      pack.fixtures['cases'] = [
        {'input': {}, 'expectedOutput': 0},
      ];
      expect(() => load(), fails('SCHEMA'));
    },
  );
  test('manifest hash/requiredTools/fixture references cannot drift', () {
    var p = pack.payload();
    p['manifestHash'] = 'sha256:${'f' * 64}';
    expect(() => load(bytes: pack.envelope([a], content: p)), fails('HASH'));
    pack.manifest['requiredTools'] = [];
    expect(() => load(), fails('SCHEMA'));
  });
  test('parsed steps cannot hide tools, cycles, missing dependencies, or duplicate IDs', () {
    final original = clone(pack.film);
    (pack.film['steps'] as List).first['toolId'] = 'shell';
    expect(() => load(), fails('SCHEMA'));
    pack.film = clone(original);
    pack.film['requiredTools'] = [];
    expect(() => load(), fails('SCHEMA'));
    pack.film = clone(original);
    (pack.film['steps'] as List).first['dependsOn'] = ['a'];
    expect(() => load(), fails('SCHEMA'));
    pack.film = clone(original);
    (pack.film['steps'] as List).first['dependsOn'] = ['missing'];
    expect(() => load(), fails('SCHEMA'));
    pack.film = clone(original);
    (pack.film['steps'] as List).add(
      clone((pack.film['steps'] as List).first as Map<String, dynamic>),
    );
    expect(() => load(), fails('SCHEMA'));
  });
  test(
    'untrusted schemas cannot exhaust an acyclic reference graph work budget',
    () {
      final defs = <String, Object?>{'leaf': true};
      for (var i = 0; i < 15; i++) {
        final target = i == 0 ? 'leaf' : 'n${i - 1}';
        defs['n$i'] = {
          'type': 'object',
          'properties': {
            'a': {r'$ref': '#/\$defs/$target'},
            'b': {r'$ref': '#/\$defs/$target'},
          },
          'additionalProperties': false,
        };
      }
      expect(
        () => checkManifestSchema({r'$defs': defs, r'$ref': r'#/$defs/n14'}),
        throwsA(
          isA<StudioException>()
              .having((e) => e.code, 'code', 'SKILL_IMPORT_LIMIT')
              .having((e) => e.path, 'path', 'schemaWork'),
        ),
      );
    },
  );
  for (final drift in [
    'epoch',
    'revoked',
    'expiry',
    'before',
    'clock-unknown',
    'rollback',
    'namespace',
    'grant',
    'same-epoch-policy-change',
  ]) {
    test('acknowledgment invalidated by $drift', () {
      final r = load();
      var raw = policy([a]);
      switch (drift) {
        case 'epoch':
          raw['policyEpoch'] = 2;
          state = snapshot(p: BuildTimeSignaturePolicy(raw));
        case 'revoked':
          (raw['trustedSigners'] as List).first['revoked'] = true;
          state = snapshot(p: BuildTimeSignaturePolicy(raw));
        case 'expiry':
          state = snapshot(now: 10000);
        case 'before':
          state = snapshot(now: 99);
        case 'clock-unknown':
          state = snapshot(confident: false);
        case 'rollback':
          state = snapshot(rollback: true);
        case 'namespace':
          raw['namespace'] = {...ns, 'workspaceId': 'other'};
          state = snapshot(p: BuildTimeSignaturePolicy(raw));
        case 'grant':
          state = snapshot(grants: {});
        case 'same-epoch-policy-change':
          (raw['trustedSigners'] as List).first['notAfter'] = 9999;
          state = snapshot(p: BuildTimeSignaturePolicy(raw));
      }
      expect(
        () => importer.acknowledge(ui.explicitPreviewConsent(r.previewId)),
        fails(),
      );
    });
  }
  for (final mode in [
    'revoked',
    'not-before',
    'expired',
    'role',
    'fingerprint',
    'namespace',
    'caller-policy',
  ]) {
    test('trusted policy refuses $mode during import', () {
      final raw = policy([a]);
      switch (mode) {
        case 'revoked':
          (raw['trustedSigners'] as List).first['revoked'] = true;
        case 'not-before':
          (raw['trustedSigners'] as List).first['notBefore'] = 101;
        case 'expired':
          (raw['trustedSigners'] as List).first['notAfter'] = 100;
        case 'role':
          (raw['trustedSigners'] as List).first['role'] = 'systemAdministrator';
        case 'fingerprint':
          (raw['trustedSigners'] as List).first['keyFingerprint'] =
              'sha256:${'0' * 64}';
        case 'namespace':
          raw['namespace'] = {...ns, 'appId': 'attacker'};
        case 'caller-policy':
          expect(
            () => load(policyOverride: BuildTimeSignaturePolicy(raw)),
            fails('POLICY'),
          );
          return;
      }
      pinned = BuildTimeSignaturePolicy(raw);
      state = snapshot();
      expect(() => load(), fails());
    });
  }
  test(
    'unknown or rollback clock yields needsReview, never a verified preview',
    () {
      state = snapshot(confident: false);
      var r = load();
      expect(r.trustState, 'needsReview');
      expect(r.privilegePreview.untrusted, isTrue);
      expect(
        () => importer.acknowledge(ui.explicitPreviewConsent(r.previewId)),
        fails('PREVIEW_STALE'),
      );
      state = snapshot(rollback: true);
      r = load();
      expect(r.trustState, 'needsReview');
      expect(() => load(bytes: pack.envelope([attacker])), fails('SIGNATURE'));
    },
  );
  test(
    'numeric/enum/time defaults and duplicate parameter slots are checked',
    () {
      final base = {
        'key': 'strength',
        'kind': 'number',
        'minimum': 0,
        'maximum': 1,
        'defaultValue': 0.5,
        'unit': 'ratio',
        'required': false,
      };
      pack.film['parameterSlots'] = [base];
      expect(load().trustState, 'verified');
      pack.film['parameterSlots'] = [
        {...base, 'defaultValue': 2},
      ];
      expect(() => load(), fails('SCHEMA'));
      pack.film['parameterSlots'] = [
        {...base, 'minimum': 2},
      ];
      expect(() => load(), fails('SCHEMA'));
      pack.film['parameterSlots'] = [base, base];
      expect(() => load(), fails('SCHEMA'));
      pack.film['parameterSlots'] = [
        {
          'key': 'mode',
          'kind': 'enum',
          'choices': ['a'],
          'defaultValue': 'b',
          'required': true,
        },
      ];
      expect(() => load(), fails('SCHEMA'));
      pack.film['parameterSlots'] = [
        {
          'key': 'offset',
          'kind': 'time',
          'defaultValue': {'n': '2', 'd': 4},
          'required': true,
        },
      ];
      expect(() => load(), fails('SCHEMA'));
    },
  );
  test('boolean schemas, local refs and malformed keyword value types', () {
    pack.manifest['inputSchema'] = true;
    pack.manifest['outputSchema'] = true;
    expect(load().trustState, 'verified');
    for (final bad in [
      false,
      {'minLength': '1'},
      {'properties': []},
      {'items': 17},
      {'type': 'string', 'properties': {}, 'additionalProperties': false},
      {
        r'$defs': {'bad/name': true},
      },
    ]) {
      pack.manifest['inputSchema'] = bad;
      expect(() => load(), fails('SCHEMA'));
    }
  });
  test('malformed signatures reject even with a valid threshold signature', () {
    final env =
        jsonDecode(utf8.decode(pack.envelope([a]))) as Map<String, dynamic>;
    (env['signatures'] as List).add({'sig': '', 'keyid': 'other'});
    expect(
      () => load(bytes: Uint8List.fromList(utf8.encode(jsonEncode(env)))),
      fails('ENCODING'),
    );
  });
  test('default AppProfile policy has no provisioned publisher roots', () {
    final app = AppProfile(appId: 'studio', region: 'test', features: {});
    pinned = BuildTimeSignaturePolicy.disabled(
      app,
      app.namespace('test', 'local'),
    );
    state = snapshot();
    expect(() => load(), fails('SIGNATURE'));
    expect(load(bytes: pack.envelope([])).trustState, 'unsignedUntrusted');
  });
  test('numeric precision cannot merge distinct const/enum values or truncate bytes', () {
    for (final raw in [
      '1.0000000000000000001',
      '0.000000000000000000000000000000000000000000000000001234567890123456789',
      '1e-999',
    ]) {
      expect(() => strictJson(utf8.encode(raw), 4096), fails('ENCODING'));
    }
    for (final raw in [
      '0.1',
      '1.00',
      '1e20',
      '-0',
      '0e999999999999999999999999',
    ]) {
      expect(() => strictJson(utf8.encode(raw), 4096), returnsNormally);
    }
    expect(sameJson(1, 1.0), isTrue);
    expect(
      () => checkSchema({'type': 'integer'}, 9007199254740993, {}),
      returnsNormally,
    );
    expect(sameJson(9007199254740993, 9007199254740992.0), isFalse);
    expect(compareJsonNumbers(-0.1, 0), lessThan(0));
    expect(() => SkillReadToken.capture([256]), fails('ENCODING'));
    expect(() => SkillReadToken.capture([-1]), fails('ENCODING'));
  });
}
