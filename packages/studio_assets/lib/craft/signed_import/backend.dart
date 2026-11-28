/// Concrete backend selection, not an injectable verification interface.
library;

export 'backend_unavailable.dart'
    if (dart.library.io) 'backend_native.dart'
    if (dart.library.js_interop) 'sodium_verifier_web.dart';
