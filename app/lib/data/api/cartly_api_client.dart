import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/api_exception.dart';
import '../../core/config.dart';

/// The single HTTP boundary of the app. Widgets and state objects must never
/// import package:http; they go through ItemsRepository, which goes through
/// this class. test/architecture_test.dart enforces that.
class CartlyApiClient {
  CartlyApiClient({required CartlyConfig config, http.Client? client})
      // ignore: prefer_initializing_formals
      : _config = config,
        _client = client ?? http.Client();

  final CartlyConfig _config;
  final http.Client _client;

  Map<String, String> get _headers => {
        'x-user-id': _config.userId,
        'content-type': 'application/json',
      };

  Uri _uri(String path) => Uri.parse('${_config.baseUrl}$path');

  Future<List<Map<String, dynamic>>> fetchItems() async {
    final response = await _client.get(_uri('/items'), headers: _headers);
    final decoded = _decode(response);
    return (decoded as List<dynamic>).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> createItem({
    required String name,
    required int quantity,
  }) async {
    final response = await _client.post(
      _uri('/items'),
      headers: _headers,
      body: jsonEncode({'name': name, 'quantity': quantity}),
    );
    return _decode(response) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> setBought(
    String id, {
    required bool bought,
  }) async {
    final response = await _client.patch(
      _uri('/items/$id'),
      headers: _headers,
      body: jsonEncode({'bought': bought}),
    );
    return _decode(response) as Map<String, dynamic>;
  }

  Future<void> deleteItem(String id) async {
    final response = await _client.delete(_uri('/items/$id'), headers: _headers);
    _decode(response);
  }

  Future<int> clearBought() async {
    final response = await _client.delete(
      _uri('/items/bought'),
      headers: _headers,
    );
    final decoded = _decode(response) as Map<String, dynamic>;
    return (decoded['deleted'] as num).toInt();
  }

  /// Returns the decoded body, or throws an ApiException carrying the
  /// backend's own message so the UI can show the real reason.
  dynamic _decode(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return null;
      return jsonDecode(response.body);
    }

    throw ApiException(
      _messageFrom(response),
      statusCode: response.statusCode,
    );
  }

  String _messageFrom(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        final raw = decoded['message'];
        if (raw is String) return raw;
        if (raw is List) return raw.join('\n');
      }
    } on FormatException {
      // Not JSON (a proxy error page, for instance). Fall through.
    }
    return 'Request failed (${response.statusCode})';
  }
}
