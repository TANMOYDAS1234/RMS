// ─── Manager: Kitchen Tab ─────────────────────────────────────────────────────
import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/config/app_theme.dart';
import '../../core/network/dio_client.dart';
import '../../core/services/websocket_service.dart';
import '../../core/utils/api_error.dart';
import '../../core/utils/idempotency.dart';
import '../state/auth_provider.dart';

// ── Provider ──────────────────────────────────────────────────────────────────
final _kitchenWorkloadProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final token = ref.watch(authProvider).token;
  final dio = createDioClient(token);
  final res = await dio.get('/manager/kitchen');
  return List<Map<String, dynamic>>.from(res.data);
});

// ── Status colors ─────────────────────────────────────────────────────────────
const _statusColors = {
  'confirmed': amber,
  'preparing': copperAccent,
  'ready':     emerald,
};

// ── Tab ───────────────────────────────────────────────────────────────────────
class ManagerKitchenTab extends ConsumerStatefulWidget {
  const ManagerKitchenTab({super.key});

  @override
  ConsumerState<ManagerKitchenTab> createState() => _ManagerKitchenTabState();
}

class _ManagerKitchenTabState extends ConsumerState<ManagerKitchenTab> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    // Rebuild every 30s so elapsed timers stay fresh
    _ticker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final kitchenAsync = ref.watch(_kitchenWorkloadProvider);

    ref.listen(wsEventsProvider, (_, next) {
      next.whenData((evt) {
        if (evt.event == 'order:updated' ||
            evt.event == 'order:created' ||
            evt.event == 'kitchen:progress') {
          ref.invalidate(_kitchenWorkloadProvider);
        }
      });
    });

    return RefreshIndicator(
      color: copperAccent,
      backgroundColor: slateCard,
      onRefresh: () async => ref.invalidate(_kitchenWorkloadProvider),
      child: kitchenAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(color: copperAccent)),
        error: (e, _) => Center(
            child: Text(describeApiError(e),
                style: const TextStyle(color: crimson, fontSize: 13))),
        data: (orders) => _KitchenBody(orders: orders),
      ),
    );
  }
}

// ── Body ──────────────────────────────────────────────────────────────────────
class _KitchenBody extends ConsumerWidget {
  final List<Map<String, dynamic>> orders;
  const _KitchenBody({required this.orders});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (orders.isEmpty) return _EmptyKitchen();

    final urgent   = orders.where((o) => o['isUrgent'] == true).toList();
    final normal   = orders.where((o) => o['isUrgent'] != true).toList();
    final byStatus = <String, int>{};
    for (final o in orders) {
      final s = o['status'] as String? ?? '';
      byStatus[s] = (byStatus[s] ?? 0) + 1;
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [
        // ── Summary strip ────────────────────────────────────────────────
        _SummaryStrip(total: orders.length, urgent: urgent.length, byStatus: byStatus),
        const SizedBox(height: 16),

        // ── Urgent banner ────────────────────────────────────────────────
        if (urgent.isNotEmpty) ...[
          _UrgentBanner(count: urgent.length),
          const SizedBox(height: 12),
          ...urgent.map((o) => _KitchenCard(
                order: o,
                isUrgent: true,
                onPrioritize: () => _prioritize(context, ref, (o['_id'] ?? o['id']).toString()),
              )),
          const SizedBox(height: 8),
          const _Divider(label: 'OTHER ORDERS'),
          const SizedBox(height: 8),
        ],

        // ── Normal orders ────────────────────────────────────────────────
        ...normal.map((o) => _KitchenCard(
              order: o,
              isUrgent: false,
              onPrioritize: () => _prioritize(context, ref, o['id'].toString()),
            )),
      ],
    );
  }

  Future<void> _prioritize(
      BuildContext context, WidgetRef ref, String orderId) async {
    try {
      final dio = createDioClient(ref.read(authProvider).token);
      await dio.patch(
        '/manager/order-action/prioritize/$orderId',
        options: Options(headers: {
          'Idempotency-Key': newIdempotencyKey('prioritize-$orderId'),
        }),
      );
      ref.invalidate(_kitchenWorkloadProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Order marked as priority'),
          backgroundColor: copperAccent,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(describeApiError(e)),
          backgroundColor: crimson,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }
}

// ── Summary strip ─────────────────────────────────────────────────────────────
class _SummaryStrip extends StatelessWidget {
  final int total;
  final int urgent;
  final Map<String, int> byStatus;
  const _SummaryStrip(
      {required this.total, required this.urgent, required this.byStatus});

  @override
  Widget build(BuildContext context) => Row(children: [
        _Chip('Total', '$total', copperAccent),
        const SizedBox(width: 8),
        _Chip('Urgent', '$urgent', urgent > 0 ? crimson : textSecondary),
        const SizedBox(width: 8),
        _Chip('Confirmed', '${byStatus['confirmed'] ?? 0}', amber),
        const SizedBox(width: 8),
        _Chip('Ready', '${byStatus['ready'] ?? 0}', emerald),
      ]);
}

class _Chip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _Chip(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Column(children: [
            Text(value,
                style: TextStyle(
                    color: color, fontSize: 16, fontWeight: FontWeight.w800)),
            Text(label,
                style: const TextStyle(color: textSecondary, fontSize: 9),
                textAlign: TextAlign.center),
          ]),
        ),
      );
}

// ── Urgent banner ─────────────────────────────────────────────────────────────
class _UrgentBanner extends StatelessWidget {
  final int count;
  const _UrgentBanner({required this.count});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: crimson.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: crimson.withValues(alpha: 0.3)),
        ),
        child: Row(children: [
          const Icon(Icons.timer_off_outlined, color: crimson, size: 16),
          const SizedBox(width: 8),
          Text(
            '$count order${count > 1 ? 's' : ''} delayed — over 15 minutes',
            style: const TextStyle(
                color: crimson, fontSize: 13, fontWeight: FontWeight.w700),
          ),
        ]),
      ).animate(onPlay: (c) => c.repeat(reverse: true))
          .fadeIn(duration: 800.ms).then().fadeOut(duration: 800.ms);
}

// ── Kitchen card ──────────────────────────────────────────────────────────────
class _KitchenCard extends StatelessWidget {
  final Map<String, dynamic> order;
  final bool isUrgent;
  final VoidCallback onPrioritize;

  const _KitchenCard({
    required this.order,
    required this.isUrgent,
    required this.onPrioritize,
  });

  @override
  Widget build(BuildContext context) {
    final status    = order['status'] as String? ?? '';
    final color     = _statusColors[status] ?? textSecondary;
    final mins      = order['minutesElapsed'] as int? ?? 0;
    final itemCount = order['itemCount'] as int? ?? 0;
    final items     = List<Map<String, dynamic>>.from(order['items'] ?? []);
    final tableLabel = order['tableLabel'] as String? ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: slateCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isUrgent ? crimson.withValues(alpha: 0.6) : color.withValues(alpha: 0.3),
          width: isUrgent ? 2 : 1,
        ),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Header ──────────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isUrgent
                ? crimson.withValues(alpha: 0.08)
                : color.withValues(alpha: 0.06),
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(15)),
          ),
          child: Row(children: [
            // Pulsing dot for urgent
            if (isUrgent)
              Container(
                width: 8, height: 8,
                margin: const EdgeInsets.only(right: 8),
                decoration:
                    const BoxDecoration(color: crimson, shape: BoxShape.circle),
              ).animate(onPlay: (c) => c.repeat())
                  .fadeIn(duration: 600.ms).then().fadeOut(duration: 600.ms),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(tableLabel,
                    style: const TextStyle(
                        color: textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w800)),
                Text('$itemCount item${itemCount != 1 ? 's' : ''}',
                    style: const TextStyle(
                        color: textSecondary, fontSize: 11)),
              ]),
            ),
            // Elapsed timer
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: isUrgent
                    ? crimson.withValues(alpha: 0.15)
                    : slateSurface,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.timer_outlined,
                    size: 12,
                    color: isUrgent ? crimson : textSecondary),
                const SizedBox(width: 4),
                Text('${mins}m',
                    style: TextStyle(
                        color: isUrgent ? crimson : textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w700)),
              ]),
            ),
            const SizedBox(width: 8),
            // Status badge
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(status.toUpperCase(),
                  style: TextStyle(
                      color: color,
                      fontSize: 9,
                      fontWeight: FontWeight.w700)),
            ),
          ]),
        ),

        // ── Items list ───────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
          child: Column(
            children: items.map((item) {
              final progress =
                  (item['progress'] as num? ?? 0).toDouble();
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(children: [
                  Container(
                    width: 22, height: 22,
                    decoration: BoxDecoration(
                      color: copperAccent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Center(
                      child: Text('${item['quantity'] ?? 1}',
                          style: const TextStyle(
                              color: copperAccent,
                              fontSize: 10,
                              fontWeight: FontWeight.w800)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(item['name'] ?? '',
                          style: const TextStyle(
                              color: textPrimary, fontSize: 12)),
                      if (progress > 0) ...[
                        const SizedBox(height: 3),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: progress,
                            backgroundColor: slateSurface,
                            valueColor: AlwaysStoppedAnimation<Color>(
                                progress >= 1.0 ? emerald : copperAccent),
                            minHeight: 3,
                          ),
                        ),
                      ],
                    ]),
                  ),
                ]),
              );
            }).toList(),
          ),
        ),

        // ── Footer: prioritize button ────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
          child: Row(children: [
            const Spacer(),
            GestureDetector(
              onTap: onPrioritize,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isUrgent
                      ? crimson.withValues(alpha: 0.12)
                      : copperAccent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isUrgent
                        ? crimson.withValues(alpha: 0.3)
                        : copperAccent.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.bolt,
                      size: 13,
                      color: isUrgent ? crimson : copperAccent),
                  const SizedBox(width: 4),
                  Text('Prioritize',
                      style: TextStyle(
                          color: isUrgent ? crimson : copperAccent,
                          fontSize: 11,
                          fontWeight: FontWeight.w700)),
                ]),
              ),
            ),
          ]),
        ),
      ]),
    ).animate().fadeIn(duration: 300.ms);
  }
}

// ── Section divider ───────────────────────────────────────────────────────────
class _Divider extends StatelessWidget {
  final String label;
  const _Divider({required this.label});

  @override
  Widget build(BuildContext context) => Row(children: [
        const Expanded(child: Divider(color: dividerColor)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(label,
              style: const TextStyle(
                  color: textSecondary,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1)),
        ),
        const Expanded(child: Divider(color: dividerColor)),
      ]);
}

// ── Empty state ───────────────────────────────────────────────────────────────
class _EmptyKitchen extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.check_circle_outline,
              size: 56, color: emerald.withValues(alpha: 0.5)),
          const SizedBox(height: 16),
          const Text('Kitchen is clear!',
              style: TextStyle(
                  color: textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          const Text('No active kitchen orders',
              style: TextStyle(color: textSecondary, fontSize: 13)),
        ]),
      );
}
