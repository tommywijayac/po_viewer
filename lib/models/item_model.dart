class PurchaseOrderItem {
  final int? id;
  final DateTime? poDate;
  final String poNumber;
  final String vendorName;
  final String projectName;
  final String productName;
  final int productQty;
  final String productQtyUnit;
  final double productUnitPrice;
  final double productDiscountPct;
  final double productFinalPrice;
  final DateTime createdAt;

  PurchaseOrderItem({
    this.id,
    this.poDate,
    required this.poNumber,
    required this.vendorName,
    required this.projectName,
    required this.productName,
    required this.productQty,
    required this.productQtyUnit,
    required this.productUnitPrice,
    required this.productDiscountPct,
    required this.productFinalPrice,
    required this.createdAt,
  });

  /// Convert PurchaseOrderItem to Map for database insertion
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'po_date': poDate?.toIso8601String(),
      'po_number': poNumber,
      'vendor_name': vendorName,
      'project_name': projectName,
      'product_name': productName,
      'product_qty': productQty,
      'product_qty_unit': productQtyUnit,
      'product_unit_price': productUnitPrice,
      'product_discount_pct': productDiscountPct,
      'product_final_price': productFinalPrice,
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// Create PurchaseOrderItem from database Map
  factory PurchaseOrderItem.fromMap(Map<String, dynamic> map) {
    return PurchaseOrderItem(
      id: map['id'] as int?,
      poDate: map['po_date'] != null ? DateTime.parse(map['po_date'] as String) : null,
      poNumber: map['po_number'] as String,
      vendorName: map['vendor_name'] as String,
      projectName: map['project_name'] as String,
      productName: map['product_name'] as String,
      productQty: map['product_qty'] as int,
      productQtyUnit: map['product_qty_unit'] as String,
      productUnitPrice: (map['product_unit_price'] as num).toDouble(),
      productDiscountPct: (map['product_discount_pct'] as num).toDouble(),
      productFinalPrice: (map['product_final_price'] as num).toDouble(),
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PurchaseOrderItem &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          poNumber == other.poNumber;

  @override
  int get hashCode => id.hashCode ^ poNumber.hashCode;
}
