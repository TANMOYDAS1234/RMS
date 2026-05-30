// ─── Manager: Tables Tab ──────────────────────────────────────────────────────
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/config/app_theme.dart';
import '../../core/network/dio_client.dart';
import '../../core/services/websocket_service.dart';
import '../../core/utils/api_error.dart';
import '../../core/utils/idempotency.dart';
import '../../data/api/manager_api.dart';
import '../state/auth_provider.dart';
import '../widgets/table_qr_sheet.dart';

final _managerTablesProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>(
        (ref) => ref.watch(managerApiProvider).tables());

// ── Status config ─────────────────────────────────────────────────────────────
const _statusColors = {
  'available': emerald,
  'occupied':  copperAccent,
  'reserved':  amber,
  'cleaning':  roseGold,
};

const _statusIcons = {
  'available': Icons.check_circle_outline,
  'occupied':  Icons.people_outline,
  'reserved':  Icons.bookmark_outline,
  'cleaning':  Icons.cleaning_services_outlined,
};

// ── Tab ───────────────────────────────────────────────────────────────────────
class ManagerTablesTab extends ConsumerWidget {
  const ManagerTablesTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tablesAsync = ref.watch(_managerTablesProvider);

    // Auto-refresh when the server pushes a table/order event.
    ref.listen(wsEventsProvider, (_, next) {
      next.whenData((evt) {
        if (evt.event == 'table:updated' ||
            evt.event == 'order:updated' ||
            evt.event == 'order:created') {
          ref.invalidate(_managerTablesProvider);
        }
      });
    });

    return Stack(
      children: [
        RefreshIndicator(
          color: copperAccent,
          backgroundColor: slateCard,
          onRefresh: () async => ref.invalidate(_managerTablesProvider),
          child: tablesAsync.when(
            loading: () => const Center(
                child: CircularProgressIndicator(color: copperAccent)),
            error: (e, _) => Center(
                child: Text(describeApiError(e),
                    style: const TextStyle(color: crimson, fontSize: 13))),
            data: (tables) => _TableBody(tables: tables),
          ),
        ),
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton.extended(
            backgroundColor: copperAccent,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.add),
            label: const Text('Add Table',
                style: TextStyle(fontWeight: FontWeight.w700)),
            onPressed: () => _showAddTableSheet(context, ref),
          ),
        ),
      ],
    );
  }

  void _showAddTableSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: slateCard,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => const _AddTableSheet(),
    );
  }
}

class _AddTableSheet extends ConsumerStatefulWidget {
  const _AddTableSheet();
  @override
  ConsumerState<_AddTableSheet> createState() => _AddTableSheetState();
}

class _AddTableSheetState extends ConsumerState<_AddTableSheet> {
  late final TextEditingController _labelCtrl;
  late final TextEditingController _capCtrl;
  late final String _idempotencyKey;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _labelCtrl = TextEditingController();
    _capCtrl = TextEditingController(text: '4');
    _idempotencyKey = newIdempotencyKey('table-create');
  }

  @override
  void dispose() {
    _labelCtrl.dispose();
    _capCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final label = _labelCtrl.text.trim();
    final cap = int.tryParse(_capCtrl.text) ?? 4;
    if (label.isEmpty) return;
    setState(() => _submitting = true);
    try {
      final dio = createDioClient(ref.read(authProvider).token);
      await dio.post(
        '/tables',
        data: {'label': label, 'capacity': cap},
        options: Options(headers: {'Idempotency-Key': _idempotencyKey}),
      );
      ref.invalidate(_managerTablesProvider);
      if (mounted) {
        Navigator.pop(context);
        _snack(context, 'Table added', emerald);
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
              const Text('Add Table',
                  style: TextStyle(
                      color: textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              _Field(ctrl: _labelCtrl, label: 'Label (e.g. T-01)'),
              const SizedBox(height: 10),
              _Field(
                  ctrl: _capCtrl,
                  label: 'Capacity',
                  keyboardType: TextInputType.number),
              const SizedBox(height: 16),
              _PrimaryBtn(
                label: _submitting ? 'Creating…' : 'Create',
                onTap: _submitting ? () {} : _submit,
              ),
            ]),
      );
}

// ── Body ──────────────────────────────────────────────────────────────────────
class _TableBody extends ConsumerWidget {
  final List<Map<String, dynamic>> tables;
  const _TableBody({required this.tables});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final available = tables.where((t) => t['status'] == 'available').length;
    final occupied  = tables.where((t) => t['status'] == 'occupied').length;
    final reserved  = tables.where((t) => t['status'] == 'reserved').length;
    final cleaning  = tables.where((t) => t['status'] == 'cleaning').length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [
        // ── Summary strip ────────────────────────────────────────────────
        Row(children: [
          _SummaryChip('Available', available, emerald),
          const SizedBox(width: 8),
          _SummaryChip('Occupied', occupied, copperAccent),
          const SizedBox(width: 8),
          _SummaryChip('Reserved', reserved, amber),
          const SizedBox(width: 8),
          _SummaryChip('Cleaning', cleaning, roseGold),
        ]),
        const SizedBox(height: 16),

        // ── Occupancy bar ────────────────────────────────────────────────
        if (tables.isNotEmpty) ...[
          _OccupancyBar(total: tables.length, occupied: occupied),
          const SizedBox(height: 16),
        ],

        // ── Table grid ───────────────────────────────────────────────────
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.1,
          ),
          itemCount: tables.length,
          itemBuilder: (_, i) => _TableCard(
            table: tables[i],
            onStatusChange: (status) =>
                _updateStatus(context, ref, tables[i]['_id'].toString(), status),
            onViewOrder: () =>
                _showOrderSheet(context, tables[i]),
          ),
        ),
      ],
    );
  }

  Future<void> _updateStatus(
      BuildContext context, WidgetRef ref, String id, String status) async {
    try {
      await ref.read(managerApiProvider).updateTableStatus(
            id,
            status,
            idempotencyKey: newIdempotencyKey('table-status-$id-$status'),
          );
      ref.invalidate(_managerTablesProvider);
    } catch (e) {
      if (context.mounted) _snack(context, describeApiError(e), crimson);
    }
  }

  void _showOrderSheet(BuildContext context, Map<String, dynamic> table) {
    final order = table['currentOrder'] as Map<String, dynamic>?;
    showModalBottomSheet(
      context: context,
      backgroundColor: slateCard,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${table['label']} — Current Order',
                  style: const TextStyle(
                      color: textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              if (order == null)
                const Text('No active order',
                    style: TextStyle(color: textSecondary, fontSize: 13))
              else ...[
                _OrderRow('Status', order['status']?.toString().toUpperCase() ?? ''),
                _OrderRow('Items',
                    '${(order['items'] as List?)?.length ?? 0}'),
                _OrderRow('Total',
                    '₹${(order['total'] as num? ?? 0).toStringAsFixed(0)}'),
                _OrderRow('Subtotal',
                    '₹${(order['subtotal'] as num? ?? 0).toStringAsFixed(0)}'),
              ],
            ]),
      ),
    );
  }
}

// ── Table card ────────────────────────────────────────────────────────────────
class _TableCard extends StatelessWidget {
  final Map<String, dynamic> table;
  final void Function(String status) onStatusChange;
  final VoidCallback onViewOrder;

  const _TableCard({
    required this.table,
    required this.onStatusChange,
    required this.onViewOrder,
  });

  @override
  Widget build(BuildContext context) {
    final status = table['status'] as String? ?? 'available';
    final color  = _statusColors[status] ?? textSecondary;
    final icon   = _statusIcons[status]  ?? Icons.table_restaurant_outlined;
    final cap    = table['capacity'] as int? ?? 0;
    final hasOrder = table['currentOrder'] != null;

    return GestureDetector(
      onTap: () => _showStatusSheet(context),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: slateCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.4), width: 1.5),
        ),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(children: [
                Icon(icon, color: color, size: 18),
                const Spacer(),
                // QR action — opens the printable QR sheet for this table.
                // Manager generates one per table, prints it, sticks it on
                // the table. Customers scan with their phone camera.
                GestureDetector(
                  onTap: () => _showQrSheet(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 5, vertical: 2),
                    margin: const EdgeInsets.only(right: 4),
                    decoration: BoxDecoration(
                      color: slateSurface,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: dividerColor),
                    ),
                    child: const Icon(Icons.qr_code,
                        color: copperAccent, size: 11),
                  ),
                ),
                if (hasOrder)
                  GestureDetector(
                    onTap: onViewOrder,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: copperAccent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text('Order',
                          style: TextStyle(
                              color: copperAccent,
                              fontSize: 9,
                              fontWeight: FontWeight.w700)),
                    ),
                  ),
              ]),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(table['label'] ?? '',
                    style: const TextStyle(
                        color: textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Row(children: [
                  Icon(Icons.people_outline, size: 11, color: textSecondary),
                  const SizedBox(width: 3),
                  Text('$cap seats',
                      style: const TextStyle(
                          color: textSecondary, fontSize: 10)),
                ]),
                const SizedBox(height: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(status.toUpperCase(),
                      style: TextStyle(
                          color: color,
                          fontSize: 9,
                          fontWeight: FontWeight.w700)),
                ),
              ]),
            ]),
      ),
    ).animate().fadeIn(duration: 250.ms);
  }

  /// Opens the printable customer-QR sheet for this table.
  void _showQrSheet(BuildContext context) {
    final tableId = (table['_id'] ?? table['id'])?.toString() ?? '';
    final branchId = (table['branchId'] ?? '')?.toString() ?? '';
    if (tableId.isEmpty || branchId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text(
            'Table is missing id or branch — cannot generate QR.'),
      ));
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: slateCard,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => TableQrSheet(
        tableId: tableId,
        tableLabel: (table['label'] ?? '').toString(),
        branchId: branchId,
      ),
    );
  }

  void _showStatusSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: slateCard,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${table['label']} — Set Status',
                  style: const TextStyle(
                      color: textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              ...['available', 'occupied', 'reserved', 'cleaning'].map(
                (s) {
                  final color = _statusColors[s] ?? textSecondary;
                  final icon  = _statusIcons[s]  ?? Icons.circle_outlined;
                  final isCurrent = table['status'] == s;
                  return GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      if (!isCurrent) onStatusChange(s);
                    },
                    child: Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: isCurrent
                            ? color.withValues(alpha: 0.12)
                            : slateSurface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isCurrent
                              ? color.withValues(alpha: 0.4)
                              : dividerColor,
                        ),
                      ),
                      child: Row(children: [
                        Icon(icon, color: color, size: 18),
                        const SizedBox(width: 12),
                        Text(s[0].toUpperCase() + s.substring(1),
                            style: TextStyle(
                                color: isCurrent ? color : textPrimary,
                                fontSize: 13,
                                fontWeight: isCurrent
                                    ? FontWeight.w700
                                    : FontWeight.w500)),
                        if (isCurrent) ...[
                          const Spacer(),
                          Icon(Icons.check, color: color, size: 16),
                        ],
                      ]),
                    ),
                  );
                },
              ),
            ]),
      ),
    );
  }
}

// ── Occupancy bar ─────────────────────────────────────────────────────────────
class _OccupancyBar extends StatelessWidget {
  final int total;
  final int occupied;
  const _OccupancyBar({required this.total, required this.occupied});

  @override
  Widget build(BuildContext context) {
    final pct = total > 0 ? occupied / total : 0.0;
    final color = pct > 0.8 ? crimson : pct > 0.5 ? amber : emerald;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: slateCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: dividerColor),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text('Occupancy',
              style: TextStyle(
                  color: textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700)),
          const Spacer(),
          Text('$occupied / $total tables',
              style: const TextStyle(color: textSecondary, fontSize: 12)),
          const SizedBox(width: 8),
          Text('${(pct * 100).toStringAsFixed(0)}%',
              style: TextStyle(
                  color: color, fontSize: 13, fontWeight: FontWeight.w800)),
        ]),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct,
            backgroundColor: slateSurface,
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 6,
          ),
        ),
      ]),
    );
  }
}

// ── Summary chip ──────────────────────────────────────────────────────────────
class _SummaryChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  const _SummaryChip(this.label, this.count, this.color);

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
            Text('$count',
                style: TextStyle(
                    color: color, fontSize: 16, fontWeight: FontWeight.w800)),
            Text(label,
                style: const TextStyle(color: textSecondary, fontSize: 9),
                textAlign: TextAlign.center),
          ]),
        ),
      );
}

// ── Order info row ────────────────────────────────────────────────────────────
class _OrderRow extends StatelessWidget {
  final String label;
  final String value;
  const _OrderRow(this.label, this.value);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(children: [
          Text(label,
              style: const TextStyle(color: textSecondary, fontSize: 13)),
          const Spacer(),
          Text(value,
              style: const TextStyle(
                  color: textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600)),
        ]),
      );
}

// ── Shared helpers ────────────────────────────────────────────────────────────
class _Field extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  final TextInputType? keyboardType;
  const _Field({required this.ctrl, required this.label, this.keyboardType});

  @override
  Widget build(BuildContext context) => TextField(
        controller: ctrl,
        keyboardType: keyboardType,
        style: const TextStyle(color: textPrimary),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: textSecondary, fontSize: 13),
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
      );
}

class _PrimaryBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _PrimaryBtn({required this.label, required this.onTap});

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
          child: Center(
              child: Text(label,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 14))),
        ),
      );
}

void _snack(BuildContext context, String msg, Color color) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
    ));
