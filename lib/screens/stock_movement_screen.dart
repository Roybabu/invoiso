import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:invoiso/models/stock_movement.dart';
import 'package:invoiso/models/user.dart';
import 'package:invoiso/providers/repositories.dart';
import 'package:intl/intl.dart';

class StockMovementScreen extends ConsumerStatefulWidget {
  final User user;
  const StockMovementScreen({super.key, required this.user});

  @override
  ConsumerState<StockMovementScreen> createState() =>
      _StockMovementScreenState();
}

class _StockMovementScreenState extends ConsumerState<StockMovementScreen> {
  List<StockMovement> _movements = [];
  int _total = 0;
  int _currentPage = 0;
  final int _pageSize = 30;
  String? _typeFilter;
  String? _fromDate;
  String? _toDate;
  bool _isLoading = false;
  int _requestId = 0;
  Map<String, double> _summary = {};

  static final _dtFormat = DateFormat('dd MMM yyyy HH:mm');
  static final _dateFormat = DateFormat('yyyy-MM-dd');

  static const _types = [
    'purchase',
    'sale',
    'adjustment',
    'wastage',
    'return',
    'opening',
    'manual',
  ];
  static const _typeColors = {
    'purchase': Colors.green,
    'sale': Colors.blue,
    'adjustment': Colors.orange,
    'wastage': Colors.red,
    'return': Colors.teal,
    'opening': Colors.purple,
    'manual': Colors.grey,
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final id = ++_requestId;
    setState(() => _isLoading = true);
    final repo = ref.read(stockMovementRepositoryProvider);
    final results = await repo.getMovementsPage(
      offset: _currentPage * _pageSize,
      limit: _pageSize,
      movementType: _typeFilter,
      fromDate: _fromDate,
      toDate: _toDate,
    );
    final count = await repo.getMovementsCount(
      movementType: _typeFilter,
      fromDate: _fromDate,
      toDate: _toDate,
    );
    final summary = await repo.getStockSummary(
        fromDate: _fromDate, toDate: _toDate);
    if (id != _requestId || !mounted) return;
    setState(() {
      _movements = results;
      _total = count;
      _summary = summary;
      _isLoading = false;
    });
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked == null) return;
    setState(() {
      if (isFrom) {
        _fromDate = _dateFormat.format(picked);
      } else {
        _toDate =
            '${_dateFormat.format(picked)}T23:59:59';
      }
      _currentPage = 0;
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(theme),
        _buildFilters(theme),
        if (_summary.isNotEmpty) _buildSummaryCards(theme),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _movements.isEmpty
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
          Text('Stock Movements',
              style: theme.textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          Text('$_total',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }

  Widget _buildFilters(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        children: [
          // Type filter chips
          FilterChip(
            label: const Text('All Types'),
            selected: _typeFilter == null,
            onSelected: (_) {
              setState(() {
                _typeFilter = null;
                _currentPage = 0;
              });
              _load();
            },
          ),
          ..._types.map((t) => FilterChip(
                label: Text(t[0].toUpperCase() + t.substring(1)),
                selected: _typeFilter == t,
                selectedColor:
                    (_typeColors[t] ?? Colors.grey).withOpacity(0.2),
                onSelected: (_) {
                  setState(() {
                    _typeFilter = _typeFilter == t ? null : t;
                    _currentPage = 0;
                  });
                  _load();
                },
              )),
          // Date range
          ActionChip(
            avatar: const Icon(Icons.calendar_today, size: 14),
            label:
                Text(_fromDate != null ? 'From: $_fromDate' : 'From Date'),
            onPressed: () => _pickDate(isFrom: true),
          ),
          ActionChip(
            avatar: const Icon(Icons.calendar_today, size: 14),
            label:
                Text(_toDate != null ? 'To: ${_toDate!.substring(0, 10)}' : 'To Date'),
            onPressed: () => _pickDate(isFrom: false),
          ),
          if (_fromDate != null || _toDate != null)
            ActionChip(
              avatar: const Icon(Icons.clear, size: 14),
              label: const Text('Clear Dates'),
              onPressed: () {
                setState(() {
                  _fromDate = null;
                  _toDate = null;
                  _currentPage = 0;
                });
                _load();
              },
            ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards(ThemeData theme) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: Row(
        children: _summary.entries.map((e) {
          final color = _typeColors[e.key] ?? Colors.grey;
          return Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color.withOpacity(0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(e.key[0].toUpperCase() + e.key.substring(1),
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: color)),
                Text(e.value.abs().toStringAsFixed(0),
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.bold)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.swap_vert_outlined,
              size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          const Text('No stock movements found.'),
        ],
      ),
    );
  }

  Widget _buildList(ThemeData theme) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: _movements.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (ctx, i) {
        final m = _movements[i];
        final color = _typeColors[m.movementType] ?? Colors.grey;
        final qty = m.quantity;
        final qtyStr = qty >= 0 ? '+${qty.toStringAsFixed(2)}' : qty.toStringAsFixed(2);
        return ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Icon(
                qty >= 0 ? Icons.arrow_downward : Icons.arrow_upward,
                color: color,
                size: 20,
              ),
            ),
          ),
          title: Text(m.productName,
              style: const TextStyle(fontWeight: FontWeight.w500)),
          subtitle: Text(
            '${m.movementType} · ${_dtFormat.format(DateTime.parse(m.date))}'
            '${m.notes != null ? ' · ${m.notes}' : ''}',
            style: theme.textTheme.bodySmall,
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(qtyStr,
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: qty >= 0 ? Colors.green : Colors.red)),
              Text('${m.beforeStock} → ${m.afterStock}',
                  style: theme.textTheme.bodySmall),
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
}
