// Виджет-тесты PhoneEntryScreen — единый экран: телефон + номер участника
// лояльности видны сразу (вход), либо телефон + форма регистрации — без
// промежуточного шага «сначала телефон, потом остальное» (SMS-код полностью
// убран из UI, см. docs/piligrim_improvements_plan.md, Фаза D).
//
// ВАЖНО: EmberCta и PiligrimBackground используют бесконечные AnimationController
// с repeat(), поэтому pumpAndSettle() всегда тайм-аутится.
// Вместо этого используем pump() + pump(duration) для ожидания async-операций.
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:piligrim/data/services/auth_service.dart';
import 'package:piligrim/providers/auth_provider.dart';
import 'package:piligrim/screens/phone_entry_screen.dart';

import '../support/fake_token_storage.dart';
import '../support/mock_dio_adapter.dart';

AuthProvider _buildAuth(MockDioAdapter adapter) {
  final dio = createMockDio(adapter);
  return AuthProvider(
    tokenStorage: FakeTokenStorage(),
    dio: dio,
    authService: AuthService(dio),
  );
}

Widget _wrap(Widget screen, AuthProvider auth) {
  return ChangeNotifierProvider<AuthProvider>.value(
    value: auth,
    child: MaterialApp(home: screen),
  );
}

// Ожидание завершения async-операций без pumpAndSettle (обходим бесконечные анимации).
// Долгий хвост обязателен для сценариев с сетевым логином/регистрацией: без
// мока платформенного канала Firebase Messaging AuthProvider._registerFcmIfPossible()
// висит до собственного 5-секундного таймаута (см. auth_provider.dart), прежде
// чем финальный notifyListeners() отработает.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
  await tester.pump(const Duration(seconds: 3));
  await tester.pump(const Duration(seconds: 3));
  for (var i = 0; i < 10; i++) {
    await tester.pump(Duration.zero);
  }
}

void main() {
  group('PhoneEntryScreen — вход по номеру участника (экран по умолчанию)', () {
    late MockDioAdapter adapter;
    late AuthProvider auth;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      adapter = MockDioAdapter();
      auth = _buildAuth(adapter);
    });

    testWidgets('оба поля видны сразу, без промежуточного шага',
        (tester) async {
      await tester.pumpWidget(_wrap(const PhoneEntryScreen(), auth));
      await _settle(tester);

      expect(find.text('ВХОД ПО НОМЕРУ УЧАСТНИКА'), findsNothing);
      expect(find.text('НАЧАТЬ ПУТЬ'), findsOneWidget);
      expect(find.text('ВОЙТИ'), findsOneWidget);
      expect(find.byType(TextField), findsNWidgets(2));
    });

    testWidgets('пустой телефон — нажатие «Войти» не уходит в сеть',
        (tester) async {
      await tester.pumpWidget(_wrap(const PhoneEntryScreen(), auth));
      await tester.pump();

      await tester.tap(find.text('ВОЙТИ'));
      await _settle(tester);

      expect(adapter.captured, isEmpty);
    });

    testWidgets('короткий телефон < 11 цифр — нет запроса на бэкенд',
        (tester) async {
      await tester.pumpWidget(_wrap(const PhoneEntryScreen(), auth));
      await tester.pump();

      await tester.enterText(find.byType(TextField).at(0), '79991234');
      await tester.tap(find.text('ВОЙТИ'));
      await _settle(tester);

      expect(adapter.captured, isEmpty);
    });

    testWidgets('корректный телефон, но пустой номер участника — loginWithMemberNumber не вызван',
        (tester) async {
      await tester.pumpWidget(_wrap(const PhoneEntryScreen(), auth));
      await tester.pump();

      await tester.enterText(find.byType(TextField).at(0), '+77771234567');
      await tester.tap(find.text('ВОЙТИ'));
      await _settle(tester);

      expect(
        adapter.captured.any((r) => r.path.contains('loyalty-login')),
        isFalse,
      );
    });

    testWidgets('успешный вход — AuthProvider.isLoggedIn == true',
        (tester) async {
      await tester.pumpWidget(_wrap(const PhoneEntryScreen(), auth));
      await tester.pump();

      // loyalty-login
      adapter.enqueue(200, {
        'access': 'tok',
        'refresh': 'ref',
        'is_new_user': false,
      });
      // GET /users/profile/
      adapter.enqueue(200, {
        'id': 1,
        'phone': '+77771234567',
        'first_name': '',
        'last_name': '',
        'notify_events': true,
        'notify_promotions': true,
        'notify_closed_events': false,
      });

      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), '+77771234567');
      await tester.enterText(fields.at(1), '113');
      await tester.tap(find.text('ВОЙТИ'));
      await _settle(tester);

      // Единственный источник истины о входе — AuthProvider.
      expect(auth.isLoggedIn, isTrue);
      expect(
        adapter.captured.any((r) => r.path.contains('loyalty-login')),
        isTrue,
      );
    });

    testWidgets('«У меня нет карты — регистрация» переключает на форму регистрации',
        (tester) async {
      await tester.pumpWidget(_wrap(const PhoneEntryScreen(), auth));
      await tester.pump();

      final registerLink = find.text('У меня нет карты — регистрация');
      await tester.ensureVisible(registerLink);
      await tester.tap(registerLink);
      await _settle(tester);

      expect(find.text('РЕГИСТРАЦИЯ'), findsOneWidget);
      expect(find.text('ЗАРЕГИСТРИРОВАТЬСЯ'), findsOneWidget);
    });
  });

  group('PhoneEntryScreen — регистрация', () {
    late MockDioAdapter adapter;
    late AuthProvider auth;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      adapter = MockDioAdapter();
      auth = _buildAuth(adapter);
    });

    // Переводит экран на форму регистрации (телефон остаётся общим полем).
    Future<void> navigateToRegisterStage(WidgetTester tester) async {
      await tester.pumpWidget(_wrap(const PhoneEntryScreen(), auth));
      await tester.pump();
      await tester.enterText(find.byType(TextField).at(0), '+77771234567');
      final registerLink = find.text('У меня нет карты — регистрация');
      await tester.ensureVisible(registerLink);
      await tester.tap(registerLink);
      await _settle(tester);
    }

    testWidgets('пустое имя — register не вызван', (tester) async {
      await navigateToRegisterStage(tester);

      await tester.ensureVisible(find.text('ЗАРЕГИСТРИРОВАТЬСЯ'));
      await tester.tap(find.text('ЗАРЕГИСТРИРОВАТЬСЯ'));
      await _settle(tester);

      expect(
        adapter.captured.any((r) => r.path.contains('loyalty-register')),
        isFalse,
      );
    });

    testWidgets('пустой телефон на форме регистрации — register не вызван',
        (tester) async {
      await tester.pumpWidget(_wrap(const PhoneEntryScreen(), auth));
      await tester.pump();
      final registerLink = find.text('У меня нет карты — регистрация');
      await tester.ensureVisible(registerLink);
      await tester.tap(registerLink);
      await _settle(tester);

      // Телефон не был введён на предыдущем шаге — поле остаётся пустым.
      await tester.enterText(find.byType(TextField).at(1), 'Айдар');
      await tester.ensureVisible(find.text('ЗАРЕГИСТРИРОВАТЬСЯ'));
      await tester.tap(find.text('ЗАРЕГИСТРИРОВАТЬСЯ'));
      await _settle(tester);

      expect(
        adapter.captured.any((r) => r.path.contains('loyalty-register')),
        isFalse,
      );
    });

    testWidgets(
        'успешная регистрация — AuthProvider.isLoggedIn == true, номер участника показан',
        (tester) async {
      await navigateToRegisterStage(tester);

      // loyalty-register
      adapter.enqueue(200, {
        'access': 'tok',
        'refresh': 'ref',
        'user_id': 1,
        'member_number': '113',
      });
      // GET /users/profile/
      adapter.enqueue(200, {
        'id': 1,
        'phone': '+77771234567',
        'first_name': 'Айдар',
        'last_name': '',
        'notify_events': true,
        'notify_promotions': true,
        'notify_closed_events': false,
      });

      // Поле имени — первое из полей формы регистрации, после телефона.
      final nameField = find.byType(TextField).at(1);
      await tester.enterText(nameField, 'Айдар');
      await tester.ensureVisible(find.text('ЗАРЕГИСТРИРОВАТЬСЯ'));
      await tester.tap(find.text('ЗАРЕГИСТРИРОВАТЬСЯ'));
      await _settle(tester);

      expect(
        adapter.captured.any((r) => r.path.contains('loyalty-register')),
        isTrue,
      );
      // Диалог с номером участника показывается поверх экрана — «Понятно»
      // закрывает его, дальше AuthProvider уже авторизован.
      expect(find.text('113'), findsOneWidget);
      await tester.tap(find.text('Понятно'));
      await _settle(tester);

      expect(auth.isLoggedIn, isTrue);
    });

    testWidgets('«У меня уже есть номер лояльности» возвращает на вход',
        (tester) async {
      await navigateToRegisterStage(tester);

      final loginLink = find.text('У меня уже есть номер лояльности');
      await tester.ensureVisible(loginLink);
      await tester.tap(loginLink);
      await _settle(tester);

      expect(find.text('НАЧАТЬ ПУТЬ'), findsOneWidget);
      expect(find.text('ВОЙТИ'), findsOneWidget);
    });
  });
}
