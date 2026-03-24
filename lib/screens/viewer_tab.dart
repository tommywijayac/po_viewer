import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart' as excel;

import '../models/item_model.dart';
import '../database/database_helper.dart';
import '../database/memory_store.dart';
import '../widgets/purchase_order_item_card.dart';

enum SnackBarType { info, warning, error }

class ViewerTab extends StatefulWidget {
  const ViewerTab({super.key});

  @override
  State<ViewerTab> createState() => _ViewerTabState();
}

class _ViewerTabState extends State<ViewerTab> {
  File? selectedFile;
  bool isLoading = false;
  final TextEditingController searchController = TextEditingController();
  
  int totalItemsInDatabase = 0;
  List<PurchaseOrderItem> filteredData = [];
  PurchaseOrderItem? selectedItem;
  final DatabaseHelper _dbHelper = DatabaseHelper();

  void _showSnackBar(String message, {SnackBarType type = SnackBarType.info}) {
    if (mounted) {
      final color = switch (type) {
        SnackBarType.info  => Colors.blue,
        SnackBarType.warning => Colors.orange,
        SnackBarType.error => Colors.red,
      };

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: color,
        ),
      );
    }
  }


  Future<void> pickExcelFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
      );

      if (result != null) {
        setState(() {
          selectedFile = File(result.files.single.path!);
          selectedItem = null;
          searchController.clear();
          filteredData = []; // Clear previous search results
          isLoading = true;
        });
        await _loadExcelData();
      }
    } catch (e) {
      _showSnackBar('Error picking file: $e', type: SnackBarType.error);
    }
  }

  Future<void> _resetDatabase() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Data'),
        content: const Text(
          'Are you sure you want to reset the data? This will permanently delete all saved purchase order items and cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _dbHelper.deleteAllItems();
        MemoryStore.clear();
        setState(() {
          selectedFile = null;
          selectedItem = null;
          searchController.clear();
          filteredData = [];
          totalItemsInDatabase = 0;
        });
        _showSnackBar('Database reset successfully', type: SnackBarType.info);
      } catch (e) {
        _showSnackBar('Error resetting database: $e', type: SnackBarType.error);
      }
    }
  }

  Future<void> _loadExcelData() async {
    try {
      if (selectedFile == null) return;

      final fileBytes = selectedFile!.readAsBytesSync();
      final result = await compute(_parseExcelInIsolate, fileBytes);

      final parsedRows = result['rows'] as List<Map<String, dynamic>>;
      final loadedSheetName = result['sheetName'] as String?;

      if (parsedRows.isEmpty) {
        _showSnackBar('No data found in first sheet', type: SnackBarType.warning);
        setState(() {
          isLoading = false;
        });
        return;
      }

      // Convert parsed rows to PurchaseOrderItem objects
      final items = parsedRows.map((rowData) => PurchaseOrderItem(
        poDate: DateTime.parse(rowData['po_date'] as String),
        poNumber: rowData['po_number'] as String,
        vendorName: rowData['vendor_name'] as String,
        projectName: rowData['project_name'] as String,
        productName: rowData['product_name'] as String,
        productQty: rowData['product_qty'] as int,
        productQtyUnit: rowData['product_qty_unit'] as String,
        productUnitPrice: rowData['product_unit_price'] as double,
        productDiscountPct: rowData['product_discount_pct'] as double,
        productFinalPrice: rowData['product_final_price'] as double,
        category: rowData['category'] as String?,
        createdAt: DateTime.now(),
      )).toList();

      // Insert items in batches of 100
      const batchSize = 100;
      int totalInserted = 0;
      for (int i = 0; i < items.length; i += batchSize) {
        final end = (i + batchSize < items.length) ? i + batchSize : items.length;
        final batch = items.sublist(i, end);
        final batchInserted = await _dbHelper.insertItems(batch);
        totalInserted += batchInserted;
      }

      final totalItems = await _dbHelper.countItems();

      setState(() {
        totalItemsInDatabase = totalItems;
        filteredData = []; // Start with empty filtered data
        isLoading = false;
      });

      _showSnackBar(
        'Loaded sheet: ${loadedSheetName ?? 'unknown'} • Processed: ${parsedRows.length} items • Saved: $totalInserted items',
      );
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      _showSnackBar('Error loading Excel file: $e', type: SnackBarType.error);
    }
  }

  void performSearch() async {
    final query = searchController.text.trim();
    final result = query.isEmpty
        ? [].cast<PurchaseOrderItem>()
        : await _dbHelper.searchItems(query.toLowerCase());

    setState(() {
      filteredData = result;
      selectedItem = null;
    });
  }

  Future<void> saveSelectedItem() async {
    if (selectedItem == null) {
      _showSnackBar('Please select an item to save', type: SnackBarType.warning);
      return;
    }

    try {
      final added = MemoryStore.addItem(selectedItem!);

      if (!added) {
        _showSnackBar('Item already exists in saved list', type: SnackBarType.warning);
        return;
      }

      if (mounted) {
        _showSnackBar('Saved: ${selectedItem!.productName}');
        setState(() {
          selectedItem = null;
        });
      }
    } catch (e) {
      _showSnackBar('Error saving item: $e', type: SnackBarType.error);
    }
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _checkDatabaseItems();
  }

  Future<void> _checkDatabaseItems() async {
    final totalItems = await _dbHelper.countItems();
    if (mounted) {
      setState(() {
        totalItemsInDatabase = totalItems;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              ElevatedButton.icon(
                onPressed: pickExcelFile,
                icon: const Icon(Icons.folder_open),
                label: const Text('Select Excel File'),
              ),
              const SizedBox(width: 16.0),
              ElevatedButton.icon(
                onPressed: _resetDatabase,
                icon: const Icon(Icons.delete_forever),
                label: const Text('Reset Data'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
        if (isLoading)
          const Expanded(
            child: Center(
              child: CircularProgressIndicator(),
            ),
          )
        else if (totalItemsInDatabase > 0) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: searchController,
                    decoration: InputDecoration(
                      hintText: 'Search by product, vendor, or PO number...',
                      prefixIcon: const Icon(Icons.search),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16.0,
                        vertical: 12.0,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                    ),
                    onSubmitted: (_) => performSearch(),
                  ),
                ),
                const SizedBox(width: 8.0),
                ElevatedButton(
                  onPressed: performSearch,
                  child: const Text('Search'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12.0),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: ElevatedButton.icon(
              onPressed: saveSelectedItem,
              icon: const Icon(Icons.save),
              label: const Text('Save Selected Item'),
            ),
          ),
          const SizedBox(height: 12.0),
          Expanded(
            child: Column(
              children: [
                if (filteredData.isEmpty)
                  Expanded(
                    child: Center(
                      child: Text(
                        totalItemsInDatabase == 0
                            ? 'No items loaded'
                            : 'Enter search term and click Search to view items',
                        style: Theme.of(context).textTheme.headlineSmall,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: ListView.builder(
                      itemCount: filteredData.length,
                      itemBuilder: (context, index) {
                        PurchaseOrderItem item = filteredData[index];
                        bool isSelected = selectedItem == item;
                        return PurchaseOrderItemCard(
                          item: item,
                          isSelected: isSelected,
                          cardStyle: CardStyle.styled,
                          priceFormatter: RupiahPriceFormatter(),
                          onTap: () {
                            setState(() {
                              selectedItem = isSelected ? null : item;
                            });
                          },
                        );
                      },
                    ),
                  ),
                // Status bar
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Available: $totalItemsInDatabase items',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      Text(
                        filteredData.isEmpty ? 'No matching results' : 'Results: ${filteredData.length} items',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ] else
          Expanded(
            child: Center(
              child: Text(
                'Select an Excel file to begin',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
          ),
      ],
    );
  }
}

/// Parse Excel file in isolate and return first-sheet rows plus sheet name
Map<String, dynamic> _parseExcelInIsolate(
  Uint8List bytes,
) {
  final excelFile = excel.Excel.decodeBytes(bytes);
  final List<Map<String, dynamic>> rows = [];

  // Process only the first sheet
  final firstSheetName = excelFile.tables.keys.isEmpty ? null : excelFile.tables.keys.first;
  if (firstSheetName != null) {
    var sheet = excelFile.tables[firstSheetName];
    if (sheet != null) {
      int rowIndex = 0;
      for (var row in sheet.rows) {
        // Skip header row
        if (rowIndex == 0) {
          rowIndex++;
          continue;
        }
        rowIndex++;

        try {
          if (row.length >= 10) {
            final poDate = row[0]?.value?.toString() ?? '';
            final poNumber = row[1]?.value?.toString() ?? '';
            final vendor = row[2]?.value?.toString() ?? '';
            final project = row[4]?.value?.toString() ?? '';
            final product = row[5]?.value?.toString() ?? '';
            final qtyStr = row[6]?.value?.toString() ?? '0';
            final unit = row[7]?.value?.toString() ?? '';
            final priceStr = row[8]?.value?.toString() ?? '0';
            final discountStr = row[9]?.value?.toString() ?? '0';
            final category = row[10]?.value?.toString() ?? ''; // PLACEHOLDER
            final finalPriceStr = row[11]?.value?.toString() ?? '0';

            if (poDate.isEmpty || vendor.isEmpty || product.isEmpty) {
              continue;
            }

            final rowData = {
              'po_date': _formatDateForDatabase(_parseExcelDateStatic(poDate)),
              'po_number': poNumber,
              'vendor_name': vendor,
              'project_name': project,
              'product_name': product,
              'product_qty': int.tryParse(qtyStr) ?? 0,
              'product_qty_unit': unit,
              'product_unit_price': double.tryParse(priceStr) ?? 0.0,
              'product_discount_pct': double.tryParse(discountStr) ?? 0.0,
              'product_final_price': double.tryParse(finalPriceStr) ?? 0.0,
              'category': category,
            };

            rows.add(rowData);
          }
        } catch (e) {
          continue;
        }
      }
    }
  }

  return {
    'sheetName': firstSheetName,
    'rows': rows,
  };
}

/// Helper to format DateTime for database storage
String _formatDateForDatabase(DateTime? date) {
  if (date == null) return DateTime.now().toIso8601String();
  return date.toIso8601String();
}

/// Static method for date parsing in isolate context
DateTime? _parseExcelDateStatic(dynamic value) {
  if (value == null) return null;

  if (value is DateTime) return value;

  if (value is String) {
    if (value.isEmpty) return null;

    DateTime? parsed = DateTime.tryParse(value);
    if (parsed != null) return parsed;

    try {
      List<String> parts = value.split('/');
      if (parts.length == 3) {
        int month = int.parse(parts[0]);
        int day = int.parse(parts[1]);
        int year = int.parse(parts[2]);
        return DateTime(year, month, day);
      }
    } catch (e) {
      return null;
    }
  }

  if (value is num) {
    try {
      int days = value.toInt();
      if (days >= 1 && days <= 2958465) {
        final excelEpoch = DateTime(1899, 12, 30);
        return excelEpoch.add(Duration(days: days));
      }
    } catch (e) {
      return null;
    }
  }

  return null;
}