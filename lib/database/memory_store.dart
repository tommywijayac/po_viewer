import '../models/item_model.dart';

class MemoryStore {
  static final List<PurchaseOrderItem> savedItems = [];

  /// Adds item if not existing (based on PurchaseOrderItem equality), returns true when added
  static bool addItem(PurchaseOrderItem item) {
    if (savedItems.contains(item)) {
      return false;
    }
    savedItems.add(item);
    return true;
  }

  static void removeItem(PurchaseOrderItem item) {
    savedItems.remove(item);
  }

  static void clear() {
    savedItems.clear();
  }
}
