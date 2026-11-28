// Real browser only. No native fixture signer or injectable production backend.
import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:studio_assets/studio_signed_skill_import_web.dart';
import 'package:studio_assets/craft/signed_import/strict_json.dart';
import 'package:studio_contracts/studio_contracts.dart';

@JS('signedImportTestData')
external JSPromise<JSString> _data();
@JS('signedImportTestReport')
external void _report(JSString data);
@JS('signedImportTestMode')
external JSString get _mode;
@JS('signedImportTestAction')
external JSAny? _action(JSString name);

void check(bool ok, String why) {
  if (!ok) throw StateError(why);
}

void rejects(void Function() f, [String? code]) {
  try {
    f();
  } on StudioException catch (e) {
    check(e.code.startsWith('SKILL_IMPORT_'), 'not import error: $e');
    if (code != null && code != 'ANY') {
      check(
        e.code == 'SKILL_IMPORT_$code',
        '$code expected, got ${e.code}/${e.path}',
      );
    }
    return;
  }
  throw StateError('expected rejection $code');
}

Future<void> rejectsAsync(Future<Object?> Function() f) async {
  try {
    await f();
  } on StudioException catch (e) {
    check(e.code == 'SKILL_IMPORT_POLICY', 'backend error');
    return;
  }
  throw StateError('expected backend rejection');
}

Uint8List hex(String s) => Uint8List.fromList([
  for (var i = 0; i < s.length; i += 2)
    int.parse(s.substring(i, i + 2), radix: 16),
]);
const rfc = [
  [
    'd75a980182b10ab7d54bfed3c964073a0ee172f3daa62325af021a68f707511a',
    '',
    'e5564300c360ac729086e2cc806e828a84877f1eb8e5d974d873e065224901555fb8821590a33bacc61e39701cf9b46bd25bf5f0595bbe24655141438e7a100b',
  ],
  [
    '3d4017c3e843895a92b70aa74d1b7ebc9c982ccf2ec4968cc0cd55f12af4660c',
    '72',
    '92a009a9f0d4cab8720e820b5f642540a2b27b5416503f8fb3762223ebdb69da085ac1e43e15996e458f3613d0f11d8c387b2eaeb4302aeeb00d291612bb0c00',
  ],
  [
    'fc51cd8e6218a1a38da47ed00230f0580816ed13ba3303ac5deb911548908025',
    'af82',
    '6291d657deec24024827e69c3abe01a30ce548a284743a445e3680d7db5ac3ac18ff9b538d16f290ae67f760984dc6594a7c15e9716ed28dc027beceea1ec40a',
  ],
];

Future<void> main() async {
  final results = <String>[];
  Future<void> test(String name, Future<void> Function() body) async {
    await body();
    results.add(name);
  }

  try {
    final data = jsonDecode((await _data().toDart).toDart) as Map;
    final fixture = data['fixtures'] as Map, mode = _mode.toDart;
    final policies = fixture['policies'] as Map,
        cases = fixture['cases'] as Map;
    final ns = Map<String, dynamic>.from(fixture['namespace'] as Map);
    Map<String, dynamic> clone(Object x) =>
        jsonDecode(jsonEncode(x)) as Map<String, dynamic>;
    BuildTimeSignaturePolicy pinned = BuildTimeSignaturePolicy(
      clone(policies['one']),
    );
    var now = 100,
        confident = true,
        rollback = false,
        grants = <String>{'media.analyze'};
    ImportAppSnapshot snapshot() => ImportAppSnapshot(
      profile: AppProfile(appId: 'studio', region: 'test', features: {}),
      namespace: ns,
      policy: pinned,
      nowSeconds: now,
      clockConfident: confident,
      clockRollback: rollback,
      installedAllowlist: {'media.analyze'},
      sessionGrant: grants,
      branchScope: {'media.analyze'},
    );
    final ui = ImportUserActionPort.forTrustedUi();
    if (mode.startsWith('fail-')) {
      await rejectsAsync(() => createWebSignedSkillRepository(snapshot, ui));
      if (mode == 'fail-late') {
        await Future<void>.delayed(const Duration(milliseconds: 2000));
        await rejectsAsync(() => createWebSignedSkillRepository(snapshot, ui));
      }
      _report(
        jsonEncode({
          'ok': true,
          'mode': mode,
          'cases': ['terminal backend rejection; no repository published'],
        }).toJS,
      );
      return;
    }
    Future<FilmSkillRepository>? firstComposition;
    if (mode == 'importer') {
      // Mutate App state while the FIRST vendor load/self-tests are still pending.
      firstComposition = createWebSignedSkillRepository(snapshot, ui);
      pinned = BuildTimeSignaturePolicy(clone(policies['empty']));
      now = 200;
      grants = {};
      confident = false;
    }
    final crypto = await SodiumVerifier.initialize();
    if (mode.startsWith('bad-')) {
      check(
        (_action(mode.toJS) as JSBoolean).toDart,
        'non-byte argument accepted',
      );
      await rejectsAsync(() => createWebSignedSkillRepository(snapshot, ui));
      _report(
        jsonEncode({
          'ok': true,
          'mode': mode,
          'cases': [
            'reject non-byte/shared/resizable input without coercion; terminal failure',
          ],
        }).toJS,
      );
      return;
    }
    if ((mode == 'crypto' || mode == 'aliasing')) {
      await test(
        'Dart caller buffers are isolated from mutating upstream',
        () async {
          final pk = hex(rfc[1][0]), msg = hex(rfc[1][1]), sig = hex(rfc[1][2]);
          final before = base64.encode([...msg, ...sig, ...pk]);
          check(crypto.verify(msg, sig, pk), 'verify');
          check(base64.encode([...msg, ...sig, ...pk]) == before, 'Dart alias');
        },
      );
      await test('RFC8032 tests 1-3 and message tampering', () async {
        for (final v in rfc) {
          check(crypto.verify(hex(v[1]), hex(v[2]), hex(v[0])), 'RFC');
          check(
            !crypto.verify(
              Uint8List.fromList([...hex(v[1]), 0]),
              hex(v[2]),
              hex(v[0]),
            ),
            'tamper',
          );
        }
      });
      await test('all 210 Wycheproof subcases', () async {
        var n = 0;
        for (final g in (data['vectors'] as Map)['testGroups'] as List) {
          for (final t in g['tests'] as List) {
            check(
              crypto.verify(
                    hex(t['msg']),
                    hex(t['sig']),
                    hex(g['publicKey']['pk']),
                  ) ==
                  (t['result'] == 'valid'),
              'Wycheproof ${t['tcId']}',
            );
            n++;
          }
        }
        check(n == 210, 'corpus count');
      });
      await test(
        'canonical S, S+L, noncanonical/small-order key and R, lengths',
        () async {
          final pk = hex(rfc[0][0]), sig = hex(rfc[0][2]), msg = hex('');
          final l = hex(
            'edd3f55c1a631258d69cf7a2def9de1400000000000000000000000000000010',
          );
          final sEquals = Uint8List.fromList(sig)..setRange(32, 64, l);
          check(!crypto.verify(msg, sEquals, pk), 'S=L');
          final plus = Uint8List.fromList(sig);
          var carry = 0;
          for (var i = 0; i < 32; i++) {
            final n = plus[i + 32] + l[i] + carry;
            plus[i + 32] = n & 255;
            carry = n >> 8;
          }
          check(!crypto.verify(msg, plus, pk), 'S+L');
          for (final k in [
            Uint8List(32),
            Uint8List(32)..[0] = 1,
            Uint8List(32)..fillRange(0, 32, 255),
          ]) {
            check(!crypto.validPublicKey(k), 'invalid point');
            check(!crypto.verify(msg, sig, k), 'key');
            final r = Uint8List.fromList(sig)..setRange(0, 32, k);
            check(!crypto.verify(msg, r, pk), 'R');
          }
          check(!crypto.verify(msg, sig.sublist(1), pk), 'signature length');
          check(!crypto.validPublicKey(pk.sublist(1)), 'key length');
          check(!crypto.validPublicKey([...pk.take(31), 256]), 'invalid byte');
        },
      );
      await test('shim rejects strings, shared/resizable buffers; double-copy aliasing and frozen bridge', () async {
        check((_action('byteBoundary'.toJS) as JSBoolean).toDart, 'boundary');
      });
      _report(
        jsonEncode({
          'ok': true,
          'mode': mode,
          'cases': results,
          'wycheproofSubcases': 210,
        }).toJS,
      );
      return;
    }
    final future =
        firstComposition ?? createWebSignedSkillRepository(snapshot, ui);
    // Deliberately change ALL App state across this await; only current state is used.
    pinned = BuildTimeSignaturePolicy(clone(policies['empty']));
    now = 200;
    grants = {};
    confident = false;
    final importer = await future;
    Uint8List bytes(String name) =>
        base64.decode((cases[name] as Map)['envelope'] as String);
    SkillVerificationReport load([
      String name = 'valid',
      BuildTimeSignaturePolicy? policy,
    ]) => importer.importPack(
      SkillReadToken.capture(bytes(name)),
      ns,
      policy ?? pinned,
    );
    void reset() {
      pinned = BuildTimeSignaturePolicy(clone(policies['one']));
      now = 100;
      grants = {'media.analyze'};
      confident = true;
      rollback = false;
    }

    if (mode == 'replacement' ||
        mode == 'truthy' ||
        mode == 'exception' ||
        mode == 'teardown') {
      final unsigned = bytes('unsigned');
      _action(mode.toJS);
      if (mode == 'truthy' || mode == 'exception') {
        rejects(
          () => crypto.verify(hex(rfc[0][1]), hex(rfc[0][2]), hex(rfc[0][0])),
          'POLICY',
        );
      }
      await test(
        'terminal failure also blocks empty-root unsigned import',
        () async {
          rejects(
            () => importer.importPack(
              SkillReadToken.capture(unsigned),
              ns,
              pinned,
            ),
            'POLICY',
          );
        },
      );
      await rejectsAsync(() => createWebSignedSkillRepository(snapshot, ui));
      _report(jsonEncode({'ok': true, 'mode': mode, 'cases': results}).toJS);
      return;
    }
    await test(
      'async drift uses live roots, clock and grants, not stale App state',
      () async {
        rejects(() => load(), 'SIGNATURE');
        reset();
        confident = false;
        grants = {};
        final r = load();
        check(r.trustState == 'needsReview', 'clock');
        check(
          (r.permissionDiff['missingTools'] as List).contains('media.analyze'),
          'grant',
        );
        importer.discard(r.previewId);
        reset();
      },
    );
    await test(
      'namespace and installed-policy identity remain non-bypassable',
      () async {
        rejects(
          () => importer.importPack(SkillReadToken.capture(bytes('valid')), {
            ...ns,
            'workspaceId': 'other',
          }, pinned),
          'SCOPE',
        );
        rejects(
          () => load('valid', BuildTimeSignaturePolicy(clone(policies['one']))),
          'POLICY',
        );
        final p = clone(policies['one']);
        (p['trustedSigners'] as List).add(
          clone((p['trustedSigners'] as List).first),
        );
        p['threshold'] = 2;
        pinned = BuildTimeSignaturePolicy(p);
        rejects(() => load(), 'POLICY');
        reset();
      },
    );
    await test(
      'DSSE exact bytes, immutable preview and one-use UI acknowledgment',
      () async {
        final selected = bytes('valid'),
            token = SkillReadToken.capture(selected);
        selected.fillRange(0, selected.length, 0);
        final r = importer.importPack(token, ns, pinned);
        check(r.trustState == 'verified', 'verified');
        check(r.envelopeHash == digest(bytes('valid')), 'exact envelope');
        check(r.knowledge['title'] == '测试镜头', 'UTF8');
        check(
          !r.executionAuthority && r.documentWrites == 0,
          'no writes/authority',
        );
        check(
          base64Url.decode(base64Url.normalize(r.previewId)).length >= 16,
          '128-bit nonce',
        );
        var immutable = false;
        try {
          r.knowledge['title'] = 'hack';
        } on UnsupportedError {
          immutable = true;
        }
        check(immutable, 'immutable map');
        immutable = false;
        try {
          r.requiredTools.clear();
        } on UnsupportedError {
          immutable = true;
        }
        check(immutable, 'immutable list');
        rejects(
          () => importer.acknowledge(
            ImportUserActionPort.forTrustedUi().explicitPreviewConsent(
              r.previewId,
            ),
          ),
          'PREVIEW_STALE',
        );
        final g = ui.explicitPreviewConsent(r.previewId),
            a = importer.acknowledge(g);
        check(
          !a.executionAuthority &&
              a.documentWrites == 0 &&
              a.payloadHash == r.payloadHash &&
              a.permissionDiffHash == r.permissionDiffHash,
          'no approval',
        );
        rejects(() => importer.acknowledge(g), 'PREVIEW_STALE');
      },
    );
    await test('two raw-key threshold, duplicate signatures, untrusted keyid and signed flag', () async {
      pinned = BuildTimeSignaturePolicy(clone(policies['two']));
      final e =
          jsonDecode(utf8.decode(bytes('twoKeys'))) as Map<String, dynamic>;
      for (final s in e['signatures'] as List) {
        s['keyid'] = 'same forged hint';
      }
      e['signed'] = true;
      e['algorithm'] = 'none';
      final r = importer.importPack(
        SkillReadToken.capture(utf8.encode(jsonEncode(e))),
        ns,
        pinned,
      );
      check(r.verifiedKeyFingerprints.length == 2, 'distinct keys');
      importer.discard(r.previewId);
      rejects(() => load('duplicateKey'), 'SIGNATURE');
      rejects(() => load('attacker'), 'SIGNATURE');
      reset();
    });
    await test('explicit unsigned empty roots never upgraded; invalid signed never downgraded', () async {
      pinned = BuildTimeSignaturePolicy(clone(policies['empty']));
      final r = load('unsigned');
      check(r.trustState == 'unsignedUntrusted', 'unsigned');
      check(
        importer
                .acknowledge(ui.explicitPreviewConsent(r.previewId))
                .trustState ==
            'unsignedUntrusted',
        'unsigned ack',
      );
      rejects(() => load(), 'SIGNATURE');
      rejects(() => load('invalidSigned'), 'SIGNATURE');
      reset();
      final disabled = BuildTimeSignaturePolicy.disabled(
        snapshot().profile,
        Namespace('studio', 'test', 'local'),
      );
      check(
        (disabled.value['trustedSigners'] as List).isEmpty,
        'default roots',
      );
    });
    for (final entry in cases.entries) {
      final expected = (entry.value as Map)['expected'] as String?;
      if (expected == null || entry.key == 'duplicateKey') continue;
      await test('hostile signed fixture ${entry.key}', () async {
        rejects(() => load(entry.key as String), expected);
      });
    }
    await test(
      'whitespace/Unicode preserved without signed-byte canonicalization',
      () async {
        final r = load('whitespaceUnicode');
        check(r.trustState == 'verified', 'raw PAE');
        importer.discard(r.previewId);
      },
    );
    await test(
      'license declarations stay unverified warnings, not grants',
      () async {
        final r = load();
        check(r.licenseFacts['licenseGranted'] == false, 'license');
        check(
          (r.licenseFacts['warnings'] as List).contains(
            'LICENSE_EVIDENCE_MISSING',
          ),
          'warning',
        );
        check(
          r.licenseFacts['commercialRiskPolicy'] == 'allow_with_warning',
          'risk',
        );
        check(r.privilegePreview.addedTools.isEmpty, 'no tool grants');
        check(
          r.privilegePreview.requiredApprovals.join(',') == 'userConfirm',
          'no license approval',
        );
        importer.discard(r.previewId);
      },
    );
    await test(
      'envelope and App policy resource limits, max pending',
      () async {
        rejects(() => SkillReadToken.capture(Uint8List(4194305)), 'LIMIT');
        final p = clone(policies['one']);
        p['maxEnvelopeBytes'] = 100;
        pinned = BuildTimeSignaturePolicy(p);
        rejects(() => load(), 'POLICY');
        reset();
        final oversized =
            jsonDecode(utf8.decode(bytes('valid'))) as Map<String, dynamic>;
        oversized['payload'] = base64.encode(Uint8List(2097153));
        rejects(
          () => importer.importPack(
            SkillReadToken.capture(utf8.encode(jsonEncode(oversized))),
            ns,
            pinned,
          ),
          'LIMIT',
        );
        final pending = <String>[];
        for (var i = 0; i < 16; i++) {
          pending.add(load().previewId);
        }
        rejects(() => load(), 'LIMIT');
        for (final id in pending) {
          importer.discard(id);
        }
        check(pending.toSet().length == 16, 'nonce uniqueness');
      },
    );
    for (final drift in [
      'policy',
      'epoch',
      'revoked',
      'expiry',
      'rollback',
      'unknownClock',
      'grant',
    ]) {
      await test('stale consent $drift', () async {
        reset();
        final r = load();
        final p = clone(policies['one']);
        switch (drift) {
          case 'policy':
            p['threshold'] = 1;
            (p['trustedSigners'] as List).first['notAfter'] = 9999;
            pinned = BuildTimeSignaturePolicy(p);
          case 'epoch':
            p['policyEpoch'] = 2;
            pinned = BuildTimeSignaturePolicy(p);
          case 'revoked':
            (p['trustedSigners'] as List).first['revoked'] = true;
            pinned = BuildTimeSignaturePolicy(p);
          case 'expiry':
            now = 10000;
          case 'rollback':
            rollback = true;
          case 'unknownClock':
            confident = false;
          case 'grant':
            grants = {};
        }
        rejects(
          () => importer.acknowledge(ui.explicitPreviewConsent(r.previewId)),
          'PREVIEW_STALE',
        );
        reset();
      });
    }
    await test('discard, realm-local pending and no echo consent', () async {
      final r = load();
      importer.discard(r.previewId);
      rejects(
        () => importer.acknowledge(ui.explicitPreviewConsent(r.previewId)),
        'PREVIEW_STALE',
      );
      final other = await createWebSignedSkillRepository(snapshot, ui);
      final live = load();
      rejects(
        () => other.acknowledge(ui.explicitPreviewConsent(live.previewId)),
        'PREVIEW_STALE',
      );
      importer.discard(live.previewId);
      rejects(
        () => importer.acknowledge(ui.explicitPreviewConsent('model-echo')),
        'PREVIEW_STALE',
      );
    });
    _report(
      jsonEncode({
        'ok': true,
        'mode': mode,
        'cases': results,
        'documentWrites': 0,
        'executionAuthority': false,
      }).toJS,
    );
  } catch (e, st) {
    _report(
      jsonEncode({
        'ok': false,
        'mode': _mode.toDart,
        'cases': results,
        'error': '$e',
        'stack': '$st',
      }).toJS,
    );
  }
}
