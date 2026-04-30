// Root application widget.
// Sets up MaterialApp, theme, and the named-route system.

import 'package:flutter/material.dart';
import 'core/theme.dart';
import 'core/routes.dart';
import 'core/constants.dart';

class SignBridgeApp extends StatelessWidget {
  const SignBridgeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      // Named routing → keeps navigation declarative and centralized.
      initialRoute: AppRoutes.login,
      routes: AppRoutes.routes,
    );
  }
}