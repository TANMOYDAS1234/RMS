// ─── Admin Portal — Complete Production-Grade Screen ─────────────────────────
// Tabs: Overview · Analytics · Staff · Orders · Billing · Inventory · System

import 'dart:async';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_picker/file_picker.dart';
import '../../core/config/app_config.dart';
import '../../core/config/app_theme.dart';
import '../../core/network/dio_client.dart';
import '../../core/services/websocket_service.dart';
import '../../core/utils/web_window.dart';
import '../../domain/entities/user_entity.dart';
import '../../core/utils/api_error.dart';
import '../../core/utils/file_download.dart';
import '../../core/utils/idempotency.dart';
import '../../data/api/admin_api.dart';
import '../state/auth_provider.dart';
import '../state/order_providers.dart';
import 'admin_onboarding_screen.dart';

/// Roles for which we have already pushed the first-launch wizard this
/// session. Stops the same admin getting re-walked through onboarding
/// on every tab switch. Reset on cold start.
final Set<String> _onboardingShownFor = {};

// ═══════════════════════════════════════════════════════════════════════════════
// PROVIDERS
// ═══════════════════════════════════════════════════════════════════════════════

// Each provider is now a 2-line wrapper around an AdminApi method.
// adminApiProvider rebuilds the Dio client when the token changes, so
// these never serve stale auth.

/// Date range used by the analytics tab. Default: last 7 days.
class AnalyticsRange {
  final DateTime from;
  final DateTime to;
  const AnalyticsRange(this.from, this.to);
}

AnalyticsRange _defaultAnalyticsRange() {
  final now = DateTime.now();
  return AnalyticsRange(now.subtract(const Duration(days: 7)), now);
}

final analyticsRangeProvider =
    StateProvider<AnalyticsRange>((_) => _defaultAnalyticsRange());

final _salesProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>(
    (ref) {
  final r = ref.watch(analyticsRangeProvider);
  return ref.watch(adminApiProvider).sales(from: r.from, to: r.to);
});

final _topItemsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  final r = ref.watch(analyticsRangeProvider);
  return ref.watch(adminApiProvider).topItems(from: r.from, to: r.to);
});

final _peakHoursProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  final r = ref.watch(analyticsRangeProvider);
  return ref.watch(adminApiProvider).peakHours(from: r.from, to: r.to);
});

final adminStaffProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>(
    (ref) => ref.watch(adminApiProvider).users());

final _branchesProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>(
        (ref) => ref.watch(adminApiProvider).branches());

final _systemHealthProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>(
        (ref) => ref.watch(adminApiProvider).systemHealth());

final _financialSummaryProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>(
        (ref) => ref.watch(adminApiProvider).financialSummary());

final _transactionsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>(
        (ref) => ref.watch(adminApiProvider).transactions());

final _profitMarginProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>(
        (ref) => ref.watch(adminApiProvider).profitMargin());

// ── Cross-cutting audit feed (auth + RBAC + refund + inventory approvals) ──
//
// Held as a single immutable filter object so widget rebuilds stay cheap
// — Riverpod only re-fetches when the user actually changes a field.
class AuditFilter {
  final String? type;     // empty string in dropdown → null here
  final String? actorId;  // free-form actor id / email substring
  final DateTime? from;
  final DateTime? to;

  const AuditFilter({this.type, this.actorId, this.from, this.to});

  AuditFilter copyWith({
    Object? type = _sentinel,
    Object? actorId = _sentinel,
    Object? from = _sentinel,
    Object? to = _sentinel,
  }) =>
      AuditFilter(
        type: type == _sentinel ? this.type : type as String?,
        actorId: actorId == _sentinel ? this.actorId : actorId as String?,
        from: from == _sentinel ? this.from : from as DateTime?,
        to: to == _sentinel ? this.to : to as DateTime?,
      );

  static const _sentinel = Object();
}

final auditFilterProvider =
    StateProvider<AuditFilter>((_) => const AuditFilter());

final auditEventsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final f = ref.watch(auditFilterProvider);
  final page = await ref.watch(adminApiProvider).auditEvents(
        type: f.type,
        actorId: f.actorId,
        from: f.from,
        to: f.to,
      );
  return List<Map<String, dynamic>>.from(page['items'] ?? []);
});

final _inventoryAdminProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>(
        (ref) => ref.watch(adminApiProvider).inventory());

final _allOrdersProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>(
        (ref) => ref.watch(adminApiProvider).activeOrders());

final _menuProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>(
        (ref, branchId) => ref.watch(adminApiProvider).menuForBranch(branchId));

final _staffAnalyticsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  final r = ref.watch(analyticsRangeProvider);
  return ref.watch(adminApiProvider).staffPerformance(from: r.from, to: r.to);
});

// Cross-branch comparison — admin-only. Reuses the same analytics range
// picker as the Analytics tab so changing the range there flows through
// here too (and vice versa) without forcing the admin to re-pick.
final _branchComparisonProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  final r = ref.watch(analyticsRangeProvider);
  return ref.watch(adminApiProvider).branchComparison(from: r.from, to: r.to);
});

// ═══════════════════════════════════════════════════════════════════════════════
// TAB 1 — OVERVIEW
// ═══════════════════════════════════════════════════════════════════════════════

class AdminOverviewTab extends ConsumerStatefulWidget {
  const AdminOverviewTab({super.key});

  @override
  ConsumerState<AdminOverviewTab> createState() => _AdminOverviewTabState();
}

class _AdminOverviewTabState extends ConsumerState<AdminOverviewTab> {
  // 30-second auto-refresh so "Live Operations" stays live even if a
  // WebSocket push drops or the user keeps the tab open through a Render
  // cold-start. Pull-to-refresh still works for an immediate kick.
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted) return;
      ref.invalidate(_systemHealthProvider);
      ref.invalidate(_financialSummaryProvider);
      ref.invalidate(_allOrdersProvider);
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final metrics = ref.watch(dashboardMetricsProvider);
    final orders = ref.watch(liveOrdersProvider);
    final healthAsync = ref.watch(_systemHealthProvider);
    final finAsync = ref.watch(_financialSummaryProvider);
    final branchesAsync = ref.watch(_branchesProvider);

    // First-launch onboarding — when the admin has zero branches we
    // push the wizard once after the first frame. The dialog flag stops
    // the same admin from being walked through every tab switch. Once
    // they finish (or kill the app and come back with branches
    // configured), the condition no longer fires.
    branchesAsync.whenData((branches) {
      if (branches.isEmpty && !_onboardingShownFor.contains('admin')) {
        _onboardingShownFor.add('admin');
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!context.mounted) return;
          Navigator.of(context).push(MaterialPageRoute(
            fullscreenDialog: true,
            builder: (_) => const AdminOnboardingScreen(),
          )).then((_) => ref.invalidate(_branchesProvider));
        });
      }
    });

    // Live data — refresh on relevant server pushes.
    ref.listen(wsEventsProvider, (_, next) {
      next.whenData((evt) {
        if (evt.event == 'order:updated' ||
            evt.event == 'order:created' ||
            evt.event == 'table:updated') {
          ref.invalidate(_systemHealthProvider);
          ref.invalidate(_financialSummaryProvider);
        }
      });
    });

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const _SectionTitle('Live Operations'),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.6,
          children: [
            _MetricCard('Active Orders', '${metrics.activeOrders}', Icons.receipt_outlined, copperAccent),
            _MetricCard('Occupied Tables', '${metrics.occupiedTables}/${metrics.totalTables}', Icons.table_restaurant_outlined, amber),
            _MetricCard("Today's Revenue", '₹${metrics.revenue.toStringAsFixed(0)}', Icons.attach_money, emerald),
            _MetricCard('Total Orders', '${orders.length}', Icons.list_alt_outlined, roseGold),
          ],
        ),
        const SizedBox(height: 20),
        // Financial snapshot
        finAsync.when(
          loading: () => const _ChartSkeleton(height: 100),
          error: (_, __) => const SizedBox.shrink(),
          data: (fin) => _FinancialSnapshot(data: fin),
        ),
        const SizedBox(height: 20),
        const _SectionTitle('Order Pipeline'),
        const SizedBox(height: 12),
        _OrderPipeline(orders: orders),
        const SizedBox(height: 20),
        // System health
        healthAsync.when(
          loading: () => const _ChartSkeleton(height: 80),
          error: (_, __) => const SizedBox.shrink(),
          data: (h) => _SystemHealthBanner(health: h),
        ),
      ],
    );
  }
}

class _FinancialSnapshot extends StatelessWidget {
  final Map<String, dynamic> data;
  const _FinancialSnapshot({required this.data});

  @override
  Widget build(BuildContext context) {
    final gross = (data['grossRevenue'] as num? ?? 0).toDouble();
    final net = (data['netRevenue'] as num? ?? 0).toDouble();
    final refunded = (data['refundedAmount'] as num? ?? 0).toDouble();
    final pending = (data['pendingAmount'] as num? ?? 0).toDouble();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: slateCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: emerald.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.today_outlined, color: emerald, size: 16),
            const SizedBox(width: 6),
            Text("Today — ${data['date'] ?? ''}", style: const TextStyle(color: textSecondary, fontSize: 12)),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            _FinStat('Gross', '₹${gross.toStringAsFixed(0)}', emerald),
            _FinStat('Net', '₹${net.toStringAsFixed(0)}', copperAccent),
            _FinStat('Refunded', '₹${refunded.toStringAsFixed(0)}', crimson),
            _FinStat('Pending', '₹${pending.toStringAsFixed(0)}', amber),
          ]),
        ],
      ),
    );
  }
}

class _FinStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _FinStat(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(
          children: [
            Text(value, style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(color: textSecondary, fontSize: 10)),
          ],
        ),
      );
}

class _SystemHealthBanner extends StatelessWidget {
  final Map<String, dynamic> health;
  const _SystemHealthBanner({required this.health});

  @override
  Widget build(BuildContext context) {
    final ok = health['status'] == 'ok';
    final color = ok ? emerald : crimson;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(children: [
        Icon(ok ? Icons.check_circle_outline : Icons.error_outline, color: color, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text('System ${ok ? "Healthy" : "Degraded"}',
            style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 13))),
        Text('${health['activeUsers'] ?? 0} users online',
            style: const TextStyle(color: textSecondary, fontSize: 11)),
      ]),
    );
  }
}

class _OrderPipeline extends StatelessWidget {
  final List orders;
  const _OrderPipeline({required this.orders});

  @override
  Widget build(BuildContext context) {
    final stages = ['created', 'confirmed', 'preparing', 'ready', 'served'];
    return Row(
      children: stages.map((stage) {
        final count = orders.where((o) => o.status.statusName == stage).length;
        return Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 3),
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: slateCard,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: dividerColor),
            ),
            child: Column(children: [
              Text('$count', style: const TextStyle(color: copperAccent, fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(stage, style: const TextStyle(color: textSecondary, fontSize: 9), textAlign: TextAlign.center),
            ]),
          ),
        );
      }).toList(),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TAB 2 — ANALYTICS
// ═══════════════════════════════════════════════════════════════════════════════

class AdminAnalyticsTab extends ConsumerWidget {
  const AdminAnalyticsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final salesAsync = ref.watch(_salesProvider);
    final topItemsAsync = ref.watch(_topItemsProvider);
    final peakAsync = ref.watch(_peakHoursProvider);
    final profitAsync = ref.watch(_profitMarginProvider);
    final staffAsync = ref.watch(_staffAnalyticsProvider);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const _AnalyticsRangePicker(),
        const SizedBox(height: 20),
        const _SectionTitle('Revenue'),
        const SizedBox(height: 12),
        salesAsync.when(
          loading: () => const _ChartSkeleton(),
          error: (e, _) => _ErrorText(describeApiError(e)),
          data: (data) => _RevenueChart(data: data),
        ),
        const SizedBox(height: 24),
        // Profit margin card
        profitAsync.when(
          loading: () => const _ChartSkeleton(height: 100),
          error: (_, __) => const SizedBox.shrink(),
          data: (p) => _ProfitCard(data: p),
        ),
        const SizedBox(height: 24),
        const _SectionTitle('Peak Hours'),
        const SizedBox(height: 12),
        peakAsync.when(
          loading: () => const _ChartSkeleton(),
          error: (e, _) => _ErrorText(describeApiError(e)),
          data: (data) => _PeakHoursChart(data: data),
        ),
        const SizedBox(height: 24),
        const _SectionTitle('Top Menu Items'),
        const SizedBox(height: 12),
        topItemsAsync.when(
          loading: () => const _ChartSkeleton(height: 120),
          error: (e, _) => _ErrorText(describeApiError(e)),
          data: (items) => Column(
            children: items.take(8).map((item) => _TopItemRow(item: item)).toList(),
          ),
        ),
        const SizedBox(height: 24),
        const _SectionTitle('Staff Performance'),
        const SizedBox(height: 12),
        staffAsync.when(
          loading: () => const _ChartSkeleton(height: 100),
          error: (_, __) => const Center(child: Text('No staff analytics', style: TextStyle(color: textSecondary))),
          data: (staff) => Column(
            children: staff.take(5).map((s) => _StaffPerfRow(data: s)).toList(),
          ),
        ),
      ],
    );
  }
}

class _AnalyticsRangePicker extends ConsumerWidget {
  const _AnalyticsRangePicker();

  static const _presets = <_Preset>[
    _Preset('Today', 0),
    _Preset('7d', 7),
    _Preset('30d', 30),
    _Preset('90d', 90),
  ];

  bool _matches(_Preset p, AnalyticsRange r) {
    final now = DateTime.now();
    final expected = now.subtract(Duration(days: p.days));
    return r.from.year == expected.year &&
        r.from.month == expected.month &&
        r.from.day == expected.day;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final range = ref.watch(analyticsRangeProvider);
    final label =
        '${DateFormat('dd MMM').format(range.from)} – ${DateFormat('dd MMM').format(range.to)}';
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: slateCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: dividerColor),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.calendar_today_outlined,
              color: copperAccent, size: 14),
          const SizedBox(width: 8),
          Text(label,
              style: const TextStyle(
                  color: textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700)),
          const Spacer(),
          GestureDetector(
            onTap: () async {
              final now = DateTime.now();
              final picked = await showDateRangePicker(
                context: context,
                firstDate: DateTime(now.year - 2),
                lastDate: now,
                initialDateRange:
                    DateTimeRange(start: range.from, end: range.to),
                builder: (ctx, child) => Theme(
                  data: datePickerTheme(ctx),
                  child: child!,
                ),
              );
              if (picked != null) {
                ref.read(analyticsRangeProvider.notifier).state =
                    AnalyticsRange(picked.start, picked.end);
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: copperAccent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.date_range, color: copperAccent, size: 12),
                SizedBox(width: 4),
                Text('Custom',
                    style: TextStyle(
                        color: copperAccent,
                        fontSize: 11,
                        fontWeight: FontWeight.w700)),
              ]),
            ),
          ),
        ]),
        const SizedBox(height: 10),
        Row(
          children: _presets.map((p) {
            final selected = _matches(p, range);
            return Expanded(
              child: GestureDetector(
                onTap: () {
                  final now = DateTime.now();
                  ref.read(analyticsRangeProvider.notifier).state =
                      AnalyticsRange(
                          now.subtract(Duration(days: p.days)), now);
                },
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: selected
                        ? copperAccent.withValues(alpha: 0.18)
                        : slateSurface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: selected ? copperAccent : dividerColor,
                    ),
                  ),
                  child: Center(
                    child: Text(p.label,
                        style: TextStyle(
                            color: selected ? copperAccent : textPrimary,
                            fontSize: 11,
                            fontWeight: FontWeight.w700)),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ]),
    );
  }
}

class _Preset {
  final String label;
  final int days;
  const _Preset(this.label, this.days);
}

class _ProfitCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _ProfitCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final margin = (data['profitMarginPercent'] as num? ?? 0).toDouble();
    final color = margin >= 30 ? emerald : margin >= 15 ? amber : crimson;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: slateCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const _SectionTitle('Profit Margin (30 days)'),
          const Spacer(),
          Text('${margin.toStringAsFixed(1)}%',
              style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.w800)),
        ]),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: (margin / 100).clamp(0.0, 1.0),
            backgroundColor: slateSurface,
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 6,
          ),
        ),
        const SizedBox(height: 10),
        Row(children: [
          _FinStat('Gross Rev', '₹${((data['grossRevenue'] ?? 0) as num).toStringAsFixed(0)}', textPrimary),
          _FinStat('COGS', '₹${((data['estimatedCOGS'] ?? 0) as num).toStringAsFixed(0)}', crimson),
          _FinStat('Profit', '₹${((data['grossProfit'] ?? 0) as num).toStringAsFixed(0)}', color),
        ]),
      ]),
    );
  }
}

class _StaffPerfRow extends StatelessWidget {
  final Map<String, dynamic> data;
  const _StaffPerfRow({required this.data});

  @override
  Widget build(BuildContext context) {
    final orders = data['ordersHandled'] as int? ?? 0;
    final name = data['name'] as String? ?? 'Staff';
    final role = data['role'] as String? ?? '';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(color: slateCard, borderRadius: BorderRadius.circular(10)),
      child: Row(children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: copperAccent.withValues(alpha: 0.15),
          child: Text(name.substring(0, 1).toUpperCase(),
              style: const TextStyle(color: copperAccent, fontSize: 13, fontWeight: FontWeight.w700)),
        ),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name, style: const TextStyle(color: textPrimary, fontSize: 12, fontWeight: FontWeight.w600)),
          Text(role.toUpperCase(), style: const TextStyle(color: textSecondary, fontSize: 10)),
        ])),
        Text('$orders orders', style: const TextStyle(color: copperAccent, fontSize: 12, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

class _RevenueChart extends StatelessWidget {
  final List<Map<String, dynamic>> data;
  const _RevenueChart({required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const Center(child: Text('No data', style: TextStyle(color: textSecondary)));
    final spots = data.asMap().entries.map((e) =>
        FlSpot(e.key.toDouble(), (e.value['revenue'] ?? 0).toDouble())).toList();

    return Container(
      height: 180,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: slateCard, borderRadius: BorderRadius.circular(14)),
      child: LineChart(LineChartData(
        gridData: FlGridData(
          show: true,
          getDrawingHorizontalLine: (_) => const FlLine(color: dividerColor, strokeWidth: 0.5),
          drawVerticalLine: false,
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(sideTitles: SideTitles(
            showTitles: true, reservedSize: 40,
            getTitlesWidget: (v, _) => Text('₹${v.toInt()}', style: const TextStyle(color: textSecondary, fontSize: 9)),
          )),
          bottomTitles: AxisTitles(sideTitles: SideTitles(
            showTitles: true,
            getTitlesWidget: (v, _) {
              final idx = v.toInt();
              if (idx < 0 || idx >= data.length) return const SizedBox.shrink();
              final date = data[idx]['_id'] as String? ?? '';
              return Text(date.length >= 10 ? date.substring(5) : date,
                  style: const TextStyle(color: textSecondary, fontSize: 9));
            },
          )),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [LineChartBarData(
          spots: spots, isCurved: true, color: copperAccent, barWidth: 2.5,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(show: true, color: copperAccent.withValues(alpha: 0.1)),
        )],
      )),
    );
  }
}

class _PeakHoursChart extends StatelessWidget {
  final List<Map<String, dynamic>> data;
  const _PeakHoursChart({required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const Center(child: Text('No data', style: TextStyle(color: textSecondary)));
    final maxCount = data.fold<int>(0, (m, e) => (e['count'] as int? ?? 0) > m ? (e['count'] as int) : m);
    return Container(
      height: 140,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: slateCard, borderRadius: BorderRadius.circular(14)),
      child: BarChart(BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxCount.toDouble() * 1.2,
        barTouchData: BarTouchData(enabled: false),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(sideTitles: SideTitles(
            showTitles: true,
            getTitlesWidget: (v, _) => Text('${v.toInt()}h', style: const TextStyle(color: textSecondary, fontSize: 9)),
          )),
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        gridData: const FlGridData(show: false),
        barGroups: data.map((d) => BarChartGroupData(
          x: (d['hour'] as int? ?? 0),
          barRods: [BarChartRodData(
            toY: (d['count'] as int? ?? 0).toDouble(),
            color: copperAccent, width: 8,
            borderRadius: BorderRadius.circular(4),
          )],
        )).toList(),
      )),
    );
  }
}

class _TopItemRow extends StatelessWidget {
  final Map<String, dynamic> item;
  const _TopItemRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final qty = item['totalQty'] as int? ?? 0;
    final revenue = (item['totalRevenue'] as num?)?.toDouble() ?? 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(color: slateCard, borderRadius: BorderRadius.circular(10)),
      child: Row(children: [
        Expanded(child: Text(item['name'] ?? '', style: const TextStyle(color: textPrimary, fontSize: 13, fontWeight: FontWeight.w600))),
        Text('$qty sold', style: const TextStyle(color: textSecondary, fontSize: 12)),
        const SizedBox(width: 12),
        Text('₹${revenue.toStringAsFixed(0)}', style: const TextStyle(color: copperAccent, fontSize: 13, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TAB — CROSS-BRANCH COMPARISON (admin only)
// ═══════════════════════════════════════════════════════════════════════════════

class AdminComparisonTab extends ConsumerWidget {
  const AdminComparisonTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Defense-in-depth: this tab is wired into the admin-only role tabs
    // list in main.dart, but if a future caller surfaces it elsewhere we
    // render a clean "admin only" empty state instead of letting the
    // backend 403 land as a generic error.
    final role = ref.watch(authProvider).user?.role;
    if (role != UserRole.admin) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_outline,
                  size: 56, color: textSecondary.withValues(alpha: 0.4)),
              const SizedBox(height: 16),
              const Text('Admins only',
                  style: TextStyle(
                      color: textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              const Text(
                'Cross-branch comparisons are limited to chain administrators.',
                textAlign: TextAlign.center,
                style: TextStyle(color: textSecondary, fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }
    final dataAsync = ref.watch(_branchComparisonProvider);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const _AnalyticsRangePicker(),
        const SizedBox(height: 20),
        const _SectionTitle('Branch Comparison'),
        const SizedBox(height: 12),
        dataAsync.when(
          loading: () => const _ChartSkeleton(height: 220),
          error: (e, _) => _ErrorText(describeApiError(e)),
          data: (rows) {
            if (rows.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text('No paid bills in this range',
                      style: TextStyle(color: textSecondary)),
                ),
              );
            }
            return Column(
              children: [
                _BranchRevenueBars(rows: rows),
                const SizedBox(height: 20),
                _BranchComparisonTable(rows: rows),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _BranchRevenueBars extends StatelessWidget {
  final List<Map<String, dynamic>> rows;
  const _BranchRevenueBars({required this.rows});

  @override
  Widget build(BuildContext context) {
    final maxRev = rows.fold<double>(
        0, (m, r) {
      final v = (r['revenue'] as num? ?? 0).toDouble();
      return v > m ? v : m;
    });
    if (maxRev == 0) {
      return const SizedBox.shrink();
    }
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: slateCard,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Revenue by Branch',
              style: TextStyle(
                  color: textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          ...rows.map((r) {
            final name = (r['branchName'] as String?) ?? 'Unknown';
            final rev = (r['revenue'] as num? ?? 0).toDouble();
            final pct = (rev / maxRev).clamp(0.0, 1.0);
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(
                      child: Text(name,
                          style: const TextStyle(
                              color: textPrimary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                    ),
                    Text('₹${rev.toStringAsFixed(0)}',
                        style: const TextStyle(
                            color: copperAccent,
                            fontSize: 12,
                            fontWeight: FontWeight.w700)),
                  ]),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: pct,
                      backgroundColor: slateSurface,
                      valueColor:
                          const AlwaysStoppedAnimation<Color>(copperAccent),
                      minHeight: 8,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _BranchComparisonTable extends StatelessWidget {
  final List<Map<String, dynamic>> rows;
  const _BranchComparisonTable({required this.rows});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: slateCard,
        borderRadius: BorderRadius.circular(14),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor:
              WidgetStateProperty.all(slateSurface),
          dataRowColor: WidgetStateProperty.all(Colors.transparent),
          columnSpacing: 24,
          horizontalMargin: 16,
          headingTextStyle: const TextStyle(
              color: textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w700),
          dataTextStyle:
              const TextStyle(color: textPrimary, fontSize: 12),
          columns: const [
            DataColumn(label: Text('Branch')),
            DataColumn(label: Text('Revenue'), numeric: true),
            DataColumn(label: Text('Orders'), numeric: true),
            DataColumn(label: Text('Avg Order'), numeric: true),
            DataColumn(label: Text('GST'), numeric: true),
          ],
          rows: rows.map((r) {
            final name = (r['branchName'] as String?) ?? 'Unknown';
            final rev = (r['revenue'] as num? ?? 0).toDouble();
            final orders = (r['orderCount'] as num? ?? 0).toInt();
            final avg = (r['avgOrderValue'] as num? ?? 0).toDouble();
            final gst = (r['gstCollected'] as num? ?? 0).toDouble();
            return DataRow(cells: [
              DataCell(Text(name,
                  style: const TextStyle(
                      color: textPrimary, fontWeight: FontWeight.w600))),
              DataCell(Text('₹${rev.toStringAsFixed(0)}',
                  style: const TextStyle(
                      color: copperAccent, fontWeight: FontWeight.w700))),
              DataCell(Text('$orders')),
              DataCell(Text('₹${avg.toStringAsFixed(0)}')),
              DataCell(Text('₹${gst.toStringAsFixed(0)}',
                  style: const TextStyle(color: emerald))),
            ]);
          }).toList(),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TAB 3 — STAFF MANAGEMENT
// ═══════════════════════════════════════════════════════════════════════════════

class AdminStaffTab extends ConsumerWidget {
  const AdminStaffTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final staffAsync = ref.watch(adminStaffProvider);

    return Stack(
      children: [
        staffAsync.when(
          loading: () => const Center(child: CircularProgressIndicator(color: copperAccent)),
          error: (e, _) => Center(child: _ErrorText(describeApiError(e))),
          data: (staff) => ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            itemCount: staff.length,
            itemBuilder: (_, i) => _StaffCard(user: staff[i]),
          ),
        ),
        Positioned(
          bottom: 16,
          right: 16,
          child: FloatingActionButton.extended(
            heroTag: 'admin_staff_fab',
            backgroundColor: copperAccent,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.person_add_outlined),
            label: const Text('Add Staff', style: TextStyle(fontWeight: FontWeight.w700)),
            onPressed: () => _showAddStaffSheet(context, ref),
          ),
        ),
      ],
    );
  }

  void _showAddStaffSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: slateCard,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => const _AddStaffSheet(),
    );
  }
}

class _AddStaffSheet extends ConsumerStatefulWidget {
  const _AddStaffSheet();
  @override
  ConsumerState<_AddStaffSheet> createState() => _AddStaffSheetState();
}

class _AddStaffSheetState extends ConsumerState<_AddStaffSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _passCtrl;
  late final String _idempotencyKey;
  String _selectedRole = 'waiter';
  String? _selectedBranchId;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
    _emailCtrl = TextEditingController();
    _passCtrl = TextEditingController();
    _idempotencyKey = newIdempotencyKey('create-user');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    setState(() => _submitting = true);
    try {
      final dio = createDioClient(ref.read(authProvider).token);
      await dio.post(
        '/users',
        data: {
          'name': _nameCtrl.text.trim(),
          'email': _emailCtrl.text.trim().toLowerCase(),
          'password': _passCtrl.text,
          'role': _selectedRole,
          // Optional for admin (can omit to make a branch-less account).
          // Backend forces manager's own branchId regardless.
          if (_selectedBranchId != null) 'branchId': _selectedBranchId,
        },
        options: Options(headers: {'Idempotency-Key': _idempotencyKey}),
      );
      ref.invalidate(adminStaffProvider);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) _showError(context, describeApiError(e));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final branchesAsync = ref.watch(_branchesProvider);
    return Padding(
        padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Add Staff Member', style: TextStyle(color: textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          _InputField(ctrl: _nameCtrl, label: 'Full Name'),
          const SizedBox(height: 10),
          _InputField(ctrl: _emailCtrl, label: 'Email', keyboardType: TextInputType.emailAddress),
          const SizedBox(height: 10),
          _InputField(ctrl: _passCtrl, label: 'Password', obscure: true),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            value: _selectedRole,
            dropdownColor: slateSurface,
            style: const TextStyle(color: textPrimary),
            decoration: _inputDec('Role'),
            items: ['manager', 'waiter', 'chef', 'cashier']
                .map((r) => DropdownMenuItem(value: r, child: Text(r.toUpperCase())))
                .toList(),
            onChanged: (v) => setState(() => _selectedRole = v ?? 'waiter'),
          ),
          const SizedBox(height: 10),
          branchesAsync.when(
            loading: () => const LinearProgressIndicator(color: copperAccent),
            error: (_, __) => const SizedBox.shrink(),
            data: (branches) => DropdownButtonFormField<String>(
              value: _selectedBranchId,
              dropdownColor: slateSurface,
              style: const TextStyle(color: textPrimary),
              decoration: _inputDec('Branch (optional)'),
              items: [
                const DropdownMenuItem<String>(value: null, child: Text('— No branch —')),
                ...branches.map((b) => DropdownMenuItem<String>(
                      value: b['_id'] as String,
                      child: Text(b['name'] as String? ?? ''),
                    )),
              ],
              onChanged: (v) => setState(() => _selectedBranchId = v),
            ),
          ),
          const SizedBox(height: 16),
          _PrimaryButton(
            label: _submitting ? 'Creating…' : 'Create Account',
            onTap: _submitting ? () {} : _submit,
          ),
        ]),
      );
  }
}

class _StaffCard extends ConsumerWidget {
  final Map<String, dynamic> user;
  const _StaffCard({required this.user});

  static const _roleColors = {
    'admin': crimson, 'manager': roseGold, 'waiter': amber,
    'chef': copperAccent, 'cashier': emerald,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = user['role'] as String? ?? 'waiter';
    final color = _roleColors[role] ?? textSecondary;
    final isActive = user['isActive'] as bool? ?? true;
    final id = user['_id'] as String? ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: slateCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: dividerColor),
      ),
      child: Row(children: [
        _StaffAvatar(user: user, color: color, id: id),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(user['name'] ?? '', style: const TextStyle(color: textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
          Text(user['email'] ?? '', style: const TextStyle(color: textSecondary, fontSize: 11)),
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
            child: Text(role.toUpperCase(), style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 6),
          Row(mainAxisSize: MainAxisSize.min, children: [
            // Active toggle dot
            GestureDetector(
              onTap: () async {
                try {
                  final dio = createDioClient(ref.read(authProvider).token);
                  await dio.patch('/users/$id', data: {'isActive': !isActive},
                      options: Options(headers: {'Idempotency-Key': newIdempotencyKey('toggle-user-$id')}));
                  ref.invalidate(adminStaffProvider);
                } catch (e) {
                  if (context.mounted) _showError(context, describeApiError(e));
                }
              },
              child: Container(
                width: 8, height: 8,
                decoration: BoxDecoration(color: isActive ? emerald : textSecondary, shape: BoxShape.circle),
              ),
            ),
            const SizedBox(width: 8),
            // Edit details
            GestureDetector(
              onTap: () => showModalBottomSheet(
                context: context,
                backgroundColor: slateCard,
                isScrollControlled: true,
                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
                builder: (_) => _EditUserSheet(user: user),
              ),
              child: const Tooltip(
                message: 'Edit user',
                child: Icon(Icons.edit_outlined, color: textSecondary, size: 16),
              ),
            ),
            const SizedBox(width: 8),
            // Reset password
            GestureDetector(
              onTap: () => showModalBottomSheet(
                context: context,
                backgroundColor: slateCard,
                isScrollControlled: true,
                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
                builder: (_) => _ResetPasswordSheet(userId: id, userName: user['name'] as String? ?? ''),
              ),
              child: const Tooltip(
                message: 'Reset password',
                child: Icon(Icons.lock_reset_outlined, color: textSecondary, size: 16),
              ),
            ),
            const SizedBox(width: 8),
            // Delete staff
            GestureDetector(
              onTap: () => showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  backgroundColor: slateCard,
                  title: const Text('Remove Staff?', style: TextStyle(color: textPrimary)),
                  content: Text('This will permanently delete ${user['name'] ?? 'this user'}. This cannot be undone.',
                      style: const TextStyle(color: textSecondary)),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: textSecondary))),
                    TextButton(
                      onPressed: () async {
                        Navigator.pop(context);
                        try {
                          final dio = createDioClient(ref.read(authProvider).token);
                          await dio.delete(
                            '/users/$id',
                            options: Options(headers: {'Idempotency-Key': newIdempotencyKey('del-user-$id')}),
                          );
                          ref.invalidate(adminStaffProvider);
                          if (context.mounted) _showSuccess(context, 'Staff removed');
                        } catch (e) {
                          if (context.mounted) _showError(context, describeApiError(e));
                        }
                      },
                      child: const Text('Remove', style: TextStyle(color: crimson, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              ),
              child: const Tooltip(
                message: 'Delete',
                child: Icon(Icons.delete_outline, color: crimson, size: 16),
              ),
            ),
          ]),
        ]),
      ]),
    ).animate().fadeIn(duration: 250.ms);
  }
}

// ── Edit user sheet (was inline StatefulBuilder with leaking controllers) ────
class _EditUserSheet extends ConsumerStatefulWidget {
  final Map<String, dynamic> user;
  const _EditUserSheet({required this.user});
  @override
  ConsumerState<_EditUserSheet> createState() => _EditUserSheetState();
}

class _EditUserSheetState extends ConsumerState<_EditUserSheet> {
  late final TextEditingController _nameCtrl;
  late final String _userId;
  late final String _idempotencyKey;
  late String _role;
  String? _branchId;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _userId = (widget.user['_id'] as String?) ?? '';
    _nameCtrl = TextEditingController(text: widget.user['name'] as String? ?? '');
    _role = widget.user['role'] as String? ?? 'waiter';
    _branchId = widget.user['branchId'] as String?;
    _idempotencyKey = newIdempotencyKey('edit-user-$_userId');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_submitting) return;
    if (_nameCtrl.text.trim().isEmpty) return;
    setState(() => _submitting = true);
    try {
      final dio = createDioClient(ref.read(authProvider).token);
      await dio.patch(
        '/users/$_userId',
        data: {'name': _nameCtrl.text.trim(), 'role': _role, 'branchId': _branchId},
        options: Options(headers: {'Idempotency-Key': _idempotencyKey}),
      );
      ref.invalidate(adminStaffProvider);
      if (mounted) {
        Navigator.pop(context);
        _showSuccess(context, 'Staff updated');
      }
    } catch (e) {
      if (mounted) _showError(context, describeApiError(e));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final branchesAsync = ref.watch(_branchesProvider);
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Edit — ${widget.user['name'] ?? ''}',
            style: const TextStyle(color: textPrimary, fontSize: 15, fontWeight: FontWeight.w700)),
        const SizedBox(height: 16),
        _InputField(ctrl: _nameCtrl, label: 'Full Name'),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          value: _role,
          dropdownColor: slateSurface,
          style: const TextStyle(color: textPrimary),
          decoration: _inputDec('Role'),
          items: ['manager', 'waiter', 'chef', 'cashier']
              .map((r) => DropdownMenuItem(value: r, child: Text(r.toUpperCase())))
              .toList(),
          onChanged: (v) => setState(() => _role = v ?? _role),
        ),
        const SizedBox(height: 10),
        branchesAsync.when(
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
          data: (branches) => DropdownButtonFormField<String>(
            value: _branchId,
            dropdownColor: slateSurface,
            style: const TextStyle(color: textPrimary),
            decoration: _inputDec('Branch'),
            items: [
              const DropdownMenuItem(value: null, child: Text('No Branch')),
              ...branches.map((b) => DropdownMenuItem(
                value: b['_id'] as String,
                child: Text(b['name'] as String? ?? ''),
              )),
            ],
            onChanged: (v) => setState(() => _branchId = v),
          ),
        ),
        const SizedBox(height: 16),
        _PrimaryButton(
          label: _submitting ? 'Saving…' : 'Save Changes',
          onTap: _submitting ? () {} : _save,
        ),
      ]),
    );
  }
}

// ── Reset password sheet ─────────────────────────────────────────────────────
class _ResetPasswordSheet extends ConsumerStatefulWidget {
  final String userId;
  final String userName;
  const _ResetPasswordSheet({required this.userId, required this.userName});
  @override
  ConsumerState<_ResetPasswordSheet> createState() => _ResetPasswordSheetState();
}

class _ResetPasswordSheetState extends ConsumerState<_ResetPasswordSheet> {
  late final TextEditingController _ctrl;
  late final String _idempotencyKey;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController();
    _idempotencyKey = newIdempotencyKey('reset-pwd-${widget.userId}');
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (_ctrl.text.length < 6) return;
    setState(() => _submitting = true);
    try {
      final dio = createDioClient(ref.read(authProvider).token);
      await dio.post(
        '/admin/users/${widget.userId}/reset-password',
        data: {'newPassword': _ctrl.text},
        options: Options(headers: {'Idempotency-Key': _idempotencyKey}),
      );
      if (mounted) {
        Navigator.pop(context);
        _showSuccess(context, 'Password reset successfully');
      }
    } catch (e) {
      if (mounted) _showError(context, describeApiError(e));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Reset Password — ${widget.userName}',
              style: const TextStyle(color: textPrimary, fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          _InputField(ctrl: _ctrl, label: 'New Password (min 6 chars)', obscure: true),
          const SizedBox(height: 16),
          _PrimaryButton(
            label: _submitting ? 'Resetting…' : 'Reset Password',
            onTap: _submitting ? () {} : _submit,
          ),
        ]),
      );
}

// ═══════════════════════════════════════════════════════════════════════════════
// STAFF AVATAR — tappable, shows real photo or fallback letter
// ═══════════════════════════════════════════════════════════════════════════════

class _StaffAvatar extends ConsumerWidget {
  final Map<String, dynamic> user;
  final Color color;
  final String id;
  const _StaffAvatar({required this.user, required this.color, required this.id});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final photoUrl = user['photoUrl'] as String?;
    // Backend reuses the same /users/:id/photo URL on every upload, so we
    // tack on updatedAt to bust CachedNetworkImage's cache when the doc
    // changes.
    final updatedAt = user['updatedAt'];
    final v = updatedAt != null
        ? (DateTime.tryParse(updatedAt.toString())?.millisecondsSinceEpoch ?? 0)
        : 0;
    final fullUrl =
        photoUrl != null ? '${AppConfig.baseUrl}$photoUrl?v=$v' : null;
    final initials = (user['name'] as String? ?? 'U').substring(0, 1).toUpperCase();

    // View-only: admins inspect staff photos here but cannot change them.
    // The staff member changes their own photo from the profile screen
    // (and the admin changes their own via /admin/profile, not from this
    // list). No tap, no camera badge.
    return CircleAvatar(
      radius: 20,
      backgroundColor: color.withValues(alpha: 0.15),
      child: fullUrl != null
          ? ClipOval(
              child: CachedNetworkImage(
                imageUrl: fullUrl,
                width: 40,
                height: 40,
                fit: BoxFit.cover,
                placeholder: (_, __) => Text(initials,
                    style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w700)),
                errorWidget: (_, __, ___) => Text(initials,
                    style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            )
          : Text(initials, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w700)),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TAB 4 — ORDERS OVERSIGHT
// ═══════════════════════════════════════════════════════════════════════════════

class AdminOrdersTab extends ConsumerWidget {
  const AdminOrdersTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(_allOrdersProvider);

    ref.listen(wsEventsProvider, (_, next) {
      next.whenData((evt) {
        if (evt.event == 'order:updated' || evt.event == 'order:created') {
          ref.invalidate(_allOrdersProvider);
        }
      });
    });

    return RefreshIndicator(
      color: copperAccent,
      backgroundColor: slateCard,
      onRefresh: () async => ref.invalidate(_allOrdersProvider),
      child: ordersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: copperAccent)),
        error: (e, _) => Center(child: _ErrorText(describeApiError(e))),
        data: (orders) => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            // Summary row
            Row(children: [
              _SmallStat('Total', '${orders.length}', copperAccent),
              _SmallStat('Active', '${orders.where((o) => !['closed', 'paid'].contains(o['status'])).length}', amber),
              _SmallStat('Paid', '${orders.where((o) => o['status'] == 'paid').length}', emerald),
            ]),
            const SizedBox(height: 16),
            ...orders.map((o) => _AdminOrderCard(order: o)),
          ],
        ),
      ),
    );
  }
}

class _SmallStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _SmallStat(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Column(children: [
            Text(value, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.w800)),
            Text(label, style: const TextStyle(color: textSecondary, fontSize: 10)),
          ]),
        ),
      );
}

class _AdminOrderCard extends ConsumerWidget {
  final Map<String, dynamic> order;
  const _AdminOrderCard({required this.order});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = order['status'] as String? ?? '';
    final id = order['_id'] as String? ?? '';
    final isClosed = status == 'closed' || status == 'paid';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: slateCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: dividerColor),
      ),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Table ${order['tableLabel'] ?? ''}',
              style: const TextStyle(color: textPrimary, fontSize: 13, fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text('${(order['items'] as List?)?.length ?? 0} items',
              style: const TextStyle(color: textSecondary, fontSize: 11)),
        ])),
        _StatusBadge(status),
        const SizedBox(width: 8),
        if (!isClosed)
          GestureDetector(
            onTap: () => _confirmForceClose(context, ref, id),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: crimson.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: crimson.withValues(alpha: 0.3)),
              ),
              child: const Text('Force Close', style: TextStyle(color: crimson, fontSize: 10, fontWeight: FontWeight.w700)),
            ),
          ),
      ]),
    );
  }

  void _confirmForceClose(BuildContext context, WidgetRef ref, String id) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: slateCard,
        title: const Text('Force Close Order?', style: TextStyle(color: textPrimary)),
        content: const Text('This will immediately close the order. This action is logged.',
            style: TextStyle(color: textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: textSecondary))),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                final dio = createDioClient(ref.read(authProvider).token);
                await dio.patch(
                  '/admin/orders/$id/force-close',
                  options: Options(headers: {'Idempotency-Key': newIdempotencyKey('force-close-$id')}),
                );
                ref.invalidate(_allOrdersProvider);
                if (context.mounted) _showSuccess(context, 'Order force-closed');
              } catch (e) {
                if (context.mounted) _showError(context, describeApiError(e));
              }
            },
            child: const Text('Force Close', style: TextStyle(color: crimson, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TAB 5 — BILLING & PAYMENTS
// ═══════════════════════════════════════════════════════════════════════════════

class AdminBillingTab extends ConsumerWidget {
  const AdminBillingTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final txAsync = ref.watch(_transactionsProvider);
    final finAsync = ref.watch(_financialSummaryProvider);

    ref.listen(wsEventsProvider, (_, next) {
      next.whenData((evt) {
        if (evt.event == 'order:updated') {
          ref.invalidate(_transactionsProvider);
          ref.invalidate(_financialSummaryProvider);
        }
      });
    });

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // EOD summary
        finAsync.when(
          loading: () => const _ChartSkeleton(height: 120),
          error: (_, __) => const SizedBox.shrink(),
          data: (fin) => _EodSummaryCard(data: fin),
        ),
        const SizedBox(height: 20),
        const _TaxReportsCard(),
        const SizedBox(height: 20),
        // Pending refund requests — surfaced above the log because they
        // need an approve/deny decision from the manager (or admin).
        txAsync.when(
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
          data: (txs) {
            final pending = txs
                .where((t) => (t['refundStatus'] as String?) == 'PENDING')
                .toList();
            if (pending.isEmpty) return const SizedBox.shrink();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SectionTitle('Pending Refund Requests'),
                const SizedBox(height: 12),
                ...pending.map((tx) => _PendingRefundCard(tx: tx)),
                const SizedBox(height: 20),
              ],
            );
          },
        ),
        const _SectionTitle('Transaction Log'),
        const SizedBox(height: 12),
        txAsync.when(
          loading: () => const Center(child: CircularProgressIndicator(color: copperAccent)),
          error: (e, _) => _ErrorText(describeApiError(e)),
          data: (txs) => Column(
            children: txs.map((tx) => _TransactionCard(tx: tx)).toList(),
          ),
        ),
      ],
    );
  }
}

// ─── Tax Reports (GST CSV export) ───────────────────────────────────────────
//
// Two DatePicker rows + an Export button. Hits /billing/reports/gst as bytes
// so we can hand the same payload to a web Blob or a mobile share sheet
// without parsing it twice.
class _TaxReportsCard extends ConsumerStatefulWidget {
  const _TaxReportsCard();

  @override
  ConsumerState<_TaxReportsCard> createState() => _TaxReportsCardState();
}

class _TaxReportsCardState extends ConsumerState<_TaxReportsCard> {
  late DateTime _from;
  late DateTime _to;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _to = now;
    _from = now.subtract(const Duration(days: 30));
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final initial = isFrom ? _from : _to;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      builder: (ctx, child) => Theme(
        data: datePickerTheme(ctx),
        child: child!,
      ),
    );
    if (picked == null) return;
    setState(() {
      if (isFrom) {
        _from = picked;
        if (_to.isBefore(_from)) _to = _from;
      } else {
        _to = picked;
        if (_from.isAfter(_to)) _from = _to;
      }
    });
  }

  Future<void> _export() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final dio = createDioClient(ref.read(authProvider).token);
      // Span the full "to" day — server uses paidAt <= to.
      final toEnd = DateTime(_to.year, _to.month, _to.day, 23, 59, 59, 999);
      final fromStart = DateTime(_from.year, _from.month, _from.day);
      final resp = await dio.get<List<int>>(
        '/billing/reports/gst',
        queryParameters: {
          'from': fromStart.toIso8601String(),
          'to': toEnd.toIso8601String(),
        },
        options: Options(
          responseType: ResponseType.bytes,
          headers: {'Accept': 'text/csv'},
        ),
      );
      final bytes = Uint8List.fromList(resp.data ?? const []);
      final fmt = DateFormat('yyyyMMdd');
      final filename = 'gst-report-${fmt.format(_from)}-to-${fmt.format(_to)}.csv';
      await downloadBytes(
        bytes: bytes,
        filename: filename,
        mimeType: 'text/csv',
      );
      if (!mounted) return;
      // On web the file is already in the downloads folder; on mobile
      // share_plus has handed control to the OS share sheet, which often
      // includes "Save to Downloads" as an option.
      _showSuccess(
        context,
        kIsWeb ? 'CSV downloaded' : 'CSV saved to downloads',
      );
    } catch (e) {
      if (mounted) _showError(context, describeApiError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('dd MMM yyyy');
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: slateCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: copperAccent.withValues(alpha: 0.25)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: const [
          Icon(Icons.receipt_long_outlined, color: copperAccent, size: 16),
          SizedBox(width: 6),
          Text('Tax Reports',
              style: TextStyle(color: textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: 4),
        const Text(
          'Export a GST-ready CSV of paid bills for accounting.',
          style: TextStyle(color: textSecondary, fontSize: 11),
        ),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(
            child: _DateField(
              label: 'From',
              value: df.format(_from),
              onTap: () => _pickDate(isFrom: true),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _DateField(
              label: 'To',
              value: df.format(_to),
              onTap: () => _pickDate(isFrom: false),
            ),
          ),
        ]),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _busy ? null : _export,
            icon: _busy
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                  )
                : const Icon(Icons.download_outlined, size: 16),
            label: Text(_busy ? 'Exporting…' : 'Export CSV'),
            style: ElevatedButton.styleFrom(
              backgroundColor: copperAccent,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              textStyle: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ]),
    );
  }
}

class _DateField extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onTap;
  const _DateField({required this.label, required this.value, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: dividerColor),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(color: textSecondary, fontSize: 10)),
          const SizedBox(height: 2),
          Row(children: [
            const Icon(Icons.calendar_today_outlined, size: 12, color: textSecondary),
            const SizedBox(width: 6),
            Expanded(
              child: Text(value,
                  style: const TextStyle(color: textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
            ),
          ]),
        ]),
      ),
    );
  }
}

// Card for a PENDING refund. Two actions: approve fires the existing
// /billing/:id/approve-refund (manager+admin) which calls the PSP, and
// deny posts to /billing/:id/deny-refund which just closes the request.
class _PendingRefundCard extends ConsumerWidget {
  final Map<String, dynamic> tx;
  const _PendingRefundCard({required this.tx});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = tx['_id'] as String? ?? '';
    final tableLabel = tx['tableLabel'] as String? ?? '';
    final total = (tx['total'] as num?)?.toDouble() ?? 0;
    final reason = tx['refundReason'] as String? ?? '';
    final reference = tx['refundReference'] as String?;
    final requestedAt = tx['refundRequestedAt'] != null
        ? DateTime.tryParse(tx['refundRequestedAt'])
        : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: slateCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: amber.withValues(alpha: 0.45)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('Table $tableLabel',
              style: const TextStyle(
                  color: textPrimary, fontSize: 13, fontWeight: FontWeight.w700)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: amber.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text('PENDING',
                style: TextStyle(
                    color: amber, fontSize: 9, fontWeight: FontWeight.w700)),
          ),
        ]),
        const SizedBox(height: 6),
        Row(children: [
          Text('₹${total.toStringAsFixed(2)}',
              style: const TextStyle(
                  color: copperAccent,
                  fontSize: 14,
                  fontWeight: FontWeight.w800)),
          const Spacer(),
          if (requestedAt != null)
            Text(DateFormat('dd MMM, HH:mm').format(requestedAt),
                style: const TextStyle(color: textSecondary, fontSize: 11)),
        ]),
        const SizedBox(height: 8),
        Text('Reason: $reason',
            style: const TextStyle(color: textSecondary, fontSize: 12)),
        if (reference != null && reference.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text('Ref: $reference',
              style: const TextStyle(color: textSecondary, fontSize: 11)),
        ],
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              icon: const Icon(Icons.close, size: 14),
              label: const Text('Deny'),
              style: OutlinedButton.styleFrom(
                foregroundColor: textSecondary,
                side: BorderSide(color: textSecondary.withValues(alpha: 0.5)),
                padding: const EdgeInsets.symmetric(vertical: 9),
                textStyle:
                    const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
              ),
              onPressed: () => _act(context, ref, id, approve: false),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ElevatedButton.icon(
              icon: const Icon(Icons.check, size: 14),
              label: const Text('Approve'),
              style: ElevatedButton.styleFrom(
                backgroundColor: emerald,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 9),
                textStyle:
                    const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
              ),
              onPressed: () => _act(context, ref, id, approve: true),
            ),
          ),
        ]),
      ]),
    );
  }

  Future<void> _act(BuildContext context, WidgetRef ref, String id,
      {required bool approve}) async {
    try {
      final dio = createDioClient(ref.read(authProvider).token);
      final path = approve
          ? '/billing/$id/approve-refund'
          : '/billing/$id/deny-refund';
      final prefix = approve ? 'refund-approve' : 'refund-deny';
      await dio.post(
        path,
        options: Options(
            headers: {'Idempotency-Key': newIdempotencyKey('$prefix-$id')}),
      );
      ref.invalidate(_transactionsProvider);
      ref.invalidate(_financialSummaryProvider);
      if (context.mounted) {
        _showSuccess(context, approve ? 'Refund approved' : 'Refund denied');
      }
    } catch (e) {
      if (context.mounted) _showError(context, describeApiError(e));
    }
  }
}

class _EodSummaryCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _EodSummaryCard({required this.data});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: slateCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: emerald.withValues(alpha: 0.25)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.summarize_outlined, color: emerald, size: 16),
            const SizedBox(width: 6),
            Text('EOD Summary — ${data['date'] ?? ''}',
                style: const TextStyle(color: textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(height: 14),
          _BillingRow('Gross Revenue', '₹${((data['grossRevenue'] ?? 0) as num).toStringAsFixed(2)}', emerald),
          _BillingRow('Refunded', '-₹${((data['refundedAmount'] ?? 0) as num).toStringAsFixed(2)}', crimson),
          _BillingRow('GST Collected', '₹${((data['gstCollected'] ?? 0) as num).toStringAsFixed(2)}', amber),
          _BillingRow('Discounts', '-₹${((data['totalDiscounts'] ?? 0) as num).toStringAsFixed(2)}', roseGold),
          const Divider(color: dividerColor, height: 16),
          _BillingRow('Net Revenue', '₹${((data['netRevenue'] ?? 0) as num).toStringAsFixed(2)}', copperAccent, bold: true),
          const SizedBox(height: 8),
          Row(children: [
            _SmallStat('Paid Orders', '${data['paidOrders'] ?? 0}', emerald),
            _SmallStat('Refunded', '${data['refundedOrders'] ?? 0}', crimson),
            _SmallStat('Pending Bills', '${data['pendingBills'] ?? 0}', amber),
          ]),
        ]),
      );
}

class _BillingRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool bold;
  const _BillingRow(this.label, this.value, this.color, {this.bold = false});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          Text(label, style: TextStyle(color: textSecondary, fontSize: 12, fontWeight: bold ? FontWeight.w700 : FontWeight.normal)),
          const Spacer(),
          Text(value, style: TextStyle(color: color, fontSize: 12, fontWeight: bold ? FontWeight.w800 : FontWeight.w600)),
        ]),
      );
}

class _TransactionCard extends ConsumerWidget {
  final Map<String, dynamic> tx;
  const _TransactionCard({required this.tx});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPaid = tx['isPaid'] as bool? ?? false;
    final isRefunded = tx['isRefunded'] as bool? ?? false;
    final total = (tx['total'] as num?)?.toDouble() ?? 0;
    final id = tx['_id'] as String? ?? '';
    final paidAt = tx['paidAt'] != null ? DateTime.tryParse(tx['paidAt']) : null;

    Color statusColor = isPaid ? (isRefunded ? crimson : emerald) : amber;
    String statusLabel = isRefunded ? 'REFUNDED' : (isPaid ? 'PAID' : 'PENDING');

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: slateCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: dividerColor),
      ),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Table ${tx['tableLabel'] ?? ''}',
              style: const TextStyle(color: textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
          if (paidAt != null)
            Text(DateFormat('dd MMM, HH:mm').format(paidAt),
                style: const TextStyle(color: textSecondary, fontSize: 11)),
        ])),
        Text('₹${total.toStringAsFixed(2)}',
            style: const TextStyle(color: copperAccent, fontSize: 14, fontWeight: FontWeight.w800)),
        const SizedBox(width: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(statusLabel, style: TextStyle(color: statusColor, fontSize: 9, fontWeight: FontWeight.w700)),
        ),
        if (isPaid && !isRefunded) ...[
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => _confirmRefund(context, ref, id),
            child: const Tooltip(
              message: 'Refund bill',
              child: Icon(Icons.undo_outlined, color: crimson, size: 18),
            ),
          ),
        ],
      ]),
    );
  }

  void _confirmRefund(BuildContext context, WidgetRef ref, String id) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: slateCard,
        title: const Text('Process Refund?', style: TextStyle(color: textPrimary)),
        content: const Text('This will mark the bill as refunded. This action cannot be undone.',
            style: TextStyle(color: textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: textSecondary))),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                final dio = createDioClient(ref.read(authProvider).token);
                await dio.patch(
                  '/admin/billing/$id/refund',
                  options: Options(headers: {'Idempotency-Key': newIdempotencyKey('refund-$id')}),
                );
                ref.invalidate(_transactionsProvider);
                ref.invalidate(_financialSummaryProvider);
                if (context.mounted) _showSuccess(context, 'Refund processed');
              } catch (e) {
                if (context.mounted) _showError(context, describeApiError(e));
              }
            },
            child: const Text('Refund', style: TextStyle(color: crimson, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TAB 6 — INVENTORY OVERSIGHT
// ═══════════════════════════════════════════════════════════════════════════════

class AdminInventoryTab extends ConsumerWidget {
  const AdminInventoryTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invAsync = ref.watch(_inventoryAdminProvider);

    // Real-time sync: when a chef adjusts stock or the manager
    // approves a chef-added ingredient, the backend emits
    // `inventory:updated` to role:admin (added in orders.gateway after
    // we noticed admin lagged). Invalidate the provider so the tab
    // re-fetches without a manual pull.
    ref.listen(wsEventsProvider, (_, next) {
      next.whenData((evt) {
        if (evt.event == 'inventory:updated') {
          ref.invalidate(_inventoryAdminProvider);
        }
      });
    });

    // Admin sees every branch's inventory (scopeFilter returns {} for
    // admin), so we fetch the branches list once and build a lookup
    // map for the per-card label. Mistakes here would render the
    // wrong branch — that's why the lookup happens once at this level
    // instead of inside each card.
    final branchesAsync = ref.watch(_branchesProvider);
    final branchNameById = <String, String>{};
    branchesAsync.whenData((branches) {
      for (final b in branches) {
        final id = (b['_id'] ?? b['id'])?.toString() ?? '';
        if (id.isNotEmpty) branchNameById[id] = (b['name'] as String?) ?? id;
      }
    });

    return Stack(
      children: [
        invAsync.when(
          loading: () => const Center(child: CircularProgressIndicator(color: copperAccent)),
          error: (e, _) => Center(child: _ErrorText(describeApiError(e))),
          data: (items) {
            final lowItems = items.where((i) {
              final cur = (i['currentStock'] as num?)?.toDouble() ?? 0;
              final thresh = (i['lowStockThreshold'] as num?)?.toDouble() ?? 0;
              return cur <= thresh;
            }).toList();
            // Branch count from the fetched inventory itself — covers
            // edge case where the items reference a branch the
            // branchesProvider hasn't yet loaded.
            final branchIdsInUse = items
                .map((i) => (i['branchId'] ?? '').toString())
                .where((s) => s.isNotEmpty)
                .toSet();

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              children: [
                if (lowItems.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: crimson.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: crimson.withValues(alpha: 0.3)),
                    ),
                    child: Row(children: [
                      const Icon(Icons.warning_amber_outlined, color: crimson, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text('${lowItems.length} items low on stock',
                            style: const TextStyle(color: crimson, fontWeight: FontWeight.w600, fontSize: 13)),
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.notifications_active_outlined, size: 14, color: crimson),
                        label: const Text('Notify', style: TextStyle(color: crimson, fontSize: 12, fontWeight: FontWeight.w700)),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed: () => _runLowStockScan(context, ref),
                      ),
                    ]),
                  ),
                Row(children: [
                  _SmallStat('Total Items', '${items.length}', copperAccent),
                  _SmallStat('Low Stock', '${lowItems.length}', crimson),
                  _SmallStat('OK', '${items.length - lowItems.length}', emerald),
                ]),
                const SizedBox(height: 8),
                Text(
                  'Across ${branchIdsInUse.length} branch${branchIdsInUse.length == 1 ? '' : 'es'}',
                  style: const TextStyle(color: textSecondary, fontSize: 11),
                ),
                // Orphan-items hint: legacy seed inserted ingredients
                // without a branchId and they would otherwise live in
                // limbo (never on any per-branch dashboard, never
                // broadcast over WS, never counted toward COGS). When
                // we detect orphans AND know at least one branch,
                // surface a one-tap fix.
                if (items.any((i) => (i['branchId'] ?? '').toString().isEmpty))
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: _OrphanItemsFix(
                      orphanCount: items
                          .where((i) => (i['branchId'] ?? '').toString().isEmpty)
                          .length,
                    ),
                  ),
                const SizedBox(height: 16),
                ...items.map((item) => _AdminInventoryCard(
                      item: item,
                      branchLabel: branchNameById[
                              (item['branchId'] ?? '').toString()] ??
                          (item['branchId']?.toString().isEmpty ?? true
                              ? null
                              : 'Branch'),
                    )),
              ],
            );
          },
        ),
        Positioned(
          bottom: 16, right: 16,
          child: FloatingActionButton.extended(
            heroTag: 'admin_inventory_fab',
            backgroundColor: copperAccent,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.add_box_outlined),
            label: const Text('Add Item', style: TextStyle(fontWeight: FontWeight.w700)),
            onPressed: () => _showAddItemSheet(context, ref),
          ),
        ),
      ],
    );
  }

  Future<void> _runLowStockScan(BuildContext context, WidgetRef ref) async {
    try {
      final dio = createDioClient(ref.read(authProvider).token);
      final res = await dio.post(
        '/inventory/low-stock/scan',
        options: Options(headers: {
          'Idempotency-Key': newIdempotencyKey('low-stock-scan'),
        }),
      );
      final fired = res.data['fired'] ?? 0;
      final scanned = res.data['scanned'] ?? 0;
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: emerald,
          content: Text('Re-fired $fired low-stock alerts across $scanned items.'),
        ));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: crimson,
          content: Text(describeApiError(e)),
        ));
      }
    }
  }

  void _showAddItemSheet(BuildContext context, WidgetRef ref) {
    final nameCtrl = TextEditingController();
    final unitCtrl = TextEditingController();
    final stockCtrl = TextEditingController();
    final threshCtrl = TextEditingController();
    final costCtrl = TextEditingController();
    // Admin must pick which branch the ingredient belongs to. We don't
    // default to the first one — silent defaults are how you end up
    // with stock "appearing" at the wrong branch and screwing up
    // per-branch COGS days later. Surface the choice explicitly.
    String? selectedBranchId;

    showModalBottomSheet(
      context: context,
      backgroundColor: slateCard,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Consumer(builder: (ctx, ref, _) {
        final branchesAsync = ref.watch(_branchesProvider);
        return Padding(
          padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: StatefulBuilder(builder: (ctx, setSheetState) {
            return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Add Inventory Item', style: TextStyle(color: textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              branchesAsync.when(
                loading: () => const _BranchPickerSkeleton(),
                error: (e, _) => Text('Branches: ${describeApiError(e)}',
                    style: const TextStyle(color: crimson, fontSize: 12)),
                data: (branches) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: slateSurface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: dividerColor),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: selectedBranchId,
                      isExpanded: true,
                      hint: const Text('Branch (required)',
                          style: TextStyle(color: textSecondary, fontSize: 13)),
                      dropdownColor: slateCard,
                      iconEnabledColor: copperAccent,
                      style: const TextStyle(color: textPrimary, fontSize: 13),
                      items: branches.map((b) {
                        final id = (b['_id'] ?? b['id']).toString();
                        final name = (b['name'] as String?) ?? id;
                        return DropdownMenuItem<String>(value: id, child: Text(name));
                      }).toList(),
                      onChanged: (v) => setSheetState(() => selectedBranchId = v),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              _InputField(ctrl: nameCtrl, label: 'Name (e.g. Tomatoes)'),
              const SizedBox(height: 10),
              _InputField(ctrl: unitCtrl, label: 'Unit (e.g. kg, litre, piece)'),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: _InputField(ctrl: stockCtrl, label: 'Current Stock', keyboardType: const TextInputType.numberWithOptions(decimal: true))),
                const SizedBox(width: 10),
                Expanded(child: _InputField(ctrl: threshCtrl, label: 'Low Threshold', keyboardType: const TextInputType.numberWithOptions(decimal: true))),
              ]),
              const SizedBox(height: 10),
              _InputField(ctrl: costCtrl, label: 'Cost per Unit (₹)', keyboardType: const TextInputType.numberWithOptions(decimal: true)),
              const SizedBox(height: 16),
              _PrimaryButton(
                label: 'Create Item',
                onTap: () async {
                  final name = nameCtrl.text.trim();
                  final unit = unitCtrl.text.trim();
                  final stock = double.tryParse(stockCtrl.text);
                  final thresh = double.tryParse(threshCtrl.text);
                  if (selectedBranchId == null) {
                    _showError(context, 'Pick a branch first.');
                    return;
                  }
                  if (name.isEmpty || unit.isEmpty || stock == null || thresh == null) {
                    _showError(context, 'Fill name, unit, current stock, and low threshold.');
                    return;
                  }
                  Navigator.pop(ctx);
                  try {
                    final dio = createDioClient(ref.read(authProvider).token);
                    await dio.post('/inventory', data: {
                      'name': name,
                      'unit': unit,
                      'currentStock': stock,
                      'lowStockThreshold': thresh,
                      'costPerUnit': double.tryParse(costCtrl.text) ?? 0,
                      'branchId': selectedBranchId,
                    }, options: Options(headers: {'Idempotency-Key': newIdempotencyKey('inv-create')}));
                    ref.invalidate(_inventoryAdminProvider);
                    if (context.mounted) _showSuccess(context, 'Item added');
                  } catch (e) {
                    if (context.mounted) _showError(context, describeApiError(e));
                  }
                },
              ),
            ]);
          }),
        );
      }),
    );
  }
}

class _OrphanItemsFix extends ConsumerStatefulWidget {
  final int orphanCount;
  const _OrphanItemsFix({required this.orphanCount});
  @override
  ConsumerState<_OrphanItemsFix> createState() => _OrphanItemsFixState();
}

class _OrphanItemsFixState extends ConsumerState<_OrphanItemsFix> {
  bool _busy = false;

  Future<void> _run() async {
    final branches = ref.read(_branchesProvider).asData?.value ?? const [];
    if (branches.isEmpty) {
      _showError(context, 'Create a branch before fixing orphan items.');
      return;
    }
    // Pick which branch to home the orphans to. Show a sheet rather
    // than silently defaulting — wrong choice ruins per-branch COGS.
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: slateCard,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text('Assign orphan ingredients to…',
                  style: TextStyle(
                      color: textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700)),
            ),
            for (final b in branches)
              ListTile(
                leading: const Icon(Icons.store_outlined, color: copperAccent),
                title: Text((b['name'] as String?) ?? '',
                    style: const TextStyle(color: textPrimary, fontSize: 13)),
                onTap: () => Navigator.pop(ctx,
                    ((b['_id'] ?? b['id'])?.toString()) ?? ''),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (picked == null || picked.isEmpty) return;

    setState(() => _busy = true);
    try {
      final dio = createDioClient(ref.read(authProvider).token);
      final res = await dio.post('/inventory/assign-orphans', data: {
        'branchId': picked,
      }, options: Options(headers: {
        'Idempotency-Key': newIdempotencyKey('inv-orphan-fix'),
      }));
      final assigned = res.data['assigned'] ?? 0;
      ref.invalidate(_inventoryAdminProvider);
      if (mounted) _showSuccess(context, 'Re-homed $assigned orphan ingredient(s).');
    } catch (e) {
      if (mounted) _showError(context, describeApiError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: amber.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: amber.withValues(alpha: 0.3)),
      ),
      child: Row(children: [
        const Icon(Icons.warning_amber_outlined, color: amber, size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            '${widget.orphanCount} ingredient(s) have no branch assigned. They won\'t appear on per-branch dashboards or fire live updates.',
            style: const TextStyle(color: amber, fontSize: 11, height: 1.3),
          ),
        ),
        TextButton(
          onPressed: _busy ? null : _run,
          style: TextButton.styleFrom(
            foregroundColor: amber,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Text(_busy ? 'Fixing…' : 'Fix',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
        ),
      ]),
    );
  }
}

// Spawned by the Add Branch flow's success snackbar — lets the admin
// seed the new branch with its head manager immediately rather than
// having to navigate to the Staff tab and re-find the branch in a
// dropdown. Manager only (role-locked); admin can add other roles
// from the Staff tab.
class _InviteManagerSheet extends ConsumerStatefulWidget {
  final String branchId;
  final String branchName;
  const _InviteManagerSheet({required this.branchId, required this.branchName});
  @override
  ConsumerState<_InviteManagerSheet> createState() => _InviteManagerSheetState();
}

class _InviteManagerSheetState extends ConsumerState<_InviteManagerSheet> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _pwdCtrl = TextEditingController();
  late final String _idempotencyKey = newIdempotencyKey(
      'invite-mgr-${widget.branchId}');
  bool _busy = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _pwdCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final pwd = _pwdCtrl.text;
    if (name.isEmpty || email.isEmpty || pwd.length < 6) {
      _showError(context, 'Name, email, and a 6+ char password are required.');
      return;
    }
    setState(() => _busy = true);
    try {
      final dio = createDioClient(ref.read(authProvider).token);
      await dio.post('/users', data: {
        'name': name,
        'email': email,
        'password': pwd,
        'role': 'manager',
        'branchId': widget.branchId,
      }, options: Options(headers: {'Idempotency-Key': _idempotencyKey}));
      ref.invalidate(adminStaffProvider);
      if (mounted) {
        Navigator.pop(context);
        _showSuccess(context,
            'Manager "$name" invited to ${widget.branchName}.');
      }
    } catch (e) {
      if (mounted) _showError(context, describeApiError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(
            24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
        child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Invite manager to ${widget.branchName}',
                  style: const TextStyle(
                      color: textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              _InputField(ctrl: _nameCtrl, label: 'Full Name'),
              const SizedBox(height: 10),
              _InputField(
                  ctrl: _emailCtrl,
                  label: 'Email',
                  keyboardType: TextInputType.emailAddress),
              const SizedBox(height: 10),
              _InputField(ctrl: _pwdCtrl, label: 'Initial Password', obscure: true),
              const SizedBox(height: 16),
              _PrimaryButton(
                label: _busy ? 'Inviting…' : 'Send invite',
                onTap: _busy ? () {} : _submit,
              ),
            ]),
      );
}

class _BranchPickerSkeleton extends StatelessWidget {
  const _BranchPickerSkeleton();
  @override
  Widget build(BuildContext context) => Container(
        height: 48,
        decoration: BoxDecoration(
          color: slateSurface,
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Center(
          child: SizedBox(width: 14, height: 14,
              child: CircularProgressIndicator(strokeWidth: 2, color: copperAccent)),
        ),
      );
}

class _AdminInventoryCard extends ConsumerWidget {
  final Map<String, dynamic> item;
  // Resolved branch name for this item, or null when the item's branchId
  // doesn't match a known branch (shouldn't happen in practice; we
  // collapse to nothing rather than show a raw ObjectId).
  final String? branchLabel;
  const _AdminInventoryCard({required this.item, this.branchLabel});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cur = (item['currentStock'] as num?)?.toDouble() ?? 0;
    final thresh = (item['lowStockThreshold'] as num?)?.toDouble() ?? 0;
    final isLow = cur <= thresh;
    final progress = thresh > 0 ? (cur / (thresh * 3)).clamp(0.0, 1.0) : 1.0;
    final id = item['_id'] as String? ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: slateCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isLow ? crimson.withValues(alpha: 0.4) : dividerColor),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(item['name'] ?? '',
                  style: const TextStyle(color: textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
              if (branchLabel != null) ...[
                const SizedBox(height: 2),
                Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.store_mall_directory_outlined, size: 10, color: textSecondary),
                  const SizedBox(width: 3),
                  Text(branchLabel!,
                      style: const TextStyle(color: textSecondary, fontSize: 10, fontWeight: FontWeight.w500)),
                ]),
              ],
            ]),
          ),
          if (isLow)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: crimson.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
              child: const Text('LOW', style: TextStyle(color: crimson, fontSize: 10, fontWeight: FontWeight.w700)),
            ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => _showAdjustSheet(context, ref, id, item['name'] ?? ''),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: slateSurface, borderRadius: BorderRadius.circular(8)),
              child: const Tooltip(
                message: 'Edit',
                child: Icon(Icons.edit_outlined, color: textSecondary, size: 16),
              ),
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: () => showDialog(
              context: context,
              builder: (_) => AlertDialog(
                backgroundColor: slateCard,
                title: const Text('Delete Item?', style: TextStyle(color: textPrimary)),
                content: Text('Permanently delete "${item['name'] ?? ''}". This cannot be undone.',
                    style: const TextStyle(color: textSecondary)),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: textSecondary))),
                  TextButton(
                    onPressed: () async {
                      Navigator.pop(context);
                      try {
                        final dio = createDioClient(ref.read(authProvider).token);
                        await dio.delete(
                          '/inventory/$id',
                          options: Options(headers: {'Idempotency-Key': newIdempotencyKey('del-inv-$id')}),
                        );
                        ref.invalidate(_inventoryAdminProvider);
                        if (context.mounted) _showSuccess(context, 'Item deleted');
                      } catch (e) {
                        if (context.mounted) _showError(context, describeApiError(e));
                      }
                    },
                    child: const Text('Delete', style: TextStyle(color: crimson, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: crimson.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
              child: const Tooltip(
                message: 'Delete',
                child: Icon(Icons.delete_outline, color: crimson, size: 16),
              ),
            ),
          ),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: Text('$cur ${item['unit'] ?? ''}',
              style: TextStyle(color: isLow ? crimson : copperAccent, fontSize: 15, fontWeight: FontWeight.w800))),
          Text('Min: $thresh ${item['unit'] ?? ''}',
              style: const TextStyle(color: textSecondary, fontSize: 11)),
        ]),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: slateSurface,
            valueColor: AlwaysStoppedAnimation<Color>(isLow ? crimson : emerald),
            minHeight: 4,
          ),
        ),
      ]),
    );
  }

  void _showAdjustSheet(BuildContext context, WidgetRef ref, String id, String name) {
    final ctrl = TextEditingController();
    final reasonCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      backgroundColor: slateCard,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Adjust Stock — $name', style: const TextStyle(color: textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          _InputField(ctrl: ctrl, label: 'Delta (e.g. +10 or -5)', keyboardType: const TextInputType.numberWithOptions(signed: true)),
          const SizedBox(height: 10),
          _InputField(ctrl: reasonCtrl, label: 'Reason'),
          const SizedBox(height: 16),
          _PrimaryButton(
            label: 'Apply',
            onTap: () async {
              final delta = double.tryParse(ctrl.text);
              if (delta == null) {
                _showError(context, 'Enter a number (e.g. +10 or -5).');
                return;
              }
              Navigator.pop(ctx);
              try {
                final dio = createDioClient(ref.read(authProvider).token);
                await dio.patch('/inventory/$id/adjust', data: {
                  'delta': delta,
                  'reason': reasonCtrl.text.isEmpty ? 'Admin adjustment' : reasonCtrl.text,
                }, options: Options(headers: {'Idempotency-Key': newIdempotencyKey('inv-adj-$id')}));
                ref.invalidate(_inventoryAdminProvider);
                // Success confirmation — without it, the sheet closed
                // and the user saw no change (the WS broadcast also
                // silently skips when branchId is null on legacy seed
                // items), making it look broken.
                if (context.mounted) {
                  _showSuccess(context,
                      '$name stock ${delta >= 0 ? '+' : ''}$delta applied.');
                }
              } catch (e) {
                if (context.mounted) _showError(context, describeApiError(e));
              }
            },
          ),
        ]),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TAB 7 — BRANCHES & FEATURE TOGGLES
// ═══════════════════════════════════════════════════════════════════════════════

class AdminBranchesTab extends ConsumerWidget {
  const AdminBranchesTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final branchesAsync = ref.watch(_branchesProvider);

    return Stack(
      children: [
        RefreshIndicator(
          color: copperAccent,
          backgroundColor: slateCard,
          onRefresh: () async => ref.invalidate(_branchesProvider),
          child: branchesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator(color: copperAccent)),
            error: (e, _) => Center(child: _ErrorText(describeApiError(e))),
            data: (branches) {
              if (branches.isEmpty) {
                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: const [
                    SizedBox(height: 80),
                    _EmptyView(
                      icon: Icons.store_outlined,
                      title: 'No branches yet',
                      subtitle:
                          'Add your first branch to start onboarding managers, staff, and menus. Each branch is fully isolated — its own staff, inventory, orders, and reports.',
                    ),
                  ],
                );
              }
              return ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                itemCount: branches.length,
                itemBuilder: (_, i) => _BranchCard(branch: branches[i]),
              );
            },
          ),
        ),
        Positioned(
          bottom: 16,
          right: 16,
          child: FloatingActionButton.extended(
            heroTag: 'admin_branches_fab',
            backgroundColor: copperAccent,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.add_business_outlined),
            label: const Text('Add Branch', style: TextStyle(fontWeight: FontWeight.w700)),
            onPressed: () => _showAddBranchSheet(context, ref),
          ),
        ),
      ],
    );
  }

  void _showAddBranchSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: slateCard,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => const _AddBranchSheet(),
    );
  }
}

class _AddBranchSheet extends ConsumerStatefulWidget {
  const _AddBranchSheet();
  @override
  ConsumerState<_AddBranchSheet> createState() => _AddBranchSheetState();
}

class _AddBranchSheetState extends ConsumerState<_AddBranchSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _slugCtrl;
  late final TextEditingController _addrCtrl;
  late final TextEditingController _gstCtrl;
  late final TextEditingController _overdueCtrl;
  late final String _idempotencyKey;
  bool _submitting = false;
  // Local validation errors per field so the user sees the issue inline
  // instead of a vague 400 / Server hiccup bubbling up from the API.
  String? _nameError;
  String? _slugError;
  String? _addrError;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
    _slugCtrl = TextEditingController();
    _addrCtrl = TextEditingController();
    _gstCtrl = TextEditingController(text: '18');
    _overdueCtrl = TextEditingController(text: '15');
    _idempotencyKey = newIdempotencyKey('create-branch');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _slugCtrl.dispose();
    _addrCtrl.dispose();
    _gstCtrl.dispose();
    _overdueCtrl.dispose();
    super.dispose();
  }

  // Slugs end up in QR URLs; we keep them URL-safe by rejecting any
  // character outside lowercase alphanumerics + dashes. Cheaper to fail
  // here than to ship a non-routable QR.
  static final _slugRe = RegExp(r'^[a-z0-9-]+$');

  bool _validate() {
    setState(() {
      _nameError = _nameCtrl.text.trim().isEmpty ? 'Name is required.' : null;
      _addrError = _addrCtrl.text.trim().isEmpty ? 'Address is required.' : null;
      final slug = _slugCtrl.text.trim();
      if (slug.isEmpty) {
        _slugError = 'Slug is required.';
      } else if (!_slugRe.hasMatch(slug)) {
        _slugError = 'Use lowercase letters, numbers, and dashes only.';
      } else {
        _slugError = null;
      }
    });
    return _nameError == null && _slugError == null && _addrError == null;
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (!_validate()) return;
    setState(() => _submitting = true);
    try {
      final dio = createDioClient(ref.read(authProvider).token);
      // Backend's create DTO accepts only name/address/slug today, so
      // we post those first and then PATCH the optional GST + overdue
      // values to avoid widening the DTO before the BE catches up.
      // Two-step is fine because both calls are idempotent.
      final res = await dio.post(
        '/branches',
        data: {
          'name': _nameCtrl.text.trim(),
          'slug': _slugCtrl.text.trim(),
          'address': _addrCtrl.text.trim(),
        },
        options: Options(headers: {'Idempotency-Key': _idempotencyKey}),
      );
      final newBranchId = (res.data['_id'] ?? res.data['id'])?.toString() ?? '';

      final gstPct = double.tryParse(_gstCtrl.text);
      final overdue = int.tryParse(_overdueCtrl.text);
      if (newBranchId.isNotEmpty && (gstPct != null || overdue != null)) {
        try {
          await dio.patch(
            '/branches/$newBranchId',
            data: {
              if (gstPct != null) 'gstRate': gstPct / 100,
              if (overdue != null) 'overdueAfterMinutes': overdue,
            },
            options: Options(headers: {
              'Idempotency-Key': '$_idempotencyKey-tune',
            }),
          );
        } catch (_) {
          // Tunables aren't critical — the branch exists; admin can
          // fix the rate via Edit if this second hop hit a glitch.
        }
      }

      ref.invalidate(_branchesProvider);
      if (mounted) {
        Navigator.pop(context);
        // Success confirmation + "Add manager?" action so the admin
        // can immediately seed the new branch with its head manager.
        final messenger = ScaffoldMessenger.of(context);
        messenger.showSnackBar(SnackBar(
          backgroundColor: emerald,
          duration: const Duration(seconds: 6),
          content: Text('Branch "${_nameCtrl.text.trim()}" created.'),
          action: SnackBarAction(
            label: 'Add manager',
            textColor: Colors.white,
            onPressed: () {
              messenger.hideCurrentSnackBar();
              _openInviteManagerSheet(newBranchId, _nameCtrl.text.trim());
            },
          ),
        ));
      }
    } catch (e) {
      if (mounted) _showError(context, describeApiError(e));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _openInviteManagerSheet(String branchId, String branchName) {
    showModalBottomSheet(
      context: context,
      backgroundColor: slateCard,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _InviteManagerSheet(
        branchId: branchId,
        branchName: branchName,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Add Branch', style: TextStyle(color: textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          _InputField(ctrl: _nameCtrl, label: 'Branch Name', errorText: _nameError),
          const SizedBox(height: 10),
          _InputField(ctrl: _slugCtrl, label: 'Slug (e.g. main-branch)', errorText: _slugError),
          const SizedBox(height: 10),
          _InputField(ctrl: _addrCtrl, label: 'Address', errorText: _addrError),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _InputField(ctrl: _gstCtrl, label: 'GST Rate (%)',
                keyboardType: const TextInputType.numberWithOptions(decimal: true))),
            const SizedBox(width: 10),
            Expanded(child: _InputField(ctrl: _overdueCtrl, label: 'Overdue after (min)',
                keyboardType: TextInputType.number)),
          ]),
          const SizedBox(height: 16),
          _PrimaryButton(
            label: _submitting ? 'Creating…' : 'Create Branch',
            onTap: _submitting ? () {} : _submit,
          ),
        ]),
      );
}

class _BranchCard extends ConsumerWidget {
  final Map<String, dynamic> branch;
  const _BranchCard({required this.branch});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final features = Map<String, dynamic>.from(branch['features'] ?? {});
    final id = branch['_id'] as String? ?? '';
    final isActive = branch['isActive'] as bool? ?? true;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: slateCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isActive ? dividerColor : crimson.withValues(alpha: 0.3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header row: name + slug + edit + delete
        Row(children: [
          Expanded(child: Text(branch['name'] ?? '',
              style: const TextStyle(color: textPrimary, fontSize: 14, fontWeight: FontWeight.w700))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: emerald.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
            child: Text(branch['slug'] ?? '',
                style: const TextStyle(color: emerald, fontSize: 10, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => _showEditSheet(context, ref, id),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: slateSurface, borderRadius: BorderRadius.circular(8)),
              child: const Tooltip(
                message: 'Edit',
                child: Icon(Icons.edit_outlined, color: textSecondary, size: 16),
              ),
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: () => _confirmAndDelete(context, ref, id, branch['name'] ?? ''),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: crimson.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
              child: const Tooltip(
                message: 'Delete',
                child: Icon(Icons.delete_outline, color: crimson, size: 16),
              ),
            ),
          ),
        ]),
        const SizedBox(height: 4),
        Text(branch['address'] ?? '', style: const TextStyle(color: textSecondary, fontSize: 12)),
        const SizedBox(height: 4),
        Row(children: [
          Text('GST: ${((branch['gstRate'] as num? ?? 0.18) * 100).toStringAsFixed(0)}%',
              style: const TextStyle(color: textSecondary, fontSize: 11)),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: (isActive ? emerald : crimson).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(isActive ? 'ACTIVE' : 'INACTIVE',
                style: TextStyle(color: isActive ? emerald : crimson, fontSize: 9, fontWeight: FontWeight.w700)),
          ),
        ]),
        const SizedBox(height: 14),
        const Text('Feature Toggles',
            style: TextStyle(color: textSecondary, fontSize: 11, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        _FeatureToggleRow(
          label: 'QR Ordering',
          value: features['qrOrdering'] as bool? ?? true,
          onChanged: (v) => _toggleFeature(context, ref, id, 'qrOrdering', v),
        ),
        _FeatureToggleRow(
          label: 'Online Payment',
          value: features['onlinePayment'] as bool? ?? true,
          onChanged: (v) => _toggleFeature(context, ref, id, 'onlinePayment', v),
        ),
        _FeatureToggleRow(
          label: 'Loyalty System',
          value: features['loyaltySystem'] as bool? ?? true,
          onChanged: (v) => _toggleFeature(context, ref, id, 'loyaltySystem', v),
        ),
        _FeatureToggleRow(
          label: 'Table Reservations',
          value: features['tableReservations'] as bool? ?? true,
          onChanged: (v) => _toggleFeature(context, ref, id, 'tableReservations', v),
        ),
      ]),
    );
  }

  void _showEditSheet(BuildContext context, WidgetRef ref, String id) {
    showModalBottomSheet(
      context: context,
      backgroundColor: slateCard,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _EditBranchSheet(branchId: id, branch: branch),
    );
  }

  Future<void> _toggleFeature(BuildContext context, WidgetRef ref, String branchId, String feature, bool value) async {
    try {
      final dio = createDioClient(ref.read(authProvider).token);
      await dio.patch('/branches/$branchId/features', data: {feature: value},
          options: Options(headers: {'Idempotency-Key': newIdempotencyKey('feat-$branchId-$feature-$value')}));
      ref.invalidate(_branchesProvider);
    } catch (e) {
      if (context.mounted) _showError(context, describeApiError(e));
    }
  }

  // Two-step delete: first hit GET /deletion-preview to count dependent
  // users/menu/tables/orders/bills/ingredients, show the admin what's
  // about to disappear, then either delete cleanly (no dependents) or
  // require explicit cascade confirmation. Without this, tapping the
  // trash icon used to silently orphan an entire branch's data.
  Future<void> _confirmAndDelete(
      BuildContext context, WidgetRef ref, String id, String name) async {
    Map<String, dynamic>? preview;
    try {
      final dio = createDioClient(ref.read(authProvider).token);
      final res = await dio.get('/branches/$id/deletion-preview');
      preview = Map<String, dynamic>.from(res.data);
    } catch (e) {
      if (context.mounted) _showError(context, describeApiError(e));
      return;
    }
    if (!context.mounted) return;

    final counts = Map<String, dynamic>.from(preview['counts'] ?? {});
    final total = (preview['total'] as num?)?.toInt() ?? 0;
    final hasDependents = preview['hasDependents'] as bool? ?? false;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: slateCard,
        title: Text(
          hasDependents ? 'Delete "$name" and all linked data?' : 'Delete "$name"?',
          style: const TextStyle(color: textPrimary, fontSize: 15),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (hasDependents)
              Text(
                'This branch has $total linked records that will be permanently deleted with it:',
                style: const TextStyle(color: crimson, fontSize: 12),
              )
            else
              const Text(
                'No linked records. The branch will be removed cleanly.',
                style: TextStyle(color: textSecondary, fontSize: 12),
              ),
            if (hasDependents) ...[
              const SizedBox(height: 8),
              _DepCountRow('Users', counts['users']),
              _DepCountRow('Menu items', counts['menus']),
              _DepCountRow('Tables', counts['tables']),
              _DepCountRow('Orders', counts['orders']),
              _DepCountRow('Bills', counts['bills']),
              _DepCountRow('Ingredients', counts['ingredients']),
              const SizedBox(height: 8),
              const Text(
                'This cannot be undone.',
                style: TextStyle(
                    color: crimson, fontSize: 11, fontWeight: FontWeight.w700),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel',
                  style: TextStyle(color: textSecondary))),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              hasDependents ? 'Delete all $total + branch' : 'Delete',
              style: const TextStyle(
                  color: crimson, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;

    try {
      final dio = createDioClient(ref.read(authProvider).token);
      await dio.delete(
        '/branches/$id',
        queryParameters: hasDependents ? {'cascade': 'true'} : null,
        options: Options(headers: {
          'Idempotency-Key': newIdempotencyKey('del-branch-$id'),
        }),
      );
      ref.invalidate(_branchesProvider);
      if (context.mounted) {
        _showSuccess(context,
            hasDependents
                ? 'Deleted branch + $total linked records.'
                : 'Branch deleted.');
      }
    } catch (e) {
      if (context.mounted) _showError(context, describeApiError(e));
    }
  }
}

class _DepCountRow extends StatelessWidget {
  final String label;
  final dynamic count;
  const _DepCountRow(this.label, this.count);
  @override
  Widget build(BuildContext context) {
    final n = (count as num?)?.toInt() ?? 0;
    final emphasised = n > 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(children: [
        Icon(
          emphasised ? Icons.warning_amber_outlined : Icons.check_circle_outline,
          size: 12,
          color: emphasised ? crimson : emerald,
        ),
        const SizedBox(width: 6),
        Text(label,
            style: const TextStyle(color: textSecondary, fontSize: 12)),
        const Spacer(),
        Text('$n',
            style: TextStyle(
                color: emphasised ? crimson : textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

// ── Edit branch sheet ────────────────────────────────────────────────────────
class _EditBranchSheet extends ConsumerStatefulWidget {
  final String branchId;
  final Map<String, dynamic> branch;
  const _EditBranchSheet({required this.branchId, required this.branch});
  @override
  ConsumerState<_EditBranchSheet> createState() => _EditBranchSheetState();
}

class _EditBranchSheetState extends ConsumerState<_EditBranchSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _addrCtrl;
  late final TextEditingController _slugCtrl;
  late final TextEditingController _gstCtrl;
  late final String _idempotencyKey;
  late bool _isActive;
  late bool _chefCanManageInventory;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.branch['name'] as String? ?? '');
    _addrCtrl = TextEditingController(text: widget.branch['address'] as String? ?? '');
    _slugCtrl = TextEditingController(text: widget.branch['slug'] as String? ?? '');
    _gstCtrl = TextEditingController(
        text: (((widget.branch['gstRate'] as num? ?? 0.18) * 100)).toStringAsFixed(0));
    _isActive = widget.branch['isActive'] as bool? ?? true;
    _chefCanManageInventory =
        widget.branch['chefCanManageInventory'] as bool? ?? false;
    _idempotencyKey = newIdempotencyKey('edit-branch-${widget.branchId}');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _addrCtrl.dispose();
    _slugCtrl.dispose();
    _gstCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_submitting) return;
    if (_nameCtrl.text.trim().isEmpty) return;
    setState(() => _submitting = true);
    try {
      final dio = createDioClient(ref.read(authProvider).token);
      final gstPct = double.tryParse(_gstCtrl.text);
      await dio.patch(
        '/branches/${widget.branchId}',
        data: {
          'name': _nameCtrl.text.trim(),
          'address': _addrCtrl.text.trim(),
          'slug': _slugCtrl.text.trim(),
          if (gstPct != null) 'gstRate': gstPct / 100,
          'isActive': _isActive,
          'chefCanManageInventory': _chefCanManageInventory,
        },
        options: Options(headers: {'Idempotency-Key': _idempotencyKey}),
      );
      ref.invalidate(_branchesProvider);
      if (mounted) {
        Navigator.pop(context);
        _showSuccess(context, 'Branch updated');
      }
    } catch (e) {
      if (mounted) _showError(context, describeApiError(e));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Edit — ${widget.branch['name'] ?? ''}',
              style: const TextStyle(color: textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          _InputField(ctrl: _nameCtrl, label: 'Branch Name'),
          const SizedBox(height: 10),
          _InputField(ctrl: _addrCtrl, label: 'Address'),
          const SizedBox(height: 10),
          _InputField(ctrl: _slugCtrl, label: 'Slug'),
          const SizedBox(height: 10),
          _InputField(ctrl: _gstCtrl, label: 'GST Rate (%)',
              keyboardType: const TextInputType.numberWithOptions(decimal: true)),
          const SizedBox(height: 10),
          Row(children: [
            const Text('Active', style: TextStyle(color: textPrimary, fontSize: 13)),
            const Spacer(),
            Switch(
              value: _isActive,
              onChanged: (v) => setState(() => _isActive = v),
              activeThumbColor: copperAccent,
              inactiveThumbColor: textSecondary,
              inactiveTrackColor: slateSurface,
            ),
          ]),
          const SizedBox(height: 4),
          // When on, head chefs on this branch can add ingredients and
          // set thresholds themselves. Chef-added items are flagged
          // pendingReview until a manager audits the values. Off by
          // default — keeps the cleaner separation of duties.
          Row(children: [
            const Expanded(
              child: Text('Chef manages inventory',
                  style: TextStyle(color: textPrimary, fontSize: 13)),
            ),
            Switch(
              value: _chefCanManageInventory,
              onChanged: (v) => setState(() => _chefCanManageInventory = v),
              activeThumbColor: copperAccent,
              inactiveThumbColor: textSecondary,
              inactiveTrackColor: slateSurface,
            ),
          ]),
          const Padding(
            padding: EdgeInsets.only(top: 2, bottom: 6),
            child: Text(
              'Chef can add ingredients + set thresholds. Items they add show a REVIEW badge until you approve.',
              style: TextStyle(color: textSecondary, fontSize: 10, height: 1.3),
            ),
          ),
          const SizedBox(height: 16),
          _PrimaryButton(
            label: _submitting ? 'Saving…' : 'Save Changes',
            onTap: _submitting ? () {} : _save,
          ),
        ]),
      );
}

class _FeatureToggleRow extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _FeatureToggleRow({required this.label, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(child: Text(label, style: const TextStyle(color: textPrimary, fontSize: 13))),
        Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: copperAccent,
          inactiveThumbColor: textSecondary,
          inactiveTrackColor: slateSurface,
        ),
      ]);
}

// ═══════════════════════════════════════════════════════════════════════════════
// TAB 8 — SYSTEM (Health · Audit Log · Menu Management)
// ═══════════════════════════════════════════════════════════════════════════════

class AdminSystemTab extends ConsumerStatefulWidget {
  const AdminSystemTab({super.key});

  @override
  ConsumerState<AdminSystemTab> createState() => _AdminSystemTabState();
}

class _AdminSystemTabState extends ConsumerState<AdminSystemTab>
    with SingleTickerProviderStateMixin {
  late TabController _tc;

  @override
  void initState() {
    super.initState();
    _tc = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(children: [
        Container(
          color: slateCard,
          child: TabBar(
            controller: _tc,
            indicatorColor: copperAccent,
            labelColor: copperAccent,
            unselectedLabelColor: textSecondary,
            labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            tabs: const [
              Tab(text: 'Health'),
              Tab(text: 'Audit Log'),
              Tab(text: 'Menu'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tc,
            children: [
              const _SystemHealthTab(),
              const _AuditLogTab(),
              _MenuManagementTab(),
            ],
          ),
        ),
      ]);
}

// ── System Health ─────────────────────────────────────────────────────────────

class _SystemHealthTab extends ConsumerWidget {
  const _SystemHealthTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final healthAsync = ref.watch(_systemHealthProvider);

    return healthAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: copperAccent)),
      error: (e, _) => Center(child: _ErrorText(describeApiError(e))),
      data: (h) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _HealthStatusCard(health: h),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.6,
            children: [
              _MetricCard('Active Orders', '${h['activeOrders'] ?? 0}', Icons.receipt_outlined, copperAccent),
              _MetricCard('Low Stock Alerts', '${h['lowStockAlerts'] ?? 0}', Icons.warning_amber_outlined,
                  (h['lowStockAlerts'] ?? 0) > 0 ? crimson : emerald),
              _MetricCard('Unpaid Bills', '${h['unpaidBills'] ?? 0}', Icons.pending_outlined, amber),
              _MetricCard('Active Users', '${h['activeUsers'] ?? 0}', Icons.people_outline, roseGold),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: slateCard, borderRadius: BorderRadius.circular(12)),
            child: Row(children: [
              const Icon(Icons.access_time_outlined, color: textSecondary, size: 14),
              const SizedBox(width: 6),
              Text('Last checked: ${h['timestamp'] ?? ''}',
                  style: const TextStyle(color: textSecondary, fontSize: 11)),
              const Spacer(),
              GestureDetector(
                onTap: () => ref.invalidate(_systemHealthProvider),
                child: const Icon(Icons.refresh, color: copperAccent, size: 18),
              ),
            ]),
          ),
          const SizedBox(height: 16),
          // Wipe demo data — one-shot cleanup for the orders + bills
          // pushed by seed.ts. Doesn't touch user accounts, the menu, or
          // tables (those are still useful even outside the demo).
          _WipeDemoCard(),
        ],
      ),
    );
  }
}

class _WipeDemoCard extends ConsumerStatefulWidget {
  @override
  ConsumerState<_WipeDemoCard> createState() => _WipeDemoCardState();
}

class _WipeDemoCardState extends ConsumerState<_WipeDemoCard> {
  bool _busy = false;

  Future<void> _wipe() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: slateCard,
        title: const Text('Clear demo orders + bills?',
            style: TextStyle(color: textPrimary, fontSize: 15)),
        content: const Text(
          'Removes the canned orders and bills the seed script pushed for first-launch demos. Your real transactions and the user accounts, menu, and tables stay.',
          style: TextStyle(color: textSecondary, fontSize: 12),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel',
                style: TextStyle(color: textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clear demo data',
                style: TextStyle(color: crimson)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      final dio = createDioClient(ref.read(authProvider).token);
      final res = await dio.post(
        '/admin/wipe-demo-data',
        options: Options(headers: {
          'Idempotency-Key': newIdempotencyKey('wipe-demo'),
        }),
      );
      final orders = res.data['deletedOrders'] ?? 0;
      final bills = res.data['deletedBills'] ?? 0;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: emerald,
          content: Text('Cleared $orders demo orders and $bills bills.'),
        ));
      }
      ref.invalidate(_systemHealthProvider);
      ref.invalidate(_allOrdersProvider);
      ref.invalidate(_transactionsProvider);
      ref.invalidate(_financialSummaryProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: crimson,
          content: Text(describeApiError(e)),
        ));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: slateCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: crimson.withValues(alpha: 0.3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: const [
          Icon(Icons.cleaning_services_outlined, color: crimson, size: 16),
          SizedBox(width: 8),
          Text('Clear demo seed data',
              style: TextStyle(
                  color: textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 4),
        const Text(
          'Remove the canned orders + bills the first-launch seed inserted. Keeps users, menu, and tables.',
          style: TextStyle(color: textSecondary, fontSize: 11, height: 1.4),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            icon: _busy
                ? const SizedBox(
                    width: 12, height: 12,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: crimson))
                : const Icon(Icons.delete_outline, size: 16),
            label: Text(_busy ? 'Clearing…' : 'Clear demo data'),
            style: OutlinedButton.styleFrom(
              foregroundColor: crimson,
              side: BorderSide(color: crimson.withValues(alpha: 0.5)),
              padding: const EdgeInsets.symmetric(vertical: 10),
            ),
            onPressed: _busy ? null : _wipe,
          ),
        ),
      ]),
    );
  }
}

class _HealthStatusCard extends StatelessWidget {
  final Map<String, dynamic> health;
  const _HealthStatusCard({required this.health});

  @override
  Widget build(BuildContext context) {
    final ok = health['status'] == 'ok';
    final color = ok ? emerald : crimson;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(children: [
        Icon(ok ? Icons.check_circle_outline : Icons.error_outline, color: color, size: 28),
        const SizedBox(width: 12),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(ok ? 'All Systems Operational' : 'System Degraded',
              style: TextStyle(color: color, fontSize: 15, fontWeight: FontWeight.w800)),
          Text(ok ? 'No issues detected' : 'Check logs for details',
              style: const TextStyle(color: textSecondary, fontSize: 12)),
        ]),
      ]),
    );
  }
}

// ── Audit Log ─────────────────────────────────────────────────────────────────

class _AuditLogTab extends ConsumerWidget {
  const _AuditLogTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auditAsync = ref.watch(auditEventsProvider);

    return Column(
      children: [
        const _AuditFilterBar(),
        Expanded(
          child: auditAsync.when(
            loading: () =>
                const Center(child: CircularProgressIndicator(color: copperAccent)),
            error: (e, _) => Center(child: _ErrorText(describeApiError(e))),
            data: (entries) => entries.isEmpty
                ? const Center(
                    child: Text('No audit entries',
                        style: TextStyle(color: textSecondary)))
                : RefreshIndicator(
                    color: copperAccent,
                    onRefresh: () async => ref.invalidate(auditEventsProvider),
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: entries.length,
                      itemBuilder: (_, i) => _AuditEntry(entry: entries[i]),
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}

// Filter row — type dropdown, actor search, date range pickers. Each
// control writes back to auditFilterProvider; the FutureProvider above
// re-runs whenever the filter object changes.
class _AuditFilterBar extends ConsumerStatefulWidget {
  const _AuditFilterBar();

  @override
  ConsumerState<_AuditFilterBar> createState() => _AuditFilterBarState();
}

class _AuditFilterBarState extends ConsumerState<_AuditFilterBar> {
  late final TextEditingController _actorCtrl;

  // Mirrors the backend AuditEventType enum. Keep the list here in sync
  // with backend/src/modules/audit/audit-log.schema.ts.
  static const _types = <String, String>{
    '': 'All types',
    'AUTH_LOGIN': 'Auth · login',
    'AUTH_LOGOUT': 'Auth · logout',
    'AUTH_FAILED': 'Auth · failed',
    'RBAC_ROLE_CHANGED': 'RBAC · role changed',
    'BILL_REFUNDED': 'Bill · refunded',
    'INVENTORY_APPROVED': 'Inventory · approved',
  };

  @override
  void initState() {
    super.initState();
    _actorCtrl =
        TextEditingController(text: ref.read(auditFilterProvider).actorId ?? '');
  }

  @override
  void dispose() {
    _actorCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final f = ref.read(auditFilterProvider);
    final initial = (isFrom ? f.from : f.to) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      builder: (ctx, child) => Theme(
        data: datePickerTheme(ctx),
        child: child!,
      ),
    );
    if (picked == null) return;
    ref.read(auditFilterProvider.notifier).update(
          (s) => isFrom
              ? s.copyWith(from: picked)
              : s.copyWith(to: picked),
        );
  }

  @override
  Widget build(BuildContext context) {
    final f = ref.watch(auditFilterProvider);
    final df = DateFormat('dd MMM');
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      decoration: const BoxDecoration(
        color: slateCard,
        border: Border(bottom: BorderSide(color: dividerColor)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: slateBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: dividerColor),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: f.type ?? '',
                    isExpanded: true,
                    dropdownColor: slateCard,
                    iconEnabledColor: copperAccent,
                    style: const TextStyle(color: textPrimary, fontSize: 12),
                    items: _types.entries
                        .map((e) => DropdownMenuItem(
                              value: e.key,
                              child: Text(e.value),
                            ))
                        .toList(),
                    onChanged: (v) {
                      ref
                          .read(auditFilterProvider.notifier)
                          .update((s) => s.copyWith(type: v == '' ? null : v));
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: SizedBox(
                height: 38,
                child: TextField(
                  controller: _actorCtrl,
                  style: const TextStyle(color: textPrimary, fontSize: 12),
                  decoration: InputDecoration(
                    hintText: 'Actor id',
                    hintStyle:
                        const TextStyle(color: textSecondary, fontSize: 12),
                    isDense: true,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    filled: true,
                    fillColor: slateBg,
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: dividerColor),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: copperAccent),
                    ),
                    suffixIcon: _actorCtrl.text.isEmpty
                        ? null
                        : IconButton(
                            iconSize: 16,
                            icon: const Icon(Icons.close,
                                color: textSecondary, size: 16),
                            onPressed: () {
                              _actorCtrl.clear();
                              ref
                                  .read(auditFilterProvider.notifier)
                                  .update((s) => s.copyWith(actorId: null));
                            },
                          ),
                  ),
                  onSubmitted: (v) {
                    final trimmed = v.trim();
                    ref.read(auditFilterProvider.notifier).update(
                          (s) => s.copyWith(
                              actorId: trimmed.isEmpty ? null : trimmed),
                        );
                  },
                ),
              ),
            ),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: dividerColor),
                  foregroundColor: textPrimary,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                ),
                onPressed: () => _pickDate(isFrom: true),
                icon: const Icon(Icons.calendar_today,
                    size: 14, color: copperAccent),
                label: Text(
                  f.from == null ? 'From' : df.format(f.from!),
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: dividerColor),
                  foregroundColor: textPrimary,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                ),
                onPressed: () => _pickDate(isFrom: false),
                icon: const Icon(Icons.calendar_today,
                    size: 14, color: copperAccent),
                label: Text(
                  f.to == null ? 'To' : df.format(f.to!),
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: () {
                _actorCtrl.clear();
                ref.read(auditFilterProvider.notifier).state =
                    const AuditFilter();
              },
              style: TextButton.styleFrom(
                foregroundColor: textSecondary,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              child: const Text('Clear', style: TextStyle(fontSize: 12)),
            ),
          ]),
        ],
      ),
    );
  }
}

class _AuditEntry extends StatelessWidget {
  final Map<String, dynamic> entry;
  const _AuditEntry({required this.entry});

  // Per-event-type accent colour. Anything unknown falls back to
  // textSecondary so future event types still render.
  static const _typeColors = {
    'AUTH_LOGIN': emerald,
    'AUTH_LOGOUT': textSecondary,
    'AUTH_FAILED': crimson,
    'RBAC_ROLE_CHANGED': amber,
    'BILL_REFUNDED': crimson,
    'INVENTORY_APPROVED': copperAccent,
    // Legacy /admin/audit-log shapes — kept for the old order trail when
    // the same widget is reused there.
    'FORCE_CLOSED': crimson,
    'DISCOUNT_APPLIED': amber,
    'REFUND': crimson,
    'BILL_EDITED': roseGold,
    'STATUS_UPDATED': copperAccent,
  };

  @override
  Widget build(BuildContext context) {
    // Tolerate both new (/audit) and legacy (/admin/audit-log) shapes —
    // the AdminSystemTab now uses the new feed but the same widget might
    // be reused elsewhere.
    final type = (entry['type'] ?? entry['action']) as String? ?? '';
    final color = _typeColors[type] ?? textSecondary;
    final atRaw = entry['createdAt'] ?? entry['at'];
    final at = atRaw is String ? DateTime.tryParse(atRaw) : null;

    final actorEmail = entry['actorEmail'] as String?;
    final actorRole = entry['actorRole'] as String?;
    final actorId = entry['actorId'] ?? entry['by'];
    final branchId = entry['branchId'] as String?;
    final meta = entry['meta'];

    final actorLine = actorEmail != null && actorEmail.isNotEmpty
        ? '$actorEmail${actorRole != null ? ' · $actorRole' : ''}'
        : 'by ${actorId ?? 'system'}';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: slateCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: dividerColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 4,
            height: 44,
            decoration: BoxDecoration(
                color: color, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(type,
                    style: TextStyle(
                        color: color,
                        fontSize: 12,
                        fontWeight: FontWeight.w700)),
                Text(actorLine,
                    style: const TextStyle(
                        color: textSecondary, fontSize: 11)),
                if (branchId != null && branchId.isNotEmpty)
                  Text('branch · $branchId',
                      style: const TextStyle(
                          color: textSecondary, fontSize: 10)),
                if (meta is Map && meta.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      meta.entries
                          .map((e) => '${e.key}: ${e.value}')
                          .join(' · '),
                      style: const TextStyle(
                          color: textSecondary, fontSize: 10),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          ),
          if (at != null)
            Text(DateFormat('dd MMM HH:mm').format(at),
                style: const TextStyle(color: textSecondary, fontSize: 10)),
        ],
      ),
    );
  }
}

// ── Menu Management ───────────────────────────────────────────────────────────

class _MenuManagementTab extends ConsumerStatefulWidget {
  const _MenuManagementTab();
  @override
  ConsumerState<_MenuManagementTab> createState() => _MenuManagementTabState();
}

class _MenuManagementTabState extends ConsumerState<_MenuManagementTab> {
  String? _selectedBranchId;
  String? _selectedBranchName;

  @override
  Widget build(BuildContext context) {
    final branchesAsync = ref.watch(_branchesProvider);

    return branchesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: copperAccent)),
      error: (e, _) => Center(child: _ErrorText(describeApiError(e))),
      data: (branches) {
        if (branches.isEmpty) {
          return const Center(child: Text('No branches found', style: TextStyle(color: textSecondary)));
        }
        // Auto-select first branch
        _selectedBranchId ??= branches.first['_id'] as String?;
        _selectedBranchName ??= branches.first['name'] as String?;

        return Stack(
          children: [
            Column(children: [
              // Branch selector
              Container(
                color: slateSurface,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: DropdownButtonFormField<String>(
                  value: _selectedBranchId,
                  dropdownColor: slateSurface,
                  style: const TextStyle(color: textPrimary, fontSize: 13),
                  decoration: InputDecoration(
                    labelText: 'Branch',
                    labelStyle: const TextStyle(color: textSecondary, fontSize: 12),
                    filled: true, fillColor: slateCard,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: dividerColor)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: dividerColor)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: copperAccent)),
                  ),
                  items: branches.map((b) => DropdownMenuItem<String>(
                    value: b['_id'] as String,
                    child: Text(b['name'] as String? ?? ''),
                  )).toList(),
                  onChanged: (v) => setState(() {
                    _selectedBranchId = v;
                    _selectedBranchName = branches.firstWhere((b) => b['_id'] == v)['name'] as String?;
                  }),
                ),
              ),
              // Menu list
              Expanded(
                child: _selectedBranchId == null
                    ? const SizedBox.shrink()
                    : Consumer(builder: (ctx, ref, _) {
                        final menuAsync = ref.watch(_menuProvider(_selectedBranchId!));
                        return menuAsync.when(
                          loading: () => const Center(child: CircularProgressIndicator(color: copperAccent)),
                          error: (e, _) => Center(child: _ErrorText(describeApiError(e))),
                          data: (items) => items.isEmpty
                              ? const Center(child: Text('No items yet. Add one!', style: TextStyle(color: textSecondary)))
                              : ListView.builder(
                                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                                  itemCount: items.length,
                                  itemBuilder: (_, i) => _MenuItemCard(
                                    item: items[i],
                                    branchId: _selectedBranchId!,
                                  ),
                                ),
                        );
                      }),
              ),
            ]),
            Positioned(
              bottom: 16, right: 16,
              child: FloatingActionButton.extended(
                heroTag: 'admin_menu_fab',
                backgroundColor: copperAccent,
                foregroundColor: Colors.white,
                icon: const Icon(Icons.restaurant_menu_outlined),
                label: const Text('Add Item', style: TextStyle(fontWeight: FontWeight.w700)),
                onPressed: _selectedBranchId == null
                    ? null
                    : () => _showMenuSheet(context, ref, _selectedBranchId!),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showMenuSheet(BuildContext context, WidgetRef ref, String branchId, [Map<String, dynamic>? existing]) {
    final id = existing?['_id'] as String?;
    final nameCtrl = TextEditingController(text: existing?['name'] ?? '');
    final descCtrl = TextEditingController(text: existing?['description'] ?? '');
    final catCtrl = TextEditingController(text: existing?['category'] ?? '');
    final priceCtrl = TextEditingController(
        text: existing != null ? ((existing['basePrice'] as num?)?.toStringAsFixed(0) ?? '') : '');
    final prepCtrl = TextEditingController(text: '${existing?['prepTimeMinutes'] ?? 0}');
    final tagsCtrl = TextEditingController(
        text: (existing?['tags'] as List?)?.join(', ') ?? '');
    bool isVeg = existing?['isVeg'] as bool? ?? false;
    // Hold the raw bytes — not the path — so the same code works on web
    // (where XFile.path is a blob URL that MultipartFile.fromFile can't open)
    // and on mobile. pickedImageName is just for the multipart filename hint.
    Uint8List? pickedImageBytes;
    String? pickedImageName;
    Uint8List? pickedGlbBytes;
    String? pickedGlbName;

    showModalBottomSheet(
      context: context,
      backgroundColor: slateCard,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(id == null ? 'Add Menu Item' : 'Edit — ${existing!['name']}',
                style: const TextStyle(color: textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            _InputField(ctrl: nameCtrl, label: 'Name'),
            const SizedBox(height: 10),
            _InputField(ctrl: descCtrl, label: 'Description'),
            const SizedBox(height: 10),
            _InputField(ctrl: catCtrl, label: 'Category (e.g. Starters)'),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: _InputField(ctrl: priceCtrl, label: 'Base Price (₹)',
                  keyboardType: const TextInputType.numberWithOptions(decimal: true))),
              const SizedBox(width: 10),
              Expanded(child: _InputField(ctrl: prepCtrl, label: 'Prep Time (min)',
                  keyboardType: TextInputType.number)),
            ]),
            const SizedBox(height: 10),
            _InputField(ctrl: tagsCtrl, label: 'Tags (comma separated, e.g. spicy,vegan)'),
            const SizedBox(height: 10),
            Row(children: [
              const Text('Vegetarian', style: TextStyle(color: textPrimary, fontSize: 13)),
              const Spacer(),
              Switch(
                value: isVeg,
                onChanged: (v) => setState(() => isVeg = v),
                activeThumbColor: emerald,
                inactiveThumbColor: textSecondary,
                inactiveTrackColor: slateSurface,
              ),
            ]),
            const SizedBox(height: 10),
            // Photo picker
            GestureDetector(
              onTap: () async {
                final picked = await ImagePicker().pickImage(
                    source: ImageSource.gallery, imageQuality: 85, maxWidth: 1024);
                if (picked != null) {
                  // readAsBytes() works on web and mobile alike, unlike
                  // File(picked.path) which throws UnsupportedError in the
                  // browser.
                  final bytes = await picked.readAsBytes();
                  setState(() {
                    pickedImageBytes = bytes;
                    pickedImageName = picked.name;
                  });
                }
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                decoration: BoxDecoration(
                  color: slateSurface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: pickedImageBytes != null ? copperAccent : dividerColor),
                ),
                child: Row(children: [
                  Icon(Icons.add_photo_alternate_outlined,
                      color: pickedImageBytes != null ? copperAccent : textSecondary, size: 18),
                  const SizedBox(width: 10),
                  Text(
                    pickedImageBytes != null ? 'Photo selected ✓' : 'Add Dish Photo (optional)',
                    style: TextStyle(
                        color: pickedImageBytes != null ? copperAccent : textSecondary, fontSize: 13),
                  ),
                ]),
              ),
            ),
            const SizedBox(height: 10),
            // GLB picker
            GestureDetector(
              onTap: () async {
                // FileType.custom + allowedExtensions: ['glb'] makes Android
                // resolve a MIME for .glb, which it doesn't know — picker
                // throws. Use FileType.any and validate the extension here.
                final result = await FilePicker.platform.pickFiles(
                  type: FileType.any,
                  withData: true,
                );
                final file = result?.files.single;
                if (file != null &&
                    !(file.name.toLowerCase().endsWith('.glb'))) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Please pick a .glb file'),
                      backgroundColor: crimson,
                    ));
                  }
                  return;
                }
                if (file != null && file.bytes != null) {
                  setState(() {
                    pickedGlbBytes = file.bytes;
                    pickedGlbName = file.name;
                  });
                }
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                decoration: BoxDecoration(
                  color: slateSurface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: pickedGlbBytes != null ? copperAccent : dividerColor),
                ),
                child: Row(children: [
                  Icon(Icons.view_in_ar_outlined,
                      color: pickedGlbBytes != null ? copperAccent : textSecondary, size: 18),
                  const SizedBox(width: 10),
                  Text(
                    pickedGlbBytes != null ? '3D Model selected ✓' : 'Add 3D Model (.glb) (optional)',
                    style: TextStyle(
                        color: pickedGlbBytes != null ? copperAccent : textSecondary, fontSize: 13),
                  ),
                ]),
              ),
            ),
            const SizedBox(height: 16),
            _PrimaryButton(
              label: id == null ? 'Create Item' : 'Save Changes',
              onTap: () async {
                if (nameCtrl.text.trim().isEmpty || catCtrl.text.trim().isEmpty) return;
                final price = double.tryParse(priceCtrl.text);
                if (price == null) return;
                Navigator.pop(ctx);
                try {
                  final dio = createDioClient(ref.read(authProvider).token);
                  final tags = tagsCtrl.text.trim().isEmpty
                      ? <String>[]
                      : tagsCtrl.text.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).toList();
                  final data = {
                    'branchId': branchId,
                    'name': nameCtrl.text.trim(),
                    'description': descCtrl.text.trim(),
                    'category': catCtrl.text.trim(),
                    'basePrice': price,
                    'prepTimeMinutes': int.tryParse(prepCtrl.text) ?? 0,
                    'tags': tags,
                    'isVeg': isVeg,
                  };
                  String? savedId = id;
                  if (id == null) {
                    final res = await dio.post('/menu', data: data,
                        options: Options(headers: {'Idempotency-Key': newIdempotencyKey('menu-create')}));
                    savedId = res.data['_id'] as String?;
                  } else {
                    await dio.patch('/menu/$id', data: data,
                        options: Options(headers: {'Idempotency-Key': newIdempotencyKey('menu-edit-$id')}));
                  }
                  // Upload photo if picked. Bytes-based upload — see comment
                  // on pickedImageBytes for why this isn't fromFile().
                  if (pickedImageBytes != null && savedId != null) {
                    // Explicit MIME — without it Dio defaults to
                    // application/octet-stream which the backend stamps
                    // as the photo's mime, and browsers refuse to render
                    // the result as an image.
                    final fn = (pickedImageName ?? 'dish.jpg').toLowerCase();
                    final subtype = fn.endsWith('.png')
                        ? 'png'
                        : fn.endsWith('.webp')
                            ? 'webp'
                            : 'jpeg';
                    final formData = FormData.fromMap({
                      'image': MultipartFile.fromBytes(
                        pickedImageBytes!,
                        filename: pickedImageName ?? 'dish.jpg',
                        contentType: DioMediaType('image', subtype),
                      ),
                    });
                    await dio.post(
                      '/menu/$savedId/image',
                      data: formData,
                      options: Options(headers: {'Idempotency-Key': newIdempotencyKey('menu-image-$savedId')}),
                    );
                  }
                  // Upload GLB if picked
                  if (pickedGlbBytes != null && savedId != null) {
                    final formData = FormData.fromMap({
                      'glb': MultipartFile.fromBytes(pickedGlbBytes!, filename: pickedGlbName ?? 'model.glb'),
                    });
                    await dio.post(
                      '/menu/$savedId/glb',
                      data: formData,
                      options: Options(headers: {'Idempotency-Key': newIdempotencyKey('menu-glb-$savedId')}),
                    );
                  }
                  ref.invalidate(_menuProvider(branchId));
                  if (context.mounted) _showSuccess(context, id == null ? 'Item created' : 'Item updated');
                } catch (e) {
                  if (context.mounted) _showError(context, describeApiError(e));
                }
              },
            ),
          ]),
        ),
      ),
    );
  }
}

class _MenuItemCard extends ConsumerWidget {
  final Map<String, dynamic> item;
  final String branchId;
  const _MenuItemCard({required this.item, required this.branchId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAvailable = item['isAvailable'] as bool? ?? true;
    final isVeg = item['isVeg'] as bool? ?? false;
    final price = (item['basePrice'] as num?)?.toDouble() ?? 0;
    final id = item['_id'] as String? ?? '';
    final prep = item['prepTimeMinutes'] as int? ?? 0;
    final rating = (item['rating'] as num?)?.toDouble() ?? 0;
    final ratingCount = item['ratingCount'] as int? ?? 0;
    final tags = List<String>.from(item['tags'] ?? []);
    final imageUrl = item['imageUrl'] as String?;
    final glbUrl = item['glbUrl'] as String?;
    // Cache-buster: the backend keeps the image URL stable across
    // uploads (`/menu/:id/image`), so CachedNetworkImage would keep
    // serving the previously-cached body (often the 404 placeholder
    // from an earlier attempt) forever. Appending ?v=updatedAt makes
    // every upload land as a brand-new URL → fresh fetch.
    final updatedAt = item['updatedAt'];
    final v = updatedAt != null
        ? (DateTime.tryParse(updatedAt.toString())?.millisecondsSinceEpoch ?? 0)
        : 0;
    final fullImageUrl = imageUrl != null ? '${AppConfig.baseUrl}$imageUrl?v=$v' : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: slateCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isAvailable ? dividerColor : crimson.withValues(alpha: 0.3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Image
        ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
          child: Stack(
            children: [
              fullImageUrl != null
                  ? CachedNetworkImage(
                      imageUrl: fullImageUrl, height: 130, width: double.infinity, fit: BoxFit.cover,
                      placeholder: (_, __) => Container(height: 130, color: slateSurface),
                      errorWidget: (_, __, ___) => _placeholder(),
                    )
                  : _placeholder(),
              Positioned(
                bottom: 8, right: 8,
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  _MediaBtn(icon: Icons.add_photo_alternate_outlined, label: 'Photo',
                      onTap: () => _uploadImage(context, ref, id)),
                  const SizedBox(width: 6),
                  _MediaBtn(icon: Icons.view_in_ar_outlined, label: glbUrl != null ? '3D ✓' : '3D',
                      active: glbUrl != null,
                      onTap: () => _uploadGlb(context, ref, id)),
                  // Preview the uploaded GLB in the same AR/3D page the
                  // customer sees. Only rendered when an upload exists —
                  // admin verifies "does this 3D model match the food?"
                  // without leaving the menu screen.
                  if (glbUrl != null) ...[
                    const SizedBox(width: 6),
                    _MediaBtn(
                      icon: Icons.preview_outlined,
                      label: 'View',
                      active: true,
                      onTap: () {
                        final name = Uri.encodeComponent(
                            (item['name'] as String?) ?? 'Item');
                        final model = Uri.encodeComponent(glbUrl);
                        openInNewTab(
                            '/ar.html?model=$model&name=$name');
                      },
                    ),
                  ],
                ]),
              ),
              Positioned(
                top: 8, left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: (isVeg ? emerald : crimson).withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(isVeg ? '🟢 VEG' : '🔴 NON-VEG',
                      style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(item['name'] ?? '',
                  style: const TextStyle(color: textPrimary, fontSize: 13, fontWeight: FontWeight.w700))),
              Text('₹${price.toStringAsFixed(0)}',
                  style: const TextStyle(color: copperAccent, fontSize: 14, fontWeight: FontWeight.w800)),
            ]),
            if ((item['description'] as String? ?? '').isNotEmpty) ...[
              const SizedBox(height: 3),
              Text(item['description'] ?? '',
                  style: const TextStyle(color: textSecondary, fontSize: 11),
                  maxLines: 2, overflow: TextOverflow.ellipsis),
            ],
            if (tags.isNotEmpty) ...[
              const SizedBox(height: 6),
              Wrap(spacing: 4, runSpacing: 4,
                children: tags.map((t) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: copperAccent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: copperAccent.withValues(alpha: 0.2)),
                  ),
                  child: Text(t, style: const TextStyle(color: copperAccent, fontSize: 9, fontWeight: FontWeight.w600)),
                )).toList()),
            ],
            const SizedBox(height: 8),
            Row(children: [
              const Icon(Icons.star_rounded, color: amber, size: 13),
              const SizedBox(width: 3),
              Text('${rating.toStringAsFixed(1)} ($ratingCount)',
                  style: const TextStyle(color: textSecondary, fontSize: 11)),
              if (prep > 0) ...[
                const SizedBox(width: 10),
                const Icon(Icons.timer_outlined, color: textSecondary, size: 12),
                const SizedBox(width: 3),
                Text('${prep}m', style: const TextStyle(color: textSecondary, fontSize: 11)),
              ],
              const Spacer(),
              // Availability
              GestureDetector(
                onTap: () async {
                  try {
                    final dio = createDioClient(ref.read(authProvider).token);
                    await dio.patch('/menu/$id', data: {'isAvailable': !isAvailable},
                        options: Options(headers: {'Idempotency-Key': newIdempotencyKey('menu-toggle-$id')}));
                    ref.invalidate(_menuProvider(branchId));
                  } catch (e) {
                    if (context.mounted) _showError(context, describeApiError(e));
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: (isAvailable ? emerald : crimson).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: (isAvailable ? emerald : crimson).withValues(alpha: 0.3)),
                  ),
                  child: Text(isAvailable ? 'AVAILABLE' : 'UNAVAILABLE',
                      style: TextStyle(color: isAvailable ? emerald : crimson, fontSize: 9, fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(width: 6),
              // Edit
              GestureDetector(
                onTap: () {
                  final state = context.findAncestorStateOfType<_MenuManagementTabState>();
                  state?._showMenuSheet(context, ref, branchId, item);
                },
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(color: slateSurface, borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.edit_outlined, color: textSecondary, size: 15),
                ),
              ),
              const SizedBox(width: 4),
              // Delete
              GestureDetector(
                onTap: () => showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    backgroundColor: slateCard,
                    title: const Text('Delete Item?', style: TextStyle(color: textPrimary)),
                    content: Text('Permanently delete "${item['name'] ?? ''}". This cannot be undone.',
                        style: const TextStyle(color: textSecondary)),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel', style: TextStyle(color: textSecondary))),
                      TextButton(
                        onPressed: () async {
                          Navigator.pop(context);
                          try {
                            final dio = createDioClient(ref.read(authProvider).token);
                            await dio.delete(
                              '/menu/$id',
                              options: Options(headers: {'Idempotency-Key': newIdempotencyKey('del-menu-$id')}),
                            );
                            ref.invalidate(_menuProvider(branchId));
                            if (context.mounted) _showSuccess(context, 'Item deleted');
                          } catch (e) {
                            if (context.mounted) _showError(context, describeApiError(e));
                          }
                        },
                        child: const Text('Delete', style: TextStyle(color: crimson, fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                ),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(color: crimson.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.delete_outline, color: crimson, size: 15),
                ),
              ),
            ]),
          ]),
        ),
      ]),
    );
  }

  Widget _placeholder() => Container(
        height: 130, width: double.infinity, color: slateSurface,
        child: const Icon(Icons.restaurant_outlined, color: textSecondary, size: 36),
      );

  Future<void> _uploadGlb(BuildContext context, WidgetRef ref, String id) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      withData: true,
    );
    final file = result?.files.single;
    if (file != null && !(file.name.toLowerCase().endsWith('.glb'))) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Please pick a .glb file'),
          backgroundColor: crimson,
        ));
      }
      return;
    }
    if (file == null || file.bytes == null) return;
    try {
      final dio = createDioClient(ref.read(authProvider).token);
      final formData = FormData.fromMap({
        'glb': MultipartFile.fromBytes(file.bytes!, filename: file.name),
      });
      await dio.post(
        '/menu/$id/glb',
        data: formData,
        options: Options(headers: {'Idempotency-Key': newIdempotencyKey('menu-glb-$id')}),
      );
      ref.invalidate(_menuProvider(branchId));
      if (context.mounted) _showSuccess(context, '3D model uploaded');
    } catch (e) {
      if (context.mounted) _showError(context, describeApiError(e));
    }
  }

  Future<void> _uploadImage(BuildContext context, WidgetRef ref, String id) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: slateCard,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 12),
          ListTile(
            leading: const Icon(Icons.camera_alt_outlined, color: copperAccent),
            title: const Text('Camera', style: TextStyle(color: textPrimary)),
            onTap: () => Navigator.pop(context, ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined, color: copperAccent),
            title: const Text('Gallery', style: TextStyle(color: textPrimary)),
            onTap: () => Navigator.pop(context, ImageSource.gallery),
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
    if (source == null) return;
    final picked = await ImagePicker().pickImage(source: source, imageQuality: 85, maxWidth: 1024);
    if (picked == null) return;
    try {
      final dio = createDioClient(ref.read(authProvider).token);
      // Bytes-based upload — fromFile() can't open blob: URLs on web.
      final bytes = await picked.readAsBytes();
      final fn = picked.name.toLowerCase();
      final subtype = fn.endsWith('.png')
          ? 'png'
          : fn.endsWith('.webp')
              ? 'webp'
              : 'jpeg';
      final formData = FormData.fromMap({
        'image': MultipartFile.fromBytes(
          bytes,
          filename: picked.name,
          contentType: DioMediaType('image', subtype),
        ),
      });
      await dio.post(
        '/menu/$id/image',
        data: formData,
        options: Options(headers: {'Idempotency-Key': newIdempotencyKey('menu-image-$id')}),
      );
      ref.invalidate(_menuProvider(branchId));
      if (context.mounted) _showSuccess(context, 'Photo updated');
    } catch (e) {
      if (context.mounted) _showError(context, describeApiError(e));
    }
  }
}

class _MediaBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;
  const _MediaBtn({required this.icon, required this.label, required this.onTap, this.active = false});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: active ? copperAccent.withValues(alpha: 0.9) : Colors.black54,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, color: Colors.white, size: 13),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600)),
          ]),
        ),
      );
}

// ═══════════════════════════════════════════════════════════════════════════════
// SHARED HELPERS & WIDGETS
// ═══════════════════════════════════════════════════════════════════════════════

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _MetricCard(this.label, this.value, this.icon, this.color);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: slateCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Icon(icon, color: color, size: 20),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(value, style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.w800)),
            Text(label, style: const TextStyle(color: textSecondary, fontSize: 11)),
          ]),
        ]),
      ).animate().fadeIn(duration: 300.ms);
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);
  @override
  Widget build(BuildContext context) => Text(title,
      style: const TextStyle(color: textPrimary, fontSize: 14, fontWeight: FontWeight.w700));
}

class _ChartSkeleton extends StatelessWidget {
  final double height;
  const _ChartSkeleton({this.height = 160});
  @override
  Widget build(BuildContext context) => Container(
        height: height,
        decoration: BoxDecoration(color: slateCard, borderRadius: BorderRadius.circular(14)),
        child: const Center(child: CircularProgressIndicator(color: copperAccent, strokeWidth: 2)),
      );
}

/// Reusable empty-state card. Used wherever the tab data is empty —
/// gives users orientation (what is this view?) and a next-step nudge
/// instead of staring at a blank scroll area.
class _EmptyView extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _EmptyView({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: textSecondary.withValues(alpha: 0.4)),
            const SizedBox(height: 18),
            Text(title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: textSecondary, fontSize: 13, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorText extends StatelessWidget {
  final String message;
  const _ErrorText(this.message);
  @override
  Widget build(BuildContext context) =>
      Text(message, style: const TextStyle(color: crimson, fontSize: 12));
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge(this.status);

  static const _colors = {
    'created': amber, 'confirmed': copperAccent, 'preparing': roseGold,
    'ready': emerald, 'served': emerald, 'billed': amber,
    'paid': emerald, 'closed': textSecondary,
  };

  @override
  Widget build(BuildContext context) {
    final color = _colors[status] ?? textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(status.toUpperCase(), style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w700)),
    );
  }
}

class _InputField extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  final bool obscure;
  final TextInputType? keyboardType;
  final String? errorText;
  const _InputField({
    required this.ctrl,
    required this.label,
    this.obscure = false,
    this.keyboardType,
    this.errorText,
  });

  @override
  Widget build(BuildContext context) => TextField(
        controller: ctrl,
        obscureText: obscure,
        keyboardType: keyboardType,
        style: const TextStyle(color: textPrimary),
        decoration: _inputDec(label).copyWith(errorText: errorText),
      );
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _PrimaryButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            gradient: copperGradient,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(child: Text(label,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14))),
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

void _showError(BuildContext context, String msg) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(msg), backgroundColor: crimson, behavior: SnackBarBehavior.floating),
  );
}

void _showSuccess(BuildContext context, String msg) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(msg), backgroundColor: emerald, behavior: SnackBarBehavior.floating),
  );
}
