import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/item.dart';
import 'providers.dart';

class ItemsNotifier extends AsyncNotifier<List<Item>> {
  @override
  FutureOr<List<Item>> build() {
    return ref.read(itemsRepositoryProvider).fetchItems();
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(
      () => ref.read(itemsRepositoryProvider).fetchItems(),
    );
  }

  Future<void> addItem({required String name, required int quantity}) async {
    // Deliberately not optimistic: the list order is the database's
    // decision (US-1), so refetch rather than guess where the item lands.
    await ref
        .read(itemsRepositoryProvider)
        .createItem(name: name, quantity: quantity);
    await refresh();
  }

  Future<void> setBought(String id, {required bool bought}) async {
    await ref.read(itemsRepositoryProvider).setBought(id, bought: bought);
    await refresh();
  }

  Future<void> deleteItem(String id) async {
    await ref.read(itemsRepositoryProvider).deleteItem(id);
    await refresh();
  }

  Future<int> clearBought() async {
    final deleted = await ref.read(itemsRepositoryProvider).clearBought();
    await refresh();
    return deleted;
  }
}
