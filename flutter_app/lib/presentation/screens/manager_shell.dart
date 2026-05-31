// ─── Manager Shell ────────────────────────────────────────────────────────────
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/config/app_config.dart';
import '../../core/config/app_theme.dart';
import '../../core/services/websocket_service.dart';
import '../../core/services/fcm_service.dart';
import '../state/auth_provider.dart';
import 'manager_operations_tab.dart';
import 'manager_tables_tab.dart';
import 'manager_kitchen_tab.dart';
import 'manager_staff_tab.dart';
import 'manager_discounts_tab.dart';
import 'manager_inventory_tab.dart';
import 'manager_reports_tab.dart';
import 'manager_customer_service_tab.dart';
import 'manager_menu_tab.dart';
import 'admin_profile_screen.dart';

// ── Tab index constants ───────────────────────────────────────────────────────
const _kOperations = 0;
const _kTables     = 1;
const _kKitchen    = 2;
const _kStaff      = 3;
// Drawer tabs (index 4+)
const _kDiscounts  = 4;
const _kInventory  = 5;
const _kMenu       = 6;
const _kReports    = 7;
const _kCustomer   = 8;

class ManagerShell extends ConsumerStatefulWidget {
  const ManagerShell({super.key});

  @override
  ConsumerState<ManagerShell> createState() => _ManagerShellState();
}

class _ManagerShellState extends ConsumerState<ManagerShell> {
  int _index = _kOperations;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey();

  // ── Screens (swapped in one by one) ────────────────────────────────────────
  static const _screens = <Widget>[
    ManagerOperationsTab(),      // 0
    ManagerTablesTab(),           // 1
    ManagerKitchenTab(),          // 2
    ManagerStaffTab(),            // 3
    ManagerDiscountsTab(),        // 4
    ManagerInventoryTab(),        // 5
    ManagerMenuTab(),             // 6
    ManagerReportsTab(),          // 7
    ManagerCustomerServiceTab(),  // 8
  ];

  static const _drawerItems = [
    _DrawerItem(_kDiscounts, Icons.discount_outlined,   Icons.discount,   'Discounts'),
    _DrawerItem(_kInventory, Icons.inventory_2_outlined, Icons.inventory_2, 'Inventory'),
    _DrawerItem(_kMenu,      Icons.restaurant_menu_outlined, Icons.restaurant_menu, 'Menu'),
    _DrawerItem(_kReports,   Icons.bar_chart_outlined,  Icons.bar_chart,  'Reports'),
    _DrawerItem(_kCustomer,  Icons.support_agent_outlined, Icons.support_agent, 'Customer Svc'),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final token = ref.read(authProvider).token;
      if (token != null) {
        ref.read(webSocketServiceProvider).connect(token);
        FcmService.instance.init(token);
      }
    });
  }

  void _select(int i) {
    setState(() => _index = i);
    if (_scaffoldKey.currentState?.isDrawerOpen == true) {
      Navigator.pop(context);
    }
  }

  String get _currentTitle => switch (_index) {
        _kOperations => 'Operations',
        _kTables     => 'Tables',
        _kKitchen    => 'Kitchen',
        _kStaff      => 'Staff',
        _kDiscounts  => 'Discounts',
        _kInventory  => 'Inventory',
        _kMenu       => 'Menu',
        _kReports    => 'Reports',
        _kCustomer   => 'Customer Service',
        _          => 'Manager',
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: slateBg,
      appBar: _buildAppBar(),
      drawer: _buildDrawer(),
      body: IndexedStack(index: _index, children: _screens),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  // ── AppBar ─────────────────────────────────────────────────────────────────
  PreferredSizeWidget _buildAppBar() => AppBar(
        backgroundColor: slateCard,
        elevation: 0,
        titleSpacing: 16,
        leading: IconButton(
          icon: const Icon(Icons.menu, color: textSecondary, size: 22),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        title: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 26, height: 26,
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
          Text(_currentTitle,
              style: const TextStyle(
                  color: textPrimary, fontSize: 15, fontWeight: FontWeight.w800)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: roseGold.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text('MGR',
                style: TextStyle(
                    color: roseGold,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1)),
          ),
        ]),
        actions: [
          Consumer(builder: (ctx, ref, _) {
            final user = ref.watch(authProvider).user;
            final initial = user?.name.isNotEmpty == true
                ? user!.name.substring(0, 1).toUpperCase()
                : 'M';
            return PopupMenuButton<String>(
              color: slateSurface,
              offset: const Offset(0, 48),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                CircleAvatar(
                  radius: 15,
                  backgroundColor: roseGold.withValues(alpha: 0.2),
                  // Render the actual photo when one is on file. Falls back
                  // to initials while loading or on error. The ?v=updatedAt
                  // cache-buster lives inside photoUrlFor so a freshly
                  // uploaded photo replaces the cached URL.
                  child: () {
                    final photo = user?.photoUrlFor(AppConfig.baseUrl);
                    if (photo == null) {
                      return Text(initial,
                          style: const TextStyle(
                              color: roseGold,
                              fontSize: 12,
                              fontWeight: FontWeight.w700));
                    }
                    return ClipOval(
                      child: CachedNetworkImage(
                        imageUrl: photo,
                        width: 30,
                        height: 30,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Text(initial,
                            style: const TextStyle(
                                color: roseGold,
                                fontSize: 12,
                                fontWeight: FontWeight.w700)),
                        errorWidget: (_, __, ___) => Text(initial,
                            style: const TextStyle(
                                color: roseGold,
                                fontSize: 12,
                                fontWeight: FontWeight.w700)),
                      ),
                    );
                  }(),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.keyboard_arrow_down, color: textSecondary, size: 16),
                const SizedBox(width: 8),
              ]),
              itemBuilder: (_) => [
                PopupMenuItem(
                  enabled: false,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(user?.name ?? 'Manager',
                        style: const TextStyle(
                            color: textPrimary, fontSize: 13, fontWeight: FontWeight.w700)),
                    Text(user?.email ?? '',
                        style: const TextStyle(color: textSecondary, fontSize: 11)),
                    const Divider(color: dividerColor, height: 16),
                  ]),
                ),
                PopupMenuItem(
                  value: 'profile',
                  child: const Row(children: [
                    Icon(Icons.account_circle_outlined, color: roseGold, size: 16),
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
          }),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: dividerColor),
        ),
      );

  // ── Bottom Nav (5 items) ───────────────────────────────────────────────────
  Widget _buildBottomNav() => Container(
        decoration: BoxDecoration(
          color: slateCard,
          border: Border(top: BorderSide(color: dividerColor, width: 1)),
        ),
        child: SafeArea(
          child: SizedBox(
            height: 64,
            child: Row(children: [
              _NavItem(
                icon: Icons.dashboard_outlined,
                activeIcon: Icons.dashboard,
                label: 'Operations',
                selected: _index == _kOperations,
                onTap: () => _select(_kOperations),
              ),
              _NavItem(
                icon: Icons.table_restaurant_outlined,
                activeIcon: Icons.table_restaurant,
                label: 'Tables',
                selected: _index == _kTables,
                onTap: () => _select(_kTables),
              ),
              _NavItem(
                icon: Icons.restaurant_outlined,
                activeIcon: Icons.restaurant,
                label: 'Kitchen',
                selected: _index == _kKitchen,
                onTap: () => _select(_kKitchen),
              ),
              _NavItem(
                icon: Icons.people_outline,
                activeIcon: Icons.people,
                label: 'Staff',
                selected: _index == _kStaff,
                onTap: () => _select(_kStaff),
              ),
              _NavItem(
                icon: Icons.grid_view_outlined,
                activeIcon: Icons.grid_view,
                label: 'More',
                selected: _index >= _kDiscounts,
                onTap: () => _scaffoldKey.currentState?.openDrawer(),
              ),
            ]),
          ),
        ),
      );

  // ── Drawer (4 secondary items) ─────────────────────────────────────────────
  Widget _buildDrawer() => Drawer(
        backgroundColor: slateCard,
        child: SafeArea(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [copperAccent, roseGold]),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.restaurant, color: Colors.white, size: 20),
                ),
                const SizedBox(height: 12),
                const Text('DINE OPS',
                    style: TextStyle(
                        color: textPrimary, fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 2)),
                const Text('Manager Panel',
                    style: TextStyle(color: textSecondary, fontSize: 12)),
              ]),
            ),
            const Divider(color: dividerColor, height: 1),
            const SizedBox(height: 8),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              child: Text('MORE SECTIONS',
                  style: TextStyle(
                      color: textSecondary, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.5)),
            ),
            ..._drawerItems.map((item) => _DrawerTile(
                  key: ValueKey(item.index),
                  item: item,
                  selected: _index == item.index,
                  onTap: () => _select(item.index),
                )),
            const Spacer(),
            const Divider(color: dividerColor, height: 1),
            Consumer(builder: (ctx, ref, _) => ListTile(
              leading: const Icon(Icons.account_circle_outlined, color: roseGold, size: 20),
              title: const Text('My Profile',
                  style: TextStyle(color: textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(ctx, MaterialPageRoute(
                  builder: (_) => const AdminProfileScreen()));
              },
            )),
            ListTile(
              leading: const Icon(Icons.logout, color: crimson, size: 20),
              title: const Text('Logout',
                  style: TextStyle(color: crimson, fontWeight: FontWeight.w600, fontSize: 13)),
              onTap: () => ref.read(authProvider.notifier).logout(),
            ),
          ]),
        ),
      );
}

// ── Bottom nav item ───────────────────────────────────────────────────────────
class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Expanded(
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: selected ? copperAccent.withValues(alpha: 0.15) : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  selected ? activeIcon : icon,
                  color: selected ? copperAccent : textSecondary,
                  size: 22,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  color: selected ? copperAccent : textSecondary,
                  fontSize: 10,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ]),
          ),
        ),
      );
}

// ── Drawer tile ───────────────────────────────────────────────────────────────
class _DrawerItem {
  final int index;
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const _DrawerItem(this.index, this.icon, this.activeIcon, this.label);
}

class _DrawerTile extends StatelessWidget {
  final _DrawerItem item;
  final bool selected;
  final VoidCallback onTap;
  const _DrawerTile({required super.key, required this.item, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => ListTile(
        leading: Icon(
          selected ? item.activeIcon : item.icon,
          color: selected ? copperAccent : textSecondary,
          size: 22,
        ),
        title: Text(
          item.label,
          style: TextStyle(
            color: selected ? copperAccent : textPrimary,
            fontSize: 13,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
        tileColor: selected ? copperAccent.withValues(alpha: 0.08) : Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
        onTap: onTap,
      );
}
