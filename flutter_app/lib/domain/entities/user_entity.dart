// ─── User / Auth Entity ──────────────────────────────────────────────────────

enum UserRole { admin, manager, waiter, chef, cashier, customer }

class UserEntity {
  final String id;
  final String name;
  final String email;
  final UserRole role;
  final String? fcmToken;
  final String? branchId;
  /// Server-relative path, e.g. /uploads/photos/abc.jpg. Prepend baseUrl
  /// before passing to CachedNetworkImage.
  final String? photoUrl;
  /// `updatedAt` from the user document. Backend stores photoUrl as a stable
  /// `/users/:id/photo` path, so the URL doesn't change when the photo
  /// changes. Appending `?v=<updatedAt-ms>` busts the on-device image cache
  /// so a fresh upload actually renders.
  final DateTime? updatedAt;

  const UserEntity({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.fcmToken,
    this.branchId,
    this.photoUrl,
    this.updatedAt,
  });

  /// Full URL ready for CachedNetworkImage, with cache-buster query param.
  /// Returns null when there is no photo on file.
  String? photoUrlFor(String baseUrl) {
    if (photoUrl == null || photoUrl!.isEmpty) return null;
    final v = updatedAt?.millisecondsSinceEpoch ?? 0;
    return '$baseUrl$photoUrl?v=$v';
  }

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
