class PurchaseOrderItem {
  String id;
  String poId;
  String productId;
  String productName;
  double quantity;
  double unitCost;
  double receivedQty;
  String notes;

  PurchaseOrderItem({
    required this.id,
    required this.poId,
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitCost,
    this.receivedQty = 0,
    this.notes = '',
  });

  // Convert a Map into a PurchaseOrderItem object
  factory PurchaseOrderItem.fromMap(Map<String, dynamic> map) {
    return PurchaseOrderItem(
      id: map['id'] ?? '',
      poId: map['po_id'] ?? '',
      productId: map['product_id'] ?? '',
      productName: map['product_name'] ?? '',
      quantity: (map['quantity'] as num?)?.toDouble() ?? 0.0,
      unitCost: (map['unit_cost'] as num?)?.toDouble() ?? 0.0,
      receivedQty: (map['received_qty'] as num?)?.toDouble() ?? 0.0,
      notes: map['notes'] ?? '',
    );
  }

  // Convert a PurchaseOrderItem object into a Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'po_id': poId,
      'product_id': productId,
      'product_name': productName,
      'quantity': quantity,
      'unit_cost': unitCost,
      'received_qty': receivedQty,
      'notes': notes,
    };
  }
}

class PurchaseOrder {
  String id;
  String supplierId;
  String supplierName;
  String date;
  String? expectedDate;
  String status; // 'draft' / 'ordered' / 'received' / 'partial' / 'cancelled'
  String notes;
  double totalAmount;
  String createdAt;
  List<PurchaseOrderItem> items;

  PurchaseOrder({
    required this.id,
    required this.supplierId,
    required this.supplierName,
    required this.date,
    this.expectedDate,
    required this.status,
    this.notes = '',
    required this.totalAmount,
    required this.createdAt,
    this.items = const [],
  });

  // Convert a Map into a PurchaseOrder object
  factory PurchaseOrder.fromMap(Map<String, dynamic> map) {
    return PurchaseOrder(
      id: map['id'] ?? '',
      supplierId: map['supplier_id'] ?? '',
      supplierName: map['supplier_name'] ?? '',
      date: map['date'] ?? '',
      expectedDate: map['expected_date'] as String?,
      status: map['status'] ?? 'draft',
      notes: map['notes'] ?? '',
      totalAmount: (map['total_amount'] as num?)?.toDouble() ?? 0.0,
      createdAt: map['created_at'] ?? '',
      items: (map['items'] as List<dynamic>?)
              ?.map((e) => PurchaseOrderItem.fromMap(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  // Convert a PurchaseOrder object into a Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'supplier_id': supplierId,
      'supplier_name': supplierName,
      'date': date,
      'expected_date': expectedDate,
      'status': status,
      'notes': notes,
      'total_amount': totalAmount,
      'created_at': createdAt,
      'items': items.map((e) => e.toMap()).toList(),
    };
  }
}
