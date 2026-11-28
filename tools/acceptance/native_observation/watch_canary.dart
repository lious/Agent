// TEST ONLY Directory.watch delivery canary, not App import or N01/N02 acceptance.
import 'dart:convert';
import 'dart:io';

String eventName(int type) {
  const names = {1: 'create', 2: 'modify', 4: 'delete', 8: 'move'};
  return names[type] ?? 'type:$type';
}

Future<void> main(List<String> args) async {
  if (args.length != 2) {
    stderr.writeln('usage: watch_canary.dart <tree> <result.json>');
    exit(2);
  }
  final tree = Directory(args[0])..createSync(recursive: true);
  final events = <Map<String, String>>[];
  String? error;
  final sub = tree
      .watch(recursive: true)
      .listen(
        (event) {
          events.add({'type': eventName(event.type), 'path': event.path});
        },
        onError: (Object e, StackTrace s) {
          error = '$e';
        },
      );
  await Future<void>.delayed(const Duration(milliseconds: 50));
  final created = File('${tree.path}/canary.txt');
  created.writeAsStringSync('one');
  await Future<void>.delayed(const Duration(milliseconds: 80));
  created.writeAsStringSync('two');
  await Future<void>.delayed(const Duration(milliseconds: 80));
  created.writeAsStringSync('one'); // restore
  await Future<void>.delayed(const Duration(milliseconds: 80));
  final renamed = File('${tree.path}/canary-renamed.txt');
  created.renameSync(renamed.path);
  await Future<void>.delayed(const Duration(milliseconds: 80));
  renamed.deleteSync();
  await Future<void>.delayed(const Duration(milliseconds: 200));
  await sub.cancel();
  final types = events.map((e) => e['type']!).toSet();
  final passed =
      error == null &&
      types.contains('create') &&
      types.contains('modify') &&
      types.contains('move') &&
      types.contains('delete');
  File(args[1]).writeAsStringSync(
    jsonEncode({
      'passed': passed,
      'error': error,
      'events': events,
      'observedTypes': types.toList()..sort(),
      'api': 'dart:io Directory.watch',
    }),
  );
  if (!passed) exit(1);
}
