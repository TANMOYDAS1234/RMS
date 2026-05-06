// ─── Staff Management - Create/Edit/Disable/Reset Password ───────────────────

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/app_theme.dart';
import '../../../domain/entities/user_entity.dart';

class AdminStaffScreen extends ConsumerWidget {
  const AdminStaffScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: slateBg,
      appBar: AppBar(
        backgroundColor: slateBg,
        title: const Text('Staff Management', style: TextStyle(color: textPrimary, fontWeight: FontWeight.w700)),
        iconTheme: const IconThemeData(color: textPrimary),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddStaffDialog(context),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildStatsRow(),
          Expanded(child: _buildStaffList()),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          _StatCard('Total Staff', '12', azure),
          const SizedBox(width: 12),
          _StatCard('Active', '10', emerald),
          const SizedBox(width: 12),
          _StatCard('Inactive', '2', crimson),
        ],
      ),
    );
  }

  Widget _buildStaffList() {
    final mockStaff = [
      _StaffMember('John Doe', 'john@restaurant.com', UserRole.manager, true),
      _StaffMember('Sarah Wilson', 'sarah@restaurant.com', UserRole.waiter, true),
      _StaffMember('Mike Chen', 'mike@restaurant.com', UserRole.chef, true),
      _StaffMember('Lisa Brown', 'lisa@restaurant.com', UserRole.cashier, false),
    ];

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: mockStaff.length,
      itemBuilder: (context, index) {
        final staff = mockStaff[index];
        return _StaffCard(
          staff: staff,
          onEdit: () => _showEditStaffDialog(context, staff),
          onToggle: () => _toggleStaffStatus(staff),
          onResetPassword: () => _resetPassword(staff),
        );
      },
    );
  }

  void _showAddStaffDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => const _StaffFormDialog(),
    );
  }

  void _showEditStaffDialog(BuildContext context, _StaffMember staff) {
    showDialog(
      context: context,
      builder: (_) => _StaffFormDialog(staff: staff),
    );
  }

  void _toggleStaffStatus(_StaffMember staff) {
    // Toggle staff active status
  }

  void _resetPassword(_StaffMember staff) {
    // Reset staff password
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final Color color;

  const _StatCard(this.title, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: slateCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: slateBorder),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: const TextStyle(color: textSecondary, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _StaffCard extends StatelessWidget {
  final _StaffMember staff;
  final VoidCallback onEdit;
  final VoidCallback onToggle;
  final VoidCallback onResetPassword;

  const _StaffCard({
    required this.staff,
    required this.onEdit,
    required this.onToggle,
    required this.onResetPassword,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: slateCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: slateBorder),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: copperAccent.withValues(alpha: 0.2),
            child: Text(
              staff.name.substring(0, 1).toUpperCase(),
              style: const TextStyle(
                color: copperAccent,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  staff.name,
                  style: const TextStyle(
                    color: textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  staff.email,
                  style: const TextStyle(color: textSecondary, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    _RoleChip(staff.role),
                    const SizedBox(width: 8),
                    _StatusChip(staff.isActive),
                  ],
                ),
              ],
            ),
          ),
          PopupMenuButton(
            color: slateCard,
            child: const Icon(Icons.more_vert, color: textSecondary),
            itemBuilder: (_) => [
              PopupMenuItem(
                child: const Row(children: [Icon(Icons.edit, size: 16), SizedBox(width: 8), Text('Edit')]),
                onTap: onEdit,
              ),
              PopupMenuItem(
                child: Row(children: [
                  Icon(staff.isActive ? Icons.block : Icons.check_circle, size: 16),
                  const SizedBox(width: 8),
                  Text(staff.isActive ? 'Disable' : 'Enable'),
                ]),
                onTap: onToggle,
              ),
              PopupMenuItem(
                child: const Row(children: [Icon(Icons.lock_reset, size: 16), SizedBox(width: 8), Text('Reset Password')]),
                onTap: onResetPassword,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RoleChip extends StatelessWidget {
  final UserRole role;

  const _RoleChip(this.role);

  @override
  Widget build(BuildContext context) {
    final color = switch (role) {
      UserRole.admin => crimson,
      UserRole.manager => copperAccent,
      UserRole.waiter => azure,
      UserRole.chef => emerald,
      UserRole.cashier => violet,
      UserRole.customer => textSecondary,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        role.name.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final bool isActive;

  const _StatusChip(this.isActive);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: (isActive ? emerald : crimson).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        isActive ? 'ACTIVE' : 'INACTIVE',
        style: TextStyle(
          color: isActive ? emerald : crimson,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _StaffFormDialog extends StatefulWidget {
  final _StaffMember? staff;

  const _StaffFormDialog({this.staff});

  @override
  State<_StaffFormDialog> createState() => _StaffFormDialogState();
}

class _StaffFormDialogState extends State<_StaffFormDialog> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  UserRole _selectedRole = UserRole.waiter;

  @override
  void initState() {
    super.initState();
    if (widget.staff != null) {
      _nameController.text = widget.staff!.name;
      _emailController.text = widget.staff!.email;
      _selectedRole = widget.staff!.role;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: slateCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.staff == null ? 'Add Staff Member' : 'Edit Staff Member',
              style: const TextStyle(
                color: textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _nameController,
              style: const TextStyle(color: textPrimary),
              decoration: const InputDecoration(
                labelText: 'Name',
                labelStyle: TextStyle(color: textSecondary),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _emailController,
              style: const TextStyle(color: textPrimary),
              decoration: const InputDecoration(
                labelText: 'Email',
                labelStyle: TextStyle(color: textSecondary),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<UserRole>(
              value: _selectedRole,
              dropdownColor: slateCard,
              style: const TextStyle(color: textPrimary),
              decoration: const InputDecoration(
                labelText: 'Role',
                labelStyle: TextStyle(color: textSecondary),
                border: OutlineInputBorder(),
              ),
              items: UserRole.values.where((r) => r != UserRole.customer).map((role) {
                return DropdownMenuItem(
                  value: role,
                  child: Text(role.name.toUpperCase()),
                );
              }).toList(),
              onChanged: (role) => setState(() => _selectedRole = role!),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(color: textSecondary)),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: copperAccent),
                  onPressed: () {
                    // Save staff member
                    Navigator.pop(context);
                  },
                  child: Text(
                    widget.staff == null ? 'Add' : 'Save',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StaffMember {
  final String name;
  final String email;
  final UserRole role;
  final bool isActive;

  _StaffMember(this.name, this.email, this.role, this.isActive);
}