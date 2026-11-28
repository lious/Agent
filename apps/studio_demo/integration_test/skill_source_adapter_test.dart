// BOX GTK integration only. No user machine, crypto, importer or product UI.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:studio_assets/craft/signed_import/source_capture.dart';
import 'package:studio_demo/skill_source_linux.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'actual GTK single selection/cancel/reselection and bounded native capture',
    (tester) async {
      final root = Platform.environment['STUDIO_SOURCE_FIXTURES']!,
          helper = Platform.environment['STUDIO_SOURCE_GTK_HELPER']!;
      final capture = SkillSourceCapture(), cases = <String>[];
      Future<Uint8List?>? pending;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FilledButton(
              key: const Key('choose'),
              onPressed: () {
                pending = chooseLinuxSkillSource(capture);
                pending!.ignore();
              },
              child: const Text('Choose public source fixture'),
            ),
          ),
        ),
      );
      Future<void> run(String name, int? size, {bool limit = false}) async {
        final path = size == null ? '' : '$root/$name.bin';
        if (size != null) {
          File(path).writeAsBytesSync(List<int>.filled(size, 42));
        }
        final driver = (await tester.runAsync(
          () => Process.start('python3', [
            helper,
            size == null ? 'cancel' : 'select',
            path,
          ]),
        ))!;
        final output = driver.stdout.transform(utf8.decoder).join(),
            errors = driver.stderr.transform(utf8.decoder).join();
        await tester.tap(find.byKey(const Key('choose')));
        await tester.pump();
        await tester.runAsync(() async {
          expect(
            await driver.exitCode.timeout(const Duration(seconds: 25)),
            0,
            reason: await errors,
          );
          await output;
          if (limit) {
            await expectLater(
              pending!,
              throwsA(
                isA<SkillSourceException>().having(
                  (e) => e.reason,
                  'reason',
                  'limit',
                ),
              ),
            );
          } else {
            final bytes = await pending!.timeout(const Duration(seconds: 45));
            expect(bytes?.length, size);
            if (size != null && size > 0) expect(bytes!.last, 42);
          }
          expect(await driver.exitCode, 0, reason: await errors);
          await output;
          await capture.quiescent;
          expect(capture.busy, false);
        });
        cases.add(name);
      }

      await run('regular', 7);
      await run('regular', 7);
      await run('cancel', null);
      await run('cap', 4194304);
      await run('over-cap', 4194305, limit: true);
      capture.dispose();
      File(Platform.environment['STUDIO_SOURCE_LINUX_RESULT']!)
          .writeAsStringSync(
            jsonEncode({
              'passed': true,
              'cases': cases,
              'profile': 'actual GTK 3 FileChooserNative on isolated Xvfb; GTK_USE_PORTAL=0; not portal/device acceptance',
            }),
          );
    },
  );
}
