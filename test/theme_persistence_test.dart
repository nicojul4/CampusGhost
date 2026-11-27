import 'package:campus_ghost/screens/auth/login_screen.dart';
import 'package:campus_ghost/screens/auth/register_screen.dart';
import 'package:campus_ghost/screens/splash/splash_screen.dart';
import 'package:campus_ghost/services/local_campus_store.dart';
import 'package:campus_ghost/widgets/theme_mode_scope.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

class _InMemorySecureStorage extends Fake implements FlutterSecureStorage {
  final Map<String, String> _data = {};

  @override
  Future<String?> read({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async =>
      _data[key];

  @override
  Future<void> write({
    required String key,
    required String? value,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value == null) {
      _data.remove(key);
    } else {
      _data[key] = value;
    }
  }

  @override
  Future<void> delete({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    _data.remove(key);
  }
}

void main() {
  group('Theme Mode Persistence & Local Cache Tests', () {
    late _InMemorySecureStorage storage;
    late LocalCampusStore store;

    setUp(() {
      storage = _InMemorySecureStorage();
      store = LocalCampusStore(storage, enableTimer: false);
    });

    tearDown(() {
      store.dispose();
    });

    test('1. Default theme mode cache is null when unset', () async {
      final initial = await store.readThemeMode();
      expect(initial, isNull);
    });

    test('2. saveThemeMode saves and reads dark mode correctly', () async {
      await store.saveThemeMode(true);
      final isDark = await store.readThemeMode();
      expect(isDark, isTrue);
    });

    test('3. saveThemeMode saves and reads light mode correctly', () async {
      await store.saveThemeMode(true);
      expect(await store.readThemeMode(), isTrue);

      await store.saveThemeMode(false);
      final isDark = await store.readThemeMode();
      expect(isDark, isFalse);
    });

    test('4. clearAllReports preserves theme mode preference', () async {
      await store.saveThemeMode(true);
      await store.clearAllReports();
      expect(await store.readThemeMode(), isTrue);
    });
  });

  group('Theme Consistency on Screens (Splash, Login, Register)', () {
    testWidgets('LoginScreen and RegisterScreen render cleanly in light mode',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          themeMode: ThemeMode.light,
          home: ThemeModeScope(
            isDark: false,
            onChanged: (_) {},
            child: const LoginScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Portal Fasilitas Mahasiswa'), findsOneWidget);
      // Memastikan tidak ada tombol toggle manual di login screen
      expect(find.byTooltip('Beralih ke tema gelap'), findsNothing);
      expect(find.byTooltip('Beralih ke tema terang'), findsNothing);
    });

    testWidgets('LoginScreen and RegisterScreen render cleanly in dark mode',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          themeMode: ThemeMode.dark,
          home: ThemeModeScope(
            isDark: true,
            onChanged: (_) {},
            child: const LoginScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Portal Fasilitas Mahasiswa'), findsOneWidget);
      // Memastikan tidak ada tombol toggle manual di login screen
      expect(find.byTooltip('Beralih ke tema gelap'), findsNothing);
      expect(find.byTooltip('Beralih ke tema terang'), findsNothing);
    });

    testWidgets('RegisterScreen renders without extra toggle buttons',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          themeMode: ThemeMode.dark,
          home: ThemeModeScope(
            isDark: true,
            onChanged: (_) {},
            child: const RegisterScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Buat Akun'), findsOneWidget);
      expect(find.byTooltip('Beralih ke tema gelap'), findsNothing);
      expect(find.byTooltip('Beralih ke tema terang'), findsNothing);
    });

    testWidgets('SplashScreen adapts smoothly to dark mode theme',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: ThemeData.dark(),
            themeMode: ThemeMode.dark,
            home: ThemeModeScope(
              isDark: true,
              onChanged: (_) {},
              child: const SplashScreen(),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('CampusGhost'), findsOneWidget);
      expect(find.text('Sistem Pelaporan Fasilitas Kampus'), findsOneWidget);
    });
  });
}
