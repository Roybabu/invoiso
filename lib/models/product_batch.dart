class ProductBatch {
  String id;
  String productId;
  String batchNumber;
  String? expiryDate; // ISO date
  String? manufactureDate;
  double quantity;
  double remainingQty;
  double costPerUnit;
  String? supplierId;
  String supplierName;
  String receivedDate; // ISO date
  String notes;

  ProductBatch({
    required this.id,
    required this.productId,
    required this.batchNumber,
    this.expiryDate,
    this.manufactureDate,
    required this.quantity,
    required this.remainingQty,
    this.costPerUnit = 0,
    this.supplierId,
    this.supplierName = '',
    required this.receivedDate,
    this.notes = '',
  });

  // Convert a Map into a ProductBatch object
  factory ProductBatch.fromMap(Map<String, dynamic> map) {
    return ProductBatch(
      id: map['id'] ?? '',
      productId: map['product_id'] ?? '',
      batchNumber: map['batch_number'] ?? '',
      expiryDate: map['expiry_date'] as String?,
      manufactureDate: map['manufacture_date'] as String?,
      quantity: (map['quantity'] as num?)?.toDouble() ?? 0.0,
      remainingQty: (map['remaining_qty'] as num?)?.toDouble() ?? 0.0,
      costPerUnit: (map['cost_per_unit'] as num?)?.toDouble() ?? 0.0,
      supplierId: map['supplier_id'] as String?,
      supplierName: map['supplier_name'] ?? '',
      receivedDate: map['received_date'] ?? '',
      notes: map['notes'] ?? '',
    );
  }

  // Convert a ProductBatch object into a Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'product_id': productId,
      'batch_number': batchNumber,
      'expiry_date': expiryDate,
      'manufacture_date': manufactureDate,
      'quantity': quantity,
      'remaining_qty': remainingQty,
      'cost_per_unit': costPerUnit,
      'supplier_id': supplierId,
      'supplier_name': supplierName,
      'received_date': receivedDate,
      'notes': notes,
    };
  }
}
