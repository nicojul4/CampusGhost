import 'package:flutter/material.dart';

import 'config/routes.dart';
import 'widgets/theme_mode_scope.dart';

class CampusGhostApp extends StatefulWidget {
  const CampusGhostApp({super.key, required this.firebaseConfigured});

  final bool firebaseConfigured;

  @override
  State<CampusGhostApp> createState() => _CampusGhostAppState();
}

class _CampusGhostAppState extends State<CampusGhostApp> {
  ThemeMode _themeMode = ThemeMode.light;

  void _toggleTheme(bool isDark) => setState(
        () => _themeMode = isDark ? ThemeMode.dark : ThemeMode.light,
      );

  ThemeData _theme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final surface = isDark ? const Color(0xFF121713) : const Color(0xFFF7FAF5);
    final card = isDark ? const Color(0xFF1C241E) : Colors.white;
    final line = isDark ? const Color(0xFF3A463D) : const Color(0xFFE1E8E2);
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF0B6837),
      brightness: brightness,
      primary: isDark ? const Color(0xFF8FE1AA) : const Color(0xFF0B6837),
      surface: surface,
      onSurface: isDark ? const Color(0xFFF1F5F1) : const Color(0xFF191D1A),
      onSurfaceVariant:
          isDark ? const Color(0xFFBAC6BC) : const Color(0xFF657168),
      outline: line,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: surface,
      cardColor: card,
      dividerColor: line,
      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? const Color(0xFF252E28) : const Color(0xFFF1F4EF),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'CampusGhost',
        debugShowCheckedModeBanner: false,
        theme: _theme(Brightness.light),
        darkTheme: _theme(Brightness.dark),
        themeMode: _themeMode,
        builder: (context, child) => ThemeModeScope(
          isDark: _themeMode == ThemeMode.dark,
          onChanged: _toggleTheme,
          child: child ?? const SizedBox.shrink(),
        ),
        home: widget.firebaseConfigured ? null : const _FirebaseSetupScreen(),
        initialRoute: widget.firebaseConfigured ? AppRoutes.login : null,
        routes: widget.firebaseConfigured ? AppRoutes.routes : const {},
      );
}

class _FirebaseSetupScreen extends StatelessWidget {
  const _FirebaseSetupScreen();

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.cloud_off_outlined,
                    size: 54, color: Theme.of(context).colorScheme.primary),
                const SizedBox(height: 16),
                const Text('Firebase belum dikonfigurasi',
                    style:
                        TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Text(
                  'Lengkapi opsi aplikasi Firebase di lib/config/firebase_options.dart, lalu jalankan ulang aplikasi.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),
      );
}
