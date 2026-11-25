import 'dart:io';

import 'package:studio_contracts/studio_contracts.dart';
import 'package:studio_document/studio_document.dart';

void main() {
  final project = ProjectDocument.empty(
    namespace: Namespace('studio', 'local', 'ws'),
    projectId: 'p1',
    title: 'Example',
  );
  File('fixtures/project/empty-2.0.0.json')
      .writeAsStringSync('${project.canonicalJson}\n');
}
