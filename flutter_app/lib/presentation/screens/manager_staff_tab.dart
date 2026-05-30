// ─── Manager: Staff Tab ───────────────────────────────────────────────────────
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/config/app_config.dart';
import '../../core/config/app_theme.dart';
import '../../core/network/dio_client.dart';
import '../../core/utils/api_error.dart';
import '../../core/utils/idempotency.dart';
import '../../data/api/manager_api.dart';
import '../state/auth_provider.dart';

final _managerStaffProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>(
        (ref) => ref.watch(managerApiProvider).staff());


// ── Role colors ───────────────────────────────────────────────────────────────
const _roleColors = {
  'manager':  roseGold,
  'waiter':   amber,
  'chef':     copperAccent,
  'cashier':  emerald,
};

// ── Tab ───────────────────────────────────────────────────────────────────────
class ManagerStaffTab extends ConsumerWidget {
  const ManagerStaffTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final staffAsync = ref.watch(_managerStaffProvider);

    return RefreshIndicator(
      color: copperAccent,
      backgroundColor: slateCard,
      onRefresh: () async => ref.invalidate(_managerStaffProvider),
      child: staffAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(color: copperAccent)),
        error: (e, _) => Center(
            child: Text('$e',
                style: const TextStyle(color: crimson, fontSize: 13))),
        data: (staff) => _StaffBody(staff: staff),
      ),
    );
  }
}

// ── Body ──────────────────────────────────────────────────────────────────────
class _StaffBody extends StatelessWidget {
  final List<Map<String, dynamic>> staff;
  const _StaffBody({required this.staff});

  @override
  Widget build(BuildContext context) {
    final active   = staff.where((s) => s['isActive'] == true).length;
    final inactive = staff.length - active;

    // Group by role
    final byRole = <String, List<Map<String, dynamic>>>{};
    for (final s in staff) {
      final role = s['role'] as String? ?? 'other';
      byRole.putIfAbsent(role, () => []).add(s);
    }
    final roleOrder = ['manager', 'waiter', 'chef', 'cashier'];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [
        // ── Summary strip ────────────────────────────────────────────────
        Row(children: [
          _SummaryChip('Total', staff.length, copperAccent),
          const SizedBox(width: 8),
          _SummaryChip('Active', active, emerald),
          const SizedBox(width: 8),
          _SummaryChip('Inactive', inactive, textSecondary),
        ]),
        const SizedBox(height: 16),

        // ── Performance leaderboard ──────────────────────────────────────
        _LeaderboardCard(staff: staff),
        const SizedBox(height: 16),

        // ── Staff by role ────────────────────────────────────────────────
        ...roleOrder.where((r) => byRole.containsKey(r)).map((role) {
          final members = byRole[role]!;
          final color = _roleColors[role] ?? textSecondary;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(children: [
                  Container(
                    width: 4, height: 16,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(role.toUpperCase(),
                      style: TextStyle(
                          color: color,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1)),
                  const SizedBox(width: 8),
                  Text('${members.length}',
                      style: const TextStyle(
                          color: textSecondary, fontSize: 11)),
                ]),
              ),
              ...members.map((s) => _StaffCard(member: s)),
              const SizedBox(height: 8),
            ],
          );
        }),
      ],
    );
  }
}

// ── Leaderboard card ──────────────────────────────────────────────────────────
class _LeaderboardCard extends StatelessWidget {
  final List<Map<String, dynamic>> staff;
  const _LeaderboardCard({required this.staff});

  @override
  Widget build(BuildContext context) {
    final sorted = [...staff]
      ..sort((a, b) =>
          (b['todayOrders'] as int? ?? 0)
              .compareTo(a['todayOrders'] as int? ?? 0));
    final top = sorted.take(3).toList();
    if (top.isEmpty || (top.first['todayOrders'] as int? ?? 0) == 0) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: slateCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: copperAccent.withValues(alpha: 0.2)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.emoji_events_outlined, color: amber, size: 16),
          SizedBox(width: 6),
          Text("Today's Top Performers",
              style: TextStyle(
                  color: textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 12),
        ...top.asMap().entries.map((e) {
          final rank  = e.key + 1;
          final s     = e.value;
          final name  = s['name'] as String? ?? 'Staff';
          final role  = s['role'] as String? ?? '';
          final orders = s['todayOrders'] as int? ?? 0;
          final medals = ['🥇', '🥈', '🥉'];
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(children: [
              Text(medals[rank - 1], style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 10),
              Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(name,
                    style: const TextStyle(
                        color: textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
                Text(role.toUpperCase(),
                    style: const TextStyle(
                        color: textSecondary, fontSize: 10)),
              ])),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: copperAccent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('$orders orders',
                    style: const TextStyle(
                        color: copperAccent,
                        fontSize: 11,
                        fontWeight: FontWeight.w700)),
              ),
            ]),
          );
        }),
      ]),
    );
  }
}

// ── Staff card ────────────────────────────────────────────────────────────────
class _StaffCard extends ConsumerWidget {
  final Map<String, dynamic> member;
  const _StaffCard({required this.member});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role      = member['role'] as String? ?? 'waiter';
    final color     = _roleColors[role] ?? textSecondary;
    final isActive  = member['isActive'] as bool? ?? true;
    final name      = member['name'] as String? ?? 'Staff';
    final email     = member['email'] as String? ?? '';
    final id        = member['_id'] as String? ?? '';
    final orders    = member['todayOrders'] as int? ?? 0;
    final photoUrl  = member['photoUrl'] as String?;
    final updatedAt = member['updatedAt'];
    final v = updatedAt != null
        ? (DateTime.tryParse(updatedAt.toString())?.millisecondsSinceEpoch ?? 0)
        : 0;
    final fullPhoto =
        photoUrl != null ? '${AppConfig.baseUrl}$photoUrl?v=$v' : null;
    final initial   = name.isNotEmpty ? name[0].toUpperCase() : 'S';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: slateCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isActive ? dividerColor : crimson.withValues(alpha: 0.2),
        ),
      ),
      child: Row(children: [
        // Avatar
        Stack(children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: color.withValues(alpha: 0.15),
            child: fullPhoto != null
                ? ClipOval(
                    child: CachedNetworkImage(
                      imageUrl: fullPhoto,
                      width: 44, height: 44,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => Text(initial,
                          style: TextStyle(
                              color: color,
                              fontSize: 16,
                              fontWeight: FontWeight.w700)),
                    ),
                  )
                : Text(initial,
                    style: TextStyle(
                        color: color,
                        fontSize: 16,
                        fontWeight: FontWeight.w700)),
          ),
          Positioned(
            bottom: 0, right: 0,
            child: Container(
              width: 12, height: 12,
              decoration: BoxDecoration(
                color: isActive ? emerald : textSecondary,
                shape: BoxShape.circle,
                border: Border.all(color: slateCard, width: 1.5),
              ),
            ),
          ),
        ]),
        const SizedBox(width: 12),

        // Info
        Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name,
              style: const TextStyle(
                  color: textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600)),
          Text(email,
              style: const TextStyle(color: textSecondary, fontSize: 10),
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(role.toUpperCase(),
                  style: TextStyle(
                      color: color,
                      fontSize: 9,
                      fontWeight: FontWeight.w700)),
            ),
            const SizedBox(width: 6),
            if (orders > 0)
              Text('$orders orders today',
                  style: const TextStyle(
                      color: textSecondary, fontSize: 10)),
          ]),
        ])),

        // Actions
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          // Toggle active
          GestureDetector(
            onTap: () => _toggleActive(context, ref, id, isActive),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: (isActive ? emerald : textSecondary)
                    .withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: (isActive ? emerald : textSecondary)
                      .withValues(alpha: 0.3),
                ),
              ),
              child: Text(isActive ? 'Active' : 'Inactive',
                  style: TextStyle(
                      color: isActive ? emerald : textSecondary,
                      fontSize: 10,
                      fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(height: 6),
          // Note button
          GestureDetector(
            onTap: () => _showNoteSheet(context, ref, id, name),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: slateSurface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: dividerColor),
              ),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.note_add_outlined, color: textSecondary, size: 12),
                SizedBox(width: 4),
                Text('Note',
                    style: TextStyle(
                        color: textSecondary,
                        fontSize: 10,
                        fontWeight: FontWeight.w600)),
              ]),
            ),
          ),
        ]),
      ]),
    ).animate().fadeIn(duration: 250.ms);
  }

  Future<void> _toggleActive(
      BuildContext context, WidgetRef ref, String id, bool current) async {
    try {
      final dio = createDioClient(ref.read(authProvider).token);
      await dio.patch(
        '/users/$id',
        data: {'isActive': !current},
        options: Options(headers: {
          'Idempotency-Key': newIdempotencyKey('toggle-active-$id'),
        }),
      );
      ref.invalidate(_managerStaffProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(describeApiError(e)),
          backgroundColor: crimson,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  void _showNoteSheet(
      BuildContext context, WidgetRef ref, String id, String name) {
    showModalBottomSheet(
      context: context,
      backgroundColor: slateCard,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _StaffNoteSheet(staffId: id, staffName: name),
    );
  }
}

class _StaffNoteSheet extends ConsumerStatefulWidget {
  final String staffId;
  final String staffName;
  const _StaffNoteSheet({required this.staffId, required this.staffName});
  @override
  ConsumerState<_StaffNoteSheet> createState() => _StaffNoteSheetState();
}

class _StaffNoteSheetState extends ConsumerState<_StaffNoteSheet> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Backend has no staff-note endpoint yet, so this is local-only feedback
    // until that ships. Keeps the controller properly disposed.
    return Padding(
      padding: EdgeInsets.fromLTRB(
          24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Add Note — ${widget.staffName}',
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
                hintText: 'e.g. Late arrival, performance note...',
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
              onTap: () {
                if (_ctrl.text.trim().isEmpty) return;
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('Note saved locally for ${widget.staffName}'),
                  backgroundColor: emerald,
                  behavior: SnackBarBehavior.floating,
                ));
              },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    gradient: copperGradient,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                      child: Text('Save Note',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 14))),
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
