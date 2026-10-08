import 'package:cartly/core/api_exception.dart';
import 'package:cartly/data/models/item.dart';
import 'package:cartly/state/providers.dart';
import 'package:cartly/ui/items_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_items_repository.dart';

Item _item(String name, {bool bought = false, int quantity = 1}) => Item(
      id: name,
      name: name,
      quantity: quantity,
      bought: bought,
      createdAt: DateTime.utc(2026, 1, 1),
    );

Widget _app(FakeItemsRepository repository) => ProviderScope(
      // Mirrors main.dart: without this, Riverpod 3 retries a throwing
      // build() for ~38s and the error-state test would hang in
      // pumpAndSettle rather than finding the error view.
      retry: (_, _) => null,
      overrides: [itemsRepositoryProvider.overrideWithValue(repository)],
      child: const MaterialApp(home: ItemsScreen()),
    );

void main() {
  testWidgets('shows a loading state while the list loads', (tester) async {
    await tester.pumpWidget(
      _app(FakeItemsRepository(fetchDelay: const Duration(seconds: 1))),
    );

    // One pump only: the fetch is still in flight.
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
  });

  testWidgets('says the list is empty in a clear way', (tester) async {
    await tester.pumpWidget(_app(FakeItemsRepository()));
    await tester.pumpAndSettle();

    expect(find.text('Your list is empty'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('shows an error and a retry action when loading fails',
      (tester) async {
    await tester.pumpWidget(
      _app(
        FakeItemsRepository(
          failWith: const ApiException('Network unreachable', statusCode: 500),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Network unreachable'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Retry'), findsOneWidget);
  });

  testWidgets('retry refetches the list', (tester) async {
    final repository = FakeItemsRepository(
      failWith: const ApiException('Network unreachable', statusCode: 500),
    );
    await tester.pumpWidget(_app(repository));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Retry'));
    await tester.pumpAndSettle();

    expect(repository.calls.where((call) => call == 'fetchItems').length, 2);
  });

  testWidgets('shows each item name, quantity and bought state',
      (tester) async {
    await tester.pumpWidget(
      _app(
        FakeItemsRepository(
          items: [
            _item('milk', quantity: 2),
            _item('bread', bought: true, quantity: 1),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('milk'), findsOneWidget);
    expect(find.text('bread'), findsOneWidget);
    expect(find.text('Qty 2'), findsOneWidget);
    expect(find.text('Qty 1'), findsOneWidget);

    final checkboxes =
        tester.widgetList<Checkbox>(find.byType(Checkbox)).toList();
    expect(checkboxes, hasLength(2));
    expect(checkboxes.first.value, isFalse);
    expect(checkboxes.last.value, isTrue);
  });

  testWidgets('renders items in the order the backend returned them',
      (tester) async {
    await tester.pumpWidget(
      _app(
        FakeItemsRepository(
          // Bought-first is an order the real backend would never return
          // (US-1 has the database sort unbought-first), but that's what
          // makes this fixture able to catch a regression: a buggy
          // sort-by-bought-status would flip this to unbought-first, while
          // leaving an already-unbought-first fixture unchanged and the
          // test wrongly green.
          items: [_item('bought-one', bought: true), _item('unbought')],
        ),
      ),
    );
    await tester.pumpAndSettle();

    final names = tester
        .widgetList<Text>(find.byType(Text))
        .map((text) => text.data)
        .where((data) => data == 'unbought' || data == 'bought-one')
        .toList();

    // The app must not re-sort; it shows what the API gave it (US-1).
    expect(names, ['bought-one', 'unbought']);
  });
}
