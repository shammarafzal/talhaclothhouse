import 'package:cloud_firestore/cloud_firestore.dart';

class InventoryService {
  static final _db = FirebaseFirestore.instance;

  /// ------------------------------------------------------------
  /// Create inventory item (call once when product is created)
  /// ------------------------------------------------------------
  static Future<void> createInventoryIfNotExists({
    required String productId,
    required String productName,
    String unit = "pcs",
  }) async {
    final ref = _db.collection("inventory").doc(productId);

    final snap = await ref.get();
    if (snap.exists) return;

    await ref.set({
      'productId': productId,
      'productName': productName,
      'unit': unit,
      'currentStock': 0,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// ------------------------------------------------------------
  /// Increase stock (Purchase Invoice)
  /// ------------------------------------------------------------
  static Future<void> increaseStock({
    required String productId,
    required int qty,
  }) async {
    final ref = _db.collection("inventory").doc(productId);

    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) {
        throw Exception("Inventory not found for $productId");
      }

      final current = (snap['currentStock'] ?? 0) as int;

      tx.update(ref, {
        'currentStock': current + qty,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  /// ------------------------------------------------------------
  /// Decrease stock (Sales Invoice)
  /// ------------------------------------------------------------
  static Future<void> decreaseStock({
    required String productId,
    required double qty,
  }) async {
    final ref = _db.collection("inventory").doc(productId);

    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) {
        throw Exception("Inventory not found for $productId");
      }

      final current = (snap['currentStock'] ?? 0) as int;

      if (current < qty) {
        throw Exception("Insufficient stock");
      }

      tx.update(ref, {
        'currentStock': current - qty,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }
}
