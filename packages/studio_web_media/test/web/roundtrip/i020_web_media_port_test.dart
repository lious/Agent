import 'package:studio_contracts/studio_contracts.dart';
import 'package:studio_web_media/studio_web_media.dart';
import 'package:test/test.dart';

/// Increment 2.37 official I-020 first DEV-PURE WebMediaPort slice.
/// Officializes leftover acceptance wording 「未支持codec不提交」 and
/// 「OPFS驱逐可恢复提示」 at the already-specified s6 / s5c bound.
/// This file does not claim a 60s browser roundtrip, V-007, native
/// golden command semantics, a real OPFS origin, ffmpeg.wasm, or a
/// native hardware AVFrame. apps/studio_web is not rewritten.
Matcher code(String c) =>
    throwsA(isA<StudioException>().having((e) => e.code, 'code', c));

WebCodecConfig config({String codec = 'avc1.42001e', bool wasm = false}) =>
    WebCodecConfig(
      codec: codec,
      container: 'mp4',
      width: 1920,
      height: 1080,
      useFfmpegWasm: wasm,
    );

WebMediaPort port({Set<String>? codecs, FakeOpfsStorage? storage}) =>
    WebMediaPort(
      codecHost: FakeWebCodecHost(
        supportedCodecs: codecs ?? {'avc1.42001e', 'mp4a.40.2'},
      ),
      storage:
          storage ?? FakeOpfsStorage(quotaBytes: 1024, persistentGranted: true),
    );

void main() {
  test('an unsupported codec is not committed; ffmpeg.wasm is not the default path', () {
    final media = port();
    final hevc = config(codec: 'hvc1.1.6.L93.B0');
    expect(media.isConfigSupported(hevc), isFalse);
    final buffer = media.adopt(WebMediaBuffer(id: 'frame-1', bytes: 16));
    expect(media.liveBuffers, 1);
    expect(() => media.commit(hevc, [buffer]), code(codecUnsupported));
    expect(media.commits, isEmpty);
    expect(buffer.closed, isTrue);
    expect(media.liveBuffers, 0);

    final wasm = config(wasm: true);
    expect(media.isConfigSupported(wasm), isFalse);
    final again = media.adopt(WebMediaBuffer(id: 'frame-2', bytes: 8));
    expect(() => media.commit(wasm, [again]), code(ffmpegWasmNotDefault));
    expect(media.commits, isEmpty);
    expect(again.closed, isTrue);
    expect(media.liveBuffers, 0);
  });

  test('a supported config can commit only after isConfigSupported, and input buffers are closed', () {
    final media = port();
    final ok = config();
    expect(media.isConfigSupported(ok), isTrue);
    final buffer = media.adopt(WebMediaBuffer(id: 'frame-ok', bytes: 32));
    final receipt = media.commit(ok, [buffer]);
    expect(receipt.codec, 'avc1.42001e');
    expect(media.commits, [receipt]);
    expect(buffer.closed, isTrue);
    expect(media.liveBuffers, 0);
  });

  test('OPFS eviction and a missing persist grant are recoverable prompts; a canceled picker is not a save', () {
    final evicted = FakeOpfsStorage(
      quotaBytes: 64,
      usedBytes: 8,
      persistentGranted: true,
      evicted: true,
    );
    final evictedProbe = evicted.probe();
    expect(evictedProbe.saved, isFalse);
    expect(evictedProbe.durable, isFalse);
    expect(evictedProbe.recoverable, isTrue);
    expect(evictedProbe.hint, webStorageEvictionHint);
    expect(() => evicted.saveProject(bytes: 8), code(webStorageNotDurable));
    expect(evicted.saves, 0);

    final ungranted = FakeOpfsStorage(quotaBytes: 64, persistentGranted: false);
    final hint = ungranted.probe();
    expect(hint.hint, webStorageEvictionHint);
    expect(hint.recoverable, isTrue);
    expect(hint.durable, isFalse);
    expect(() => ungranted.saveProject(bytes: 8), code(webStorageNotDurable));
    expect(ungranted.saves, 0);

    final durable = FakeOpfsStorage(quotaBytes: 64, persistentGranted: true);
    final canceled = durable.pickExport(userCanceled: true, bytes: 8);
    expect(canceled.saved, isFalse);
    expect(canceled.receiptId, isNull);
    expect(durable.saves, 0);
    expect(durable.usedBytes, 0);
    final written = durable.pickExport(userCanceled: false, bytes: 8);
    expect(written.saved, isTrue);
    expect(written.durable, isTrue);
    expect(written.receiptId, 'web-save-1');
    expect(durable.saves, 1);
  });
}
