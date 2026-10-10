import 'package:invoiso/models/restaurant_menu.dart';

abstract class MenuRepository {
  Future<void> insertCategory(MenuCategory category);
  Future<void> updateCategory(MenuCategory category);
  Future<void> deleteCategory(String id);
  Future<List<MenuCategory>> getAllCategories();

  Future<void> insertMenuItem(MenuItem item);
  Future<void> updateMenuItem(MenuItem item);
  Future<void> deleteMenuItem(String id);
  Future<List<MenuItem>> getItemsForCategory(String categoryId);
  Future<List<MenuItem>> getAllMenuItems();
  Future<List<MenuItem>> searchMenuItems(String query);

  Future<List<String>> deductRecipeIngredients({
    required MenuItem item,
    required double quantity,
    String? referenceId,
    String? referenceType,
  });
}
