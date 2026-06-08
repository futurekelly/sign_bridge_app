// OnboardingScreen — 4-page intro with language toggle and full bilingual support.
// Language toggle sits in the top-right corner alongside the Skip button.

import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:provider/provider.dart';
import '../../controllers/accessibility_controller.dart';
import '../../core/theme.dart';
import '../../core/spacing.dart';
import '../../core/routes.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  static bool get hasSeenOnboarding {
    final box = Hive.box('app_settings');
    return box.get('hasSeenOnboarding', defaultValue: false) as bool;
  }

  static Future<void> markComplete() async {
    final box = Hive.box('app_settings');
    await box.put('hasSeenOnboarding', true);
  }

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageController = PageController();
  int _currentPage = 0;

  // Page data as keys — resolved via a11y.t() at build time
  static const _pageKeys = [
    ('onboarding.welcome_title', 'onboarding.welcome_desc',
        Icons.sign_language, AppColors.primary),
    ('onboarding.video_title', 'onboarding.video_desc',
        Icons.video_call, AppColors.secondary),
    ('onboarding.ai_title', 'onboarding.ai_desc',
        Icons.auto_awesome, AppColors.accent),
    ('onboarding.access_title', 'onboarding.access_desc',
        Icons.accessibility_new, Color(0xFFF59E0B)),
  ];

  void _next(AccessibilityController a11y) {
    if (_currentPage < _pageKeys.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _finish();
    }
  }

  Future<void> _finish() async {
    await OnboardingScreen.markComplete();
    if (mounted) Navigator.pushReplacementNamed(context, AppRoutes.login);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final a11y = context.watch<AccessibilityController>();
    final lang = a11y.languageCode;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // ── Top bar: Language toggle + Skip ──
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md, vertical: AppSpacing.sm),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Premium language toggle pill
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.3)),
                      color: AppColors.primary.withValues(alpha: 0.05),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _LangButton(
                          label: 'EN',
                          active: lang == 'en',
                          onTap: () => a11y.setLanguageCode('en'),
                        ),
                        _LangButton(
                          label: 'SW',
                          active: lang == 'sw',
                          onTap: () => a11y.setLanguageCode('sw'),
                        ),
                      ],
                    ),
                  ),
                  // Skip button
                  TextButton(
                    onPressed: _finish,
                    child: Text(
                      a11y.t('onboarding.skip'),
                      style: TextStyle(
                          color: theme.textTheme.bodySmall?.color,
                          fontSize: 15),
                    ),
                  ),
                ],
              ),
            ),

            // ── Pages ──
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (i) => setState(() => _currentPage = i),
                itemCount: _pageKeys.length,
                itemBuilder: (_, i) {
                  final (titleKey, descKey, icon, color) = _pageKeys[i];
                  return _OnboardingPage(
                    icon: icon,
                    iconColor: color,
                    title: a11y.t(titleKey),
                    description: a11y.t(descKey),
                  );
                },
              ),
            ),

            // ── Dots + Next/Get Started button ──
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg, vertical: AppSpacing.xl),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: List.generate(
                      _pageKeys.length,
                      (i) => AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        margin: const EdgeInsets.only(right: 8),
                        width: _currentPage == i ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _currentPage == i
                              ? AppColors.primary
                              : AppColors.primary.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () => _next(a11y),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 28, vertical: 14),
                    ),
                    child: Text(
                      _currentPage == _pageKeys.length - 1
                          ? a11y.t('onboarding.get_started')
                          : a11y.t('onboarding.next'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Language toggle button ──
class _LangButton extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _LangButton(
      {required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: active ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: active ? Colors.white : AppColors.primary,
          ),
        ),
      ),
    );
  }
}

// ── Single onboarding page ──
class _OnboardingPage extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String description;

  const _OnboardingPage({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding:
          const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  iconColor.withValues(alpha: 0.15),
                  iconColor.withValues(alpha: 0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Icon(icon, size: 56, color: iconColor),
          ),
          const SizedBox(height: 40),
          Text(title,
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineMedium),
          const SizedBox(height: 16),
          Text(
            description,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.textTheme.bodySmall?.color,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
