import '../models/item_model.dart';

class MemoryStore {
  static final List<PurchaseOrderItem> savedItems = [];

  static void addItem(PurchaseOrderItem item) {
    savedItems.add(item);
  }

  static void removeItem(PurchaseOrderItem item) {
    savedItems.remove(item);
  }

  static void clear() {
    savedItems.clear();
  }
}
