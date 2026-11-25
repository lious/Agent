import 'dart:io';
import 'dart:convert';

import 'package:studio_media/studio_media.dart';
import 'package:studio_contracts/studio_contracts.dart';

Future<void> main(List<String> args) async {
  final media = NativeMedia.open(args[0], Namespace('off', 'test', 'local'));
  final dir = Directory.systemTemp.createTempSync('proxy-off-');
  try {
    if (media.capabilities['pulseServicePlaybackV1'] != false ||
        media.capabilities['rgba128PtsProxyV1'] != true) {
      throw StateError('Capability mismatch');
    }
    var refused = false;
    try {
      media.playback({'op': 'status'});
    } on StudioException catch (e) {
      refused = e.code == 'AUDIO_SINK_ADAPTER_UNAVAILABLE';
    }
    if (!refused) throw StateError('Missing explicit refusal');
    final facts = await media.buildPreviewProxyAsync(
      File(args[1]),
      File('${dir.path}/frames.rgba'),
    );
    if ((facts['frames'] as List).length != 90) {
      throw StateError('Proxy did not run');
    }
    print(
      jsonEncode({
        'status': 'passed',
        'capability': false,
        'unavailable': 'AUDIO_SINK_ADAPTER_UNAVAILABLE',
        'proxyFrames': 90,
        'platform': 'Linux OFF configuration, NOT a non-Linux build',
      }),
    );
  } finally {
    media.close();
    dir.deleteSync(recursive: true);
  }
}
