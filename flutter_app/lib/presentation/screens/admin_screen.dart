// ─── Admin Portal — Complete Production-Grade Screen ─────────────────────────
// Tabs: Overview · Analytics · Staff · Orders · Billing · Inventory · System

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../core/config/app_theme.dart';
import '../../core/network/dio_client.dart';
import '../state/auth_provider.dart';
import '../state/order_providers.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// PROVIDERS
// ═══════════════════════════════════════════════════════════════════════════════

final _salesProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final token = ref.watch(authProvider).token;
  if (token == null) throw Exception('Not authenticated');
  final dio = createDioClient(token);
  final res = await dio.get('/analytics/sales');
  return List<Map<String, dynamic>>.from(res.data);
});

final _topItemsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final token = ref.watch(authProvider).token;
  if (token == null) throw Exception('Not authenticated');
  final dio = createDioClient(token);
  final res = await dio.get('/analytics/top-items');
  return List<Map<String, dynamic>>.from(res.data);
});

final _peakHoursProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final token = ref.watch(authProvider).token;
  if (token == null) throw Exception('Not authenticated');
  final dio = createDioClient(token);
  final res = await dio.get('/analytics/peak-hours');
  return List<Map<String, dynamic>>.from(res.data);
});

final _staffProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final token = ref.watch(authProvider).token;
  if (token == null) throw Exception('Not authenticated');
  final dio = createDioClient(token);
  final res = await dio.get('/users');
  return List<Map<String, dynamic>>.from(res.data);
});

final _branchesProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final token = ref.watch(authProvider).token;
  if (token == null) throw Exception('Not authenticated');
  final dio = createDioClient(token);
  final res = await dio.get('/branches');
  return List<Map<String, dynamic>>.from(res.data);
});

final _systemHealthProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final token = ref.watch(authProvider).token;
  if (token == null) throw Exception('Not authenticated');
  final dio = createDioClient(token);
  final res = await dio.get('/admin/system-health');
  return Map<String, dynamic>.from(res.data);
});

final _financialSummaryProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final token = ref.watch(authProvider).token;
  if (token == null) throw Exception('Not authenticated');
  final dio = createDioClient(token);
  final res = await dio.get('/admin/financial-summary');
  return Map<String, dynamic>.from(res.data);
});

final _transactionsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final token = ref.watch(authProvider).token;
  if (token == null) throw Exception('Not authenticated');
  final dio = createDioClient(token);
  final res = await dio.get('/admin/transactions');
  return List<Map<String, dynamic>>.from(res.data);
});

final _profitMarginProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final token = ref.watch(authProvider).token;
  if (token == null) throw Exception('Not authenticated');
  final dio = createDioClient(token);
  final res = await dio.get('/admin/profit-margin');
  return Map<String, dynamic>.from(res.data);
});

final _auditLogProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final token = ref.watch(authProvider).token;
  if (token == null) throw Exception('Not authenticated');
  final dio = createDioClient(token);
  final res = await dio.get('/admin/audit-log');
  return List<Map<String, dynamic>>.from(res.data);
});

final _inventoryAdminProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final token = ref.watch(authProvider).token;
  if (token == null) throw Exception('Not authenticated');
  final dio = createDioClient(token);
  final res = await dio.get('/inventory');
  return List<Map<String, dynamic>>.from(res.data);
});

final _allOrdersProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final token = ref.watch(authProvider).token;
  if (token == null) throw Exception('Not authenticated');
  final dio = createDioClient(token);
  final res = await dio.get('/orders/active');
  return List<Map<String, dynamic>>.from(res.data);
});

final _menuProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final token = ref.watch(authProvider).token;
  if (token == null) throw Exception('Not authenticated');
  final dio = createDioClient(token);
  final res = await dio.get('/menu');
  return List<Map<String, dynamic>>.from(res.data);
});

final _staffAnalyticsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final dio = createDioClient(ref.watch(authProvider).token);
  final res = await dio.get('/analytics/staff-performance');
  return List<Map<String, dynamic>>.from(res.data);
});

// ═══════════════════════════════════════════════════════════════════════════════
// TAB 1 — OVERVIEW
// ═══════════════════════════════════════════════════════════════════════════════

class AdminOverviewTab extends ConsumerWidget {
  const AdminOverviewTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metrics = ref.watch(dashboardMetricsProvider);
    final orders = ref.watch(liveOrdersProvider);
    final healthAsync = ref.watch(_systemHealthProvider);
    final finAsync = ref.watch(_financialSummaryProvider);

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
        final count = orders.where((o) => o.status.name == stage).length;
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
        const _SectionTitle('Revenue — Last 7 Days'),
        const SizedBox(height: 12),
        salesAsync.when(
          loading: () => const _ChartSkeleton(),
          error: (e, _) => _ErrorText('$e'),
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
          error: (e, _) => _ErrorText('$e'),
          data: (data) => _PeakHoursChart(data: data),
        ),
        const SizedBox(height: 24),
        const _SectionTitle('Top Menu Items'),
        const SizedBox(height: 12),
        topItemsAsync.when(
          loading: () => const _ChartSkeleton(height: 120),
          error: (e, _) => _ErrorText('$e'),
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
// TAB 3 — STAFF MANAGEMENT
// ═══════════════════════════════════════════════════════════════════════════════

class AdminStaffTab extends ConsumerWidget {
  const AdminStaffTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final staffAsync = ref.watch(_staffProvider);

    return Stack(
      children: [
        staffAsync.when(
          loading: () => const Center(child: CircularProgressIndicator(color: copperAccent)),
          error: (e, _) => Center(child: _ErrorText('$e')),
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
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    String selectedRole = 'waiter';

    showModalBottomSheet(
      context: context,
      backgroundColor: slateCard,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => Padding(
          padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Add Staff Member', style: TextStyle(color: textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            _InputField(ctrl: nameCtrl, label: 'Full Name'),
            const SizedBox(height: 10),
            _InputField(ctrl: emailCtrl, label: 'Email', keyboardType: TextInputType.emailAddress),
            const SizedBox(height: 10),
            _InputField(ctrl: passCtrl, label: 'Password', obscure: true),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: selectedRole,
              dropdownColor: slateSurface,
              style: const TextStyle(color: textPrimary),
              decoration: _inputDec('Role'),
              items: ['manager', 'waiter', 'chef', 'cashier']
                  .map((r) => DropdownMenuItem(value: r, child: Text(r.toUpperCase())))
                  .toList(),
              onChanged: (v) => setState(() => selectedRole = v ?? 'waiter'),
            ),
            const SizedBox(height: 16),
            _PrimaryButton(
              label: 'Create Account',
              onTap: () async {
                Navigator.pop(ctx);
                try {
                  final dio = createDioClient(ref.read(authProvider).token);
                  await dio.post('/users', data: {
                    'name': nameCtrl.text.trim(),
                    'email': emailCtrl.text.trim().toLowerCase(),
                    'password': passCtrl.text,
                    'role': selectedRole,
                  }, options: Options(headers: {'Idempotency-Key': 'create-user-${nameCtrl.text.trim()}-${DateTime.now().millisecondsSinceEpoch}'}));
                  ref.invalidate(_staffProvider);
                } catch (e) {
                  if (context.mounted) _showError(context, '$e');
                }
              },
            ),
          ]),
        ),
      ),
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
        CircleAvatar(
          radius: 20,
          backgroundColor: color.withValues(alpha: 0.15),
          child: Text((user['name'] as String? ?? 'U').substring(0, 1).toUpperCase(),
              style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w700)),
        ),
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
            GestureDetector(
              onTap: () async {
                try {
                  final dio = createDioClient(ref.read(authProvider).token);
                  await dio.patch('/users/$id', data: {'isActive': !isActive},
                      options: Options(headers: {'Idempotency-Key': 'toggle-user-$id-${DateTime.now().millisecondsSinceEpoch}'}));
                  ref.invalidate(_staffProvider);
                } catch (e) {
                  if (context.mounted) _showError(context, '$e');
                }
              },
              child: Container(
                width: 8, height: 8,
                decoration: BoxDecoration(color: isActive ? emerald : textSecondary, shape: BoxShape.circle),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () {
                final ctrl = TextEditingController();
                showModalBottomSheet(
                  context: context,
                  backgroundColor: slateCard,
                  isScrollControlled: true,
                  shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
                  builder: (ctx) => Padding(
                    padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
                    child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Reset Password — ${user['name'] ?? ''}',
                          style: const TextStyle(color: textPrimary, fontSize: 15, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 16),
                      _InputField(ctrl: ctrl, label: 'New Password (min 6 chars)', obscure: true),
                      const SizedBox(height: 16),
                      _PrimaryButton(
                        label: 'Reset Password',
                        onTap: () async {
                          if (ctrl.text.length < 6) return;
                          Navigator.pop(ctx);
                          try {
                            final dio = createDioClient(ref.read(authProvider).token);
                            await dio.post('/admin/users/$id/reset-password', data: {'newPassword': ctrl.text});
                            if (context.mounted) _showSuccess(context, 'Password reset successfully');
                          } catch (e) {
                            if (context.mounted) _showError(context, '$e');
                          }
                        },
                      ),
                    ]),
                  ),
                );
              },
              child: const Icon(Icons.lock_reset_outlined, color: textSecondary, size: 16),
            ),
          ]),
        ]),
      ]),
    ).animate().fadeIn(duration: 250.ms);
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

    return ordersAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: copperAccent)),
      error: (e, _) => Center(child: _ErrorText('$e')),
      data: (orders) => ListView(
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
                await dio.patch('/admin/orders/$id/force-close');
                ref.invalidate(_allOrdersProvider);
                if (context.mounted) _showSuccess(context, 'Order force-closed');
              } catch (e) {
                if (context.mounted) _showError(context, '$e');
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
        const _SectionTitle('Transaction Log'),
        const SizedBox(height: 12),
        txAsync.when(
          loading: () => const Center(child: CircularProgressIndicator(color: copperAccent)),
          error: (e, _) => _ErrorText('$e'),
          data: (txs) => Column(
            children: txs.map((tx) => _TransactionCard(tx: tx)).toList(),
          ),
        ),
      ],
    );
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
            child: const Icon(Icons.undo_outlined, color: crimson, size: 18),
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
                await dio.patch('/admin/billing/$id/refund');
                ref.invalidate(_transactionsProvider);
                ref.invalidate(_financialSummaryProvider);
                if (context.mounted) _showSuccess(context, 'Refund processed');
              } catch (e) {
                if (context.mounted) _showError(context, '$e');
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

    return invAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: copperAccent)),
      error: (e, _) => Center(child: _ErrorText('$e')),
      data: (items) {
        final lowItems = items.where((i) {
          final cur = (i['currentStock'] as num?)?.toDouble() ?? 0;
          final thresh = (i['lowStockThreshold'] as num?)?.toDouble() ?? 0;
          return cur <= thresh;
        }).toList();

        return ListView(
          padding: const EdgeInsets.all(16),
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
                  Text('${lowItems.length} items low on stock',
                      style: const TextStyle(color: crimson, fontWeight: FontWeight.w600, fontSize: 13)),
                ]),
              ),
            // Summary stats
            Row(children: [
              _SmallStat('Total Items', '${items.length}', copperAccent),
              _SmallStat('Low Stock', '${lowItems.length}', crimson),
              _SmallStat('OK', '${items.length - lowItems.length}', emerald),
            ]),
            const SizedBox(height: 16),
            ...items.map((item) => _AdminInventoryCard(item: item)),
          ],
        );
      },
    );
  }
}

class _AdminInventoryCard extends ConsumerWidget {
  final Map<String, dynamic> item;
  const _AdminInventoryCard({required this.item});

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
          Expanded(child: Text(item['name'] ?? '',
              style: const TextStyle(color: textPrimary, fontSize: 13, fontWeight: FontWeight.w600))),
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
              child: const Icon(Icons.edit_outlined, color: textSecondary, size: 16),
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
              if (delta == null) return;
              Navigator.pop(ctx);
              try {
                final dio = createDioClient(ref.read(authProvider).token);
                await dio.patch('/inventory/$id/adjust', data: {
                  'delta': delta,
                  'reason': reasonCtrl.text.isEmpty ? 'Admin adjustment' : reasonCtrl.text,
                }, options: Options(headers: {'Idempotency-Key': 'adj-$id-${DateTime.now().millisecondsSinceEpoch}'}));
                ref.invalidate(_inventoryAdminProvider);
              } catch (e) {
                if (context.mounted) _showError(context, '$e');
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
        branchesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator(color: copperAccent)),
          error: (e, _) => Center(child: _ErrorText('$e')),
          data: (branches) => ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            itemCount: branches.length,
            itemBuilder: (_, i) => _BranchCard(branch: branches[i]),
          ),
        ),
        Positioned(
          bottom: 16,
          right: 16,
          child: FloatingActionButton.extended(
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
    final nameCtrl = TextEditingController();
    final slugCtrl = TextEditingController();
    final addrCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      backgroundColor: slateCard,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Add Branch', style: TextStyle(color: textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          _InputField(ctrl: nameCtrl, label: 'Branch Name'),
          const SizedBox(height: 10),
          _InputField(ctrl: slugCtrl, label: 'Slug (e.g. main-branch)'),
          const SizedBox(height: 10),
          _InputField(ctrl: addrCtrl, label: 'Address'),
          const SizedBox(height: 16),
          _PrimaryButton(
            label: 'Create Branch',
            onTap: () async {
              Navigator.pop(ctx);
              try {
                final dio = createDioClient(ref.read(authProvider).token);
                await dio.post('/branches', data: {
                  'name': nameCtrl.text.trim(),
                  'slug': slugCtrl.text.trim(),
                  'address': addrCtrl.text.trim(),
                }, options: Options(headers: {'Idempotency-Key': 'create-branch-${slugCtrl.text.trim()}-${DateTime.now().millisecondsSinceEpoch}'}));
                ref.invalidate(_branchesProvider);
              } catch (e) {
                if (context.mounted) _showError(context, '$e');
              }
            },
          ),
        ]),
      ),
    );
  }
}

class _BranchCard extends ConsumerWidget {
  final Map<String, dynamic> branch;
  const _BranchCard({required this.branch});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final features = Map<String, dynamic>.from(branch['features'] ?? {});
    final id = branch['_id'] as String? ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: slateCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: dividerColor),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(branch['name'] ?? '',
              style: const TextStyle(color: textPrimary, fontSize: 14, fontWeight: FontWeight.w700))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: emerald.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
            child: Text(branch['slug'] ?? '',
                style: const TextStyle(color: emerald, fontSize: 10, fontWeight: FontWeight.w600)),
          ),
        ]),
        const SizedBox(height: 4),
        Text(branch['address'] ?? '', style: const TextStyle(color: textSecondary, fontSize: 12)),
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

  Future<void> _toggleFeature(BuildContext context, WidgetRef ref, String branchId, String feature, bool value) async {
    try {
      final dio = createDioClient(ref.read(authProvider).token);
      await dio.patch('/branches/$branchId/features', data: {feature: value},
          options: Options(headers: {'Idempotency-Key': 'feat-$branchId-$feature-${DateTime.now().millisecondsSinceEpoch}'}));
      ref.invalidate(_branchesProvider);
    } catch (e) {
      if (context.mounted) _showError(context, '$e');
    }
  }
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
            children: const [
              _SystemHealthTab(),
              _AuditLogTab(),
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
      error: (e, _) => Center(child: _ErrorText('$e')),
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
        ],
      ),
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
    final auditAsync = ref.watch(_auditLogProvider);

    return auditAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: copperAccent)),
      error: (e, _) => Center(child: _ErrorText('$e')),
      data: (entries) => entries.isEmpty
          ? const Center(child: Text('No audit entries', style: TextStyle(color: textSecondary)))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: entries.length,
              itemBuilder: (_, i) => _AuditEntry(entry: entries[i]),
            ),
    );
  }
}

class _AuditEntry extends StatelessWidget {
  final Map<String, dynamic> entry;
  const _AuditEntry({required this.entry});

  static const _actionColors = {
    'FORCE_CLOSED': crimson,
    'DISCOUNT_APPLIED': amber,
    'REFUND': crimson,
    'BILL_EDITED': roseGold,
    'STATUS_UPDATED': copperAccent,
  };

  @override
  Widget build(BuildContext context) {
    final action = entry['action'] as String? ?? '';
    final color = _actionColors[action] ?? textSecondary;
    final at = entry['at'] != null ? DateTime.tryParse(entry['at']) : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: slateCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: dividerColor),
      ),
      child: Row(children: [
        Container(
          width: 4, height: 36,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(action, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700)),
          Text('Table ${entry['tableLabel'] ?? ''} · by ${entry['by'] ?? 'system'}',
              style: const TextStyle(color: textSecondary, fontSize: 11)),
        ])),
        if (at != null)
          Text(DateFormat('dd MMM HH:mm').format(at),
              style: const TextStyle(color: textSecondary, fontSize: 10)),
      ]),
    );
  }
}

// ── Menu Management ───────────────────────────────────────────────────────────

class _MenuManagementTab extends ConsumerWidget {
  const _MenuManagementTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final menuAsync = ref.watch(_menuProvider);

    return menuAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: copperAccent)),
      error: (e, _) => Center(child: _ErrorText('$e')),
      data: (items) => ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: items.length,
        itemBuilder: (_, i) => _MenuItemCard(item: items[i]),
      ),
    );
  }
}

class _MenuItemCard extends ConsumerWidget {
  final Map<String, dynamic> item;
  const _MenuItemCard({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAvailable = item['isAvailable'] as bool? ?? true;
    final price = (item['basePrice'] as num?)?.toDouble() ?? 0;
    final id = item['_id'] as String? ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: slateCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isAvailable ? dividerColor : crimson.withValues(alpha: 0.3)),
      ),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(item['name'] ?? '', style: const TextStyle(color: textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
          Text(item['category'] ?? '', style: const TextStyle(color: textSecondary, fontSize: 11)),
        ])),
        Text('₹${price.toStringAsFixed(0)}',
            style: const TextStyle(color: copperAccent, fontSize: 14, fontWeight: FontWeight.w800)),
        const SizedBox(width: 10),
        Switch(
          value: isAvailable,
          onChanged: (v) async {
            try {
              final dio = createDioClient(ref.read(authProvider).token);
              await dio.patch('/menu/$id', data: {'isAvailable': v},
                  options: Options(headers: {'Idempotency-Key': 'menu-toggle-$id-${DateTime.now().millisecondsSinceEpoch}'}));
              ref.invalidate(_menuProvider);
            } catch (e) {
              if (context.mounted) _showError(context, '$e');
            }
          },
          activeThumbColor: emerald,
          inactiveThumbColor: crimson,
          inactiveTrackColor: crimson.withValues(alpha: 0.2),
        ),
      ]),
    );
  }
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
  const _InputField({required this.ctrl, required this.label, this.obscure = false, this.keyboardType});

  @override
  Widget build(BuildContext context) => TextField(
        controller: ctrl,
        obscureText: obscure,
        keyboardType: keyboardType,
        style: const TextStyle(color: textPrimary),
        decoration: _inputDec(label),
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
            gradient: const LinearGradient(colors: [copperAccent, Color(0xFFE8722A)]),
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
