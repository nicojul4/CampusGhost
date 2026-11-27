import 'package:flutter/material.dart';

import '../screens/admin/admin_dashboard_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/incident_detail/incident_detail_screen.dart';
import '../screens/profile/edit_profile_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/report/api_reports_screen.dart';
import '../screens/report/create_report_screen.dart';
import '../screens/splash/splash_screen.dart';
import '../screens/technician/technician_tickets_screen.dart';
import '../widgets/auth_gate.dart';

class AppRoutes {
  AppRoutes._();

  static const root = '/';
  static const splash = '/splash';
  static const login = '/login';
  static const register = '/register';
  static const dashboard = '/dashboard';
  static const profile = '/profile';
  static const editProfile = '/profile/edit';
  static const detail = '/detail';
  static const createReport = '/create-report';
  static const apiReports = '/api-reports';
  static const technicianTickets = '/technician/tickets';
  static const adminDashboard = '/admin';

  static Map<String, WidgetBuilder> get routes => {
        root: (_) => const SplashScreen(),
        splash: (_) => const SplashScreen(),
        login: (_) => const LoginScreen(),
        register: (_) => const RegisterScreen(),
        dashboard: (_) => const ProtectedRoute(child: DashboardScreen()),
        profile: (_) => const ProtectedRoute(child: ProfileScreen()),
        editProfile: (_) => const ProtectedRoute(child: EditProfileScreen()),
        detail: (_) => const ProtectedRoute(child: IncidentDetailScreen()),
        createReport: (_) => const ProtectedRoute(child: CreateReportScreen()),
        apiReports: (_) => const ProtectedRoute(child: ApiReportsScreen()),
        technicianTickets: (_) =>
            const ProtectedRoute(child: TechnicianTicketsScreen()),
        adminDashboard: (_) =>
            const ProtectedRoute(child: AdminDashboardScreen()),
      };
}
