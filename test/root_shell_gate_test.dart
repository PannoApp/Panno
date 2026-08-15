// Глобальный gate RootShell (docs/piligrim_improvements_plan.md, Фаза D.4):
// неавторизованный гость должен видеть только экран входа/регистрации —
// ни один таб (Home/Menu/Interior/Events/Profile) не должен собираться.
//
// Полный рендер авторизованного состояния (весь IndexedStack с 5 экранами)
// не покрыт здесь намеренно — для этого потребовался бы мок всех провайдеров
// приложения (Menu/Events/Booking/CoreInfo), которых RootShell сам не создаёт
// (получает от PiligrimApp выше по дереву); такого сквозного теста нет и для
// самого PiligrimApp в существующем тестовом наборе. Здесь проверяется именно
// условие gate — единственная новая логика, добавленная в main.dart.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:piligrim/core/theme.dart';
import 'package:piligrim/data/services/auth_service.dart';
import 'package:piligrim/main.dart';
import 'package:piligrim/providers/auth_provider.dart';
import 'package:piligrim/widgets/bottom_nav_bar.dart';

import 'support/fake_token_storage.dart';
import 'support/mock_dio_adapter.dart';

AuthProvider _buildAuth() {
  final adapter = MockDioAdapter();
  final dio = createMockDio(adapter);
  return AuthProvider(
    tokenStorage: FakeTokenStorage(),
    dio: dio,
    authService: AuthService(dio),
  );
}

Widget _wrap(AuthProvider auth) {
  return ChangeNotifierProvider<AuthProvider>.value(
    value: auth,
    child: MaterialApp(
      theme: piligrimTheme,
      home: const RootShell(),
    ),
  );
}

// PiligrimAuthView использует flutter_animate (.animate().fadeIn(...)) на
// нескольких элементах — без довыполнения этих таймеров тест падает с
// "A Timer is still pending" при разрушении дерева виджетов.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 900));
  for (var i = 0; i < 10; i++) {
    await tester.pump(Duration.zero);
  }
}

void main() {
  group('RootShell — глобальный gate', () {
    testWidgets('неавторизованный гость видит экран входа, не таб-бар',
        (tester) async {
      final auth = _buildAuth();
      await tester.pumpWidget(_wrap(auth));
      await _settle(tester);

      expect(find.text('НАЧАТЬ ПУТЬ'), findsOneWidget);
      expect(find.byType(PiligrimNavBar), findsNothing);
    });

    testWidgets('гость видит только вход/регистрацию — Главная/Меню недоступны',
        (tester) async {
      final auth = _buildAuth();
      await tester.pumpWidget(_wrap(auth));
      await _settle(tester);

      expect(find.text('Главная'), findsNothing);
      expect(find.text('Меню'), findsNothing);
      expect(find.text('Профиль'), findsNothing);
    });
  });
}
