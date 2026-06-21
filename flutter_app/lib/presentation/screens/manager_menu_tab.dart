// ─── Manager: Menu Tab ───────────────────────────────────────────────────────
//
// Read-only view of the branch menu plus an availability toggle per item.
// Admin still owns "add/edit/delete" — those operations stay in the admin
// screen because they impact every branch. Manager can:
//   - See every item in their branch (including unavailable ones via the
//     /menu/branch/:branchId/admin endpoint)
//   - Flip availability (e.g. ran out of sea bass, hide it from the
//     customer QR menu instantly)
//
// Items are grouped by category with a sticky-style category header.

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/config/app_theme.dart';
import '../../core/network/dio_client.dart';
import '../../core/utils/api_error.dart';
import '../../core/utils/idempotency.dart';
import '../state/auth_provider.dart';

// Branch-scoped admin view: includes unavailable items so the manager can
// re-enable something they previously paused.
final _managerMenuProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, branchId) async {
  final token = ref.watch(authProvider).token;
  final dio = createDioClient(token);
  final res = await dio.get('/menu/branch/$branchId/admin');
  return List<Map<String, dynamic>>.from(res.data);
});

class ManagerMenuTab extends ConsumerStatefulWidget {
  const ManagerMenuTab({super.key});
  @override
  ConsumerState<ManagerMenuTab> createState() => _ManagerMenuTabState();
}

class _ManagerMenuTabState extends ConsumerState<ManagerMenuTab> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final branchId = user?.branchId;
    if (branchId == null || branchId.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Your account is not assigned to a branch. Contact an administrator.',
            style: TextStyle(color: textSecondary, fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final menuAsync = ref.watch(_managerMenuProvider(branchId));
    return Scaffold(
      backgroundColor: slateBg,
      body: RefreshIndicator(
        color: copperAccent,
        backgroundColor: slateCard,
        onRefresh: () async => ref.invalidate(_managerMenuProvider(branchId)),
        child: menuAsync.when(
          loading: () => const Center(
              child: CircularProgressIndicator(color: copperAccent)),
          error: (e, _) => Center(
              child: Text(describeApiError(e),
                  style: const TextStyle(color: crimson))),
          data: (items) {
            final filtered = items
                .where((i) => _query.isEmpty
                    ? true
                    : (i['name'] as String? ?? '')
                        .toLowerCase()
                        .contains(_query.toLowerCase()))
                .toList();
            final categories = filtered
                .map((i) => (i['category'] as String?) ?? 'Other')
                .toSet()
                .toList()
              ..sort();
            final available = items.where((i) => i['isAvailable'] == true).length;
            final unavailable = items.length - available;
            return ListView(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
              children: [
                // Header summary
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: slateCard,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: dividerColor),
                  ),
                  child: Row(children: [
                    _Pill('Available', available, emerald),
                    const SizedBox(width: 8),
                    _Pill('Hidden', unavailable, amber),
                    const Spacer(),
                    Text('${items.length} total',
                        style: const TextStyle(
                            color: textSecondary, fontSize: 11)),
                  ]),
                ),
                const SizedBox(height: 12),
                // Search
                TextField(
                  onChanged: (v) => setState(() => _query = v),
                  style: const TextStyle(color: textPrimary, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Search items',
                    hintStyle:
                        const TextStyle(color: textSecondary, fontSize: 12),
                    filled: true,
                    fillColor: slateCard,
                    prefixIcon:
                        const Icon(Icons.search, color: textSecondary, size: 18),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: dividerColor),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: dividerColor),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: copperAccent),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                if (categories.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(
                      child: Text(
                          'No items found. Admin can add new items from the Admin → System → Menu tab.',
                          style: TextStyle(
                              color: textSecondary, fontSize: 12),
                          textAlign: TextAlign.center),
                    ),
                  ),
                for (final cat in categories) ...[
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                    child: Text(cat.toUpperCase(),
                        style: const TextStyle(
                            color: textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1)),
                  ),
                  ...filtered
                      .where((i) => (i['category'] ?? 'Other') == cat)
                      .map((i) => _MenuRow(
                            item: i,
                            onToggle: () => _toggle(i),
                          )),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _toggle(Map<String, dynamic> item) async {
    final user = ref.read(authProvider).user;
    final branchId = user?.branchId ?? '';
    final id = (item['_id'] ?? item['id'])?.toString() ?? '';
    if (id.isEmpty) return;
    try {
      final dio = createDioClient(ref.read(authProvider).token);
      await dio.patch(
        '/menu/$id/toggle',
        options: Options(headers: {
          'Idempotency-Key': newIdempotencyKey('menu-toggle-$id'),
        }),
      );
      ref.invalidate(_managerMenuProvider(branchId));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(describeApiError(e)),
          backgroundColor: crimson,
        ));
      }
    }
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  const _Pill(this.label, this.count, this.color);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text('$count',
              style: TextStyle(
                  color: color, fontSize: 13, fontWeight: FontWeight.w800)),
          const SizedBox(width: 5),
          Text(label.toUpperCase(),
              style: TextStyle(
                  color: color, fontSize: 9, fontWeight: FontWeight.w800)),
        ]),
      );
}

class _MenuRow extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback onToggle;
  const _MenuRow({required this.item, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final available = item['isAvailable'] == true;
    final price = (item['basePrice'] as num? ?? 0).toDouble();
    final prep = (item['prepTimeMinutes'] as num? ?? 0).toInt();
    final isVeg = item['isVeg'] == true;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: slateCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: available
              ? dividerColor
              : amber.withValues(alpha: 0.35),
        ),
      ),
      child: Row(children: [
        // Veg/non-veg dot
        Container(
          width: 10, height: 10,
          decoration: BoxDecoration(
            shape: BoxShape.rectangle,
            border: Border.all(
                color: isVeg ? emerald : crimson, width: 1.4),
          ),
          child: Center(
            child: Container(
              width: 4, height: 4,
              decoration: BoxDecoration(
                color: isVeg ? emerald : crimson,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item['name'] ?? '',
                    style: TextStyle(
                        color: available ? textPrimary : textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        decoration: available
                            ? TextDecoration.none
                            : TextDecoration.lineThrough),
                    overflow: TextOverflow.ellipsis),
                Row(children: [
                  Text('₹${price.toStringAsFixed(0)}',
                      style: const TextStyle(
                          color: copperAccent,
                          fontSize: 12,
                          fontWeight: FontWeight.w700)),
                  if (prep > 0) ...[
                    const SizedBox(width: 10),
                    const Icon(Icons.timer_outlined,
                        color: textSecondary, size: 10),
                    const SizedBox(width: 2),
                    Text('${prep}m',
                        style: const TextStyle(
                            color: textSecondary, fontSize: 10)),
                  ],
                ]),
              ]),
        ),
        Switch(
          value: available,
          activeThumbColor: emerald,
          inactiveThumbColor: textSecondary,
          inactiveTrackColor: slateSurface,
          onChanged: (_) => onToggle(),
        ),
      ]),
    );
  }
}
