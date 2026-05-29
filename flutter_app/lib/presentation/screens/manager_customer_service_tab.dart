// ─── Manager: Customer Service Tab ───────────────────────────────────────────
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/config/app_theme.dart';
import '../../core/network/dio_client.dart';
import '../../core/utils/api_error.dart';
import '../../core/utils/idempotency.dart';
import '../state/auth_provider.dart';

// ── Providers ─────────────────────────────────────────────────────────────────
final _complaintsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final token = ref.watch(authProvider).token;
  final dio = createDioClient(token);
  final res = await dio.get('/manager/complaints');
  return List<Map<String, dynamic>>.from(res.data);
});

// ── Issue categories ──────────────────────────────────────────────────────────
const _categories = [
  'Food Quality',
  'Long Wait',
  'Wrong Order',
  'Staff Behaviour',
  'Billing Issue',
  'Cleanliness',
  'Other',
];

const _categoryIcons = {
  'Food Quality':    Icons.restaurant_outlined,
  'Long Wait':       Icons.timer_outlined,
  'Wrong Order':     Icons.swap_horiz_outlined,
  'Staff Behaviour': Icons.person_outline,
  'Billing Issue':   Icons.receipt_outlined,
  'Cleanliness':     Icons.cleaning_services_outlined,
  'Other':           Icons.more_horiz_outlined,
};

const _categoryColors = {
  'Food Quality':    crimson,
  'Long Wait':       amber,
  'Wrong Order':     roseGold,
  'Staff Behaviour': copperAccent,
  'Billing Issue':   Colors.blue,
  'Cleanliness':     emerald,
  'Other':           textSecondary,
};

// ── Tab ───────────────────────────────────────────────────────────────────────
class ManagerCustomerServiceTab extends ConsumerStatefulWidget {
  const ManagerCustomerServiceTab({super.key});

  @override
  ConsumerState<ManagerCustomerServiceTab> createState() =>
      _ManagerCustomerServiceTabState();
}

class _ManagerCustomerServiceTabState
    extends ConsumerState<ManagerCustomerServiceTab>
    with SingleTickerProviderStateMixin {
  late TabController _tc;

  @override
  void initState() {
    super.initState();
    _tc = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Container(
        color: slateCard,
        child: TabBar(
          controller: _tc,
          indicatorColor: copperAccent,
          labelColor: copperAccent,
          unselectedLabelColor: textSecondary,
          labelStyle:
              const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          tabs: const [
            Tab(text: 'Log Complaint'),
            Tab(text: 'History'),
          ],
        ),
      ),
      Expanded(
        child: TabBarView(
          controller: _tc,
          children: [
            _LogComplaintTab(onLogged: () => _tc.animateTo(1)),
            const _ComplaintHistoryTab(),
          ],
        ),
      ),
    ]);
  }
}

// ── Log complaint tab ─────────────────────────────────────────────────────────
class _LogComplaintTab extends ConsumerStatefulWidget {
  final VoidCallback onLogged;
  const _LogComplaintTab({required this.onLogged});

  @override
  ConsumerState<_LogComplaintTab> createState() => _LogComplaintTabState();
}

class _LogComplaintTabState extends ConsumerState<_LogComplaintTab> {
  final _tableLabelCtrl = TextEditingController();
  final _detailCtrl     = TextEditingController();
  String _selectedCategory = 'Food Quality';
  String _severity = 'medium'; // low | medium | high
  bool _submitting = false;

  @override
  void dispose() {
    _tableLabelCtrl.dispose();
    _detailCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Info banner ──────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: copperAccent.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: copperAccent.withValues(alpha: 0.2)),
          ),
          child: const Row(children: [
            Icon(Icons.info_outline, color: copperAccent, size: 16),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Log customer complaints to track service quality and identify recurring issues.',
                style: TextStyle(color: textSecondary, fontSize: 12),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 20),

        // ── Table label ──────────────────────────────────────────────────
        const _Label('Table / Customer'),
        const SizedBox(height: 6),
        _Field(
          ctrl: _tableLabelCtrl,
          hint: 'e.g. T-05 or Walk-in',
        ),
        const SizedBox(height: 16),

        // ── Category ─────────────────────────────────────────────────────
        const _Label('Issue Category'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _categories.map((cat) {
            final selected = _selectedCategory == cat;
            final color    = _categoryColors[cat] ?? textSecondary;
            final icon     = _categoryIcons[cat] ?? Icons.circle_outlined;
            return GestureDetector(
              onTap: () => setState(() => _selectedCategory = cat),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: selected
                      ? color.withValues(alpha: 0.15)
                      : slateSurface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: selected
                        ? color.withValues(alpha: 0.5)
                        : dividerColor,
                  ),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(icon,
                      size: 14,
                      color: selected ? color : textSecondary),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(cat,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: selected ? color : textSecondary,
                            fontSize: 12,
                            fontWeight: selected
                                ? FontWeight.w700
                                : FontWeight.w500)),
                  ),
                ]),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),

        // ── Severity ─────────────────────────────────────────────────────
        const _Label('Severity'),
        const SizedBox(height: 8),
        Row(children: [
          _SeverityChip('Low', 'low', _severity, emerald,
              (v) => setState(() => _severity = v)),
          const SizedBox(width: 8),
          _SeverityChip('Medium', 'medium', _severity, amber,
              (v) => setState(() => _severity = v)),
          const SizedBox(width: 8),
          _SeverityChip('High', 'high', _severity, crimson,
              (v) => setState(() => _severity = v)),
        ]),
        const SizedBox(height: 16),

        // ── Details ──────────────────────────────────────────────────────
        const _Label('Details'),
        const SizedBox(height: 6),
        TextField(
          controller: _detailCtrl,
          maxLines: 4,
          style: const TextStyle(color: textPrimary, fontSize: 13),
          decoration: InputDecoration(
            hintText: 'Describe the issue in detail...',
            hintStyle:
                const TextStyle(color: textSecondary, fontSize: 12),
            filled: true,
            fillColor: slateCard,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: dividerColor)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: dividerColor)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: copperAccent)),
          ),
        ),
        const SizedBox(height: 24),

        // ── Submit ───────────────────────────────────────────────────────
        GestureDetector(
          onTap: _submitting ? null : _submit,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [copperAccent, Color(0xFFE8722A)]),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: _submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Text('Log Complaint',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 14)),
            ),
          ),
        ),
      ]),
    );
  }

  Future<void> _submit() async {
    final table = _tableLabelCtrl.text.trim();
    final detail = _detailCtrl.text.trim();
    if (table.isEmpty || detail.isEmpty) {
      _snack(context, 'Fill in table and details', amber);
      return;
    }
    setState(() => _submitting = true);
    try {
      final dio = createDioClient(ref.read(authProvider).token);
      await dio.post(
        '/manager/complaints',
        data: {
          'tableLabel': table,
          'issue': detail,
          'category': _selectedCategory,
          'severity': _severity,
        },
        options: Options(headers: {
          'Idempotency-Key': newIdempotencyKey('complaint-$table'),
        }),
      );
      ref.invalidate(_complaintsProvider);
      _tableLabelCtrl.clear();
      _detailCtrl.clear();
      setState(() {
        _selectedCategory = 'Food Quality';
        _severity = 'medium';
      });
      if (mounted) {
        _snack(context, 'Complaint logged', emerald);
        widget.onLogged();
      }
    } catch (e) {
      if (mounted) _snack(context, describeApiError(e), crimson);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}

// ── Complaint history tab ─────────────────────────────────────────────────────
class _ComplaintHistoryTab extends ConsumerWidget {
  const _ComplaintHistoryTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final complaintsAsync = ref.watch(_complaintsProvider);

    return RefreshIndicator(
      color: copperAccent,
      backgroundColor: slateCard,
      onRefresh: () async => ref.invalidate(_complaintsProvider),
      child: complaintsAsync.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: copperAccent)),
        error: (e, _) => Center(
            child: Text('$e',
                style: const TextStyle(color: crimson, fontSize: 13))),
        data: (complaints) {
          if (complaints.isEmpty) {
            return const _EmptyState();
          }

          // Group by category for summary
          final catCounts = <String, int>{};
          for (final c in complaints) {
            final issue = c['issue'] as String? ?? '';
            for (final cat in _categories) {
              if (issue.contains(cat)) {
                catCounts[cat] = (catCounts[cat] ?? 0) + 1;
                break;
              }
            }
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            children: [
              // Summary
              _ComplaintSummary(
                  total: complaints.length, catCounts: catCounts),
              const SizedBox(height: 16),

              // List
              ...complaints.map((c) => _ComplaintCard(complaint: c)),
            ],
          );
        },
      ),
    );
  }
}

// ── Complaint summary ─────────────────────────────────────────────────────────
class _ComplaintSummary extends StatelessWidget {
  final int total;
  final Map<String, int> catCounts;
  const _ComplaintSummary(
      {required this.total, required this.catCounts});

  @override
  Widget build(BuildContext context) {
    final sorted = catCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = sorted.take(3).toList();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: slateCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: dividerColor),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.bar_chart_outlined,
              color: copperAccent, size: 16),
          const SizedBox(width: 6),
          Text('$total complaint${total != 1 ? 's' : ''} logged',
              style: const TextStyle(
                  color: textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700)),
        ]),
        if (top.isNotEmpty) ...[
          const SizedBox(height: 10),
          const Text('Top issues:',
              style: TextStyle(color: textSecondary, fontSize: 11)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: top.map((e) {
              final color = _categoryColors[e.key] ?? textSecondary;
              return Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border:
                      Border.all(color: color.withValues(alpha: 0.3)),
                ),
                child: Text('${e.key} (${e.value})',
                    style: TextStyle(
                        color: color,
                        fontSize: 11,
                        fontWeight: FontWeight.w600)),
              );
            }).toList(),
          ),
        ],
      ]),
    );
  }
}

// ── Complaint card ────────────────────────────────────────────────────────────
class _ComplaintCard extends ConsumerWidget {
  final Map<String, dynamic> complaint;
  const _ComplaintCard({required this.complaint});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tableLabel = complaint['tableLabel'] as String? ?? '';
    final issue      = complaint['issue'] as String? ?? '';
    final at         = complaint['at'] != null
        ? DateTime.tryParse(complaint['at'].toString())
        : null;
    final orderId     = complaint['orderId']?.toString();
    final complaintId = complaint['complaintId']?.toString();
    final resolved    = complaint['resolved'] as bool? ?? false;

    // Prefer the structured fields from the new backend; fall back to
    // string-prefix parsing for entries logged before the schema change.
    String category;
    Color catColor;
    String severity;
    Color sevColor;
    String cleanIssue = issue;

    final structuredCat = complaint['category'] as String?;
    if (structuredCat != null && structuredCat.isNotEmpty && structuredCat != 'general') {
      category = structuredCat;
      catColor = _categoryColors[structuredCat] ?? textSecondary;
    } else {
      category = 'Other';
      catColor = textSecondary;
      for (final cat in _categories) {
        if (issue.contains(cat)) {
          category = cat;
          catColor = _categoryColors[cat] ?? textSecondary;
          break;
        }
      }
    }

    final structuredSev = complaint['severity'] as String?;
    if (structuredSev != null && structuredSev.isNotEmpty) {
      severity = structuredSev.toUpperCase();
      sevColor = switch (structuredSev.toLowerCase()) {
        'high' => crimson,
        'low'  => emerald,
        _      => amber,
      };
    } else if (issue.contains('HIGH')) {
      severity = 'HIGH';
      sevColor = crimson;
    } else if (issue.contains('LOW')) {
      severity = 'LOW';
      sevColor = emerald;
    } else {
      severity = 'MEDIUM';
      sevColor = amber;
    }

    if (structuredCat == null) {
      cleanIssue = issue.replaceAll(RegExp(r'\[.*?\]\s*'), '');
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: slateCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: resolved
                ? emerald.withValues(alpha: 0.3)
                : catColor.withValues(alpha: 0.2)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(_categoryIcons[category] ?? Icons.circle_outlined,
              color: catColor, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(tableLabel,
                style: const TextStyle(
                    color: textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700),
                overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(width: 6),
          if (resolved)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: emerald.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text('RESOLVED',
                  style: TextStyle(
                      color: emerald,
                      fontSize: 9,
                      fontWeight: FontWeight.w700)),
            )
          else
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: sevColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(severity,
                    style: TextStyle(
                        color: sevColor,
                        fontSize: 9,
                        fontWeight: FontWeight.w700)),
              ),
              const SizedBox(height: 3),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: catColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(category,
                    style: TextStyle(
                        color: catColor,
                        fontSize: 9,
                        fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis),
              ),
            ]),
        ]),
        const SizedBox(height: 8),
        Text(cleanIssue.isEmpty ? issue : cleanIssue,
            style: const TextStyle(color: textSecondary, fontSize: 12)),
        if (at != null) ...[
          const SizedBox(height: 6),
          Row(children: [
            const Icon(Icons.access_time_outlined,
                size: 11, color: textSecondary),
            const SizedBox(width: 4),
            Text(DateFormat('dd MMM, HH:mm').format(at),
                style: const TextStyle(
                    color: textSecondary, fontSize: 10)),
          ]),
        ],
        if (!resolved && orderId != null && complaintId != null) ...[
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTap: () =>
                  _openResolveSheet(context, ref, orderId, complaintId, tableLabel),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: emerald.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: emerald.withValues(alpha: 0.3)),
                ),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.check_circle_outline, color: emerald, size: 13),
                  SizedBox(width: 5),
                  Text('Mark Resolved',
                      style: TextStyle(
                          color: emerald,
                          fontSize: 11,
                          fontWeight: FontWeight.w700)),
                ]),
              ),
            ),
          ),
        ],
      ]),
    ).animate().fadeIn(duration: 250.ms);
  }

  void _openResolveSheet(BuildContext context, WidgetRef ref, String orderId,
      String complaintId, String tableLabel) {
    showModalBottomSheet(
      context: context,
      backgroundColor: slateCard,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _ResolveComplaintSheet(
        orderId: orderId,
        complaintId: complaintId,
        tableLabel: tableLabel,
      ),
    );
  }
}

class _ResolveComplaintSheet extends ConsumerStatefulWidget {
  final String orderId;
  final String complaintId;
  final String tableLabel;
  const _ResolveComplaintSheet({
    required this.orderId,
    required this.complaintId,
    required this.tableLabel,
  });

  @override
  ConsumerState<_ResolveComplaintSheet> createState() =>
      _ResolveComplaintSheetState();
}

class _ResolveComplaintSheetState
    extends ConsumerState<_ResolveComplaintSheet> {
  late final TextEditingController _ctrl;
  late final String _idempotencyKey;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController();
    _idempotencyKey =
        newIdempotencyKey('resolve-complaint-${widget.complaintId}');
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final resolution = _ctrl.text.trim();
    if (resolution.isEmpty) return;
    setState(() => _submitting = true);
    try {
      final dio = createDioClient(ref.read(authProvider).token);
      await dio.patch(
        '/manager/complaints/resolve',
        data: {
          'orderId': widget.orderId,
          'complaintId': widget.complaintId,
          'resolution': resolution,
        },
        options: Options(headers: {'Idempotency-Key': _idempotencyKey}),
      );
      ref.invalidate(_complaintsProvider);
      if (mounted) {
        Navigator.pop(context);
        _snack(context, 'Complaint resolved', emerald);
      }
    } catch (e) {
      if (mounted) _snack(context, describeApiError(e), crimson);
    } finally {
      if (mounted) setState(() => _submitting = false);
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
              Text('Resolve Complaint — ${widget.tableLabel}',
                  style: const TextStyle(
                      color: textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              TextField(
                controller: _ctrl,
                maxLines: 3,
                style: const TextStyle(color: textPrimary),
                decoration: InputDecoration(
                  hintText: 'How was this resolved? (e.g. comped meal, replaced dish)',
                  hintStyle:
                      const TextStyle(color: textSecondary, fontSize: 12),
                  filled: true,
                  fillColor: slateSurface,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: dividerColor)),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: dividerColor)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: emerald)),
                ),
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: _submitting ? null : _submit,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [emerald, Color(0xFF26997C)]),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                        _submitting ? 'Saving…' : 'Mark Resolved',
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 14)),
                  ),
                ),
              ),
            ]),
      );
}

// ── Severity chip ─────────────────────────────────────────────────────────────
class _SeverityChip extends StatelessWidget {
  final String label;
  final String value;
  final String selected;
  final Color color;
  final ValueChanged<String> onTap;
  const _SeverityChip(
      this.label, this.value, this.selected, this.color, this.onTap);

  @override
  Widget build(BuildContext context) {
    final isSelected = selected == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? color.withValues(alpha: 0.15) : slateSurface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? color.withValues(alpha: 0.5) : dividerColor,
            ),
          ),
          child: Center(
            child: Text(label,
                style: TextStyle(
                    color: isSelected ? color : textSecondary,
                    fontSize: 12,
                    fontWeight: isSelected
                        ? FontWeight.w700
                        : FontWeight.w500)),
          ),
        ),
      ),
    );
  }
}

// ── Shared helpers ────────────────────────────────────────────────────────────
class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(
          color: textSecondary, fontSize: 12, fontWeight: FontWeight.w600));
}

class _Field extends StatelessWidget {
  final TextEditingController ctrl;
  final String hint;
  const _Field({required this.ctrl, required this.hint});

  @override
  Widget build(BuildContext context) => TextField(
        controller: ctrl,
        style: const TextStyle(color: textPrimary, fontSize: 13),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle:
              const TextStyle(color: textSecondary, fontSize: 12),
          filled: true,
          fillColor: slateCard,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: dividerColor)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: dividerColor)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: copperAccent)),
        ),
      );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.sentiment_satisfied_outlined,
              size: 56, color: emerald.withValues(alpha: 0.5)),
          const SizedBox(height: 16),
          const Text('No complaints logged',
              style: TextStyle(
                  color: textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          const Text('Great service! Keep it up.',
              style: TextStyle(color: textSecondary, fontSize: 12)),
        ]),
      );
}

void _snack(BuildContext context, String msg, Color color) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
    ));
