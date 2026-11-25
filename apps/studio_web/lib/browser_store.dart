import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

import 'package:web/web.dart' as web;
import 'package:studio_document/studio_document.dart';
import 'package:studio_contracts/studio_contracts.dart';

/// Browser-specific metadata/caption adapter. IndexedDB transaction completion is
/// the ACK, not a per-request success. This is NOT SQLite/OPFS qualification and
/// not a guarantee against browser eviction, private-mode loss or power failure.
final class BrowserProjectStore {
  BrowserProjectStore._(this._db, this.namespace);
  final web.IDBDatabase _db;
  final Namespace namespace;
  static Future<BrowserProjectStore> open(String name, Namespace namespace) {
    final c = Completer<BrowserProjectStore>(),
        request = web.window.indexedDB.open(name, 2);
    request.onupgradeneeded = ((web.Event e) {
      final db = request.result as web.IDBDatabase;
      if (!db.objectStoreNames.contains('projects')) {
        db.createObjectStore('projects');
      }
      if (!db.objectStoreNames.contains('peer_runtime')) {
        db.createObjectStore('peer_runtime');
      }
    }).toJS;
    request.onsuccess = ((web.Event e) {
      final database = request.result as web.IDBDatabase;
      if (c.isCompleted) {
        database.close();
        return;
      }
      c.complete(BrowserProjectStore._(database, namespace));
    }).toJS;
    request.onerror = ((web.Event e) {
      if (!c.isCompleted) {
        c.completeError(const StudioException('WEB_STORAGE_OPEN_FAILED'));
      }
    }).toJS;
    request.onblocked = ((web.Event e) {
      if (!c.isCompleted) {
        c.completeError(const StudioException('WEB_STORAGE_BLOCKED'));
      }
    }).toJS;
    return c.future;
  }

  String _key(String projectId) => jsonEncode([namespace.toJson(), projectId]);
  ProjectDocument _verified(Map<String, dynamic> record, String id) {
    final p = ProjectDocument.fromJson(record['head'] as Map<String, dynamic>);
    if (p.namespace != namespace ||
        p.projectId != id ||
        record['format'] != 'browser-project-1' ||
        record['headHash'] != p.hash) {
      throw const StudioException('WEB_STORAGE_INTEGRITY');
    }
    return p;
  }

  Future<ProjectDocument> _write(
    String projectId,
    Map<String, dynamic> Function(Map<String, dynamic>?) change,
  ) {
    final result = Completer<ProjectDocument>(),
        tx = _db.transaction(
          'projects'.toJS,
          'readwrite',
          web.IDBTransactionOptions(durability: 'strict'),
        ),
        store = tx.objectStore('projects');
    ProjectDocument? published;
    Object? failure;
    final request = store.get(_key(projectId).toJS);
    request.onsuccess = ((web.Event event) {
      try {
        final raw = request.result;
        final previous = raw == null
            ? null
            : jsonDecode((raw as JSString).toDart) as Map<String, dynamic>;
        if (previous != null) _verified(previous, projectId);
        final next = change(previous);
        final document = ProjectDocument.fromJson(
          next['head'] as Map<String, dynamic>,
        );
        if (document.namespace != namespace ||
            document.projectId != projectId) {
          throw const StudioException('NAMESPACE_MISMATCH');
        }
        next['format'] = 'browser-project-1';
        next['headHash'] = document.hash;
        final encoded = jsonEncode(next);
        if (encoded.length > 4 * 1024 * 1024) {
          throw const StudioException('WEB_PROJECT_RESOURCE_LIMIT');
        }
        published = ProjectDocument.fromJson(
          next['head'] as Map<String, dynamic>,
        );
        store.put(encoded.toJS, _key(projectId).toJS);
      } catch (e) {
        failure = e;
        tx.abort();
      }
    }).toJS;
    tx.oncomplete = ((web.Event e) {
      result.complete(published!);
    }).toJS;
    void abort(web.Event e) {
      if (!result.isCompleted) {
        result.completeError(
          failure ?? const StudioException('WEB_STORAGE_TRANSACTION_FAILED'),
        );
      }
    }

    tx.onabort = abort.toJS;
    tx.onerror = abort.toJS;
    return result.future;
  }

  Future<ProjectDocument> openProject(ProjectDocument seed) {
    if (seed.namespace != namespace) {
      throw const StudioException('NAMESPACE_MISMATCH');
    }
    return _write(
      seed.projectId,
      (old) =>
          old ??
          {
            'head': seed.toJson(),
            'versions': <String, dynamic>{},
            'receipts': <String, dynamic>{},
            'idCounter': '0',
          },
    );
  }

  Future<ProjectDocument> read(String id) async {
    final tx = _db.transaction('projects'.toJS),
        r = tx.objectStore('projects').get(_key(id).toJS),
        c = Completer<ProjectDocument>();
    r.onsuccess = ((web.Event e) {
      try {
        if (r.result == null) throw const StudioException('PROJECT_NOT_FOUND');
        final data =
            jsonDecode((r.result as JSString).toDart) as Map<String, dynamic>;
        c.complete(_verified(data, id));
      } catch (e) {
        c.completeError(e);
      }
    }).toJS;
    r.onerror = ((web.Event e) {
      c.completeError(const StudioException('WEB_STORAGE_READ_FAILED'));
    }).toJS;
    return c.future;
  }

  Future<ProjectDocument> edit(
    String id,
    EditOperation operation, {
    required String commandId,
    required BigInt expectedRevision,
  }) {
    requireId(commandId);
    final inputHash = contentHash({
      'operation': operation.toJson(),
      'expectedRevision': expectedRevision.toString(),
    });
    return _write(id, (record) {
      if (record == null) throw const StudioException('PROJECT_NOT_FOUND');
      if (operation is AppendVideoAsset) {
        throw const StudioException('WEB_MEDIA_ADAPTER_UNAVAILABLE');
      }
      final receipts = Map<String, dynamic>.from(record['receipts'] as Map),
          old = receipts[commandId];
      if (old != null) {
        if (old['inputHash'] != inputHash) {
          throw const StudioException('IDEMPOTENCY_CONFLICT');
        }
        return record;
      }
      if (receipts.length >= 1024) {
        throw const StudioException('WEB_RECEIPT_RETENTION_LIMIT');
      }
      final before = ProjectDocument.fromJson(
        record['head'] as Map<String, dynamic>,
      );
      if (before.revision != expectedRevision) {
        throw const StudioException('REVISION_CONFLICT');
      }
      if ((before.toJson()['assets'] as List).isNotEmpty) {
        throw const StudioException('WEB_MEDIA_ADAPTER_UNAVAILABLE');
      }
      final versions = Map<String, dynamic>.from(record['versions'] as Map);
      var counter = BigInt.parse(record['idCounter'] as String);
      // Inventory existing immutable definitions before allocating, including an
      // imported seed whose version high-water marks are not in browser history.
      for (final entity in [
        ...before.toJson()['sequences'] as List,
        ...before.toJson()['captions'] as List,
      ]) {
        final v = BigInt.parse(entity['version'] as String),
            known = BigInt.parse(versions[entity['id']] as String? ?? '0');
        if (v > known) versions[entity['id'] as String] = v.toString();
      }
      final after = applyEdit(
        before,
        operation,
        nextVersion: (key) {
          final value =
              BigInt.parse(versions[key] as String? ?? '0') + BigInt.one;
          if (value > maxI64) throw const StudioException('VERSION_OVERFLOW');
          versions[key] = value.toString();
          return value.toString();
        },
        newId: () {
          counter += BigInt.one;
          return 'web-$counter';
        },
      );
      final next = after.hash == before.hash
          ? before
          : after.withTitle(after.title, before.revision + BigInt.one);
      receipts[commandId] = {
        'inputHash': inputHash,
        'revision': next.revision.toString(),
        'snapshotHash': next.hash,
      };
      return {
        ...record,
        'head': next.toJson(),
        'versions': versions,
        'receipts': receipts,
        'idCounter': counter.toString(),
      };
    });
  }

  /// Browser persistence adapter for original Harness state. Project revision and
  /// peer record changes share one IDB transaction; only transaction.complete ACKs.
  Future<Map<String, dynamic>> peerTransaction(
    String projectId,
    Map<String, dynamic> Function(ProjectDocument, Map<String, dynamic>) change,
  ) {
    final c = Completer<Map<String, dynamic>>();
    final tx = _db.transaction(
      ['projects'.toJS, 'peer_runtime'.toJS].toJS,
      'readwrite',
      web.IDBTransactionOptions(durability: 'strict'),
    );
    final project = tx.objectStore('projects').get(_key(projectId).toJS);
    final store = tx.objectStore('peer_runtime');
    final key = jsonEncode(namespace.toJson()).toJS;
    final runtime = store.get(key);
    Object? failure;
    Map<String, dynamic>? result;
    var loaded = 0;
    void apply(web.Event _) {
      if (++loaded != 2) return;
      try {
        if (project.result == null) {
          throw const StudioException('PROJECT_NOT_FOUND');
        }
        final doc = _verified(
          jsonDecode((project.result as JSString).toDart)
              as Map<String, dynamic>,
          projectId,
        );
        final raw = runtime.result;
        final value = raw == null
            ? <String, dynamic>{'sessions': <String, dynamic>{}}
            : jsonDecode((raw as JSString).toDart) as Map<String, dynamic>;
        result = change(doc, value);
        final encoded = jsonEncode(value);
        if (encoded.length > 512 * 1024) {
          throw const StudioException('WEB_PEER_STORAGE_LIMIT');
        }
        store.put(encoded.toJS, key);
      } catch (e) {
        failure = e;
        tx.abort();
      }
    }

    project.onsuccess = apply.toJS;
    runtime.onsuccess = apply.toJS;
    tx.oncomplete = ((web.Event _) {
      c.complete(result!);
    }).toJS;
    void abort(web.Event _) {
      if (!c.isCompleted) {
        c.completeError(
          failure ?? const StudioException('WEB_STORAGE_TRANSACTION_FAILED'),
        );
      }
    }

    tx.onabort = abort.toJS;
    tx.onerror = abort.toJS;
    return c.future;
  }

  void close() => _db.close();
}
