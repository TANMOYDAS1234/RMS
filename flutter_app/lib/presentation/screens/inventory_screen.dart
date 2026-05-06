import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/config/app_theme.dart';
import '../../core/network/dio_client.dart';
import '../state/auth_provider.dart';

class InventoryItem {
  final String id;
  final String name;
  final String unit;
  final double currentStock;
  final double lowStockThreshold;
  final double costPerUnit;

  const InventoryItem({
    required this.id,
    required this.name,
    required this.unit,
    required this.currentStock,
    required this.lowStockThreshold,
    required this.costPerUnit,
  });

  factory InventoryItem.fromJson(Map<String, dynamic> j) => InventoryItem(
        id: j['_id'] ?? j['id'] ?? '',
        name: j['name'] ?? '',
        unit: j['unit'] ?? '',
        currentStock: (j['currentStock'] ?? 0).toDouble(),
        lowStockThreshold: (j['lowStockThreshold'] ?? 0).toDouble(),
        costPerUnit: (j['costPerUnit'] ?? 0).toDouble(),
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

    return Scaffold(
      backgroundColor: slateBg,
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
