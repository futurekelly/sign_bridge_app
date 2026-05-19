// LoginScreen — Anonymous auth + display name + role selection.
// Redesigned with neumorphic styling and dark/light support.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../controllers/accessibility_controller.dart';
import '../../core/constants.dart';
import '../../core/enums.dart';
import '../../core/theme.dart';
import '../../core/spacing.dart';
import '../../core/routes.dart';
import '../../services/auth/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _auth = AuthService();
  final _nameController = TextEditingController();
  bool _busy = false;
  String? _error;
  bool _isReturningUser = false;
  UserRole _selectedRole = UserRole.both;

  @override
  void initState() {
    super.initState();
    _checkExistingUser();
  }

  Future<void> _checkExistingUser() async {
    if (_auth.currentUser != null) {
      final hasProfile = await _auth.hasProfile();
      if (hasProfile && mounted) {
        Navigator.pushReplacementNamed(context, AppRoutes.home);
        return;
      }
      if (mounted) setState(() => _isReturningUser = true);
    }
  }

  Future<void> _continue() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Please enter your name');
      return;
    }
    setState(() { _busy = true; _error = null; });
    try {
      await _auth.signInAnonymously();
      await _auth.saveUserProfile(name);
      if (!mounted) return;
      context.read<AccessibilityController>().setRole(_selectedRole);
      Navigator.pushReplacementNamed(context, AppRoutes.home);
    } catch (e) {
      setState(() => _error = 'Sign-in failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _continueAsGuest() async {
    setState(() { _busy = true; _error = null; });
    try {
      await _auth.signInAnonymously();
      await _auth.saveUserProfile('Guest');
      if (!mounted) return;
      context.read<AccessibilityController>().setRole(_selectedRole);
      Navigator.pushReplacementNamed(context, AppRoutes.home);
    } catch (e) {
      setState(() => _error = 'Sign-in failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() { _nameController.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MediaQuery.of(context).size.height -
                  MediaQuery.of(context).padding.top -
                  MediaQuery.of(context).padding.bottom - 48,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Logo ──
                Container(
                  width: 90, height: 90,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [AppColors.primary, AppColors.primaryLight],
                      begin: Alignment.topLeft, end: Alignment.bottomRight,
                    ),
                  ),
                  child: const Icon(Icons.sign_language, size: 44, color: Colors.white),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(AppConstants.appName, textAlign: TextAlign.center,
                    style: theme.textTheme.headlineMedium),
                const SizedBox(height: AppSpacing.xs),
                Text(AppConstants.appTagline, textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall),

                const SizedBox(height: AppSpacing.xl),

                // ── Name Input (neumorphic) ──
                Container(
                  decoration: AppTheme.neumorphic(context, radius: AppRadius.lg),
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('What should we call you?',
                          style: theme.textTheme.titleMedium),
                      const SizedBox(height: AppSpacing.sm),
                      TextField(
                        controller: _nameController,
                        autofocus: !_isReturningUser,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          hintText: 'Enter your display name',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                        onSubmitted: (_) => _continue(),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: AppSpacing.md),

                // ── Role Selection (neumorphic) ──
                Container(
                  decoration: AppTheme.neumorphic(context, radius: AppRadius.lg),
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('How do you communicate?',
                          style: theme.textTheme.titleMedium),
                      const SizedBox(height: AppSpacing.xs),
                      Text('This personalises your experience.',
                          style: theme.textTheme.bodySmall),
                      const SizedBox(height: AppSpacing.md),
                      _RoleOption(
                        role: UserRole.deaf,
                        selected: _selectedRole,
                        icon: Icons.sign_language,
                        title: 'Deaf User',
                        subtitle: 'Visual-first: sign GIFs, captions, visual alerts',
                        onTap: () => setState(() => _selectedRole = UserRole.deaf),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      _RoleOption(
                        role: UserRole.hearing,
                        selected: _selectedRole,
                        icon: Icons.hearing,
                        title: 'Hearing User',
                        subtitle: 'Audio-first: speech controls, optional captions',
                        onTap: () => setState(() => _selectedRole = UserRole.hearing),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      _RoleOption(
                        role: UserRole.both,
                        selected: _selectedRole,
                        icon: Icons.accessibility_new,
                        title: 'Both',
                        subtitle: 'Full feature set for all communication styles',
                        onTap: () => setState(() => _selectedRole = UserRole.both),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: AppSpacing.lg),

                // ── Continue button ──
                ElevatedButton(
                  onPressed: _busy ? null : _continue,
                  child: _busy
                      ? const SizedBox(height: 20, width: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                      : const Text('Get Started'),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextButton(
                  onPressed: _busy ? null : _continueAsGuest,
                  child: Text('Continue as Guest',
                      style: TextStyle(color: theme.textTheme.bodySmall?.color)),
                ),

                if (_error != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  Text(_error!, textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.error)),
                ],

                const SizedBox(height: AppSpacing.sm),
                Text('Your name will be shown to other users during calls.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(fontSize: 11)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Role selection option ──
class _RoleOption extends StatelessWidget {
  final UserRole role;
  final UserRole selected;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _RoleOption({
    required this.role, required this.selected, required this.icon,
    required this.title, required this.subtitle, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = role == selected;
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.08)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: (isSelected ? AppColors.primary : Colors.grey)
                    .withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Icon(icon, color: isSelected ? AppColors.primary : Colors.grey, size: 20),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isSelected ? AppColors.primary : null)),
                  Text(subtitle, style: theme.textTheme.bodySmall?.copyWith(fontSize: 11)),
                ],
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle, color: AppColors.primary, size: 20),
          ],
        ),
      ),
    );
  }
}