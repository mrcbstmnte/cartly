import 'dart:convert';

import 'package:cartly/core/api_exception.dart';
import 'package:cartly/core/config.dart';
import 'package:cartly/data/api/cartly_api_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _config = CartlyConfig(baseUrl: 'http://api.test', userId: 'user-a');

void main() {
  test('sends the user id header on every request', () async {
    final seenHeaders = <Map<String, String>>[];
    final client = CartlyApiClient(
      config: _config,
      client: MockClient((request) async {
        seenHeaders.add(request.headers);
        switch (request.method) {
          case 'GET':
            return http.Response('[]', 200);
          case 'POST':
          case 'PATCH':
            return http.Response(jsonEncode({'id': 'a'}), 200);
          case 'DELETE':
            if (request.url.toString().endsWith('/items/bought')) {
              return http.Response(jsonEncode({'deleted': 0}), 200);
            }
            return http.Response('', 200);
          default:
            throw StateError('unexpected method ${request.method}');
        }
      }),
    );

    await client.fetchItems();
    await client.createItem(name: 'milk', quantity: 1);
    await client.setBought('a', bought: true);
    await client.deleteItem('a');
    await client.clearBought();

    expect(seenHeaders, hasLength(5));
    for (final headers in seenHeaders) {
      expect(headers['x-user-id'], 'user-a');
    }
  });

  test('fetchItems returns the decoded list', () async {
    final client = CartlyApiClient(
      config: _config,
      client: MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.toString(), 'http://api.test/items');
        return http.Response(
          jsonEncode([
            {
              'id': 'a',
              'name': 'milk',
              'quantity': 1,
              'bought': false,
              'createdAt': '2026-01-01T00:00:00.000Z',
              'updatedAt': '2026-01-01T00:00:00.000Z',
            }
          ]),
          200,
        );
      }),
    );

    final items = await client.fetchItems();

    expect(items, hasLength(1));
    expect(items.first['name'], 'milk');
  });

  test('createItem posts name and quantity as JSON', () async {
    String? method;
    String? url;
    Map<String, dynamic>? sentBody;
    final client = CartlyApiClient(
      config: _config,
      client: MockClient((request) async {
        method = request.method;
        url = request.url.toString();
        sentBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(jsonEncode({'id': 'a'}), 201);
      }),
    );

    await client.createItem(name: 'milk', quantity: 3);

    expect(method, 'POST');
    expect(url, 'http://api.test/items');
    expect(sentBody, {'name': 'milk', 'quantity': 3});
  });

  test('surfaces the backend validation message (US-2)', () async {
    final client = CartlyApiClient(
      config: _config,
      client: MockClient((request) async {
        return http.Response(
          jsonEncode({
            'message': ['name must not be empty', 'quantity must be at least 1'],
            'statusCode': 400,
          }),
          400,
        );
      }),
    );

    await expectLater(
      client.createItem(name: '', quantity: 0),
      throwsA(
        isA<ApiException>()
            .having((e) => e.statusCode, 'statusCode', 400)
            .having((e) => e.message, 'message', contains('name must not be empty')),
      ),
    );
  });

  test('surfaces a single-string message', () async {
    final client = CartlyApiClient(
      config: _config,
      client: MockClient((request) async {
        return http.Response(
          jsonEncode({'message': 'Item abc not found', 'statusCode': 404}),
          404,
        );
      }),
    );

    await expectLater(
      client.deleteItem('abc'),
      throwsA(
        isA<ApiException>().having((e) => e.message, 'message', 'Item abc not found'),
      ),
    );
  });

  test('falls back to a readable message when the body is not JSON', () async {
    final client = CartlyApiClient(
      config: _config,
      client: MockClient((request) async => http.Response('<html>502</html>', 502)),
    );

    await expectLater(
      client.fetchItems(),
      throwsA(
        isA<ApiException>().having((e) => e.message, 'message', contains('502')),
      ),
    );
  });

  test('setBought patches the desired state', () async {
    String? method;
    String? url;
    Map<String, dynamic>? body;
    final client = CartlyApiClient(
      config: _config,
      client: MockClient((request) async {
        method = request.method;
        url = request.url.toString();
        body = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(jsonEncode({'id': 'a'}), 200);
      }),
    );

    await client.setBought('a', bought: true);

    expect(method, 'PATCH');
    expect(url, 'http://api.test/items/a');
    expect(body, {'bought': true});
  });

  test('clearBought deletes the bought collection endpoint', () async {
    String? url;
    final client = CartlyApiClient(
      config: _config,
      client: MockClient((request) async {
        url = request.url.toString();
        return http.Response(jsonEncode({'deleted': 2}), 200);
      }),
    );

    await client.clearBought();

    expect(url, 'http://api.test/items/bought');
  });
}
