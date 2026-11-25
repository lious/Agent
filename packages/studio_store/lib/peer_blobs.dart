part of 'studio_store.dart';

/// Bounded peer inbox, NOT the project's production media CAS or fixture table.
/// No peer path, automatic project attachment, decode, cloud upload or model use.
extension PeerBlobInbox on DocumentRepository {
  Uint8List? receivedPeerBlob(String rawHash) {
    _peerHash(rawHash);
    final rows = _db.select(
      'SELECT bytes FROM peer_blob_objects WHERE ns=? AND hash=?',
      [_ns, rawHash],
    );
    if (rows.isEmpty) return null;
    final bytes = Uint8List.fromList(rows.single['bytes'] as Uint8List);
    if (rawBytesHash(bytes) != 'sha256:$rawHash') {
      throw const StudioException('STORE_INTEGRITY');
    }
    return bytes;
  }

  Map<String, dynamic> _peerBlobOperation(
    String fingerprint,
    SessionRef session,
    String planHash,
    String node,
    int epoch,
    Map<String, dynamic> grant,
    String operation,
    Map<String, dynamic> payload,
  ) {
    final hash = payload['blobHash'];
    if (hash is! String) throw const StudioException('PEER_BLOB_SCHEMA');
    _peerHash(hash);
    final allowed = grant['allowedBlobs'] as Map? ?? const {};
    if (!allowed.containsKey(hash)) {
      throw const StudioException('PEER_BLOB_NOT_GRANTED');
    }
    final size = allowed[hash] as int;
    if (size < 0 || size > 16 * 1024 * 1024) {
      throw const StudioException('PEER_BLOB_QUOTA');
    }
    final key = <Object?>[_ns, fingerprint, session.id, planHash, epoch, hash];
    var rows = _db.select(
      'SELECT state,size FROM peer_blob_stages WHERE ns=? AND fingerprint=? AND session_id=? AND plan_hash=? AND epoch=? AND hash=?',
      key,
    );
    if (operation == 'blob.begin') {
      if (payload.length != 1) throw const StudioException('PEER_BLOB_SCHEMA');
      if (rows.isEmpty) {
        final reserved =
            (_db.select(
                  'SELECT coalesce(sum(size),0) AS n FROM peer_blob_stages WHERE ns=?',
                  [_ns],
                ).single['n']
                as int);
        if (reserved + size > 64 * 1024 * 1024) {
          throw const StudioException('PEER_BLOB_QUOTA');
        }
        _db.execute(
          "INSERT INTO peer_blob_stages VALUES(?,?,?,?,?,?,?,'receiving')",
          [...key, size],
        );
        rows = _db.select(
          'SELECT state,size FROM peer_blob_stages WHERE ns=? AND fingerprint=? AND session_id=? AND plan_hash=? AND epoch=? AND hash=?',
          key,
        );
      }
    }
    if (rows.length != 1) throw const StudioException('PEER_BLOB_NOT_STARTED');
    if (rows.single['size'] != size) {
      throw const StudioException('PEER_BLOB_SIZE');
    }
    const chunkSize = 65536;
    final chunks = (size + chunkSize - 1) ~/ chunkSize;
    if (operation == 'blob.chunk') {
      if (payload.length != 4 ||
          payload['index'] is! int ||
          payload['base64'] is! String ||
          payload['chunkHash'] is! String) {
        throw const StudioException('PEER_BLOB_SCHEMA');
      }
      final index = payload['index'] as int,
          encoded = payload['base64'] as String;
      if (index < 0 || index >= chunks || encoded.length > 87384) {
        throw const StudioException('PEER_BLOB_SIZE');
      }
      Uint8List bytes;
      try {
        bytes = base64.decode(encoded);
      } catch (_) {
        throw const StudioException('PEER_BLOB_SCHEMA');
      }
      final expected = index == chunks - 1
          ? size - index * chunkSize
          : chunkSize;
      if (bytes.length != expected ||
          rawBytesHash(bytes) != 'sha256:${payload['chunkHash']}') {
        throw const StudioException('PEER_BLOB_CHUNK_HASH');
      }
      final previous = _db.select(
        'SELECT bytes FROM peer_blob_chunks WHERE ns=? AND fingerprint=? AND session_id=? AND plan_hash=? AND epoch=? AND hash=? AND chunk_index=?',
        [...key, index],
      );
      if (previous.isNotEmpty) {
        if (base64.encode(previous.single['bytes'] as Uint8List) !=
            base64.encode(bytes)) {
          throw const StudioException('PEER_BLOB_CHUNK_CONFLICT');
        }
      } else {
        if (rows.single['state'] == 'committed') {
          throw const StudioException('PEER_BLOB_ALREADY_COMMITTED');
        }
        _db.execute('INSERT INTO peer_blob_chunks VALUES(?,?,?,?,?,?,?,?)', [
          ...key,
          index,
          bytes,
        ]);
      }
    } else if (![
          'blob.begin',
          'blob.status',
          'blob.finish',
        ].contains(operation) ||
        payload.length != 1) {
      throw const StudioException('PEER_BLOB_SCHEMA');
    }
    final present = _db.select(
      'SELECT chunk_index FROM peer_blob_chunks WHERE ns=? AND fingerprint=? AND session_id=? AND plan_hash=? AND epoch=? AND hash=? ORDER BY chunk_index',
      key,
    );
    if (operation == 'blob.finish' && rows.single['state'] != 'committed') {
      if (present.length != chunks) {
        throw const StudioException('PEER_BLOB_INCOMPLETE');
      }
      final complete = _db.select(
        'SELECT bytes FROM peer_blob_chunks WHERE ns=? AND fingerprint=? AND session_id=? AND plan_hash=? AND epoch=? AND hash=? ORDER BY chunk_index',
        key,
      );
      final bytes = BytesBuilder(copy: false);
      for (final row in complete) {
        bytes.add(row['bytes'] as Uint8List);
      }
      final all = bytes.takeBytes();
      if (all.length != size || rawBytesHash(all) != 'sha256:$hash') {
        throw const StudioException('PEER_BLOB_FINAL_HASH');
      }
      final existing = receivedPeerBlob(hash);
      if (existing == null) {
        _db.execute('INSERT INTO peer_blob_objects VALUES(?,?,?)', [
          _ns,
          hash,
          all,
        ]);
      }
      _db.execute(
        "UPDATE peer_blob_stages SET state='committed' WHERE ns=? AND fingerprint=? AND session_id=? AND plan_hash=? AND epoch=? AND hash=?",
        key,
      );
      final event = harnessHash({
        'session': session.id,
        'plan': planHash,
        'fingerprint': fingerprint,
        'epoch': '$epoch',
        'hash': hash,
        'kind': 'peer.blob.ready',
      });
      _db.execute(
        'INSERT OR IGNORE INTO harness_outbox VALUES(?,?,?,?,?,?,?)',
        [
          _ns,
          event,
          session.id,
          planHash,
          node,
          'peer.blob.ready',
          jsonEncode({
            'blobRef': 'sha256:$hash',
            'size': size,
            'certificateFingerprint': fingerprint,
          }),
        ],
      );
    }
    return {
      'blobHash': hash,
      'size': size,
      'chunkSize': chunkSize,
      'received': [for (final row in present) row['chunk_index']],
      'committed':
          operation == 'blob.finish' || rows.single['state'] == 'committed',
    };
  }
}
