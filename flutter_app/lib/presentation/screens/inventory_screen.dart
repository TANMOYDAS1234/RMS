import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/config/app_theme.dart';
import '../../core/network/dio_client.dart';
import '../../core/utils/idempotency.dart';
import '../../domain/entities/user_entity.dart';
import '../state/auth_provider.dart';

class InventoryItem {
  final String id;
  final String name;
  final String unit;
  final double currentStock;
  final double lowStockThreshold;
  final double costPerUnit;
  // True when a chef added the item under chefCanManageInventory and the
  // manager hasn't audited the cost/threshold yet. Pure soft flag — the
  // item is fully usable; the badge just nudges the manager to verify.
  final bool pendingReview;

  const InventoryItem({
    required this.id,
    required this.name,
    required this.unit,
    required this.currentStock,
    required this.lowStockThreshold,
    required this.costPerUnit,
    this.pendingReview = false,
  });

  factory InventoryItem.fromJson(Map<String, dynamic> j) => InventoryItem(
        id: j['_id'] ?? j['id'] ?? '',
        name: j['name'] ?? '',
        unit: j['unit'] ?? '',
        currentStock: (j['currentStock'] ?? 0).toDouble(),
        lowStockThreshold: (j['lowStockThreshold'] ?? 0).toDouble(),
        costPerUnit: (j['costPerUnit'] ?? 0).toDouble(),
        pendingReview: j['pendingReview'] == true,
      );

  bool get isLow => currentStock <= lowStockThreshold;
}

final inventoryProvider = FutureProvider.autoDispose<List<InventoryItem>>((ref) async {
  final token = ref.watch(authProvider).token;
  final dio = createDioClient(token);
  final res = await dio.get('/inventory');
  return (res.data as List).map((j) => InventoryItem.fromJson(j)).toList();
});

class InventoryScreen extends ConsumerWidget {
  const InventoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inventoryAsync = ref.watch(inventoryProvider);
    final role = ref.watch(authProvider).user?.role;
    // Admin + manager always have the Add power. Chef gets it too — the
    // backend re-checks the branch's chefCanManageInventory toggle and
    // 403s with a helpful message if the chef's branch hasn't enabled
    // it. We surface the FAB optimistically so chefs on enabled branches
    // see it without an extra round-trip; the 403 path falls through to
    // the snackbar inside _showAddSheet.
    final canAttemptAdd = role == UserRole.admin ||
        role == UserRole.manager ||
        role == UserRole.chef;

    return Scaffold(
      backgroundColor: slateBg,
      floatingActionButton: canAttemptAdd
          ? FloatingActionButton.extended(
              backgroundColor: copperAccent,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add),
              label: const Text('Add Ingredient',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              onPressed: () => _showAddSheet(context, ref, role!),
            )
          : null,
      appBar: AppBar(
        title: const Text('INVENTORY'),
        backgroundColor: slateBg,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: textSecondary),
            onPressed: () => ref.invalidate(inventoryProvider),
          ),
        ],
      ),
      body: inventoryAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: copperAccent)),
        error: (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: crimson))),
        data: (items) {
          // Empty inventory is the default state on a fresh branch — chef
          // can't add ingredients (manager/admin do that), so without a
          // copy line they'd just see a blank screen and think it broke.
          if (items.isEmpty) {
            final role = ref.read(authProvider).user?.role;
            final canAdd = role == UserRole.admin || role == UserRole.manager;
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.inventory_2_outlined,
                        size: 64, color: textSecondary.withValues(alpha: 0.4)),
                    const SizedBox(height: 18),
                    const Text('No ingredients yet',
                        style: TextStyle(
                            color: textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w800)),
                    const SizedBox(height: 6),
                    Text(
                      canAdd
                          ? 'Add your first ingredient to start tracking stock for this branch.'
                          : 'Ask your manager to add the ingredients you cook with.\nOnce they appear here, you can adjust stock after each shift.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: textSecondary, fontSize: 13, height: 1.4),
                    ),
                  ],
                ),
              ),
            );
          }
          final lowItems = items.where((i) => i.isLow).toList();
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (lowItems.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: crimson.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: crimson.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_outlined, color: crimson, size: 18),
                      const SizedBox(width: 8),
                      Text('${lowItems.length} items low on stock', style: const TextStyle(color: crimson, fontWeight: FontWeight.w600, fontSize: 13)),
                    ],
                  ),
                ),
              ],
              ...items.map((item) => _InventoryCard(item: item, ref: ref)),
            ],
          );
        },
      ),
    );
  }

  /// Add-ingredient bottom sheet. Same UI for chef/manager/admin; the
  /// backend decides whether the chef's add gets through (depends on the
  /// branch's chefCanManageInventory toggle) and tags it pendingReview.
  /// We don't need to read the toggle on the client — we let the server
  /// be the source of truth.
  void _showAddSheet(BuildContext context, WidgetRef ref, UserRole role) {
    final nameCtrl = TextEditingController();
    final unitCtrl = TextEditingController(text: 'kg');
    final stockCtrl = TextEditingController(text: '0');
    final thresholdCtrl = TextEditingController(text: '5');
    final costCtrl = TextEditingController(text: '0');

    showModalBottomSheet(
      context: context,
      backgroundColor: slateCard,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
            24, 20, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 36, height: 4,
            decoration: BoxDecoration(
              color: textSecondary.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 14),
          const Text('Add Ingredient',
              style: TextStyle(
                  color: textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w800)),
          if (role == UserRole.chef) ...[
            const SizedBox(height: 4),
            const Text(
                'Your manager will review the cost and threshold after you add it.',
                textAlign: TextAlign.center,
                style: TextStyle(color: textSecondary, fontSize: 11)),
          ],
          const SizedBox(height: 16),
          _Field(label: 'Name', controller: nameCtrl),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _Field(label: 'Unit (kg, litre, pcs)', controller: unitCtrl)),
            const SizedBox(width: 10),
            Expanded(
                child: _Field(
                    label: 'Current stock',
                    controller: stockCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true))),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
                child: _Field(
                    label: 'Low-stock threshold',
                    controller: thresholdCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true))),
            const SizedBox(width: 10),
            Expanded(
                child: _Field(
                    label: 'Cost / unit (₹)',
                    controller: costCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true))),
          ]),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.check, size: 16),
              label: const Text('Add'),
              style: ElevatedButton.styleFrom(
                backgroundColor: copperAccent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                textStyle: const TextStyle(fontWeight: FontWeight.w800),
              ),
              onPressed: () async {
                final name = nameCtrl.text.trim();
                final unit = unitCtrl.text.trim();
                final stock = double.tryParse(stockCtrl.text);
                final threshold = double.tryParse(thresholdCtrl.text);
                final cost = double.tryParse(costCtrl.text);
                if (name.isEmpty || unit.isEmpty || stock == null || threshold == null || cost == null) {
                  return;
                }
                Navigator.pop(ctx);
                final token = ref.read(authProvider).token;
                final branchId = ref.read(authProvider).user?.branchId;
                try {
                  final dio = createDioClient(token);
                  await dio.post(
                    '/inventory',
                    data: {
                      'name': name,
                      'unit': unit,
                      'currentStock': stock,
                      'lowStockThreshold': threshold,
                      'costPerUnit': cost,
                      if (branchId != null) 'branchId': branchId,
                    },
                    options: Options(headers: {
                      'Idempotency-Key': newIdempotencyKey('ingredient-add'),
                    }),
                  );
                  ref.invalidate(inventoryProvider);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      backgroundColor: emerald,
                      content: Text(role == UserRole.chef
                          ? 'Added — awaiting manager review.'
                          : 'Ingredient added.'),
                    ));
                  }
                } catch (e) {
                  if (context.mounted) {
                    final msg = e is DioException
                        ? (e.response?.data is Map
                            ? (e.response!.data['message']?.toString() ??
                                'Failed to add.')
                            : 'Failed to add.')
                        : 'Failed to add.';
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      backgroundColor: crimson,
                      content: Text(msg),
                    ));
                  }
                }
              },
            ),
          ),
        ]),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  const _Field({required this.label, required this.controller, this.keyboardType});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(color: textPrimary, fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: textSecondary, fontSize: 12),
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
      ),
    );
  }
}

class _InventoryCard extends StatelessWidget {
  final InventoryItem item;
  final WidgetRef ref;

  const _InventoryCard({required this.item, required this.ref});

  @override
  Widget build(BuildContext context) {
    final progress = item.lowStockThreshold > 0
        ? (item.currentStock / (item.lowStockThreshold * 3)).clamp(0.0, 1.0)
        : 1.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: slateCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: item.isLow ? crimson.withValues(alpha: 0.4) : dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(item.name, style: const TextStyle(color: textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
              ),
              if (item.isLow)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: crimson.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
                  child: const Text('LOW', style: TextStyle(color: crimson, fontSize: 10, fontWeight: FontWeight.w700)),
                ),
              // Chef-added items waiting on a manager audit. Soft signal —
              // the item still works; the badge just nudges the manager
              // to verify cost + threshold before they slide into reports.
              if (item.pendingReview) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                      color: amber.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: amber.withValues(alpha: 0.4), width: 0.5)),
                  child: const Text('REVIEW',
                      style: TextStyle(color: amber, fontSize: 10, fontWeight: FontWeight.w700)),
                ),
              ],
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => _showAdjustSheet(context),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(color: slateSurface, borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.edit_outlined, color: textSecondary, size: 16),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${item.currentStock} ${item.unit}',
                  style: TextStyle(
                    color: item.isLow ? crimson : copperAccent,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                'Min: ${item.lowStockThreshold} ${item.unit}',
                style: const TextStyle(color: textSecondary, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: slateSurface,
              valueColor: AlwaysStoppedAnimation<Color>(item.isLow ? crimson : emerald),
              minHeight: 4,
            ),
          ),
        ],
      ),
    );
  }

  void _showAdjustSheet(BuildContext context) {
    final ctrl = TextEditingController();
    final reasonCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      backgroundColor: slateCard,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Adjust Stock — ${item.name}', style: const TextStyle(color: textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            TextField(
              controller: ctrl,
              keyboardType: const TextInputType.numberWithOptions(signed: true),
              style: const TextStyle(color: textPrimary),
              decoration: _inputDec('Delta (e.g. +10 or -5)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonCtrl,
              style: const TextStyle(color: textPrimary),
              decoration: _inputDec('Reason'),
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () async {
                final delta = double.tryParse(ctrl.text);
                if (delta == null) return;
                Navigator.pop(context);
                try {
                  final token = ref.read(authProvider).token;
                  final dio = createDioClient(token);
                  await dio.patch(
                    '/inventory/${item.id}/adjust',
                    data: {'delta': delta, 'reason': reasonCtrl.text.isEmpty ? 'Manual adjustment' : reasonCtrl.text},
                    options: Options(headers: {'Idempotency-Key': 'adj-${item.id}-${DateTime.now().millisecondsSinceEpoch}'}),
                  );
                  ref.invalidate(inventoryProvider);
                } catch (_) {}
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(gradient: const LinearGradient(colors: [copperAccent, copperLight]), borderRadius: BorderRadius.circular(12)),
                child: const Center(child: Text('Apply', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700))),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDec(String label) => InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: textSecondary, fontSize: 13),
        filled: true,
        fillColor: slateSurface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: dividerColor)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: dividerColor)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: copperAccent)),
      );
}
