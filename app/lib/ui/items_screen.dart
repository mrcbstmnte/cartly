import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/item.dart';
import '../state/providers.dart';
import 'widgets/item_tile.dart';
import 'widgets/list_states.dart';

class ItemsScreen extends ConsumerWidget {
  const ItemsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(itemsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Cartly')),
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
          onToggle: (bought) => ref
              .read(itemsProvider.notifier)
              .setBought(item.id, bought: bought),
          onDelete: () => ref.read(itemsProvider.notifier).deleteItem(item.id),
        );
      },
    );
  }
}
