import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart' hide Border;
import 'dart:io';
import '../models/item_model.dart';
import '../database/database_helper.dart';
import 'package:intl/intl.dart';

class ViewerTab extends StatefulWidget {
  const ViewerTab({super.key});

  @override
  State<ViewerTab> createState() => _ViewerTabState();
}

class _ViewerTabState extends State<ViewerTab> {
  File? selectedFile;
  String? selectedFileName;
  List<PurchaseOrderItem> excelData = [];
  final TextEditingController searchController = TextEditingController();
  List<PurchaseOrderItem> filteredData = [];
  PurchaseOrderItem? selectedItem;
  final DatabaseHelper _dbHelper = DatabaseHelper();
  bool isLoading = false;

  late final NumberFormat _priceFormatter = NumberFormat('###,###.##', 'id_ID');

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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking file: $e')),
        );
      }
    }
  }

  /// Parse Excel date value to DateTime
  /// Excel stores dates as numbers (days since 1900-01-01) or DateTime objects
  DateTime? _parseExcelDate(dynamic value) {
    if (value == null) return null;
    
    // If already a DateTime, return it
    if (value is DateTime) return value;
    
    // If it's a string, try to parse it
    if (value is String) {
      if (value.isEmpty) return null;
      
      // Try ISO 8601 format first
      DateTime? parsed = DateTime.tryParse(value);
      if (parsed != null) return parsed;
      
      // Try common date formats
      try {
        // Try MM/dd/yyyy format
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
    
    // If it's a number (Excel serial date)
    if (value is num) {
      try {
        // Excel epoch: January 1, 1900 (with 1900 leap year bug)
        // Excel serial 1 = Jan 1, 1900
        // Excel serial 44562 = Jan 1, 2022 (approximately)
        int days = value.toInt();
        if (days >= 1 && days <= 2958465) { // Valid Excel date range
          final excelEpoch = DateTime(1899, 12, 30); // Adjusted for Excel epoch
          return excelEpoch.add(Duration(days: days));
        }
      } catch (e) {
        return null;
      }
    }
    
    return null;
  }

  Future<void> loadExcelData() async {
    try {
      if (selectedFile == null) return;

      var bytes = selectedFile!.readAsBytesSync();
      var excel = Excel.decodeBytes(bytes);

      List<PurchaseOrderItem> allData = [];

      for (var table in excel.tables.keys) {
        var sheet = excel.tables[table];
        if (sheet != null) {
          int rowIndex = 0;
          for (var row in sheet.rows) {
            // Skip header row (first row)
            if (rowIndex == 0) {
              rowIndex++;
              continue;
            }
            rowIndex++;
            
            try {
              // Expected: PO Date, PO Number, Vendor, Project, Product, Qty, Unit, Unit Price, Discount %, Final Price
              if (row.length >= 10) {
                final poDate = row[0]?.value?.toString() ?? '';
                final poNumber = row[1]?.value?.toString() ?? '';
                final vendor = row[2]?.value?.toString() ?? '';
                // final poCust = row[3]
                final project = row[4]?.value?.toString() ?? '';
                final product = row[5]?.value?.toString() ?? '';
                final qtyStr = row[6]?.value?.toString() ?? '0';
                final unit = row[7]?.value?.toString() ?? '';
                final priceStr = row[8]?.value?.toString() ?? '0';
                final discountStr = row[9]?.value?.toString() ?? '0';
                // row[10] ??
                final finalPriceStr = row[11]?.value?.toString() ?? '0';

                // Skip invalid entries
                if (poDate.isEmpty || vendor.isEmpty || product.isEmpty) {
                  continue;
                }

                final item = PurchaseOrderItem(
                  poDate: _parseExcelDate(poDate),
                  poNumber: poNumber,
                  vendorName: vendor,
                  projectName: project,
                  productName: product,
                  productQty: int.tryParse(qtyStr) ?? 0,
                  productQtyUnit: unit,
                  productUnitPrice: double.tryParse(priceStr) ?? 0.0,
                  productDiscountPct: double.tryParse(discountStr) ?? 0.0,
                  productFinalPrice: double.tryParse(finalPriceStr) ?? 0.0,
                  createdAt: DateTime.now(),
                );

                allData.add(item);
              }
            } catch (e) {
              // Skip invalid rows
              continue;
            }
          }
        }
      }

      setState(() {
        excelData = allData;
        filteredData = excelData;
        isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading Excel file: $e')),
        );
      }
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an item to save')),
      );
      return;
    }

    try {
      await _dbHelper.insertItem(selectedItem!);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Saved: ${selectedItem!.productName}'),
          ),
        );
        setState(() {
          selectedItem = null;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving item: $e')),
        );
      }
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
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      selectedItem = isSelected ? null : item;
                    });
                  },
                  child: Container(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 4.0,
                    ),
                    padding: const EdgeInsets.all(12.0),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Colors.blue.withAlpha(77) // 0.3 * 255
                          : Colors.grey.withAlpha(26), // 0.1 * 255
                      border: Border.all(
                        color: isSelected ? Colors.blue : Colors.grey.shade300,
                        width: isSelected ? 2 : 1,
                      ),
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${item.productName} | PO: ${item.poNumber}',
                          style: Theme.of(context).textTheme.titleSmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4.0),
                        Text(
                          'Vendor: ${item.vendorName} | Qty: ${item.productQty} ${item.productQtyUnit}',
                          style: Theme.of(context).textTheme.bodySmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4.0),
                        Text(
                          'Unit Final Price: Rp${_priceFormatter.format(item.productFinalPrice)}',
                          style: Theme.of(context).textTheme.bodySmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
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
