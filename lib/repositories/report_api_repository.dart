import '../exceptions/api_exception.dart';
import '../models/report_model.dart';
import '../services/report_api_service.dart';

class ReportApiRepository {
  ReportApiRepository(this._apiService);

  final ReportApiService _apiService;

  Future<List<ReportModel>> getReports() async {
    try {
      final rawList = await _apiService.fetchReports();
      return rawList.map((item) => ReportModel.fromJson(item)).toList();
    } on ApiException {
      rethrow;
    } on NetworkException {
      rethrow;
    } on JsonParsingException {
      rethrow;
    } on ValidationException {
      rethrow;
    } catch (e) {
      throw JsonParsingException('Gagal memproses data laporan: $e');
    }
  }

  Future<ReportModel> createReport({
    required String category,
    required String locationId,
    required String description,
    String? userId,
    String? photoUrl,
  }) async {
    final payload = <String, dynamic>{
      'category': category,
      'locationId': locationId,
      'description': description,
      'userId': userId ?? 'user_guest',
      if (photoUrl != null) 'photoUrl': photoUrl,
    };

    try {
      final resultMap = await _apiService.createReport(payload);
      return ReportModel.fromJson(resultMap);
    } on ApiException {
      rethrow;
    } on NetworkException {
      rethrow;
    } on JsonParsingException {
      rethrow;
    } on ValidationException {
      rethrow;
    } catch (e) {
      throw ApiException(statusCode: 500, message: 'Gagal membuat laporan: $e');
    }
  }
}
