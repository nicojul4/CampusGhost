import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:campus_ghost/providers/api_report_provider.dart';
import 'package:campus_ghost/repositories/report_api_repository.dart';
import 'package:campus_ghost/screens/report/api_reports_screen.dart';
import 'package:campus_ghost/services/report_api_service.dart';

void main() {
  const testBaseUrl = 'http://test.local/api';

  Widget buildTestApp({required ReportApiService apiService}) {
    final repository = ReportApiRepository(apiService);
    return ProviderScope(
      overrides: [
        reportApiServiceProvider.overrideWithValue(apiService),
        reportApiRepositoryProvider.overrideWithValue(repository),
      ],
      child: const MaterialApp(
        home: ApiReportsScreen(),
      ),
    );
  }

  group('ApiReportsScreen Widget Tests — 5 UI States & Retry', () {
    testWidgets('Kondisi 1: Loading state tampil saat request sedang berjalan', (tester) async {
      final mockClient = MockClient((request) async {
        await Future.delayed(const Duration(milliseconds: 200));
        return http.Response('[]', 200, headers: {'content-type': 'application/json'});
      });

      final service = ReportApiService(client: mockClient, baseUrl: testBaseUrl);

      await tester.pumpWidget(buildTestApp(apiService: service));

      // Sebelum delay selesai, harus menampilkan loading indicator
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Menghubungkan ke API server...'), findsOneWidget);

      await tester.pumpAndSettle();
    });

    testWidgets('Kondisi 2: Empty state tampil saat respons []', (tester) async {
      final mockClient = MockClient((request) async {
        return http.Response('[]', 200, headers: {'content-type': 'application/json'});
      });

      final service = ReportApiService(client: mockClient, baseUrl: testBaseUrl);

      await tester.pumpWidget(buildTestApp(apiService: service));
      await tester.pumpAndSettle();

      expect(find.text('Belum Ada Laporan'), findsOneWidget);
      expect(find.text('Muat Ulang'), findsOneWidget);
      expect(find.byIcon(Icons.assignment_turned_in_outlined), findsOneWidget);
    });

    testWidgets('Kondisi 3: Error state dan Retry tampil saat respons 500', (tester) async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({'error': 'Server Error Terjadi'}),
          500,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = ReportApiService(client: mockClient, baseUrl: testBaseUrl);

      await tester.pumpWidget(buildTestApp(apiService: service));
      await tester.pumpAndSettle();

      expect(find.text('Gagal Memuat Data'), findsOneWidget);
      expect(find.textContaining('Server Error Terjadi'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Coba Lagi'), findsOneWidget);
      expect(find.byIcon(Icons.cloud_off_rounded), findsOneWidget);
    });

    testWidgets('Kondisi 4: Menekan tombol Coba Lagi (Retry) memicu refresh data', (tester) async {
      int requestCount = 0;
      final mockClient = MockClient((request) async {
        requestCount++;
        if (requestCount == 1) {
          return http.Response(
            jsonEncode({'error': 'Gangguan sementara'}),
            500,
            headers: {'content-type': 'application/json'},
          );
        } else {
          return http.Response(
            jsonEncode([
              {
                'id': 'rep-sukses-retry',
                'userId': 'user-1',
                'locationId': 'gedung-1-lantai-3',
                'category': 'Wifi',
                'description': 'Wifi kembali lancar setelah retry',
                'status': 'Active',
              }
            ]),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
      });

      final service = ReportApiService(client: mockClient, baseUrl: testBaseUrl);

      await tester.pumpWidget(buildTestApp(apiService: service));
      await tester.pumpAndSettle();

      // Pertama kali: error
      expect(find.text('Gagal Memuat Data'), findsOneWidget);
      expect(requestCount, equals(1));

      // Tekan tombol "Coba Lagi"
      await tester.tap(find.widgetWithText(FilledButton, 'Coba Lagi'));
      await tester.pumpAndSettle();

      // Setelah retry: request kedua berhasil dan beralih ke Success state
      expect(requestCount, equals(2));
      expect(find.text('Wifi'), findsOneWidget);
      expect(find.text('Wifi kembali lancar setelah retry'), findsOneWidget);
    });

    testWidgets('Kondisi 5: Success state menampilkan list laporan dengan benar', (tester) async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode([
            {
              'id': 'rep-1',
              'userId': 'user-1',
              'locationId': 'gedung-1-lantai-1',
              'category': 'AC',
              'description': 'AC ruangan bocor air',
              'status': 'Active',
              'createdAt': '2026-10-23T08:00:00.000Z',
            },
            {
              'id': 'rep-2',
              'userId': 'user-2',
              'locationId': 'gedung-2-lantai-2',
              'category': 'Toilet',
              'description': 'Kran air patah',
              'status': 'Resolved',
              'createdAt': '2026-10-23T08:10:00.000Z',
            }
          ]),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = ReportApiService(client: mockClient, baseUrl: testBaseUrl);

      await tester.pumpWidget(buildTestApp(apiService: service));
      await tester.pumpAndSettle();

      expect(find.text('AC'), findsOneWidget);
      expect(find.text('AC ruangan bocor air'), findsOneWidget);
      expect(find.text('Toilet'), findsOneWidget);
      expect(find.text('Kran air patah'), findsOneWidget);
      expect(find.text('Active'), findsOneWidget);
      expect(find.text('Resolved'), findsOneWidget);
    });

    testWidgets('Aksi Tambah Laporan: form input mengirim POST ke backend lalu me-refresh list', (tester) async {
      final mockData = <Map<String, dynamic>>[];
      final mockClient = MockClient((request) async {
        if (request.method == 'GET') {
          return http.Response(jsonEncode(mockData), 200, headers: {'content-type': 'application/json'});
        } else if (request.method == 'POST') {
          final payload = jsonDecode(request.body) as Map<String, dynamic>;
          final newItem = {
            'id': 'created-id-99',
            'userId': 'user_guest',
            'locationId': payload['locationId'],
            'category': payload['category'],
            'description': payload['description'],
            'status': 'Active',
            'createdAt': DateTime.now().toIso8601String(),
          };
          mockData.insert(0, newItem);
          return http.Response(jsonEncode(newItem), 201, headers: {'content-type': 'application/json'});
        }
        return http.Response('Not Found', 404);
      });

      final service = ReportApiService(client: mockClient, baseUrl: testBaseUrl);

      await tester.pumpWidget(buildTestApp(apiService: service));
      await tester.pumpAndSettle();

      // Mula-mula data kosong
      expect(find.text('Belum Ada Laporan'), findsOneWidget);

      // Buka form "Buat Laporan"
      await tester.tap(find.widgetWithText(FloatingActionButton, 'Buat Laporan'));
      await tester.pumpAndSettle();

      expect(find.text('Laporkan Masalah Fasilitas'), findsOneWidget);

      // Isi deskripsi
      final descField = find.widgetWithText(TextFormField, 'Deskripsi Masalah');
      await tester.enterText(descField, 'Lampu sorot proyektor padam tiba-tiba');
      await tester.pumpAndSettle();

      // Submit form
      await tester.tap(find.widgetWithText(FilledButton, 'Kirim Laporan'));
      await tester.pumpAndSettle();

      // Form tertutup, SnackBar muncul, dan item baru muncul di UI
      expect(find.text('Laporan "Wifi" berhasil dikirim ke backend!'), findsOneWidget);
      expect(find.text('Lampu sorot proyektor padam tiba-tiba'), findsOneWidget);
    });
  });
}
