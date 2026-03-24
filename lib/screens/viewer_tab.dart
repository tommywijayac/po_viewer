import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart' as excel;

import '../models/item_model.dart';
import '../database/database_helper.dart';
import '../widgets/purchase_order_item_card.dart';

class ViewerTab extends StatefulWidget {
  const ViewerTab({super.key});

  @override
  State<ViewerTab> createState() => _ViewerTabState();
}

class _ViewerTabState extends State<ViewerTab> {
  File? selectedFile;
  String? selectedFileName;
  String? loadedSheetName;
  List<PurchaseOrderItem> excelData = [];
  final TextEditingController searchController = TextEditingController();
  List<PurchaseOrderItem> filteredData = [];
  PurchaseOrderItem? selectedItem;
  final DatabaseHelper _dbHelper = DatabaseHelper();
  bool isLoading = false;

  void _showSnackBar(String message) {
    if (mounted) {
      // Use this.context to ensure we're getting the State's context, not the excel Context
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
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
          selectedFileName = result.files.single.name;
          selectedItem = null;
          searchController.clear();
          isLoading = true;
        });
        await loadExcelData();
      }
    } catch (e) {
      _showSnackBar('Error picking file: $e');
    }
  }

  Future<void> loadExcelData() async {
    try {
      if (selectedFile == null) return;

      final fileBytes = selectedFile!.readAsBytesSync();
      final result = await compute(_parseExcelInIsolate, fileBytes);

      final parsedRows = result['rows'] as List<Map<String, dynamic>>;
      loadedSheetName = result['sheetName'] as String?;

      if (parsedRows.isEmpty) {
        _showSnackBar('No data found in first sheet');
        setState(() {
          isLoading = false;
        });
        return;
      }

      // Insert all rows into database on main thread
      int insertedCount = 0;
      for (var rowData in parsedRows) {
        await _dbHelper.insertItem(
          PurchaseOrderItem(
            poDate: DateTime.tryParse(rowData['po_date'] as String),
            poNumber: rowData['po_number'] as String,
            vendorName: rowData['vendor_name'] as String,
            projectName: rowData['project_name'] as String,
            productName: rowData['product_name'] as String,
            productQty: rowData['product_qty'] as int,
            productQtyUnit: rowData['product_qty_unit'] as String,
            productUnitPrice: rowData['product_unit_price'] as double,
            productDiscountPct: rowData['product_discount_pct'] as double,
            productFinalPrice: rowData['product_final_price'] as double,
            createdAt: DateTime.now(),
          ),
        );
        insertedCount++;
      }

      // Load all items from database for display
      final displayItems = await _dbHelper.getAllItems();

      setState(() {
        excelData = displayItems;
        filteredData = excelData;
        isLoading = false;
      });

      _showSnackBar(
        'Loaded sheet: ${loadedSheetName ?? 'unknown'} • Processed: ${parsedRows.length} items • Saved: $insertedCount items',
      );
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      _showSnackBar('Error loading Excel file: $e');
    }
  }

  void filterData(String query) {
    setState(() {
      if (query.isEmpty) {
        filteredData = excelData;
        selectedItem = null;
      } else {
        filteredData = excelData
            .where((item) =>
                item.productName.toLowerCase().contains(query.toLowerCase()) ||
                item.vendorName.toLowerCase().contains(query.toLowerCase()) ||
                item.poNumber.toLowerCase().contains(query.toLowerCase()))
            .toList();
        selectedItem = null;
      }
    });
  }

  Future<void> saveSelectedItem() async {
    if (selectedItem == null || selectedFileName == null) {
      _showSnackBar('Please select an item to save');
      return;
    }

    try {
      await _dbHelper.insertItem(selectedItem!);

      if (mounted) {
        _showSnackBar('Saved: ${selectedItem!.productName}');
        setState(() {
          selectedItem = null;
        });
      }
    } catch (e) {
      _showSnackBar('Error saving item: $e');
    }
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: ElevatedButton.icon(
            onPressed: pickExcelFile,
            icon: const Icon(Icons.folder_open),
            label: const Text('Select Excel File'),
          ),
        ),
        if (isLoading)
          const Expanded(
            child: Center(
              child: CircularProgressIndicator(),
            ),
          )
        else if (selectedFile != null) ...[
          if (loadedSheetName != null) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  const Icon(Icons.sticky_note_2, size: 18),
                  const SizedBox(width: 8),
                  Text('Loaded sheet: $loadedSheetName', style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
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
              onChanged: filterData,
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
            child: ListView.builder(
              itemCount: filteredData.length,
              itemBuilder: (context, index) {
                PurchaseOrderItem item = filteredData[index];
                bool isSelected = selectedItem == item;
                return PurchaseOrderItemCard(
                  item: item,
                  isSelected: isSelected,
                  cardStyle: CardStyle.compact,
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