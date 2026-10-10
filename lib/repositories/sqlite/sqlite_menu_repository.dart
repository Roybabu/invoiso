import 'package:invoiso/database/menu_service.dart';
import 'package:invoiso/models/restaurant_menu.dart';
import 'package:invoiso/repositories/menu_repository.dart';

class SqliteMenuRepository implements MenuRepository {
  @override
  Future<void> insertCategory(MenuCategory category) =>
      MenuService.insertCategory(category);

  @override
  Future<void> updateCategory(MenuCategory category) =>
      MenuService.updateCategory(category);

  @override
  Future<void> deleteCategory(String id) =>
      MenuService.deleteCategory(id);

  @override
  Future<List<MenuCategory>> getAllCategories() =>
      MenuService.getAllCategories();

  @override
  Future<void> insertMenuItem(MenuItem item) =>
      MenuService.insertMenuItem(item);

  @override
  Future<void> updateMenuItem(MenuItem item) =>
      MenuService.updateMenuItem(item);

  @override
  Future<void> deleteMenuItem(String id) =>
      MenuService.deleteMenuItem(id);

  @override
  Future<List<MenuItem>> getItemsForCategory(String categoryId) =>
      MenuService.getItemsForCategory(categoryId);

  @override
  Future<List<MenuItem>> getAllMenuItems() =>
      MenuService.getAllMenuItems();

  @override
  Future<List<MenuItem>> searchMenuItems(String query) =>
      MenuService.searchMenuItems(query);

  @override
  Future<List<String>> deductRecipeIngredients({
    required MenuItem item,
    required double quantity,
    String? referenceId,
    String? referenceType,
  }) =>
      MenuService.deductRecipeIngredients(
        item: item,
        quantity: quantity,
        referenceId: referenceId,
        referenceType: referenceType,
      );
}
