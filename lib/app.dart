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
import 'ui/widgets/boot_gate.dart';

class SignBridgeApp extends StatelessWidget {
  const SignBridgeApp({super.key});

  @override
  Widget build(BuildContext context) {
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
          // BootGate decides between onboarding / login / profile setup / home
          // *before* building any of them, so an already-signed-in user never
          // sees the login form. See lib/ui/widgets/boot_gate.dart for why
          // this is not just an initialRoute.
          home: const BootGate(),
          routes: AppRoutes.routes,
          navigatorKey: AppRoutes.navigatorKey,
        ),
      ),
    );
  }
}