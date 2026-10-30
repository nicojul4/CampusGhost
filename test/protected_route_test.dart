import 'package:campus_ghost/config/routes.dart';
import 'package:campus_ghost/providers/auth_provider.dart';
import 'package:campus_ghost/screens/auth/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('route dashboard langsung kembali menampilkan login saat logout',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith((ref) => Stream.value(null)),
        ],
        child: MaterialApp(
          initialRoute: AppRoutes.dashboard,
          routes: AppRoutes.routes,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text('Masuk Portal'), findsOneWidget);
  });
}
