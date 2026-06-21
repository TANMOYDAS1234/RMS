// ─── Cashier — Cash Drawer Shift Screen ─────────────────────────────────────
//
// Three states:
//   1. No open shift → Open Shift form (opening balance + cashier name).
//   2. Open shift    → live summary + Close Shift form (closing count).
//   3. Closed view   → variance + history (manager-only listing reuses the
//      same /cash-drawer endpoint).
//
// The variance the server computes is the cashier's accountability for the
// shift. Positive = surplus, negative = shortage. Manager audits via the
// /cash-drawer list endpoint (Phase 6 hooks that into the manager panel).

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/config/app_theme.dart';
import '../../core/network/dio_client.dart';
import '../../core/utils/api_error.dart';
import '../../core/utils/idempotency.dart';
import '../state/auth_provider.dart';

/// Currently-open shift for the caller. null when none is open.
final cashDrawerCurrentProvider =
    FutureProvider.autoDispose<Map<String, dynamic>?>((ref) async {
  final token = ref.watch(authProvider).token;
  final dio = createDioClient(token);
  final res = await dio.get('/cash-drawer/current');
  if (res.data == null) return null;
  return Map<String, dynamic>.from(res.data);
});

class CashDrawerScreen extends ConsumerWidget {
  const CashDrawerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(cashDrawerCurrentProvider);
    return Scaffold(
      backgroundColor: slateBg,
      appBar: AppBar(
        title: const Text('CASH DRAWER'),
        backgroundColor: slateBg,
      ),
      body: current.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: copperAccent)),
        error: (e, _) => Center(
            child: Text(describeApiError(e),
                style: const TextStyle(color: crimson))),
        data: (shift) => shift == null
            ? const _OpenShiftForm()
            : _OpenShiftView(shift: shift),
      ),
    );
  }
}

// ── Open shift form (no shift active) ──────────────────────────────────────
class _OpenShiftForm extends ConsumerStatefulWidget {
  const _OpenShiftForm();
  @override
  ConsumerState<_OpenShiftForm> createState() => _OpenShiftFormState();
}

class _OpenShiftFormState extends ConsumerState<_OpenShiftForm> {
  final _balanceCtrl = TextEditingController();
  bool _busy = false;
  late final String _idempotencyKey;

  @override
  void initState() {
    super.initState();
    _idempotencyKey = newIdempotencyKey('shift-open');
  }

  @override
  void dispose() {
    _balanceCtrl.dispose();
    super.dispose();
  }

  Future<void> _open() async {
    if (_busy) return;
    final amount = double.tryParse(_balanceCtrl.text);
    if (amount == null || amount < 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Enter the cash currently in the drawer.'),
        backgroundColor: amber,
      ));
      return;
    }
    setState(() => _busy = true);
    try {
      final dio = createDioClient(ref.read(authProvider).token);
      final user = ref.read(authProvider).user;
      await dio.post(
        '/cash-drawer/open',
        data: {
          'openingBalance': amount,
          if (user?.name != null) 'cashierName': user!.name,
        },
        options: Options(headers: {'Idempotency-Key': _idempotencyKey}),
      );
      ref.invalidate(cashDrawerCurrentProvider);
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
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.point_of_sale_outlined,
                    color: copperAccent, size: 44),
                const SizedBox(height: 12),
                const Text('Start a new shift',
                    style: TextStyle(
                        color: textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                const Text(
                    'Count the cash in the drawer and enter the opening balance. Variance at the end of your shift compares this against the cash you collect.',
                    style: TextStyle(color: textSecondary, fontSize: 12)),
                const SizedBox(height: 20),
                TextField(
                  controller: _balanceCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(
                      color: textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w800),
                  decoration: InputDecoration(
                    labelText: 'Opening Balance',
                    labelStyle: const TextStyle(color: textSecondary),
                    prefixText: '₹ ',
                    prefixStyle:
                        const TextStyle(color: copperAccent, fontSize: 18),
                    filled: true,
                    fillColor: slateCard,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: dividerColor),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: dividerColor),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: copperAccent),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.play_arrow_rounded, size: 18),
                    label: const Text('Open Shift'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: copperAccent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      textStyle: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w800),
                    ),
                    onPressed: _busy ? null : _open,
                  ),
                ),
              ]),
        ),
      ),
    );
  }
}

// ── Open shift view (shift is active) ──────────────────────────────────────
class _OpenShiftView extends ConsumerStatefulWidget {
  final Map<String, dynamic> shift;
  const _OpenShiftView({required this.shift});
  @override
  ConsumerState<_OpenShiftView> createState() => _OpenShiftViewState();
}

class _OpenShiftViewState extends ConsumerState<_OpenShiftView> {
  final _closingCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  bool _busy = false;
  late final String _idempotencyKey;

  @override
  void initState() {
    super.initState();
    _idempotencyKey = newIdempotencyKey('shift-close-${widget.shift['_id']}');
  }

  @override
  void dispose() {
    _closingCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _close() async {
    if (_busy) return;
    final closing = double.tryParse(_closingCtrl.text);
    if (closing == null || closing < 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Enter the cash you counted at end of shift.'),
        backgroundColor: amber,
      ));
      return;
    }
    setState(() => _busy = true);
    try {
      final dio = createDioClient(ref.read(authProvider).token);
      final res = await dio.post(
        '/cash-drawer/${widget.shift['_id']}/close',
        data: {
          'closingBalance': closing,
          if (_noteCtrl.text.trim().isNotEmpty) 'note': _noteCtrl.text.trim(),
        },
        options: Options(headers: {'Idempotency-Key': _idempotencyKey}),
      );
      final variance = (res.data['variance'] as num?)?.toDouble() ?? 0;
      ref.invalidate(cashDrawerCurrentProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: variance.abs() < 0.01
              ? emerald
              : variance > 0
                  ? amber
                  : crimson,
          content: Text(variance.abs() < 0.01
              ? 'Shift closed — balanced!'
              : variance > 0
                  ? 'Shift closed — surplus ₹${variance.toStringAsFixed(2)}'
                  : 'Shift closed — short ₹${(-variance).toStringAsFixed(2)}'),
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
    final s = widget.shift;
    final opening = (s['openingBalance'] as num? ?? 0).toDouble();
    final openedAt = DateTime.tryParse(s['openedAt']?.toString() ?? '');
    final cashierName = s['cashierName']?.toString() ?? 'You';

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: slateCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: emerald.withValues(alpha: 0.3)),
          ),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                        color: emerald, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 8),
                  const Text('SHIFT OPEN',
                      style: TextStyle(
                          color: emerald,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1)),
                ]),
                const SizedBox(height: 12),
                Text(cashierName,
                    style: const TextStyle(
                        color: textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w700)),
                if (openedAt != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                        'Opened ${DateFormat('dd MMM, HH:mm').format(openedAt)}',
                        style: const TextStyle(
                            color: textSecondary, fontSize: 12)),
                  ),
                const Divider(color: dividerColor, height: 22),
                Row(children: [
                  const Text('Opening Balance',
                      style: TextStyle(color: textSecondary, fontSize: 13)),
                  const Spacer(),
                  Text('₹${opening.toStringAsFixed(2)}',
                      style: const TextStyle(
                          color: copperAccent,
                          fontSize: 15,
                          fontWeight: FontWeight.w800)),
                ]),
              ]),
        ),
        const SizedBox(height: 20),
        const Text('CLOSE SHIFT',
            style: TextStyle(
                color: textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1)),
        const SizedBox(height: 8),
        const Text(
            'Count every note and coin in the drawer at end of shift. The server will compute your expected cash from CASH bills you processed and flag any variance.',
            style: TextStyle(color: textSecondary, fontSize: 12)),
        const SizedBox(height: 12),
        TextField(
          controller: _closingCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: const TextStyle(
              color: textPrimary, fontSize: 18, fontWeight: FontWeight.w800),
          decoration: InputDecoration(
            labelText: 'Closing Balance',
            labelStyle: const TextStyle(color: textSecondary),
            prefixText: '₹ ',
            prefixStyle: const TextStyle(color: copperAccent, fontSize: 18),
            filled: true,
            fillColor: slateCard,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: dividerColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: dividerColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: copperAccent),
            ),
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _noteCtrl,
          maxLines: 2,
          style: const TextStyle(color: textPrimary, fontSize: 13),
          decoration: InputDecoration(
            labelText: 'Note (optional)',
            labelStyle: const TextStyle(color: textSecondary),
            filled: true,
            fillColor: slateCard,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: dividerColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: dividerColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: copperAccent),
            ),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.stop_circle_outlined, size: 18),
            label: const Text('Close Shift'),
            style: ElevatedButton.styleFrom(
              backgroundColor: crimson,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              textStyle:
                  const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
            ),
            onPressed: _busy ? null : _close,
          ),
        ),
      ],
    );
  }
}
