import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import 'package:invoiso/models/purchase_order.dart';
import 'package:invoiso/models/stock_movement.dart';
import 'package:invoiso/utils/app_logger.dart';
import 'database_helper.dart';
import 'stock_movement_service.dart';

const _tag = 'PurchaseOrderService';
const _uuid = Uuid();

class PurchaseOrderService {
  static final _db = DatabaseHelper();

  static Future<PurchaseOrder> insertPurchaseOrder(PurchaseOrder po) async {
    final db = await _db.database;
    await db.transaction((txn) async {
      await txn.insert('purchase_orders', po.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace);
      for (final item in po.items) {
        await txn.insert('purchase_order_items', item.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
    AppLogger.d(_tag, 'PO inserted: ${po.id}');
    return po;
  }

  static Future<void> updatePurchaseOrder(PurchaseOrder po) async {
    final db = await _db.database;
    await db.transaction((txn) async {
      final map = po.toMap()..remove('id');
      await txn.update('purchase_orders', map,
          where: 'id = ?', whereArgs: [po.id]);
      await txn.delete('purchase_order_items',
          where: 'po_id = ?', whereArgs: [po.id]);
      for (final item in po.items) {
        await txn.insert('purchase_order_items', item.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  static Future<void> deletePurchaseOrder(String id) async {
    final db = await _db.database;
    await db.transaction((txn) async {
      await txn.delete('purchase_order_items',
          where: 'po_id = ?', whereArgs: [id]);
      await txn.delete('purchase_orders', where: 'id = ?', whereArgs: [id]);
    });
  }

  static Future<PurchaseOrder?> getPurchaseOrderById(String id) async {
    final db = await _db.database;
    final rows = await db.query('purchase_orders',
        where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    final itemRows = await db.query('purchase_order_items',
        where: 'po_id = ?', whereArgs: [id]);
    final items = itemRows.map(PurchaseOrderItem.fromMap).toList();
    return PurchaseOrder.fromMap(rows.first, items: items);
  }

  static Future<List<PurchaseOrder>> getPurchaseOrdersPage({
    required int offset,
    required int limit,
    String query = '',
    String? status,
    String? supplierId,
  }) async {
    final db = await _db.database;
    final conditions = <String>[];
    final args = <dynamic>[];
    if (query.trim().isNotEmpty) {
      conditions.add('(supplier_name LIKE ? OR notes LIKE ?)');
      final q = '%${query.trim()}%';
      args.addAll([q, q]);
    }
    if (status != null) {
      conditions.add('status = ?');
      args.add(status);
    }
    if (supplierId != null) {
      conditions.add('supplier_id = ?');
      args.add(supplierId);
    }
    final where = conditions.isEmpty ? null : conditions.join(' AND ');
    final rows = await db.query(
      'purchase_orders',
      where: where,
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'date DESC',
      limit: limit,
      offset: offset,
    );
    // Load items for each PO
    final pos = <PurchaseOrder>[];
    for (final row in rows) {
      final id = row['id'] as String;
      final itemRows = await db.query('purchase_order_items',
          where: 'po_id = ?', whereArgs: [id]);
      pos.add(PurchaseOrder.fromMap(row,
          items: itemRows.map(PurchaseOrderItem.fromMap).toList()));
    }
    return pos;
  }

  static Future<int> getPurchaseOrderCount({
    String query = '',
    String? status,
    String? supplierId,
  }) async {
    final db = await _db.database;
    final conditions = <String>[];
    final args = <dynamic>[];
    if (query.trim().isNotEmpty) {
      conditions.add('(supplier_name LIKE ? OR notes LIKE ?)');
      final q = '%${query.trim()}%';
      args.addAll([q, q]);
    }
    if (status != null) {
      conditions.add('status = ?');
      args.add(status);
    }
    if (supplierId != null) {
      conditions.add('supplier_id = ?');
      args.add(supplierId);
    }
    final where = conditions.isEmpty ? null : conditions.join(' AND ');
    final r = await db.rawQuery(
      'SELECT COUNT(*) FROM purchase_orders${where != null ? ' WHERE $where' : ''}',
      args.isEmpty ? null : args,
    );
    return Sqflite.firstIntValue(r) ?? 0;
  }

  /// Mark a PO as received, record stock movements for each item,
  /// and update received quantities. Idempotent per item via duplicate check.
  static Future<void> receivePurchaseOrder(String poId) async {
    final po = await getPurchaseOrderById(poId);
    if (po == null) throw StateError('PO not found: $poId');
    if (po.status == 'cancelled') throw StateError('Cannot receive a cancelled PO');

    final db = await _db.database;
    final now = DateTime.now().toIso8601String();

    await db.transaction((txn) async {
      for (final item in po.items) {
        final qty = item.quantity - item.receivedQty;
        if (qty <= 0) continue;

        // Update received qty on item
        await txn.update(
          'purchase_order_items',
          {'received_qty': item.quantity},
          where: 'id = ?',
          whereArgs: [item.id],
        );

        // Check for duplicate movement
        final dup = await txn.query(
          'stock_movements',
          where: 'reference_id = ? AND reference_type = ? AND product_id = ?',
          whereArgs: [poId, 'purchase_order', item.productId],
          limit: 1,
        );
        if (dup.isNotEmpty) continue;

        final currentRow = await txn.query('products',
            columns: ['stock', 'unlimited_stock'],
            where: 'id = ?',
            whereArgs: [item.productId]);
        if (currentRow.isEmpty) continue;

        final currentStock = currentRow.first['stock'] as int? ?? 0;
        final unlimited = (currentRow.first['unlimited_stock'] as int? ?? 0) == 1;
        final newStock = currentStock + qty.round();

        await txn.insert('stock_movements', {
          'id': _uuid.v4(),
          'product_id': item.productId,
          'product_name': item.productName,
          'movement_type': 'purchase',
          'quantity': qty,
          'before_stock': currentStock,
          'after_stock': unlimited ? currentStock : newStock,
          'reference_id': poId,
          'reference_type': 'purchase_order',
          'notes': 'Received via PO',
          'date': now,
        }, conflictAlgorithm: ConflictAlgorithm.replace);

        if (!unlimited) {
          await txn.update('products', {'stock': newStock},
              where: 'id = ?', whereArgs: [item.productId]);
        }
      }

      // Determine new status
      final allItems = await txn.query('purchase_order_items',
          where: 'po_id = ?', whereArgs: [poId]);
      final allReceived = allItems.every((r) =>
          (r['received_qty'] as num).toDouble() >=
          (r['quantity'] as num).toDouble());
      final anyReceived = allItems.any(
          (r) => (r['received_qty'] as num).toDouble() > 0);
      final newStatus = allReceived
          ? 'received'
          : (anyReceived ? 'partial' : po.status);

      await txn.update('purchase_orders', {'status': newStatus},
          where: 'id = ?', whereArgs: [poId]);
    });

    AppLogger.d(_tag, 'PO received: $poId');
  }
}
