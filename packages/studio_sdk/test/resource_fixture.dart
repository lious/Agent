import 'dart:convert';
import 'dart:io';

import 'package:studio_document/studio_document.dart';

Map<String, dynamic> resourceFixture(List<int> font, List<int> mask) {
  final d = jsonDecode(
    File(
      '${File(Platform.environment['STUDIO_TEST_VIDEO']!).parent.parent.parent.path}/fixtures/project/local-video.json',
    ).readAsStringSync(),
  ) as Map<String, dynamic>;
  final fh = rawBytesHash(font), mh = rawBytesHash(mask);
  d['blobs'].addAll([
    {
      'hash': fh,
      'bytes': font.length.toString(),
      'mime': 'font/ttf',
      'packagePath': 'fonts/Roboto-Regular.ttf',
      'role': 'font',
    },
    {
      'hash': mh,
      'bytes': mask.length.toString(),
      'mime': 'image/png',
      'packagePath': 'assets/layer-mask.png',
      'role': 'mask',
    },
  ]);
  d['fontRefs'] = [
    {
      'id': 'font-fixture',
      'family': 'Roboto fixture',
      'style': 'Regular',
      'hash': fh,
      'licenseRef': null,
      'embedAllowed': false,
      'fallbackFamilies': <String>[],
    },
  ];
  d['defaultFontRef'] = 'font-fixture';
  d['imageDocuments'] = [
    {
      'id': 'image-fixture',
      'version': '1',
      'width': 320,
      'height': 180,
      'color': 'linear-rec709',
      'rootLayerIds': ['layer-fixture'],
      'layers': [
        {
          'id': 'layer-fixture',
          'parentId': null,
          'kind': 'raster',
          'sourceRef': {
            'id': d['assets'][0]['id'],
            'version': d['assets'][0]['version'],
          },
          'text': null,
          'transform': [1, 0, 0, 1, 0, 0],
          'opacity': 1,
          'blendMode': 'normal',
          'maskRef': mh,
          'effectIds': ['mask-fixture'],
          'locked': false,
          'visible': true,
        },
      ],
      'fontRefs': ['font-fixture'],
    },
  ];
  d['effects'] = [
    {
      'id': 'mask-fixture',
      'version': '1',
      'owner': {'kind': 'imageLayer', 'id': 'layer-fixture'},
      'pluginVersion': '1.0.0',
      'enabled': true,
      'keyframes': <dynamic>[],
      'extensions': <String, dynamic>{},
      'type': 'mask',
      'parameters': {
        'blobHash': mh,
        'transform': [1, 0, 0, 1, 0, 0],
        'invert': false,
      },
    },
  ];
  ProjectDocument.fromJson(d);
  return d;
}

List<int> fixtureMask() => base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQIHWP4z8DwHwAFgAI/ScLbtAAAAABJRU5ErkJggg==',
);
File fixtureFont() => File(
  '/workspace/toolchains/flutter/bin/cache/artifacts/material_fonts/Roboto-Regular.ttf',
);
