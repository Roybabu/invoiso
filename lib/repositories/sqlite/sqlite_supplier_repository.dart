import 'package:invoiso/database/supplier_service.dart';
import 'package:invoiso/models/supplier.dart';
import 'package:invoiso/repositories/supplier_repository.dart';

class SqliteSupplierRepository implements SupplierRepository {
  @override
  Future<void> insertSupplier(Supplier supplier) =>
      SupplierService.insertSupplier(supplier);

  @override
  Future<void> updateSupplier(Supplier supplier) =>
      SupplierService.updateSupplier(supplier);

  @override
  Future<void> deleteSupplier(String id) =>
      SupplierService.deleteSupplier(id);

  @override
  Future<Supplier?> getSupplierById(String id) =>
      SupplierService.getSupplierById(id);

  @override
  Future<List<Supplier>> getAllSuppliers() =>
      SupplierService.getAllSuppliers();

  @override
  Future<List<Supplier>> searchSuppliers(String query) =>
      SupplierService.searchSuppliers(query);

  @override
  Future<List<Supplier>> getSupplierPage({
    required int offset,
    required int limit,
    String query = '',
  }) =>
      SupplierService.getSupplierPage(
        offset: offset,
        limit: limit,
        query: query,
      );

  @override
  Future<int> getSupplierCount([String query = '']) =>
      SupplierService.getSupplierCount(query);
}
