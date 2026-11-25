import 'dart:io';

import 'package:studio_store/studio_store.dart';
import 'package:studio_document/studio_document.dart';
import 'package:test/test.dart';

void main() {
  test('actual SQLite caption command CAS/version/undo/reopen and automatic manual lock rollback', () {
    final dir = Directory.systemTemp.createTempSync('caption-sql-'),
        ns = Namespace('test', 'local', 'caption');
    var repo = DocumentRepository.open('${dir.path}/db', ns);
    try {
      repo.create(
        ProjectDocument.empty(namespace: ns, projectId: 'p', title: 'p'),
      );
      var writer = repo.acquireWriter('p', 'first', expectedEpoch: 0);
      var id = 0;
      void apply(CaptionStore value, {bool automatic = false}) {
        repo.edit(
          writer: writer,
          commandId: 'cmd-${++id}',
          receiptKey: 'receipt-$id',
          expectedRevision: repo.read('p')!.revision,
          operation: SetCaptions(value, automatic: automatic),
        );
      }

      final cue = CaptionCue(
        'cue',
        TimeRange(Q.of(123, 1000), Q.of(1)),
        'hello🙂',
      ).editText('manual שלום');
      apply(CaptionStore([cue]));
      expect(repo.read('p')!.revision, BigInt.one);
      apply(CaptionStore([cue]));
      expect(repo.read('p')!.revision, BigInt.one);
      expect(
        () => apply(
          CaptionStore([CaptionCue('cue', cue.range, 'ASR')]),
          automatic: true,
        ),
        throwsA(
          isA<StudioException>().having(
            (e) => e.code,
            'code',
            'MANUAL_FIELD_LOCKED',
          ),
        ),
      );
      expect(repo.read('p')!.revision, BigInt.one);
      apply(CaptionStore(cue.split(Q.of(1, 2), 'right')));
      expect(repo.read('p')!.toJson()['captions'], hasLength(2));
      final target = repo.latestCommandId('p')!;
      repo.undoLatest(
        writer: writer,
        commandId: 'undo',
        receiptKey: 'undo',
        expectedRevision: BigInt.two,
        targetCommandId: target,
      );
      expect(repo.read('p')!.toJson()['captions'], hasLength(1));
      repo.close();
      repo = DocumentRepository.open('${dir.path}/db', ns);
      writer = repo.acquireWriter('p', 'second', expectedEpoch: 1);
      expect(repo.read('p')!.revision, BigInt.from(3));
      apply(CaptionStore([cue.editText('after reopen')]));
      expect(repo.read('p')!.toJson()['captions'][0]['version'], '3');
    } finally {
      repo.close();
      dir.deleteSync(recursive: true);
    }
  });
}
