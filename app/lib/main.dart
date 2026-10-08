import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'ui/items_screen.dart';

void main() {
  runApp(
    ProviderScope(
      // Riverpod 3 automatically retries a provider whose build() throws —
      // up to 10 attempts with exponential backoff, roughly 38 seconds —
      // and only skips that when the thrown object `is Error`. ApiException
      // implements Exception, so a failed initial fetch would sit in the
      // loading state for ~38s before the UI ever saw the failure. US-1
      // requires the user to see an error and a way to retry, so the retry
      // here is the explicit Retry button, not a silent backoff storm.
      retry: (_, _) => null,
      child: const CartlyApp(),
    ),
  );
}

class CartlyApp extends StatelessWidget {
  const CartlyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cartly',
      theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
      home: const ItemsScreen(),
    );
  }
}
