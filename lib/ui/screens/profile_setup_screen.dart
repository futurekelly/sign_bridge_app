// ProfileSetupScreen — premium onboarding profile completion.
// Features cascading animations, glassmorphism, and neon glow borders.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../controllers/accessibility_controller.dart';
import '../../core/enums.dart';
import '../../core/theme.dart';
import '../../core/spacing.dart';
import '../../core/routes.dart';
import '../../services/auth/auth_service.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> with TickerProviderStateMixin {
  final _auth = AuthService();
  
  // Controllers
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  
  UserRole _selectedRole = UserRole.both;
  bool _busy = false;
  String? _error;
  
  // Background Animation
  late AnimationController _bgAnimController;
  late Animation<Alignment> _bgAnimTop;
  late Animation<Alignment> _bgAnimBottom;

  // Cascading Card Animation
  late AnimationController _cascadeController;
  late Animation<Offset> _banner1Slide;
  late Animation<double> _banner1Fade;
  late Animation<Offset> _banner2Slide;
  late Animation<double> _banner2Fade;
  late Animation<Offset> _banner3Slide;
  late Animation<double> _banner3Fade;

  @override
  void initState() {
    super.initState();
    _prepopulateFields();

    // Background Gradient Animation
    _bgAnimController = AnimationController(
      vsync: this, 
      duration: const Duration(seconds: 10)
    )..repeat(reverse: true);
    
    _bgAnimTop = Tween<Alignment>(begin: Alignment.topLeft, end: Alignment.topRight)
        .animate(_bgAnimController);
    _bgAnimBottom = Tween<Alignment>(begin: Alignment.bottomRight, end: Alignment.bottomLeft)
        .animate(_bgAnimController);

    // Cascading Entrance Animation Setup (1.5 seconds total)
    _cascadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _banner1Slide = Tween<Offset>(begin: const Offset(0.4, 0), end: Offset.zero).animate(
      CurvedAnimation(
        parent: _cascadeController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOutCubic),
      ),
    );
    _banner1Fade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _cascadeController,
        curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
      ),
    );

    _banner2Slide = Tween<Offset>(begin: const Offset(0.4, 0), end: Offset.zero).animate(
      CurvedAnimation(
        parent: _cascadeController,
        curve: const Interval(0.25, 0.75, curve: Curves.easeOutCubic),
      ),
    );
    _banner2Fade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _cascadeController,
        curve: const Interval(0.25, 0.65, curve: Curves.easeOut),
      ),
    );

    _banner3Slide = Tween<Offset>(begin: const Offset(0.4, 0), end: Offset.zero).animate(
      CurvedAnimation(
        parent: _cascadeController,
        curve: const Interval(0.5, 1.0, curve: Curves.easeOutCubic),
      ),
    );
    _banner3Fade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _cascadeController,
        curve: const Interval(0.5, 0.9, curve: Curves.easeOut),
      ),
    );

    _cascadeController.forward();
  }

  void _prepopulateFields() {
    final user = _auth.currentUser;
    if (user != null) {
      final String displayName = user.displayName ?? '';
      _nameController.text = displayName;
      
      // Auto-suggest username from email prefix or display name
      String suggestPrefix = '';
      if (user.email != null && user.email!.contains('@')) {
        suggestPrefix = user.email!.split('@')[0];
      } else if (displayName.isNotEmpty) {
        suggestPrefix = displayName;
      }
      
      // Sanitize username suggest: lowercase, remove non-alphanumeric, max length 12
      final clean = suggestPrefix
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9_]'), '');
      
      if (clean.length > 12) {
        _usernameController.text = clean.substring(0, 12);
      } else if (clean.isNotEmpty) {
        _usernameController.text = clean;
      }
    }
  }

  @override
  void dispose() {
    _bgAnimController.dispose();
    _cascadeController.dispose();
    _nameController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _submitProfile() async {
    final a11y = context.read<AccessibilityController>();
    final displayName = _nameController.text.trim();
    final username = _usernameController.text.trim().toLowerCase();

    if (displayName.isEmpty) {
      setState(() => _error = a11y.t('login.name_required'));
      return;
    }

    if (username.isEmpty ||
        username.length < 3 ||
        username.length > 15 ||
        !RegExp(r'^[a-z0-9_]+$').hasMatch(username)) {
      setState(() => _error = a11y.t('profile_setup.id_invalid'));
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      // 1. Check unique username in Firestore
      final isUnique = await _auth.isUsernameUnique(username);
      if (!isUnique) {
        setState(() {
          _error = a11y.t('profile_setup.id_taken');
          _busy = false;
        });
        return;
      }

      // 2. Transaction setup for google/guest users to write to usernames doc and user doc atomically
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final usernameRef = FirebaseFirestore.instance.collection('usernames').doc(username);
        final userDocRef = FirebaseFirestore.instance.collection('users').doc(_auth.currentUser!.uid);

        final usernameSnap = await transaction.get(usernameRef);
        if (usernameSnap.exists) {
          throw Exception(a11y.t('profile_setup.id_taken'));
        }

        transaction.set(usernameRef, {'uid': _auth.currentUser!.uid});
        transaction.set(userDocRef, {
          'displayName': displayName,
          'signBridgeId': username,
          'uid': _auth.currentUser!.uid,
          'status': 'idle',
          'createdAt': FieldValue.serverTimestamp(),
          'lastLogin': FieldValue.serverTimestamp(),
          'provider': _auth.currentUser!.isAnonymous
              ? 'anonymous'
              : _auth.currentUser!.providerData.firstOrNull?.providerId ?? 'google',
        });
      });

      // 3. Update accessibility local role configuration
      await a11y.setRole(_selectedRole);

      if (!mounted) return;
      Navigator.pushReplacementNamed(context, AppRoutes.home);
    } catch (e) {
      debugPrint('[ProfileSetup] Submit Profile error: $e');
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '').replaceAll('FirebaseException: ', '');
        _busy = false;
      });
    }
  }

  Future<void> _logout() async {
    await _auth.signOut();
    if (mounted) {
      Navigator.pushReplacementNamed(context, AppRoutes.login);
    }
  }

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
          
          // Neon Glow Orbs
          Positioned(
            top: -50, right: -50,
            child: Container(
              width: 250, height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withValues(alpha: 0.25),
                backgroundBlendMode: isDark ? BlendMode.screen : BlendMode.multiply,
              ),
            ),
          ),
          Positioned(
            bottom: -50, left: -50,
            child: Container(
              width: 250, height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.secondary.withValues(alpha: 0.25),
                backgroundBlendMode: isDark ? BlendMode.screen : BlendMode.multiply,
              ),
            ),
          ),

          // Main Screen Content
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.xl),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Brand Identity Icon
                    Container(
                      width: 72, height: 72,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [AppColors.primary, AppColors.primaryLight],
                          begin: Alignment.topLeft, end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.4),
                            blurRadius: 16,
                            offset: const Offset(0, 6)
                          ),
                        ]
                      ),
                      child: const Icon(Icons.badge_outlined, size: 36, color: Colors.white),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      a11y.t('profile_setup.title'),
                      style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      a11y.t('profile_setup.subtitle'),
                      style: theme.textTheme.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    // Glassmorphic Glowing Setup Card
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.xl),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(AppSpacing.lg),
                          decoration: BoxDecoration(
                            color: theme.scaffoldBackgroundColor.withValues(alpha: isDark ? 0.45 : 0.65),
                            borderRadius: BorderRadius.circular(AppRadius.xl),
                            border: Border.all(color: AppColors.primary.withValues(alpha: 0.25), width: 1.5),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.15),
                                blurRadius: 24,
                                spreadRadius: 2,
                              ),
                            ]
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // ── BANNER 1: NAME AND LANGUAGE SELECTOR ──
                              FadeTransition(
                                opacity: _banner1Fade,
                                child: SlideTransition(
                                  position: _banner1Slide,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Preferred Language Header
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(a11y.t('profile_setup.lang_title'), style: theme.textTheme.titleSmall),
                                          Container(
                                            decoration: BoxDecoration(
                                              borderRadius: BorderRadius.circular(AppRadius.pill),
                                              border: Border.all(color: AppColors.primary.withValues(alpha: 0.35)),
                                              color: AppColors.primary.withValues(alpha: 0.06),
                                            ),
                                            child: Row(
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
                                        ],
                                      ),
                                      const SizedBox(height: AppSpacing.md),
                                      
                                      // Display Name Question Banner
                                      _buildSectionHeader(theme, a11y.t('profile_setup.how_to_call'), Icons.person_outline),
                                      const SizedBox(height: AppSpacing.sm),
                                      _buildNeumorphicInput(context, _nameController, a11y.t('profile_setup.display_name_hint')),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: AppSpacing.lg),

                              // ── BANNER 2: ROLE SELECTOR ──
                              FadeTransition(
                                opacity: _banner2Fade,
                                child: SlideTransition(
                                  position: _banner2Slide,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      _buildSectionHeader(theme, a11y.t('profile_setup.role_question'), Icons.accessibility_new_outlined),
                                      Text(a11y.t('profile_setup.role_desc'), style: theme.textTheme.bodySmall),
                                      const SizedBox(height: AppSpacing.sm),
                                      _buildRoleSelector(a11y, theme),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: AppSpacing.lg),

                              // ── BANNER 3: SIGNBRIDGE ID SELECTOR & SUBMIT ──
                              FadeTransition(
                                opacity: _banner3Fade,
                                child: SlideTransition(
                                  position: _banner3Slide,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      _buildSectionHeader(theme, a11y.t('profile_setup.create_id'), Icons.alternate_email_outlined),
                                      const SizedBox(height: AppSpacing.sm),
                                      _buildNeumorphicInput(context, _usernameController, a11y.t('profile_setup.create_id_hint'), isUsername: true),
                                      
                                      if (_error != null) ...[
                                        const SizedBox(height: AppSpacing.md),
                                        Container(
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            color: AppColors.error.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(AppRadius.md),
                                          ),
                                          child: Text(_error!, style: const TextStyle(color: AppColors.error, fontSize: 12), textAlign: TextAlign.center),
                                        ),
                                      ],
                                      
                                      const SizedBox(height: AppSpacing.xl),
                                      
                                      // Submit Button
                                      SizedBox(
                                        height: 50,
                                        child: ElevatedButton(
                                          onPressed: _busy ? null : _submitProfile,
                                          style: ElevatedButton.styleFrom(
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
                                            elevation: 8,
                                            shadowColor: AppColors.primary.withValues(alpha: 0.4),
                                          ),
                                          child: _busy
                                            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                                            : Text(a11y.t('profile_setup.submit'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    
                    // Cancel and Sign Out Button
                    TextButton.icon(
                      onPressed: _busy ? null : _logout,
                      icon: const Icon(Icons.arrow_back, size: 16),
                      label: Text(a11y.t('profile_setup.logout')),
                      style: TextButton.styleFrom(
                        foregroundColor: isDark ? Colors.white54 : Colors.black54,
                      ),
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

  Widget _buildSectionHeader(ThemeData theme, String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 6),
        Text(title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildNeumorphicInput(BuildContext context, TextEditingController controller, String hint, {bool isUsername = false}) {
    final theme = Theme.of(context);
    return Container(
      decoration: AppTheme.neumorphic(context, radius: AppRadius.md),
      child: TextField(
        controller: controller,
        style: theme.textTheme.bodyMedium,
        keyboardType: isUsername ? TextInputType.text : TextInputType.name,
        onChanged: isUsername 
            ? (val) {
                // Instantly force lowercase alphanumeric and underscores
                final clean = val.toLowerCase().replaceAll(RegExp(r'[^a-z0-9_]'), '');
                if (clean != val) {
                  controller.value = controller.value.copyWith(
                    text: clean,
                    selection: TextSelection.collapsed(offset: clean.length),
                  );
                }
              }
            : null,
        decoration: InputDecoration(
          hintText: hint,
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
