import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:piligrim/data/services/token_storage.dart';

class _MockSecureStorage extends Mock implements FlutterSecureStorage {}

void main() {
  late _MockSecureStorage mockStorage;
  late TokenStorage tokenStorage;

  setUp(() {
    mockStorage = _MockSecureStorage();
    tokenStorage = TokenStorage(storage: mockStorage);
  });

  group('saveTokens', () {
    setUp(() {
      when(
        () => mockStorage.write(
          key: any(named: 'key'),
          value: any(named: 'value'),
        ),
      ).thenAnswer((_) async {});
    });

    test('readAccess() возвращает сохранённый access', () async {
      when(() => mockStorage.read(key: 'access_token'))
          .thenAnswer((_) async => 'acc_123');

      await tokenStorage.saveTokens(access: 'acc_123', refresh: 'ref_456');
      final result = await tokenStorage.readAccess();

      expect(result, 'acc_123');
    });

    test('readRefresh() возвращает сохранённый refresh', () async {
      when(() => mockStorage.read(key: 'refresh_token'))
          .thenAnswer((_) async => 'ref_456');

      await tokenStorage.saveTokens(access: 'acc_123', refresh: 'ref_456');
      final result = await tokenStorage.readRefresh();

      expect(result, 'ref_456');
    });
  });

  group('clearTokens', () {
    setUp(() {
      when(
        () => mockStorage.delete(key: any(named: 'key')),
      ).thenAnswer((_) async {});
    });

    test('readAccess() возвращает null', () async {
      when(() => mockStorage.read(key: 'access_token'))
          .thenAnswer((_) async => null);

      await tokenStorage.clearTokens();
      final result = await tokenStorage.readAccess();

      expect(result, isNull);
    });

    test('readRefresh() возвращает null', () async {
      when(() => mockStorage.read(key: 'refresh_token'))
          .thenAnswer((_) async => null);

      await tokenStorage.clearTokens();
      final result = await tokenStorage.readRefresh();

      expect(result, isNull);
    });
  });
}
