import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api_exception.dart';
import '../data/models/item.dart';
import '../state/providers.dart';
import 'widgets/add_item_sheet.dart';
import 'widgets/item_tile.dart';
import 'widgets/list_states.dart';

class ItemsScreen extends ConsumerWidget {
  const ItemsScreen({super.key});

  /// Runs a mutation and surfaces the backend's own message on failure,
  /// which is how US-2's "the rejection reason is shown to the user" is met.
  static Future<String?> _run(
    BuildContext context,
    Future<void> Function() action,
  ) async {
    try {
      await action();
      return null;
    } on ApiException catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
      return error.message;
    }
  }

  Future<void> _openAddSheet(BuildContext context, WidgetRef ref) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => AddItemSheet(
        onSubmit: ({required String name, required int quantity}) => _run(
          context,
          () => ref
              .read(itemsProvider.notifier)
              .addItem(name: name, quantity: quantity),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(itemsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cartly'),
        actions: [
          IconButton(
            icon: const Icon(Icons.cleaning_services_outlined),
            tooltip: 'Clear bought items',
            onPressed: () => _run(
              context,
              () => ref.read(itemsProvider.notifier).clearBought(),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Add item',
        onPressed: () => _openAddSheet(context, ref),
        child: const Icon(Icons.add),
      ),
      body: switch (items) {
        AsyncError(:final error) => ErrorRetryView(
            message: error.toString(),
            onRetry: () => ref.invalidate(itemsProvider),
          ),
        AsyncData(:final value) =>
          value.isEmpty ? const EmptyListView() : _ItemList(items: value),
        _ => const LoadingView(),
      },
    );
  }
}

class _ItemList extends ConsumerWidget {
  const _ItemList({required this.items});

  final List<Item> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // No sorting here: the order is exactly what the API returned (US-1).
    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final item = items[index];
        return ItemTile(
          item: item,
          onToggle: (bought) => ItemsScreen._run(
            context,
            () => ref
                .read(itemsProvider.notifier)
                .setBought(item.id, bought: bought),
          ),
          onDelete: () => ItemsScreen._run(
            context,
            () => ref.read(itemsProvider.notifier).deleteItem(item.id),
          ),
        );
      },
    );
  }
}
