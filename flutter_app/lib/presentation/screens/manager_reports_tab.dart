// ─── Manager: Reports Tab ─────────────────────────────────────────────────────
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/config/app_theme.dart';
import '../../core/network/dio_client.dart';
import '../../core/utils/api_error.dart';
import '../../data/api/manager_api.dart';
import '../state/auth_provider.dart';

/// Date range selected via the picker. Drives all analytics providers.
/// Default: last 7 days.
class DateRange {
  final DateTime from;
  final DateTime to;
  const DateRange(this.from, this.to);

  String get fromIso => from.toIso8601String();
  String get toIso => to.toIso8601String();
  String get label =>
      '${DateFormat('dd MMM').format(from)} – ${DateFormat('dd MMM').format(to)}';
}

DateRange _defaultRange() {
  final now = DateTime.now();
  return DateRange(now.subtract(const Duration(days: 7)), now);
}

final reportsDateRangeProvider = StateProvider<DateRange>((_) => _defaultRange());

final _operationalReportProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>(
        (ref) => ref.watch(managerApiProvider).report());

final _salesProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final token = ref.watch(authProvider).token;
  final range = ref.watch(reportsDateRangeProvider);
  final dio = createDioClient(token);
  final res = await dio.get('/analytics/sales',
      queryParameters: {'from': range.fromIso, 'to': range.toIso});
  return List<Map<String, dynamic>>.from(res.data);
});

final _peakHoursProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final token = ref.watch(authProvider).token;
  final range = ref.watch(reportsDateRangeProvider);
  final dio = createDioClient(token);
  final res = await dio.get('/analytics/peak-hours',
      queryParameters: {'from': range.fromIso, 'to': range.toIso});
  return List<Map<String, dynamic>>.from(res.data);
});

final _topItemsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final token = ref.watch(authProvider).token;
  final range = ref.watch(reportsDateRangeProvider);
  final dio = createDioClient(token);
  final res = await dio.get('/analytics/top-items', queryParameters: {
    'limit': '5',
    'from': range.fromIso,
    'to': range.toIso,
  });
  return List<Map<String, dynamic>>.from(res.data);
});

// ── Tab ───────────────────────────────────────────────────────────────────────
class ManagerReportsTab extends ConsumerWidget {
  const ManagerReportsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportAsync   = ref.watch(_operationalReportProvider);
    final salesAsync    = ref.watch(_salesProvider);
    final peakAsync     = ref.watch(_peakHoursProvider);
    final topAsync      = ref.watch(_topItemsProvider);
    final range         = ref.watch(reportsDateRangeProvider);

    return RefreshIndicator(
      color: copperAccent,
      backgroundColor: slateCard,
      onRefresh: () async {
        ref.invalidate(_operationalReportProvider);
        ref.invalidate(_salesProvider);
        ref.invalidate(_peakHoursProvider);
        ref.invalidate(_topItemsProvider);
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        children: [
          _DateRangePicker(range: range),
          const SizedBox(height: 20),
          _SectionTitle("Today's Summary"),
          const SizedBox(height: 10),
          reportAsync.when(
            loading: () => const _Skeleton(height: 160),
            error: (e, _) => _ErrorBanner(describeApiError(e)),
            data: (r) => _TodaySummary(report: r),
          ),
          const SizedBox(height: 20),

          // ── Status breakdown ─────────────────────────────────────────
          reportAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
            data: (r) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SectionTitle('Order Status Breakdown'),
                const SizedBox(height: 10),
                _StatusBreakdown(
                    breakdown: Map<String, dynamic>.from(
                        r['statusBreakdown'] ?? {})),
                const SizedBox(height: 20),
              ],
            ),
          ),

          // ── Revenue chart (7 days) ───────────────────────────────────
          const _SectionTitle('Revenue'),
          const SizedBox(height: 10),
          salesAsync.when(
            loading: () => const _Skeleton(),
            error: (e, _) => _ErrorBanner(describeApiError(e)),
            data: (data) => _RevenueChart(data: data),
          ),
          const SizedBox(height: 20),

          // ── Peak hours ───────────────────────────────────────────────
          const _SectionTitle('Peak Hours'),
          const SizedBox(height: 10),
          peakAsync.when(
            loading: () => const _Skeleton(height: 120),
            error: (e, _) => _ErrorBanner(describeApiError(e)),
            data: (data) => _PeakHoursChart(data: data),
          ),
          const SizedBox(height: 20),

          // ── Top menu items ───────────────────────────────────────────
          const _SectionTitle('Top Menu Items'),
          const SizedBox(height: 10),
          topAsync.when(
            loading: () => const _Skeleton(height: 120),
            error: (e, _) => _ErrorBanner(describeApiError(e)),
            data: (items) => _TopItemsList(items: items),
          ),
          const SizedBox(height: 20),

          // ── Staff activity ───────────────────────────────────────────
          reportAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
            data: (r) {
              final activity = List<Map<String, dynamic>>.from(
                  r['staffActivity'] ?? []);
              if (activity.isEmpty) return const SizedBox.shrink();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _SectionTitle('Staff Activity Today'),
                  const SizedBox(height: 10),
                  _StaffActivityList(activity: activity),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

// ── Date-range picker bar ─────────────────────────────────────────────────────
class _DateRangePicker extends ConsumerWidget {
  final DateRange range;
  const _DateRangePicker({required this.range});

  static const _presets = <_RangePreset>[
    _RangePreset('Today', 0),
    _RangePreset('7d', 7),
    _RangePreset('30d', 30),
    _RangePreset('90d', 90),
  ];

  bool _matchesPreset(_RangePreset preset, DateRange r) {
    final now = DateTime.now();
    final expectedFrom = now.subtract(Duration(days: preset.days));
    return r.from.year == expectedFrom.year &&
        r.from.month == expectedFrom.month &&
        r.from.day == expectedFrom.day;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
          Text(range.label,
              style: const TextStyle(
                  color: textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700)),
          const Spacer(),
          GestureDetector(
            onTap: () => _pickCustom(context, ref),
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
            final selected = _matchesPreset(p, range);
            return Expanded(
              child: GestureDetector(
                onTap: () {
                  final now = DateTime.now();
                  ref.read(reportsDateRangeProvider.notifier).state =
                      DateRange(now.subtract(Duration(days: p.days)), now);
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

  Future<void> _pickCustom(BuildContext context, WidgetRef ref) async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 2),
      lastDate: now,
      initialDateRange: DateTimeRange(start: range.from, end: range.to),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: copperAccent,
            onPrimary: Colors.white,
            surface: slateCard,
            onSurface: textPrimary,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      ref.read(reportsDateRangeProvider.notifier).state =
          DateRange(picked.start, picked.end);
    }
  }
}

class _RangePreset {
  final String label;
  final int days;
  const _RangePreset(this.label, this.days);
}

// ── Today's summary card ──────────────────────────────────────────────────────
class _TodaySummary extends StatelessWidget {
  final Map<String, dynamic> report;
  const _TodaySummary({required this.report});

  @override
  Widget build(BuildContext context) {
    final totalOrders   = report['totalOrders'] as int? ?? 0;
    final paidBills     = report['paidBills'] as int? ?? 0;
    final revenue       = (report['totalRevenue'] as num? ?? 0).toDouble();
    final avgService    = (report['avgServiceTimeMinutes'] as num? ?? 0).toDouble();
    final date          = report['date'] as String? ?? '';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: slateCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: copperAccent.withValues(alpha: 0.2)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.today_outlined, color: copperAccent, size: 14),
          const SizedBox(width: 6),
          Text(date,
              style: const TextStyle(color: textSecondary, fontSize: 12)),
        ]),
        const SizedBox(height: 14),
        Row(children: [
          _StatBox('Orders', '$totalOrders', copperAccent),
          _StatBox('Paid Bills', '$paidBills', emerald),
          _StatBox('Revenue', '₹${revenue.toStringAsFixed(0)}', roseGold),
          _StatBox('Avg Service', '${avgService.toStringAsFixed(1)}m', amber),
        ]),
      ]),
    ).animate().fadeIn(duration: 300.ms);
  }
}

class _StatBox extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatBox(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(value,
                style: TextStyle(
                    color: color,
                    fontSize: 18,
                    fontWeight: FontWeight.w800)),
          ),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(color: textSecondary, fontSize: 10),
              textAlign: TextAlign.center),
        ]),
      );
}

// ── Status breakdown ──────────────────────────────────────────────────────────
class _StatusBreakdown extends StatelessWidget {
  final Map<String, dynamic> breakdown;
  const _StatusBreakdown({required this.breakdown});

  static const _colors = {
    'created':   textSecondary,
    'confirmed': amber,
    'preparing': copperAccent,
    'ready':     emerald,
    'served':    roseGold,
    'billed':    Colors.blue,
    'paid':      emerald,
    'closed':    textSecondary,
  };

  @override
  Widget build(BuildContext context) {
    final entries = breakdown.entries
        .where((e) => (e.value as int? ?? 0) > 0)
        .toList();
    if (entries.isEmpty) {
      return const Text('No orders today',
          style: TextStyle(color: textSecondary, fontSize: 12));
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: entries.map((e) {
        final color = _colors[e.key] ?? textSecondary;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(e.key.toUpperCase(),
                style: TextStyle(
                    color: color, fontSize: 10, fontWeight: FontWeight.w700)),
            const SizedBox(width: 6),
            Text('${e.value}',
                style: TextStyle(
                    color: color, fontSize: 13, fontWeight: FontWeight.w800)),
          ]),
        );
      }).toList(),
    );
  }
}

// ── Revenue chart ─────────────────────────────────────────────────────────────
class _RevenueChart extends StatelessWidget {
  final List<Map<String, dynamic>> data;
  const _RevenueChart({required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return const _NoData();
    }
    final spots = data.asMap().entries.map((e) =>
        FlSpot(e.key.toDouble(),
            (e.value['revenue'] as num? ?? 0).toDouble())).toList();

    return Container(
      height: 180,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: slateCard, borderRadius: BorderRadius.circular(14)),
      child: LineChart(LineChartData(
        gridData: FlGridData(
          show: true,
          getDrawingHorizontalLine: (_) =>
              const FlLine(color: dividerColor, strokeWidth: 0.5),
          drawVerticalLine: false,
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 44,
              getTitlesWidget: (v, _) => Text(
                '₹${(v / 1000).toStringAsFixed(0)}k',
                style: const TextStyle(color: textSecondary, fontSize: 9),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (v, _) {
                final idx = v.toInt();
                if (idx < 0 || idx >= data.length) {
                  return const SizedBox.shrink();
                }
                final date = data[idx]['_id'] as String? ?? '';
                return Text(
                  date.length >= 10 ? date.substring(5) : date,
                  style: const TextStyle(color: textSecondary, fontSize: 9),
                );
              },
            ),
          ),
          topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: copperAccent,
            barWidth: 2.5,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: copperAccent.withValues(alpha: 0.1),
            ),
          ),
        ],
      )),
    );
  }
}

// ── Peak hours chart ──────────────────────────────────────────────────────────
class _PeakHoursChart extends StatelessWidget {
  final List<Map<String, dynamic>> data;
  const _PeakHoursChart({required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const _NoData();
    final maxY = data.fold<int>(
            0, (m, e) => (e['count'] as int? ?? 0) > m ? e['count'] as int : m)
        .toDouble();

    return Container(
      height: 130,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: slateCard, borderRadius: BorderRadius.circular(14)),
      child: BarChart(BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxY * 1.2,
        barTouchData: BarTouchData(enabled: false),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (v, _) => Text('${v.toInt()}h',
                  style: const TextStyle(
                      color: textSecondary, fontSize: 9)),
            ),
          ),
          leftTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        gridData: const FlGridData(show: false),
        barGroups: data
            .map((d) => BarChartGroupData(
                  x: d['hour'] as int? ?? 0,
                  barRods: [
                    BarChartRodData(
                      toY: (d['count'] as int? ?? 0).toDouble(),
                      color: copperAccent,
                      width: 8,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ],
                ))
            .toList(),
      )),
    );
  }
}

// ── Top items list ────────────────────────────────────────────────────────────
class _TopItemsList extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  const _TopItemsList({required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const _NoData();
    return Column(
      children: items.asMap().entries.map((e) {
        final rank    = e.key + 1;
        final item    = e.value;
        final qty     = item['totalQty'] as int? ?? 0;
        final revenue = (item['totalRevenue'] as num? ?? 0).toDouble();
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
              color: slateCard, borderRadius: BorderRadius.circular(10)),
          child: Row(children: [
            Container(
              width: 26, height: 26,
              decoration: BoxDecoration(
                color: copperAccent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text('$rank',
                    style: const TextStyle(
                        color: copperAccent,
                        fontSize: 11,
                        fontWeight: FontWeight.w800)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(item['name'] as String? ?? '',
                  style: const TextStyle(
                      color: textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
            ),
            Text('$qty sold',
                style: const TextStyle(
                    color: textSecondary, fontSize: 11)),
            const SizedBox(width: 10),
            Text('₹${revenue.toStringAsFixed(0)}',
                style: const TextStyle(
                    color: copperAccent,
                    fontSize: 12,
                    fontWeight: FontWeight.w700)),
          ]),
        );
      }).toList(),
    );
  }
}

// ── Staff activity list ───────────────────────────────────────────────────────
class _StaffActivityList extends StatelessWidget {
  final List<Map<String, dynamic>> activity;
  const _StaffActivityList({required this.activity});

  @override
  Widget build(BuildContext context) => Column(
        children: activity.take(5).map((s) {
          final count   = s['count'] as int? ?? 0;
          final revenue = (s['revenue'] as num? ?? 0).toDouble();
          final id      = s['_id'] as String? ?? '';
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
                color: slateCard, borderRadius: BorderRadius.circular(10)),
            child: Row(children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: roseGold.withValues(alpha: 0.15),
                child: Text(
                  id.isNotEmpty ? id.substring(0, 1).toUpperCase() : 'S',
                  style: const TextStyle(
                      color: roseGold,
                      fontSize: 12,
                      fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(id,
                    style: const TextStyle(
                        color: textSecondary, fontSize: 11),
                    overflow: TextOverflow.ellipsis),
              ),
              Text('$count orders',
                  style: const TextStyle(
                      color: copperAccent,
                      fontSize: 11,
                      fontWeight: FontWeight.w700)),
              const SizedBox(width: 10),
              Text('₹${revenue.toStringAsFixed(0)}',
                  style: const TextStyle(
                      color: emerald,
                      fontSize: 11,
                      fontWeight: FontWeight.w600)),
            ]),
          );
        }).toList(),
      );
}

// ── Shared helpers ────────────────────────────────────────────────────────────
class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) => Text(title,
      style: const TextStyle(
          color: textPrimary, fontSize: 14, fontWeight: FontWeight.w700));
}

class _Skeleton extends StatelessWidget {
  final double height;
  const _Skeleton({this.height = 180});

  @override
  Widget build(BuildContext context) => Container(
        height: height,
        decoration: BoxDecoration(
            color: slateCard, borderRadius: BorderRadius.circular(14)),
        child: const Center(
            child: CircularProgressIndicator(
                color: copperAccent, strokeWidth: 2)),
      );
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner(this.message);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: crimson.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: crimson.withValues(alpha: 0.3)),
        ),
        child: Row(children: [
          const Icon(Icons.error_outline, color: crimson, size: 14),
          const SizedBox(width: 8),
          Expanded(
              child: Text(message,
                  style: const TextStyle(color: crimson, fontSize: 11))),
        ]),
      );
}

class _NoData extends StatelessWidget {
  const _NoData();

  @override
  Widget build(BuildContext context) => Container(
        height: 80,
        decoration: BoxDecoration(
            color: slateCard, borderRadius: BorderRadius.circular(14)),
        child: const Center(
            child: Text('No data available',
                style: TextStyle(color: textSecondary, fontSize: 12))),
      );
}
