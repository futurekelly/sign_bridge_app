// OnboardingScreen — 3-page intro shown once on first launch.
// Users can skip or complete it. Stores a flag in Hive so it
// never shows again.

import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../../core/theme.dart';
import '../../core/routes.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  /// Check whether onboarding has been completed.
  static bool get hasSeenOnboarding {
    final box = Hive.box('app_settings');
    return box.get('hasSeenOnboarding', defaultValue: false) as bool;
  }

  /// Mark onboarding as complete.
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

  static const _pages = [
    _PageData(
      icon: Icons.sign_language,
      iconColor: AppTheme.primary,
      title: 'Welcome to SignBridge',
      description:
          'A two-way sign language recognition and speech translation '
          'system. Bridging communication between deaf and hearing users '
          'in real-time.',
    ),
    _PageData(
      icon: Icons.video_call,
      iconColor: AppTheme.secondary,
      title: 'Real-Time Video Calls',
      description:
          'Create or join a video call with a unique Call ID. Share the '
          'ID with your peer to connect instantly. AI translation runs '
          'on your device — no internet required for processing.',
    ),
    _PageData(
      icon: Icons.auto_awesome,
      iconColor: Colors.purple,
      title: 'AI-Powered Translation',
      description:
          'Sign language gestures are recognized and converted to text '
          'and speech. Spoken words are converted to text and sign '
          'language GIFs. All processing happens on your phone!',
    ),
  ];

  void _next() {
    if (_currentPage < _pages.length - 1) {
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
    if (mounted) {
      Navigator.pushReplacementNamed(context, AppRoutes.login);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // ── Skip button ──
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: TextButton(
                  onPressed: _finish,
                  child: const Text(
                    'Skip',
                    style: TextStyle(color: AppTheme.textMuted, fontSize: 15),
                  ),
                ),
              ),
            ),

            // ── Pages ──
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (i) => setState(() => _currentPage = i),
                itemCount: _pages.length,
                itemBuilder: (_, i) => _OnboardingPage(data: _pages[i]),
              ),
            ),

            // ── Dots + button ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Page indicator dots
                  Row(
                    children: List.generate(
                      _pages.length,
                      (i) => AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        margin: const EdgeInsets.only(right: 8),
                        width: _currentPage == i ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _currentPage == i
                              ? AppTheme.primary
                              : AppTheme.primary.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),

                  // Next / Get Started button
                  ElevatedButton(
                    onPressed: _next,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 28, vertical: 14),
                    ),
                    child: Text(
                      _currentPage == _pages.length - 1
                          ? 'Get Started'
                          : 'Next',
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

// ── Page data model ──
class _PageData {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String description;

  const _PageData({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.description,
  });
}

// ── Individual onboarding page ──
class _OnboardingPage extends StatelessWidget {
  final _PageData data;
  const _OnboardingPage({required this.data});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: data.iconColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(data.icon, size: 56, color: data.iconColor),
          ),
          const SizedBox(height: 40),
          Text(
            data.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppTheme.textDark,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            data.description,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15,
              color: AppTheme.textMuted,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
