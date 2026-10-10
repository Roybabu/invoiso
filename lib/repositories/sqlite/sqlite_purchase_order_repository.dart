import 'package:invoiso/database/purchase_order_service.dart';
import 'package:invoiso/models/purchase_order.dart';
import 'package:invoiso/repositories/purchase_order_repository.dart';

class SqlitePurchaseOrderRepository implements PurchaseOrderRepository {
  @override
  Future<PurchaseOrder> insertPurchaseOrder(PurchaseOrder po) =>
      PurchaseOrderService.insertPurchaseOrder(po);

  @override
  Future<void> updatePurchaseOrder(PurchaseOrder po) =>
      PurchaseOrderService.updatePurchaseOrder(po);

  @override
  Future<void> deletePurchaseOrder(String id) =>
      PurchaseOrderService.deletePurchaseOrder(id);

  @override
  Future<PurchaseOrder?> getPurchaseOrderById(String id) =>
      PurchaseOrderService.getPurchaseOrderById(id);

  @override
  Future<List<PurchaseOrder>> getPurchaseOrdersPage({
    required int offset,
    required int limit,
    String query = '',
    String? status,
    String? supplierId,
  }) =>
      PurchaseOrderService.getPurchaseOrdersPage(
        offset: offset,
        limit: limit,
        query: query,
        status: status,
        supplierId: supplierId,
      );

  @override
  Future<int> getPurchaseOrderCount({
    String query = '',
    String? status,
    String? supplierId,
  }) =>
      PurchaseOrderService.getPurchaseOrderCount(
        query: query,
        status: status,
        supplierId: supplierId,
      );

  @override
  Future<void> receivePurchaseOrder(String poId) =>
      PurchaseOrderService.receivePurchaseOrder(poId);
}
