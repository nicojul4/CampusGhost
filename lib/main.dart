import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'app.dart';
import 'config/firebase_options.dart';
import 'providers/firebase_provider.dart';
import 'services/local_campus_store.dart';
import 'utils/logger.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Global Error Catchers for Release & Runtime Tracing
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    logger.error(
      'FlutterError',
      details.exceptionAsString(),
      details.exception,
      details.stack,
    );
  };

  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    logger.error(
      'PlatformDispatcher',
      'Uncaught async error: $error',
      error,
      stack,
    );
    return true; // prevent immediate unhandled crash
  };

  logger.info('main', 'Application starting...');

  final configured = FirebaseOptionsConfig.isConfigured;
  if (configured) {
    logger.info('main', 'Firebase configured, initializing...');
    try {
      await Firebase.initializeApp(options: FirebaseOptionsConfig.current);
      logger.info('main', 'Firebase initialized successfully');
    } catch (e, st) {
      logger.error('main', 'Firebase initialization failed: $e', e, st);
    }
  } else {
    logger.warning('main', 'Firebase not configured, skipping initialization');
  }

  const storage = FlutterSecureStorage();
  final store = LocalCampusStore(storage);
  bool? isDark;
  try {
    isDark = await store.readThemeMode();
  } catch (e) {
    logger.warning('main', 'Gagal membaca cache tema: $e');
  }

  final initialThemeMode =
      isDark == true ? ThemeMode.dark : ThemeMode.light;

  runApp(ProviderScope(
    overrides: [
      localCampusStoreProvider.overrideWithValue(store),
    ],
    child: CampusGhostApp(
      firebaseConfigured: configured,
      initialThemeMode: initialThemeMode,
      store: store,
    ),
  ));

  logger.info('main', 'Application ready');
}
