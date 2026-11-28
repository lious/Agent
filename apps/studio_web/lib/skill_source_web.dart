/// App-owned File/Blob source only. No URL fetch, source persistence or verifier.
library;

import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:studio_assets/craft/signed_import/source_capture.dart';
import 'package:web/web.dart' as web;

Future<Uint8List?> chooseWebSkillSource(
  SkillSourceCapture capture, {
  bool Function()? currentAppStillValid,
}) => capture.choose(_pick, currentAppStillValid: currentAppStillValid);

SkillSourceSelection _pick() {
  final input = web.HTMLInputElement()
    ..type = 'file'
    ..multiple = false
    ..hidden = true.toJS;
  final result = Completer<SkillSourceReader?>();
  late JSFunction changed, cancelled;
  void cleanup() {
    input.removeEventListener('change', changed);
    input.removeEventListener('cancel', cancelled);
    input.value = '';
    input.remove();
  }

  changed = ((web.Event event) {
    if (!event.isTrusted || result.isCompleted) return;
    final files = input.files;
    final file = files != null && files.length == 1 ? files.item(0) : null;
    cleanup();
    result.complete(file == null ? null : _WebReader(file));
  }).toJS;
  cancelled = ((web.Event event) {
    if (!event.isTrusted || result.isCompleted) return;
    cleanup();
    result.complete(null);
  }).toJS;
  input.addEventListener('change', changed);
  input.addEventListener('cancel', cancelled);
  web.document.body!.append(input);
  try {
    input.click();
  } catch (_) {
    cleanup();
    rethrow;
  }
  // Terminal disposal removes observers but DOES NOT claim OS chooser settlement.
  return SkillSourceSelection(result.future, dispose: cleanup);
}

final class _WebReader implements SkillSourceReader {
  _WebReader(this._file);
  web.File? _file;
  int _position = 0;
  @override
  Future<int> length() async => _file!.size;
  @override
  Future<Uint8List> read(int start, int end) async {
    if (start != _position ||
        end <= start ||
        end - start > skillSourceChunkBytes) {
      throw const SkillSourceException('unreadable');
    }
    final buffer = await _file!.slice(start, end).arrayBuffer().toDart;
    final bytes = Uint8List.fromList(buffer.toDart.asUint8List());
    _position += bytes.length;
    return bytes;
  }

  @override
  Future<void> close() async {
    _file = null;
  }
}
