import 'package:cartly/core/api_exception.dart';
import 'package:cartly/data/models/item.dart';
import 'package:cartly/state/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_items_repository.dart';

Item _item(String id, {bool bought = false}) => Item(
      id: id,
      name: id,
      quantity: 1,
      bought: bought,
      createdAt: DateTime.utc(2026, 1, 1),
    );

ProviderContainer _containerWith(FakeItemsRepository repository) {
  final container = ProviderContainer(
    overrides: [itemsRepositoryProvider.overrideWithValue(repository)],
    // Riverpod 3's default retry policy re-runs a throwing build() with
    // exponential backoff (up to ~38s across 10 attempts) before settling
    // into AsyncError, because ApiException implements Exception rather
    // than Error. Disabled here so error-path tests are deterministic and
    // fast; production wiring in lib/state is untouched.
    retry: (_, _) => null,
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('loads items from the repository', () async {
    final repository = FakeItemsRepository(items: [_item('a'), _item('b')]);
    final container = _containerWith(repository);

    final items = await container.read(itemsProvider.future);

    expect(items.map((item) => item.id), ['a', 'b']);
    expect(repository.calls, ['fetchItems']);
  });

  test('surfaces a load failure as an error state', () async {
    final repository = FakeItemsRepository(
      failWith: const ApiException('boom', statusCode: 500),
    );
    final container = _containerWith(repository);

    await expectLater(
      container.read(itemsProvider.future),
      throwsA(isA<ApiException>()),
    );
    expect(container.read(itemsProvider).hasError, isTrue);
  });

  test('addItem creates then refetches, so the backend decides order', () async {
    final repository = FakeItemsRepository();
    final container = _containerWith(repository);
    await container.read(itemsProvider.future);

    await container
        .read(itemsProvider.notifier)
        .addItem(name: 'milk', quantity: 2);

    expect(repository.calls, [
      'fetchItems',
      'createItem:milk:2',
      'fetchItems',
    ]);
    expect(container.read(itemsProvider).requireValue.single.name, 'milk');
  });

  test('addItem rethrows so the UI can show the rejection reason', () async {
    final repository = FakeItemsRepository(
      failWith: const ApiException('name must not be empty', statusCode: 400),
    );
    final container = _containerWith(repository);

    await expectLater(
      container.read(itemsProvider.notifier).addItem(name: '', quantity: 1),
      throwsA(
        isA<ApiException>()
            .having((e) => e.message, 'message', 'name must not be empty'),
      ),
    );
  });

  test('setBought updates then refetches', () async {
    final repository = FakeItemsRepository(items: [_item('a')]);
    final container = _containerWith(repository);
    await container.read(itemsProvider.future);

    await container.read(itemsProvider.notifier).setBought('a', bought: true);

    expect(repository.calls, [
      'fetchItems',
      'setBought:a:true',
      'fetchItems',
    ]);
    expect(container.read(itemsProvider).requireValue.single.bought, isTrue);
  });

  test('deleteItem removes the item', () async {
    final repository = FakeItemsRepository(items: [_item('a'), _item('b')]);
    final container = _containerWith(repository);
    await container.read(itemsProvider.future);

    await container.read(itemsProvider.notifier).deleteItem('a');

    expect(
      container.read(itemsProvider).requireValue.map((item) => item.id),
      ['b'],
    );
  });

  test('clearBought removes bought items and reports the count', () async {
    final repository = FakeItemsRepository(
      items: [_item('a', bought: true), _item('b'), _item('c', bought: true)],
    );
    final container = _containerWith(repository);
    await container.read(itemsProvider.future);

    final deleted =
        await container.read(itemsProvider.notifier).clearBought();

    expect(deleted, 2);
    expect(
      container.read(itemsProvider).requireValue.map((item) => item.id),
      ['b'],
    );
  });
}
