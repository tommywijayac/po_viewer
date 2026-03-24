import 'package:flutter/material.dart';

import '../models/item_model.dart';
import '../database/memory_store.dart';
import '../widgets/purchase_order_item_card.dart';

class SavedTab extends StatefulWidget {
  const SavedTab({super.key});

  @override
  State<SavedTab> createState() => _SavedTabState();
}

class _SavedTabState extends State<SavedTab> {
  List<PurchaseOrderItem> _items = MemoryStore.savedItems;

  @override
  void initState() {
    super.initState();
  }

  void _loadItems() {
    setState(() {
      _items = MemoryStore.savedItems;
    });
  }

  Future<void> _removeItem(PurchaseOrderItem item) async {
    try {
      MemoryStore.removeItem(item);
      _loadItems();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Removed: ${item.productName}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error removing item: $e')),
        );
      }
    }
  }

  Future<void> _removeAll() async {
    try {
      MemoryStore.clear();
      _loadItems();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All items removed')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error removing items: $e')),
        );
      }
    }
  }

  void _showRemoveAllConfirmation() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Remove All Items?'),
          content: const Text('This action cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _removeAll();
              },
              child: const Text('Remove All', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: ElevatedButton.icon(
            onPressed: _items.isNotEmpty ? _showRemoveAllConfirmation : null,
            icon: const Icon(Icons.delete_sweep),
            label: const Text('Remove All'),
          ),
        ),
        Expanded(
          child: _items.isEmpty
              ? Center(
                  child: Text(
                    'No saved items yet',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                )
              : ListView.builder(
                  itemCount: _items.length,
                  itemBuilder: (context, index) {
                    final item = _items[index];
                    return PurchaseOrderItemCard(
                      item: item,
                      cardStyle: CardStyle.detailed,
                      priceFormatter: RupiahPriceFormatter(),
                      onTap: () {
                        // Could add functionality here if needed
                      },
                      onDeletePressed: () => _removeItem(item),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
