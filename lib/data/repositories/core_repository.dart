import 'package:dio/dio.dart';

import '../models/app_version_info.dart';
import '../models/core_info.dart';
import '../models/interior_slide.dart';
import '../services/api_client.dart';

class CoreRepository {
  CoreRepository({Dio? dio}) : _dio = dio ?? DioClient.instance.dio;

  final Dio _dio;

  Future<CoreInfo> fetchCoreInfo() async {
    final response = await _dio.get<Map<String, dynamic>>('/core/info/');
    return CoreInfo.fromJson(response.data ?? {});
  }

  Future<List<InteriorSlide>> fetchInterior() async {
    final response = await _dio.get<List<dynamic>>('/core/interior/');
    final list = response.data ?? [];
    return list
        .map((e) => InteriorSlide.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList(growable: false);
  }

  Future<AppVersionInfo> fetchAppVersion(String platform) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/core/app-version/',
      queryParameters: {'platform': platform},
    );
    return AppVersionInfo.fromJson(response.data ?? {});
  }
}
