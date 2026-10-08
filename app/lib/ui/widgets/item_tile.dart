import 'package:flutter/material.dart';

import '../../data/models/item.dart';

class ItemTile extends StatelessWidget {
  const ItemTile({
    required this.item,
    required this.onToggle,
    required this.onDelete,
    super.key,
  });

  final Item item;
  final ValueChanged<bool> onToggle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Checkbox(
        value: item.bought,
        onChanged: (value) => onToggle(value ?? false),
      ),
      title: Text(
        item.name,
        style: TextStyle(
          decoration: item.bought ? TextDecoration.lineThrough : null,
          color: item.bought ? Theme.of(context).disabledColor : null,
        ),
      ),
      subtitle: Text('Qty ${item.quantity}'),
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline),
        tooltip: 'Delete ${item.name}',
        onPressed: onDelete,
      ),
    );
  }
}
