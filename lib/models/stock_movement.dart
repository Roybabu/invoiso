class StockMovement {
  String id;
  String productId;
  String productName;
  String movementType; // 'purchase' / 'sale' / 'adjustment' / 'wastage' / 'return' / 'opening' / 'manual'
  double quantity; // positive = stock in, negative = stock out
  int beforeStock;
  int afterStock;
  String? referenceId; // PO id / invoice id / etc.
  String? referenceType; // 'purchase_order' / 'invoice' / 'manual' / 'wastage'
  String notes;
  String date; // ISO datetime

  StockMovement({
    required this.id,
    required this.productId,
    required this.productName,
    required this.movementType,
    required this.quantity,
    required this.beforeStock,
    required this.afterStock,
    this.referenceId,
    this.referenceType,
    this.notes = '',
    required this.date,
  });

  // Convert a Map into a StockMovement object
  factory StockMovement.fromMap(Map<String, dynamic> map) {
    return StockMovement(
      id: map['id'] ?? '',
      productId: map['product_id'] ?? '',
      productName: map['product_name'] ?? '',
      movementType: map['movement_type'] ?? '',
      quantity: (map['quantity'] as num?)?.toDouble() ?? 0.0,
      beforeStock: map['before_stock'] ?? 0,
      afterStock: map['after_stock'] ?? 0,
      referenceId: map['reference_id'] as String?,
      referenceType: map['reference_type'] as String?,
      notes: map['notes'] ?? '',
      date: map['date'] ?? '',
    );
  }

  // Convert a StockMovement object into a Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'product_id': productId,
      'product_name': productName,
      'movement_type': movementType,
      'quantity': quantity,
      'before_stock': beforeStock,
      'after_stock': afterStock,
      'reference_id': referenceId,
      'reference_type': referenceType,
      'notes': notes,
      'date': date,
    };
  }
}
