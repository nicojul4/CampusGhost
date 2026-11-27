import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/routes.dart';
import '../../enums/user_role.dart';
import '../../providers/auth_provider.dart';
import '../../providers/firebase_provider.dart';
import '../../providers/user_role_provider.dart';
import '../admin/admin_dashboard_screen.dart';
import '../auth/login_screen.dart';
import '../home/home_screen.dart';
import '../technician/technician_tickets_screen.dart';

/// Transisi halaman yang halus (Fade + Subtle Slide) untuk pengalaman pengguna bebas patah-patah.
class SmoothPageRoute<T> extends PageRouteBuilder<T> {
  SmoothPageRoute({
    required Widget page,
    Duration duration = const Duration(milliseconds: 650),
  }) : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final curvedAnimation = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            );
            return FadeTransition(
              opacity: curvedAnimation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0.0, 0.04),
                  end: Offset.zero,
                ).animate(curvedAnimation),
                child: child,
              ),
            );
          },
          transitionDuration: duration,
        );
}

/// Halaman Intro / Splash Screen dengan animasi logo CampusGhost yang halus.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _entranceController;
  late final AnimationController _floatingController;

  late final Animation<double> _logoScale;
  late final Animation<double> _logoFade;
  late final Animation<double> _glowScale;
  late final Animation<Offset> _titleSlide;
  late final Animation<double> _titleFade;
  late final Animation<double> _badgeFade;

  bool _navigated = false;

  @override
  void initState() {
    super.initState();

    // 1. Controller untuk animasi kemunculan logo & teks awal
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );

    // 2. Controller untuk animasi melayang halus (floating ghost effect)
    _floatingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    // Animasi logo: scale up dari 0.65 ke 1.0 dengan pantulan lembut (easeOutBack)
    _logoScale = Tween<double>(begin: 0.65, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.0, 0.65, curve: Curves.easeOutBack),
      ),
    );

    // Fade in logo
    _logoFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.0, 0.45, curve: Curves.easeIn),
      ),
    );

    // Efek cahaya / halo di belakang logo
    _glowScale = Tween<double>(begin: 0.5, end: 1.15).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.2, 0.75, curve: Curves.easeOut),
      ),
    );

    // Teks judul: meluncur ke atas dan memudar masuk
    _titleSlide = Tween<Offset>(
      begin: const Offset(0.0, 0.35),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.35, 0.85, curve: Curves.easeOutCubic),
      ),
    );

    _titleFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.35, 0.75, curve: Curves.easeIn),
      ),
    );

    // Badge institusi / branding bawah
    _badgeFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.60, 1.0, curve: Curves.easeIn),
      ),
    );

    // Memulai animasi
    _entranceController.forward();
    _floatingController.repeat(reverse: true);

    // Precaching aset gambar di background agar saat masuk ke login/dashboard tidak lag
    WidgetsBinding.instance.addPostFrameCallback((_) {
      precacheImage(
        const AssetImage('web/icons/Ghost Campus Map Pin Icon.png'),
        context,
      );
      precacheImage(
        const AssetImage('image/LOGO-PRADITA-removebg-preview.png'),
        context,
      );
    });

    // Listener saat animasi selesai untuk transisi mulus ke halaman tujuan
    _entranceController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        Future.delayed(const Duration(milliseconds: 350), _navigateToNextScreen);
      }
    });
  }

  Future<void> _navigateToNextScreen() async {
    if (!mounted || _navigated) return;
    _navigated = true;

    final user = ref.read(authStateProvider).asData?.value ??
        ref.read(firebaseAuthProvider).currentUser;

    if (user == null) {
      Navigator.of(context).pushReplacement(
        SmoothPageRoute(page: const LoginScreen()),
      );
      return;
    }

    await ref.read(userRoleProvider.notifier).refreshFromToken();
    final role = ref.read(userRoleProvider);

    final Widget targetScreen = switch (role) {
      UserRole.admin => const AdminDashboardScreen(),
      UserRole.technician => const TechnicianTicketsScreen(),
      UserRole.student => const DashboardScreen(),
    };

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      SmoothPageRoute(page: targetScreen),
    );
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _floatingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final bgGradient = isDark
        ? const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0F1E14), Color(0xFF080F0A)],
          )
        : const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFEAF5EE), Color(0xFFF7FAF5)],
          );

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(gradient: bgGradient),
        child: SafeArea(
          child: Column(
            children: [
              const Spacer(flex: 2),

              // Bagian Logo Beranimasi
              AnimatedBuilder(
                animation: Listenable.merge([_entranceController, _floatingController]),
                builder: (context, child) {
                  // Floating offset: gerakan naik-turun halus seperti melayang (±5 pixel)
                  final floatingOffset =
                      math.sin(_floatingController.value * 2 * math.pi) * 5.0;

                  return Transform.translate(
                    offset: Offset(0, floatingOffset),
                    child: Opacity(
                      opacity: _logoFade.value,
                      child: Transform.scale(
                        scale: _logoScale.value,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Efek aura cahaya lembut di belakang logo
                            Container(
                              width: 150 * _glowScale.value,
                              height: 150 * _glowScale.value,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: const Color(0xFF0B6837).withValues(
                                  alpha: isDark ? 0.25 : 0.14,
                                ),
                              ),
                            ),
                            // Lingkaran wadah logo
                            Container(
                              width: 124,
                              height: 124,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF1B271F)
                                    : Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF0B6837).withValues(alpha: 0.18),
                                    blurRadius: 28,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                                border: Border.all(
                                  color: const Color(0xFF0B6837).withValues(
                                    alpha: isDark ? 0.35 : 0.2,
                                  ),
                                  width: 2,
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(50),
                                child: Image.asset(
                                  'web/icons/Ghost Campus Map Pin Icon.png',
                                  fit: BoxFit.contain,
                                  cacheWidth: 260,
                                  cacheHeight: 260,
                                  filterQuality: FilterQuality.medium,
                                  semanticLabel: 'Logo CampusGhost',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 30),

              // Bagian Teks Judul "CampusGhost" dengan animasi Slide + Fade
              AnimatedBuilder(
                animation: _entranceController,
                builder: (context, child) {
                  return SlideTransition(
                    position: _titleSlide,
                    child: Opacity(
                      opacity: _titleFade.value,
                      child: Column(
                        children: [
                          Text(
                            'CampusGhost',
                            style: theme.textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.5,
                              color: isDark
                                  ? const Color(0xFF8FE1AA)
                                  : const Color(0xFF0B6837),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Sistem Pelaporan Fasilitas Kampus',
                            style: TextStyle(
                              color: colors.onSurfaceVariant,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),

              const Spacer(flex: 3),

              // Bagian Footer / Identitas Pradita University dengan Fade In halus
              FadeTransition(
                opacity: _badgeFade,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Logo Pradita kecil
                      Image.asset(
                        'image/LOGO-PRADITA-removebg-preview.png',
                        height: 28,
                        fit: BoxFit.contain,
                        cacheHeight: 60,
                        filterQuality: FilterQuality.medium,
                        semanticLabel: 'Logo Pradita',
                      ),
                      const SizedBox(height: 14),
                      // Indikator loading halus (smooth progress line)
                      SizedBox(
                        width: 44,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: const LinearProgressIndicator(
                            minHeight: 3,
                            color: Color(0xFF0B6837),
                            backgroundColor: Colors.transparent,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
