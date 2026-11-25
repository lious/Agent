import 'package:studio_contracts/studio_contracts.dart';
import 'package:test/test.dart';

void main() {
  test('namespace tuple cannot collide on delimiter-like identifiers', () {
    expect(Namespace('a:b', 'c', 'd'), isNot(Namespace('a', 'b:c', 'd')));
    expect(Namespace('studio', 't', 'w'), Namespace('studio', 't', 'w'));
  });
  test('empty, paths, unicode and oversized IDs are rejected', () {
    for (final id in ['', '../x', '/root', 'a/b', 'a\\b', '汉字', 'a' * 129]) {
      expect(() => requireId(id), throwsA(isA<StudioException>()));
    }
    requireId('allowed@id:1');
  });
  test(
    'profile feature collection cannot be mutated through caller reference',
    () {
      final features = {'project.metadata'};
      final profile = AppProfile(
        appId: 'studio',
        region: 'local',
        features: features,
      );
      features.clear();
      expect(profile.features, contains('project.metadata'));
      expect(() => profile.features.add('upload'), throwsUnsupportedError);
    },
  );
}
