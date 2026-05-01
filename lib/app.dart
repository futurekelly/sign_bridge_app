// Root application widget.
// Sets up MaterialApp, theme, and the named-route system.
// Chooses initial route based on onboarding and auth state.

import 'package:flutter/material.dart';
import 'core/theme.dart';
import 'core/routes.dart';
import 'core/constants.dart';
import 'ui/screens/onboarding_screen.dart';

class SignBridgeApp extends StatelessWidget {
  const SignBridgeApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Decide initial route:
    // 1. If first launch → onboarding
    // 2. Otherwise → login (which auto-skips to home if already signed in)
    final initialRoute = OnboardingScreen.hasSeenOnboarding
        ? AppRoutes.login
        : AppRoutes.onboarding;

    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      initialRoute: initialRoute,
      routes: AppRoutes.routes,
    );
  }
}