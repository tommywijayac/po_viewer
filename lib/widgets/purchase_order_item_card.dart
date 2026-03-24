import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/item_model.dart';

/// Reusable widget for displaying purchase order items
/// Can be used in both viewer and saved tabs with different display styles
class PurchaseOrderItemCard extends StatelessWidget {
  final PurchaseOrderItem item;
  final VoidCallback onTap;
  final VoidCallback? onDeletePressed;
  final bool isSelected;
  final PriceFormatter? priceFormatter;
  final CardStyle cardStyle;

  const PurchaseOrderItemCard({
    super.key,
    required this.item,
    required this.onTap,
    this.onDeletePressed,
    this.isSelected = false,
    this.priceFormatter,
    this.cardStyle = CardStyle.compact,
  });

  @override
  Widget build(BuildContext context) {
    return cardStyle == CardStyle.compact
        ? _buildCompactCard(context)
        : _buildDetailedCard(context);
  }

  /// Compact card style used in viewer tab
  Widget _buildCompactCard(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
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
              '${item.productName} | PO: ${item.poNumber} | ${_formatPoDate()}',
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
              _getPriceDisplay(),
              style: Theme.of(context).textTheme.bodySmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  /// Detailed card style used in saved tab
  Widget _buildDetailedCard(BuildContext context) {
    final formattedDate =
        DateFormat('MMM dd, yyyy HH:mm').format(item.createdAt);

    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: 16.0,
        vertical: 8.0,
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12.0),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${item.productName} | PO: ${item.poNumber} | ${_formatPoDate()}',
              style: Theme.of(context).textTheme.titleSmall,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8.0),
            Text(
              'Vendor: ${item.vendorName}',
              style: Theme.of(context).textTheme.bodySmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              'Project: ${item.projectName}',
              style: Theme.of(context).textTheme.bodySmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4.0),
            if (item.productQty > 1) ...[
              Text(
                'Qty: ${item.productQty} ${item.productQtyUnit}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              Text(
                'Total Price: ${_formatPrice(item.productFinalPrice)} (with ${item.productDiscountPct}% discount)',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ] else ...[
              Text(
                'Qty: ${item.productQty} ${item.productQtyUnit} | Unit Price: ${_formatPrice(item.productUnitPrice)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              Text(
                'Discount: ${item.productDiscountPct}%',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 4.0),
            Text(
              'Saved: $formattedDate',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Colors.grey),
            ),
          ],
        ),
        trailing: onDeletePressed != null
            ? IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: onDeletePressed,
              )
            : null,
      ),
    );
  }

  /// Format price using provided formatter or default USD format
  String _formatPrice(double price) {
    if (priceFormatter != null) {
      return priceFormatter!.format(price);
    }
    return '\$${price.toStringAsFixed(2)}';
  }

  /// Get conditional price display based on quantity
  /// If qty > 1: shows total price with discount
  /// If qty = 1: shows unit price
  String _getPriceDisplay() {
    if (item.productQty > 1) {
      final discountText = item.productDiscountPct > 0
          ? ' (${item.productDiscountPct}% discount)'
          : '';
      return 'Unit Price: ${_formatPrice(item.productUnitPrice)} | Total Price: ${_formatPrice(item.productFinalPrice)}$discountText';
    } else {
      return 'Unit Price: ${_formatPrice(item.productUnitPrice)}';
    }
  }

  /// Format PO date to display only the date portion
  String _formatPoDate() {
    if (item.poDate == null) return 'N/A';
    final dateFormat = DateFormat('dd MMM yyyy');
    return dateFormat.format(item.poDate!);
  }
}

/// Enum for different card display styles
enum CardStyle {
  compact, // Simple container style for viewer tab
  detailed, // Card with ListTile style for saved tab
}

/// Interface for custom price formatting
abstract class PriceFormatter {
  String format(double price);
}

/// Default USD price formatter
class USDPriceFormatter implements PriceFormatter {
  @override
  String format(double price) => '\$${price.toStringAsFixed(2)}';
}

/// Custom formatter for Indonesian Rupiah (used in viewer tab)
class RupiahPriceFormatter implements PriceFormatter {
  final NumberFormat _formatter = NumberFormat('###,###.##', 'id_ID');

  @override
  String format(double price) => 'Rp${_formatter.format(price)}';
}
