import 'dart:convert';

import 'package:studio_gltf_probe/studio_gltf_probe.dart';
import 'package:test/test.dart';

/// Increment 2.63 official first V-026 slice: untrusted glTF resource
/// refusal. This file does not invent a glTF runtime, does not claim
/// preview consistency or V-026=gltf-preview, does not start I-061,
/// does not open NeRF/3DGS, does not re-qualify I-039 or I-038, does
/// not start I-035 or I-055, does not invent a limiter, and does not
/// mark I-037, I-038, V-007, V-020, I-054, I-051, I-046, I-041, I-040,
/// I-053, I-056, I-057, I-052, or I-039 complete. InversePatch kind
/// stays restoreSnapshot. Project user_version stays 9.
List<Object> damagedInputs() {
  final inputs = <Object>[
    '',
    '{',
    'null',
    '[]',
    'true',
    '0',
    '{"asset":1}',
    '{"asset":{"version":2}}',
    '{"asset":{"version":"2.0"},"buffers":{}}',
    '{"asset":{"version":"2.0"},"buffers":[1]}',
    '{"asset":{"version":"2.0"},"buffers":[{"byteLength":-1}]}',
    '{"asset":{"version":"2.0"},"buffers":[{"byteLength":20971521}]}',
    '{"asset":{"version":"2.0"},"accessors":[{"count":-3}]}',
    '{"asset":{"version":"2.0"},"meshes":["bad"]}',
    '{"asset":{"version":"2.0"},"nodes":null}',
    '{"asset":{"version":"2.0"},"extensionsUsed":1}',
    '{"asset":{"version":"2.0"},"extensionsUsed":[1]}',
    utf8.encode('{'),
    utf8.encode(''),
    {'asset': 'nope'},
  ];
  for (var i = 0; i < 80; i++) {
    inputs.add(
      '{"asset":{"version":"2.0"},"buffers":[{"byteLength":${-i - 1}}]}',
    );
  }
  return inputs;
}

void main() {
  test('a local core document is admitted without fetching, previewing, or inventing a runtime', () {
    final admission = UntrustedGltfAdmission();
    final report = admission.admit(localCoreGltf);
    expect(report.admitted, isTrue);
    expect(report.networkRequestCount, 0);
    expect(report.autoFetchExternalUrl, isFalse);
    expect(report.previewed, isFalse);
    expect(report.previewConsistencyClaimed, isFalse);
    expect(report.runtimeInvented, isFalse);
    expect(report.v026GltfPreviewClaimed, isFalse);
    expect(report.i061Started, isFalse);
    expect(report.nerfOpened, isFalse);
    expect(admission.runtimeInvented, isFalse);
    expect(admission.previewConsistencyClaimed, isFalse);
    expect(admission.v026GltfPreviewClaimed, isFalse);
    expect(admission.i061Started, isFalse);
    expect(admission.documentWrites, 0);
    expect(admission.paidApiCalled, isFalse);
  });

  test('external URLs and path traversal are refused with zero network requests; unsupported extensions are refused and not dropped', () {
    final admission = UntrustedGltfAdmission();
    for (final uri in [
      'https://evil.example/buf.bin',
      'http://evil.example/img.png',
      'file:///etc/passwd',
      'ftp://evil.example/a',
      '//cdn.example/buf.bin',
      '../secret.bin',
      '/etc/passwd',
    ]) {
      final report = admission.admit(
        '{"asset":{"version":"2.0"},"buffers":[{"byteLength":4,"uri":"$uri"}]}',
      );
      expect(report.admitted, isFalse, reason: uri);
      expect(report.refusalCode, 'EXTERNAL_URL_FORBIDDEN', reason: uri);
      expect(report.networkRequestCount, 0, reason: uri);
      expect(report.autoFetchExternalUrl, isFalse);
    }

    final required = admission.admit(
      '{"asset":{"version":"2.0"},"extensionsRequired":["KHR_materials_variants"]}',
    );
    expect(required.admitted, isFalse);
    expect(required.refusalCode, 'EXTENSION_UNSUPPORTED');
    expect(required.networkRequestCount, 0);

    final used = admission.admit(
      '{"asset":{"version":"2.0"},"extensionsUsed":["EXT_evil_code"]}',
    );
    expect(used.admitted, isFalse);
    expect(used.refusalCode, 'EXTENSION_UNSUPPORTED');

    final unknown = admission.admit(
      '{"asset":{"version":"2.0"},"weirdPipeline":{"run":"os"}}',
    );
    expect(unknown.admitted, isTrue);
    expect(unknown.unknownNodesRetained, ['weirdPipeline']);
    expect(admission.runtimeInvented, isFalse);
  });

  test('100 damaged inputs are refused without escaping or crashing, and none are auto-fetched', () {
    final admission = UntrustedGltfAdmission();
    final inputs = damagedInputs();
    expect(inputs, hasLength(100));
    var refused = 0;
    for (final input in inputs) {
      final report = admission.admit(input);
      expect(report.admitted, isFalse);
      expect(report.refusalCode, 'DAMAGED_INPUT');
      expect(report.networkRequestCount, 0);
      refused += 1;
    }
    expect(refused, 100);
    expect(admission.previewConsistencyClaimed, isFalse);
    expect(admission.v026GltfPreviewClaimed, isFalse);
    expect(admission.runtimeInvented, isFalse);
  });
}
