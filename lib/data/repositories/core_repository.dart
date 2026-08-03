import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_version_info.dart';
import '../models/core_info.dart';
import '../models/interior_slide.dart';
import '../services/api_client.dart';

class CoreRepository {
  CoreRepository({Dio? dio}) : _dio = dio ?? DioClient.instance.dio;

  final Dio _dio;
  bool isOfflineMode = false;

  Future<SharedPreferences?> _getPrefs() async {
    try {
      return await SharedPreferences.getInstance();
    } catch (_) {
      return null;
    }
  }

  Future<CoreInfo> fetchCoreInfo() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('/core/info/');
      isOfflineMode = false;
      DioClient.isOfflineNotifier.value = false;
      final prefs = await _getPrefs();
      if (prefs != null) {
        await prefs.setString('cache_core_info', jsonEncode(response.data));
      }
      return CoreInfo.fromJson(response.data ?? {});
    } on DioException catch (e) {
      isOfflineMode = true;
      if (e.type != DioExceptionType.badResponse) {
        DioClient.isOfflineNotifier.value = true;
      }
      final prefs = await _getPrefs();
      final cached = prefs?.getString('cache_core_info');
      if (cached != null) {
        return CoreInfo.fromJson(jsonDecode(cached) as Map<String, dynamic>);
      }
      rethrow;
    }
  }

  Future<List<InteriorSlide>> fetchInterior() async {
    try {
      final response = await _dio.get<List<dynamic>>('/core/interior/');
      isOfflineMode = false;
      DioClient.isOfflineNotifier.value = false;
      final prefs = await _getPrefs();
      if (prefs != null) {
        await prefs.setString('cache_interior', jsonEncode(response.data));
      }
      final list = response.data ?? [];
      return list
          .map((e) => InteriorSlide.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(growable: false);
    } on DioException catch (e) {
      isOfflineMode = true;
      if (e.type != DioExceptionType.badResponse) {
        DioClient.isOfflineNotifier.value = true;
      }
      final prefs = await _getPrefs();
      final cached = prefs?.getString('cache_interior');
      if (cached != null) {
        final list = jsonDecode(cached) as List<dynamic>;
        return list
            .map((e) => InteriorSlide.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(growable: false);
      }
      return const [];
    }
  }

  Future<AppVersionInfo> fetchAppVersion(String platform) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/core/app-version/',
        queryParameters: {'platform': platform},
      );
      isOfflineMode = false;
      DioClient.isOfflineNotifier.value = false;
      final prefs = await _getPrefs();
      if (prefs != null) {
        await prefs.setString('cache_app_version_$platform', jsonEncode(response.data));
      }
      return AppVersionInfo.fromJson(response.data ?? {});
    } on DioException catch (e) {
      isOfflineMode = true;
      if (e.type != DioExceptionType.badResponse) {
        DioClient.isOfflineNotifier.value = true;
      }
      final prefs = await _getPrefs();
      final cached = prefs?.getString('cache_app_version_$platform');
      if (cached != null) {
        return AppVersionInfo.fromJson(jsonDecode(cached) as Map<String, dynamic>);
      }
      rethrow;
    }
  }
}
