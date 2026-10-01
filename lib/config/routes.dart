import 'package:flutter/material.dart';

import '../screens/home/home_screen.dart';
import '../screens/report/create_report_screen.dart';
import '../screens/incident_detail/incident_detail_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/profile/edit_profile_screen.dart';

class AppRoutes {
  AppRoutes._();

  static const login = '/';
  static const register = '/register';
  static const dashboard = '/dashboard';
  static const profile = '/profile';
  static const editProfile = '/profile/edit';
  static const detail = '/detail';
  static const createReport = '/create-report';

  static Map<String, WidgetBuilder> get routes => {
        login: (_) => const LoginScreen(),
        register: (_) => const RegisterScreen(),
        dashboard: (_) => const DashboardScreen(),
        profile: (_) => const ProfileScreen(),
        editProfile: (_) => const EditProfileScreen(),
        detail: (_) => const IncidentDetailScreen(),
        createReport: (_) => const CreateReportScreen(),
      };
}
