import 'package:flutter_test/flutter_test.dart';
import 'package:studio_demo/import_fixture_composition.dart';

void main() {
  test('initial lifetime allows an owner without publishing authority', () {
    final life = ImportCompositionLifetime();
    var retired = 0;
    life.register(() => ++retired);
    expect(retired, 0);
  });
  test('retirement is synchronous before replacement publication', () {
    final life = ImportCompositionLifetime();
    var scope = 'old';
    final observed = <String>[];
    life.register(() => observed.add(scope));
    life.invalidateBeforePublication();
    scope = 'new';
    expect(observed, ['old']);
  });
  test('retired generation cannot register an active ABA successor', () {
    final life = ImportCompositionLifetime();
    life.invalidateBeforePublication();
    var retired = 0;
    life.register(() => ++retired);
    expect(retired, 1);
  });
  test('disposal unregisters the private lifetime listener', () {
    final life = ImportCompositionLifetime();
    var retired = 0;
    final unregister = life.register(() => ++retired);
    unregister();
    life.invalidateBeforePublication();
    expect(retired, 0);
  });
}
