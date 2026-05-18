import 'dart:convert';

import 'package:http/http.dart' as http;

import 'token_storage.dart';

/// REST-клиент PILIGRIM (Блок 1).
class ApiClient {
  ApiClient({
    required this.baseUrl,
    required this.tokenStorage,
    http.Client? httpClient,
  }) : _http = httpClient ?? http.Client();

  final String baseUrl;
  final TokenStorage tokenStorage;
  final http.Client _http;

  Future<Map<String, dynamic>> get(
    String path, {
    bool authenticated = true,
  }) async {
    final response = await _http.get(
      _uri(path),
      headers: await _headers(authenticated: authenticated),
    );
    return _decodeResponse(response);
  }

  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? body,
    bool authenticated = true,
  }) async {
    final response = await _http.post(
      _uri(path),
      headers: await _headers(authenticated: authenticated),
      body: body == null ? null : jsonEncode(body),
    );
    return _decodeResponse(response);
  }

  Future<Map<String, dynamic>> patch(
    String path, {
    Map<String, dynamic>? body,
    bool authenticated = true,
  }) async {
    final response = await _http.patch(
      _uri(path),
      headers: await _headers(authenticated: authenticated),
      body: body == null ? null : jsonEncode(body),
    );
    return _decodeResponse(response);
  }

  Uri _uri(String path) {
    final normalized = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$baseUrl$normalized');
  }

  Future<Map<String, String>> _headers({required bool authenticated}) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (authenticated) {
      final token = await tokenStorage.getAccessToken();
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    }
    return headers;
  }

  Map<String, dynamic> _decodeResponse(http.Response response) {
    final status = response.statusCode;
    Map<String, dynamic>? body;
    if (response.body.isNotEmpty) {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        body = decoded;
      } else if (decoded is Map) {
        body = Map<String, dynamic>.from(decoded);
      }
    }
    if (status >= 200 && status < 300) {
      return body ?? <String, dynamic>{};
    }
    throw ApiException(
      statusCode: status,
      message: body?['detail']?.toString() ?? response.body,
    );
  }

  void close() => _http.close();
}

class ApiException implements Exception {
  ApiException({required this.statusCode, this.message});

  final int statusCode;
  final String? message;

  @override
  String toString() => 'ApiException($statusCode): $message';
}

/// Базовый URL API (переопределяется через --dart-define=API_BASE_URL=...).
class ApiConfig {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://api.piligrim.kz',
  );
}
