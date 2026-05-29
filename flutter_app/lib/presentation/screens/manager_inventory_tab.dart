// ─── Manager: Inventory Tab ───────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/config/app_theme.dart';
import '../../core/utils/api_error.dart';
import '../../core/utils/idempotency.dart';
import '../../data/api/manager_api.dart';

final _managerInventoryProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>(
        (ref) => ref.watch(managerApiProvider).inventoryStatus());

// ── Tab ───────────────────────────────────────────────────────────────────────
class ManagerInventoryTab extends ConsumerStatefulWidget {
  const ManagerInventoryTab({super.key});

  @override
  ConsumerState<ManagerInventoryTab> createState() =>
      _ManagerInventoryTabState();
}

class _ManagerInventoryTabState extends ConsumerState<ManagerInventoryTab> {
  String _filter = 'all'; // all | low | ok
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final invAsync = ref.watch(_managerInventoryProvider);

    return RefreshIndicator(
      color: copperAccent,
      backgroundColor: slateCard,
      onRefresh: () async => ref.invalidate(_managerInventoryProvider),
      child: invAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(color: copperAccent)),
        error: (e, _) => Center(
            child: Text('$e',
                style: const TextStyle(color: crimson, fontSize: 13))),
        data: (data) {
          final items =
              List<Map<String, dynamic>>.from(data['items'] ?? []);
          final lowCount = data['lowCount'] as int? ?? 0;

          // Apply filter + search
          final filtered = items.where((i) {
            final cur = (i['currentStock'] as num? ?? 0).toDouble();
            final thr = (i['lowStockThreshold'] as num? ?? 0).toDouble();
            final isLow = cur <= thr;
            final matchFilter = _filter == 'all' ||
                (_filter == 'low' && isLow) ||
                (_filter == 'ok' && !isLow);
            final matchSearch = _search.isEmpty ||
                (i['name'] as String? ?? '')
                    .toLowerCase()
                    .contains(_search.toLowerCase());
            return matchFilter && matchSearch;
          }).toList();

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            children: [
              // ── Summary ────────────────────────────────────────────────
              _SummaryRow(
                total: items.length,
                low: lowCount,
                ok: items.length - lowCount,
              ),
              const SizedBox(height: 12),

              // ── Low stock alert banner ─────────────────────────────────
              if (lowCount > 0) ...[
                _LowStockBanner(count: lowCount),
                const SizedBox(height: 12),
              ],

              // ── Search bar ─────────────────────────────────────────────
              _SearchBar(
                onChanged: (v) => setState(() => _search = v),
              ),
              const SizedBox(height: 10),

              // ── Filter chips ───────────────────────────────────────────
              _FilterRow(
                selected: _filter,
                onSelect: (f) => setState(() => _filter = f),
              ),
              const SizedBox(height: 14),

              // ── Items ──────────────────────────────────────────────────
              if (filtered.isEmpty)
                const _EmptyState()
              else
                ...filtered.map((item) => _InventoryCard(
                      item: item,
                      onReportShortage: () =>
                          _showShortageSheet(context, item),
                    )),
            ],
          );
        },
      ),
    );
  }

  void _showShortageSheet(
      BuildContext context, Map<String, dynamic> item) {
    showModalBottomSheet(
      context: context,
      backgroundColor: slateCard,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _ShortageSheet(item: item),
    );
  }
}

class _ShortageSheet extends ConsumerStatefulWidget {
  final Map<String, dynamic> item;
  const _ShortageSheet({required this.item});
  @override
  ConsumerState<_ShortageSheet> createState() => _ShortageSheetState();
}

class _ShortageSheetState extends ConsumerState<_ShortageSheet> {
  late final TextEditingController _ctrl;
  late final String _idempotencyKey;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController();
    _idempotencyKey =
        newIdempotencyKey('shortage-${widget.item['_id']}');
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final note = _ctrl.text.trim();
    if (note.isEmpty) return;
    setState(() => _submitting = true);
    try {
      await ref.read(managerApiProvider).reportShortage(
            widget.item['_id'].toString(),
            note,
            idempotencyKey: _idempotencyKey,
          );
      ref.invalidate(_managerInventoryProvider);
      if (mounted) {
        Navigator.pop(context);
        _snack(context, 'Shortage reported to admin', emerald);
      }
    } catch (e) {
      if (mounted) _snack(context, describeApiError(e), crimson);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.item['name'] as String? ?? '';
    return Padding(
        padding: EdgeInsets.fromLTRB(
            24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
        child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Report Shortage — $name',
                  style: const TextStyle(
                      color: textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text(
                'Current: ${widget.item['currentStock']} ${widget.item['unit']} '
                '(min: ${widget.item['lowStockThreshold']} ${widget.item['unit']})',
                style: const TextStyle(color: textSecondary, fontSize: 12),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _ctrl,
                maxLines: 2,
                style: const TextStyle(color: textPrimary),
                decoration: InputDecoration(
                  hintText: 'Describe the shortage (e.g. supplier delayed)',
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
                      borderSide: const BorderSide(color: copperAccent)),
                ),
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: _submitting ? null : _submit,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    gradient: dangerGradient,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(_submitting ? 'Reporting…' : 'Report to Admin',
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 14)),
                  ),
                ),
              ),
            ]));
  }
}

// ── Summary row ───────────────────────────────────────────────────────────────
class _SummaryRow extends StatelessWidget {
  final int total;
  final int low;
  final int ok;
  const _SummaryRow(
      {required this.total, required this.low, required this.ok});

  @override
  Widget build(BuildContext context) => Row(children: [
        _Chip('Total', total, copperAccent),
        const SizedBox(width: 8),
        _Chip('Low Stock', low, low > 0 ? crimson : textSecondary),
        const SizedBox(width: 8),
        _Chip('OK', ok, emerald),
      ]);
}

class _Chip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  const _Chip(this.label, this.count, this.color);

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Column(children: [
            Text('$count',
                style: TextStyle(
                    color: color, fontSize: 18, fontWeight: FontWeight.w800)),
            Text(label,
                style: const TextStyle(color: textSecondary, fontSize: 10)),
          ]),
        ),
      );
}

// ── Low stock banner ──────────────────────────────────────────────────────────
class _LowStockBanner extends StatelessWidget {
  final int count;
  const _LowStockBanner({required this.count});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: crimson.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: crimson.withValues(alpha: 0.3)),
        ),
        child: Row(children: [
          const Icon(Icons.warning_amber_outlined, color: crimson, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$count item${count > 1 ? 's' : ''} below minimum threshold — report to admin',
              style: const TextStyle(
                  color: crimson, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ]),
      ).animate(onPlay: (c) => c.repeat(reverse: true))
          .fadeIn(duration: 900.ms).then().fadeOut(duration: 900.ms);
}

// ── Search bar ────────────────────────────────────────────────────────────────
class _SearchBar extends StatelessWidget {
  final ValueChanged<String> onChanged;
  const _SearchBar({required this.onChanged});

  @override
  Widget build(BuildContext context) => TextField(
        onChanged: onChanged,
        style: const TextStyle(color: textPrimary, fontSize: 13),
        decoration: InputDecoration(
          hintText: 'Search ingredients...',
          hintStyle: const TextStyle(color: textSecondary, fontSize: 13),
          prefixIcon:
              const Icon(Icons.search, color: textSecondary, size: 18),
          filled: true,
          fillColor: slateCard,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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

// ── Filter row ────────────────────────────────────────────────────────────────
class _FilterRow extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onSelect;
  const _FilterRow({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) => Row(children: [
        _FilterChip('All', 'all', selected, onSelect),
        const SizedBox(width: 8),
        _FilterChip('Low Stock', 'low', selected, onSelect),
        const SizedBox(width: 8),
        _FilterChip('OK', 'ok', selected, onSelect),
      ]);
}

class _FilterChip extends StatelessWidget {
  final String label;
  final String value;
  final String selected;
  final ValueChanged<String> onSelect;
  const _FilterChip(this.label, this.value, this.selected, this.onSelect);

  @override
  Widget build(BuildContext context) {
    final isSelected = selected == value;
    return GestureDetector(
      onTap: () => onSelect(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? copperAccent.withValues(alpha: 0.15)
              : slateSurface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? copperAccent : dividerColor,
          ),
        ),
        child: Text(label,
            style: TextStyle(
                color: isSelected ? copperAccent : textSecondary,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500)),
      ),
    );
  }
}

// ── Inventory card ────────────────────────────────────────────────────────────
class _InventoryCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback onReportShortage;
  const _InventoryCard(
      {required this.item, required this.onReportShortage});

  @override
  Widget build(BuildContext context) {
    final cur    = (item['currentStock'] as num? ?? 0).toDouble();
    final thr    = (item['lowStockThreshold'] as num? ?? 0).toDouble();
    final unit   = item['unit'] as String? ?? '';
    final name   = item['name'] as String? ?? '';
    final isLow  = cur <= thr;
    final progress =
        thr > 0 ? (cur / (thr * 3)).clamp(0.0, 1.0) : 1.0;
    final color  = isLow ? crimson : emerald;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: slateCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isLow ? crimson.withValues(alpha: 0.4) : dividerColor,
        ),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text(name,
                style: const TextStyle(
                    color: textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
          ),
          if (isLow) ...[
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: crimson.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text('LOW',
                  style: TextStyle(
                      color: crimson,
                      fontSize: 10,
                      fontWeight: FontWeight.w700)),
            ),
            const SizedBox(width: 8),
          ],
          // Report shortage button
          GestureDetector(
            onTap: onReportShortage,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: isLow
                    ? crimson.withValues(alpha: 0.1)
                    : slateSurface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isLow
                      ? crimson.withValues(alpha: 0.3)
                      : dividerColor,
                ),
              ),
              child: Icon(Icons.report_outlined,
                  color: isLow ? crimson : textSecondary, size: 16),
            ),
          ),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Text('$cur $unit',
              style: TextStyle(
                  color: color,
                  fontSize: 16,
                  fontWeight: FontWeight.w800)),
          const Spacer(),
          Text('Min: $thr $unit',
              style: const TextStyle(color: textSecondary, fontSize: 11)),
        ]),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: slateSurface,
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 5,
          ),
        ),
        // Shortage warning
        if (isLow) ...[
          const SizedBox(height: 8),
          Row(children: [
            const Icon(Icons.info_outline, color: crimson, size: 12),
            const SizedBox(width: 4),
            Text(
              '${(thr - cur).toStringAsFixed(1)} $unit below minimum',
              style: const TextStyle(color: crimson, fontSize: 11),
            ),
          ]),
        ],
      ]),
    ).animate().fadeIn(duration: 250.ms);
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.inventory_2_outlined,
                size: 48, color: textSecondary.withValues(alpha: 0.4)),
            const SizedBox(height: 12),
            const Text('No items found',
                style: TextStyle(
                    color: textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            const Text('Try a different filter or search',
                style: TextStyle(color: textSecondary, fontSize: 12)),
          ]),
        ),
      );
}

void _snack(BuildContext context, String msg, Color color) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
    ));
