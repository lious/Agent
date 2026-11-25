import 'dart:convert';
import 'dart:io';

import 'package:studio_contracts/studio_contracts.dart';
import 'package:studio_media/studio_media.dart';

void main(List<String> args) {
  if (args.length != 2) {
    throw ArgumentError(
      'Usage: probe.dart <trusted library> <selected local media>',
    );
  }
  final native = NativeMedia.open(
    args[0],
    Namespace('probe', 'local', 'development'),
  );
  try {
    print(jsonEncode(native.probe(File(args[1]))));
  } finally {
    native.close();
  }
}
