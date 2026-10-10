import 'package:sqflite/sqflite.dart';
import 'package:invoiso/models/supplier.dart';
import 'database_helper.dart';

class SupplierService {
  static final _db = DatabaseHelper();

  static Future<void> insertSupplier(Supplier s) async {
    final db = await _db.database;
    await db.insert('suppliers', s.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<void> updateSupplier(Supplier s) async {
    final db = await _db.database;
    final map = s.toMap()..remove('id');
    await db.update('suppliers', map, where: 'id = ?', whereArgs: [s.id]);
  }

  static Future<void> deleteSupplier(String id) async {
    final db = await _db.database;
    await db.delete('suppliers', where: 'id = ?', whereArgs: [id]);
  }

  static Future<Supplier?> getSupplierById(String id) async {
    final db = await _db.database;
    final rows = await db.query('suppliers', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : Supplier.fromMap(rows.first);
  }

  static Future<List<Supplier>> getAllSuppliers() async {
    final db = await _db.database;
    final rows = await db.query('suppliers', orderBy: 'name COLLATE NOCASE ASC');
    return rows.map(Supplier.fromMap).toList();
  }

  static Future<List<Supplier>> searchSuppliers(String query) async {
    final db = await _db.database;
    if (query.trim().isEmpty) return getAllSuppliers();
    final q = '%${query.trim()}%';
    final rows = await db.query(
      'suppliers',
      where: 'name LIKE ? OR email LIKE ? OR phone LIKE ? OR business_name LIKE ?',
      whereArgs: [q, q, q, q],
      orderBy: 'name COLLATE NOCASE ASC',
    );
    return rows.map(Supplier.fromMap).toList();
  }

  static Future<List<Supplier>> getSupplierPage({
    required int offset,
    required int limit,
    String query = '',
  }) async {
    final db = await _db.database;
    if (query.trim().isEmpty) {
      final rows = await db.query('suppliers',
          orderBy: 'name COLLATE NOCASE ASC', limit: limit, offset: offset);
      return rows.map(Supplier.fromMap).toList();
    }
    final q = '%${query.trim()}%';
    final rows = await db.rawQuery(
      'SELECT * FROM suppliers WHERE name LIKE ? OR email LIKE ? OR phone LIKE ? OR business_name LIKE ? ORDER BY name COLLATE NOCASE ASC LIMIT ? OFFSET ?',
      [q, q, q, q, limit, offset],
    );
    return rows.map(Supplier.fromMap).toList();
  }

  static Future<int> getSupplierCount([String query = '']) async {
    final db = await _db.database;
    if (query.trim().isEmpty) {
      final r = await db.rawQuery('SELECT COUNT(*) FROM suppliers');
      return Sqflite.firstIntValue(r) ?? 0;
    }
    final q = '%${query.trim()}%';
    final r = await db.rawQuery(
      'SELECT COUNT(*) FROM suppliers WHERE name LIKE ? OR email LIKE ? OR phone LIKE ? OR business_name LIKE ?',
      [q, q, q, q],
    );
    return Sqflite.firstIntValue(r) ?? 0;
  }
}
