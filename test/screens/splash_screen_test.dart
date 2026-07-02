import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:piligrim/data/models/app_version_info.dart';
import 'package:piligrim/data/repositories/core_repository.dart';
import 'package:piligrim/data/services/auth_service.dart';
import 'package:piligrim/providers/auth_provider.dart';
import 'package:piligrim/screens/onboarding_screen.dart';
import 'package:piligrim/screens/splash_screen.dart';

import '../support/fake_token_storage.dart';
import '../support/mock_dio_adapter.dart';

class _MockCoreRepository extends Mock implements CoreRepository {}

AppVersionInfo _versionInfo({required String min, required String latest}) =>
    AppVersionInfo(
      platform: 'android',
      minVersion: min,
      latestVersion: latest,
      storeUrl: 'https://example.com',
    );

AuthProvider _fakeAuth({bool isNewUser = false}) {
  final adapter = MockDioAdapter();
  final dio = createMockDio(adapter);
  return AuthProvider(
    tokenStorage: FakeTokenStorage(),
    dio: dio,
    authService: AuthService(dio),
  )..isNewUser = isNewUser;
}

void main() {
  group('SplashScreen — версионирование', () {
    late _MockCoreRepository mockRepo;

    setUp(() {
      mockRepo = _MockCoreRepository();
    });

    Widget buildSplash({VoidCallback? onNavigateToHome, AuthProvider? auth}) =>
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(
              value: auth ?? _fakeAuth(),
            ),
          ],
          child: MaterialApp(
            home: SplashScreen(
              coreRepository: mockRepo,
              onNavigateToHome: onNavigateToHome ?? () {},
            ),
          ),
        );

    // Прокачивает тесты мимо 3200мс таймера и ждёт разрешения всех Future.
    Future<void> pumpPastSplash(WidgetTester tester) async {
      await tester.pump(const Duration(milliseconds: 3300));
      await tester.pump(); // разрешаем Future fetchAppVersion
      await tester.pump(); // обрабатываем showDialog / setState
    }

    testWidgets('Если текущая версия < minVersion → AlertDialog показан',
        (tester) async {
      // kAppVersion = '1.0.0'; minVersion = '2.0.0' → текущая устарела
      when(() => mockRepo.fetchAppVersion(any()))
          .thenAnswer((_) async => _versionInfo(min: '2.0.0', latest: '2.0.0'));

      await tester.pumpWidget(buildSplash());
      await pumpPastSplash(tester);

      expect(find.byType(AlertDialog), findsOneWidget);
    });

    testWidgets('AlertDialog не имеет кнопки закрытия (неотклоняемый)',
        (tester) async {
      when(() => mockRepo.fetchAppVersion(any()))
          .thenAnswer((_) async => _versionInfo(min: '2.0.0', latest: '2.0.0'));

      await tester.pumpWidget(buildSplash());
      await pumpPastSplash(tester);

      expect(find.byType(AlertDialog), findsOneWidget);

      // Единственное действие — «Обновить»; кнопок закрытия нет
      expect(find.text('Обновить'), findsOneWidget);
      expect(find.text('Закрыть'), findsNothing);
      expect(find.text('Отмена'), findsNothing);

      // PopScope(canPop: false) — диалог нельзя закрыть кнопкой «Назад»
      expect(
        find.byWidgetPredicate((w) => w is PopScope && w.canPop == false),
        findsWidgets,
      );
    });

    testWidgets('Если версия актуальная → нет диалога', (tester) async {
      // kAppVersion = '1.0.0'; min='1.0.0', latest='1.0.0' → актуально
      when(() => mockRepo.fetchAppVersion(any()))
          .thenAnswer((_) async => _versionInfo(min: '1.0.0', latest: '1.0.0'));

      var navigated = false;
      await tester.pumpWidget(
        buildSplash(onNavigateToHome: () => navigated = true),
      );
      await pumpPastSplash(tester);

      expect(find.byType(AlertDialog), findsNothing);
      expect(navigated, isTrue);
    });

    testWidgets('При isNewUser=true навигация идёт на OnboardingScreen',
        (tester) async {
      when(() => mockRepo.fetchAppVersion(any()))
          .thenAnswer((_) async => _versionInfo(min: '1.0.0', latest: '1.0.0'));

      await tester.pumpWidget(buildSplash(auth: _fakeAuth(isNewUser: true)));
      await pumpPastSplash(tester);
      // Ждём завершения flutter_animate анимаций OnboardingScreen (max delay+duration = 1000ms)
      await tester.pump(const Duration(milliseconds: 1000));

      expect(find.byType(OnboardingScreen), findsOneWidget);
    });

    testWidgets('При isNewUser=false навигация идёт на RootShell',
        (tester) async {
      when(() => mockRepo.fetchAppVersion(any()))
          .thenAnswer((_) async => _versionInfo(min: '1.0.0', latest: '1.0.0'));

      var navigated = false;
      await tester.pumpWidget(
        buildSplash(
          auth: _fakeAuth(isNewUser: false),
          onNavigateToHome: () => navigated = true,
        ),
      );
      await pumpPastSplash(tester);

      expect(navigated, isTrue);
      expect(find.byType(OnboardingScreen), findsNothing);
    });
  });
}
