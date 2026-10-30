import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_provider.dart';
import '../screens/auth/login_screen.dart';
import '../screens/home/home_screen.dart';
import 'campus_ui.dart';

/// AuthGate mengontrol navigasi root berdasarkan status autentikasi pengguna.
/// - Jika sesi aktif (auto-login), langsung masuk ke Dashboard.
/// - Jika belum login, menampilkan LoginScreen (route terproteksi).
/// - Jika sesi berakhir/logout, otomatis kembali ke LoginScreen.
class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);

    return authState.when(
      loading: () => const _AuthSplashLoading(),
      error: (_, __) => const LoginScreen(),
      data: (user) {
        if (user != null) {
          return const DashboardScreen();
        }
        return const LoginScreen();
      },
    );
  }
}

/// Menjaga setiap route privat, termasuk saat dibuka langsung lewat deep link.
class ProtectedRoute extends ConsumerWidget {
  const ProtectedRoute({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    return authState.when(
      loading: () => const _AuthSplashLoading(),
      error: (_, __) => const LoginScreen(),
      data: (user) => user == null ? const LoginScreen() : child,
    );
  }
}

class _AuthSplashLoading extends StatelessWidget {
  const _AuthSplashLoading();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                'image/LOGO-PRADITA-removebg-preview.png',
                width: 190,
                height: 80,
                fit: BoxFit.contain,
                semanticLabel: 'Logo Pradita University',
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.school_rounded,
                  size: 64,
                  color: campusGreen,
                ),
              ),
              const SizedBox(height: 24),
              CircularProgressIndicator(
                strokeWidth: 3,
                color: colors.primary,
              ),
              const SizedBox(height: 16),
              Text(
                'Memeriksa sesi akun...',
                style: TextStyle(
                  color: colors.onSurfaceVariant,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
