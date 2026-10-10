import 'package:invoiso/models/supplier.dart';

abstract class SupplierRepository {
  Future<void> insertSupplier(Supplier supplier);
  Future<void> updateSupplier(Supplier supplier);
  Future<void> deleteSupplier(String id);
  Future<Supplier?> getSupplierById(String id);
  Future<List<Supplier>> getAllSuppliers();
  Future<List<Supplier>> searchSuppliers(String query);
  Future<List<Supplier>> getSupplierPage({
    required int offset,
    required int limit,
    String query,
  });
  Future<int> getSupplierCount([String query]);
}
