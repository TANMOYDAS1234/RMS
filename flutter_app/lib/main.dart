import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'core/config/app_theme.dart';
import 'core/services/sync_engine.dart';
import 'core/services/websocket_service.dart';
import 'domain/entities/user_entity.dart';
import 'presentation/screens/login_screen.dart';
import 'presentation/screens/dashboard_screen.dart';
import 'presentation/screens/kitchen_screen.dart';
import 'presentation/screens/billing_screen.dart';
import 'presentation/screens/inventory_screen.dart';
import 'presentation/state/auth_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  runApp(const ProviderScope(child: RmsApp()));
}

class RmsApp extends ConsumerWidget {
  const RmsApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.read(syncEngineProvider).init();
    final auth = ref.watch(authProvider);

    // Show splash while restoring persisted session
    if (auth.isRestoring) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        home: const _SplashScreen(),
      );
    }

    return MaterialApp(
      title: 'DINE OPS',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: auth.isAuthenticated ? MainShell(role: auth.user!.role) : const LoginScreen(),
    );
  }
}

// ── Splash ────────────────────────────────────────────────────────────────────
class _SplashScreen extends StatelessWidget {
  const _SplashScreen();
  @override
  Widget build(BuildContext context) => const Scaffold(
        backgroundColor: slateBg,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.restaurant, color: copperAccent, size: 48),
              SizedBox(height: 16),
              Text('DINE OPS', style: TextStyle(color: textPrimary, fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: 4)),
              SizedBox(height: 24),
              CircularProgressIndicator(color: copperAccent, strokeWidth: 2),
            ],
          ),
        ),
      );
}

// ── Main shell with role-based tabs ──────────────────────────────────────────
class MainShell extends ConsumerStatefulWidget {
  final UserRole role;
  const MainShell({super.key, required this.role});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  int _index = 0;

  // Each role gets specific tabs
  List<_TabDef> get _tabs => switch (widget.role) {
        UserRole.admin => [
            _TabDef('Dashboard',  Icons.dashboard_outlined,    Icons.dashboard,    const DashboardScreen()),
            _TabDef('Kitchen',    Icons.restaurant_outlined,   Icons.restaurant,   const KitchenScreen()),
            _TabDef('Billing',    Icons.receipt_long_outlined, Icons.receipt_long, const BillingScreen()),
            _TabDef('Inventory',  Icons.inventory_2_outlined,  Icons.inventory_2,  const InventoryScreen()),
          ],
        UserRole.manager => [
            _TabDef('Dashboard',  Icons.dashboard_outlined,    Icons.dashboard,    const DashboardScreen()),
            _TabDef('Kitchen',    Icons.restaurant_outlined,   Icons.restaurant,   const KitchenScreen()),
            _TabDef('Billing',    Icons.receipt_long_outlined, Icons.receipt_long, const BillingScreen()),
            _TabDef('Inventory',  Icons.inventory_2_outlined,  Icons.inventory_2,  const InventoryScreen()),
          ],
        UserRole.waiter => [
            _TabDef('Orders',     Icons.receipt_outlined,      Icons.receipt,      const DashboardScreen()),
            _TabDef('Kitchen',    Icons.restaurant_outlined,   Icons.restaurant,   const KitchenScreen()),
          ],
        UserRole.chef => [
            _TabDef('Kitchen',    Icons.restaurant_outlined,   Icons.restaurant,   const KitchenScreen()),
            _TabDef('Inventory',  Icons.inventory_2_outlined,  Icons.inventory_2,  const InventoryScreen()),
          ],
        UserRole.cashier => [
            _TabDef('Orders',     Icons.receipt_outlined,      Icons.receipt,      const DashboardScreen()),
            _TabDef('Billing',    Icons.receipt_long_outlined, Icons.receipt_long, const BillingScreen()),
          ],
        UserRole.customer => [
            _TabDef('Orders',     Icons.receipt_outlined,      Icons.receipt,      const DashboardScreen()),
          ],
      };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final token = ref.read(authProvider).token;
      if (token != null) ref.read(webSocketServiceProvider).connect(token);
    });
  }

  @override
  Widget build(BuildContext context) {
    final tabs = _tabs;
    // Clamp index in case role changed
    if (_index >= tabs.length) _index = 0;

    return Scaffold(
      body: IndexedStack(index: _index, children: tabs.map((t) => t.screen).toList()),
      bottomNavigationBar: tabs.length == 1
          ? null
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
}

class _TabDef {
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final Widget screen;
  const _TabDef(this.label, this.icon, this.selectedIcon, this.screen);
}
