class WastageEntry {
  String id;
  String productId;
  String productName;
  double quantity;
  String reason;
  String date; // ISO date
  String? batchId;
  String notes;
  String createdAt; // ISO datetime

  WastageEntry({
    required this.id,
    required this.productId,
    required this.productName,
    required this.quantity,
    this.reason = '',
    required this.date,
    this.batchId,
    this.notes = '',
    required this.createdAt,
  });

  // Convert a Map into a WastageEntry object
  factory WastageEntry.fromMap(Map<String, dynamic> map) {
    return WastageEntry(
      id: map['id'] ?? '',
      productId: map['product_id'] ?? '',
      productName: map['product_name'] ?? '',
      quantity: (map['quantity'] as num?)?.toDouble() ?? 0.0,
      reason: map['reason'] ?? '',
      date: map['date'] ?? '',
      batchId: map['batch_id'] as String?,
      notes: map['notes'] ?? '',
      createdAt: map['created_at'] ?? '',
    );
  }

  // Convert a WastageEntry object into a Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'product_id': productId,
      'product_name': productName,
      'quantity': quantity,
      'reason': reason,
      'date': date,
      'batch_id': batchId,
      'notes': notes,
      'created_at': createdAt,
    };
  }
}
