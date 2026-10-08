import 'api/cartly_api_client.dart';
import 'models/item.dart';

/// Domain-facing data access. Returns models, throws ApiException. Knows
/// nothing about HTTP; the state layer knows nothing about JSON.
class ItemsRepository {
  const ItemsRepository(this._api);

  final CartlyApiClient _api;

  Future<List<Item>> fetchItems() async {
    final raw = await _api.fetchItems();
    // Order is the backend's responsibility (US-1 requires the database to
    // sort). Do not re-sort here.
    return raw.map(Item.fromJson).toList();
  }

  Future<Item> createItem({required String name, required int quantity}) async {
    final raw = await _api.createItem(name: name, quantity: quantity);
    return Item.fromJson(raw);
  }

  Future<Item> setBought(String id, {required bool bought}) async {
    final raw = await _api.setBought(id, bought: bought);
    return Item.fromJson(raw);
  }

  Future<void> deleteItem(String id) => _api.deleteItem(id);

  Future<int> clearBought() => _api.clearBought();
}
