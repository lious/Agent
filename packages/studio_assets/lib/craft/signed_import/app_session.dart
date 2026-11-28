/// Opt-in App-owned session logic only. Never exported as a model/tool endpoint.
library;

import 'dart:typed_data';

import 'package:studio_contracts/studio_contracts.dart';

import 'importer.dart';
import 'source_capture.dart';

typedef ImportRepositoryFactory = Future<FilmSkillRepository> Function(
  ImportAppSnapshot Function() currentApp,
  ImportUserActionPort actions,
);

final class AppImportSession {
  AppImportSession({
    required this.currentApp,
    required this.capture,
    required this.changed,
  }) : _initial = currentApp(),
       _actions = ImportUserActionPort.forTrustedUi() {
    _lastTime = _initial.nowSeconds;
  }
  final ImportAppSnapshot Function() currentApp;
  final SkillSourceCapture capture;
  final void Function() changed;
  final ImportAppSnapshot _initial;
  final ImportUserActionPort _actions;
  FilmSkillRepository? _repository;
  SkillVerificationReport? _report;
  SkillVerificationReport? get report => _report;
  String state = 'initializing', status = 'Preview backend initializing';
  bool _live = true, _disposed = false, _started = false;
  int _generation = 0;
  late int _lastTime;
  bool fence() {
    if (!_live || _disposed) return false;
    try {
      final now = currentApp();
      final valid =
          identical(now.profile, _initial.profile) &&
          identical(now.policy, _initial.policy) &&
          now.scopeHash == _initial.scopeHash &&
          now.clockConfident == _initial.clockConfident &&
          now.clockRollback == _initial.clockRollback &&
          now.nowSeconds >= _lastTime;
      if (valid) _lastTime = now.nowSeconds;
      return valid;
    } catch (_) {
      return false;
    }
  }

  void _emit() {
    if (!_disposed) changed();
  }

  Future<void> initialize(ImportRepositoryFactory create) async {
    if (_started || !_live || _disposed) return;
    _started = true;
    final generation = _generation;
    try {
      final repository = await create(currentApp, _actions);
      if (!_live || _disposed || generation != _generation || !fence()) {
        retire();
        return;
      }
      _repository = repository;
      state = 'ready';
      status = 'Ready for preview only';
    } catch (_) {
      if (_live && !_disposed) {
        state = 'unavailable';
        status = 'Preview backend unavailable';
      }
    }
    _emit();
  }

  bool get canChoose =>
      _live &&
      !capture.busy &&
      _repository != null &&
      ['ready', 'preview', 'acknowledged'].contains(state) &&
      fence();
  bool get canAcknowledge {
    if (!_live ||
        state != 'preview' ||
        _report == null ||
        _report!.trustState == 'needsReview' ||
        !fence()) {
      return false;
    }
    final app = currentApp();
    return app.clockConfident && !app.clockRollback;
  }

  void reading() {
    if (_live && state == 'picking') {
      state = 'reading';
      _emit();
    }
  }

  Future<void> choose(Future<Uint8List?> Function() select) async {
    if (!canChoose) return;
    discard(notify: false);
    final generation = _generation;
    state = 'picking';
    status = 'Choose one local source';
    _emit();
    try {
      // Do NOT await readiness or dispatch before the trusted synchronous picker.
      final bytes = await select();
      await capture.quiescent;
      if (!_live || _disposed || generation != _generation || !fence()) {
        retire();
        return;
      }
      if (bytes == null) {
        state = 'ready';
        status = 'Selection cancelled';
        return;
      }
      state = 'checking';
      status = 'Checking captured bytes';
      _emit();
      final app = currentApp();
      final result = _repository!.importPack(
        SkillReadToken.capture(bytes),
        Map<String, dynamic>.from(app.namespace),
        app.policy,
      );
      if (!_live || generation != _generation || !fence()) {
        _repository!.discard(result.previewId);
        retire();
        return;
      }
      _report = result;
      state = 'preview';
      status = 'Preview only — not approval';
    } on StudioException catch (e) {
      discard(notify: false);
      state = 'ready';
      status = e.code.startsWith('SKILL_IMPORT_') ? e.code : 'Import refused';
    } on SkillSourceException catch (e) {
      discard(notify: false);
      if (e.reason == 'scopeChanged') {
        retire();
        return;
      }
      state = 'ready';
      status = 'Source capture refused';
    } catch (_) {
      discard(notify: false);
      state = 'ready';
      status = 'Source or import refused';
    } finally {
      await capture.quiescent;
      if (_live && !_disposed) _emit();
    }
  }

  void acknowledge() {
    if (!canAcknowledge) {
      if (!fence()) retire();
      return;
    }
    final target = _report!;
    state = 'acknowledging';
    _emit();
    try {
      final result = _repository!.acknowledge(
        _actions.explicitPreviewConsent(target.previewId),
      );
      _report = null;
      state = 'acknowledged';
      status =
          'Preview acknowledged only; documentWrites=${result.documentWrites}; executionAuthority=${result.executionAuthority}; installs nothing';
    } catch (_) {
      discard(notify: false);
      state = 'ready';
      status = 'Preview stale or refused; select again';
    }
    _emit();
  }

  void discard({bool notify = true}) {
    final target = _report;
    if (target != null) _repository?.discard(target.previewId);
    _report = null;
    if (_live && _repository != null) {
      state = 'ready';
      status = 'Preview dismissed';
    }
    if (notify) _emit();
  }

  void cancel() {
    capture.cancel();
    discard(notify: false);
    status = 'Cancelling; waiting for source quiescence';
    state = 'reading';
    _emit();
  }

  /// Call BEFORE publishing any known App profile/policy/scope/grant/clock change.
  /// Increment first, so an equal-looking ABA replacement never revives this owner.
  void retire() {
    if (!_live) return;
    ++_generation;
    _live = false;
    capture.cancel();
    discard(notify: false);
    _repository = null;
    state = 'invalidated';
    status = 'App context changed; preview retired';
    _emit();
  }

  void refresh() {
    if (!fence()) retire();
  }

  void dispose() {
    _disposed = true;
    retire();
    capture.dispose();
  }
}
