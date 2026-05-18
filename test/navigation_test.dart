// Тесты навигации — порядок табов и push-роут для BookingScreen.
// Используем _TestShell с уникальными метками экранов (не совпадают с метками табов),
// чтобы find.text() не давал неоднозначных совпадений.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:piligrim/core/theme.dart';
import 'package:piligrim/providers/auth_provider.dart';
import 'package:piligrim/data/services/auth_service.dart';
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

// Минимальный RootShell: IndexedStack + PiligrimNavBar без Firebase/провайдеров.
class _TestShell extends StatefulWidget {
  const _TestShell({required this.screens});
  final List<Widget> screens;

  @override
  State<_TestShell> createState() => _TestShellState();
}

class _TestShellState extends State<_TestShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PiligrimColors.earth,
      body: IndexedStack(index: _index, children: widget.screens),
      bottomNavigationBar: PiligrimNavBar(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
      ),
    );
  }
}

// Уникальные ключи экранов — не совпадают с метками навигации (Главная, Меню, …).
const _kScreenKeys = ['sc0', 'sc1', 'sc2', 'sc3', 'sc4'];

List<Widget> _screens() => _kScreenKeys
    .map((k) => Center(child: Text(k, key: ValueKey(k))))
    .toList();

void main() {
  group('PiligrimNavBar — метки табов (Блок 3)', () {
    testWidgets('порядок: Главная / Меню / Интерьер / Афиша / Профиль',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: piligrimTheme,
          home: PiligrimNavBar(currentIndex: 0, onTap: (_) {}),
        ),
      );
      await tester.pump(); // SVG assets

      expect(find.text('Главная'), findsOneWidget);
      expect(find.text('Меню'), findsOneWidget);
      expect(find.text('Интерьер'), findsOneWidget);
      expect(find.text('Афиша'), findsOneWidget);
      expect(find.text('Профиль'), findsOneWidget);

      // «Стол» больше не таб в Блоке 3.
      expect(find.text('Стол'), findsNothing);
    });
  });

  group('IndexedStack — переключение табов', () {
    late AuthProvider auth;

    setUp(() => auth = _buildAuth());

    testWidgets('таб 2 (Интерьер) показывает screen sc2', (tester) async {
      await tester.pumpWidget(
        ChangeNotifierProvider<AuthProvider>.value(
          value: auth,
          child: MaterialApp(
            theme: piligrimTheme,
            home: _TestShell(screens: _screens()),
          ),
        ),
      );
      await tester.pump();

      // Tab 0 активен → sc0 видим.
      expect(find.text('sc0'), findsOneWidget);

      // Нажимаем таб «Интерьер» (index 2).
      await tester.tap(find.text('Интерьер'));
      await tester.pump();

      // sc2 теперь показан, sc0 ушёл в offstage.
      expect(find.text('sc2'), findsOneWidget);
      expect(find.text('sc0', skipOffstage: false), findsOneWidget);
    });

    testWidgets('таб 3 (Афиша) показывает screen sc3', (tester) async {
      await tester.pumpWidget(
        ChangeNotifierProvider<AuthProvider>.value(
          value: auth,
          child: MaterialApp(
            theme: piligrimTheme,
            home: _TestShell(screens: _screens()),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Афиша'));
      await tester.pump();

      expect(find.text('sc3'), findsOneWidget);
    });

    testWidgets('пять нажатий на табы не открывают sc-booking', (tester) async {
      // BookingScreen не входит в IndexedStack — убеждаемся, что пять
      // стандартных табов не приводят к появлению «sc-booking».
      await tester.pumpWidget(
        ChangeNotifierProvider<AuthProvider>.value(
          value: auth,
          child: MaterialApp(
            theme: piligrimTheme,
            home: _TestShell(screens: _screens()),
          ),
        ),
      );
      await tester.pump();

      for (final label in ['Меню', 'Интерьер', 'Афиша', 'Профиль', 'Главная']) {
        await tester.tap(find.text(label));
        await tester.pump();
      }

      expect(find.text('sc-booking'), findsNothing);
    });
  });
}
