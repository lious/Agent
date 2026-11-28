/// Bounded opt-in import-to-preview entry point. No persistence/installation API.
library;

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:studio_contracts/studio_contracts.dart';
import 'package:studio_document/studio_document.dart' show Q;

import '../skill_privilege.dart';
import 'film_schema.dart';
import 'schema_check.dart';
import 'backend.dart';
import 'strict_json.dart';

const signedSkillPayloadType =
    'application/vnd.studio.filmcraft.import.v1+json';
Uint8List dssePae(String type, List<int> body) {
  final t = utf8.encode(type);
  return Uint8List.fromList([
    ...ascii.encode('DSSEv1 ${t.length} '),
    ...t,
    ...ascii.encode(' ${body.length} '),
    ...body,
  ]);
}

/// App grants a read capability over already-selected local bytes, not a model
/// path/URL. The capture is bounded and copied once; the source cannot be swapped.
final class SkillReadToken {
  SkillReadToken.capture(List<int> selectedBytes) {
    if (selectedBytes.length > 4194304) importFailure('LIMIT', 'envelope');
    requireThat(
      selectedBytes.every((b) => b >= 0 && b <= 255),
      'ENCODING',
      'byteToken',
    );
    _bytes = Uint8List.fromList(selectedBytes).asUnmodifiableView();
  }
  late final Uint8List _bytes;
}

/// Construct ONLY in the trusted, build-time AppProfile composition root. Never
/// deserialize this object from a pack/model/user import-dialog claim.
final class BuildTimeSignaturePolicy {
  factory BuildTimeSignaturePolicy(Map<String, dynamic> profilePolicy) =>
      BuildTimeSignaturePolicy._(jsonEncode(profilePolicy));
  BuildTimeSignaturePolicy._(this._json)
    : value = freezeJson(
        strictJson(utf8.encode(_json), 65536),
      ) as Map<String, Object?>;
  factory BuildTimeSignaturePolicy.disabled(
    AppProfile profile,
    Namespace namespace,
  ) => BuildTimeSignaturePolicy({
    'policyVersion': 'filmcraft-import-v1',
    'policyEpoch': 1,
    'appId': profile.appId,
    'namespace': namespace.toJson(),
    'threshold': 1,
    'trustedSigners': [],
    'maxEnvelopeBytes': 4194304,
    'maxPayloadBytes': 2097152,
    'maxFileBytes': 1048576,
  });
  final String _json;
  final Map<String, Object?> value;
}

/// Trusted App port snapshot. Namespace, scope, policy and clock are NOT package
/// fields. Re-sampled on acknowledgment so grants/keys/time cannot become stale.
final class ImportAppSnapshot {
  ImportAppSnapshot({
    required this.profile,
    required Map<String, dynamic> namespace,
    required this.policy,
    required this.nowSeconds,
    this.clockConfident = false,
    this.clockRollback = false,
    required Set<String> installedAllowlist,
    required Set<String> sessionGrant,
    required Set<String> branchScope,
  }) : namespace = freezeJson(namespace) as Map<String, Object?>,
       installedAllowlist = Set.unmodifiable(installedAllowlist),
       sessionGrant = Set.unmodifiable(sessionGrant),
       branchScope = Set.unmodifiable(branchScope);
  final AppProfile profile;
  String get appId => profile.appId;
  final Map<String, Object?> namespace;
  final BuildTimeSignaturePolicy policy;
  final int nowSeconds;
  final bool clockConfident, clockRollback;
  final Set<String> installedAllowlist, sessionGrant, branchScope;
  Set<String> get allowedTools =>
      installedAllowlist.intersection(sessionGrant).intersection(branchScope);
  String get scopeHash {
    List<String> sorted(Set<String> x) => x.toList()..sort();
    return digest(
      utf8.encode(
        jsonEncode([
          appId,
          profile.version,
          namespace['appId'],
          namespace['tenantId'],
          namespace['workspaceId'],
          sorted(installedAllowlist),
          sorted(sessionGrant),
          sorted(branchScope),
        ]),
      ),
    );
  }
}

final class SkillVerificationReport {
  SkillVerificationReport._({
    required this.previewId,
    required this.envelopeHash,
    required this.payloadHash,
    required this.contentHash,
    required this.policyEpoch,
    required this.namespace,
    required this.verifiedKeyFingerprints,
    required this.trustState,
    required this.requiredTools,
    required this.permissionDiff,
    required this.permissionDiffHash,
    required this.licenseFacts,
    required this.knowledge,
    required this.privilegePreview,
  });
  final String previewId,
      envelopeHash,
      payloadHash,
      contentHash,
      trustState,
      permissionDiffHash;
  final int policyEpoch;
  final Map<String, Object?> namespace, permissionDiff, licenseFacts, knowledge;
  final List<String> verifiedKeyFingerprints, requiredTools;
  final SkillImportPreview privilegePreview;
  int get documentWrites => 0;
  bool get executionAuthority => false;
}

/// Acknowledges one preview, NOT an installation or tool ApprovalReceipt.
final class SkillPreviewAcknowledgment {
  SkillPreviewAcknowledgment._(
    this.previewId,
    this.payloadHash,
    this.contentHash,
    this.namespace,
    this.policyEpoch,
    this.permissionDiffHash,
    this.trustState,
  );
  final String previewId,
      payloadHash,
      contentHash,
      permissionDiffHash,
      trustState;
  final int policyEpoch;
  final Map<String, Object?> namespace;
  bool get executionAuthority => false;
  int get documentWrites => 0;
}

final class _Signer {
  _Signer(this.key, this.fingerprint, this.before, this.after, this.revoked);
  final Uint8List key;
  final String fingerprint;
  final int before, after;
  final bool revoked;
}

final class _Policy {
  _Policy(this.epoch, this.threshold, this.signers);
  final int epoch, threshold;
  final List<_Signer> signers;
}

final class _Pending {
  _Pending(
    this.report,
    this.bytes,
    this.diffBytes,
    this.policyJson,
    this.scopeHash,
    this.time,
  );
  final SkillVerificationReport report;
  final Uint8List bytes, diffBytes;
  final String policyJson, scopeHash;
  final int time;
}

/// App UI-only capability, never registered as a model tool or deserialized.
final class ImportUserActionPort {
  ImportUserActionPort.forTrustedUi();
  ImportUserGesture explicitPreviewConsent(String previewId) =>
      ImportUserGesture._(this, previewId);
}

final class ImportUserGesture {
  ImportUserGesture._(this._issuer, this._previewId);
  final ImportUserActionPort _issuer;
  final String _previewId;
  bool _used = false;
}

final class FilmSkillRepository {
  FilmSkillRepository(this._backend, this._snapshot, this._userActions);
  final SodiumVerifier _backend;
  final ImportAppSnapshot Function() _snapshot;
  final ImportUserActionPort _userActions;
  final _pending = <String, _Pending>{};
  final _random = Random.secure();
  static final _filmSchema =
      jsonDecode(filmSkillSchemaJson) as Map<String, dynamic>;

  _Policy _policy(ImportAppSnapshot app, Map<String, Object?> namespace) {
    final p = object(app.policy.value, {
      'policyVersion',
      'policyEpoch',
      'appId',
      'namespace',
      'threshold',
      'trustedSigners',
      'maxEnvelopeBytes',
      'maxPayloadBytes',
      'maxFileBytes',
    });
    final ns = object(p['namespace'], {'appId', 'tenantId', 'workspaceId'});
    requireThat(
      ns.values.every(isId) && isId(app.appId) && safeInt(app.nowSeconds),
      'POLICY',
    );
    requireThat(
      p['policyVersion'] == 'filmcraft-import-v1' &&
          safeInt(p['policyEpoch'], 1) &&
          safeInt(p['threshold'], 1, 8),
      'POLICY',
    );
    requireThat(
      p['maxEnvelopeBytes'] == 4194304 &&
          p['maxPayloadBytes'] == 2097152 &&
          p['maxFileBytes'] == 1048576,
      'POLICY',
    );
    requireThat(
      p['appId'] == app.appId &&
          ns['appId'] == app.appId &&
          sameJson(ns, namespace) &&
          sameJson(ns, app.namespace),
      'SCOPE',
    );
    final keys = <String>{}, signers = <_Signer>[];
    for (final raw in array(p['trustedSigners'], 8)) {
      final k = object(raw, {
        'publicKeyBase64',
        'keyFingerprint',
        'role',
        'notBefore',
        'notAfter',
        'revoked',
      });
      final key = strictBase64(k['publicKeyBase64'], 32), fp = digest(key);
      requireThat(
        _backend.validPublicKey(key) &&
            k['keyFingerprint'] == fp &&
            keys.add(fp) &&
            k['role'] == 'filmCraftPublisher' &&
            safeInt(k['notBefore']) &&
            safeInt(k['notAfter']) &&
            (k['notBefore'] as int) < (k['notAfter'] as int) &&
            k['revoked'] is bool,
        'POLICY',
      );
      signers.add(
        _Signer(
          key,
          fp,
          k['notBefore'] as int,
          k['notAfter'] as int,
          k['revoked'] as bool,
        ),
      );
    }
    final threshold = p['threshold'] as int;
    requireThat(
      signers.isEmpty ? threshold == 1 : threshold <= signers.length,
      'POLICY',
    );
    return _Policy(p['policyEpoch'] as int, threshold, signers);
  }

  SkillVerificationReport importPack(
    SkillReadToken token,
    Map<String, dynamic> namespace,
    BuildTimeSignaturePolicy signaturePolicy,
  ) {
    ensureImportBackend(_backend);
    final app = _snapshot();
    requireThat(identical(signaturePolicy, app.policy), 'POLICY');
    final policy = _policy(app, namespace);
    final bytes = token._bytes;
    final envelope = object(strictJson(bytes, 4194304));
    requireThat(
      envelope.containsKey('payloadType') &&
          envelope.containsKey('payload') &&
          envelope.containsKey('signatures'),
    );
    requireThat(
      envelope['payloadType'] == signedSkillPayloadType,
      'SIGNATURE',
      'payloadType',
    );
    final body = strictBase64(envelope['payload'], 2097152);
    final signatures = <Uint8List>[];
    for (final v in array(envelope['signatures'], 8)) {
      final entry = object(v);
      requireThat(
        entry.containsKey('sig') &&
            (!entry.containsKey('keyid') || entry['keyid'] is String),
      );
      final sig = strictBase64(entry['sig'], 64);
      requireThat(sig.length == 64, 'ENCODING', 'signature');
      signatures.add(sig);
    }
    final accepted = <String>{};
    final acceptedKeyBytes = <String>{};
    final confident = app.clockConfident && !app.clockRollback;
    if (signatures.isNotEmpty) {
      final pae = dssePae(signedSkillPayloadType, body);
      for (final signer in policy.signers) {
        if (signer.revoked ||
            (confident &&
                (app.nowSeconds < signer.before ||
                    app.nowSeconds >= signer.after))) {
          continue;
        }
        if (signatures.any((sig) => _backend.verify(pae, sig, signer.key))) {
          accepted.add(signer.fingerprint);
          acceptedKeyBytes.add(base64.encode(signer.key));
        }
      }
      requireThat(acceptedKeyBytes.length >= policy.threshold, 'SIGNATURE');
    }
    final payload = object(strictJson(body, 2097152), {
      'schemaVersion',
      'contentType',
      'skillId',
      'version',
      'manifestHash',
      'entrypoint',
      'files',
      'licenseEvidence',
    });
    requireThat(
      payload['schemaVersion'] == '1.0.0' &&
          payload['contentType'] == 'filmCraft' &&
          isId(payload['skillId']) &&
          payload['version'] is String &&
          fullMatch(
            RegExp(r'[0-9]+\.[0-9]+\.[0-9]+'),
            payload['version'] as String,
          ) &&
          isHash(payload['manifestHash']) &&
          payload['entrypoint'] == 'film-skill.json',
    );
    for (final v in array(payload['licenseEvidence'], 16)) {
      final e = object(v, {'licenseId', 'termsSha256'});
      requireThat(isId(e['licenseId']) && isHash(e['termsSha256']));
    }
    final files = <String, Uint8List>{};
    for (final v in array(payload['files'], 3, 3)) {
      final f = object(v, {
        'path',
        'mediaType',
        'byteLength',
        'sha256',
        'data',
      });
      final path = f['path'];
      requireThat(
        path is String &&
            {
              'film-skill.json',
              'skill-manifest.json',
              'test-fixtures.json',
            }.contains(path) &&
            !files.containsKey(path),
        'PATH',
      );
      requireThat(
        f['mediaType'] == 'application/json' &&
            safeInt(f['byteLength'], 1, 1048576) &&
            isHash(f['sha256']),
      );
      final data = strictBase64(f['data'], 1048576);
      requireThat(
        data.length == f['byteLength'] && digest(data) == f['sha256'],
        'HASH',
      );
      files[path as String] = data.asUnmodifiableView();
    }
    final film = object(strictJson(files['film-skill.json']!, 1048576));
    checkSchema(_filmSchema, film, _filmSchema);
    requireThat(
      film['id'] == payload['skillId'] &&
          film['version'] == payload['version'] &&
          film['signatureRef'] == null,
    );
    requireThat(sameJson(film['namespace'], namespace), 'SCOPE');
    _safety(film);
    final manifest = object(
      strictJson(files['skill-manifest.json']!, 1048576),
      {
        'version',
        'contentType',
        'requiredTools',
        'inputSchema',
        'outputSchema',
        'testFixtures',
        'payloadPath',
      },
    );
    requireThat(
      digest(files['skill-manifest.json']!) == payload['manifestHash'],
      'HASH',
    );
    requireThat(
      manifest['version'] == film['version'] &&
          manifest['contentType'] == 'filmCraft' &&
          sameJson(manifest['requiredTools'], film['requiredTools']) &&
          manifest['payloadPath'] == 'film-skill.json',
    );
    final fixtureRef = object(manifest['testFixtures'], {'path', 'sha256'});
    final fixtureHash = digest(files['test-fixtures.json']!);
    requireThat(
      fixtureRef['path'] == 'test-fixtures.json' &&
          fixtureRef['sha256'] == fixtureHash &&
          film['testFixturesHash'] == fixtureHash,
      'HASH',
    );
    for (final name in ['inputSchema', 'outputSchema']) {
      checkManifestSchema(manifest[name]);
    }
    final fixtures = object(strictJson(files['test-fixtures.json']!, 1048576), {
      'cases',
    });
    for (final v in array(fixtures['cases'], 16)) {
      final f = object(v, {'input', 'expectedOutput'});
      for (final pair in [
        ['inputSchema', 'input'],
        ['outputSchema', 'expectedOutput'],
      ]) {
        final s = manifest[pair[0]];
        checkSchema(
          s,
          f[pair[1]],
          s is Map<String, dynamic> ? s : <String, dynamic>{},
        );
      }
    }
    final tools =
        (film['requiredTools'] as List).cast<String>().toSet().toList()..sort();
    final missing = tools.where((x) => !app.allowedTools.contains(x)).toList();
    final diff = {'requiredTools': tools, 'missingTools': missing};
    final diffBytes = Uint8List.fromList(utf8.encode(jsonEncode(diff)))
        .asUnmodifiableView();
    final trust = !confident
        ? 'needsReview'
        : signatures.isEmpty
        ? 'unsignedUntrusted'
        : 'verified';
    final fingerprints = accepted.toList()..sort();
    // Local license assertions are unverified facts, never an authorization grant.
    final facts = {
      'declaredLicense': film['license'],
      'evidence': payload['licenseEvidence'],
      'warnings': [
        'LICENSE_DECLARATION_UNVERIFIED',
        if ((payload['licenseEvidence'] as List).isEmpty)
          'LICENSE_EVIDENCE_MISSING',
      ],
      'commercialRiskPolicy': 'allow_with_warning',
      'licenseGranted': false,
    };
    final nonce = base64Url.encode(
      List<int>.generate(16, (_) => _random.nextInt(256)),
    );
    // Bound retained previews; explicit disposal permits the App to release bytes.
    requireThat(_pending.length < 16, 'LIMIT', 'pendingPreviews');
    final report = SkillVerificationReport._(
      previewId: nonce,
      envelopeHash: digest(bytes),
      payloadHash: digest(body),
      contentHash: digest(files['film-skill.json']!),
      policyEpoch: policy.epoch,
      namespace: freezeJson(namespace) as Map<String, Object?>,
      verifiedKeyFingerprints: List.unmodifiable(fingerprints),
      trustState: trust,
      requiredTools: List.unmodifiable(tools),
      permissionDiff: freezeJson(diff) as Map<String, Object?>,
      permissionDiffHash: digest(diffBytes),
      licenseFacts: freezeJson(facts) as Map<String, Object?>,
      knowledge: freezeJson(film) as Map<String, Object?>,
      privilegePreview: SkillImportPreview(
        skillSnapshotHash: digest(files['film-skill.json']!),
        untrusted: trust != 'verified',
        addedTools: const [],
        requiredApprovals: const ['userConfirm'],
      ),
    );
    _pending[nonce] = _Pending(
      report,
      bytes,
      diffBytes,
      app.policy._json,
      app.scopeHash,
      app.nowSeconds,
    );
    return report;
  }

  /// UI invokes ONLY after explicit user acknowledgment; accepting model-supplied
  /// "confirmed" flags is not a valid App integration. The ID binds retained data.
  SkillPreviewAcknowledgment acknowledge(ImportUserGesture gesture) {
    ensureImportBackend(_backend);
    requireThat(
      identical(gesture._issuer, _userActions) && !gesture._used,
      'PREVIEW_STALE',
    );
    gesture._used = true;
    final previewId = gesture._previewId;
    final pending = _pending.remove(previewId);
    requireThat(pending != null, 'PREVIEW_STALE');
    final p = pending!, report = p.report, app = _snapshot();
    final policy = _policy(app, report.namespace);
    requireThat(
      report.trustState != 'needsReview' &&
          app.clockConfident &&
          !app.clockRollback &&
          app.nowSeconds >= p.time &&
          policy.epoch == report.policyEpoch &&
          app.policy._json == p.policyJson &&
          app.scopeHash == p.scopeHash &&
          digest(p.bytes) == report.envelopeHash &&
          digest(p.diffBytes) == report.permissionDiffHash,
      'PREVIEW_STALE',
    );
    if (report.trustState == 'verified') {
      final eligible = policy.signers
          .where(
            (s) =>
                !s.revoked &&
                app.nowSeconds >= s.before &&
                app.nowSeconds < s.after,
          )
          .map((s) => s.fingerprint)
          .toSet();
      requireThat(
        report.verifiedKeyFingerprints.where(eligible.contains).length >=
            policy.threshold,
        'PREVIEW_STALE',
      );
    }
    return SkillPreviewAcknowledgment._(
      report.previewId,
      report.payloadHash,
      report.contentHash,
      report.namespace,
      report.policyEpoch,
      report.permissionDiffHash,
      report.trustState,
    );
  }

  void discard(String previewId) {
    _pending.remove(previewId);
  }

  void _safety(Map<String, dynamic> film) {
    final slotKeys = <String>{};
    for (final raw in film['parameterSlots'] as List) {
      final slot = raw as Map<String, dynamic>;
      requireThat(
        slotKeys.add(slot['key'] as String),
        'SCHEMA',
        'parameterSlots',
      );
      final value = slot['defaultValue'];
      if (slot['kind'] == 'number') {
        requireThat(
          (slot['minimum'] as num) <= (slot['maximum'] as num) &&
              (value == null ||
                  ((value as num) >= (slot['minimum'] as num) &&
                      value <= (slot['maximum'] as num))),
          'SCHEMA',
          'parameterRange',
        );
      } else if (slot['kind'] == 'enum') {
        final choices = slot['choices'] as List;
        requireThat(
          choices.toSet().length == choices.length &&
              (value == null || choices.contains(value)),
          'SCHEMA',
          'parameterEnum',
        );
      } else if (slot['kind'] == 'time' && value != null) {
        try {
          Q.fromJson(value as Map<String, dynamic>);
        } on StudioException {
          importFailure('SCHEMA', 'parameterTime');
        }
      }
      // EntityRef slots only declare a kind. No bound entity is imported or
      // resolved here; current entity/scope gates remain required at compile.
    }
    final required = (film['requiredTools'] as List).cast<String>().toSet();
    final steps = (film['steps'] as List).cast<Map<String, dynamic>>();
    final ids = <String>{};
    for (final s in steps) {
      requireThat(
        ids.add(s['id'] as String) &&
            required.contains(s['toolId']) &&
            admittedFilmCraftTools.contains(s['toolId']),
        'SCHEMA',
        'steps',
      );
    }
    final byId = {for (final s in steps) s['id']: s};
    final visiting = <String>{}, done = <String>{};
    void visit(String id) {
      requireThat(
        byId.containsKey(id) && !visiting.contains(id),
        'SCHEMA',
        'dag',
      );
      if (done.contains(id)) return;
      visiting.add(id);
      for (final dep in byId[id]!['dependsOn'] as List) {
        visit(dep as String);
      }
      visiting.remove(id);
      done.add(id);
    }

    for (final id in ids) {
      visit(id);
    }
    void refuseRemote(Object? x) {
      if (x is Map) {
        if (x.containsKey(r'$ref')) {
          requireThat(
            x[r'$ref'] is String && (x[r'$ref'] as String).startsWith('#/'),
            'SCHEMA',
            'remoteRef',
          );
        }
        for (final v in x.values) {
          refuseRemote(v);
        }
      } else if (x is List) {
        for (final v in x) {
          refuseRemote(v);
        }
      }
    }

    refuseRemote(film);
  }
}
