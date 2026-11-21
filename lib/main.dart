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
  
  logger.info('main', 'Application starting...');
  
  final configured = FirebaseOptionsConfig.isConfigured;
  if (configured) {
    logger.info('main', 'Firebase configured, initializing...');
    await Firebase.initializeApp(options: FirebaseOptionsConfig.current);
    logger.info('main', 'Firebase initialized successfully');
  } else {
    logger.warning('main', 'Firebase not configured, skipping initialization');
  }
  
  runApp(ProviderScope(
    overrides: [
      localCampusStoreProvider
          .overrideWithValue(LocalCampusStore(const FlutterSecureStorage())),
    ],
    child: CampusGhostApp(firebaseConfigured: configured),
  ));
  
  logger.info('main', 'Application ready');
}
