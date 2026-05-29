// ─── Manager: Discounts Tab ───────────────────────────────────────────────────
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/config/app_theme.dart';
import '../../core/network/dio_client.dart';
import '../../core/utils/api_error.dart';
import '../../core/utils/idempotency.dart';
import '../state/auth_provider.dart';

// ── Providers ─────────────────────────────────────────────────────────────────
final _pendingBillsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final token = ref.watch(authProvider).token;
  final dio = createDioClient(token);
  final res = await dio.get('/billing?isPaid=false');
  return List<Map<String, dynamic>>.from(res.data);
});

final _allOrdersProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final token = ref.watch(authProvider).token;
  final dio = createDioClient(token);
  final res = await dio.get('/orders/active');
  return List<Map<String, dynamic>>.from(res.data);
});

// ── Tab ───────────────────────────────────────────────────────────────────────
class ManagerDiscountsTab extends ConsumerStatefulWidget {
  const ManagerDiscountsTab({super.key});

  @override
  ConsumerState<ManagerDiscountsTab> createState() =>
      _ManagerDiscountsTabState();
}

class _ManagerDiscountsTabState extends ConsumerState<ManagerDiscountsTab>
    with SingleTickerProviderStateMixin {
  late TabController _tc;

  @override
  void initState() {
    super.initState();
    _tc = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      // ── Sub-tabs ───────────────────────────────────────────────────────
      Container(
        color: slateCard,
        child: TabBar(
          controller: _tc,
          indicatorColor: copperAccent,
          labelColor: copperAccent,
          unselectedLabelColor: textSecondary,
          labelStyle:
              const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          tabs: const [
            Tab(text: 'Apply Discount'),
            Tab(text: 'Active Orders'),
          ],
        ),
      ),
      Expanded(
        child: TabBarView(
          controller: _tc,
          children: [
            _PendingBillsTab(),
            _ActiveOrdersTab(),
          ],
        ),
      ),
    ]);
  }
}

// ── Pending bills (apply discount) ────────────────────────────────────────────
class _PendingBillsTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final billsAsync = ref.watch(_pendingBillsProvider);

    return RefreshIndicator(
      color: copperAccent,
      backgroundColor: slateCard,
      onRefresh: () async => ref.invalidate(_pendingBillsProvider),
      child: billsAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(color: copperAccent)),
        error: (e, _) => Center(
            child: Text('$e',
                style: const TextStyle(color: crimson, fontSize: 13))),
        data: (bills) {
          final withDiscount =
              bills.where((b) => (b['discountPercent'] as num? ?? 0) > 0).length;
          final noDiscount =
              bills.where((b) => (b['discountPercent'] as num? ?? 0) == 0).length;

          if (bills.isEmpty) {
            return const _EmptyState(
              icon: Icons.discount_outlined,
              message: 'No pending bills',
              sub: 'All bills have been settled',
            );
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            children: [
              // Summary
              Row(children: [
                _SummaryChip('Pending', bills.length, amber),
                const SizedBox(width: 8),
                _SummaryChip('Discounted', withDiscount, emerald),
                const SizedBox(width: 8),
                _SummaryChip('No Discount', noDiscount, textSecondary),
              ]),
              const SizedBox(height: 16),
              ...bills.map((b) => _BillCard(
                    bill: b,
                    onApplyDiscount: (pct, reason) =>
                        _applyDiscount(context, ref, b, pct, reason),
                  )),
            ],
          );
        },
      ),
    );
  }

  Future<void> _applyDiscount(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> bill,
    double pct,
    String reason,
  ) async {
    final orderId = bill['orderId']?.toString() ?? '';
    if (orderId.isEmpty) return;
    try {
      final dio = createDioClient(ref.read(authProvider).token);
      await dio.patch(
        '/manager/order-action/discount/$orderId',
        data: {'discountPercent': pct, 'reason': reason},
        options: Options(headers: {
          'Idempotency-Key': newIdempotencyKey('discount-bill-$orderId'),
        }),
      );
      ref.invalidate(_pendingBillsProvider);
      if (context.mounted) _snack(context, 'Discount applied: ${pct.toInt()}%', emerald);
    } catch (e) {
      if (context.mounted) _snack(context, describeApiError(e), crimson);
    }
  }
}

// ── Active orders (apply discount before bill) ────────────────────────────────
class _ActiveOrdersTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(_allOrdersProvider);

    return RefreshIndicator(
      color: copperAccent,
      backgroundColor: slateCard,
      onRefresh: () async => ref.invalidate(_allOrdersProvider),
      child: ordersAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(color: copperAccent)),
        error: (e, _) => Center(
            child: Text('$e',
                style: const TextStyle(color: crimson, fontSize: 13))),
        data: (orders) {
          final active = orders
              .where((o) =>
                  !['closed', 'paid'].contains(o['status'] as String? ?? ''))
              .toList();

          if (active.isEmpty) {
            return const _EmptyState(
              icon: Icons.receipt_outlined,
              message: 'No active orders',
              sub: 'Orders will appear here',
            );
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            children: active
                .map((o) => _OrderDiscountCard(
                      order: o,
                      onApply: (pct, reason) =>
                          _applyToOrder(context, ref, o, pct, reason),
                    ))
                .toList(),
          );
        },
      ),
    );
  }

  Future<void> _applyToOrder(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> order,
    double pct,
    String reason,
  ) async {
    final id = order['_id']?.toString() ?? '';
    final version = (order['version'] as num?)?.toInt();
    try {
      final dio = createDioClient(ref.read(authProvider).token);
      await dio.patch(
        '/manager/order-action/discount/$id',
        data: {
          'discountPercent': pct,
          'reason': reason,
          if (version != null) 'expectedVersion': version,
        },
        options: Options(headers: {
          'Idempotency-Key': newIdempotencyKey('discount-order-$id'),
        }),
      );
      ref.invalidate(_allOrdersProvider);
      if (context.mounted) _snack(context, 'Discount applied: ${pct.toInt()}%', emerald);
    } catch (e) {
      if (context.mounted) _snack(context, describeApiError(e), crimson);
    }
  }
}

// ── Bill card ─────────────────────────────────────────────────────────────────
class _BillCard extends StatelessWidget {
  final Map<String, dynamic> bill;
  final void Function(double pct, String reason) onApplyDiscount;
  const _BillCard({required this.bill, required this.onApplyDiscount});

  @override
  Widget build(BuildContext context) {
    final tableLabel    = bill['tableLabel'] as String? ?? '';
    final subtotal      = (bill['subtotal'] as num? ?? 0).toDouble();
    final discountPct   = (bill['discountPercent'] as num? ?? 0).toDouble();
    final discountAmt   = (bill['discountAmount'] as num? ?? 0).toDouble();
    final total         = (bill['total'] as num? ?? 0).toDouble();
    final hasDiscount   = discountPct > 0;
    final createdAt     = bill['createdAt'] != null
        ? DateTime.tryParse(bill['createdAt'].toString())
        : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: slateCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: hasDiscount
              ? emerald.withValues(alpha: 0.3)
              : dividerColor,
        ),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(tableLabel,
                  style: const TextStyle(
                      color: textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700)),
              if (createdAt != null)
                Text(DateFormat('dd MMM, HH:mm').format(createdAt),
                    style: const TextStyle(color: textSecondary, fontSize: 11)),
            ]),
          ),
          if (hasDiscount)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: emerald.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('${discountPct.toInt()}% OFF',
                  style: const TextStyle(
                      color: emerald, fontSize: 10, fontWeight: FontWeight.w700)),
            ),
        ]),
        const SizedBox(height: 10),
        _BillRow('Subtotal', '₹${subtotal.toStringAsFixed(0)}', textSecondary),
        if (hasDiscount)
          _BillRow('Discount', '-₹${discountAmt.toStringAsFixed(0)}', emerald),
        _BillRow('Total', '₹${total.toStringAsFixed(0)}', copperAccent,
            bold: true),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: () => _showDiscountSheet(context),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: hasDiscount
                  ? slateSurface
                  : copperAccent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: hasDiscount
                    ? dividerColor
                    : copperAccent.withValues(alpha: 0.3),
              ),
            ),
            child: Center(
              child: Text(
                hasDiscount ? 'Update Discount' : 'Apply Discount',
                style: TextStyle(
                    color: hasDiscount ? textSecondary : copperAccent,
                    fontSize: 12,
                    fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ),
      ]),
    ).animate().fadeIn(duration: 250.ms);
  }

  void _showDiscountSheet(BuildContext context) =>
      _showDiscountBottomSheet(context, onApplyDiscount);
}

// ── Order discount card ───────────────────────────────────────────────────────
class _OrderDiscountCard extends StatelessWidget {
  final Map<String, dynamic> order;
  final void Function(double pct, String reason) onApply;
  const _OrderDiscountCard({required this.order, required this.onApply});

  @override
  Widget build(BuildContext context) {
    final tableLabel  = order['tableLabel'] as String? ?? '';
    final status      = order['status'] as String? ?? '';
    final subtotal    = (order['subtotal'] as num? ?? 0).toDouble();
    final discount    = (order['discountAmount'] as num? ?? 0).toDouble();
    final total       = (order['total'] as num? ?? 0).toDouble();
    final items       = (order['items'] as List?)?.length ?? 0;
    final hasDiscount = discount > 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: slateCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: hasDiscount
              ? emerald.withValues(alpha: 0.3)
              : dividerColor,
        ),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(tableLabel,
                style: const TextStyle(
                    color: textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700)),
            Text('$items items · ${status.toUpperCase()}',
                style: const TextStyle(color: textSecondary, fontSize: 11)),
          ])),
          if (hasDiscount)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: emerald.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('-₹${discount.toStringAsFixed(0)}',
                  style: const TextStyle(
                      color: emerald,
                      fontSize: 10,
                      fontWeight: FontWeight.w700)),
            ),
        ]),
        const SizedBox(height: 10),
        _BillRow('Subtotal', '₹${subtotal.toStringAsFixed(0)}', textSecondary),
        if (hasDiscount)
          _BillRow('Discount', '-₹${discount.toStringAsFixed(0)}', emerald),
        _BillRow('Total', '₹${total.toStringAsFixed(0)}', copperAccent,
            bold: true),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: () => _showDiscountBottomSheet(context, onApply),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: copperAccent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: copperAccent.withValues(alpha: 0.3)),
            ),
            child: const Center(
              child: Text('Apply Discount',
                  style: TextStyle(
                      color: copperAccent,
                      fontSize: 12,
                      fontWeight: FontWeight.w700)),
            ),
          ),
        ),
      ]),
    ).animate().fadeIn(duration: 250.ms);
  }
}

// ── Discount bottom sheet ─────────────────────────────────────────────────────
void _showDiscountBottomSheet(
  BuildContext context,
  void Function(double pct, String reason) onApply,
) {
  showModalBottomSheet(
    context: context,
    backgroundColor: slateCard,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (_) => _DiscountSheet(onApply: onApply),
  );
}

class _DiscountSheet extends StatefulWidget {
  final void Function(double pct, String reason) onApply;
  const _DiscountSheet({required this.onApply});
  @override
  State<_DiscountSheet> createState() => _DiscountSheetState();
}

class _DiscountSheetState extends State<_DiscountSheet> {
  static const _presets = [5.0, 10.0, 15.0, 20.0, 25.0, 50.0];
  double _selectedPct = 10;
  late final TextEditingController _reasonCtrl;

  @override
  void initState() {
    super.initState();
    _reasonCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(
            24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
        child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Apply Discount',
                  style: TextStyle(
                      color: textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              const Text('Quick Select',
                  style: TextStyle(color: textSecondary, fontSize: 12)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _presets.map((p) {
                  final selected = _selectedPct == p;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedPct = p),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: selected
                            ? copperAccent.withValues(alpha: 0.2)
                            : slateSurface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: selected ? copperAccent : dividerColor,
                        ),
                      ),
                      child: Text('${p.toInt()}%',
                          style: TextStyle(
                              color: selected ? copperAccent : textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w700)),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              Row(children: [
                const Text('Custom:',
                    style: TextStyle(color: textSecondary, fontSize: 12)),
                const SizedBox(width: 8),
                Text('${_selectedPct.toInt()}%',
                    style: const TextStyle(
                        color: copperAccent,
                        fontSize: 14,
                        fontWeight: FontWeight.w800)),
              ]),
              Slider(
                value: _selectedPct,
                min: 0,
                max: 100,
                divisions: 20,
                activeColor: copperAccent,
                inactiveColor: slateSurface,
                onChanged: (v) => setState(() => _selectedPct = v),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _reasonCtrl,
                style: const TextStyle(color: textPrimary),
                decoration: InputDecoration(
                  labelText: 'Reason (e.g. VIP guest, complaint)',
                  labelStyle:
                      const TextStyle(color: textSecondary, fontSize: 13),
                  filled: true,
                  fillColor: slateSurface,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: dividerColor)),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: dividerColor)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: copperAccent)),
                ),
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () {
                  Navigator.pop(context);
                  widget.onApply(_selectedPct,
                      _reasonCtrl.text.isEmpty ? 'Manager discount' : _reasonCtrl.text);
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [copperAccent, Color(0xFFE8722A)]),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      'Apply ${_selectedPct.toInt()}% Discount',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 14),
                    ),
                  ),
                ),
              ),
            ]),
      );
}

// ── Shared helpers ────────────────────────────────────────────────────────────
class _BillRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool bold;
  const _BillRow(this.label, this.value, this.color, {this.bold = false});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(children: [
          Text(label,
              style: TextStyle(
                  color: textSecondary,
                  fontSize: 12,
                  fontWeight: bold ? FontWeight.w700 : FontWeight.normal)),
          const Spacer(),
          Text(value,
              style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: bold ? FontWeight.w800 : FontWeight.w600)),
        ]),
      );
}

class _SummaryChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  const _SummaryChip(this.label, this.count, this.color);

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Column(children: [
            Text('$count',
                style: TextStyle(
                    color: color, fontSize: 18, fontWeight: FontWeight.w800)),
            Text(label,
                style: const TextStyle(color: textSecondary, fontSize: 10)),
          ]),
        ),
      );
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  final String sub;
  const _EmptyState(
      {required this.icon, required this.message, required this.sub});

  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 48, color: textSecondary.withValues(alpha: 0.4)),
          const SizedBox(height: 12),
          Text(message,
              style: const TextStyle(
                  color: textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(sub,
              style: const TextStyle(color: textSecondary, fontSize: 12)),
        ]),
      );
}

void _snack(BuildContext context, String msg, Color color) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
    ));
