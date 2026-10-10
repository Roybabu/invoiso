import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:invoiso/common/invoiso_colors.dart';
import 'package:invoiso/models/product.dart';
import 'package:invoiso/models/restaurant_menu.dart';
import 'package:invoiso/models/user.dart';
import 'package:invoiso/providers/repositories.dart';
import 'package:uuid/uuid.dart';

class RestaurantMenuScreen extends ConsumerStatefulWidget {
  final User user;
  const RestaurantMenuScreen({super.key, required this.user});

  @override
  ConsumerState<RestaurantMenuScreen> createState() =>
      _RestaurantMenuScreenState();
}

class _RestaurantMenuScreenState extends ConsumerState<RestaurantMenuScreen> {
  List<MenuCategory> _categories = [];
  MenuCategory? _selectedCategory;
  List<MenuItem> _items = [];
  bool _isLoading = false;

  // Add/edit
  bool _showCategoryPanel = false;
  bool _showItemPanel = false;
  MenuCategory? _editingCategory;
  MenuItem? _editingItem;

  // Category form
  final _catNameController = TextEditingController();
  final _catDescController = TextEditingController();
  final _catOrderController = TextEditingController(text: '0');

  // Item form
  final _itemNameController = TextEditingController();
  final _itemDescController = TextEditingController();
  final _itemPriceController = TextEditingController(text: '0');
  final _itemTaxRateController = TextEditingController(text: '0');
  final _itemOrderController = TextEditingController(text: '0');
  bool _itemAvailable = true;
  final List<_IngredientDraft> _ingredientDrafts = [];

  // Products for ingredient selection
  List<Product> _allProducts = [];

  final _catFormKey = GlobalKey<FormState>();
  final _itemFormKey = GlobalKey<FormState>();
  static const _uuid = Uuid();

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _loadProducts();
  }

  @override
  void dispose() {
    _catNameController.dispose();
    _catDescController.dispose();
    _catOrderController.dispose();
    _itemNameController.dispose();
    _itemDescController.dispose();
    _itemPriceController.dispose();
    _itemTaxRateController.dispose();
    _itemOrderController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    setState(() => _isLoading = true);
    final cats = await ref.read(menuRepositoryProvider).getAllCategories();
    if (!mounted) return;
    setState(() {
      _categories = cats;
      _isLoading = false;
    });
    if (_selectedCategory != null) {
      final updated =
          cats.where((c) => c.id == _selectedCategory!.id).firstOrNull;
      setState(() => _selectedCategory = updated);
      if (updated != null) await _loadItems(updated.id);
    }
  }

  Future<void> _loadItems(String categoryId) async {
    final items = await ref
        .read(menuRepositoryProvider)
        .getItemsForCategory(categoryId);
    if (!mounted) return;
    setState(() => _items = items);
  }

  Future<void> _loadProducts() async {
    final products =
        await ref.read(productRepositoryProvider).getAllProducts();
    if (!mounted) return;
    setState(() => _allProducts =
        products.where((p) => p.type == 'product').toList());
  }

  void _openCategoryPanel({MenuCategory? editing}) {
    _editingCategory = editing;
    if (editing != null) {
      _catNameController.text = editing.name;
      _catDescController.text = editing.description ?? '';
      _catOrderController.text = editing.displayOrder.toString();
    } else {
      _catNameController.clear();
      _catDescController.clear();
      _catOrderController.text = '0';
    }
    setState(() => _showCategoryPanel = true);
  }

  Future<void> _saveCategory() async {
    if (!(_catFormKey.currentState?.validate() ?? false)) return;
    final repo = ref.read(menuRepositoryProvider);
    if (_editingCategory != null) {
      final updated = MenuCategory(
        id: _editingCategory!.id,
        name: _catNameController.text.trim(),
        description: _catDescController.text.trim().isEmpty
            ? null
            : _catDescController.text.trim(),
        displayOrder: int.tryParse(_catOrderController.text) ?? 0,
        active: _editingCategory!.active,
      );
      await repo.updateCategory(updated);
    } else {
      final cat = MenuCategory(
        id: _uuid.v4(),
        name: _catNameController.text.trim(),
        description: _catDescController.text.trim().isEmpty
            ? null
            : _catDescController.text.trim(),
        displayOrder: int.tryParse(_catOrderController.text) ?? 0,
        active: true,
      );
      await repo.insertCategory(cat);
    }
    setState(() => _showCategoryPanel = false);
    await _loadCategories();
  }

  Future<void> _deleteCategory(MenuCategory cat) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Category'),
        content: Text(
            'Delete "${cat.name}"? All items in this category will also be deleted.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete',
                  style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(menuRepositoryProvider).deleteCategory(cat.id);
    if (_selectedCategory?.id == cat.id) {
      setState(() {
        _selectedCategory = null;
        _items = [];
      });
    }
    await _loadCategories();
  }

  void _openItemPanel({MenuItem? editing}) {
    _editingItem = editing;
    if (editing != null) {
      _itemNameController.text = editing.name;
      _itemDescController.text = editing.description ?? '';
      _itemPriceController.text = editing.price.toStringAsFixed(2);
      _itemTaxRateController.text = editing.taxRate.toStringAsFixed(2);
      _itemOrderController.text = editing.displayOrder.toString();
      _itemAvailable = editing.available;
      _ingredientDrafts
        ..clear()
        ..addAll(editing.ingredients.map((i) => _IngredientDraft.fromIngredient(i)));
    } else {
      _itemNameController.clear();
      _itemDescController.clear();
      _itemPriceController.text = '0';
      _itemTaxRateController.text = '0';
      _itemOrderController.text = '0';
      _itemAvailable = true;
      _ingredientDrafts.clear();
    }
    setState(() => _showItemPanel = true);
  }

  Future<void> _saveItem() async {
    if (!(_itemFormKey.currentState?.validate() ?? false)) return;
    if (_selectedCategory == null) return;
    final repo = ref.read(menuRepositoryProvider);
    final itemId = _editingItem?.id ?? _uuid.v4();
    final ingredients = _ingredientDrafts
        .where((d) => d.productId.isNotEmpty)
        .map((d) => RecipeIngredient(
              id: d.id ?? _uuid.v4(),
              menuItemId: itemId,
              productId: d.productId,
              productName: d.productName,
              quantity: double.tryParse(d.qtyController.text) ?? 1,
              unit: d.unit,
            ))
        .toList();
    if (_editingItem != null) {
      final updated = MenuItem(
        id: itemId,
        categoryId: _selectedCategory!.id,
        categoryName: _selectedCategory!.name,
        name: _itemNameController.text.trim(),
        description: _itemDescController.text.trim().isEmpty
            ? null
            : _itemDescController.text.trim(),
        price: double.tryParse(_itemPriceController.text) ?? 0,
        taxRate: double.tryParse(_itemTaxRateController.text) ?? 0,
        available: _itemAvailable,
        displayOrder: int.tryParse(_itemOrderController.text) ?? 0,
        ingredients: ingredients,
      );
      await repo.updateMenuItem(updated);
    } else {
      final item = MenuItem(
        id: itemId,
        categoryId: _selectedCategory!.id,
        categoryName: _selectedCategory!.name,
        name: _itemNameController.text.trim(),
        description: _itemDescController.text.trim().isEmpty
            ? null
            : _itemDescController.text.trim(),
        price: double.tryParse(_itemPriceController.text) ?? 0,
        taxRate: double.tryParse(_itemTaxRateController.text) ?? 0,
        available: _itemAvailable,
        displayOrder: int.tryParse(_itemOrderController.text) ?? 0,
        ingredients: ingredients,
      );
      await repo.insertMenuItem(item);
    }
    setState(() => _showItemPanel = false);
    await _loadItems(_selectedCategory!.id);
  }

  Future<void> _deleteItem(MenuItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Menu Item'),
        content: Text('Delete "${item.name}"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete',
                  style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(menuRepositoryProvider).deleteMenuItem(item.id);
    await _loadItems(_selectedCategory!.id);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        // Categories sidebar
        Container(
          width: 220,
          decoration: BoxDecoration(
            border: Border(
                right: BorderSide(color: theme.colorScheme.outlineVariant)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 16, 8, 8),
                child: Row(
                  children: [
                    Text('Categories',
                        style: theme.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.add, size: 18),
                      onPressed: () => _openCategoryPanel(),
                      tooltip: 'Add Category',
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _categories.isEmpty
                        ? const Center(
                            child: Padding(
                            padding: EdgeInsets.all(12),
                            child: Text('No categories.\nTap + to add.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    color: Colors.grey, fontSize: 12)),
                          ))
                        : ListView.builder(
                            itemCount: _categories.length,
                            itemBuilder: (ctx, i) {
                              final cat = _categories[i];
                              final selected =
                                  _selectedCategory?.id == cat.id;
                              return ListTile(
                                selected: selected,
                                selectedTileColor:
                                    InvoisoColors.primary.withOpacity(0.08),
                                contentPadding:
                                    const EdgeInsets.only(left: 12),
                                dense: true,
                                title: Text(cat.name,
                                    style: TextStyle(
                                        fontWeight: selected
                                            ? FontWeight.bold
                                            : null)),
                                onTap: () {
                                  setState(() => _selectedCategory = cat);
                                  _loadItems(cat.id);
                                  setState(() {
                                    _showItemPanel = false;
                                    _showCategoryPanel = false;
                                  });
                                },
                                trailing: PopupMenuButton<String>(
                                  padding: EdgeInsets.zero,
                                  itemBuilder: (ctx) => [
                                    const PopupMenuItem(
                                        value: 'edit',
                                        child: Text('Edit')),
                                    const PopupMenuItem(
                                        value: 'delete',
                                        child: Text('Delete',
                                            style: TextStyle(
                                                color: Colors.red))),
                                  ],
                                  onSelected: (v) {
                                    if (v == 'edit') {
                                      _openCategoryPanel(editing: cat);
                                    } else {
                                      _deleteCategory(cat);
                                    }
                                  },
                                ),
                              );
                            },
                          ),
              ),
            ],
          ),
        ),

        // Items list
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Row(
                  children: [
                    Text(
                      _selectedCategory != null
                          ? _selectedCategory!.name
                          : 'Restaurant Menu',
                      style: theme.textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    if (_selectedCategory != null)
                      FilledButton.icon(
                        onPressed: () => _openItemPanel(),
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Add Item'),
                      ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: _selectedCategory == null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.restaurant_menu_outlined,
                                size: 64, color: Colors.grey.shade400),
                            const SizedBox(height: 12),
                            const Text(
                                'Select a category from the left\nto view and manage menu items.',
                                textAlign: TextAlign.center),
                          ],
                        ),
                      )
                    : _items.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.fastfood_outlined,
                                    size: 64, color: Colors.grey.shade400),
                                const SizedBox(height: 12),
                                const Text('No items in this category.\nTap Add Item to get started.',
                                    textAlign: TextAlign.center),
                              ],
                            ),
                          )
                        : ListView.separated(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 20),
                            itemCount: _items.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1),
                            itemBuilder: (ctx, i) {
                              final item = _items[i];
                              return ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                title: Row(
                                  children: [
                                    Text(item.name,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w500)),
                                    const SizedBox(width: 8),
                                    if (!item.available)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 5, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade200,
                                          borderRadius:
                                              BorderRadius.circular(4),
                                        ),
                                        child: Text('Unavailable',
                                            style: theme.textTheme.labelSmall
                                                ?.copyWith(
                                                    color: Colors.grey)),
                                      ),
                                  ],
                                ),
                                subtitle: Text(
                                  '₹${item.price.toStringAsFixed(2)}'
                                  '${item.taxRate > 0 ? ' + ${item.taxRate.toStringAsFixed(1)}% tax' : ''}'
                                  '${item.ingredients.isNotEmpty ? ' · ${item.ingredients.length} ingredients' : ''}',
                                  style: theme.textTheme.bodySmall,
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit_outlined,
                                          size: 18),
                                      onPressed: () =>
                                          _openItemPanel(editing: item),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline,
                                          size: 18),
                                      onPressed: () => _deleteItem(item),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
              ),
            ],
          ),
        ),

        // Edit panels
        if (_showCategoryPanel) _buildCategoryPanel(theme),
        if (_showItemPanel) _buildItemPanel(theme),
      ],
    );
  }

  Widget _buildCategoryPanel(ThemeData theme) {
    return Container(
      width: 320,
      decoration: BoxDecoration(
        border: Border(
            left: BorderSide(color: theme.colorScheme.outlineVariant)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
            child: Row(
              children: [
                Text(
                    _editingCategory != null
                        ? 'Edit Category'
                        : 'Add Category',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () =>
                      setState(() => _showCategoryPanel = false),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _catFormKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _catNameController,
                      decoration: const InputDecoration(
                          labelText: 'Name *',
                          border: OutlineInputBorder()),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Required'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _catDescController,
                      decoration: const InputDecoration(
                          labelText: 'Description',
                          border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _catOrderController,
                      decoration: const InputDecoration(
                          labelText: 'Display Order',
                          border: OutlineInputBorder()),
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () =>
                      setState(() => _showCategoryPanel = false),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _saveCategory,
                  child: Text(
                      _editingCategory != null ? 'Update' : 'Save'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemPanel(ThemeData theme) {
    return Container(
      width: 380,
      decoration: BoxDecoration(
        border: Border(
            left: BorderSide(color: theme.colorScheme.outlineVariant)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
            child: Row(
              children: [
                Text(_editingItem != null ? 'Edit Item' : 'Add Item',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => setState(() => _showItemPanel = false),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _itemFormKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: _itemNameController,
                      decoration: const InputDecoration(
                          labelText: 'Name *',
                          border: OutlineInputBorder()),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Required'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _itemDescController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                          labelText: 'Description',
                          border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _itemPriceController,
                            decoration: const InputDecoration(
                                labelText: 'Price ₹',
                                border: OutlineInputBorder()),
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                  RegExp(r'[0-9.]'))
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _itemTaxRateController,
                            decoration: const InputDecoration(
                                labelText: 'Tax %',
                                border: OutlineInputBorder()),
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                  RegExp(r'[0-9.]'))
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _itemOrderController,
                            decoration: const InputDecoration(
                                labelText: 'Display Order',
                                border: OutlineInputBorder()),
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: SwitchListTile(
                            title: const Text('Available'),
                            value: _itemAvailable,
                            onChanged: (v) =>
                                setState(() => _itemAvailable = v),
                            dense: true,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Text('Recipe Ingredients',
                            style: theme.textTheme.titleSmall
                                ?.copyWith(
                                    fontWeight: FontWeight.bold)),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: () => setState(
                              () => _ingredientDrafts.add(_IngredientDraft())),
                          icon: const Icon(Icons.add, size: 14),
                          label: const Text('Add'),
                        ),
                      ],
                    ),
                    ..._ingredientDrafts.asMap().entries.map((e) =>
                        _buildIngredientRow(theme, e.key, e.value)),
                  ],
                ),
              ),
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => setState(() => _showItemPanel = false),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _saveItem,
                  child:
                      Text(_editingItem != null ? 'Update' : 'Save'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIngredientRow(
      ThemeData theme, int index, _IngredientDraft d) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: _allProducts.isEmpty
                ? TextFormField(
                    initialValue: d.productName,
                    decoration: const InputDecoration(
                        labelText: 'Product',
                        border: OutlineInputBorder(),
                        isDense: true),
                    onChanged: (v) => d.productName = v,
                  )
                : DropdownButtonFormField<Product>(
                    value: _allProducts
                        .where((p) => p.id == d.productId)
                        .firstOrNull,
                    decoration: const InputDecoration(
                        labelText: 'Product',
                        border: OutlineInputBorder(),
                        isDense: true),
                    items: _allProducts
                        .map((p) => DropdownMenuItem(
                            value: p, child: Text(p.name)))
                        .toList(),
                    onChanged: (p) {
                      if (p != null) {
                        setState(() {
                          d.productId = p.id;
                          d.productName = p.name;
                        });
                      }
                    },
                  ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 70,
            child: TextFormField(
              controller: d.qtyController,
              decoration: const InputDecoration(
                  labelText: 'Qty',
                  border: OutlineInputBorder(),
                  isDense: true),
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 60,
            child: TextFormField(
              initialValue: d.unit,
              decoration: const InputDecoration(
                  labelText: 'Unit',
                  border: OutlineInputBorder(),
                  isDense: true),
              onChanged: (v) => d.unit = v,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline,
                size: 16, color: Colors.red),
            onPressed: () =>
                setState(() => _ingredientDrafts.removeAt(index)),
          ),
        ],
      ),
    );
  }
}

class _IngredientDraft {
  String? id;
  String productId;
  String productName;
  String unit;
  final TextEditingController qtyController;

  _IngredientDraft({
    this.id,
    this.productId = '',
    this.productName = '',
    this.unit = 'g',
    String qty = '1',
  }) : qtyController = TextEditingController(text: qty);

  factory _IngredientDraft.fromIngredient(RecipeIngredient ing) =>
      _IngredientDraft(
        id: ing.id,
        productId: ing.productId,
        productName: ing.productName,
        unit: ing.unit,
        qty: ing.quantity.toStringAsFixed(2),
      );
}
