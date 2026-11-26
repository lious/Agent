import 'dart:convert';
import 'dart:io';

import 'package:studio_sdk/studio_sdk.dart';
import 'package:studio_store/blob_store.dart';
import 'package:studio_store/project_archive.dart';
import 'package:test/test.dart';

/// Increment 1.93 official I-014 remainingAcceptance wording
/// 「自动外链均拒」 on the already-admitted ResourcePreservationSession and
/// writable ProjectArchive paths. Opening a granted JSON that plants an
/// HTTP locator and a file locator must not fetch or follow them; writable
/// packing stays refused as FEATURE_NOT_IMPLEMENTED. This file does not
/// rewrite files_test.dart, resource_preservation_test.dart, or invent
/// packMode=linked.
Namespace get ns => Namespace('studio', 'local', 'i014-external-link');

const locatorId = 'locator-1914-unresolved';
const sentinelBody = 'I014-SENTINEL-1914';

Matcher code(String c) =>
    throwsA(isA<StudioException>().having((e) => e.code, 'code', c));

void main() {
  late Directory dir;
  late HttpServer server;
  late List<String> requested;

  setUp(() async {
    dir = Directory.systemTemp.createTempSync('i014-external-link-');
    requested = <String>[];
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      requested.add('${request.method} ${request.uri}');
      request.response.statusCode = 200;
      request.response.write('must-not-fetch');
      await request.response.close();
    });
  });
  tearDown(() async {
    await server.close(force: true);
    dir.deleteSync(recursive: true);
  });

  test('preservation open and writable pack do not auto-fetch planted external locators', () async {
    final sentinel = File('${dir.path}/sentinel.bin')
      ..writeAsStringSync(sentinelBody);
    final before = sentinel.statSync();
    final url = 'http://127.0.0.1:${server.port}/i014-must-not-fetch';
    final data =
        jsonDecode(File('fixtures/project/local-video.json').readAsStringSync())
            as Map<String, dynamic>;
    data['assets'][0]['externalLocator'] = locatorId;
    data['extensions'] = {
      'i014.unresolved': {
        'locator': url,
        'fileLocator': 'file://${sentinel.absolute.path}',
      },
    };
    final jsonFile = File('${dir.path}/project.json')
      ..writeAsStringSync(jsonEncode(data));

    final session = await ResourcePreservationSession.openJson(
      LocalFileGrant.fromUserSelection(jsonFile),
    );
    expect(
      session.project.toJson()['assets'][0]['externalLocator'],
      locatorId,
    );
    final issues = session.report['issues'] as List;
    expect(
      issues.any((issue) => issue['code'] == 'EXTERNAL_MEDIA_UNRESOLVED'),
      isTrue,
    );

    await Future<void>.delayed(const Duration(milliseconds: 80));
    expect(requested, isEmpty);
    expect(sentinel.readAsStringSync(), sentinelBody);
    final after = sentinel.statSync();
    expect(after.size, before.size);
    expect(after.modified, before.modified);

    final dest = File('${dir.path}/out.zip');
    await expectLater(
      ProjectArchive().save(
        session.project,
        BlobStore(Directory('${dir.path}/cas'), ns),
        dest,
      ),
      code('FEATURE_NOT_IMPLEMENTED'),
    );
    expect(dest.existsSync(), false);
    expect(requested, isEmpty);
  });
}
