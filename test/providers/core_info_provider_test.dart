import 'package:flutter_test/flutter_test.dart';
import 'package:piligrim/data/models/core_info.dart';
import 'package:piligrim/data/models/interior_slide.dart';
import 'package:piligrim/data/repositories/core_repository.dart';
import 'package:piligrim/providers/core_info_provider.dart';
import 'package:mocktail/mocktail.dart';

class _MockCoreRepository extends Mock implements CoreRepository {}

CoreInfo _sampleCoreInfo() => CoreInfo.fromJson({
      'address': 'Алматы',
      'working_hours': '12:00–23:00',
      'is_open_now': true,
      'phone': '+7700',
      'visit_rules': 'rules',
      'privacy_policy': 'policy',
      'booking_deposit_required': false,
    });

void main() {
  group('CoreInfoProvider', () {
    late _MockCoreRepository repository;

    setUp(() {
      repository = _MockCoreRepository();
    });

    test('load sets coreInfo after success', () async {
      when(() => repository.fetchCoreInfo()).thenAnswer((_) async => _sampleCoreInfo());
      when(() => repository.fetchInterior()).thenAnswer((_) async => <InteriorSlide>[]);

      final provider = CoreInfoProvider(repository: repository);
      await provider.load();

      expect(provider.coreInfo, isNotNull);
      expect(provider.isOpenNow, isTrue);
      expect(provider.error, isNull);
    });

    test('load sets error on failure', () async {
      when(() => repository.fetchCoreInfo()).thenThrow(Exception('network'));
      when(() => repository.fetchInterior()).thenAnswer((_) async => []);

      final provider = CoreInfoProvider(repository: repository);
      await provider.load();

      expect(provider.coreInfo, isNull);
      expect(provider.error, isNotNull);
    });

    test('load does not double-fetch when coreInfo loaded', () async {
      when(() => repository.fetchCoreInfo()).thenAnswer((_) async => _sampleCoreInfo());
      when(() => repository.fetchInterior()).thenAnswer((_) async => []);

      final provider = CoreInfoProvider(repository: repository);
      await provider.load();
      await provider.load();

      verify(() => repository.fetchCoreInfo()).called(1);
    });

    test('isOpenNow reads from coreInfo after load', () async {
      when(() => repository.fetchCoreInfo()).thenAnswer(
        (_) async => CoreInfo.fromJson({
          'address': 'Алматы',
          'working_hours': '12:00–23:00',
          'is_open_now': false,
          'phone': '+7700',
          'visit_rules': 'rules',
          'privacy_policy': 'policy',
          'booking_deposit_required': false,
        }),
      );
      when(() => repository.fetchInterior()).thenAnswer((_) async => []);

      final provider = CoreInfoProvider(repository: repository);
      await provider.load();

      expect(provider.coreInfo!.isOpenNow, isFalse);
      expect(provider.isOpenNow, isFalse);
    });
  });
}
