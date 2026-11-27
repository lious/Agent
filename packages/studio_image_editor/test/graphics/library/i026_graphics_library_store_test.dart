import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:studio_contracts/studio_contracts.dart';
import 'package:studio_image_editor/studio_image_editor.dart';
import 'package:test/test.dart';

Matcher code(String value) =>
    throwsA(isA<StudioException>().having((e) => e.code, 'code', value));

Namespace get appA => Namespace('studio.app.a', 'tenant', 'ws');
Namespace get appB => Namespace('studio.app.b', 'tenant', 'ws');

String blob(String seed) => sha256.convert(utf8.encode(seed)).toString();
GraphicAsset asset({
  required Namespace ns,
  required String id,
  required String name,
  required String rightsId,
  int version = 1,
  List<String> tags = const ['paper'],
}) {
  return GraphicAsset(
    id: id,
    version: version,
    namespace: ns,
    name: name,
    kind: 'illustration',
    sourceAssetRef: 'src-$id',
    sourceGeometryHash: blob('geom-$id'),
    previewBlobHash: blob('prev-$id'),
    thumbnailBlobHash: blob('thumb-$id'),
    width: 1024,
    height: 1024,
    colorPolicyRef: 'color-srgb',
    rightsId: rightsId,
    tags: tags,
  );
}

void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('i026-lib-'));
  tearDown(() {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  test('graphics-library/1 is a private library and does not write project user_version', () {
    final repo = GraphicRepository.open(p.join(dir.path, 'lib'), appA);
    expect(repo.store.userVersion, GraphicsLibraryStore.libraryDocumentVersion);
    expect(repo.store.userVersion, 1);
    expect(
      officialGraphicsLibraryDdl,
      contains("INSERT INTO workspace_features VALUES('graphics_library','1.0.0','graphics-library/1')"),
    );
    expect(officialGraphicsLibraryDdl, contains('CREATE TABLE graphic_versions'));
    expect(officialGraphicsLibraryDdl, contains('IMMUTABLE_GRAPHIC_VERSION'));
    expect(officialGraphicsLibraryDdl, contains('CREATE TABLE graphic_heads'));
    final sqlFile = File(
      p.join(
        Directory.current.path,
        'store/graphics_library.sql',
      ),
    );
    // Resolve from repo root when tests run via workspace.
    final fromPackage = File(
      p.join(
        Directory.current.path,
        'packages/studio_image_editor/store/graphics_library.sql',
      ),
    );
    final official = sqlFile.existsSync()
        ? sqlFile.readAsStringSync()
        : fromPackage.readAsStringSync();
    expect(officialGraphicsLibraryDdl, official);
    expect(File(p.join(dir.path, 'lib', 'project.sqlite')).existsSync(), isFalse);
    repo.close();
  });

  test('the same Graphic@1 stays pinned in P and Q after @2 is published; only Q upgrades', () {
    final repo = GraphicRepository.open(p.join(dir.path, 'lib'), appA);
    repo.registerRights(
      rightsId: 'rights-g',
      epoch: '0',
      allowedUses: ['use'],
      redistributable: false,
    );
    final pin1 = repo.publish(
      GraphicDraft(asset: asset(ns: appA, id: 'g1', name: 'Leaf', rightsId: 'rights-g')),
      null,
      '0',
    );
    expect(pin1.version, 1);
    repo.pinToProject(projectId: 'P', pin: pin1);
    repo.pinToProject(projectId: 'Q', pin: pin1);
    final pin2 = repo.publish(
      GraphicDraft(
        asset: asset(ns: appA, id: 'g1', name: 'Leaf v2', rightsId: 'rights-g', version: 2),
      ),
      '1',
      '0',
    );
    expect(pin2.version, 2);
    expect(repo.projectPin('P', 'g1')!.version, 1);
    expect(repo.projectPin('Q', 'g1')!.version, 1);
    expect(repo.load('g1', 1).name, 'Leaf');
    repo.upgradeProject(projectId: 'Q', newPin: pin2);
    expect(repo.projectPin('P', 'g1')!.version, 1);
    expect(repo.projectPin('Q', 'g1')!.version, 2);
    expect(repo.load('g1', 1).name, 'Leaf');
    expect(repo.load('g1', 2).name, 'Leaf v2');
    repo.close();
  });

  test('deleting a library head leaves pinned versions loadable; pinned versions are GRAPHIC_IN_USE', () {
    final repo = GraphicRepository.open(p.join(dir.path, 'lib'), appA);
    repo.registerRights(
      rightsId: 'rights-g',
      epoch: '0',
      allowedUses: ['use'],
      redistributable: false,
    );
    final pin1 = repo.publish(
      GraphicDraft(asset: asset(ns: appA, id: 'g1', name: 'Leaf', rightsId: 'rights-g')),
      null,
      '0',
    );
    repo.pinToProject(projectId: 'P', pin: pin1);
    repo.publish(
      GraphicDraft(
        asset: asset(ns: appA, id: 'g1', name: 'Leaf v2', rightsId: 'rights-g', version: 2),
      ),
      '1',
      '0',
    );
    final retention = GraphicRetention(repo);
    expect(
      () => retention.planDelete(id: 'g1', version: '1'),
      code(graphicInUse),
    );
    retention.deleteHead('graphic', 'g1');
    expect(repo.store.headVersion('graphic', 'g1'), isNull);
    expect(repo.load('g1', 1).name, 'Leaf');
    expect(repo.projectPin('P', 'g1')!.version, 1);
    repo.close();
  });

  test('unauthorized material cannot enter a shared template; selection does not grant redistribution', () {
    final repo = GraphicRepository.open(p.join(dir.path, 'lib'), appA);
    repo.registerRights(
      rightsId: 'rights-g',
      epoch: '0',
      allowedUses: ['use'],
      redistributable: false,
    );
    expect(
      () => repo.publish(
        GraphicDraft(
          asset: asset(ns: appA, id: 'g1', name: 'Leaf', rightsId: 'rights-g'),
          shared: true,
        ),
        null,
        '0',
      ),
      code(rightsRequired),
    );
    final pin = repo.publish(
      GraphicDraft(asset: asset(ns: appA, id: 'g1', name: 'Leaf', rightsId: 'rights-g')),
      null,
      '0',
    );
    repo.pinToProject(projectId: 'P', pin: pin);
    expect(repo.selectionGrantsRedistribution('rights-g'), isFalse);
    final editor = TemplateEditorSession(repository: repo, namespace: appA);
    expect(editor.usingGrantsRedistribution('rights-g'), isFalse);
    repo.close();
  });

  test('empty or too-long names are refused, tags are casefold-deduped, and search is namespace-first', () {
    final repoA = GraphicRepository.open(p.join(dir.path, 'lib'), appA);
    repoA.registerRights(
      rightsId: 'rights-g',
      epoch: '0',
      allowedUses: ['use'],
      redistributable: false,
    );
    expect(
      () => repoA.publish(
        GraphicDraft(
          asset: asset(ns: appA, id: 'g1', name: '   ', rightsId: 'rights-g'),
        ),
        null,
        '0',
      ),
      code(nameRejected),
    );
    expect(
      () => repoA.publish(
        GraphicDraft(
          asset: asset(
            ns: appA,
            id: 'g1',
            name: 'x' * 257,
            rightsId: 'rights-g',
          ),
        ),
        null,
        '0',
      ),
      code(nameRejected),
    );
    final pin = repoA.publish(
      GraphicDraft(
        asset: asset(
          ns: appA,
          id: 'g1',
          name: 'Paper Leaf',
          rightsId: 'rights-g',
          tags: ['Paper', 'paper', 'LEAF'],
        ),
      ),
      null,
      '0',
    );
    expect(repoA.load('g1', 1).tags, ['paper', 'leaf']);
    final editor = TemplateEditorSession(repository: repoA, namespace: appA);
    expect(editor.search(text: 'leaf').items.single.id, 'g1');
    expect(editor.search(tags: ['paper']).items.single.id, 'g1');
    final renamed = editor.rename(pin, 'Maple');
    expect(renamed.version, 2);
    expect(repoA.load('g1', 2).name, 'Maple');
    final repoB = GraphicRepository.open(p.join(dir.path, 'lib'), appB);
    expect(repoB.search(namespace: appB, text: 'Maple').items, isEmpty);
    expect(repoB.search(namespace: appA, text: 'Maple').items, isEmpty);
    repoA.close();
    repoB.close();
  });

  test('template editor rebinds a photo without flattening or changing text, ids, or transforms', () {
    final repo = GraphicRepository.open(p.join(dir.path, 'lib'), appA);
    final editor = TemplateEditorSession(repository: repo, namespace: appA);
    final photo = blob('photo-a');
    final other = blob('photo-b');
    final born = editor.instantiateOfficial(
      'tmpl-photo-card-portrait',
      bindings: [TemplateBinding(slotId: 'slot-photo', assetHash: photo)],
    );
    final photoLayerId = '${born.document.id}-ly-photo';
    final titleBefore = born.document.layer('${born.document.id}-ly-title').text;
    final titleTransform =
        born.document.layer('${born.document.id}-ly-title').transform;
    final original = born.document.originalHash(photoLayerId);
    expect(original, photo);
    editor.selectSlot('slot-photo');
    editor.rebindSelected(assetHash: other);
    expect(born.document.originalHash(photoLayerId), photo);
    expect(born.document.layer(photoLayerId).sourceHash, other);
    expect(born.document.layer('${born.document.id}-ly-title').text, titleBefore);
    expect(
      born.document.layer('${born.document.id}-ly-title').transform.tx,
      titleTransform.tx,
    );
    expect(born.document.layers.length, OfficialTemplateCatalog.byId('tmpl-photo-card-portrait').layers.length);
    expect(editor.refuseFlatten, code(flattenForbidden));
    repo.close();
  });

  test('a required empty slot may stay as a draft but blocks delivery; unknown template metadata refuses upgrade/rebind', () {
    final repo = GraphicRepository.open(p.join(dir.path, 'lib'), appA);
    final editor = TemplateEditorSession(repository: repo, namespace: appA);
    editor.instantiateOfficial('tmpl-photo-card-portrait', allowDraft: true);
    expect(() => editor.requestDelivery(), code(requiredSlotEmpty));
    expect(
      () => editor.instantiateStored(
        templateId: 'tmpl-unknown',
        version: '1.0.0',
        bindings: const [],
        metadataRecognized: false,
      ),
      code(unknownTemplate),
    );
    repo.close();
  });

  test('published versions are immutable', () {
    final repo = GraphicRepository.open(p.join(dir.path, 'lib'), appA);
    repo.registerRights(
      rightsId: 'rights-g',
      epoch: '0',
      allowedUses: ['use'],
      redistributable: false,
    );
    final pin = repo.publish(
      GraphicDraft(asset: asset(ns: appA, id: 'g1', name: 'Leaf', rightsId: 'rights-g')),
      null,
      '0',
    );
    expect(
      () => repo.store.insertVersion(
        kind: 'graphic',
        id: pin.id,
        version: '1',
        bodyHash: pin.hash,
      ),
      code(immutableGraphicVersion),
    );
    repo.close();
  });
}
