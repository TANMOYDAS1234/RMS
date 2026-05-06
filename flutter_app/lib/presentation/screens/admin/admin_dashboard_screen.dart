// ─── Admin Dashboard - Control + Visibility + Governance ─────────────────────

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/app_theme.dart';
import '../../widgets/metrics_ribbon.dart';
import '../../state/order_providers.dart';

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metrics = ref.watch(dashboardMetricsProvider);
    
    return Scaffold(
      backgroundColor: slateBg,
      body: RefreshIndicator(
        color: copperAccent,
        backgroundColor: slateCard,
        onRefresh: () => ref.read(dashboardMetricsProvider.notifier).refresh(),
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: MetricsRibbon(
                activeOrders: metrics.activeOrders,
                occupiedTables: metrics.occupiedTables,
                totalTables: metrics.totalTables,
                revenue: metrics.revenue,
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.2,
                ),
                delegate: SliverChildListDelegate([
                  _AdminCard(
                    title: 'Live Orders',
                    subtitle: '${metrics.activeOrders} active',
                    icon: Icons.receipt_long,
                    color: copperAccent,
                    onTap: () => _showOrderPipeline(context, ref),
                  ),
                  _AdminCard(
                    title: 'Analytics',
                    subtitle: 'Sales & Revenue',
                    icon: Icons.analytics,
                    color: emerald,
                    onTap: () => Navigator.pushNamed(context, '/admin/analytics'),
                  ),
                  _AdminCard(
                    title: 'Staff',
                    subtitle: 'Manage Users',
                    icon: Icons.people,
                    color: azure,
                    onTap: () => Navigator.pushNamed(context, '/admin/staff'),
                  ),
                  _AdminCard(
                    title: 'Menu',
                    subtitle: 'Items & Pricing',
                    icon: Icons.restaurant_menu,
                    color: amber,
                    onTap: () => Navigator.pushNamed(context, '/admin/menu'),
                  ),
                  _AdminCard(
                    title: 'Inventory',
                    subtitle: 'Stock Levels',
                    icon: Icons.inventory_2,
                    color: violet,
                    onTap: () => Navigator.pushNamed(context, '/admin/inventory'),
                  ),
                  _AdminCard(
                    title: 'Financial',
                    subtitle: 'Transactions',
                    icon: Icons.account_balance,
                    color: roseGold,
                    onTap: () => Navigator.pushNamed(context, '/admin/financial'),
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showOrderPipeline(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: slateCard,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const _OrderPipelineSheet(),
    );
  }
}

class _AdminCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _AdminCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: slateCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: slateBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const Spacer(),
            Text(
              title,
              style: const TextStyle(
                color: textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: const TextStyle(
                color: textSecondary,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrderPipelineSheet extends ConsumerWidget {
  const _OrderPipelineSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orders = ref.watch(liveOrdersProvider);
    
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Order Pipeline',
            style: TextStyle(
              color: textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              itemCount: orders.length,
              itemBuilder: (context, index) {
                final order = orders[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: slateSurface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Text(
                        '#${order.id}',
                        style: const TextStyle(
                          color: textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        order.tableLabel,
                        style: const TextStyle(color: textSecondary),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: copperAccent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          order.status.label,
                          style: const TextStyle(
                            color: copperAccent,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}