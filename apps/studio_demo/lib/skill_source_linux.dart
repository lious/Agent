/// App-owned Linux selection adapter only. Not a model-path or verifier API.
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:file_selector_linux/file_selector_linux.dart';
import 'package:studio_assets/craft/signed_import/source_capture.dart';

Future<Uint8List?> chooseLinuxSkillSource(SkillSourceCapture capture) =>
    capture.choose(() => SkillSourceSelection(_pick()));

Future<SkillSourceReader?> _pick() async {
  final selected = await FileSelectorLinux().openFile(
    acceptedTypeGroups: const [],
  );
  return selected == null ? null : _LinuxReader(selected.path);
}

final class _LinuxReader implements SkillSourceReader {
  _LinuxReader(this._path);
  final String _path;
  Future<RandomAccessFile>? _opening;
  int _position = 0;
  Future<RandomAccessFile> _open() => _opening ??= () async {
    if (_path.isEmpty ||
        _path.contains('\u0000') ||
        await FileSystemEntity.type(_path, followLinks: false) !=
            FileSystemEntityType.file) {
      throw const SkillSourceException('unreadable');
    }
    final file = File(_path), stat = await File(_path).stat();
    if ((stat.mode & 0xf000) != 0x8000) {
      throw const SkillSourceException('unreadable');
    }
    // Path selection is not atomic inode attestation; never reopen after this.
    return file.open(mode: FileMode.read);
  }();
  @override
  Future<int> length() async => (await _open()).length();
  @override
  Future<Uint8List> read(int start, int end) async {
    if (start != _position ||
        end <= start ||
        end - start > skillSourceChunkBytes) {
      throw const SkillSourceException('unreadable');
    }
    final bytes = await (await _open()).read(end - start);
    _position += bytes.length;
    return bytes;
  }

  @override
  Future<void> close() async {
    final opening = _opening;
    if (opening == null) return;
    RandomAccessFile handle;
    try {
      handle = await opening;
    } catch (_) {
      return;
    }
    await handle.close();
  }
}
