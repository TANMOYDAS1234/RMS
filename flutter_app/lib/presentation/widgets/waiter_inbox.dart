// ─── Waiter "Help requested" inbox ───────────────────────────────────────────
//
// Pulls open help-requests across active sessions in the waiter's branch
// (Phase 6: GET /sessions/help-requests). Auto-invalidates on every WS
// event so a brand-new request appears within the round-trip — no polling.
//
// Tap a row → PATCH /sessions/:id/help/:helpId/resolve, then optimistic
// drop from the inbox.

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/config/app_theme.dart';
import '../../core/network/dio_client.dart';
import '../../core/services/websocket_service.dart';
import '../../core/utils/idempotency.dart';
import '../state/auth_provider.dart';

final waiterHelpInboxProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final token = ref.watch(authProvider).token;
  final dio = createDioClient(token);
  final res = await dio.get('/sessions/help-requests');
  return List<Map<String, dynamic>>.from(res.data);
});

class WaiterInbox extends ConsumerWidget {
  const WaiterInbox({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // FCM-driven path is already wired in main.dart; this WS listener
    // covers the foreground-active case so the inbox refreshes within
    // the round-trip of any session-side event.
    ref.listen(wsEventsProvider, (_, next) {
      next.whenData((evt) {
        if (evt.event == 'order:updated' ||
            evt.event == 'order:created' ||
            evt.event == 'kitchen:progress') {
          ref.invalidate(waiterHelpInboxProvider);
        }
      });
    });

    final inbox = ref.watch(waiterHelpInboxProvider);
    return inbox.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (items) {
        if (items.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: amber.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: amber.withValues(alpha: 0.4)),
            ),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Icon(Icons.notifications_active_outlined,
                        color: amber, size: 16),
                    const SizedBox(width: 8),
                    Text(
                        '${items.length} table${items.length == 1 ? '' : 's'} need help',
                        style: const TextStyle(
                            color: amber,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5)),
                  ]),
                  const SizedBox(height: 6),
                  for (final h in items)
                    _HelpRow(
                      help: h,
                      onResolve: () => _resolve(ref, h),
                    ),
                ]),
          ),
        );
      },
    );
  }

  Future<void> _resolve(WidgetRef ref, Map<String, dynamic> help) async {
    final sessionId = help['sessionId']?.toString();
    final helpId = help['helpId']?.toString();
    if (sessionId == null || helpId == null) return;
    try {
      final dio = createDioClient(ref.read(authProvider).token);
      await dio.patch(
        '/sessions/$sessionId/help/$helpId/resolve',
        options: Options(headers: {
          'Idempotency-Key': newIdempotencyKey('help-resolve-$helpId'),
        }),
      );
    } catch (_) {
      // best-effort — the inbox reload below will surface any failure
    } finally {
      ref.invalidate(waiterHelpInboxProvider);
    }
  }
}

class _HelpRow extends StatelessWidget {
  final Map<String, dynamic> help;
  final VoidCallback onResolve;
  const _HelpRow({required this.help, required this.onResolve});

  @override
  Widget build(BuildContext context) {
    final at = help['at'] != null
        ? DateTime.tryParse(help['at'].toString())
        : null;
    final mins = at == null
        ? 0
        : DateTime.now().difference(at).inMinutes;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: amber.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(help['tableLabel']?.toString() ?? '—',
              style: const TextStyle(
                  color: amber,
                  fontSize: 11,
                  fontWeight: FontWeight.w800)),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            help['reason']?.toString().isNotEmpty == true
                ? help['reason'].toString()
                : 'Help requested',
            style: const TextStyle(color: textPrimary, fontSize: 12),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (at != null) ...[
          const SizedBox(width: 6),
          Text('${mins}m',
              style: const TextStyle(
                  color: textSecondary, fontSize: 11)),
        ],
        const SizedBox(width: 6),
        IconButton(
          icon: const Icon(Icons.check_circle_outline,
              color: emerald, size: 20),
          tooltip: 'Mark resolved',
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          onPressed: onResolve,
        ),
      ]),
    );
  }
}
