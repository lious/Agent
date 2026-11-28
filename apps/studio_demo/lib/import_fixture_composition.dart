// App-private typed test composition. Contains NO fixture roots/time or consent port.
import 'dart:typed_data';

import 'package:studio_assets/craft/signed_import/importer.dart';
import 'package:studio_assets/craft/signed_import/source_capture.dart';
import 'package:studio_sdk/studio_sdk.dart';

final class NativeImportFixtureConfiguration {
  NativeImportFixtureConfiguration({
    required this.policyForOwner,
    required this.nowSeconds,
    required this.clockConfident,
    this.clockRollback = false,
    this.chooseSourceForTest,
    this.readerControlsForTest,
    Set<String> installedAllowlist = const {},
    Set<String> sessionGrant = const {},
    Set<String> branchScope = const {},
  }) : installedAllowlist = Set.unmodifiable(installedAllowlist),
       sessionGrant = Set.unmodifiable(sessionGrant),
       branchScope = Set.unmodifiable(branchScope);
  final BuildTimeSignaturePolicy Function(AppProfile, Namespace) policyForOwner;
  final int nowSeconds;
  final bool clockConfident, clockRollback;
  final Set<String> installedAllowlist, sessionGrant, branchScope;
  final Future<Uint8List?> Function(
    SkillSourceCapture,
    bool Function(),
    void Function(),
  )?
  chooseSourceForTest;
  final NativeImportFixtureReaderControls? readerControlsForTest;
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

// App-private typed TEST control only; native rows hold the first read.
abstract interface class NativeImportFixtureReaderControls {
  void arm();
  void release();
}
