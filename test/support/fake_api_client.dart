import 'package:http/http.dart' as http;
import 'package:piligrim/data/api_client.dart';
import 'package:piligrim/data/token_storage.dart';

/// In-memory [ApiClient] для unit-тестов.
class FakeApiClient extends ApiClient {
  FakeApiClient({
    required TokenStorage tokenStorage,
    this.getResponses = const {},
    this.postResponses = const {},
    this.patchResponses = const {},
  }) : super(
          baseUrl: 'http://test',
          tokenStorage: tokenStorage,
          httpClient: http.Client(),
        );

  final Map<String, Map<String, dynamic>> getResponses;
  final Map<String, Map<String, dynamic>> postResponses;
  final Map<String, Map<String, dynamic>> patchResponses;

  final List<String> getCalls = [];
  final List<String> postCalls = [];
  final List<String> patchCalls = [];

  @override
  Future<Map<String, dynamic>> get(
    String path, {
    bool authenticated = true,
  }) async {
    getCalls.add(path);
    return Map<String, dynamic>.from(getResponses[path] ?? {});
  }

  @override
  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? body,
    bool authenticated = true,
  }) async {
    postCalls.add(path);
    return Map<String, dynamic>.from(postResponses[path] ?? {});
  }

  @override
  Future<Map<String, dynamic>> patch(
    String path, {
    Map<String, dynamic>? body,
    bool authenticated = true,
  }) async {
    patchCalls.add(path);
    final base = Map<String, dynamic>.from(patchResponses[path] ?? {});
    if (body != null) {
      base.addAll(body);
    }
    return base;
  }
}
