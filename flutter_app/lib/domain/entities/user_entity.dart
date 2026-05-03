// ─── User / Auth Entity ──────────────────────────────────────────────────────

enum UserRole { admin, manager, waiter, chef, cashier, customer }

class UserEntity {
  final String id;
  final String name;
  final String email;
  final UserRole role;
  final String? fcmToken;

  const UserEntity({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.fcmToken,
  });

  bool hasPermission(String permission) {
    const rolePermissions = <UserRole, List<String>>{
      UserRole.admin: ['*'],
      UserRole.manager: [
        'orders.read', 'orders.write', 'tables.read', 'tables.write',
        'menu.read', 'menu.write', 'reports.read', 'staff.read',
      ],
      UserRole.waiter: [
        'orders.read', 'orders.write', 'tables.read',
      ],
      UserRole.chef: [
        'orders.read', 'kitchen.write',
      ],
      UserRole.cashier: [
        'orders.read', 'billing.read', 'billing.write',
      ],
      UserRole.customer: [
        'menu.read', 'orders.create',
      ],
    };
    final perms = rolePermissions[role] ?? [];
    return perms.contains('*') || perms.contains(permission);
  }
}
