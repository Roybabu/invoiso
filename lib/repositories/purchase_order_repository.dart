import 'package:invoiso/models/purchase_order.dart';

abstract class PurchaseOrderRepository {
  Future<PurchaseOrder> insertPurchaseOrder(PurchaseOrder po);
  Future<void> updatePurchaseOrder(PurchaseOrder po);
  Future<void> deletePurchaseOrder(String id);
  Future<PurchaseOrder?> getPurchaseOrderById(String id);
  Future<List<PurchaseOrder>> getPurchaseOrdersPage({
    required int offset,
    required int limit,
    String query,
    String? status,
    String? supplierId,
  });
  Future<int> getPurchaseOrderCount({
    String query,
    String? status,
    String? supplierId,
  });
  Future<void> receivePurchaseOrder(String poId);
}
