import 'package:flutter/material.dart';
import '../models/item_model.dart';
import '../database/database_helper.dart';
import '../widgets/purchase_order_item_card.dart';

class SavedTab extends StatefulWidget {
  const SavedTab({super.key});

  @override
  State<SavedTab> createState() => _SavedTabState();
}

class _SavedTabState extends State<SavedTab> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  late Future<List<PurchaseOrderItem>> _itemsFuture;

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  void _loadItems() {
    setState(() {
      _itemsFuture = _dbHelper.getAllItems();
    });
  }

  Future<void> _removeItem(int id, String itemName) async {
    try {
      await _dbHelper.deleteItem(id);
      _loadItems();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Removed: $itemName')),
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
      await _dbHelper.deleteAllItems();
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
          child: FutureBuilder<List<PurchaseOrderItem>>(
            future: _itemsFuture,
            builder: (context, snapshot) {
              bool hasItems = snapshot.hasData && snapshot.data!.isNotEmpty;
              return ElevatedButton.icon(
                onPressed: hasItems ? _showRemoveAllConfirmation : null,
                icon: const Icon(Icons.delete_sweep),
                label: const Text('Remove All'),
              );
            },
          ),
        ),
        Expanded(
          child: FutureBuilder<List<PurchaseOrderItem>>(
            future: _itemsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(
                  child: Text('Error: ${snapshot.error}'),
                );
              }

              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return Center(
                  child: Text(
                    'No saved items yet',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                );
              }

              List<PurchaseOrderItem> items = snapshot.data!;

              return ListView.builder(
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  return PurchaseOrderItemCard(
                    item: item,
                    cardStyle: CardStyle.compact,
                    priceFormatter: RupiahPriceFormatter(),
                    onTap: () {
                      // Could add functionality here if needed
                    },
                    onDeletePressed: () =>
                        _removeItem(item.id!, item.productName),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
