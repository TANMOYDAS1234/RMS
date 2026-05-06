import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/config/app_theme.dart';
import '../../core/network/dio_client.dart';
import '../state/billing_provider.dart';
import '../state/auth_provider.dart';

class BillingScreen extends ConsumerWidget {
  const BillingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final billsAsync = ref.watch(billingProvider);
    final revenueAsync = ref.watch(dailyRevenueProvider);

    return Scaffold(
      backgroundColor: slateBg,
      appBar: AppBar(
        title: const Text('BILLING'),
        backgroundColor: slateBg,
      ),
      body: Column(
        children: [
          // Daily revenue card
          revenueAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
            data: (data) => Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: slateCard,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: dividerColor),
              ),
              child: Row(
                children: [
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
                        const Text("Today's Revenue", style: TextStyle(color: textSecondary, fontSize: 11)),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '₹${(data['total'] ?? 0).toStringAsFixed(2)}',
                            style: const TextStyle(color: emerald, fontSize: 20, fontWeight: FontWeight.w800),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text('Bills Paid', style: TextStyle(color: textSecondary, fontSize: 11)),
                      Text('${data['count'] ?? 0}', style: const TextStyle(color: textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: billsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator(color: copperAccent)),
              error: (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: crimson))),
              data: (bills) => bills.isEmpty
                  ? const Center(child: Text('No bills yet', style: TextStyle(color: textSecondary)))
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      itemCount: bills.length,
                      itemBuilder: (_, i) => _BillCard(bill: bills[i], ref: ref),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BillCard extends StatelessWidget {
  final BillModel bill;
  final WidgetRef ref;

  const _BillCard({required this.bill, required this.ref});

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: slateCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: bill.isPaid ? emerald.withValues(alpha: 0.3) : dividerColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(bill.tableLabel, style: const TextStyle(color: textPrimary, fontSize: 14, fontWeight: FontWeight.w700)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: bill.isPaid ? emerald.withValues(alpha: 0.12) : amber.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    bill.isPaid ? 'PAID' : 'PENDING',
                    style: TextStyle(color: bill.isPaid ? emerald : amber, fontSize: 10, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _Row('Subtotal', '₹${bill.subtotal.toStringAsFixed(2)}'),
            if (bill.discountAmount > 0) _Row('Discount', '-₹${bill.discountAmount.toStringAsFixed(2)}', color: emerald),
            _Row('GST (18%)', '₹${bill.gstAmount.toStringAsFixed(2)}'),
            const Divider(color: dividerColor, height: 16),
            _Row('Total', '₹${bill.total.toStringAsFixed(2)}', bold: true, color: copperAccent),
            if (bill.isPaid && bill.paidAt != null) ...[
              const SizedBox(height: 6),
              Text(
                'Paid via ${bill.paymentMethod?.toUpperCase() ?? 'N/A'} on ${DateFormat('dd MMM, HH:mm').format(bill.paidAt!)}',
                style: const TextStyle(color: textSecondary, fontSize: 11),
              ),
            ],
            if (!bill.isPaid) ...[
              const SizedBox(height: 12),
              _PayButton(bill: bill, ref: ref),
            ],
          ],
        ),
      );
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  final Color? color;

  const _Row(this.label, this.value, {this.bold = false, this.color});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Text(label, style: TextStyle(color: textSecondary, fontSize: 12, fontWeight: bold ? FontWeight.w700 : FontWeight.normal)),
            const Spacer(),
            Text(value, style: TextStyle(color: color ?? textPrimary, fontSize: 12, fontWeight: bold ? FontWeight.w800 : FontWeight.normal)),
          ],
        ),
      );
}

class _PayButton extends ConsumerStatefulWidget {
  final BillModel bill;
  final WidgetRef ref;

  const _PayButton({required this.bill, required this.ref});

  @override
  ConsumerState<_PayButton> createState() => _PayButtonState();
}

class _PayButtonState extends ConsumerState<_PayButton> {
  bool _loading = false;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: _loading ? null : () => _showPaymentSheet(context),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [copperAccent, copperLight]),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: _loading
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('Process Payment', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
          ),
        ),
      );

  void _showPaymentSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: slateCard,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Pay ₹${widget.bill.total.toStringAsFixed(2)}', style: const TextStyle(color: textPrimary, fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 16),
            ...['cash', 'card', 'upi'].map((method) => GestureDetector(
                  onTap: () { Navigator.pop(context); _pay(method); },
                  child: Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(color: slateSurface, borderRadius: BorderRadius.circular(12)),
                    child: Center(child: Text(method.toUpperCase(), style: const TextStyle(color: textPrimary, fontWeight: FontWeight.w700))),
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Future<void> _pay(String method) async {
    setState(() => _loading = true);
    try {
      final token = ref.read(authProvider).token;
      final dio = createDioClient(token);
      await dio.post(
        '/billing/${widget.bill.id}/pay',
        data: {'paymentMethod': method},
        options: Options(headers: {'Idempotency-Key': 'pay-${widget.bill.id}'}),
      );
      ref.invalidate(billingProvider);
      ref.invalidate(dailyRevenueProvider);
    } catch (_) {} finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}
