import 'package:cartly/core/api_exception.dart';
import 'package:cartly/data/items_repository.dart';
import 'package:cartly/data/models/item.dart';

/// A repository that serves a scripted list and records calls, so the state
/// layer can be tested without HTTP.
class FakeItemsRepository implements ItemsRepository {
  FakeItemsRepository({
    List<Item> items = const [],
    this.failWith,
    this.fetchDelay,
  }) : _items = [...items];

  List<Item> _items;
  final ApiException? failWith;
  final Duration? fetchDelay;

  final List<String> calls = <String>[];

  void setItems(List<Item> items) => _items = [...items];

  @override
  Future<List<Item>> fetchItems() async {
    calls.add('fetchItems');
    if (fetchDelay != null) await Future<void>.delayed(fetchDelay!);
    if (failWith != null) throw failWith!;
    return [..._items];
  }

  @override
  Future<Item> createItem({
    required String name,
    required int quantity,
  }) async {
    calls.add('createItem:$name:$quantity');
    if (failWith != null) throw failWith!;
    final item = Item(
      id: 'generated-${_items.length}',
      name: name,
      quantity: quantity,
      bought: false,
      createdAt: DateTime.utc(2026, 1, 1),
    );
    _items = [item, ..._items];
    return item;
  }

  @override
  Future<Item> setBought(String id, {required bool bought}) async {
    calls.add('setBought:$id:$bought');
    if (failWith != null) throw failWith!;
    final existing = _items.firstWhere((item) => item.id == id);
    final updated = Item(
      id: existing.id,
      name: existing.name,
      quantity: existing.quantity,
      bought: bought,
      createdAt: existing.createdAt,
    );
    _items = [
      for (final item in _items) if (item.id == id) updated else item,
    ];
    return updated;
  }

  @override
  Future<void> deleteItem(String id) async {
    calls.add('deleteItem:$id');
    if (failWith != null) throw failWith!;
    _items = _items.where((item) => item.id != id).toList();
  }

  @override
  Future<int> clearBought() async {
    calls.add('clearBought');
    if (failWith != null) throw failWith!;
    final before = _items.length;
    _items = _items.where((item) => !item.bought).toList();
    return before - _items.length;
  }
}
