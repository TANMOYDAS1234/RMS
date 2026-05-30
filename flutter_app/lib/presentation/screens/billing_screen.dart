// ─── Cashier — Billing Screen (Phase 4b) ────────────────────────────────────
//
// Three sections, in order of cashier workflow:
//   1. Awaiting Billing  — served orders that don't have a bill yet.
//      One-tap "Generate Bill" with optional discount.
//   2. Pending Payment   — bills generated, not yet paid. Single-method
//      or split payment. UUID idempotency per attempt so a network
//      retry doesn't double-charge.
//   3. Paid Today        — receipt of today's collections, scoped to
//      the cashier's branch (server already does the scoping).
//
// Plus a top revenue card and a WS-driven auto-refresh on every order
// or bill change.

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/config/app_theme.dart';
import '../../core/network/dio_client.dart';
import '../../core/services/websocket_service.dart';
import 'dart:typed_data';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../../core/payments/razorpay_sandbox.dart';
import '../../core/receipts/receipt_pdf.dart';
import '../../core/utils/api_error.dart';
import '../../core/utils/idempotency.dart';
import '../../domain/entities/order_entity.dart';
import '../state/auth_provider.dart';
import '../state/billing_provider.dart';
import '../state/order_providers.dart';

/// Razorpay sandbox config — cached so we don't refetch on every Pay tap.
final _razorpayConfigProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final token = ref.watch(authProvider).token;
  final dio = createDioClient(token);
  try {
    final res = await dio.get('/billing/razorpay/config');
    return Map<String, dynamic>.from(res.data);
  } catch (_) {
    return {'enabled': false, 'keyId': '', 'environment': 'sandbox'};
  }
});

class BillingScreen extends ConsumerWidget {
  const BillingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final billsAsync = ref.watch(billingProvider);
    final revenueAsync = ref.watch(dailyRevenueProvider);
    final liveOrders = ref.watch(liveOrdersProvider);

    // Auto-refresh on every WS order/bill change. Saves the cashier a
    // pull-to-refresh on every payment.
    ref.listen(wsEventsProvider, (_, next) {
      next.whenData((evt) {
        if (evt.event == 'order:updated' ||
            evt.event == 'order:created') {
          ref.invalidate(billingProvider);
          ref.invalidate(dailyRevenueProvider);
        }
      });
    });

    // Served orders need a bill before the cashier can collect. The order
    // state machine puts orders in SERVED until billed → PAID → CLOSED.
    final servedOrders = liveOrders
        .where((o) => o.status == OrderStatus.served)
        .toList();

    return Scaffold(
      backgroundColor: slateBg,
      appBar: AppBar(
        title: const Text('BILLING'),
        backgroundColor: slateBg,
      ),
      body: RefreshIndicator(
        color: copperAccent,
        backgroundColor: slateCard,
        onRefresh: () async {
          ref.invalidate(billingProvider);
          ref.invalidate(dailyRevenueProvider);
          ref.read(liveOrdersProvider.notifier).refresh();
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          children: [
            // Revenue
            revenueAsync.when(
              loading: () => const _Skeleton(height: 84),
              error: (_, __) => const SizedBox.shrink(),
              data: (data) => _RevenueCard(data: data),
            ),
            const SizedBox(height: 18),
            // Section 1 — Awaiting Billing
            _SectionTitle(
              icon: Icons.receipt_outlined,
              title: 'Awaiting Billing',
              count: servedOrders.length,
              accent: amber,
            ),
            const SizedBox(height: 10),
            if (servedOrders.isEmpty)
              _SectionEmpty(label: 'No served orders waiting for a bill')
            else
              ...servedOrders.map((o) => _AwaitingBillingCard(order: o)),
            const SizedBox(height: 22),
            // Sections 2 & 3 — Pending Payment + Paid Today
            billsAsync.when(
              loading: () => const _Skeleton(height: 200),
              error: (e, _) => Center(
                child: Text(describeApiError(e),
                    style: const TextStyle(color: crimson, fontSize: 13)),
              ),
              data: (bills) {
                final pending = bills.where((b) => !b.isPaid).toList();
                final paid = bills.where((b) => b.isPaid).toList();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _SectionTitle(
                      icon: Icons.pending_actions_outlined,
                      title: 'Pending Payment',
                      count: pending.length,
                      accent: copperAccent,
                    ),
                    const SizedBox(height: 10),
                    if (pending.isEmpty)
                      _SectionEmpty(label: 'No bills awaiting payment')
                    else
                      ...pending.map((b) => _BillCard(bill: b)),
                    const SizedBox(height: 22),
                    _SectionTitle(
                      icon: Icons.check_circle_outline,
                      title: 'Paid Today',
                      count: paid.length,
                      accent: emerald,
                    ),
                    const SizedBox(height: 10),
                    if (paid.isEmpty)
                      _SectionEmpty(label: 'No payments collected yet')
                    else
                      ...paid.map((b) => _BillCard(bill: b)),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ── Section helpers ────────────────────────────────────────────────────────
class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;
  final int count;
  final Color accent;
  const _SectionTitle({
    required this.icon,
    required this.title,
    required this.count,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, color: accent, size: 16),
      const SizedBox(width: 8),
      Text(title.toUpperCase(),
          style: const TextStyle(
              color: textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1)),
      const SizedBox(width: 8),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text('$count',
            style: TextStyle(
                color: accent, fontSize: 10, fontWeight: FontWeight.w800)),
      ),
    ]);
  }
}

class _SectionEmpty extends StatelessWidget {
  final String label;
  const _SectionEmpty({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      alignment: Alignment.center,
      child: Text(label,
          style: const TextStyle(color: textSecondary, fontSize: 12)),
    );
  }
}

class _Skeleton extends StatelessWidget {
  final double height;
  const _Skeleton({required this.height});

  @override
  Widget build(BuildContext context) => Container(
        height: height,
        decoration: BoxDecoration(
          color: slateCard,
          borderRadius: BorderRadius.circular(14),
        ),
      );
}

// ── Revenue header ──────────────────────────────────────────────────────────
class _RevenueCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _RevenueCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final total = (data['total'] ?? 0) as num;
    final count = (data['count'] ?? 0) as num;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: slateCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: emerald.withValues(alpha: 0.3)),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: emerald.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.attach_money, color: emerald, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              const Text("Today's Revenue",
                  style: TextStyle(color: textSecondary, fontSize: 11)),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text('₹${total.toStringAsFixed(2)}',
                    style: const TextStyle(
                        color: emerald,
                        fontSize: 20,
                        fontWeight: FontWeight.w800)),
              ),
            ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          const Text('Bills Paid',
              style: TextStyle(color: textSecondary, fontSize: 11)),
          Text('$count',
              style: const TextStyle(
                  color: textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700)),
        ]),
      ]),
    );
  }
}

// ── Awaiting billing card (served orders without a bill yet) ───────────────
class _AwaitingBillingCard extends ConsumerWidget {
  final OrderEntity order;
  const _AwaitingBillingCard({required this.order});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: slateCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: amber.withValues(alpha: 0.35)),
      ),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Text(order.tableLabel,
                  style: const TextStyle(
                      color: textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: amber.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('SERVED',
                    style: TextStyle(
                        color: amber,
                        fontSize: 9,
                        fontWeight: FontWeight.w700)),
              ),
            ]),
            const SizedBox(height: 8),
            Text(
                '${order.items.length} item${order.items.length == 1 ? '' : 's'}',
                style: const TextStyle(color: textSecondary, fontSize: 11)),
            const SizedBox(height: 6),
            Row(children: [
              const Text('Order total',
                  style: TextStyle(color: textSecondary, fontSize: 12)),
              const Spacer(),
              Text('₹${order.total.toStringAsFixed(2)}',
                  style: const TextStyle(
                      color: copperAccent,
                      fontSize: 14,
                      fontWeight: FontWeight.w800)),
            ]),
            const SizedBox(height: 12),
            SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                    icon: const Icon(Icons.receipt_long_outlined, size: 16),
                    label: const Text('Generate Bill'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: copperAccent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      textStyle: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w800),
                    ),
                    onPressed: () => _showGenerateSheet(context, ref))),
          ]),
    );
  }

  void _showGenerateSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: slateCard,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _GenerateBillSheet(order: order),
    );
  }
}

class _GenerateBillSheet extends ConsumerStatefulWidget {
  final OrderEntity order;
  const _GenerateBillSheet({required this.order});
  @override
  ConsumerState<_GenerateBillSheet> createState() => _GenerateBillSheetState();
}

class _GenerateBillSheetState extends ConsumerState<_GenerateBillSheet> {
  double _discount = 0;
  bool _busy = false;
  late final String _idempotencyKey;

  @override
  void initState() {
    super.initState();
    _idempotencyKey = newIdempotencyKey('gen-bill-${widget.order.id}');
  }

  Future<void> _generate() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final dio = createDioClient(ref.read(authProvider).token);
      await dio.post(
        '/billing/order/${widget.order.id}/generate',
        data: {'discountPercent': _discount},
        options: Options(headers: {'Idempotency-Key': _idempotencyKey}),
      );
      ref.invalidate(billingProvider);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Bill generated for ${widget.order.tableLabel}'),
          backgroundColor: emerald,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(describeApiError(e)),
          backgroundColor: crimson,
        ));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // OrderEntity.total is a computed getter over items — same value the
    // server treats as the pre-tax subtotal. Use it directly so we don't
    // need a separate subtotal field client-side.
    final subtotal = widget.order.total;
    final discountAmount = subtotal * (_discount / 100);
    final gstAmount = (subtotal - discountAmount) * 0.18;
    final total = subtotal - discountAmount + gstAmount;
    return Padding(
      padding: EdgeInsets.fromLTRB(
          24, 20, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 36, height: 4,
          decoration: BoxDecoration(
            color: textSecondary.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 14),
        Text('Generate Bill — ${widget.order.tableLabel}',
            style: const TextStyle(
                color: textPrimary, fontSize: 15, fontWeight: FontWeight.w800)),
        const SizedBox(height: 16),
        Row(children: [
          const Text('Discount',
              style: TextStyle(color: textSecondary, fontSize: 12)),
          const Spacer(),
          Text('${_discount.toInt()}%',
              style: const TextStyle(
                  color: copperAccent,
                  fontSize: 14,
                  fontWeight: FontWeight.w800)),
        ]),
        Slider(
          value: _discount,
          min: 0,
          max: 50,
          divisions: 10,
          activeColor: copperAccent,
          inactiveColor: slateSurface,
          onChanged: (v) => setState(() => _discount = v),
        ),
        const SizedBox(height: 8),
        _SummaryRow('Subtotal', subtotal),
        if (_discount > 0)
          _SummaryRow('Discount', -discountAmount, color: emerald),
        _SummaryRow('GST (18%)', gstAmount),
        const Divider(color: dividerColor, height: 24),
        _SummaryRow('Total', total, bold: true, color: copperAccent),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: copperAccent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
            ),
            onPressed: _busy ? null : _generate,
            child: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : Text('Generate ₹${total.toStringAsFixed(2)} Bill'),
          ),
        ),
      ]),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final double value;
  final bool bold;
  final Color? color;
  const _SummaryRow(this.label, this.value, {this.bold = false, this.color});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          Text(label,
              style: TextStyle(
                  color: textSecondary,
                  fontSize: 13,
                  fontWeight: bold ? FontWeight.w700 : FontWeight.normal)),
          const Spacer(),
          Text(
              '${value < 0 ? '-' : ''}₹${value.abs().toStringAsFixed(2)}',
              style: TextStyle(
                  color: color ?? textPrimary,
                  fontSize: 13,
                  fontWeight: bold ? FontWeight.w800 : FontWeight.normal)),
        ]),
      );
}

// ── Bill card (pending or paid) ────────────────────────────────────────────
class _BillCard extends ConsumerWidget {
  final BillModel bill;
  const _BillCard({required this.bill});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: slateCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: bill.isPaid ? emerald.withValues(alpha: 0.3) : dividerColor),
      ),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Text(bill.tableLabel,
                  style: const TextStyle(
                      color: textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: bill.isPaid
                      ? emerald.withValues(alpha: 0.12)
                      : amber.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(bill.isPaid ? 'PAID' : 'PENDING',
                    style: TextStyle(
                        color: bill.isPaid ? emerald : amber,
                        fontSize: 10,
                        fontWeight: FontWeight.w700)),
              ),
            ]),
            const SizedBox(height: 10),
            _SummaryRow('Subtotal', bill.subtotal),
            if (bill.discountAmount > 0)
              _SummaryRow('Discount', -bill.discountAmount, color: emerald),
            _SummaryRow('GST', bill.gstAmount),
            const Divider(color: dividerColor, height: 16),
            _SummaryRow('Total', bill.total, bold: true, color: copperAccent),
            if (bill.isPaid && bill.paidAt != null) ...[
              const SizedBox(height: 6),
              Text(
                'Paid via ${bill.paymentMethod?.toUpperCase() ?? 'N/A'} • ${DateFormat('dd MMM, HH:mm').format(bill.paidAt!)}',
                style: const TextStyle(color: textSecondary, fontSize: 11),
              ),
              const SizedBox(height: 10),
              _ReceiptActions(bill: bill),
            ],
            if (!bill.isPaid) ...[
              const SizedBox(height: 12),
              _PayButtons(bill: bill),
            ],
          ]),
    );
  }
}

// ── Receipt print + share ───────────────────────────────────────────────────
class _ReceiptActions extends ConsumerStatefulWidget {
  final BillModel bill;
  const _ReceiptActions({required this.bill});

  @override
  ConsumerState<_ReceiptActions> createState() => _ReceiptActionsState();
}

class _ReceiptActionsState extends ConsumerState<_ReceiptActions> {
  bool _busy = false;

  Future<Uint8List> _buildPdfBytes() async {
    final user = ref.read(authProvider).user;
    final doc = await ReceiptPdf.build(
      bill: widget.bill,
      branchName: 'DINE OPS',
      // Branch metadata isn't on BillModel; using a sane default. Phase 6
      // can resolve the branch name via a branchesProvider lookup.
      branchAddress: null,
      cashierName: user?.name,
    );
    return doc.save();
  }

  Future<void> _print() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final bytes = await _buildPdfBytes();
      await Printing.layoutPdf(onLayout: (_) async => bytes);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Print failed: ${e.toString()}'),
          backgroundColor: crimson,
        ));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _share() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final bytes = await _buildPdfBytes();
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/receipt-${widget.bill.id.substring(widget.bill.id.length - 6)}.pdf');
      await file.writeAsBytes(bytes);
      await SharePlus.instance.share(ShareParams(
        files: [XFile(file.path, mimeType: 'application/pdf')],
        text: 'Receipt for ${widget.bill.tableLabel} — ₹${widget.bill.total.toStringAsFixed(2)}',
      ));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Share failed: ${e.toString()}'),
          backgroundColor: crimson,
        ));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(
        child: OutlinedButton.icon(
          icon: const Icon(Icons.print_outlined, size: 14),
          label: const Text('Print'),
          style: OutlinedButton.styleFrom(
            foregroundColor: copperAccent,
            side: BorderSide(color: copperAccent.withValues(alpha: 0.5)),
            padding: const EdgeInsets.symmetric(vertical: 8),
            textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
          ),
          onPressed: _busy ? null : _print,
        ),
      ),
      const SizedBox(width: 6),
      Expanded(
        child: OutlinedButton.icon(
          icon: const Icon(Icons.share_outlined, size: 14),
          label: const Text('Share'),
          style: OutlinedButton.styleFrom(
            foregroundColor: textPrimary,
            side: BorderSide(color: textSecondary.withValues(alpha: 0.5)),
            padding: const EdgeInsets.symmetric(vertical: 8),
            textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
          ),
          onPressed: _busy ? null : _share,
        ),
      ),
    ]);
  }
}

// ── Payment action row (single or split) ───────────────────────────────────
class _PayButtons extends ConsumerWidget {
  final BillModel bill;
  const _PayButtons({required this.bill});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(children: [
      Expanded(
        child: ElevatedButton.icon(
          icon: const Icon(Icons.payment_outlined, size: 16),
          label: const Text('Quick Pay'),
          style: ElevatedButton.styleFrom(
            backgroundColor: copperAccent,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 11),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
            textStyle:
                const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
          ),
          onPressed: () => _showQuickSheet(context, ref),
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: OutlinedButton.icon(
          icon: const Icon(Icons.call_split_outlined, size: 16),
          label: const Text('Split'),
          style: OutlinedButton.styleFrom(
            foregroundColor: copperAccent,
            side: const BorderSide(color: copperAccent),
            padding: const EdgeInsets.symmetric(vertical: 11),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
            textStyle:
                const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
          ),
          onPressed: () => _showSplitSheet(context, ref),
        ),
      ),
    ]);
  }

  void _showQuickSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: slateCard,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _QuickPaySheet(bill: bill),
    );
  }

  void _showSplitSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: slateCard,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _SplitPaySheet(bill: bill),
    );
  }
}

// ── Quick pay (single method) ──────────────────────────────────────────────
class _QuickPaySheet extends ConsumerStatefulWidget {
  final BillModel bill;
  const _QuickPaySheet({required this.bill});
  @override
  ConsumerState<_QuickPaySheet> createState() => _QuickPaySheetState();
}

class _QuickPaySheetState extends ConsumerState<_QuickPaySheet> {
  bool _busy = false;

  Future<void> _payCash() async => _record('cash');

  Future<void> _payRazorpay() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final cfg = await ref.read(_razorpayConfigProvider.future);
      final keyId = (cfg['keyId'] as String?) ?? '';
      if (keyId.isEmpty || cfg['enabled'] != true) {
        _snack('Razorpay not configured on server (sandbox mode disabled).', crimson);
        return;
      }
      final result = await RazorpaySandbox.instance.pay(
        keyId: keyId,
        amount: widget.bill.total,
        orderTag: '${widget.bill.tableLabel} • ${widget.bill.id.substring(widget.bill.id.length - 6)}',
        customerName: ref.read(authProvider).user?.name,
      );
      if (!result.success) {
        _snack(result.errorMessage ?? 'Payment cancelled.', amber);
        return;
      }
      // Record on the backend. The bill is marked paid with method
      // depending on what Razorpay reports; we treat anything that
      // succeeded as 'card' for ledger purposes — the razorpayPaymentId
      // is also stored on the bill for reconciliation.
      await _record('card', razorpay: {
        'razorpayPaymentId': result.paymentId,
        'razorpayOrderId': result.orderId,
      });
    } catch (e) {
      _snack(describeApiError(e), crimson);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _record(String method, {Map<String, String?>? razorpay}) async {
    final key = newIdempotencyKey('pay-${widget.bill.id}-$method');
    try {
      final dio = createDioClient(ref.read(authProvider).token);
      await dio.post(
        '/billing/${widget.bill.id}/pay',
        data: {
          'paymentMethod': method,
          if (razorpay != null) ...razorpay,
        },
        options: Options(headers: {'Idempotency-Key': key}),
      );
      ref.invalidate(billingProvider);
      ref.invalidate(dailyRevenueProvider);
      if (mounted) {
        Navigator.pop(context);
        _snack(
            'Paid ₹${widget.bill.total.toStringAsFixed(2)} via ${method.toUpperCase()}',
            emerald);
      }
    } catch (e) {
      _snack(describeApiError(e), crimson);
    }
  }

  void _snack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color),
    );
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Pay ₹${widget.bill.total.toStringAsFixed(2)}',
                  style: const TextStyle(
                      color: textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              const Text('Razorpay is in sandbox mode — no real money moves.',
                  style: TextStyle(color: textSecondary, fontSize: 11)),
              const SizedBox(height: 16),
              _PayTile(
                icon: Icons.payments_outlined,
                label: 'CASH',
                color: emerald,
                onTap: _busy ? null : _payCash,
              ),
              _PayTile(
                icon: Icons.credit_card_outlined,
                label: 'CARD / UPI (Razorpay Sandbox)',
                color: copperAccent,
                trailing: const Text('TEST',
                    style: TextStyle(
                        color: amber,
                        fontSize: 9,
                        fontWeight: FontWeight.w800)),
                onTap: _busy ? null : _payRazorpay,
              ),
            ]),
      );
}

class _PayTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Widget? trailing;
  final VoidCallback? onTap;
  const _PayTile({
    required this.icon,
    required this.label,
    required this.color,
    this.trailing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
          decoration: BoxDecoration(
            color: slateSurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.4)),
          ),
          child: Row(children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(label,
                  style: const TextStyle(
                      color: textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 13)),
            ),
            if (trailing != null) trailing!,
          ]),
        ),
      );
}

// ── Split payment ──────────────────────────────────────────────────────────
class _SplitPaySheet extends ConsumerStatefulWidget {
  final BillModel bill;
  const _SplitPaySheet({required this.bill});
  @override
  ConsumerState<_SplitPaySheet> createState() => _SplitPaySheetState();
}

class _SplitPaySheetState extends ConsumerState<_SplitPaySheet> {
  // Three default allocations (cash/card/upi) the cashier can edit.
  final Map<String, double> _allocations = {'cash': 0, 'card': 0, 'upi': 0};
  bool _busy = false;
  late final String _idempotencyKey;

  @override
  void initState() {
    super.initState();
    _idempotencyKey = newIdempotencyKey('split-${widget.bill.id}');
  }

  double get _allocated => _allocations.values.fold(0, (s, v) => s + v);
  double get _remaining => widget.bill.total - _allocated;

  Future<void> _submit() async {
    if (_busy) return;
    // Server-side rule: split amounts must sum to total.
    if ((_remaining).abs() > 0.01) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_remaining > 0
            ? 'Under by ₹${_remaining.toStringAsFixed(2)}'
            : 'Over by ₹${(-_remaining).toStringAsFixed(2)}'),
        backgroundColor: crimson,
      ));
      return;
    }
    setState(() => _busy = true);
    try {
      final dio = createDioClient(ref.read(authProvider).token);
      final splits = _allocations.entries
          .where((e) => e.value > 0)
          .map((e) => {'method': e.key, 'amount': e.value})
          .toList();
      await dio.post(
        '/billing/${widget.bill.id}/pay',
        data: {
          // Backend requires a primary paymentMethod even on splits — use
          // the largest allocation as the headline.
          'paymentMethod': splits.reduce((a, b) =>
              (a['amount'] as double) >= (b['amount'] as double) ? a : b)['method'],
          'splitPayments': splits,
        },
        options: Options(headers: {'Idempotency-Key': _idempotencyKey}),
      );
      ref.invalidate(billingProvider);
      ref.invalidate(dailyRevenueProvider);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Split payment recorded for ${widget.bill.tableLabel}'),
          backgroundColor: emerald,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(describeApiError(e)),
          backgroundColor: crimson,
        ));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final remaining = _remaining;
    return Padding(
      padding: EdgeInsets.fromLTRB(
          24, 20, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 36, height: 4,
          decoration: BoxDecoration(
            color: textSecondary.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 14),
        Text('Split ₹${widget.bill.total.toStringAsFixed(2)}',
            style: const TextStyle(
                color: textPrimary, fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 18),
        for (final m in const ['cash', 'card', 'upi']) _SplitRow(
          method: m,
          value: _allocations[m]!,
          onChanged: (v) => setState(() => _allocations[m] = v),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: remaining.abs() < 0.01
                ? emerald.withValues(alpha: 0.10)
                : amber.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(children: [
            Icon(
              remaining.abs() < 0.01
                  ? Icons.check_circle_outline
                  : Icons.info_outline,
              color: remaining.abs() < 0.01 ? emerald : amber,
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                remaining.abs() < 0.01
                    ? 'Balanced'
                    : remaining > 0
                        ? 'Add ₹${remaining.toStringAsFixed(2)}'
                        : 'Over by ₹${(-remaining).toStringAsFixed(2)}',
                style: TextStyle(
                  color: remaining.abs() < 0.01 ? emerald : amber,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 14),
        SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: copperAccent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
              ),
              onPressed: _busy ? null : _submit,
              child: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Text('Record Split Payment'),
            )),
      ]),
    );
  }
}

class _SplitRow extends StatefulWidget {
  final String method;
  final double value;
  final ValueChanged<double> onChanged;
  const _SplitRow({
    required this.method,
    required this.value,
    required this.onChanged,
  });
  @override
  State<_SplitRow> createState() => _SplitRowState();
}

class _SplitRowState extends State<_SplitRow> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(
        text: widget.value > 0 ? widget.value.toStringAsFixed(0) : '');
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: slateSurface,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(children: [
          SizedBox(
            width: 60,
            child: Text(widget.method.toUpperCase(),
                style: const TextStyle(
                    color: textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700)),
          ),
          Expanded(
              child: TextField(
                  controller: _ctrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(color: textPrimary, fontSize: 14),
                  textAlign: TextAlign.right,
                  decoration: const InputDecoration(
                    hintText: '0',
                    hintStyle: TextStyle(color: textSecondary, fontSize: 14),
                    border: InputBorder.none,
                    prefixText: '₹',
                    prefixStyle: TextStyle(color: textSecondary, fontSize: 14),
                  ),
                  onChanged: (s) {
                    final v = double.tryParse(s) ?? 0;
                    widget.onChanged(v);
                  })),
        ]),
      );
}
