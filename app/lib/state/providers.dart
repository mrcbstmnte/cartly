import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config.dart';
import '../data/api/cartly_api_client.dart';
import '../data/items_repository.dart';
import '../data/models/item.dart';
import 'items_notifier.dart';

final configProvider = Provider<CartlyConfig>(
  (ref) => const CartlyConfig.fromEnvironment(),
);

final apiClientProvider = Provider<CartlyApiClient>(
  (ref) => CartlyApiClient(config: ref.watch(configProvider)),
);

/// Overridden in tests with a fake, which is why the notifier reads the
/// repository through a provider instead of constructing one.
final itemsRepositoryProvider = Provider<ItemsRepository>(
  (ref) => ItemsRepository(ref.watch(apiClientProvider)),
);

final itemsProvider =
    AsyncNotifierProvider<ItemsNotifier, List<Item>>(ItemsNotifier.new);
