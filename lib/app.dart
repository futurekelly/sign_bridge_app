// Root application widget.
// Sets up MaterialApp with MultiProvider for theme + accessibility,
// dark/light theme switching, and the named-route system.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'controllers/theme_controller.dart';
import 'controllers/accessibility_controller.dart';
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

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeController()),
        ChangeNotifierProvider(create: (_) => AccessibilityController()),
      ],
      child: Consumer<ThemeController>(
        builder: (_, themeCtrl, __) => MaterialApp(
          title: AppConstants.appName,
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeCtrl.themeMode,
          initialRoute: initialRoute,
          routes: AppRoutes.routes,
          navigatorKey: AppRoutes.navigatorKey,
        ),
      ),
    );
  }
}