import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:invoiso/common/invoiso_colors.dart';
import 'package:invoiso/models/supplier.dart';
import 'package:invoiso/models/user.dart';
import 'package:invoiso/providers/repositories.dart';
import 'package:uuid/uuid.dart';

class SupplierManagementScreen extends ConsumerStatefulWidget {
  final User user;
  const SupplierManagementScreen({super.key, required this.user});

  @override
  ConsumerState<SupplierManagementScreen> createState() =>
      _SupplierManagementScreenState();
}

class _SupplierManagementScreenState
    extends ConsumerState<SupplierManagementScreen> {
  List<Supplier> _suppliers = [];
  int _total = 0;
  int _currentPage = 0;
  final int _pageSize = 20;
  String _searchQuery = '';
  bool _isLoading = false;
  Timer? _debounce;
  int _requestId = 0;
  bool _showAddPanel = false;
  Supplier? _editing;

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _gstinController = TextEditingController();
  final _businessNameController = TextEditingController();
  final _contactPersonController = TextEditingController();
  final _notesController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _searchFocusNode = FocusNode();

  static const _uuid = Uuid();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _gstinController.dispose();
    _businessNameController.dispose();
    _contactPersonController.dispose();
    _notesController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final id = ++_requestId;
    setState(() => _isLoading = true);
    final repo = ref.read(supplierRepositoryProvider);
    final q = _searchQuery;
    final offset = _currentPage * _pageSize;
    final results = await repo.getSupplierPage(
        offset: offset, limit: _pageSize, query: q);
    final count = await repo.getSupplierCount(q);
    if (id != _requestId || !mounted) return;
    setState(() {
      _suppliers = results;
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

  void _openAddPanel({Supplier? editing}) {
    _editing = editing;
    if (editing != null) {
      _nameController.text = editing.name;
      _emailController.text = editing.email ?? '';
      _phoneController.text = editing.phone ?? '';
      _addressController.text = editing.address ?? '';
      _gstinController.text = editing.gstin ?? '';
      _businessNameController.text = editing.businessName ?? '';
      _contactPersonController.text = editing.contactPerson ?? '';
      _notesController.text = editing.notes ?? '';
    } else {
      _nameController.clear();
      _emailController.clear();
      _phoneController.clear();
      _addressController.clear();
      _gstinController.clear();
      _businessNameController.clear();
      _contactPersonController.clear();
      _notesController.clear();
    }
    setState(() => _showAddPanel = true);
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final repo = ref.read(supplierRepositoryProvider);
    final now = DateTime.now().toIso8601String();
    if (_editing != null) {
      final updated = Supplier(
        id: _editing!.id,
        name: _nameController.text.trim(),
        email: _emailController.text.trim().isEmpty
            ? null
            : _emailController.text.trim(),
        phone: _phoneController.text.trim().isEmpty
            ? null
            : _phoneController.text.trim(),
        address: _addressController.text.trim().isEmpty
            ? null
            : _addressController.text.trim(),
        gstin: _gstinController.text.trim().isEmpty
            ? null
            : _gstinController.text.trim(),
        businessName: _businessNameController.text.trim().isEmpty
            ? null
            : _businessNameController.text.trim(),
        contactPerson: _contactPersonController.text.trim().isEmpty
            ? null
            : _contactPersonController.text.trim(),
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        createdAt: _editing!.createdAt,
      );
      await repo.updateSupplier(updated);
    } else {
      final supplier = Supplier(
        id: _uuid.v4(),
        name: _nameController.text.trim(),
        email: _emailController.text.trim().isEmpty
            ? null
            : _emailController.text.trim(),
        phone: _phoneController.text.trim().isEmpty
            ? null
            : _phoneController.text.trim(),
        address: _addressController.text.trim().isEmpty
            ? null
            : _addressController.text.trim(),
        gstin: _gstinController.text.trim().isEmpty
            ? null
            : _gstinController.text.trim(),
        businessName: _businessNameController.text.trim().isEmpty
            ? null
            : _businessNameController.text.trim(),
        contactPerson: _contactPersonController.text.trim().isEmpty
            ? null
            : _contactPersonController.text.trim(),
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        createdAt: now,
      );
      await repo.insertSupplier(supplier);
    }
    setState(() => _showAddPanel = false);
    await _load();
  }

  Future<void> _delete(Supplier supplier) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Supplier'),
        content: Text('Delete "${supplier.name}"?'),
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
    await ref.read(supplierRepositoryProvider).deleteSupplier(supplier.id);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(theme),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _suppliers.isEmpty
                        ? _buildEmpty()
                        : _buildList(theme),
              ),
              if (_total > _pageSize) _buildPagination(),
            ],
          ),
        ),
        if (_showAddPanel) _buildAddPanel(theme),
      ],
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      child: Row(
        children: [
          Text('Suppliers',
              style: theme.textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          Text('$_total',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          const Spacer(),
          SizedBox(
            width: 240,
            child: TextField(
              focusNode: _searchFocusNode,
              decoration: const InputDecoration(
                hintText: 'Search suppliers…',
                prefixIcon: Icon(Icons.search, size: 18),
                isDense: true,
                border: OutlineInputBorder(),
              ),
              onChanged: _onSearchChanged,
            ),
          ),
          const SizedBox(width: 12),
          FilledButton.icon(
            onPressed: () => _openAddPanel(),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add Supplier'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.local_shipping_outlined,
              size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text(_searchQuery.isEmpty
              ? 'No suppliers yet.\nTap Add Supplier to get started.'
              : 'No suppliers match "$_searchQuery".'),
        ],
      ),
    );
  }

  Widget _buildList(ThemeData theme) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: _suppliers.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (ctx, i) {
        final s = _suppliers[i];
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          leading: CircleAvatar(
            backgroundColor: InvoisoColors.primary.withOpacity(0.12),
            child: Text(s.name[0].toUpperCase(),
                style: TextStyle(
                    color: InvoisoColors.primary,
                    fontWeight: FontWeight.bold)),
          ),
          title: Text(s.name, style: const TextStyle(fontWeight: FontWeight.w500)),
          subtitle: Text([
            if (s.businessName != null) s.businessName!,
            if (s.phone != null) s.phone!,
            if (s.email != null) s.email!,
          ].join(' · '),
              style: theme.textTheme.bodySmall),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (s.gstin != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(s.gstin!,
                      style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSecondaryContainer)),
                ),
              IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  onPressed: () => _openAddPanel(editing: s)),
              IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18),
                  onPressed: () => _delete(s)),
            ],
          ),
        );
      },
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

  Widget _buildAddPanel(ThemeData theme) {
    return Container(
      width: 360,
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
                Text(_editing != null ? 'Edit Supplier' : 'Add Supplier',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => setState(() => _showAddPanel = false),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                          labelText: 'Name *', border: OutlineInputBorder()),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _businessNameController,
                      decoration: const InputDecoration(
                          labelText: 'Business Name',
                          border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _contactPersonController,
                      decoration: const InputDecoration(
                          labelText: 'Contact Person',
                          border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _phoneController,
                      decoration: const InputDecoration(
                          labelText: 'Phone', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _emailController,
                      decoration: const InputDecoration(
                          labelText: 'Email', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _gstinController,
                      decoration: const InputDecoration(
                          labelText: 'GSTIN', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _addressController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                          labelText: 'Address', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _notesController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                          labelText: 'Notes', border: OutlineInputBorder()),
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
                  onPressed: () => setState(() => _showAddPanel = false),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _save,
                  child: Text(_editing != null ? 'Update' : 'Save'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
