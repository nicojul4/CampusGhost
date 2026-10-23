import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:campus_ghost/enums/report_status.dart';
import 'package:campus_ghost/exceptions/api_exception.dart';
import 'package:campus_ghost/models/report_model.dart';
import 'package:campus_ghost/repositories/report_api_repository.dart';
import 'package:campus_ghost/services/report_api_service.dart';

void main() {
  const testBaseUrl = 'http://test.campusghost.local/api';

  group('Vertical Slice Unit Tests — Report API', () {
    // -------------------------------------------------------------------------
    // TEST 1: Model Valid
    // -------------------------------------------------------------------------
    test('1. Model valid: fromJson dengan data benar menghasilkan objek dengan nilai yang tepat', () {
      final validJson = <String, dynamic>{
        'id': 'report-101',
        'userId': 'user-nic-1',
        'locationId': 'gedung-1-lantai-3',
        'category': 'Wifi',
        'description': 'Koneksi Wi-Fi sering drop saat jam kuliah.',
        'status': 'Active',
        'incidentId': 'inc-99',
        'photoUrl': 'https://example.com/photo.jpg',
        'createdAt': '2026-10-23T08:00:00.000Z',
        'updatedAt': '2026-10-23T08:15:00.000Z',
      };

      final model = ReportModel.fromJson(validJson);

      expect(model.id, equals('report-101'));
      expect(model.userId, equals('user-nic-1'));
      expect(model.locationId, equals('gedung-1-lantai-3'));
      expect(model.category, equals('Wifi'));
      expect(model.description, equals('Koneksi Wi-Fi sering drop saat jam kuliah.'));
      expect(model.status, equals(ReportStatus.active));
      expect(model.incidentId, equals('inc-99'));
      expect(model.photoUrl, equals('https://example.com/photo.jpg'));
      expect(model.createdAt, equals(DateTime.parse('2026-10-23T08:00:00.000Z')));
      expect(model.updatedAt, equals(DateTime.parse('2026-10-23T08:15:00.000Z')));

      // Uji juga toJson kesesuaian serialisasi
      final jsonOutput = model.toJson();
      expect(jsonOutput['id'], equals('report-101'));
      expect(jsonOutput['status'], equals('Active'));
      expect(jsonOutput['category'], equals('Wifi'));
    });

    // -------------------------------------------------------------------------
    // TEST 2: Model Invalid
    // -------------------------------------------------------------------------
    test('2. Model invalid: data kurang field atau tipe salah menghasilkan ValidationException', () {
      // 2a. Kurang field wajib 'category'
      final missingCategory = <String, dynamic>{
        'id': 'rep-1',
        'locationId': 'loc-1',
        'description': 'AC bocor air',
      };
      expect(
        () => ReportModel.fromJson(missingCategory),
        throwsA(isA<ValidationException>().having(
          (e) => e.message,
          'message',
          contains('category'),
        )),
      );

      // 2b. Kurang field wajib 'description'
      final missingDescription = <String, dynamic>{
        'id': 'rep-1',
        'category': 'AC',
        'locationId': 'loc-1',
      };
      expect(
        () => ReportModel.fromJson(missingDescription),
        throwsA(isA<ValidationException>().having(
          (e) => e.message,
          'message',
          contains('description'),
        )),
      );

      // 2c. Tipe data salah (id bertipe integer bukan String)
      final invalidType = <String, dynamic>{
        'id': 12345, // salah, seharusnya String
        'category': 'Toilet',
        'locationId': 'loc-1',
        'description': 'Kran air patah',
      };
      expect(
        () => ReportModel.fromJson(invalidType),
        throwsA(isA<ValidationException>().having(
          (e) => e.message,
          'message',
          contains('id'),
        )),
      );

      // 2d. Format tanggal createdAt tidak valid
      final invalidDateFormat = <String, dynamic>{
        'id': 'rep-2',
        'category': 'Toilet',
        'locationId': 'loc-1',
        'description': 'Kran air patah',
        'createdAt': 'bukan-format-iso-tanggal',
      };
      expect(
        () => ReportModel.fromJson(invalidDateFormat),
        throwsA(isA<ValidationException>().having(
          (e) => e.message,
          'message',
          contains('createdAt'),
        )),
      );
    });

    // -------------------------------------------------------------------------
    // TEST 3: API Sukses (200 OK dengan list laporan)
    // -------------------------------------------------------------------------
    test('3. API sukses: respons 200 berisi daftar item -> repository mengembalikan list model yang benar', () async {
      final mockData = [
        {
          'id': 'report-1',
          'userId': 'user-1',
          'locationId': 'gedung-1-lantai-1',
          'category': 'AC',
          'description': 'AC tidak menyala',
          'status': 'Active',
          'createdAt': '2026-10-23T07:00:00.000Z',
        },
        {
          'id': 'report-2',
          'userId': 'user-2',
          'locationId': 'gedung-2-lantai-3',
          'category': 'Proyektor',
          'description': 'Proyektor buram di kelas 301',
          'status': 'Resolved',
          'createdAt': '2026-10-23T07:30:00.000Z',
        },
      ];

      final mockClient = MockClient((request) async {
        expect(request.method, equals('GET'));
        expect(request.url.path, equals('/api/reports'));
        return http.Response(
          jsonEncode(mockData),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = ReportApiService(client: mockClient, baseUrl: testBaseUrl);
      final repository = ReportApiRepository(service);

      final reports = await repository.getReports();

      expect(reports.length, equals(2));
      expect(reports[0].id, equals('report-1'));
      expect(reports[0].category, equals('AC'));
      expect(reports[0].status, equals(ReportStatus.active));
      expect(reports[1].id, equals('report-2'));
      expect(reports[1].category, equals('Proyektor'));
      expect(reports[1].status, equals(ReportStatus.resolved));
    });

    // -------------------------------------------------------------------------
    // TEST 4: Data Kosong (200 OK dengan [])
    // -------------------------------------------------------------------------
    test('4. Data kosong: respons 200 dengan [] -> repository mengembalikan list kosong (bukan error)', () async {
      final mockClient = MockClient((request) async {
        expect(request.method, equals('GET'));
        return http.Response(
          '[]',
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = ReportApiService(client: mockClient, baseUrl: testBaseUrl);
      final repository = ReportApiRepository(service);

      final reports = await repository.getReports();

      expect(reports, isA<List<ReportModel>>());
      expect(reports, isEmpty);
    });

    // -------------------------------------------------------------------------
    // TEST 5: HTTP Gagal (404 dan 500)
    // -------------------------------------------------------------------------
    test('5. HTTP gagal: respons 404/500 -> melempar exception ApiException yang sesuai', () async {
      // 5a. Uji respons 500 Internal Server Error
      final mockClient500 = MockClient((request) async {
        return http.Response(
          jsonEncode({'error': 'Internal server malfunction'}),
          500,
          headers: {'content-type': 'application/json'},
        );
      });

      final service500 = ReportApiService(client: mockClient500, baseUrl: testBaseUrl);
      final repo500 = ReportApiRepository(service500);

      expect(
        () => repo500.getReports(),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', equals(500))
              .having((e) => e.message, 'message', contains('Internal server malfunction')),
        ),
      );

      // 5b. Uji respons 404 Not Found
      final mockClient404 = MockClient((request) async {
        return http.Response(
          jsonEncode({'error': 'Endpoint laporan tidak ditemukan'}),
          404,
          headers: {'content-type': 'application/json'},
        );
      });

      final service404 = ReportApiService(client: mockClient404, baseUrl: testBaseUrl);
      final repo404 = ReportApiRepository(service404);

      expect(
        () => repo404.getReports(),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', equals(404))
              .having((e) => e.message, 'message', contains('tidak ditemukan')),
        ),
      );
    });

    // -------------------------------------------------------------------------
    // TEST 6: JSON Rusak (body bukan JSON valid)
    // -------------------------------------------------------------------------
    test('6. JSON rusak: body bukan JSON valid -> melempar exception JsonParsingException yang jelas', () async {
      final mockClientCorrupt = MockClient((request) async {
        return http.Response(
          '<html><body><h1>502 Bad Gateway</h1><p>HTML alih-alih JSON</p></body></html>',
          200,
          headers: {'content-type': 'text/html'},
        );
      });

      final serviceCorrupt = ReportApiService(client: mockClientCorrupt, baseUrl: testBaseUrl);
      final repoCorrupt = ReportApiRepository(serviceCorrupt);

      expect(
        () => repoCorrupt.getReports(),
        throwsA(
          isA<JsonParsingException>().having(
            (e) => e.message,
            'message',
            contains('bukan JSON valid'),
          ),
        ),
      );
    });

    // -------------------------------------------------------------------------
    // TEST 7 (Tambahan): Simpan Data Baru (POST) Berhasil
    // -------------------------------------------------------------------------
    test('7. Simpan data (POST): berhasil mengirim dan mengembalikan objek model baru', () async {
      final mockClient = MockClient((request) async {
        expect(request.method, equals('POST'));
        expect(request.url.path, equals('/api/reports'));
        final decodedBody = jsonDecode(request.body) as Map<String, dynamic>;
        expect(decodedBody['category'], equals('Parkiran'));
        expect(decodedBody['locationId'], equals('gedung-1-lantai-b'));
        expect(decodedBody['description'], equals('Palang parkir tertahan tidak bisa dibuka.'));

        return http.Response(
          jsonEncode({
            'id': 'report-created-777',
            'userId': decodedBody['userId'] ?? 'user_guest',
            'locationId': decodedBody['locationId'],
            'category': decodedBody['category'],
            'description': decodedBody['description'],
            'status': 'Active',
            'createdAt': '2026-10-23T08:45:00.000Z',
          }),
          201,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = ReportApiService(client: mockClient, baseUrl: testBaseUrl);
      final repository = ReportApiRepository(service);

      final created = await repository.createReport(
        category: 'Parkiran',
        locationId: 'gedung-1-lantai-b',
        description: 'Palang parkir tertahan tidak bisa dibuka.',
        userId: 'mhs-101',
      );

      expect(created.id, equals('report-created-777'));
      expect(created.category, equals('Parkiran'));
      expect(created.locationId, equals('gedung-1-lantai-b'));
      expect(created.description, equals('Palang parkir tertahan tidak bisa dibuka.'));
      expect(created.status, equals(ReportStatus.active));
    });

    // -------------------------------------------------------------------------
    // TEST 8 (Tambahan): Simpan Data Gagal (POST 400 Validation Error dari API)
    // -------------------------------------------------------------------------
    test('8. Simpan data (POST) gagal: server return 400 -> melempar ApiException', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({'error': 'Kategori wajib diisi.'}),
          400,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = ReportApiService(client: mockClient, baseUrl: testBaseUrl);
      final repository = ReportApiRepository(service);

      expect(
        () => repository.createReport(
          category: '',
          locationId: 'loc',
          description: 'desc',
        ),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', equals(400))
              .having((e) => e.message, 'message', contains('Kategori wajib diisi')),
        ),
      );
    });
  });
}
