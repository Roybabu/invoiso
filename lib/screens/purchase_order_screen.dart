import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:invoiso/common/invoiso_colors.dart';
import 'package:invoiso/models/purchase_order.dart';
import 'package:invoiso/models/supplier.dart';
import 'package:invoiso/models/user.dart';
import 'package:invoiso/providers/repositories.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

class PurchaseOrderScreen extends ConsumerStatefulWidget {
  final User user;
  const PurchaseOrderScreen({super.key, required this.user});

  @override
  ConsumerState<PurchaseOrderScreen> createState() =>
      _PurchaseOrderScreenState();
}

class _PurchaseOrderScreenState extends ConsumerState<PurchaseOrderScreen> {
  List<PurchaseOrder> _pos = [];
  int _total = 0;
  int _currentPage = 0;
  final int _pageSize = 20;
  String _searchQuery = '';
  String? _statusFilter;
  bool _isLoading = false;
  Timer? _debounce;
  int _requestId = 0;

  // View
  PurchaseOrder? _viewingPO;
  bool _showCreateForm = false;

  // Create form
  Supplier? _selectedSupplier;
  List<Supplier> _allSuppliers = [];
  final _notesController = TextEditingController();
  final _expectedDateController = TextEditingController();
  DateTime? _expectedDate;
  final List<_POItemDraft> _draftItems = [];

  final _formKey = GlobalKey<FormState>();
  static const _uuid = Uuid();
  static final _dateFormat = DateFormat('dd/MM/yyyy');
  static final _dtFormat = DateFormat('dd MMM yyyy');

  static const _statuses = ['draft', 'ordered', 'partial', 'received', 'cancelled'];
  static const _statusColors = {
    'draft': Colors.grey,
    'ordered': Colors.blue,
    'partial': Colors.orange,
    'received': Colors.green,
    'cancelled': Colors.red,
  };

  @override
  void initState() {
    super.initState();
    _loadSuppliers();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _notesController.dispose();
    _expectedDateController.dispose();
    super.dispose();
  }

  Future<void> _loadSuppliers() async {
    final suppliers =
        await ref.read(supplierRepositoryProvider).getAllSuppliers();
    if (!mounted) return;
    setState(() => _allSuppliers = suppliers);
  }

  Future<void> _load() async {
    final id = ++_requestId;
    setState(() => _isLoading = true);
    final repo = ref.read(purchaseOrderRepositoryProvider);
    final results = await repo.getPurchaseOrdersPage(
      offset: _currentPage * _pageSize,
      limit: _pageSize,
      query: _searchQuery,
      status: _statusFilter,
    );
    final count = await repo.getPurchaseOrderCount(
        query: _searchQuery, status: _statusFilter);
    if (id != _requestId || !mounted) return;
    setState(() {
      _pos = results;
      _total = count;
      _isLoading = false;
    });
  }

  void _onSearchChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      setState(() {
        _searchQuery = v;
        _currentPage = 0;
      });
      _load();
    });
  }

  Future<void> _receivePO(PurchaseOrder po) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Mark as Received'),
        content: Text(
            'Record receipt of all items in PO #${po.id.substring(0, 8)}? Stock will be updated.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Receive')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ref.read(purchaseOrderRepositoryProvider).receivePurchaseOrder(po.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('PO received and stock updated.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
    await _load();
  }

  Future<void> _deletePO(PurchaseOrder po) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Purchase Order'),
        content: Text('Delete this PO from ${po.supplierName}?'),
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
    await ref.read(purchaseOrderRepositoryProvider).deletePurchaseOrder(po.id);
    setState(() {
      if (_viewingPO?.id == po.id) _viewingPO = null;
    });
    await _load();
  }

  Future<void> _savePO() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_selectedSupplier == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Please select a supplier')));
      return;
    }
    if (_draftItems.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Add at least one item')));
      return;
    }

    final now = DateTime.now().toIso8601String();
    final poId = _uuid.v4();
    final items = _draftItems
        .where((d) => d.productId.isNotEmpty)
        .map((d) => PurchaseOrderItem(
              id: _uuid.v4(),
              poId: poId,
              productId: d.productId,
              productName: d.productName,
              quantity: double.tryParse(d.qtyController.text) ?? 0,
              unitCost: double.tryParse(d.costController.text) ?? 0,
              receivedQty: 0,
              notes: null,
            ))
        .toList();

    final totalAmount = items.fold(
        0.0, (sum, item) => sum + item.quantity * item.unitCost);

    final po = PurchaseOrder(
      id: poId,
      supplierId: _selectedSupplier!.id,
      supplierName: _selectedSupplier!.name,
      date: now,
      expectedDate: _expectedDate?.toIso8601String(),
      status: 'ordered',
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
      totalAmount: totalAmount,
      createdAt: now,
      items: items,
    );

    await ref.read(purchaseOrderRepositoryProvider).insertPurchaseOrder(po);
    setState(() {
      _showCreateForm = false;
      _selectedSupplier = null;
      _draftItems.clear();
      _notesController.clear();
      _expectedDateController.clear();
      _expectedDate = null;
    });
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_viewingPO != null) {
      return _buildDetailView(theme, _viewingPO!);
    }
    if (_showCreateForm) {
      return _buildCreateForm(theme);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(theme),
        _buildFilters(theme),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _pos.isEmpty
                  ? _buildEmpty()
                  : _buildList(theme),
        ),
        if (_total > _pageSize) _buildPagination(),
      ],
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Row(
        children: [
          Text('Purchase Orders',
              style: theme.textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          Text('$_total',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          const Spacer(),
          SizedBox(
            width: 220,
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search POs…',
                prefixIcon: Icon(Icons.search, size: 18),
                isDense: true,
                border: OutlineInputBorder(),
              ),
              onChanged: _onSearchChanged,
            ),
          ),
          const SizedBox(width: 12),
          FilledButton.icon(
            onPressed: () => setState(() => _showCreateForm = true),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('New PO'),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters(ThemeData theme) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: Row(
        children: [
          _filterChip('All', null),
          const SizedBox(width: 8),
          ..._statuses.map((s) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _filterChip(
                    s[0].toUpperCase() + s.substring(1), s),
              )),
        ],
      ),
    );
  }

  Widget _filterChip(String label, String? status) {
    final selected = _statusFilter == status;
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) {
        setState(() {
          _statusFilter = selected ? null : status;
          _currentPage = 0;
        });
        _load();
      },
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.shopping_cart_outlined,
              size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text(_searchQuery.isEmpty
              ? 'No purchase orders yet.\nTap New PO to create one.'
              : 'No POs match "$_searchQuery".'),
        ],
      ),
    );
  }

  Widget _buildList(ThemeData theme) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: _pos.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (ctx, i) {
        final po = _pos[i];
        final color =
            _statusColors[po.status] ?? Colors.grey;
        return ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          title: Row(
            children: [
              Text(po.supplierName,
                  style: const TextStyle(fontWeight: FontWeight.w500)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(po.status,
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: color, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          subtitle: Text(
              '${_dtFormat.format(DateTime.parse(po.date))} · ${po.items.length} items · ₹${po.totalAmount.toStringAsFixed(2)}',
              style: theme.textTheme.bodySmall),
          onTap: () => setState(() => _viewingPO = po),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (po.status != 'received' && po.status != 'cancelled')
                IconButton(
                  icon: const Icon(Icons.check_circle_outline, size: 18),
                  tooltip: 'Mark Received',
                  onPressed: () => _receivePO(po),
                ),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 18),
                onPressed: () => _deletePO(po),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailView(ThemeData theme, PurchaseOrder po) {
    final color = _statusColors[po.status] ?? Colors.grey;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () async {
                  final fresh = await ref
                      .read(purchaseOrderRepositoryProvider)
                      .getPurchaseOrderById(po.id);
                  setState(() => _viewingPO = null);
                  await _load();
                },
              ),
              const SizedBox(width: 8),
              Text('Purchase Order',
                  style: theme.textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(width: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(po.status,
                    style: TextStyle(
                        color: color, fontWeight: FontWeight.bold)),
              ),
              const Spacer(),
              if (po.status != 'received' && po.status != 'cancelled')
                FilledButton.icon(
                  onPressed: () => _receivePO(po),
                  icon: const Icon(Icons.check_circle_outline, size: 18),
                  label: const Text('Mark Received'),
                ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () => _deletePO(po),
                icon: const Icon(Icons.delete_outline, size: 18),
                label: const Text('Delete'),
                style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _detailRow('Supplier', po.supplierName),
                _detailRow('Date',
                    _dtFormat.format(DateTime.parse(po.date))),
                if (po.expectedDate != null)
                  _detailRow('Expected',
                      _dtFormat.format(DateTime.parse(po.expectedDate!))),
                if (po.notes != null) _detailRow('Notes', po.notes!),
                const SizedBox(height: 20),
                Text('Items',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ...po.items.map((item) => Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item.productName,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w500)),
                                  Text(
                                      'Qty: ${item.quantity.toStringAsFixed(2)} · Cost: ₹${item.unitCost.toStringAsFixed(2)}',
                                      style: theme.textTheme.bodySmall),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                    '₹${(item.quantity * item.unitCost).toStringAsFixed(2)}',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold)),
                                Text(
                                    'Received: ${item.receivedQty.toStringAsFixed(2)}',
                                    style: theme.textTheme.bodySmall),
                              ],
                            ),
                          ],
                        ),
                      ),
                    )),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text('Total: ₹${po.totalAmount.toStringAsFixed(2)}',
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
              width: 100,
              child: Text(label,
                  style: const TextStyle(color: Colors.grey))),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Widget _buildCreateForm(ThemeData theme) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() => _showCreateForm = false),
              ),
              Text('New Purchase Order',
                  style: theme.textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Supplier
                  DropdownButtonFormField<Supplier>(
                    value: _selectedSupplier,
                    decoration: const InputDecoration(
                        labelText: 'Supplier *',
                        border: OutlineInputBorder()),
                    items: _allSuppliers
                        .map((s) => DropdownMenuItem(
                            value: s, child: Text(s.name)))
                        .toList(),
                    onChanged: (s) =>
                        setState(() => _selectedSupplier = s),
                    validator: (v) =>
                        v == null ? 'Please select a supplier' : null,
                  ),
                  const SizedBox(height: 12),
                  // Expected Date
                  TextFormField(
                    controller: _expectedDateController,
                    readOnly: true,
                    decoration: const InputDecoration(
                      labelText: 'Expected Date',
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.calendar_today, size: 18),
                    ),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime.now(),
                        lastDate:
                            DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked != null) {
                        setState(() {
                          _expectedDate = picked;
                          _expectedDateController.text =
                              _dateFormat.format(picked);
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _notesController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                        labelText: 'Notes', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Text('Items',
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold)),
                      const Spacer(),
                      OutlinedButton.icon(
                        onPressed: _addItem,
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Add Item'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ..._draftItems.asMap().entries.map((e) =>
                      _buildDraftItemRow(theme, e.key, e.value)),
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
                onPressed: () => setState(() => _showCreateForm = false),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _savePO,
                child: const Text('Create PO'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _addItem() {
    setState(() => _draftItems.add(_POItemDraft()));
  }

  Widget _buildDraftItemRow(ThemeData theme, int index, _POItemDraft item) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: LayoutBuilder(
          builder: (ctx, constraints) {
            final isMobile = constraints.maxWidth < 500;
            final fields = [
              // Product name
              Expanded(
                flex: 3,
                child: TextFormField(
                  controller: item.nameController,
                  decoration: const InputDecoration(
                      labelText: 'Product Name',
                      border: OutlineInputBorder(),
                      isDense: true),
                  onChanged: (v) => item.productName = v,
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Required'
                      : null,
                ),
              ),
              SizedBox(width: isMobile ? 0 : 8, height: isMobile ? 8 : 0),
              // Qty
              SizedBox(
                width: isMobile ? double.infinity : 80,
                child: TextFormField(
                  controller: item.qtyController,
                  decoration: const InputDecoration(
                      labelText: 'Qty',
                      border: OutlineInputBorder(),
                      isDense: true),
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                        RegExp(r'[0-9.]'))
                  ],
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Required';
                    if ((double.tryParse(v) ?? 0) <= 0) return '>0';
                    return null;
                  },
                ),
              ),
              SizedBox(width: isMobile ? 0 : 8, height: isMobile ? 8 : 0),
              // Cost
              SizedBox(
                width: isMobile ? double.infinity : 100,
                child: TextFormField(
                  controller: item.costController,
                  decoration: const InputDecoration(
                      labelText: 'Unit Cost',
                      border: OutlineInputBorder(),
                      isDense: true),
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                        RegExp(r'[0-9.]'))
                  ],
                ),
              ),
            ];

            return Column(
              children: [
                isMobile
                    ? Column(children: fields)
                    : Row(children: fields),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () =>
                        setState(() => _draftItems.removeAt(index)),
                    icon: const Icon(Icons.delete_outline,
                        size: 16, color: Colors.red),
                    label: const Text('Remove',
                        style: TextStyle(color: Colors.red)),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildPagination() {
    final totalPages = (_total / _pageSize).ceil();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text('Page ${_currentPage + 1} of $totalPages'),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: _currentPage > 0
                ? () {
                    setState(() => _currentPage--);
                    _load();
                  }
                : null,
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: _currentPage < totalPages - 1
                ? () {
                    setState(() => _currentPage++);
                    _load();
                  }
                : null,
          ),
        ],
      ),
    );
  }
}

class _POItemDraft {
  String productId = '';
  String productName = '';
  final TextEditingController nameController = TextEditingController();
  final TextEditingController qtyController = TextEditingController(text: '1');
  final TextEditingController costController =
      TextEditingController(text: '0');
}
