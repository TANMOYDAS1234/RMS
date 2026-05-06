// ─── Inventory Overview - Stock Levels, Low-Stock Alerts, Adjustments ───────

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/app_theme.dart';

class AdminInventoryScreen extends ConsumerWidget {
  const AdminInventoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: slateBg,
      appBar: AppBar(
        backgroundColor: slateBg,
        title: const Text('Inventory Overview', style: TextStyle(color: textPrimary, fontWeight: FontWeight.w700)),
        iconTheme: const IconThemeData(color: textPrimary),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddItemDialog(context),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildAlertsBanner(),
          _buildStatsRow(),
          _buildCategoryFilter(),
          Expanded(child: _buildInventoryList()),
        ],
      ),
    );
  }

  Widget _buildAlertsBanner() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: crimson.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: crimson.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.warning, color: crimson, size: 20),
          const SizedBox(width: 8),
          const Text(
            '3 items running low on stock',
            style: TextStyle(color: crimson, fontWeight: FontWeight.w600),
          ),
          const Spacer(),
          TextButton(
            onPressed: () {},
            child: const Text('View All', style: TextStyle(color: crimson)),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _StatCard('Total Items', '47', azure),
          const SizedBox(width: 12),
          _StatCard('Low Stock', '3', crimson),
          const SizedBox(width: 12),
          _StatCard('Out of Stock', '1', amber),
        ],
      ),
    );
  }

  Widget _buildCategoryFilter() {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _FilterChip('All', true),
          _FilterChip('Vegetables', false),
          _FilterChip('Dairy', false),
          _FilterChip('Spices', false),
          _FilterChip('Beverages', false),
        ],
      ),
    );
  }

  Widget _buildInventoryList() {
    final mockItems = [
      _InventoryItem('Tomatoes', 'Vegetables', 15, 50, 'kg'),
      _InventoryItem('Onions', 'Vegetables', 8, 30, 'kg'),
      _InventoryItem('Paneer', 'Dairy', 2, 10, 'kg'),
      _InventoryItem('Chicken', 'Meat', 0, 25, 'kg'),
      _InventoryItem('Basmati Rice', 'Grains', 45, 100, 'kg'),
    ];

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: mockItems.length,
      itemBuilder: (context, index) {
        final item = mockItems[index];
        return _InventoryItemCard(
          item: item,
          onAdjust: () => _showAdjustmentDialog(context, item),
        );
      },
    );
  }

  void _showAddItemDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => const _InventoryItemFormDialog(),
    );
  }

  void _showAdjustmentDialog(BuildContext context, _InventoryItem item) {
    showDialog(
      context: context,
      builder: (_) => _StockAdjustmentDialog(item: item),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final Color color;

  const _StatCard(this.title, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: slateCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: slateBorder),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: const TextStyle(color: textSecondary, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;

  const _FilterChip(this.label, this.selected);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: selected ? copperAccent.withValues(alpha: 0.2) : slateSurface,
        borderRadius: BorderRadius.circular(25),
        border: Border.all(
          color: selected ? copperAccent : Colors.transparent,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: selected ? copperAccent : textSecondary,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _InventoryItemCard extends StatelessWidget {
  final _InventoryItem item;
  final VoidCallback onAdjust;

  const _InventoryItemCard({
    required this.item,
    required this.onAdjust,
  });

  @override
  Widget build(BuildContext context) {
    final stockLevel = item.currentStock / item.maxStock;
    final stockColor = stockLevel > 0.3 ? emerald : stockLevel > 0.1 ? amber : crimson;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: slateCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: slateBorder),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: stockColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.inventory_2, color: stockColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: const TextStyle(
                        color: textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      item.category,
                      style: const TextStyle(color: textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${item.currentStock} ${item.unit}',
                    style: TextStyle(
                      color: stockColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    'of ${item.maxStock} ${item.unit}',
                    style: const TextStyle(color: textSecondary, fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.edit, color: textSecondary, size: 20),
                onPressed: onAdjust,
              ),
            ],
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: stockLevel,
            backgroundColor: slateSurface,
            valueColor: AlwaysStoppedAnimation(stockColor),
          ),
        ],
      ),
    );
  }
}

class _InventoryItemFormDialog extends StatefulWidget {
  const _InventoryItemFormDialog();

  @override
  State<_InventoryItemFormDialog> createState() => _InventoryItemFormDialogState();
}

class _InventoryItemFormDialogState extends State<_InventoryItemFormDialog> {
  final _nameController = TextEditingController();
  final _maxStockController = TextEditingController();
  String _selectedCategory = 'Vegetables';
  String _selectedUnit = 'kg';

  final _categories = ['Vegetables', 'Dairy', 'Meat', 'Grains', 'Spices', 'Beverages'];
  final _units = ['kg', 'g', 'L', 'ml', 'pcs'];

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: slateCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Add Inventory Item',
              style: TextStyle(
                color: textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _nameController,
              style: const TextStyle(color: textPrimary),
              decoration: const InputDecoration(
                labelText: 'Item Name',
                labelStyle: TextStyle(color: textSecondary),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedCategory,
                    dropdownColor: slateCard,
                    style: const TextStyle(color: textPrimary),
                    decoration: const InputDecoration(
                      labelText: 'Category',
                      labelStyle: TextStyle(color: textSecondary),
                      border: OutlineInputBorder(),
                    ),
                    items: _categories.map((category) {
                      return DropdownMenuItem(
                        value: category,
                        child: Text(category),
                      );
                    }).toList(),
                    onChanged: (category) => setState(() => _selectedCategory = category!),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedUnit,
                    dropdownColor: slateCard,
                    style: const TextStyle(color: textPrimary),
                    decoration: const InputDecoration(
                      labelText: 'Unit',
                      labelStyle: TextStyle(color: textSecondary),
                      border: OutlineInputBorder(),
                    ),
                    items: _units.map((unit) {
                      return DropdownMenuItem(
                        value: unit,
                        child: Text(unit),
                      );
                    }).toList(),
                    onChanged: (unit) => setState(() => _selectedUnit = unit!),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _maxStockController,
              style: const TextStyle(color: textPrimary),
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Maximum Stock',
                labelStyle: TextStyle(color: textSecondary),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(color: textSecondary)),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: copperAccent),
                  onPressed: () {
                    // Add inventory item
                    Navigator.pop(context);
                  },
                  child: const Text('Add', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StockAdjustmentDialog extends StatefulWidget {
  final _InventoryItem item;

  const _StockAdjustmentDialog({required this.item});

  @override
  State<_StockAdjustmentDialog> createState() => _StockAdjustmentDialogState();
}

class _StockAdjustmentDialogState extends State<_StockAdjustmentDialog> {
  final _adjustmentController = TextEditingController();
  String _adjustmentType = 'add';

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: slateCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Adjust Stock - ${widget.item.name}',
              style: const TextStyle(
                color: textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Current: ${widget.item.currentStock} ${widget.item.unit}',
              style: const TextStyle(color: textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _adjustmentType,
                    dropdownColor: slateCard,
                    style: const TextStyle(color: textPrimary),
                    decoration: const InputDecoration(
                      labelText: 'Type',
                      labelStyle: TextStyle(color: textSecondary),
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'add', child: Text('Add Stock')),
                      DropdownMenuItem(value: 'remove', child: Text('Remove Stock')),
                      DropdownMenuItem(value: 'set', child: Text('Set Stock')),
                    ],
                    onChanged: (type) => setState(() => _adjustmentType = type!),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: _adjustmentController,
                    style: const TextStyle(color: textPrimary),
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Amount (${widget.item.unit})',
                      labelStyle: const TextStyle(color: textSecondary),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(color: textSecondary)),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: copperAccent),
                  onPressed: () {
                    // Apply stock adjustment
                    Navigator.pop(context);
                  },
                  child: const Text('Apply', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InventoryItem {
  final String name;
  final String category;
  final double currentStock;
  final double maxStock;
  final String unit;

  _InventoryItem(this.name, this.category, this.currentStock, this.maxStock, this.unit);
}