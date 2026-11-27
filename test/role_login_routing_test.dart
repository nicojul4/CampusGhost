import 'package:campus_ghost/config/routes.dart';
import 'package:campus_ghost/enums/user_role.dart';
import 'package:campus_ghost/providers/user_role_provider.dart';
import 'package:campus_ghost/screens/auth/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Role Login Routing & Demo Accounts Tests', () {
    test('1. Match demo admin email returns admin role', () {
      expect(UserRoleNotifier.isDemoAdminEmail('admin@pradita.ac.id'), isTrue);
      expect(
          UserRoleNotifier.isDemoAdminEmail('admin@campusghost.ac.id'), isTrue);
      expect(
          UserRoleNotifier.isDemoAdminEmail('mahasiswa@student.pradita.ac.id'),
          isFalse);
    });

    test('2. Match demo technician email returns technician role', () {
      expect(
          UserRoleNotifier.isDemoTechnicianEmail('teknisi.ga@pradita.ac.id'),
          isTrue);
      expect(UserRoleNotifier.isDemoTechnicianEmail('teknisi@pradita.ac.id'),
          isTrue);
      expect(
          UserRoleNotifier.isDemoTechnicianEmail('admin@pradita.ac.id'), isFalse);
    });

    testWidgets(
        '3. LoginScreen displays quick demo account selectors for all 3 roles',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: LoginScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Memastikan section akun demo cepat hadir
      expect(find.text('PILIH AKUN DEMO / ROLE KHUSUS'), findsOneWidget);
      expect(find.text('Mahasiswa'), findsOneWidget);
      expect(find.text('Teknisi GA'), findsOneWidget);
      expect(find.text('Administrator'), findsOneWidget);

      // Tap chip Administrator -> memastikan input email terisi akun admin
      await tester.tap(find.text('Administrator'));
      await tester.pumpAndSettle();

      final adminField = find.widgetWithText(TextFormField, 'admin@pradita.ac.id');
      expect(adminField, findsOneWidget);

      // Tap chip Teknisi GA -> memastikan input email terisi akun teknisi
      await tester.tap(find.text('Teknisi GA'));
      await tester.pumpAndSettle();

      final techField =
          find.widgetWithText(TextFormField, 'teknisi.ga@pradita.ac.id');
      expect(techField, findsOneWidget);

      // Tap chip Mahasiswa -> memastikan input email terisi akun mahasiswa
      await tester.tap(find.text('Mahasiswa'));
      await tester.pumpAndSettle();

      final studentField = find.widgetWithText(
          TextFormField, 'mahasiswa@student.pradita.ac.id');
      expect(studentField, findsOneWidget);
    });
  });
}
