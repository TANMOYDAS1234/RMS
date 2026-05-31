import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
// Mobile-only background handler registration lives in a separate file so
// the web build doesn't have to compile firebase_messaging (which has
// a long-running web compatibility bug).
import 'core/services/fcm_bg_handler_io.dart'
    if (dart.library.html) 'core/services/fcm_bg_handler_web.dart' as fcm_bg;
import 'core/config/app_config.dart';
import 'core/config/app_theme.dart';
import 'core/config/system_config_provider.dart';
import 'core/observability/sentry_bootstrap.dart';
import 'core/services/sync_engine.dart';
import 'core/services/websocket_service.dart';
import 'core/services/fcm_service.dart';
import 'domain/entities/user_entity.dart';
import 'presentation/screens/login_screen.dart';
import 'presentation/screens/dashboard_screen.dart';
import 'presentation/screens/kitchen_screen.dart';
import 'presentation/screens/billing_screen.dart';
import 'presentation/screens/inventory_screen.dart';
import 'presentation/screens/admin_screen.dart';
import 'presentation/screens/manager_shell.dart';
import 'presentation/screens/qr_ordering_screen.dart';
import 'presentation/screens/admin_profile_screen.dart';
import 'presentation/screens/cash_drawer_screen.dart';
import 'presentation/screens/floor_grid_screen.dart';
import 'presentation/state/auth_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  // Firebase initialization isn't required on web — the customer QR app
  // doesn't use FCM at all, and the firebase_core_web SDK ships partially-
  // working bindings that drag in firebase_messaging_web during link.
  if (!kIsWeb) {
    try {
      await Firebase.initializeApp();
    } catch (_) {}
    fcm_bg.registerBackgroundHandler();
  }

  // runWithSentry is a no-op when SENTRY_DSN dart-define is unset, so
  // local dev doesn't need credentials. Set --dart-define SENTRY_DSN=...
  // on release builds.
  await runWithSentry(() async {
    runApp(const ProviderScope(child: RmsApp()));
  });
}

class RmsApp extends ConsumerStatefulWidget {
  const RmsApp({super.key});
  @override
  ConsumerState<RmsApp> createState() => _RmsAppState();
}

class _RmsAppState extends ConsumerState<RmsApp> {
  /// Most recent notification tap that hasn't been consumed by a screen
  /// yet. main.dart watches this and routes to the correct tab on the
  /// next rebuild — necessary because FCM messages can arrive before
  /// the navigator is ready (cold start) or while the wrong tab is
  /// mounted (background → foreground).
  Map<String, dynamic>? _pendingTap;

  @override
  void initState() {
    super.initState();
    final engine = ref.read(syncEngineProvider);
    engine.setTokenProvider(() => ref.read(authProvider).token);
    engine.init();
    // Prefetch the runtime system config (QR web origin, Razorpay key,
    // env tag) so QR-sheet and payment flows have a warm cache. Errors
    // fall through to the provider's defaulted fallback — see
    // system_config_provider.dart.
    ref.read(systemConfigProvider);
    ref.listenManual(authProvider, (prev, next) {
      if (next.isAuthenticated && prev?.isAuthenticated != true) {
        engine.flushQueue();
      }
    });

    // Wire the FCM tap callback. Stash the message and rebuild — the
    // MainShell will read _pendingTap on its next frame and switch to
    // the right tab. We can't do navigation directly here because
    // there's no BuildContext at this point.
    FcmService.instance.onMessageOpened = (message) {
      if (mounted) setState(() => _pendingTap = message);
    };
  }

  /// Map a notification type to the index of the role's tab that should
  /// be foregrounded when the user taps the notification.
  int? _tabForMessage(Map<String, dynamic> data, UserRole role) {
    final type = data['type'];
    switch (role) {
      case UserRole.waiter:
        // Waiter has Orders (0) and Kitchen (1) tabs. ORDER_READY belongs
        // on the orders list so the waiter sees what's ready to pick up.
        if (type == 'ORDER_READY' || type == 'ORDER_SERVED') return 0;
        return 0;
      case UserRole.chef:
        // Chef has Kitchen (0) and Inventory (1). All order events route
        // to Kitchen; LOW_STOCK to Inventory.
        if (type == 'LOW_STOCK') return 1;
        return 0;
      case UserRole.cashier:
        // Cashier has Orders (0) and Billing (1). SERVED + PAYMENT go
        // to the billing tab.
        if (type == 'ORDER_SERVED' || type == 'PAYMENT_RECEIVED') return 1;
        return 0;
      case UserRole.manager:
      case UserRole.admin:
      case UserRole.customer:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);

    if (auth.isRestoring) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        scaffoldMessengerKey: FcmService.messengerKey,
        home: const _SplashScreen(),
      );
    }

    // QR web route: check for /t/{tableId}?branch={branchId}
    final uri = Uri.base;
    if (uri.pathSegments.length >= 2 && uri.pathSegments[0] == 't') {
      final tableId = uri.pathSegments[1];
      final branchId = uri.queryParameters['branch'] ?? 'default';
      return MaterialApp(
        title: 'DINE OPS',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        scaffoldMessengerKey: FcmService.messengerKey,
        home: QrOrderingScreen(tableId: tableId, branchId: branchId),
      );
    }

    // Translate the pending FCM tap into a tab index for this user's role.
    // Cleared on the way down so a stale tap doesn't get re-applied.
    int? jumpTo;
    if (_pendingTap != null && auth.user != null) {
      jumpTo = _tabForMessage(_pendingTap!, auth.user!.role);
      _pendingTap = null;
    }

    return MaterialApp(
      title: 'DINE OPS',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      scaffoldMessengerKey: FcmService.messengerKey,
      home: auth.isAuthenticated
          ? MainShell(role: auth.user!.role, jumpToTab: jumpTo)
          : const LoginScreen(),
    );
  }
}

// ── Splash ────────────────────────────────────────────────────────────────────
class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    // Layered animation: radial copper glow ⇒ rotating plate ⇒ knife/fork
    // crest ⇒ wordmark slide-up ⇒ tagline fade ⇒ progress shimmer.
    // All chained through flutter_animate so the heavy lifting stays in
    // one declarative pipeline.
    return Scaffold(
      backgroundColor: slateBg,
      body: Stack(
        children: [
          // Background: soft radial copper glow that breathes.
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0, -0.1),
                  radius: 0.9,
                  colors: [
                    Color(0x33C87B3A),
                    Color(0x00000000),
                  ],
                ),
              ),
            )
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .scaleXY(begin: 1.0, end: 1.15, duration: 2200.ms, curve: Curves.easeInOut),
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Logo crest — outer plate ring + inner knife/fork icon.
                SizedBox(
                  width: 110,
                  height: 110,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Slow-rotating copper ring (the "plate rim").
                      Container(
                        width: 110,
                        height: 110,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: SweepGradient(
                            colors: [
                              copperAccent.withValues(alpha: 0.0),
                              copperAccent.withValues(alpha: 0.9),
                              roseGold.withValues(alpha: 0.7),
                              copperAccent.withValues(alpha: 0.0),
                            ],
                            stops: const [0.0, 0.45, 0.7, 1.0],
                          ),
                        ),
                      )
                          .animate(onPlay: (c) => c.repeat())
                          .rotate(duration: 6000.ms, curve: Curves.linear),
                      // Inner disc covers the ring's centre so the
                      // sweep gradient reads as a thin halo.
                      Container(
                        width: 92,
                        height: 92,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: slateCard,
                          boxShadow: [
                            BoxShadow(
                              color: copperAccent.withValues(alpha: 0.35),
                              blurRadius: 24,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.restaurant_outlined,
                          color: copperAccent,
                          size: 40,
                        )
                            .animate(onPlay: (c) => c.repeat(reverse: true))
                            .scaleXY(
                                begin: 1.0,
                                end: 1.08,
                                duration: 1400.ms,
                                curve: Curves.easeInOut),
                      ),
                    ],
                  ),
                )
                    .animate()
                    .scaleXY(
                        begin: 0.4,
                        end: 1.0,
                        duration: 700.ms,
                        curve: Curves.elasticOut)
                    .fadeIn(duration: 400.ms),
                const SizedBox(height: 28),
                // Wordmark — slides up + fades in.
                const Text(
                  'DINE OPS',
                  style: TextStyle(
                      color: textPrimary,
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 8),
                )
                    .animate()
                    .fadeIn(delay: 350.ms, duration: 500.ms)
                    .slideY(begin: 0.4, end: 0, duration: 500.ms, curve: Curves.easeOutCubic),
                const SizedBox(height: 6),
                // Copper-tinted tagline.
                Text(
                  'Restaurant Operations, Reimagined',
                  style: TextStyle(
                      color: copperAccent.withValues(alpha: 0.85),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 2.2),
                )
                    .animate()
                    .fadeIn(delay: 650.ms, duration: 500.ms),
                const SizedBox(height: 36),
                // Bouncing copper dots in place of the spinner — feels
                // less "Material default", more crafted.
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(3, (i) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: copperAccent,
                        ),
                      )
                          .animate(onPlay: (c) => c.repeat())
                          .moveY(
                              begin: 0,
                              end: -8,
                              duration: 600.ms,
                              delay: (i * 150).ms,
                              curve: Curves.easeInOut)
                          .then()
                          .moveY(
                              begin: -8,
                              end: 0,
                              duration: 600.ms,
                              curve: Curves.easeInOut),
                    );
                  }),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Main shell with role-based tabs ──────────────────────────────────────────
class MainShell extends ConsumerStatefulWidget {
  final UserRole role;
  /// When non-null, the shell jumps to this tab index on mount and on every
  /// rebuild that carries a new value. Driven by FCM notification taps:
  /// _RmsAppState resolves the message's type → tab index and passes it
  /// here. The shell ignores nulls so the user's manual tab selections
  /// aren't clobbered when no tap is pending.
  final int? jumpToTab;
  const MainShell({super.key, required this.role, this.jumpToTab});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  int _index = 0;

  @override
  void didUpdateWidget(MainShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A new tap arrived (parent changed jumpToTab). Apply it without
    // overriding the user's manual selection in the no-new-tap case.
    if (widget.jumpToTab != null && widget.jumpToTab != oldWidget.jumpToTab) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _index = widget.jumpToTab!);
      });
    }
  }

  List<_TabDef> get _tabs => switch (widget.role) {
        UserRole.admin => [
            const _TabDef('Overview',  Icons.dashboard_outlined,    Icons.dashboard,    AdminOverviewTab()),
            const _TabDef('Analytics', Icons.bar_chart_outlined,    Icons.bar_chart,    AdminAnalyticsTab()),
            const _TabDef('Staff',     Icons.people_outline,        Icons.people,       AdminStaffTab()),
            const _TabDef('Orders',    Icons.receipt_outlined,      Icons.receipt,      AdminOrdersTab()),
            const _TabDef('Billing',   Icons.payments_outlined,     Icons.payments,     AdminBillingTab()),
            const _TabDef('Inventory', Icons.inventory_2_outlined,  Icons.inventory_2,  AdminInventoryTab()),
            const _TabDef('Branches',  Icons.store_outlined,        Icons.store,        AdminBranchesTab()),
            const _TabDef('System',    Icons.settings_outlined,     Icons.settings,     AdminSystemTab()),
          ],
        UserRole.manager => const [
            _TabDef('Manager', Icons.manage_accounts_outlined, Icons.manage_accounts, ManagerShell()),
          ],
        UserRole.waiter => [
            const _TabDef('Orders',  Icons.receipt_outlined,      Icons.receipt,      DashboardScreen()),
            const _TabDef('Floor',   Icons.grid_view_outlined,    Icons.grid_view,    FloorGridScreen()),
            const _TabDef('Kitchen', Icons.restaurant_outlined,   Icons.restaurant,   KitchenScreen()),
          ],
        UserRole.chef => [
            const _TabDef('Kitchen',   Icons.restaurant_outlined,  Icons.restaurant,  KitchenScreen()),
            const _TabDef('Inventory', Icons.inventory_2_outlined, Icons.inventory_2, InventoryScreen()),
          ],
        UserRole.cashier => [
            const _TabDef('Orders',  Icons.receipt_outlined,      Icons.receipt,      DashboardScreen()),
            const _TabDef('Billing', Icons.receipt_long_outlined, Icons.receipt_long, BillingScreen()),
            const _TabDef('Drawer',  Icons.point_of_sale_outlined, Icons.point_of_sale, CashDrawerScreen()),
          ],
        UserRole.customer => [
            const _TabDef('Orders', Icons.receipt_outlined, Icons.receipt, DashboardScreen()),
          ],
      };

  @override
  void initState() {
    super.initState();
    if (widget.jumpToTab != null) _index = widget.jumpToTab!;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final token = ref.read(authProvider).token;
      if (token != null) {
        ref.read(webSocketServiceProvider).connect(token);
        FcmService.instance.init(token);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final tabs = _tabs;
    if (_index >= tabs.length) _index = 0;
    final isAdmin = widget.role == UserRole.admin;

    return Scaffold(
      backgroundColor: slateBg,
      appBar: isAdmin ? _buildAdminAppBar() : null,
      body: IndexedStack(
          index: _index, children: tabs.map((t) => t.screen).toList()),
      bottomNavigationBar: tabs.length == 1
          ? null
          : isAdmin
              ? _buildAdminNavBar(tabs)
              : NavigationBar(
                  backgroundColor: slateCard,
                  indicatorColor: copperAccent.withValues(alpha: 0.2),
                  selectedIndex: _index,
                  onDestinationSelected: (i) => setState(() => _index = i),
                  destinations: tabs
                      .map((t) => NavigationDestination(
                            icon: Icon(t.icon, color: textSecondary),
                            selectedIcon: Icon(t.selectedIcon, color: copperAccent),
                            label: t.label,
                          ))
                      .toList(),
                ),
    );
  }

  Widget _buildAdminNavBar(List<_TabDef> tabs) => BottomNavigationBar(
        backgroundColor: slateCard,
        selectedItemColor: copperAccent,
        unselectedItemColor: textSecondary,
        type: BottomNavigationBarType.fixed,
        selectedFontSize: 10,
        unselectedFontSize: 10,
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        items: tabs
            .map((t) => BottomNavigationBarItem(
                  icon: Icon(t.icon, size: 22),
                  activeIcon: Icon(t.selectedIcon, size: 22),
                  label: t.label,
                ))
            .toList(),
      );

  PreferredSizeWidget _buildAdminAppBar() => AppBar(
        backgroundColor: slateCard,
        elevation: 0,
        titleSpacing: 16,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [copperAccent, roseGold],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(7),
              ),
              child: const Icon(Icons.restaurant, color: Colors.white, size: 14),
            ),
            const SizedBox(width: 8),
            const Text('DINE OPS',
                style: TextStyle(
                    color: textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: copperAccent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text('ADMIN',
                  style: TextStyle(
                      color: copperAccent,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1)),
            ),
          ],
        ),
        actions: [
          // Current user avatar + logout menu
          Consumer(
            builder: (ctx, ref, _) {
              final user = ref.watch(authProvider).user;
              final initial = user?.name.isNotEmpty == true
                  ? user!.name.substring(0, 1).toUpperCase()
                  : 'A';
              // photoUrlFor appends ?v=<updatedAt> so a fresh upload busts
              // CachedNetworkImage's cache (backend keeps the same URL path).
              final fullUrl = user?.photoUrlFor(AppConfig.baseUrl);
              return PopupMenuButton<String>(
                color: slateSurface,
                offset: const Offset(0, 48),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: 15,
                      backgroundColor: copperAccent.withValues(alpha: 0.2),
                      child: fullUrl != null
                          ? ClipOval(
                              child: CachedNetworkImage(
                                imageUrl: fullUrl,
                                width: 30,
                                height: 30,
                                fit: BoxFit.cover,
                                placeholder: (_, __) => Text(initial,
                                    style: const TextStyle(
                                        color: copperAccent,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700)),
                                errorWidget: (_, __, ___) => Text(initial,
                                    style: const TextStyle(
                                        color: copperAccent,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700)),
                              ),
                            )
                          : Text(initial,
                              style: const TextStyle(
                                  color: copperAccent,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700)),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.keyboard_arrow_down,
                        color: textSecondary, size: 16),
                    const SizedBox(width: 8),
                  ],
                ),
                itemBuilder: (_) => [
                  PopupMenuItem(
                    enabled: false,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(user?.name ?? 'Admin',
                            style: const TextStyle(
                                color: textPrimary,
                                fontSize: 13,
                                fontWeight: FontWeight.w700)),
                        Text(user?.email ?? '',
                            style: const TextStyle(
                                color: textSecondary, fontSize: 11)),
                        const Divider(color: dividerColor, height: 16),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'profile',
                    child: const Row(children: [
                      Icon(Icons.account_circle_outlined, color: copperAccent, size: 16),
                      SizedBox(width: 10),
                      Text('My Profile', style: TextStyle(color: textPrimary, fontWeight: FontWeight.w600)),
                    ]),
                    onTap: () => Future.microtask(() => Navigator.push(
                      ctx,
                      MaterialPageRoute(builder: (_) => const AdminProfileScreen()),
                    )),
                  ),
                  PopupMenuItem(
                    value: 'logout',
                    child: const Row(children: [
                      Icon(Icons.logout, color: crimson, size: 16),
                      SizedBox(width: 10),
                      Text('Logout', style: TextStyle(color: crimson, fontWeight: FontWeight.w600)),
                    ]),
                    onTap: () => ref.read(authProvider.notifier).logout(),
                  ),
                ],
              );
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: dividerColor),
        ),
      );
}

class _TabDef {
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final Widget screen;
  const _TabDef(this.label, this.icon, this.selectedIcon, this.screen);
}
