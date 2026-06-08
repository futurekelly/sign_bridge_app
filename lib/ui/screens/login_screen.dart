// LoginScreen — Google Auth + Email Auth + Guest
// Premium Redesign with Animated Glassmorphism and Neumorphic Inputs.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:ui';
import '../../controllers/accessibility_controller.dart';
import '../../core/constants.dart';
import '../../core/enums.dart';
import '../../core/theme.dart';
import '../../core/spacing.dart';
import '../../core/routes.dart';
import '../../services/auth/auth_service.dart';

enum AuthMode { login, signup }

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final _auth = AuthService();
  
  // Controllers
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController(); // Only for Sign Up
  
  AuthMode _authMode = AuthMode.login;
  bool _busy = false;
  String? _error;
  UserRole _selectedRole = UserRole.both; // Selected during sign-up
  bool _obscurePassword = true;

  // Background Animation
  late AnimationController _bgAnimController;
  late Animation<Alignment> _bgAnimTop;
  late Animation<Alignment> _bgAnimBottom;

  @override
  void initState() {
    super.initState();
    _checkExistingUser();
    
    _bgAnimController = AnimationController(
      vsync: this, 
      duration: const Duration(seconds: 10)
    )..repeat(reverse: true);
    
    _bgAnimTop = Tween<Alignment>(begin: Alignment.topLeft, end: Alignment.topRight)
        .animate(_bgAnimController);
    _bgAnimBottom = Tween<Alignment>(begin: Alignment.bottomRight, end: Alignment.bottomLeft)
        .animate(_bgAnimController);
  }

  Future<void> _checkExistingUser() async {
    if (_auth.currentUser != null) {
      final hasProfile = await _auth.hasProfile();
      if (hasProfile && mounted) {
        Navigator.pushReplacementNamed(context, AppRoutes.home);
      }
    }
  }

  @override
  void dispose() {
    _bgAnimController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  // --- Auth Handlers ---
  Future<void> _submitEmailAuth() async {
    final a11y = context.read<AccessibilityController>();
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = a11y.t('login.fill_fields'));
      return;
    }

    setState(() { _busy = true; _error = null; });
    try {
      if (_authMode == AuthMode.login) {
        await _auth.loginWithEmail(email, password);
      } else {
        final name = _nameController.text.trim();
        if (name.isEmpty) {
          setState(() { _error = a11y.t('login.name_required'); _busy = false; });
          return;
        }
        await _auth.registerWithEmail(email, password, name);
        if (mounted) context.read<AccessibilityController>().setRole(_selectedRole);
      }

      if (!mounted) return;
      Navigator.pushReplacementNamed(context, AppRoutes.home);
    } catch (e) {
      setState(() => _error = _cleanFirebaseError(e.toString()));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() { _busy = true; _error = null; });
    try {
      final user = await _auth.signInWithGoogle();
      if (user != null && mounted) {
        Navigator.pushReplacementNamed(context, AppRoutes.home);
      }
    } catch (e) {
      setState(() => _error = _cleanFirebaseError(e.toString()));
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
      Navigator.pushReplacementNamed(context, AppRoutes.home);
    } catch (e) {
      setState(() => _error = 'Guest login failed.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _cleanFirebaseError(String error) {
    if (error.contains('user-not-found')) return 'No account found with this email.';
    if (error.contains('wrong-password') || error.contains('invalid-credential')) return 'Incorrect password or email.';
    if (error.contains('email-already-in-use')) return 'Email already registered.';
    if (error.contains('weak-password')) return 'Password is too weak.';
    if (error.contains('operation-not-allowed')) {
      return 'Authentication provider disabled. Please enable Email/Password or Google auth in the Firebase Console.';
    }
    
    // Clean up typical Firebase exception text if present to make it readable
    String cleanMsg = error;
    if (cleanMsg.contains(']')) {
      cleanMsg = cleanMsg.substring(cleanMsg.indexOf(']') + 1).trim();
    }
    return 'Authentication failed: $cleanMsg';
  }

  void _switchMode() {
    setState(() {
      _authMode = _authMode == AuthMode.login ? AuthMode.signup : AuthMode.login;
      _error = null;
    });
  }

  // --- UI Components ---
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final a11y = context.watch<AccessibilityController>();
    final lang = a11y.languageCode;

    return Scaffold(
      body: Stack(
        children: [
          // Animated Gradient Background
          AnimatedBuilder(
            animation: _bgAnimController,
            builder: (context, _) {
              return Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: _bgAnimTop.value,
                    end: _bgAnimBottom.value,
                    colors: isDark 
                        ? [const Color(0xFF0F172A), const Color(0xFF1E1B4B), const Color(0xFF020617)]
                        : [const Color(0xFFE0F2FE), const Color(0xFFF3E8FF), const Color(0xFFF8FAFC)],
                  ),
                ),
              );
            },
          ),
          
          // Background Glow Orbs for Glassmorphism effect
          Positioned(
            top: -100, left: -100,
            child: Container(
              width: 300, height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withValues(alpha: 0.3),
                backgroundBlendMode: isDark ? BlendMode.screen : BlendMode.multiply,
              ),
            ),
          ),
          Positioned(
            bottom: -50, right: -50,
            child: Container(
              width: 250, height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.secondary.withValues(alpha: 0.3),
                backgroundBlendMode: isDark ? BlendMode.screen : BlendMode.multiply,
              ),
            ),
          ),

          // Main Scrollable Content
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.xl),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // ── Language toggle ──
                    Align(
                      alignment: Alignment.centerRight,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                          border: Border.all(
                              color: AppColors.primary.withValues(alpha: 0.35)),
                          color: AppColors.primary.withValues(alpha: 0.06),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _LangPill(
                              label: 'EN',
                              active: lang == 'en',
                              onTap: () => a11y.setLanguageCode('en'),
                            ),
                            _LangPill(
                              label: 'SW',
                              active: lang == 'sw',
                              onTap: () => a11y.setLanguageCode('sw'),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // Brand Logo
                    Container(
                      width: 80, height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [AppColors.primary, AppColors.primaryLight],
                          begin: Alignment.topLeft, end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(color: AppColors.primary.withValues(alpha: 0.4), blurRadius: 20, offset: const Offset(0, 8)),
                        ]
                      ),
                      child: const Icon(Icons.sign_language, size: 40, color: Colors.white),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(AppConstants.appName, style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: AppSpacing.xs),
                    Text(AppConstants.appTagline, style: theme.textTheme.bodySmall),
                    const SizedBox(height: AppSpacing.xl),

                    // Glassmorphic Auth Card
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.xl),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(AppSpacing.lg),
                          decoration: BoxDecoration(
                            color: theme.scaffoldBackgroundColor.withValues(alpha: isDark ? 0.4 : 0.6),
                            borderRadius: BorderRadius.circular(AppRadius.xl),
                            border: Border.all(color: Colors.white.withValues(alpha: isDark ? 0.1 : 0.4), width: 1.5),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 24, spreadRadius: -5),
                            ]
                          ),
                          child: AnimatedSize(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                            child: Column(
                              children: [
                                // Toggle Log In / Sign Up
                                _buildModeToggle(theme),
                                const SizedBox(height: AppSpacing.lg),

                                // Neumorphic Inputs
                                if (_authMode == AuthMode.signup) ...[
                                  _buildNeumorphicInput(context, _nameController, a11y.t('login.name'), Icons.person_outline),
                                  const SizedBox(height: AppSpacing.md),
                                ],
                                _buildNeumorphicInput(context, _emailController, a11y.t('login.email'), Icons.email_outlined, keyboardType: TextInputType.emailAddress),
                                const SizedBox(height: AppSpacing.md),
                                _buildNeumorphicInput(context, _passwordController, a11y.t('login.password'), Icons.lock_outline, isPassword: true),
                                
                                if (_authMode == AuthMode.signup) ...[
                                  const SizedBox(height: AppSpacing.lg),
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text(a11y.t('login.select_role'), style: theme.textTheme.titleSmall),
                                  ),
                                  const SizedBox(height: AppSpacing.sm),
                                  _buildRoleSelector(a11y, theme),
                                ],

                                if (_error != null) ...[
                                  const SizedBox(height: AppSpacing.md),
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(color: AppColors.error.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                                    child: Text(_error!, style: const TextStyle(color: AppColors.error, fontSize: 12), textAlign: TextAlign.center),
                                  ),
                                ],

                                const SizedBox(height: AppSpacing.xl),
                                
                                // Submit Button
                                SizedBox(
                                  width: double.infinity,
                                  height: 50,
                                  child: ElevatedButton(
                                    onPressed: _busy ? null : _submitEmailAuth,
                                    style: ElevatedButton.styleFrom(
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
                                      elevation: 8,
                                      shadowColor: AppColors.primary.withValues(alpha: 0.5),
                                    ),
                                    child: _busy
                                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                                      : Text(
                                          _authMode == AuthMode.login ? a11y.t('login.title_login') : a11y.t('login.title_signup'),
                                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                  ),
                                ),

                                const SizedBox(height: AppSpacing.lg),
                                Row(children: [
                                  Expanded(child: Divider(color: theme.dividerColor)),
                                  Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Text(a11y.t('login.or'), style: theme.textTheme.bodySmall)),
                                  Expanded(child: Divider(color: theme.dividerColor)),
                                ]),
                                const SizedBox(height: AppSpacing.lg),

                                // Google Auth Button
                                SizedBox(
                                  width: double.infinity,
                                  height: 50,
                                  child: OutlinedButton.icon(
                                    onPressed: _busy ? null : _signInWithGoogle,
                                    icon: const Icon(Icons.g_mobiledata, size: 30),
                                    label: Text(a11y.t('login.google'), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                                    style: OutlinedButton.styleFrom(
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
                                      side: BorderSide(color: theme.dividerColor, width: 1.5),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    TextButton(
                      onPressed: _busy ? null : _continueAsGuest,
                      child: Text(a11y.t('login.guest'), style: TextStyle(color: theme.textTheme.bodySmall?.color)),
                    )
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeToggle(ThemeData theme) {
    final a11y = context.read<AccessibilityController>();
    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Row(
        children: [
          Expanded(child: _buildToggleBtn(a11y.t('login.title_login'), AuthMode.login, theme)),
          Expanded(child: _buildToggleBtn(a11y.t('login.title_signup'), AuthMode.signup, theme)),
        ],
      ),
    );
  }

  Widget _buildToggleBtn(String text, AuthMode mode, ThemeData theme) {
    final isSelected = _authMode == mode;
    return GestureDetector(
      onTap: _switchMode,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          boxShadow: isSelected ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 2))] : null,
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isSelected ? Colors.white : theme.textTheme.bodyMedium?.color,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildNeumorphicInput(BuildContext context, TextEditingController controller, String hint, IconData icon, {bool isPassword = false, TextInputType? keyboardType}) {
    final theme = Theme.of(context);
    return Container(
      decoration: AppTheme.neumorphic(context, radius: AppRadius.md),
      child: TextField(
        controller: controller,
        obscureText: isPassword && _obscurePassword,
        keyboardType: keyboardType,
        style: theme.textTheme.bodyMedium,
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: Icon(icon, size: 20),
          suffixIcon: isPassword 
            ? IconButton(
                icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, size: 20),
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              )
            : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  Widget _buildRoleSelector(AccessibilityController a11y, ThemeData theme) {
    return Row(
      children: [
        _buildRoleChip(a11y.t('settings.deaf'), UserRole.deaf, Icons.sign_language, theme),
        const SizedBox(width: 8),
        _buildRoleChip(a11y.t('settings.hearing'), UserRole.hearing, Icons.hearing, theme),
        const SizedBox(width: 8),
        _buildRoleChip(a11y.t('settings.both'), UserRole.both, Icons.accessibility_new, theme),
      ],
    );
  }

  Widget _buildRoleChip(String label, UserRole role, IconData icon, ThemeData theme) {
    final isSelected = _selectedRole == role;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedRole = role),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary.withValues(alpha: 0.1) : theme.scaffoldBackgroundColor.withValues(alpha: 0.5),
            border: Border.all(color: isSelected ? AppColors.primary : Colors.transparent),
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Column(
            children: [
              Icon(icon, size: 20, color: isSelected ? AppColors.primary : Colors.grey),
              const SizedBox(height: 4),
              Text(label, style: TextStyle(fontSize: 11, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: isSelected ? AppColors.primary : Colors.grey)),
            ],
          ),
        ),
      ),
    );
  }
}

class _LangPill extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _LangPill({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.white : Colors.grey,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}