// Tests for inventory stock movement integrity and purchase order receipt flow.
//
// Uses sqflite_common_ffi (in-memory) — no platform channels needed, so these
// run on any host (flutter test, dart test).
//
// Covers:
//   - StockMovementService: records movement, updates stock, prevents duplicate
//     references, throws on negative stock (when allowNegative=false)
//   - PurchaseOrderService: receivePurchaseOrder updates stock, sets status,
//     is idempotent (second call is a no-op due to duplicate-ref guard)
//   - Product.isLowStock computed getter

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:invoiso/database/database_helper.dart';
import 'package:invoiso/database/stock_movement_service.dart';
import 'package:invoiso/database/purchase_order_service.dart';
import 'package:invoiso/models/product.dart';
import 'package:invoiso/models/purchase_order.dart';
import 'package:invoiso/models/stock_movement.dart';

// ── helpers ──────────────────────────────────────────────────────────────────

Future<Database> _openFreshDb() async {
  // Use DatabaseHelper's public create-from-scratch method which runs _createDB.
  // openDbForTest returns an in-memory Database initialised to the current schema.
  return DatabaseHelper().openDbForTest();
}

Future<String> _insertProduct(
  Database db, {
  required String id,
  required String name,
  int stock = 0,
  bool unlimited = false,
  int lowStockThreshold = 10,
}) async {
  await db.insert('products', {
    'id': id,
    'name': name,
    'description': '',
    'price': 100.0,
    'stock': stock,
    'hsncode': '',
    'tax_rate': 0,
    'type': 'product',
    'unlimited_stock': unlimited ? 1 : 0,
    'low_stock_threshold': lowStockThreshold,
  });
  return id;
}

// ── tests ─────────────────────────────────────────────────────────────────────

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Product.isLowStock', () {
    Product _makeProduct({
      int stock = 0,
      bool unlimited = false,
      int threshold = 10,
    }) =>
        Product(
          id: '1',
          name: 'Flour',
          description: '',
          price: 10,
          stock: stock,
          hsncode: '',
          // ignore: non_constant_identifier_names
          tax_rate: 0,
          unlimitedStock: unlimited,
          lowStockThreshold: threshold,
        );

    test('true when stock <= threshold and stock > 0', () {
      expect(_makeProduct(stock: 5, threshold: 10).isLowStock, isTrue);
    });

    test('true when stock == threshold', () {
      expect(_makeProduct(stock: 10, threshold: 10).isLowStock, isTrue);
    });

    test('false when stock == 0 (out-of-stock, not low-stock)', () {
      expect(_makeProduct(stock: 0, threshold: 10).isLowStock, isFalse);
    });

    test('false when unlimited stock', () {
      expect(_makeProduct(stock: 5, unlimited: true, threshold: 10).isLowStock,
          isFalse);
    });

    test('false when stock > threshold', () {
      expect(_makeProduct(stock: 20, threshold: 10).isLowStock, isFalse);
    });
  });

  group('StockMovementService', () {
    late Database db;
    late DatabaseHelper helper;

    setUp(() async {
      db = await _openFreshDb();
      helper = DatabaseHelper();
      // Point the singleton at our in-memory DB.
      await helper.injectDatabaseForTest(db);
    });

    tearDown(() async {
      await db.close();
      helper.resetForTest();
    });

    test('recordMovement increases stock and writes movement row', () async {
      await _insertProduct(db, id: 'p1', name: 'Rice', stock: 50);

      final m = StockMovement(
        id: 'mv1',
        productId: 'p1',
        productName: 'Rice',
        movementType: 'purchase',
        quantity: 20,
        beforeStock: 0,
        afterStock: 0,
        date: DateTime.now().toIso8601String(),
      );
      final saved = await StockMovementService.recordMovement(movement: m);

      expect(saved.beforeStock, 50);
      expect(saved.afterStock, 70);

      final product =
          (await db.query('products', where: 'id = ?', whereArgs: ['p1'])).first;
      expect(product['stock'], 70);

      final rows = await db.query('stock_movements',
          where: 'id = ?', whereArgs: ['mv1']);
      expect(rows.length, 1);
      expect(rows.first['quantity'], 20.0);
    });

    test('recordMovement decreases stock for negative quantity', () async {
      await _insertProduct(db, id: 'p2', name: 'Oil', stock: 100);

      final m = StockMovement(
        id: 'mv2',
        productId: 'p2',
        productName: 'Oil',
        movementType: 'sale',
        quantity: -30,
        beforeStock: 0,
        afterStock: 0,
        date: DateTime.now().toIso8601String(),
      );
      final saved = await StockMovementService.recordMovement(movement: m);

      expect(saved.beforeStock, 100);
      expect(saved.afterStock, 70);

      final product =
          (await db.query('products', where: 'id = ?', whereArgs: ['p2'])).first;
      expect(product['stock'], 70);
    });

    test('recordMovement throws StateError when stock would go negative', () async {
      await _insertProduct(db, id: 'p3', name: 'Salt', stock: 5);

      final m = StockMovement(
        id: 'mv3',
        productId: 'p3',
        productName: 'Salt',
        movementType: 'sale',
        quantity: -10,
        beforeStock: 0,
        afterStock: 0,
        date: DateTime.now().toIso8601String(),
      );

      expect(
        () => StockMovementService.recordMovement(movement: m),
        throwsA(isA<StateError>()),
      );
    });

    test('recordMovement with allowNegative=true permits negative stock', () async {
      await _insertProduct(db, id: 'p4', name: 'Sugar', stock: 5);

      final m = StockMovement(
        id: 'mv4',
        productId: 'p4',
        productName: 'Sugar',
        movementType: 'sale',
        quantity: -10,
        beforeStock: 0,
        afterStock: 0,
        date: DateTime.now().toIso8601String(),
      );

      final saved = await StockMovementService.recordMovement(
          movement: m, allowNegative: true);
      expect(saved.afterStock, -5);
    });

    test('duplicate reference throws StateError', () async {
      await _insertProduct(db, id: 'p5', name: 'Pepper', stock: 100);

      final m = StockMovement(
        id: 'mv5a',
        productId: 'p5',
        productName: 'Pepper',
        movementType: 'purchase',
        quantity: 10,
        beforeStock: 0,
        afterStock: 0,
        referenceId: 'po-001',
        referenceType: 'purchase_order',
        date: DateTime.now().toIso8601String(),
      );
      await StockMovementService.recordMovement(movement: m);

      final dup = StockMovement(
        id: 'mv5b',
        productId: 'p5',
        productName: 'Pepper',
        movementType: 'purchase',
        quantity: 10,
        beforeStock: 0,
        afterStock: 0,
        referenceId: 'po-001',
        referenceType: 'purchase_order',
        date: DateTime.now().toIso8601String(),
      );
      expect(
        () => StockMovementService.recordMovement(movement: dup),
        throwsA(isA<StateError>()),
      );
    });

    test('unlimited stock product: stock column unchanged after movement', () async {
      await _insertProduct(db, id: 'p6', name: 'Drinks', stock: 999, unlimited: true);

      final m = StockMovement(
        id: 'mv6',
        productId: 'p6',
        productName: 'Drinks',
        movementType: 'sale',
        quantity: -50,
        beforeStock: 0,
        afterStock: 0,
        date: DateTime.now().toIso8601String(),
      );
      final saved = await StockMovementService.recordMovement(movement: m);
      expect(saved.afterStock, 999); // unchanged because unlimited

      final product =
          (await db.query('products', where: 'id = ?', whereArgs: ['p6'])).first;
      expect(product['stock'], 999);
    });
  });

  group('PurchaseOrderService', () {
    late Database db;
    late DatabaseHelper helper;

    setUp(() async {
      db = await _openFreshDb();
      helper = DatabaseHelper();
      await helper.injectDatabaseForTest(db);
    });

    tearDown(() async {
      await db.close();
      helper.resetForTest();
    });

    Future<PurchaseOrder> _createAndInsertPO({
      required String productId,
      required String productName,
      double qty = 10,
      int initialStock = 0,
    }) async {
      await _insertProduct(db,
          id: productId, name: productName, stock: initialStock);

      const uuid = 'test-po-001';
      final item = PurchaseOrderItem(
        id: 'item-001',
        poId: uuid,
        productId: productId,
        productName: productName,
        quantity: qty,
        unitCost: 50,
        receivedQty: 0,
      );
      final po = PurchaseOrder(
        id: uuid,
        supplierId: 'sup-1',
        supplierName: 'Test Supplier',
        date: DateTime.now().toIso8601String(),
        status: 'ordered',
        totalAmount: qty * 50,
        createdAt: DateTime.now().toIso8601String(),
        items: [item],
      );
      await PurchaseOrderService.insertPurchaseOrder(po);
      return po;
    }

    test('receivePurchaseOrder updates stock and sets status to received', () async {
      final po = await _createAndInsertPO(
          productId: 'prod-a', productName: 'Butter', qty: 10);

      await PurchaseOrderService.receivePurchaseOrder(po.id);

      final product = (await db.query('products',
              where: 'id = ?', whereArgs: ['prod-a']))
          .first;
      expect(product['stock'], 10);

      final updatedPO = (await db.query('purchase_orders',
              where: 'id = ?', whereArgs: [po.id]))
          .first;
      expect(updatedPO['status'], 'received');
    });

    test('receivePurchaseOrder is idempotent — second call does not double-add stock',
        () async {
      final po = await _createAndInsertPO(
          productId: 'prod-b', productName: 'Cheese', qty: 5);

      await PurchaseOrderService.receivePurchaseOrder(po.id);
      // Second call: received_qty is already == quantity, so qty=0, no new movement.
      await PurchaseOrderService.receivePurchaseOrder(po.id);

      final product = (await db.query('products',
              where: 'id = ?', whereArgs: ['prod-b']))
          .first;
      expect(product['stock'], 5); // unchanged after second call
    });

    test('receivePurchaseOrder throws for cancelled PO', () async {
      await _insertProduct(db, id: 'prod-c', name: 'Milk', stock: 0);
      const poId = 'test-po-cancel';
      final item = PurchaseOrderItem(
        id: 'item-c',
        poId: poId,
        productId: 'prod-c',
        productName: 'Milk',
        quantity: 10,
        unitCost: 10,
        receivedQty: 0,
      );
      final po = PurchaseOrder(
        id: poId,
        supplierId: 'sup-1',
        supplierName: 'Sup',
        date: DateTime.now().toIso8601String(),
        status: 'cancelled',
        totalAmount: 100,
        createdAt: DateTime.now().toIso8601String(),
        items: [item],
      );
      await PurchaseOrderService.insertPurchaseOrder(po);

      expect(
        () => PurchaseOrderService.receivePurchaseOrder(poId),
        throwsA(isA<StateError>()),
      );
    });
  });
}
