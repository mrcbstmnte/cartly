import 'package:flutter/material.dart';

class AddItemSheet extends StatefulWidget {
  const AddItemSheet({required this.onSubmit, super.key});

  /// Returns null on success, or a message to display on failure.
  final Future<String?> Function({required String name, required int quantity})
  onSubmit;

  @override
  State<AddItemSheet> createState() => _AddItemSheetState();
}

class _AddItemSheetState extends State<AddItemSheet> {
  final _nameController = TextEditingController();
  final _quantityController = TextEditingController(text: '1');
  final _formKey = GlobalKey<FormState>();
  bool _submitting = false;
  String? _serverError;

  @override
  void dispose() {
    _nameController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _submitting = true;
      _serverError = null;
    });
    String? error;
    try {
      error = await widget.onSubmit(
        name: _nameController.text.trim(),
        quantity: int.parse(_quantityController.text),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
    if (!mounted) return;

    if (error == null) {
      Navigator.of(context).pop();
    } else {
      // The sheet covers the screen's SnackBar, so show the reason here too.
      setState(() => _serverError = error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              key: const Key('name-field'),
              controller: _nameController,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Item name'),
              validator: (value) =>
                  (value ?? '').trim().isEmpty ? 'Enter a name' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('quantity-field'),
              controller: _quantityController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Quantity'),
              validator: (value) {
                final quantity = int.tryParse(value ?? '');
                if (quantity == null) return 'Enter a whole number';
                if (quantity < 1) return 'Quantity must be at least 1';
                return null;
              },
            ),
            if (_serverError != null) ...[
              const SizedBox(height: 12),
              Text(
                _serverError!,
                key: const Key('server-error'),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _submitting ? null : _submit,
                child: const Text('Add'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
