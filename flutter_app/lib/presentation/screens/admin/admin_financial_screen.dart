// ─── Financial Oversight - Transactions, EOD Summary, Refunds, Audit Log ────

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/app_theme.dart';

class AdminFinancialScreen extends ConsumerWidget {
  const AdminFinancialScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: slateBg,
        appBar: AppBar(
          backgroundColor: slateBg,
          title: const Text('Financial Oversight', style: TextStyle(color: textPrimary, fontWeight: FontWeight.w700)),
          iconTheme: const IconThemeData(color: textPrimary),
          bottom: const TabBar(
            labelColor: copperAccent,
            unselectedLabelColor: textSecondary,
            indicatorColor: copperAccent,
            tabs: [
              Tab(text: 'Transactions'),
              Tab(text: 'EOD Summary'),
              Tab(text: 'Audit Log'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _TransactionsTab(),
            _EODSummaryTab(),
            _AuditLogTab(),
          ],
        ),
      ),
    );
  }
}

class _TransactionsTab extends StatelessWidget {
  const _TransactionsTab();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildTransactionStats(),
        _buildDateFilter(),
        Expanded(child: _buildTransactionsList()),
      ],
    );
  }

  Widget _buildTransactionStats() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          _StatCard('Total', '₹24,580', emerald),
          const SizedBox(width: 12),
          _StatCard('Cash', '₹8,240', azure),
          const SizedBox(width: 12),
          _StatCard('Card/UPI', '₹16,340', violet),
        ],
      ),
    );
  }

  Widget _buildDateFilter() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          const Text(
            'Today\'s Transactions',
            style: TextStyle(
              color: textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.filter_list, color: textSecondary),
            onPressed: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionsList() {
    final mockTransactions = [
      _Transaction('TXN001', '₹1,240', 'Card', DateTime.now().subtract(const Duration(minutes: 15)), 'Order #127'),
      _Transaction('TXN002', '₹680', 'Cash', DateTime.now().subtract(const Duration(minutes: 32)), 'Order #126'),
      _Transaction('TXN003', '₹2,150', 'UPI', DateTime.now().subtract(const Duration(hours: 1)), 'Order #125'),
      _Transaction('TXN004', '-₹320', 'Refund', DateTime.now().subtract(const Duration(hours: 2)), 'Order #124'),
    ];

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: mockTransactions.length,
      itemBuilder: (context, index) {
        final transaction = mockTransactions[index];
        return _TransactionCard(transaction: transaction);
      },
    );
  }
}

class _EODSummaryTab extends StatelessWidget {
  const _EODSummaryTab();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildEODHeader(),
          const SizedBox(height: 20),
          _buildRevenueBreakdown(),
          const SizedBox(height: 20),
          _buildPaymentMethods(),
          const SizedBox(height: 20),
          _buildExpensesSummary(),
        ],
      ),
    );
  }

  Widget _buildEODHeader() {
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
            'End of Day Summary',
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
          Text(
            'December 15, 2024',
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildRevenueBreakdown() {
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
            'Revenue Breakdown',
            style: TextStyle(
              color: textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          _RevenueItem('Food Sales', '₹20,480', 0.83),
          _RevenueItem('Beverages', '₹3,240', 0.13),
          _RevenueItem('Service Charge', '₹860', 0.04),
        ],
      ),
    );
  }

  Widget _buildPaymentMethods() {
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
            'Payment Methods',
            style: TextStyle(
              color: textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          _PaymentMethodItem('Cash', '₹8,240', azure),
          _PaymentMethodItem('Card', '₹10,180', emerald),
          _PaymentMethodItem('UPI', '₹6,160', violet),
        ],
      ),
    );
  }

  Widget _buildExpensesSummary() {
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
            'Expenses',
            style: TextStyle(
              color: textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          _ExpenseItem('Ingredients', '₹6,240'),
          _ExpenseItem('Staff Wages', '₹4,800'),
          _ExpenseItem('Utilities', '₹1,200'),
          _ExpenseItem('Other', '₹800'),
          const Divider(color: slateBorder),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Net Profit',
                style: TextStyle(
                  color: textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                '₹11,540',
                style: const TextStyle(
                  color: emerald,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AuditLogTab extends StatelessWidget {
  const _AuditLogTab();

  @override
  Widget build(BuildContext context) {
    final mockAuditLogs = [
      _AuditLog('Order Cancelled', 'Sarah Wilson', 'Order #127 cancelled by waiter', DateTime.now().subtract(const Duration(minutes: 5))),
      _AuditLog('Discount Applied', 'John Doe', '10% discount applied to Order #126', DateTime.now().subtract(const Duration(minutes: 15))),
      _AuditLog('Menu Item Modified', 'Admin', 'Butter Chicken price updated to ₹320', DateTime.now().subtract(const Duration(hours: 1))),
      _AuditLog('Staff Added', 'Admin', 'New waiter Lisa Brown added', DateTime.now().subtract(const Duration(hours: 2))),
    ];

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: mockAuditLogs.length,
      itemBuilder: (context, index) {
        final log = mockAuditLogs[index];
        return _AuditLogCard(log: log);
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final Color color;

  const _StatCard(this.title, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: slateCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: slateBorder),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: const TextStyle(color: textSecondary, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _TransactionCard extends StatelessWidget {
  final _Transaction transaction;

  const _TransactionCard({required this.transaction});

  @override
  Widget build(BuildContext context) {
    final isRefund = transaction.amount.startsWith('-');
    final color = isRefund ? crimson : emerald;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: slateCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: slateBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isRefund ? Icons.undo : Icons.payment,
              color: color,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction.id,
                  style: const TextStyle(
                    color: textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  transaction.description,
                  style: const TextStyle(color: textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                transaction.amount,
                style: TextStyle(
                  color: color,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                transaction.method,
                style: const TextStyle(color: textSecondary, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RevenueItem extends StatelessWidget {
  final String title;
  final String amount;
  final double percentage;

  const _RevenueItem(this.title, this.amount, this.percentage);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(color: textPrimary, fontSize: 14),
            ),
          ),
          Text(
            amount,
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

class _PaymentMethodItem extends StatelessWidget {
  final String method;
  final String amount;
  final Color color;

  const _PaymentMethodItem(this.method, this.amount, this.color);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              method,
              style: const TextStyle(color: textPrimary, fontSize: 14),
            ),
          ),
          Text(
            amount,
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ExpenseItem extends StatelessWidget {
  final String title;
  final String amount;

  const _ExpenseItem(this.title, this.amount);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(color: textSecondary, fontSize: 14),
          ),
          Text(
            amount,
            style: const TextStyle(color: textPrimary, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

class _AuditLogCard extends StatelessWidget {
  final _AuditLog log;

  const _AuditLogCard({required this.log});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: slateCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: slateBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                log.action,
                style: const TextStyle(
                  color: textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                _formatTime(log.timestamp),
                style: const TextStyle(color: textSecondary, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            log.description,
            style: const TextStyle(color: textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 4),
          Text(
            'by ${log.user}',
            style: const TextStyle(color: copperAccent, fontSize: 11),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else {
      return '${diff.inDays}d ago';
    }
  }
}

class _Transaction {
  final String id;
  final String amount;
  final String method;
  final DateTime timestamp;
  final String description;

  _Transaction(this.id, this.amount, this.method, this.timestamp, this.description);
}

class _AuditLog {
  final String action;
  final String user;
  final String description;
  final DateTime timestamp;

  _AuditLog(this.action, this.user, this.description, this.timestamp);
}