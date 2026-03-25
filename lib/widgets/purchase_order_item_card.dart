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
    switch (cardStyle) {
      case CardStyle.compact:
        return _buildCompactCard(context);
      case CardStyle.detailed:
        return _buildDetailedCard(context);
      case CardStyle.styled:
        return _buildStyledCard(context);
    }
  }

  /// Styled card matching the provided HTML design
  Widget _buildStyledCard(BuildContext context) {
    final formattedPoDate = DateFormat('dd MMM yyyy').format(item.poDate);
    final formattedUnitPrice = _formatPrice(item.productUnitPrice);
    final hasDeleteButton = onDeletePressed != null;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.all(2.0),
        padding: EdgeInsets.fromLTRB(14, 12, 14, hasDeleteButton ? 44 : 12),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.blue.withAlpha(77) // 0.3 * 255
              : Colors.white.withAlpha(26), // 0.1 * 255
          border: Border.all(
            color: isSelected ? Colors.blue : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8.0),
        ),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.productName,
                  style: const TextStyle(fontSize: 20.0, fontWeight: FontWeight.w600),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      formattedUnitPrice,
                      style: const TextStyle(
                        fontSize: 20.0,
                        color: Colors.red,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          '| PO Date',
                          style: TextStyle(
                            fontSize: 15.0,
                            color: Colors.black54,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          formattedPoDate,
                          style: const TextStyle(
                            fontSize: 20.0,
                            color: Colors.black87,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Qty: ${item.productQty} ${item.productQtyUnit}  |  PO: ${item.poNumber}',
                  style: const TextStyle(fontSize: 12.0, color: Colors.black54),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _buildBadge(context, 'Vendor', item.vendorName, const Color(0xFFE1F5EE), const Color(0xFF085041)),
                    if (item.category != null && item.category!.isNotEmpty)
                      _buildBadge(context, 'Category', item.category!, const Color(0xFFFFF7E6), const Color(0xFF995A00)),
                  ],
                ),
              ],
            ),
            if (hasDeleteButton)
              Positioned(
                right: 0,
                bottom: 0,
                child: IconButton(
                  onPressed: onDeletePressed,
                  icon: const Icon(Icons.delete),
                  tooltip: 'Delete',
                  visualDensity: VisualDensity.compact,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBadge(BuildContext context, String label, String value, Color bgColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$label ', style: const TextStyle(fontSize: 13.0, fontWeight: FontWeight.bold, letterSpacing: 0.4, color: Colors.black54)),
          Flexible(
            child: Text(value, style: TextStyle(fontSize: 15.0, color: textColor, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis)
          ),
        ],
      ),
    );
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
              'Price: ${_formatPrice(item.productUnitPrice)}',
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
            const SizedBox(height: 4.0),
            if (item.productQty > 1) ...[
              Text(
                'Qty: ${item.productQty} ${item.productQtyUnit}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ] else ...[
              Text(
                'Qty: ${item.productQty} ${item.productQtyUnit} | Unit Price: ${_formatPrice(item.productUnitPrice)}',
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

  /// Format PO date to display only the date portion
  String _formatPoDate() {
    final dateFormat = DateFormat('dd MMM yyyy');
    return dateFormat.format(item.poDate);
  }
}

/// Enum for different card display styles
enum CardStyle {
  compact, // Simple container style for viewer tab
  detailed, // Card with ListTile style for saved tab
  styled, // New styled card matching inline design
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
  String format(double price) => 'Rp ${_formatter.format(price)}';
}
