class MenuCategory {
  String id;
  String name;
  String description;
  int displayOrder;
  bool active;

  MenuCategory({
    required this.id,
    required this.name,
    this.description = '',
    this.displayOrder = 0,
    this.active = true,
  });

  // Convert a Map into a MenuCategory object
  factory MenuCategory.fromMap(Map<String, dynamic> map) {
    return MenuCategory(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      displayOrder: map['display_order'] ?? 0,
      active: (map['active'] ?? 1) == 1,
    );
  }

  // Convert a MenuCategory object into a Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'display_order': displayOrder,
      'active': active ? 1 : 0,
    };
  }
}

class RecipeIngredient {
  String id;
  String menuItemId;
  String productId;
  String productName;
  double quantity;
  String unit;

  RecipeIngredient({
    required this.id,
    required this.menuItemId,
    required this.productId,
    required this.productName,
    required this.quantity,
    this.unit = '',
  });

  // Convert a Map into a RecipeIngredient object
  factory RecipeIngredient.fromMap(Map<String, dynamic> map) {
    return RecipeIngredient(
      id: map['id'] ?? '',
      menuItemId: map['menu_item_id'] ?? '',
      productId: map['product_id'] ?? '',
      productName: map['product_name'] ?? '',
      quantity: (map['quantity'] as num?)?.toDouble() ?? 0.0,
      unit: map['unit'] ?? '',
    );
  }

  // Convert a RecipeIngredient object into a Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'menu_item_id': menuItemId,
      'product_id': productId,
      'product_name': productName,
      'quantity': quantity,
      'unit': unit,
    };
  }
}

class MenuItem {
  String id;
  String categoryId;
  String categoryName;
  String name;
  String description;
  double price;
  double taxRate;
  bool available;
  int displayOrder;
  List<RecipeIngredient> ingredients;

  MenuItem({
    required this.id,
    required this.categoryId,
    this.categoryName = '',
    required this.name,
    this.description = '',
    required this.price,
    this.taxRate = 0,
    this.available = true,
    this.displayOrder = 0,
    this.ingredients = const [],
  });

  // Convert a Map into a MenuItem object
  factory MenuItem.fromMap(Map<String, dynamic> map) {
    return MenuItem(
      id: map['id'] ?? '',
      categoryId: map['category_id'] ?? '',
      categoryName: map['category_name'] ?? '',
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      price: (map['price'] as num?)?.toDouble() ?? 0.0,
      taxRate: (map['tax_rate'] as num?)?.toDouble() ?? 0.0,
      available: (map['available'] ?? 1) == 1,
      displayOrder: map['display_order'] ?? 0,
      ingredients: (map['ingredients'] as List<dynamic>?)
              ?.map((e) => RecipeIngredient.fromMap(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  // Convert a MenuItem object into a Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'category_id': categoryId,
      'category_name': categoryName,
      'name': name,
      'description': description,
      'price': price,
      'tax_rate': taxRate,
      'available': available ? 1 : 0,
      'display_order': displayOrder,
      'ingredients': ingredients.map((e) => e.toMap()).toList(),
    };
  }
}
