import 'dart:convert';

import 'package:sqlite3/sqlite3.dart';

void main() {
  final db = sqlite3.openInMemory();
  try {
    print(
      jsonEncode({
        'sqliteSourceId': db
            .select('SELECT sqlite_source_id() AS source')
            .single['source'],
        'threadsafe': db
            .select(
              "SELECT sqlite_compileoption_used('THREADSAFE=1') AS enabled",
            )
            .single['enabled'],
        'sqliteVersion': db
            .select('SELECT sqlite_version() AS version')
            .single['version'],
      }),
    );
  } finally {
    db.dispose();
  }
}
