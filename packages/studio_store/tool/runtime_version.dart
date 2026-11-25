import 'dart:convert';

import 'package:sqlite3/sqlite3.dart';

void main() {
  final db = sqlite3.openInMemory();
  try {
    print(
      jsonEncode({
        'sqliteVersion': db
            .select('SELECT sqlite_version() AS version')
            .single['version'],
      }),
    );
  } finally {
    db.dispose();
  }
}
