import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'app.dart';
import 'config/firebase_options.dart';
import 'providers/firebase_provider.dart';
import 'services/local_campus_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final configured = FirebaseOptionsConfig.isConfigured;
  if (configured) {
    await Firebase.initializeApp(options: FirebaseOptionsConfig.current);
  }
  runApp(ProviderScope(
    overrides: [
      localCampusStoreProvider
          .overrideWithValue(LocalCampusStore(const FlutterSecureStorage())),
    ],
    child: CampusGhostApp(firebaseConfigured: configured),
  ));
}
