// Centralized named-route registry.
// All navigation in the app flows through here.

import 'package:flutter/material.dart';
import '../ui/screens/login_screen.dart';
import '../ui/screens/home_screen.dart';
import '../ui/screens/call_screen.dart';
import '../ui/screens/history_screen.dart';

class AppRoutes {
  static const String login = '/';
  static const String home = '/home';
  static const String call = '/call';
  static const String history = '/history';

  static Map<String, WidgetBuilder> routes = {
    login:   (_) => const LoginScreen(),
    home:    (_) => const HomeScreen(),
    call:    (_) => const CallScreen(),
    history: (_) => const HistoryScreen(),
  };
}