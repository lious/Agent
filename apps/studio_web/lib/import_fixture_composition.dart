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
    this.chooseSourceForTest,
  });
  final BuildTimeSignaturePolicy Function(AppProfile, Namespace) policyForOwner;
  final int nowSeconds;
  final bool clockConfident, clockRollback;
  final bool lifecycleTestControls;
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
