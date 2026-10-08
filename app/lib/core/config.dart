/// Runtime configuration. There is no login in this app (out of scope), so the
/// user ID is supplied at build time and sent as the x-user-id header:
///
///   flutter run -d chrome --dart-define=CARTLY_USER_ID=user-a
class CartlyConfig {
  const CartlyConfig({required this.baseUrl, required this.userId});

  const CartlyConfig.fromEnvironment()
      : baseUrl = const String.fromEnvironment(
          'CARTLY_API_BASE_URL',
          defaultValue: 'http://localhost:3000',
        ),
        userId = const String.fromEnvironment(
          'CARTLY_USER_ID',
          defaultValue: 'demo-user',
        );

  final String baseUrl;
  final String userId;
}
