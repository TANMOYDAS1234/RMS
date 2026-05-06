// ─── Analytics Screen - Sales, Revenue, Peak Hours, Profit Margin ────────────

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/app_theme.dart';

class AdminAnalyticsScreen extends ConsumerWidget {
  const AdminAnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: slateBg,
      appBar: AppBar(
        backgroundColor: slateBg,
        title: const Text('Analytics', style: TextStyle(color: textPrimary, fontWeight: FontWeight.w700)),
        iconTheme: const IconThemeData(color: textPrimary),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTimeFilter(),
            const SizedBox(height: 20),
            _buildRevenueCard(),
            const SizedBox(height: 16),
            _buildMetricsGrid(),
            const SizedBox(height: 16),
            _buildPeakHoursCard(),
            const SizedBox(height: 16),
            _buildTopItemsCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeFilter() {
    return Row(
      children: [
        _FilterChip('Today', true),
        _FilterChip('Week', false),
        _FilterChip('Month', false),
        _FilterChip('Year', false),
      ],
    );
  }

  Widget _buildRevenueCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [copperAccent, roseGold],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Total Revenue',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 8),
          const Text(
            '₹24,580',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.trending_up, color: Colors.white70, size: 16),
              const SizedBox(width: 4),
              const Text(
                '+12.5% from yesterday',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsGrid() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: [
        _MetricCard('Orders', '127', '+8%', emerald),
        _MetricCard('Avg Order', '₹193', '+5%', azure),
        _MetricCard('Profit Margin', '32%', '+2%', violet),
        _MetricCard('Table Turns', '4.2', '+1%', amber),
      ],
    );
  }

  Widget _buildPeakHoursCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: slateCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: slateBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Peak Hours',
            style: TextStyle(
              color: textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          _PeakHourBar('12:00 PM', 0.9),
          _PeakHourBar('1:00 PM', 1.0),
          _PeakHourBar('7:00 PM', 0.8),
          _PeakHourBar('8:00 PM', 0.7),
        ],
      ),
    );
  }

  Widget _buildTopItemsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: slateCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: slateBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Top Selling Items',
            style: TextStyle(
              color: textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          _TopItem('Butter Chicken', '₹2,340', '24 orders'),
          _TopItem('Paneer Tikka', '₹1,890', '18 orders'),
          _TopItem('Dal Makhani', '₹1,560', '26 orders'),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;

  const _FilterChip(this.label, this.selected);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: selected ? copperAccent.withValues(alpha: 0.2) : slateSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: selected ? copperAccent : Colors.transparent,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: selected ? copperAccent : textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final String change;
  final Color color;

  const _MetricCard(this.title, this.value, this.change, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: slateCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: slateBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(color: textSecondary, fontSize: 12),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            change,
            style: const TextStyle(color: emerald, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _PeakHourBar extends StatelessWidget {
  final String time;
  final double intensity;

  const _PeakHourBar(this.time, this.intensity);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          SizedBox(
            width: 60,
            child: Text(
              time,
              style: const TextStyle(color: textSecondary, fontSize: 12),
            ),
          ),
          Expanded(
            child: Container(
              height: 8,
              decoration: BoxDecoration(
                color: slateSurface,
                borderRadius: BorderRadius.circular(4),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: intensity,
                child: Container(
                  decoration: BoxDecoration(
                    color: copperAccent,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TopItem extends StatelessWidget {
  final String name;
  final String revenue;
  final String orders;

  const _TopItem(this.name, this.revenue, this.orders);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  orders,
                  style: const TextStyle(color: textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          Text(
            revenue,
            style: const TextStyle(
              color: copperAccent,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}