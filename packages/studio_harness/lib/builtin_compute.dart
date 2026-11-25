import 'dart:math' as math;

import 'package:studio_contracts/studio_contracts.dart';

import 'device_scheduler.dart';

/// Free deterministic built-ins only; never a shell, model runner or provider.
/// Handler pins are semantic algorithm/version pins, not a runtime SBOM signature.
final class BuiltinCompute {
  static Map<String, Object> pin(String id) {
    if (!['core.digest-json', 'core.pcm-rms'].contains(id)) {
      throw const StudioException('HANDLER_NOT_INSTALLED');
    }
    return {
      'id': id,
      'version': '1.0.0',
      'hash': harnessHash({
        'id': id,
        'version': '1.0.0',
        'algorithm': id == 'core.digest-json' ? 'jcs-sha256-v1' : 'rms-f64-v1',
      }),
    };
  }

  static Map<String, Object> execute(
    Map<String, dynamic> handler,
    Object? input,
  ) {
    final id = handler['id'];
    if (id is! String || harnessHash(handler) != harnessHash(pin(id))) {
      throw const StudioException('HANDLER_PIN_MISMATCH');
    }
    var count = 0;
    void check(Object? value, int depth) {
      if (depth > 32 || ++count > 500000) {
        throw const StudioException('COMPUTE_INPUT_LIMIT');
      }
      if (value is Map) {
        if (value.length > 10000) {
          throw const StudioException('COMPUTE_INPUT_LIMIT');
        }
        for (final e in value.entries) {
          if (e.key is! String) {
            throw const StudioException('COMPUTE_INPUT_INVALID');
          }
          check(e.value, depth + 1);
        }
      } else if (value is List) {
        for (final v in value) {
          check(v, depth + 1);
        }
      } else if (value is String) {
        if (value.length > 1024 * 1024) {
          throw const StudioException('COMPUTE_INPUT_LIMIT');
        }
      } else if (value is num) {
        if (!value.isFinite) {
          throw const StudioException('COMPUTE_INPUT_INVALID');
        }
      } else if (value != null && value is! bool) {
        throw const StudioException('COMPUTE_INPUT_INVALID');
      }
    }

    check(input, 0);
    if (input is! Map || input.length != 1) {
      throw const StudioException('COMPUTE_INPUT_INVALID');
    }
    if (id == 'core.digest-json') {
      if (!input.containsKey('payload')) {
        throw const StudioException('COMPUTE_INPUT_INVALID');
      }
      return {'sha256': harnessHash(input['payload'])};
    }
    final values = input['samples'];
    if (values is! List || values.isEmpty || values.length > 480000) {
      throw const StudioException('COMPUTE_INPUT_INVALID');
    }
    var sum = 0.0;
    for (final value in values) {
      if (value is! num || !value.isFinite || value < -1 || value > 1) {
        throw const StudioException('COMPUTE_INPUT_INVALID');
      }
      sum += value * value;
    }
    return {
      'rms': math.sqrt(sum / values.length),
      'sampleCount': values.length.toString(),
    };
  }
}
