import 'package:cartly/data/models/item.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Item.fromJson', () {
    test('parses every field the API returns', () {
      final item = Item.fromJson(const {
        'id': 'abc123',
        'name': 'milk',
        'quantity': 2,
        'bought': false,
        'createdAt': '2026-01-01T00:00:00.000Z',
        'updatedAt': '2026-01-01T00:00:00.000Z',
      });

      expect(item.id, 'abc123');
      expect(item.name, 'milk');
      expect(item.quantity, 2);
      expect(item.bought, isFalse);
      expect(item.createdAt, DateTime.utc(2026, 1, 1));
    });

    test('accepts a quantity sent as a double', () {
      final item = Item.fromJson(const {
        'id': 'abc123',
        'name': 'milk',
        'quantity': 2.0,
        'bought': true,
        'createdAt': '2026-01-01T00:00:00.000Z',
        'updatedAt': '2026-01-01T00:00:00.000Z',
      });

      expect(item.quantity, 2);
    });

    test('compares by value so widget tests can assert on lists', () {
      const json = {
        'id': 'abc123',
        'name': 'milk',
        'quantity': 1,
        'bought': false,
        'createdAt': '2026-01-01T00:00:00.000Z',
        'updatedAt': '2026-01-01T00:00:00.000Z',
      };

      expect(Item.fromJson(json), Item.fromJson(json));
    });
  });
}
