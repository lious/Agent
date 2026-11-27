import 'package:studio_contracts/studio_contracts.dart';

const codecUnsupported = 'CODEC_UNSUPPORTED';
const ffmpegWasmNotDefault = 'FFMPEG_WASM_NOT_DEFAULT';
const webStorageNotDurable = 'WEB_STORAGE_NOT_DURABLE';

/// s5c wording when persistent storage is not granted or OPFS is evicted.
const webStorageEvictionHint = '浏览器可能回收本机数据，请导出工程包';

/// A WebCodecs encoder/decoder config. This is not a native AVFrame and
/// not an ffmpeg.wasm handle.
final class WebCodecConfig {
  WebCodecConfig({
    required this.codec,
    required this.container,
    this.width = 0,
    this.height = 0,
    this.useFfmpegWasm = false,
  }) {
    requireId(codec);
    requireId(container);
    if (width < 0 || height < 0) {
      throw const StudioException('INVALID_ID', 'size');
    }
  }

  final String codec, container;
  final int width, height;
  final bool useFfmpegWasm;
}

/// Owned WebCodecs-style buffer. Callers and [WebMediaPort.commit] must
/// close it; this port never holds a native hardware AVFrame.
final class WebMediaBuffer {
  WebMediaBuffer({required this.id, required this.bytes});

  final String id;
  final int bytes;
  bool closed = false;

  void close() => closed = true;
}

final class WebMediaCommit {
  WebMediaCommit({required this.id, required this.codec, required this.bytes});

  final String id, codec;
  final int bytes;
}

/// Probe / save outcome for the OPFS-style quota host. A canceled file
/// picker is not a save. Eviction is recoverable and is not silent.
final class WebStorageDecision {
  const WebStorageDecision({
    required this.saved,
    required this.durable,
    required this.recoverable,
    this.hint,
    this.receiptId,
  });

  final bool saved, durable, recoverable;
  final String? hint, receiptId;
}

/// Capability host. VM tests use [FakeWebCodecHost]; a real browser
/// VideoEncoder.isConfigSupported is a V-007 concern and is not claimed.
abstract interface class WebCodecHost {
  bool isConfigSupported(WebCodecConfig config);
}

final class FakeWebCodecHost implements WebCodecHost {
  FakeWebCodecHost({required this.supportedCodecs});

  final Set<String> supportedCodecs;

  @override
  bool isConfigSupported(WebCodecConfig config) =>
      !config.useFfmpegWasm && supportedCodecs.contains(config.codec);
}

/// In-memory OPFS/IndexedDB quota stand-in. This is not a real browser
/// origin, not workspace SQLite w5, and not project user_version 10.
final class FakeOpfsStorage {
  FakeOpfsStorage({
    required this.quotaBytes,
    this.usedBytes = 0,
    this.persistentGranted = false,
    this.evicted = false,
  });

  final int quotaBytes;
  int usedBytes;
  bool persistentGranted;
  bool evicted;
  int saves = 0;
  int _n = 0;

  WebStorageDecision probe() {
    if (!persistentGranted || evicted || usedBytes > quotaBytes) {
      return WebStorageDecision(
        saved: false,
        durable: false,
        recoverable: true,
        hint: webStorageEvictionHint,
      );
    }
    return const WebStorageDecision(
      saved: false,
      durable: true,
      recoverable: true,
    );
  }

  /// A durable in-origin write is refused when the probe is not durable.
  WebStorageDecision saveProject({required int bytes}) {
    final status = probe();
    if (!status.durable) {
      throw StudioException(webStorageNotDurable, status.hint ?? '');
    }
    if (bytes <= 0) throw const StudioException('INVALID_ID', 'bytes');
    if (usedBytes + bytes > quotaBytes) {
      evicted = true;
      throw StudioException(webStorageNotDurable, webStorageEvictionHint);
    }
    usedBytes += bytes;
    saves += 1;
    _n += 1;
    return WebStorageDecision(
      saved: true,
      durable: true,
      recoverable: true,
      receiptId: 'web-save-$_n',
    );
  }

  /// s5c: canceling the file picker is not a save.
  WebStorageDecision pickExport({required bool userCanceled, int bytes = 0}) {
    if (userCanceled) {
      return const WebStorageDecision(
        saved: false,
        durable: false,
        recoverable: true,
      );
    }
    return saveProject(bytes: bytes);
  }
}

/// s6 WebMediaPort protocol slice. JS demux/mux libraries, real WebCodecs,
/// and a 60s browser roundtrip are not opened here.
final class WebMediaPort {
  WebMediaPort({required this.codecHost, required this.storage});

  final WebCodecHost codecHost;
  final FakeOpfsStorage storage;
  final List<WebMediaCommit> commits = [];
  int _n = 0;
  int get liveBuffers => _live.length;
  final _live = <WebMediaBuffer>{};

  bool isConfigSupported(WebCodecConfig config) =>
      codecHost.isConfigSupported(config);

  WebMediaBuffer adopt(WebMediaBuffer buffer) {
    if (buffer.closed) throw const StudioException('INVALID_ID', 'buffer');
    _live.add(buffer);
    return buffer;
  }

  WebMediaCommit commit(WebCodecConfig config, List<WebMediaBuffer> inputs) {
    if (config.useFfmpegWasm) {
      _closeAll(inputs);
      throw const StudioException(ffmpegWasmNotDefault);
    }
    if (!isConfigSupported(config)) {
      _closeAll(inputs);
      throw StudioException(codecUnsupported, config.codec);
    }
    var bytes = 0;
    for (final buffer in inputs) {
      if (buffer.closed) {
        throw const StudioException('INVALID_ID', 'buffer');
      }
      bytes += buffer.bytes;
    }
    _closeAll(inputs);
    _n += 1;
    final row = WebMediaCommit(
      id: 'web-commit-$_n',
      codec: config.codec,
      bytes: bytes,
    );
    commits.add(row);
    return row;
  }

  void _closeAll(List<WebMediaBuffer> inputs) {
    for (final buffer in inputs) {
      buffer.close();
      _live.remove(buffer);
    }
  }
}
