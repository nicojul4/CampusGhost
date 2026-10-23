import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../exceptions/api_exception.dart';

class ReportApiService {
  ReportApiService({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        _baseUrl = baseUrl ?? ApiConfig.baseUrl;

  final http.Client _client;
  final String _baseUrl;

  Uri _buildUri(String path) {
    final base = _baseUrl.endsWith('/')
        ? _baseUrl.substring(0, _baseUrl.length - 1)
        : _baseUrl;
    final subPath = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$base$subPath');
  }

  Future<List<Map<String, dynamic>>> fetchReports() async {
    final uri = _buildUri('/reports');
    final http.Response response;

    try {
      response = await _client.get(
        uri,
        headers: const {'Accept': 'application/json'},
      ).timeout(
        ApiConfig.requestTimeout,
        onTimeout: () =>
            throw NetworkException('Koneksi timeout setelah 10 detik.'),
      );
    } on SocketException catch (e) {
      throw NetworkException('Gagal terhubung ke server (tidak ada koneksi): ${e.message}');
    } on http.ClientException catch (e) {
      throw NetworkException('Gagal melakukan permintaan jaringan: ${e.message}');
    } on TimeoutException {
      throw NetworkException('Koneksi timeout saat menghubungi server.');
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      String errorMessage = 'Server mengembalikan status ${response.statusCode}';
      try {
        final decodedError = jsonDecode(response.body);
        if (decodedError is Map && decodedError['error'] != null) {
          errorMessage = decodedError['error'].toString();
        }
      } catch (_) {
        // Fallback ke pesan status default jika body error bukan JSON
      }
      throw ApiException(
        statusCode: response.statusCode,
        message: errorMessage,
      );
    }

    final dynamic decodedBody;
    try {
      decodedBody = jsonDecode(response.body);
    } on FormatException catch (e) {
      throw JsonParsingException('Body respons bukan JSON valid.', e);
    }

    if (decodedBody is! List) {
      throw JsonParsingException('Format data tidak sesuai, diharapkan berupa List JSON.');
    }

    return decodedBody
        .map((item) {
          if (item is Map<String, dynamic>) {
            return item;
          } else if (item is Map) {
            return Map<String, dynamic>.from(item);
          } else {
            throw JsonParsingException('Elemen dalam daftar bukan objek JSON valid.');
          }
        })
        .toList();
  }

  Future<Map<String, dynamic>> createReport(Map<String, dynamic> data) async {
    final uri = _buildUri('/reports');
    final http.Response response;

    try {
      response = await _client.post(
        uri,
        headers: const {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(data),
      ).timeout(
        ApiConfig.requestTimeout,
        onTimeout: () =>
            throw NetworkException('Koneksi timeout saat menyimpan data.'),
      );
    } on SocketException catch (e) {
      throw NetworkException('Gagal terhubung ke server (tidak ada koneksi): ${e.message}');
    } on http.ClientException catch (e) {
      throw NetworkException('Gagal melakukan permintaan jaringan: ${e.message}');
    } on TimeoutException {
      throw NetworkException('Koneksi timeout saat menyimpan data.');
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      String errorMessage = 'Server mengembalikan status ${response.statusCode}';
      try {
        final decodedError = jsonDecode(response.body);
        if (decodedError is Map && decodedError['error'] != null) {
          errorMessage = decodedError['error'].toString();
        }
      } catch (_) {
        // Fallback ke pesan status default
      }
      throw ApiException(
        statusCode: response.statusCode,
        message: errorMessage,
      );
    }

    final dynamic decodedBody;
    try {
      decodedBody = jsonDecode(response.body);
    } on FormatException catch (e) {
      throw JsonParsingException('Body respons simpan bukan JSON valid.', e);
    }

    if (decodedBody is! Map) {
      throw JsonParsingException('Respons penyimpanan harus berupa objek JSON.');
    }

    return Map<String, dynamic>.from(decodedBody);
  }
}
