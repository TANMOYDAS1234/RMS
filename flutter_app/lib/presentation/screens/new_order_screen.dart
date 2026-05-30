import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/config/app_theme.dart';
import '../state/auth_provider.dart';
import '../state/menu_provider.dart';
import '../state/tables_provider.dart';
import '../state/order_providers.dart';

class NewOrderScreen extends ConsumerStatefulWidget {
  const NewOrderScreen({super.key});

  @override
  ConsumerState<NewOrderScreen> createState() => _NewOrderScreenState();
}

class _NewOrderScreenState extends ConsumerState<NewOrderScreen> {
  TableModel? _selectedTable;
  final Map<String, int> _cart = {}; // itemId → quantity
  final TextEditingController _notesCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tablesAsync = ref.watch(tablesProvider);
    final branchId = ref.watch(authProvider).user?.branchId;
    final menuAsync = ref.watch(menuProvider(branchId));

    return Scaffold(
      backgroundColor: slateBg,
      appBar: AppBar(
        title: const Text('New Order'),
        backgroundColor: slateBg,
        actions: [
          if (_cart.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Text(
                  '${_cart.values.fold(0, (a, b) => a + b)} items',
                  style: const TextStyle(color: copperAccent, fontWeight: FontWeight.w700),
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Table selector
          Container(
            margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            padding: const EdgeInsets.all(14),
            constraints: const BoxConstraints(maxHeight: 180),
            decoration: BoxDecoration(
              color: slateCard,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: dividerColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Select Table', style: TextStyle(color: textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 10),
                Flexible(
                  child: tablesAsync.when(
                    loading: () => const LinearProgressIndicator(color: copperAccent),
                    error: (e, _) => Text('Error: $e', style: const TextStyle(color: crimson)),
                    data: (tables) => SingleChildScrollView(
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: tables.map((t) {
                          final selected = _selectedTable?.id == t.id;
                          return GestureDetector(
                            onTap: t.isAvailable ? () => setState(() => _selectedTable = t) : null,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: selected
                                    ? copperAccent.withValues(alpha: 0.2)
                                    : t.isAvailable
                                        ? slateSurface
                                        : slateSurface.withValues(alpha: 0.4),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: selected ? copperAccent : t.isAvailable ? dividerColor : Colors.transparent,
                                ),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    t.label,
                                    style: TextStyle(
                                      color: selected ? copperAccent : t.isAvailable ? textPrimary : textSecondary,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    t.isAvailable ? '${t.capacity}p' : 'Busy',
                                    style: TextStyle(
                                      color: t.isAvailable ? textSecondary : crimson,
                                      fontSize: 9,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Menu
          Expanded(
            child: menuAsync.when(
              loading: () => const Center(child: CircularProgressIndicator(color: copperAccent)),
              error: (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: crimson))),
              data: (items) {
                final categories = items.map((i) => i.category).toSet().toList()..sort();
                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                  children: categories.map((cat) {
                    final catItems = items.where((i) => i.category == cat && i.isAvailable).toList();
                    if (catItems.isEmpty) return const SizedBox.shrink();
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Text(cat, style: const TextStyle(color: textSecondary, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1)),
                        ),
                        ...catItems.map((item) => _MenuItemTile(
                              item: item,
                              quantity: _cart[item.id] ?? 0,
                              onAdd: () => setState(() => _cart[item.id] = (_cart[item.id] ?? 0) + 1),
                              onRemove: () => setState(() {
                                final q = (_cart[item.id] ?? 0) - 1;
                                if (q <= 0) {
                                  _cart.remove(item.id);
                                } else {
                                  _cart[item.id] = q;
                                }
                              }),
                            )),
                      ],
                    );
                  }).toList(),
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: _cart.isEmpty
          ? null
          : _buildOrderFooter(context),
    );
  }

  /// Footer with notes field + Place Order button. Used to be a FAB which
  /// hid the notes; this layout keeps both visible while the cart has
  /// items. Falls back to nothing when the cart is empty.
  Widget _buildOrderFooter(BuildContext context) => Container(
        padding: EdgeInsets.fromLTRB(
            12, 10, 12, MediaQuery.of(context).viewInsets.bottom + 12),
        decoration: const BoxDecoration(
          color: slateCard,
          border: Border(top: BorderSide(color: dividerColor)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: _notesCtrl,
            style: const TextStyle(color: textPrimary, fontSize: 13),
            maxLines: 2,
            minLines: 1,
            decoration: InputDecoration(
              hintText: 'Notes (allergies, "no onions", VIP, …)',
              hintStyle:
                  const TextStyle(color: textSecondary, fontSize: 12),
              filled: true,
              fillColor: slateSurface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: dividerColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: dividerColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: copperAccent),
              ),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 8),
              prefixIcon: const Icon(Icons.note_alt_outlined,
                  color: textSecondary, size: 18),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: _submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.check, size: 18),
              label: Text(
                _selectedTable == null ? 'Pick a table' : 'Place Order',
                style: const TextStyle(
                    fontWeight: FontWeight.w800, fontSize: 14),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: copperAccent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed:
                  (_submitting || _selectedTable == null) ? null : _placeOrder,
            ),
          ),
        ]),
      );

  Future<void> _placeOrder() async {
    if (_selectedTable == null || _cart.isEmpty) return;
    setState(() => _submitting = true);

    final branchId = ref.read(authProvider).user?.branchId;
    final menuItems = ref.read(menuProvider(branchId)).value ?? [];
    final items = _cart.entries.map((e) {
      final item = menuItems.firstWhere((m) => m.id == e.key);
      return {
        'itemId': item.id,
        'name': item.name,
        'quantity': e.value,
        'unitPrice': item.basePrice,
      };
    }).toList();

    final notes = _notesCtrl.text.trim();
    await ref.read(liveOrdersProvider.notifier).createOrder(
          tableId: _selectedTable!.id,
          tableLabel: _selectedTable!.label,
          items: items,
          notes: notes.isEmpty ? null : notes,
        );

    if (mounted) Navigator.pop(context);
  }
}

class _MenuItemTile extends StatelessWidget {
  final MenuItemModel item;
  final int quantity;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  const _MenuItemTile({required this.item, required this.quantity, required this.onAdd, required this.onRemove});

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: slateCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: quantity > 0 ? copperAccent.withValues(alpha: 0.4) : dividerColor),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.name, style: const TextStyle(color: textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text('₹${item.basePrice.toStringAsFixed(2)}', style: const TextStyle(color: copperAccent, fontSize: 12, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
            if (quantity == 0)
              GestureDetector(
                onTap: onAdd,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(color: copperAccent.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.add, color: copperAccent, size: 18),
                ),
              )
            else
              Row(
                children: [
                  GestureDetector(
                    onTap: onRemove,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(color: slateSurface, borderRadius: BorderRadius.circular(8)),
                      child: const Icon(Icons.remove, color: textSecondary, size: 18),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Text('$quantity', style: const TextStyle(color: textPrimary, fontSize: 14, fontWeight: FontWeight.w700)),
                  ),
                  GestureDetector(
                    onTap: onAdd,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(color: copperAccent.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                      child: const Icon(Icons.add, color: copperAccent, size: 18),
                    ),
                  ),
                ],
              ),
          ],
        ),
      );
}
