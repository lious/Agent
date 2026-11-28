// App-private typed test composition. Contains NO fixture roots/time or consent port.
import 'dart:typed_data';

import 'package:studio_assets/craft/signed_import/importer.dart';
import 'package:studio_assets/craft/signed_import/source_capture.dart';
import 'package:studio_contracts/studio_contracts.dart';

final class AppImportFixtureConfiguration {
  const AppImportFixtureConfiguration({
    required this.policyForOwner,
    required this.nowSeconds,
    required this.clockConfident,
    this.clockRollback = false,
    this.lifecycleTestControls = false,
    this.observeRepositoryForTest = false,
    this.chooseSourceForTest,
    this.readerControlsForTest,
    this.transitions = const [],
  });
  final BuildTimeSignaturePolicy Function(AppProfile, Namespace) policyForOwner;
  final AppImportFixtureReaderControls? readerControlsForTest;
  final List<AppImportFixtureTransition> transitions;
  final int nowSeconds;
  final bool clockConfident, clockRollback;
  final bool lifecycleTestControls, observeRepositoryForTest;
  final Future<Uint8List?> Function(
    SkillSourceCapture,
    bool Function(),
    void Function(),
  )?
  chooseSourceForTest;
}

// Synchronous App-only lifetime signal, never a consent/action endpoint.
final class ImportCompositionLifetime {
  final _listeners = <void Function()>{};
  int _generation = 0;
  void Function() register(void Function() retire) {
    if (_generation != 0) retire();
    _listeners.add(retire);
    return () => _listeners.remove(retire);
  }

  void invalidateBeforePublication() {
    ++_generation;
    for (final retire in List.of(_listeners)) {
      retire();
    }
  }
}

// Typed trusted test inputs, not snapshots, repository factories or action ports.
final class AppImportFixtureTransition {
  AppImportFixtureTransition(this.label, List<AppImportFixtureChange> steps)
    : steps = List.unmodifiable(steps);
  final String label;
  final List<AppImportFixtureChange> steps;
}

final class AppImportFixtureChange {
  AppImportFixtureChange({
    this.profileForOwner,
    this.policyForOwner,
    this.projectId,
    Set<String>? installed,
    Set<String>? session,
    Set<String>? branch,
    this.nowSeconds,
    this.clockConfident,
    this.clockRollback,
  }) : installed = installed == null ? null : Set.unmodifiable(installed),
       session = session == null ? null : Set.unmodifiable(session),
       branch = branch == null ? null : Set.unmodifiable(branch);
  final AppProfile Function(AppProfile)? profileForOwner;
  final BuildTimeSignaturePolicy Function(AppProfile, Namespace)?
  policyForOwner;
  final String? projectId;
  final Set<String>? installed, session, branch;
  final int? nowSeconds;
  final bool? clockConfident, clockRollback;
}

// App-private typed TEST control only; no repository, snapshot or consent input.
enum AppImportFixtureReaderBoundary { open, length, read, close }

abstract interface class AppImportFixtureReaderControls {
  void arm(AppImportFixtureReaderBoundary boundary);
  void release();
}
