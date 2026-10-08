class Item {
  const Item({
    required this.id,
    required this.name,
    required this.quantity,
    required this.bought,
    required this.createdAt,
  });

  factory Item.fromJson(Map<String, dynamic> json) => Item(
        id: json['id'] as String,
        name: json['name'] as String,
        // num, not int: JSON numbers can decode as double.
        quantity: (json['quantity'] as num).toInt(),
        bought: json['bought'] as bool,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );

  final String id;
  final String name;
  final int quantity;
  final bool bought;
  final DateTime createdAt;

  @override
  bool operator ==(Object other) =>
      other is Item &&
      other.id == id &&
      other.name == name &&
      other.quantity == quantity &&
      other.bought == bought &&
      other.createdAt == createdAt;

  @override
  int get hashCode => Object.hash(id, name, quantity, bought, createdAt);
}
