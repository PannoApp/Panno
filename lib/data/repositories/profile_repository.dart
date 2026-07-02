import 'package:dio/dio.dart';

import '../models/user_profile.dart';
import '../services/api_client.dart';

class ProfileRepository {
  ProfileRepository({Dio? dio}) : _dio = dio ?? DioClient.instance.dio;

  final Dio _dio;

  Future<UserProfile> fetchProfile() async {
    final response = await _dio.get<Map<String, dynamic>>('/users/profile/');
    return UserProfile.fromJson(response.data ?? {});
  }

  Future<UserProfile> updateProfile(Map<String, dynamic> patch) async {
    final response = await _dio.patch<Map<String, dynamic>>(
      '/users/profile/',
      data: patch,
    );
    return UserProfile.fromJson(response.data ?? {});
  }
}
