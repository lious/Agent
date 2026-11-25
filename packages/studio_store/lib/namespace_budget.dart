part of 'blob_store.dart';

final _casLeaseZoneKey = Object(), _diskReservationZoneKey = Object();

extension NamespaceDiskBudget on BlobStore {
  File get _policyFile =>
      File(p.join(directory.path, '.storage-policy-v1.json'));
  File get _reservationFile =>
      File(p.join(directory.path, '.storage-reservation-v1.json'));
  String get _leaseKey => p.join(
    directory.parent.resolveSymbolicLinksSync(),
    '.cas-maintenance.lock',
  );
  Map<String, dynamic> namespaceStoragePolicy() {
    _checkDirectory();
    final type = FileSystemEntity.typeSync(
      _policyFile.path,
      followLinks: false,
    );
    if (type == FileSystemEntityType.notFound) {
      return {
        'version': 1,
        'casFileByteLimit': null,
        'retention': 'preserveAll',
      };
    }
    if (type != FileSystemEntityType.file || _policyFile.lengthSync() > 4096) {
      throw const StudioException('STORAGE_POLICY_UNSAFE');
    }
    final value = readStrictJson(_policyFile.readAsBytesSync(), maxBytes: 4096);
    if (value is! Map<String, dynamic> ||
        value.length != 3 ||
        value['version'] != 1 ||
        value['retention'] != 'preserveAll' ||
        !value.containsKey('casFileByteLimit')) {
      throw const StudioException('STORAGE_POLICY_INVALID');
    }
    _limit(value['casFileByteLimit']);
    return value;
  }

  BigInt? _limit(dynamic value) {
    if (value == null) return null;
    if (value is! String || !RegExp(r'^[1-9][0-9]{0,18}$').hasMatch(value)) {
      throw const StudioException('STORAGE_POLICY_INVALID');
    }
    final n = BigInt.parse(value);
    if (n > maxI64) throw const StudioException('STORAGE_POLICY_INVALID');
    return n;
  }

  /// Logical regular-file sizes, NOT allocation blocks/free volume bytes.
  /// Includes originals, derived, stages, unknown files, owner/proof/audit metadata.
  Map<String, dynamic> namespaceInventory() {
    _checkDirectory();
    var bytes = BigInt.zero, files = 0;
    final unsafe = <String>[];
    for (final entry in directory.listSync(followLinks: false)) {
      if (++files > 100000) {
        throw const StudioException('STORAGE_INVENTORY_LIMIT');
      }
      if (FileSystemEntity.typeSync(entry.path, followLinks: false) !=
          FileSystemEntityType.file) {
        if (unsafe.length < 16) unsafe.add(p.basename(entry.path));
      } else {
        bytes += BigInt.from(File(entry.path).lengthSync());
      }
    }
    return {
      'fileBytes': bytes.toString(),
      'entries': files,
      'unsafeEntries': unsafe,
      'policy': namespaceStoragePolicy(),
      'scope': 'namespace regular-file bytes only; excludes DB, external archives/exports and filesystem allocation overhead',
    };
  }

  Future<Map<String, dynamic>> configureNamespaceBudget(
    String? limit, {
    required String databasePath,
    required bool confirmed,
  }) async {
    if (!confirmed) {
      throw const StudioException('STORAGE_POLICY_CONFIRMATION_REQUIRED');
    }
    final cap = _limit(limit);
    return withMaintenanceLease(() async {
      requireExclusiveRepairDatabase(databasePath);
      final inventory = namespaceInventory();
      if ((inventory['unsafeEntries'] as List).isNotEmpty) {
        throw const StudioException('STORAGE_INVENTORY_UNSAFE');
      }
      if (cap != null &&
          BigInt.parse(inventory['fileBytes']) + BigInt.from(8192) > cap) {
        throw const StudioException('NAMESPACE_DISK_BUDGET_EXCEEDED');
      }
      final policy = {
        'version': 1,
        'casFileByteLimit': limit,
        'retention': 'preserveAll',
      };
      AtomicFilePublisher().write(_policyFile, utf8.encode(jsonEncode(policy)));
      return namespaceInventory();
    });
  }

  void requireNativeDiskReservation() {
    if (namespaceStoragePolicy()['casFileByteLimit'] != null &&
        (Zone.current[_diskReservationZoneKey] as Map?)?['namespace'] !=
            _leaseKey) {
      throw const StudioException('NAMESPACE_DISK_RESERVATION_REQUIRED');
    }
  }

  Future<T> withNamespaceDiskReservation<T>(
    int peakAdditionalBytes,
    Future<T> Function() action,
  ) async {
    if (peakAdditionalBytes < 0) {
      throw const StudioException('INVALID_DISK_RESERVATION');
    }
    if (Zone.current[_casLeaseZoneKey] != _leaseKey) {
      return withMaintenanceLease(
        () => withNamespaceDiskReservation(peakAdditionalBytes, action),
      );
    }
    final cap = _limit(namespaceStoragePolicy()['casFileByteLimit']);
    if (cap == null) return action();
    final active = Zone.current[_diskReservationZoneKey] as Map?;
    if (active?['namespace'] == _leaseKey) {
      if (peakAdditionalBytes > active!['bytes']) {
        throw const StudioException('NAMESPACE_DISK_RESERVATION_EXCEEDED');
      }
      return action();
    }
    final inventory = namespaceInventory();
    if ((inventory['unsafeEntries'] as List).isNotEmpty) {
      throw const StudioException('STORAGE_INVENTORY_UNSAFE');
    }
    if (BigInt.parse(inventory['fileBytes']) +
            BigInt.from(peakAdditionalBytes) +
            BigInt.from(8192) >
        cap) {
      throw const StudioException('NAMESPACE_DISK_BUDGET_EXCEEDED');
    }
    // Acquiring the SAME stable OS lease proves a prior active holder is gone.
    // Reclaim accounting only; actual stage files remain counted, never deleted.
    var reclaimed = false;
    if (FileSystemEntity.typeSync(_reservationFile.path, followLinks: false) !=
        FileSystemEntityType.notFound) {
      if (FileSystemEntity.typeSync(
                _reservationFile.path,
                followLinks: false,
              ) !=
              FileSystemEntityType.file ||
          _reservationFile.lengthSync() > 4096) {
        throw const StudioException('DISK_RESERVATION_UNSAFE');
      }
      final old = readStrictJson(
        _reservationFile.readAsBytesSync(),
        maxBytes: 4096,
      );
      if (old is! Map ||
          old['version'] != 1 ||
          !{'active', 'released', 'failed'}.contains(old['state'])) {
        throw const StudioException('DISK_RESERVATION_INVALID');
      }
      reclaimed = old['state'] == 'active';
    }
    final record = <String, dynamic>{
      'version': 1,
      'id': const Uuid().v7(),
      'state': 'active',
      'bytes': peakAdditionalBytes.toString(),
      'reclaimedAbandonedAccounting': reclaimed,
      'retention': 'preserveAll',
    };
    void persist() => AtomicFilePublisher().write(
      _reservationFile,
      utf8.encode(jsonEncode(record)),
    );
    persist();
    try {
      final result = await runZoned(
        action,
        zoneValues: {
          _diskReservationZoneKey: {
            'namespace': _leaseKey,
            'bytes': peakAdditionalBytes,
          },
        },
      );
      record['state'] = 'released';
      persist();
      return result;
    } catch (_) {
      record['state'] = 'failed';
      persist();
      rethrow;
    }
  }
}
