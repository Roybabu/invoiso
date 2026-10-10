import 'package:sqflite/sqflite.dart';
import 'package:invoiso/models/stock_movement.dart';
import 'package:invoiso/utils/app_logger.dart';
import 'database_helper.dart';

const _tag = 'StockMovementService';

class StockMovementService {
  static final _db = DatabaseHelper();

  /// Records a stock movement AND updates the product's stock column
  /// atomically inside a transaction. Returns the persisted movement.
  /// [quantity] is positive for inbound, negative for outbound.
  ///
  /// Throws [StateError] if the resulting stock would go below zero and
  /// [allowNegative] is false (default).
  static Future<StockMovement> recordMovement({
    required StockMovement movement,
    bool updateProductStock = true,
    bool allowNegative = false,
  }) async {
    final db = await _db.database;
    late StockMovement saved;

    await db.transaction((txn) async {
      final rows = await txn.query(
        'products',
        columns: ['stock', 'unlimited_stock'],
        where: 'id = ?',
        whereArgs: [movement.productId],
      );
      if (rows.isEmpty) {
        throw StateError('Product ${movement.productId} not found');
      }
      final unlimited = (rows.first['unlimited_stock'] as int? ?? 0) == 1;
      final currentStock = rows.first['stock'] as int? ?? 0;
      final newStock = currentStock + movement.quantity.round();

      if (!allowNegative && !unlimited && newStock < 0) {
        throw StateError(
            'Insufficient stock: have $currentStock, need ${movement.quantity.abs().round()}');
      }

      // Check for duplicate reference to prevent double-posting
      if (movement.referenceId != null && movement.referenceType != null) {
        final dup = await txn.query(
          'stock_movements',
          where: 'reference_id = ? AND reference_type = ? AND product_id = ?',
          whereArgs: [
            movement.referenceId,
            movement.referenceType,
            movement.productId,
          ],
          limit: 1,
        );
        if (dup.isNotEmpty) {
          throw StateError(
              'Duplicate movement: reference ${movement.referenceType}/${movement.referenceId} already applied to product ${movement.productId}');
        }
      }

      saved = StockMovement(
        id: movement.id,
        productId: movement.productId,
        productName: movement.productName,
        movementType: movement.movementType,
        quantity: movement.quantity,
        beforeStock: currentStock,
        afterStock: unlimited ? currentStock : newStock,
        referenceId: movement.referenceId,
        referenceType: movement.referenceType,
        notes: movement.notes,
        date: movement.date,
      );

      await txn.insert('stock_movements', saved.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace);

      if (updateProductStock && !unlimited) {
        await txn.update(
          'products',
          {'stock': newStock},
          where: 'id = ?',
          whereArgs: [movement.productId],
        );
      }
      AppLogger.d(_tag,
          'Movement ${movement.movementType} qty=${movement.quantity} product=${movement.productId} stock $currentStock→${unlimited ? currentStock : newStock}');
    });

    return saved;
  }

  static Future<List<StockMovement>> getMovementsForProduct(
    String productId, {
    int? limit,
    int offset = 0,
  }) async {
    final db = await _db.database;
    final rows = await db.query(
      'stock_movements',
      where: 'product_id = ?',
      whereArgs: [productId],
      orderBy: 'date DESC',
      limit: limit,
      offset: offset,
    );
    return rows.map(StockMovement.fromMap).toList();
  }

  static Future<List<StockMovement>> getMovementsPage({
    required int offset,
    required int limit,
    String? productId,
    String? movementType,
    String? fromDate,
    String? toDate,
  }) async {
    final db = await _db.database;
    final conditions = <String>[];
    final args = <dynamic>[];

    if (productId != null) {
      conditions.add('product_id = ?');
      args.add(productId);
    }
    if (movementType != null) {
      conditions.add('movement_type = ?');
      args.add(movementType);
    }
    if (fromDate != null) {
      conditions.add('date >= ?');
      args.add(fromDate);
    }
    if (toDate != null) {
      conditions.add('date <= ?');
      args.add(toDate);
    }

    final where = conditions.isEmpty ? null : conditions.join(' AND ');
    final rows = await db.query(
      'stock_movements',
      where: where,
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'date DESC',
      limit: limit,
      offset: offset,
    );
    return rows.map(StockMovement.fromMap).toList();
  }

  static Future<int> getMovementsCount({
    String? productId,
    String? movementType,
    String? fromDate,
    String? toDate,
  }) async {
    final db = await _db.database;
    final conditions = <String>[];
    final args = <dynamic>[];
    if (productId != null) {
      conditions.add('product_id = ?');
      args.add(productId);
    }
    if (movementType != null) {
      conditions.add('movement_type = ?');
      args.add(movementType);
    }
    if (fromDate != null) {
      conditions.add('date >= ?');
      args.add(fromDate);
    }
    if (toDate != null) {
      conditions.add('date <= ?');
      args.add(toDate);
    }
    final where = conditions.isEmpty ? null : conditions.join(' AND ');
    final r = await db.rawQuery(
      'SELECT COUNT(*) FROM stock_movements${where != null ? ' WHERE $where' : ''}',
      args.isEmpty ? null : args,
    );
    return Sqflite.firstIntValue(r) ?? 0;
  }

  static Future<Map<String, double>> getStockSummary({
    String? fromDate,
    String? toDate,
  }) async {
    final db = await _db.database;
    final args = <dynamic>[];
    var where = '';
    if (fromDate != null && toDate != null) {
      where = 'WHERE date >= ? AND date <= ?';
      args.addAll([fromDate, toDate]);
    }
    final rows = await db.rawQuery(
      'SELECT movement_type, SUM(quantity) as total FROM stock_movements $where GROUP BY movement_type',
      args.isEmpty ? null : args,
    );
    return {for (final r in rows) r['movement_type'] as String: (r['total'] as num).toDouble()};
  }
}
