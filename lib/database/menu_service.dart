import 'package:sqflite/sqflite.dart';
import 'package:invoiso/models/restaurant_menu.dart';
import 'database_helper.dart';

class MenuService {
  static final _db = DatabaseHelper();

  // ── Categories ──────────────────────────────────────────────────────────

  static Future<void> insertCategory(MenuCategory c) async {
    final db = await _db.database;
    await db.insert('menu_categories', c.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<void> updateCategory(MenuCategory c) async {
    final db = await _db.database;
    final map = c.toMap()..remove('id');
    await db.update('menu_categories', map,
        where: 'id = ?', whereArgs: [c.id]);
  }

  static Future<void> deleteCategory(String id) async {
    final db = await _db.database;
    // Cascade: delete items and their ingredients
    final items = await db.query('menu_items',
        columns: ['id'], where: 'category_id = ?', whereArgs: [id]);
    for (final item in items) {
      await db.delete('recipe_ingredients',
          where: 'menu_item_id = ?', whereArgs: [item['id']]);
    }
    await db.delete('menu_items', where: 'category_id = ?', whereArgs: [id]);
    await db.delete('menu_categories', where: 'id = ?', whereArgs: [id]);
  }

  static Future<List<MenuCategory>> getAllCategories() async {
    final db = await _db.database;
    final rows = await db.query('menu_categories', orderBy: 'display_order ASC, name ASC');
    return rows.map(MenuCategory.fromMap).toList();
  }

  // ── Menu Items ───────────────────────────────────────────────────────────

  static Future<void> insertMenuItem(MenuItem item) async {
    final db = await _db.database;
    await db.transaction((txn) async {
      await txn.insert('menu_items', item.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace);
      for (final ing in item.ingredients) {
        await txn.insert('recipe_ingredients', ing.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  static Future<void> updateMenuItem(MenuItem item) async {
    final db = await _db.database;
    await db.transaction((txn) async {
      final map = item.toMap()..remove('id');
      await txn.update('menu_items', map,
          where: 'id = ?', whereArgs: [item.id]);
      await txn.delete('recipe_ingredients',
          where: 'menu_item_id = ?', whereArgs: [item.id]);
      for (final ing in item.ingredients) {
        await txn.insert('recipe_ingredients', ing.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  static Future<void> deleteMenuItem(String id) async {
    final db = await _db.database;
    await db.delete('recipe_ingredients',
        where: 'menu_item_id = ?', whereArgs: [id]);
    await db.delete('menu_items', where: 'id = ?', whereArgs: [id]);
  }

  static Future<List<MenuItem>> getItemsForCategory(String categoryId) async {
    final db = await _db.database;
    final rows = await db.query('menu_items',
        where: 'category_id = ?',
        whereArgs: [categoryId],
        orderBy: 'display_order ASC, name ASC');
    final items = <MenuItem>[];
    for (final row in rows) {
      final id = row['id'] as String;
      final ingRows = await db.query('recipe_ingredients',
          where: 'menu_item_id = ?', whereArgs: [id]);
      items.add(MenuItem.fromMap(row,
          ingredients: ingRows.map(RecipeIngredient.fromMap).toList()));
    }
    return items;
  }

  static Future<List<MenuItem>> getAllMenuItems() async {
    final db = await _db.database;
    final rows = await db.query('menu_items',
        orderBy: 'category_id ASC, display_order ASC, name ASC');
    final items = <MenuItem>[];
    for (final row in rows) {
      final id = row['id'] as String;
      final ingRows = await db.query('recipe_ingredients',
          where: 'menu_item_id = ?', whereArgs: [id]);
      items.add(MenuItem.fromMap(row,
          ingredients: ingRows.map(RecipeIngredient.fromMap).toList()));
    }
    return items;
  }

  static Future<List<MenuItem>> searchMenuItems(String query) async {
    final db = await _db.database;
    if (query.trim().isEmpty) return getAllMenuItems();
    final q = '%${query.trim()}%';
    final rows = await db.rawQuery(
      'SELECT * FROM menu_items WHERE name LIKE ? OR description LIKE ? ORDER BY name ASC',
      [q, q],
    );
    final items = <MenuItem>[];
    for (final row in rows) {
      final id = row['id'] as String;
      final ingRows = await db.query('recipe_ingredients',
          where: 'menu_item_id = ?', whereArgs: [id]);
      items.add(MenuItem.fromMap(row,
          ingredients: ingRows.map(RecipeIngredient.fromMap).toList()));
    }
    return items;
  }

  /// Deduct recipe ingredients from stock for [quantity] of a menu item.
  /// Records a 'sale' stock movement for each ingredient.
  /// Returns a list of warning strings for products with insufficient stock.
  static Future<List<String>> deductRecipeIngredients({
    required MenuItem item,
    required double quantity,
    String? referenceId,
    String? referenceType,
  }) async {
    final db = await _db.database;
    final warnings = <String>[];
    final now = DateTime.now().toIso8601String();

    await db.transaction((txn) async {
      for (final ing in item.ingredients) {
        final needed = ing.quantity * quantity;
        final rows = await txn.query('products',
            columns: ['stock', 'name', 'unlimited_stock'],
            where: 'id = ?',
            whereArgs: [ing.productId]);
        if (rows.isEmpty) continue;

        final unlimited = (rows.first['unlimited_stock'] as int? ?? 0) == 1;
        final currentStock = rows.first['stock'] as int? ?? 0;
        if (unlimited) continue;

        final newStock = currentStock - needed.round();
        if (newStock < 0) {
          warnings.add(
              '${ing.productName}: needed ${needed.toStringAsFixed(2)} but only $currentStock available');
        }
        final actualNew = newStock < 0 ? 0 : newStock;

        await txn.insert(
          'stock_movements',
          {
            'id': DateTime.now().microsecondsSinceEpoch.toString(),
            'product_id': ing.productId,
            'product_name': ing.productName,
            'movement_type': 'sale',
            'quantity': -needed,
            'before_stock': currentStock,
            'after_stock': actualNew,
            'reference_id': referenceId,
            'reference_type': referenceType ?? 'menu_sale',
            'notes': 'Recipe deduction: ${item.name} ×$quantity',
            'date': now,
          },
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );

        await txn.update('products', {'stock': actualNew},
            where: 'id = ?', whereArgs: [ing.productId]);
      }
    });

    return warnings;
  }
}
