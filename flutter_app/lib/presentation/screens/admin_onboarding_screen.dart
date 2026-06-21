// ─── Admin Onboarding Wizard ─────────────────────────────────────────────────
//
// Shown on first admin login when no branches exist. Walks the new admin
// through three concrete steps:
//   1. Welcome screen — explains what this is + the path ahead.
//   2. Create the first branch — name + slug, posts to /branches.
//   3. Invite the first manager for that branch — email + name,
//      posts to /users.
//   4. (Optional) Seed a starter menu — minimal name + price + category,
//      can be skipped.
//
// Each step animates in with a copper crest motif consistent with the
// splash. The wizard stores its position in local state only — if the
// admin kills the app halfway, the next launch re-checks /branches and
// resumes at the right step rather than restarting at zero.

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/config/app_theme.dart';
import '../../core/network/dio_client.dart';
import '../../core/utils/api_error.dart';
import '../../core/utils/idempotency.dart';
import '../state/auth_provider.dart';

class AdminOnboardingScreen extends ConsumerStatefulWidget {
  const AdminOnboardingScreen({super.key});

  @override
  ConsumerState<AdminOnboardingScreen> createState() =>
      _AdminOnboardingScreenState();
}

class _AdminOnboardingScreenState
    extends ConsumerState<AdminOnboardingScreen> {
  int _step = 0;
  String? _createdBranchId;
  String? _createdBranchName;
  bool _busy = false;

  // Step 2 — branch
  final _branchNameCtrl = TextEditingController();
  final _branchAddrCtrl = TextEditingController();
  final _branchSlugCtrl = TextEditingController();

  // Step 3 — manager
  final _mgrNameCtrl = TextEditingController();
  final _mgrEmailCtrl = TextEditingController();
  final _mgrPwdCtrl = TextEditingController();

  // Step 4 — first menu item
  final _itemNameCtrl = TextEditingController();
  final _itemCatCtrl = TextEditingController(text: 'Starters');
  final _itemPriceCtrl = TextEditingController();

  @override
  void dispose() {
    _branchNameCtrl.dispose();
    _branchAddrCtrl.dispose();
    _branchSlugCtrl.dispose();
    _mgrNameCtrl.dispose();
    _mgrEmailCtrl.dispose();
    _mgrPwdCtrl.dispose();
    _itemNameCtrl.dispose();
    _itemCatCtrl.dispose();
    _itemPriceCtrl.dispose();
    super.dispose();
  }

  // ── API calls ────────────────────────────────────────────────────────────

  Future<void> _createBranch() async {
    final name = _branchNameCtrl.text.trim();
    final addr = _branchAddrCtrl.text.trim();
    final slug = _branchSlugCtrl.text.trim().toLowerCase();
    if (name.isEmpty || addr.isEmpty || slug.isEmpty) {
      _snack('Fill in name, address, and slug.');
      return;
    }
    setState(() => _busy = true);
    try {
      final dio = createDioClient(ref.read(authProvider).token);
      final res = await dio.post(
        '/branches',
        data: {'name': name, 'address': addr, 'slug': slug},
        options: Options(headers: {
          'Idempotency-Key': newIdempotencyKey('onboard-branch'),
        }),
      );
      _createdBranchId = (res.data['_id'] ?? res.data['id'])?.toString();
      _createdBranchName = name;
      _snack('Branch "$name" created.', emerald);
      setState(() => _step = 2);
    } catch (e) {
      _snack(describeApiError(e), crimson);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _createManager() async {
    final name = _mgrNameCtrl.text.trim();
    final email = _mgrEmailCtrl.text.trim();
    final pwd = _mgrPwdCtrl.text;
    if (name.isEmpty ||
        email.isEmpty ||
        pwd.isEmpty ||
        _createdBranchId == null) {
      _snack('Fill all fields.');
      return;
    }
    setState(() => _busy = true);
    try {
      final dio = createDioClient(ref.read(authProvider).token);
      await dio.post(
        '/users',
        data: {
          'name': name,
          'email': email,
          'password': pwd,
          'role': 'manager',
          'branchId': _createdBranchId,
        },
        options: Options(headers: {
          'Idempotency-Key': newIdempotencyKey('onboard-mgr'),
        }),
      );
      _snack('Manager "$name" invited.', emerald);
      setState(() => _step = 3);
    } catch (e) {
      _snack(describeApiError(e), crimson);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _seedMenu({bool skip = false}) async {
    if (skip) {
      _finish();
      return;
    }
    final name = _itemNameCtrl.text.trim();
    final cat = _itemCatCtrl.text.trim();
    final price = double.tryParse(_itemPriceCtrl.text);
    if (name.isEmpty || cat.isEmpty || price == null) {
      _snack('Fill name, category, and price (or tap Skip).');
      return;
    }
    setState(() => _busy = true);
    try {
      final dio = createDioClient(ref.read(authProvider).token);
      await dio.post(
        '/menu',
        data: {
          'branchId': _createdBranchId,
          'name': name,
          'category': cat,
          'basePrice': price,
        },
        options: Options(headers: {
          'Idempotency-Key': newIdempotencyKey('onboard-menu'),
        }),
      );
      _snack('First menu item added.', emerald);
      _finish();
    } catch (e) {
      _snack(describeApiError(e), crimson);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _finish() {
    Navigator.of(context).pop();
  }

  void _snack(String msg, [Color color = amber]) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
    ));
  }

  // ── UI ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
          child: Column(children: [
            _ProgressBar(step: _step, total: 4),
            const SizedBox(height: 24),
            Expanded(child: _stepBody()),
          ]),
        ),
      ),
    );
  }

  Widget _stepBody() {
    switch (_step) {
      case 0:
        return _StepWelcome(onNext: () => setState(() => _step = 1));
      case 1:
        return _StepBranch(
          nameCtrl: _branchNameCtrl,
          addrCtrl: _branchAddrCtrl,
          slugCtrl: _branchSlugCtrl,
          busy: _busy,
          onNext: _createBranch,
        );
      case 2:
        return _StepManager(
          nameCtrl: _mgrNameCtrl,
          emailCtrl: _mgrEmailCtrl,
          pwdCtrl: _mgrPwdCtrl,
          busy: _busy,
          branchName: _createdBranchName ?? '',
          onNext: _createManager,
        );
      case 3:
        return _StepMenu(
          nameCtrl: _itemNameCtrl,
          catCtrl: _itemCatCtrl,
          priceCtrl: _itemPriceCtrl,
          busy: _busy,
          onSubmit: () => _seedMenu(),
          onSkip: () => _seedMenu(skip: true),
        );
    }
    return const SizedBox.shrink();
  }
}

// ── Progress bar ────────────────────────────────────────────────────────────

class _ProgressBar extends StatelessWidget {
  final int step;
  final int total;
  const _ProgressBar({required this.step, required this.total});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      for (int i = 0; i < total; i++) ...[
        Expanded(
          child: Container(
            height: 4,
            decoration: BoxDecoration(
              color: i <= step ? copperAccent : slateSurface,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        if (i < total - 1) const SizedBox(width: 6),
      ],
    ]);
  }
}

// ── Step 1: Welcome ────────────────────────────────────────────────────────

class _StepWelcome extends StatelessWidget {
  final VoidCallback onNext;
  const _StepWelcome({required this.onNext});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      const Spacer(),
      Container(
        width: 96, height: 96,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const RadialGradient(
              colors: [Color(0xFF2A1810), Color(0xFF150B07)]),
          boxShadow: [
            BoxShadow(
              color: copperAccent.withValues(alpha: 0.5),
              blurRadius: 36,
              spreadRadius: 4,
            ),
          ],
        ),
        child: const Icon(Icons.celebration_outlined,
            color: copperAccent, size: 46),
      ).animate().scaleXY(
          begin: 0.4,
          end: 1.0,
          duration: 600.ms,
          curve: Curves.elasticOut),
      const SizedBox(height: 24),
      const Text('WELCOME TO DINE OPS',
              style: TextStyle(
                  color: textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 4))
          .animate()
          .fadeIn(delay: 250.ms, duration: 400.ms),
      const SizedBox(height: 8),
      const Padding(
        padding: EdgeInsets.symmetric(horizontal: 18),
        child: Text(
          'Let us set up your first branch in three quick steps. Should take less than a minute.',
          textAlign: TextAlign.center,
          style: TextStyle(color: textSecondary, fontSize: 13, height: 1.5),
        ),
      ).animate().fadeIn(delay: 450.ms, duration: 400.ms),
      const SizedBox(height: 28),
      _StepList(items: const [
        ('Create a branch', 'Name, address, URL slug.'),
        ('Invite the first manager', 'They will get login credentials.'),
        ('Seed a starter menu', 'Optional — you can skip this step.'),
      ]),
      const Spacer(),
      _PrimaryBtn(label: 'Start', onTap: onNext),
    ]);
  }
}

class _StepList extends StatelessWidget {
  final List<(String, String)> items;
  const _StepList({required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      for (var i = 0; i < items.length; i++) ...[
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 26, height: 26,
            decoration: BoxDecoration(
              color: copperAccent.withValues(alpha: 0.15),
              shape: BoxShape.circle,
              border: Border.all(color: copperAccent, width: 1),
            ),
            alignment: Alignment.center,
            child: Text('${i + 1}',
                style: const TextStyle(
                    color: copperAccent,
                    fontSize: 11,
                    fontWeight: FontWeight.w800)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(items[i].$1,
                  style: const TextStyle(
                      color: textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(items[i].$2,
                  style: const TextStyle(
                      color: textSecondary, fontSize: 11)),
            ]),
          ),
        ])
            .animate()
            .fadeIn(delay: (600 + i * 100).ms, duration: 350.ms)
            .slideX(begin: 0.2, end: 0, duration: 350.ms),
        if (i < items.length - 1) const SizedBox(height: 14),
      ],
    ]);
  }
}

// ── Step 2: Branch ─────────────────────────────────────────────────────────

class _StepBranch extends StatelessWidget {
  final TextEditingController nameCtrl;
  final TextEditingController addrCtrl;
  final TextEditingController slugCtrl;
  final bool busy;
  final VoidCallback onNext;
  const _StepBranch({
    required this.nameCtrl,
    required this.addrCtrl,
    required this.slugCtrl,
    required this.busy,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(children: [
      const _StepTitle(
        icon: Icons.store_outlined,
        title: 'Your first branch',
        subtitle:
            'A branch is one physical restaurant. Staff, inventory, orders, and reports are all isolated per branch.',
      ),
      const SizedBox(height: 22),
      _Field(ctrl: nameCtrl, label: 'Branch name', hint: 'e.g. Indiranagar'),
      const SizedBox(height: 12),
      _Field(
          ctrl: addrCtrl,
          label: 'Address',
          hint: 'e.g. 12th Main, Bengaluru'),
      const SizedBox(height: 12),
      _Field(
          ctrl: slugCtrl,
          label: 'URL slug',
          hint: 'e.g. indiranagar — used in the QR URL'),
      const SizedBox(height: 26),
      _PrimaryBtn(label: busy ? 'Creating…' : 'Create branch', onTap: onNext),
    ]);
  }
}

// ── Step 3: Manager ────────────────────────────────────────────────────────

class _StepManager extends StatelessWidget {
  final TextEditingController nameCtrl;
  final TextEditingController emailCtrl;
  final TextEditingController pwdCtrl;
  final bool busy;
  final String branchName;
  final VoidCallback onNext;
  const _StepManager({
    required this.nameCtrl,
    required this.emailCtrl,
    required this.pwdCtrl,
    required this.busy,
    required this.branchName,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(children: [
      _StepTitle(
        icon: Icons.manage_accounts_outlined,
        title: 'Invite a manager',
        subtitle:
            'They will run "$branchName" day to day. Share the credentials securely (1Password / Signal); they should change the password on first login.',
      ),
      const SizedBox(height: 22),
      _Field(ctrl: nameCtrl, label: 'Full name'),
      const SizedBox(height: 12),
      _Field(
          ctrl: emailCtrl,
          label: 'Email',
          keyboardType: TextInputType.emailAddress),
      const SizedBox(height: 12),
      _Field(ctrl: pwdCtrl, label: 'Temporary password', obscure: true),
      const SizedBox(height: 26),
      _PrimaryBtn(label: busy ? 'Inviting…' : 'Invite manager', onTap: onNext),
    ]);
  }
}

// ── Step 4: Menu ───────────────────────────────────────────────────────────

class _StepMenu extends StatelessWidget {
  final TextEditingController nameCtrl;
  final TextEditingController catCtrl;
  final TextEditingController priceCtrl;
  final bool busy;
  final VoidCallback onSubmit;
  final VoidCallback onSkip;
  const _StepMenu({
    required this.nameCtrl,
    required this.catCtrl,
    required this.priceCtrl,
    required this.busy,
    required this.onSubmit,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(children: [
      const _StepTitle(
        icon: Icons.restaurant_menu_outlined,
        title: 'Seed your menu',
        subtitle:
            'Optional — add one starter item so customers see something the moment they scan. You can add the rest from the Menu tab.',
      ),
      const SizedBox(height: 22),
      _Field(ctrl: nameCtrl, label: 'Item name', hint: 'e.g. Paneer Tikka'),
      const SizedBox(height: 12),
      _Field(ctrl: catCtrl, label: 'Category', hint: 'e.g. Starters'),
      const SizedBox(height: 12),
      _Field(
          ctrl: priceCtrl,
          label: 'Base price (₹)',
          keyboardType: TextInputType.number),
      const SizedBox(height: 26),
      Row(children: [
        Expanded(
          child: _SecondaryBtn(label: 'Skip', onTap: onSkip),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _PrimaryBtn(label: busy ? 'Adding…' : 'Add + Finish', onTap: onSubmit),
        ),
      ]),
    ]);
  }
}

// ── Shared widgets ──────────────────────────────────────────────────────────

class _StepTitle extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _StepTitle({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: copperAccent.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: copperAccent, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(title,
              style: const TextStyle(
                  color: textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w800)),
        ),
      ]),
      const SizedBox(height: 10),
      Text(subtitle,
          style: const TextStyle(
              color: textSecondary, fontSize: 12, height: 1.5)),
    ]).animate().fadeIn(duration: 350.ms);
  }
}

class _Field extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  final String? hint;
  final bool obscure;
  final TextInputType? keyboardType;
  const _Field({
    required this.ctrl,
    required this.label,
    this.hint,
    this.obscure = false,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: ctrl,
      obscureText: obscure,
      keyboardType: keyboardType,
      style: const TextStyle(color: textPrimary, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: const TextStyle(color: textSecondary, fontSize: 12),
        hintStyle: const TextStyle(color: textSecondary, fontSize: 12),
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
    );
  }
}

class _PrimaryBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _PrimaryBtn({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          gradient: copperGradient,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(label,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  letterSpacing: 1.5)),
        ),
      ),
    );
  }
}

class _SecondaryBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _SecondaryBtn({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: slateSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: dividerColor),
        ),
        child: Center(
          child: Text(label,
              style: const TextStyle(
                  color: textSecondary,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  letterSpacing: 1.5)),
        ),
      ),
    );
  }
}
