import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/config/app_config.dart';
import '../../core/config/app_theme.dart';
import '../../core/network/dio_client.dart';
import '../../core/utils/api_error.dart';
import '../../core/utils/idempotency.dart';
import '../state/auth_provider.dart';
import 'admin_screen.dart' show adminStaffProvider;
import 'manager_staff_tab.dart' show managerStaffProvider;

final _profileProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final token = ref.watch(authProvider).token;
  if (token == null) throw Exception('Not authenticated');
  final res = await createDioClient(token).get('/auth/me');
  return Map<String, dynamic>.from(res.data);
});

class AdminProfileScreen extends ConsumerWidget {
  const AdminProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(_profileProvider);

    return Scaffold(
      backgroundColor: slateBg,
      appBar: AppBar(
        backgroundColor: slateCard,
        title: const Text('My Profile',
            style: TextStyle(color: textPrimary, fontSize: 15, fontWeight: FontWeight.w700)),
        iconTheme: const IconThemeData(color: textSecondary),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: dividerColor),
        ),
      ),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: copperAccent)),
        error: (e, _) => Center(child: Text(describeApiError(e), style: const TextStyle(color: crimson))),
        data: (profile) => _ProfileBody(profile: profile),
      ),
    );
  }
}

class _ProfileBody extends ConsumerWidget {
  final Map<String, dynamic> profile;
  const _ProfileBody({required this.profile});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final photoUrl = profile['photoUrl'] as String?;
    // Cache-buster: backend keeps the photo URL stable across uploads,
    // so we tack on updatedAt to force CachedNetworkImage to refetch.
    final updatedAt = profile['updatedAt'];
    final v = updatedAt != null
        ? (DateTime.tryParse(updatedAt.toString())?.millisecondsSinceEpoch ?? 0)
        : 0;
    final fullUrl =
        photoUrl != null ? '${AppConfig.baseUrl}$photoUrl?v=$v' : null;
    final name = profile['name'] as String? ?? '';
    final email = profile['email'] as String? ?? '';
    final role = profile['role'] as String? ?? '';
    final id = (profile['_id'] ?? profile['id'])?.toString() ?? '';

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        // Avatar
        Center(
          child: GestureDetector(
            onTap: () => _pickAndUploadPhoto(context, ref, id),
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 48,
                  backgroundColor: copperAccent.withValues(alpha: 0.15),
                  child: fullUrl != null
                      ? ClipOval(
                          child: CachedNetworkImage(
                            imageUrl: fullUrl,
                            width: 96, height: 96, fit: BoxFit.cover,
                            placeholder: (_, __) => _initials(name),
                            errorWidget: (_, __, ___) => _initials(name),
                          ),
                        )
                      : _initials(name),
                ),
                Positioned(
                  bottom: 0, right: 0,
                  child: Container(
                    width: 28, height: 28,
                    decoration: BoxDecoration(
                      color: copperAccent, shape: BoxShape.circle,
                      border: Border.all(color: slateBg, width: 2),
                    ),
                    child: const Icon(Icons.camera_alt, size: 14, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Center(child: Text(name,
            style: const TextStyle(color: textPrimary, fontSize: 18, fontWeight: FontWeight.w800))),
        const SizedBox(height: 4),
        Center(child: Text(email,
            style: const TextStyle(color: textSecondary, fontSize: 13))),
        const SizedBox(height: 8),
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: copperAccent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(role.toUpperCase(),
                style: const TextStyle(color: copperAccent, fontSize: 11, fontWeight: FontWeight.w700)),
          ),
        ),
        const SizedBox(height: 32),

        // Info cards
        _InfoRow(icon: Icons.person_outline, label: 'Name', value: name),
        _InfoRow(icon: Icons.email_outlined, label: 'Email', value: email),
        _InfoRow(icon: Icons.shield_outlined, label: 'Role', value: role.toUpperCase()),
        _InfoRow(
          icon: Icons.circle,
          label: 'Status',
          value: (profile['isActive'] as bool? ?? true) ? 'Active' : 'Inactive',
          valueColor: (profile['isActive'] as bool? ?? true) ? emerald : crimson,
        ),
        const SizedBox(height: 32),

        // Edit button
        _PrimaryBtn(
          label: 'Edit Profile',
          onTap: () => _showEditSheet(context, ref, profile),
        ),
        const SizedBox(height: 12),
        _PrimaryBtn(
          label: 'Change Password',
          onTap: () => _showPasswordSheet(context, ref),
          secondary: true,
        ),
      ],
    );
  }

  Widget _initials(String name) => Text(
        name.isNotEmpty ? name.substring(0, 1).toUpperCase() : 'A',
        style: const TextStyle(color: copperAccent, fontSize: 36, fontWeight: FontWeight.w800),
      );

  Future<void> _pickAndUploadPhoto(BuildContext context, WidgetRef ref, String id) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: slateCard,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 12),
          ListTile(
            leading: const Icon(Icons.camera_alt_outlined, color: copperAccent),
            title: const Text('Camera', style: TextStyle(color: textPrimary)),
            onTap: () => Navigator.pop(context, ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined, color: copperAccent),
            title: const Text('Gallery', style: TextStyle(color: textPrimary)),
            onTap: () => Navigator.pop(context, ImageSource.gallery),
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
    if (source == null) return;

    final picked = await ImagePicker().pickImage(source: source, imageQuality: 80, maxWidth: 512);
    if (picked == null) return;

    try {
      final dio = createDioClient(ref.read(authProvider).token);
      // Bytes-based upload — fromFile() can't open blob: URLs on web.
      final bytes = await picked.readAsBytes();
      final formData = FormData.fromMap({
        'photo': MultipartFile.fromBytes(bytes, filename: picked.name),
      });
      await dio.post(
        '/users/$id/photo',
        data: formData,
        options: Options(headers: {'Idempotency-Key': newIdempotencyKey('profile-photo-$id')}),
      );
      // Refresh both: the profile screen's local FutureProvider AND the
      // shared authProvider.user so the AppBar avatar (and anything else
      // that watches it) picks up the new photoUrl without a re-login.
      // Force every place that renders the user's photo to refetch.
      // CachedNetworkImage keys on the URL itself, so the ?v=updatedAt
      // cache-buster takes care of the actual image bytes — but the
      // providers wrapping the data also need a kick or they keep
      // handing out the stale updatedAt and the URL never changes.
      ref.invalidate(_profileProvider);
      // Cross-screen invalidation: the same user appears in the admin
      // staff tab AND the manager staff tab; both keep their own
      // FutureProvider cache. Without this, switching tabs after a
      // photo upload shows the stale image until autoDispose kicks in.
      try { ref.invalidate(adminStaffProvider); } catch (_) {}
      try { ref.invalidate(managerStaffProvider); } catch (_) {}
      await ref.read(authProvider.notifier).refreshUser();
      if (context.mounted) _snack(context, 'Photo updated', emerald);
    } catch (e) {
      if (context.mounted) _snack(context, describeApiError(e), crimson);
    }
  }

  void _showEditSheet(BuildContext context, WidgetRef ref, Map<String, dynamic> profile) {
    showModalBottomSheet(
      context: context,
      backgroundColor: slateCard,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _EditProfileSheet(profile: profile),
    );
  }

  void _showPasswordSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: slateCard,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => const _ChangePasswordSheet(),
    );
  }

  void _snack(BuildContext context, String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color, behavior: SnackBarBehavior.floating),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;
  const _InfoRow({required this.icon, required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(color: slateCard, borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          Icon(icon, color: textSecondary, size: 16),
          const SizedBox(width: 12),
          Text(label, style: const TextStyle(color: textSecondary, fontSize: 13)),
          const Spacer(),
          Text(value,
              style: TextStyle(
                  color: valueColor ?? textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
        ]),
      );
}

class _Field extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  final bool obscure;
  final TextInputType? keyboardType;
  const _Field({required this.ctrl, required this.label, this.obscure = false, this.keyboardType});

  @override
  Widget build(BuildContext context) => TextField(
        controller: ctrl,
        obscureText: obscure,
        keyboardType: keyboardType,
        style: const TextStyle(color: textPrimary),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: textSecondary, fontSize: 13),
          filled: true,
          fillColor: slateSurface,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: dividerColor)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: dividerColor)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: copperAccent)),
        ),
      );
}

class _PrimaryBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool secondary;
  const _PrimaryBtn({required this.label, required this.onTap, this.secondary = false});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            gradient: secondary
                ? null
                : copperGradient,
            color: secondary ? slateSurface : null,
            borderRadius: BorderRadius.circular(12),
            border: secondary ? Border.all(color: dividerColor) : null,
          ),
          child: Center(
            child: Text(label,
                style: TextStyle(
                    color: secondary ? textSecondary : Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14)),
          ),
        ),
      );
}

// ── Edit profile sheet ───────────────────────────────────────────────────────
class _EditProfileSheet extends ConsumerStatefulWidget {
  final Map<String, dynamic> profile;
  const _EditProfileSheet({required this.profile});
  @override
  ConsumerState<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends ConsumerState<_EditProfileSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _emailCtrl;
  late final String _idempotencyKey;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.profile['name'] as String? ?? '');
    _emailCtrl = TextEditingController(text: widget.profile['email'] as String? ?? '');
    _idempotencyKey = newIdempotencyKey('profile-edit');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_submitting) return;
    if (_nameCtrl.text.trim().isEmpty) return;
    setState(() => _submitting = true);
    try {
      final dio = createDioClient(ref.read(authProvider).token);
      await dio.patch(
        '/auth/me',
        data: {
          'name': _nameCtrl.text.trim(),
          'email': _emailCtrl.text.trim(),
        },
        options: Options(headers: {'Idempotency-Key': _idempotencyKey}),
      );
      ref.invalidate(_profileProvider);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Profile updated'),
          backgroundColor: emerald,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(describeApiError(e)),
          backgroundColor: crimson,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Edit Profile',
              style: TextStyle(color: textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          _Field(ctrl: _nameCtrl, label: 'Full Name'),
          const SizedBox(height: 10),
          _Field(ctrl: _emailCtrl, label: 'Email', keyboardType: TextInputType.emailAddress),
          const SizedBox(height: 16),
          _PrimaryBtn(
            label: _submitting ? 'Saving…' : 'Save Changes',
            onTap: _submitting ? () {} : _save,
          ),
        ]),
      );
}

// ── Change password sheet ────────────────────────────────────────────────────
class _ChangePasswordSheet extends ConsumerStatefulWidget {
  const _ChangePasswordSheet();
  @override
  ConsumerState<_ChangePasswordSheet> createState() => _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends ConsumerState<_ChangePasswordSheet> {
  late final TextEditingController _ctrl;
  late final String _idempotencyKey;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController();
    _idempotencyKey = newIdempotencyKey('pwd-change');
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_submitting) return;
    if (_ctrl.text.length < 6) return;
    setState(() => _submitting = true);
    try {
      final dio = createDioClient(ref.read(authProvider).token);
      await dio.patch(
        '/auth/me',
        data: {'password': _ctrl.text},
        options: Options(headers: {'Idempotency-Key': _idempotencyKey}),
      );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Password updated'),
          backgroundColor: emerald,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(describeApiError(e)),
          backgroundColor: crimson,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Change Password',
              style: TextStyle(color: textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          _Field(ctrl: _ctrl, label: 'New Password (min 6 chars)', obscure: true),
          const SizedBox(height: 16),
          _PrimaryBtn(
            label: _submitting ? 'Updating…' : 'Update Password',
            onTap: _submitting ? () {} : _save,
          ),
        ]),
      );
}
