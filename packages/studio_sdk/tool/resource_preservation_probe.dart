import 'dart:io';
import 'dart:convert';

import 'package:studio_sdk/studio_sdk.dart';

Future<void> main(List<String> args) async {
  if (args.length != 1) {
    throw ArgumentError('explicit read-only archive path required');
  }
  final session = await ResourcePreservationSession.openArchive(
    LocalFileGrant.fromUserSelection(File(args.single)),
  );
  stdout.writeln(
    jsonEncode({'projectHash': session.project.hash, 'report': session.report}),
  );
}
