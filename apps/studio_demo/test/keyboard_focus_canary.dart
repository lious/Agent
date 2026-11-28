// TEST ONLY keyboard/focus transport canary, not product UI or N01 acceptance.
import 'dart:io';

import 'package:material_ui/material_ui.dart';

void main() {
  final out = Platform.environment['STUDIO_KEYBOARD_CANARY_OUT'];
  if (out == null || out.isEmpty) {
    throw StateError('STUDIO_KEYBOARD_CANARY_OUT is required');
  }
  runApp(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: FilledButton(
            onPressed: () => File(out).writeAsStringSync('activated'),
            child: const Text('Canary activate'),
          ),
        ),
      ),
    ),
  );
}
