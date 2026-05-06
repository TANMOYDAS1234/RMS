// ─── Menu Management - Add/Edit/Delete/Toggle Items ──────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/app_theme.dart';

class AdminMenuScreen extends ConsumerWidget {
  const AdminMenuScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: slateBg,
      appBar: AppBar(
        backgroundColor: slateBg,
        title: const Text('Menu Management', style: TextStyle(color: textPrimary, fontWeight: FontWeight.w700)),
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
          _buildCategoryTabs(),
          Expanded(child: _buildMenuItems()),
        ],
      ),
    );
  }

  Widget _buildCategoryTabs() {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _CategoryTab('All', true),
          _CategoryTab('Starters', false),
          _CategoryTab('Main Course', false),
          _CategoryTab('Beverages', false),
          _CategoryTab('Desserts', false),
        ],
      ),
    );
  }

  Widget _buildMenuItems() {
    final mockItems = [
      _MenuItem('Butter Chicken', 'Creamy tomato-based curry', 320, 'Main Course', true),
      _MenuItem('Paneer Tikka', 'Grilled cottage cheese cubes', 280, 'Starters', true),
      _MenuItem('Dal Makhani', 'Rich black lentil curry', 240, 'Main Course', false),
      _MenuItem('Masala Chai', 'Spiced Indian tea', 60, 'Beverages', true),
    ];

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: mockItems.length,
      itemBuilder: (context, index) {
        final item = mockItems[index];
        return _MenuItemCard(
          item: item,
          onEdit: () => _showEditItemDialog(context, item),
          onToggle: () => _toggleItemStatus(item),
          onDelete: () => _deleteItem(item),
        );
      },
    );
  }

  void _showAddItemDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => const _MenuItemFormDialog(),
    );
  }

  void _showEditItemDialog(BuildContext context, _MenuItem item) {
    showDialog(
      context: context,
      builder: (_) => _MenuItemFormDialog(item: item),
    );
  }

  void _toggleItemStatus(_MenuItem item) {
    // Toggle item availability
  }

  void _deleteItem(_MenuItem item) {
    // Delete menu item
  }
}

class _CategoryTab extends StatelessWidget {
  final String label;
  final bool selected;

  const _CategoryTab(this.label, this.selected);

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

class _MenuItemCard extends StatelessWidget {
  final _MenuItem item;
  final VoidCallback onEdit;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  const _MenuItemCard({
    required this.item,
    required this.onEdit,
    required this.onToggle,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: slateCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: slateBorder),
        opacity: item.isAvailable ? 1.0 : 0.6,
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: copperAccent.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.restaurant, color: copperAccent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.name,
                        style: const TextStyle(
                          color: textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      '₹${item.price}',
                      style: const TextStyle(
                        color: copperAccent,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  item.description,
                  style: const TextStyle(color: textSecondary, fontSize: 12),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _CategoryChip(item.category),
                    const SizedBox(width: 8),
                    _AvailabilityChip(item.isAvailable),
                  ],
                ),
              ],
            ),
          ),
          PopupMenuButton(
            color: slateCard,
            child: const Icon(Icons.more_vert, color: textSecondary),
            itemBuilder: (_) => [
              PopupMenuItem(
                child: const Row(children: [Icon(Icons.edit, size: 16), SizedBox(width: 8), Text('Edit')]),
                onTap: onEdit,
              ),
              PopupMenuItem(
                child: Row(children: [
                  Icon(item.isAvailable ? Icons.visibility_off : Icons.visibility, size: 16),
                  const SizedBox(width: 8),
                  Text(item.isAvailable ? 'Hide' : 'Show'),
                ]),
                onTap: onToggle,
              ),
              PopupMenuItem(
                child: const Row(children: [Icon(Icons.delete, color: crimson, size: 16), SizedBox(width: 8), Text('Delete', style: TextStyle(color: crimson))]),
                onTap: onDelete,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String category;

  const _CategoryChip(this.category);

  @override
  Widget build(BuildContext context) {
    final color = switch (category) {
      'Starters' => emerald,
      'Main Course' => copperAccent,
      'Beverages' => azure,
      'Desserts' => violet,
      _ => textSecondary,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        category,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _AvailabilityChip extends StatelessWidget {
  final bool isAvailable;

  const _AvailabilityChip(this.isAvailable);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: (isAvailable ? emerald : crimson).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        isAvailable ? 'AVAILABLE' : 'HIDDEN',
        style: TextStyle(
          color: isAvailable ? emerald : crimson,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _MenuItemFormDialog extends StatefulWidget {
  final _MenuItem? item;

  const _MenuItemFormDialog({this.item});

  @override
  State<_MenuItemFormDialog> createState() => _MenuItemFormDialogState();
}

class _MenuItemFormDialogState extends State<_MenuItemFormDialog> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  String _selectedCategory = 'Main Course';

  final _categories = ['Starters', 'Main Course', 'Beverages', 'Desserts'];

  @override
  void initState() {
    super.initState();
    if (widget.item != null) {
      _nameController.text = widget.item!.name;
      _descriptionController.text = widget.item!.description;
      _priceController.text = widget.item!.price.toString();
      _selectedCategory = widget.item!.category;
    }
  }

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
              widget.item == null ? 'Add Menu Item' : 'Edit Menu Item',
              style: const TextStyle(
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
            TextField(
              controller: _descriptionController,
              style: const TextStyle(color: textPrimary),
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Description',
                labelStyle: TextStyle(color: textSecondary),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _priceController,
                    style: const TextStyle(color: textPrimary),
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Price (₹)',
                      labelStyle: TextStyle(color: textSecondary),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
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
                    // Save menu item
                    Navigator.pop(context);
                  },
                  child: Text(
                    widget.item == null ? 'Add' : 'Save',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuItem {
  final String name;
  final String description;
  final int price;
  final String category;
  final bool isAvailable;

  _MenuItem(this.name, this.description, this.price, this.category, this.isAvailable);
}