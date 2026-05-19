import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piligrim/data/models/user_profile.dart';
import 'package:piligrim/data/repositories/profile_repository.dart';

import '../../support/mock_dio_adapter.dart';

Map<String, dynamic> _sampleProfileJson() => {
      'id': 42,
      'phone': '+77001234567',
      'first_name': 'Айдар',
      'last_name': 'Нурланов',
      'notify_events': true,
      'notify_promotions': false,
      'notify_closed_events': true,
    };

void main() {
  group('ProfileRepository', () {
    late MockDioAdapter adapter;
    late ProfileRepository repository;

    setUp(() {
      adapter = MockDioAdapter();
      repository = ProfileRepository(dio: createMockDio(adapter));
    });

    test('fetchProfile returns UserProfile on 200', () async {
      adapter.enqueue(200, _sampleProfileJson());

      final profile = await repository.fetchProfile();

      expect(profile, isA<UserProfile>());
      expect(profile.phone, '+77001234567');
      expect(profile.displayName, 'Айдар Нурланов');
      expect(adapter.captured.single.path, '/users/profile/');
      expect(adapter.captured.single.method, 'GET');
    });

    test('updateProfile sends PATCH with notify_events body', () async {
      adapter.enqueue(200, {
        ..._sampleProfileJson(),
        'notify_events': false,
      });

      final profile = await repository.updateProfile({'notify_events': false});

      expect(profile.notifyEvents, isFalse);
      expect(adapter.captured.single.method, 'PATCH');
      expect(adapter.captured.single.path, '/users/profile/');
      expect(adapter.captured.single.data, {'notify_events': false});
    });
  });
}
