// Centralized named-route registry.
// All navigation in the app flows through here.

import 'package:flutter/material.dart';
import '../ui/screens/onboarding_screen.dart';
import '../ui/screens/login_screen.dart';
import '../ui/screens/home_screen.dart';
import '../ui/screens/call_screen.dart';
import '../ui/screens/history_screen.dart';
import '../ui/screens/settings_screen.dart';
import '../ui/screens/learning_screen.dart';
import '../ui/screens/contacts_screen.dart';

class AppRoutes {
  static const String onboarding = '/onboarding';
  static const String login = '/login';
  static const String home = '/home';
  static const String call = '/call';
  static const String history = '/history';
  static const String settings = '/settings';
  static const String learning = '/learning';
  static const String contacts = '/contacts';

  static Map<String, WidgetBuilder> routes = {
    onboarding: (_) => const OnboardingScreen(),
    login:      (_) => const LoginScreen(),
    home:       (_) => const HomeScreen(),
    call:       (_) => const CallScreen(),
    history:    (_) => const HistoryScreen(),
    settings:   (_) => const SettingsScreen(),
    learning:   (_) => const LearningScreen(),
    contacts:   (_) => const ContactsScreen(),
  };
}