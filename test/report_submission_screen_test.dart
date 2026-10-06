import 'dart:async';

import 'package:campus_ghost/enums/report_category.dart';
import 'package:campus_ghost/providers/location_provider.dart';
import 'package:campus_ghost/screens/report/create_report_screen.dart';
import 'package:campus_ghost/models/location_model.dart';
import 'package:campus_ghost/repositories/location_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _TestLocationRepository extends LocationRepository {
  _TestLocationRepository(this.stream);

  final Stream<List<LocationModel>> stream;

  @override
  Stream<List<LocationModel>> watchAll() => stream;
}

const _location = LocationModel(
  id: 'gedung-1',
  name: 'Gedung 1',
  building: 'Gedung 1',
  floor: 1,
  latitude: null,
  longitude: null,
  createdAt: null,
);

Widget _screen(Stream<List<LocationModel>> locations) => ProviderScope(
      overrides: [
        locationRepositoryProvider
            .overrideWithValue(_TestLocationRepository(locations)),
      ],
      child: const MaterialApp(home: CreateReportScreen()),
    );

void main() {
  testWidgets('menampilkan initial loading untuk data lokasi', (tester) async {
    final controller = StreamController<List<LocationModel>>();
    await tester.pumpWidget(_screen(controller.stream));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await controller.close();
  });

  testWidgets('menampilkan form saat data berhasil dimuat', (tester) async {
    await tester.pumpWidget(_screen(Stream.value([_location])));
    await tester.pump(const Duration(milliseconds: 10));
    await tester.pumpAndSettle();
    expect(find.text('Pilih kategori fasilitas'), findsOneWidget);
    expect(find.byType(Form), findsOneWidget);
  });

  testWidgets('menampilkan empty state saat belum ada lokasi', (tester) async {
    await tester.pumpWidget(_screen(Stream.value(const [])));
    await tester.pumpAndSettle();
    expect(find.text('Belum ada lokasi terdaftar.'), findsOneWidget);
  });

  testWidgets('menampilkan error state dan tombol retry', (tester) async {
    await tester
        .pumpWidget(_screen(Stream.error(StateError('gagal memuat lokasi'))));
    await tester.pumpAndSettle();
    expect(find.text('Lokasi gagal dimuat.'), findsOneWidget);
    expect(find.text('Coba lagi'), findsOneWidget);
  });

  testWidgets('menampilkan validasi deskripsi saat form tidak valid',
      (tester) async {
    await tester.pumpWidget(_screen(Stream.value([_location])));
    await tester.pump(const Duration(milliseconds: 10));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text(ReportCategory.wifi.value),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text(ReportCategory.wifi.value));
    await tester.scrollUntilVisible(
      find.text('Kirim Laporan Fasilitas'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Kirim Laporan Fasilitas'));
    await tester.pumpAndSettle();
    expect(find.text('Jelaskan kendala minimal 10 karakter'), findsOneWidget);
  });
}
