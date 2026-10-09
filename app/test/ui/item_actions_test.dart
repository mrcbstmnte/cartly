import 'package:cartly/core/api_exception.dart';
import 'package:cartly/data/models/item.dart';
import 'package:cartly/state/providers.dart';
import 'package:cartly/ui/items_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_items_repository.dart';

Item _item(String name, {bool bought = false}) => Item(
  id: name,
  name: name,
  quantity: 1,
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
  testWidgets('adds an item through the sheet (US-2)', (tester) async {
    final repository = FakeItemsRepository();
    await tester.pumpWidget(_app(repository));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Add item'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('name-field')), 'milk');
    await tester.enterText(find.byKey(const Key('quantity-field')), '3');
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await tester.pumpAndSettle();

    expect(repository.calls, contains('createItem:milk:3'));
    expect(find.text('milk'), findsOneWidget);
  });

  testWidgets('shows the backend rejection reason (US-2)', (tester) async {
    final repository = FakeItemsRepository(
      failWith: const ApiException(
        'quantity must be at least 1',
        statusCode: 400,
      ),
    );
    await tester.pumpWidget(_app(repository));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Add item'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('name-field')), 'milk');
    await tester.enterText(find.byKey(const Key('quantity-field')), '1');
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await tester.pumpAndSettle();

    // failWith also fails the initial fetch, so the error view shows the same
    // text; scope the assertion to the SnackBar, which is what US-2 requires.
    expect(
      find.descendant(
        of: find.byType(SnackBar),
        matching: find.text('quantity must be at least 1'),
      ),
      findsOneWidget,
    );
    // The sheet stays open and shows the reason inline (it covers the SnackBar).
    expect(find.byKey(const Key('server-error')), findsOneWidget);
    expect(find.byKey(const Key('name-field')), findsOneWidget);
  });

  testWidgets('toggles an item bought (US-3)', (tester) async {
    final repository = FakeItemsRepository(items: [_item('milk')]);
    await tester.pumpWidget(_app(repository));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();

    expect(repository.calls, [
      'fetchItems',
      'setBought:milk:true',
      'fetchItems',
    ]);
  });

  testWidgets('a failed mutation keeps the loaded list (US-3)', (tester) async {
    final repository = FakeItemsRepository(
      items: [_item('milk'), _item('bread')],
      failMutationsWith: const ApiException('item not found', statusCode: 404),
    );
    await tester.pumpWidget(_app(repository));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byType(SnackBar),
        matching: find.text('item not found'),
      ),
      findsOneWidget,
    );
    expect(find.text('milk'), findsOneWidget);
    expect(find.text('bread'), findsOneWidget);
  });

  testWidgets('deletes an item (US-4)', (tester) async {
    final repository = FakeItemsRepository(items: [_item('milk')]);
    await tester.pumpWidget(_app(repository));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Delete milk'));
    await tester.pumpAndSettle();

    expect(repository.calls, contains('deleteItem:milk'));
    expect(find.text('milk'), findsNothing);
  });

  testWidgets('clears bought items (US-5)', (tester) async {
    final repository = FakeItemsRepository(
      items: [_item('milk', bought: true), _item('bread')],
    );
    await tester.pumpWidget(_app(repository));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Clear bought items'));
    await tester.pumpAndSettle();

    expect(repository.calls, contains('clearBought'));
    expect(find.text('milk'), findsNothing);
    expect(find.text('bread'), findsOneWidget);
  });

  testWidgets('clearing with nothing bought shows no error (US-5)', (
    tester,
  ) async {
    final repository = FakeItemsRepository(items: [_item('bread')]);
    await tester.pumpWidget(_app(repository));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Clear bought items'));
    await tester.pumpAndSettle();

    expect(find.byType(SnackBar), findsNothing);
    expect(find.text('bread'), findsOneWidget);
  });

  testWidgets('rejects an empty name before calling the API', (tester) async {
    final repository = FakeItemsRepository();
    await tester.pumpWidget(_app(repository));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Add item'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await tester.pumpAndSettle();

    expect(find.text('Enter a name'), findsOneWidget);
    expect(repository.calls.where((c) => c.startsWith('createItem')), isEmpty);
  });
}
