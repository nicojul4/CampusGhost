import 'package:flutter/material.dart';

import '../screens/dashboard_screen.dart';
import '../screens/login_screen.dart';
import '../screens/profile_screen.dart';

class AppRoutes {
  AppRoutes._();

  static const login = '/';
  static const dashboard = '/dashboard';
  static const profile = '/profile';

  static Map<String, WidgetBuilder> get routes => {
        login: (_) => const LoginScreen(),
        dashboard: (_) => const DashboardScreen(),
        profile: (_) => const ProfileScreen(),
      };
}
