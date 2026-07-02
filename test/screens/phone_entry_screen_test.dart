// Виджет-тесты PhoneEntryScreen — форма телефона + OTP на одном экране.
// PhoneEntryScreen объединяет ввод телефона и ввод кода (флаг _awaitingCode).
//
// ВАЖНО: EmberCta и PiligrimBackground используют бесконечные AnimationController
// с repeat(), поэтому pumpAndSettle() всегда тайм-аутится.
// Вместо этого используем pump() + pump(duration) для ожидания async-операций.
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:flutter/material.dart';

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
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 200));
}

void main() {
  group('PhoneEntryScreen — ввод телефона', () {
    late MockDioAdapter adapter;
    late AuthProvider auth;

    setUp(() {
      adapter = MockDioAdapter();
      auth = _buildAuth(adapter);
    });

    testWidgets('поле пустое — нажатие не вызывает sendOtp', (tester) async {
      await tester.pumpWidget(_wrap(const PhoneEntryScreen(), auth));
      await tester.pump();

      await tester.tap(find.text('Получить код'));
      await _settle(tester);

      // Форма не прошла валидацию — сетевой запрос не отправлен.
      expect(adapter.captured, isEmpty);
    });

    testWidgets('короткий номер < 11 цифр — нет перехода к вводу кода',
        (tester) async {
      await tester.pumpWidget(_wrap(const PhoneEntryScreen(), auth));
      await tester.pump();

      await tester.enterText(find.byType(TextFormField).first, '79991234');
      await tester.tap(find.text('Получить код'));
      await _settle(tester);

      // Форма не прошла → код не запрошен, поле «Код» не появилось.
      expect(adapter.captured, isEmpty);
      expect(find.text('Подтвердить'), findsNothing);
    });

    testWidgets('корректный номер 11 цифр — sendOtp вызван', (tester) async {
      adapter.enqueue(200, <String, dynamic>{});

      await tester.pumpWidget(_wrap(const PhoneEntryScreen(), auth));
      await tester.pump();

      await tester.enterText(find.byType(TextFormField).first, '+77771234567');
      await tester.tap(find.text('Получить код'));
      await _settle(tester);

      expect(
        adapter.captured.any((r) => r.path.contains('request-sms')),
        isTrue,
      );
    });

    testWidgets('успешный sendOtp — экран переключается на ввод кода',
        (tester) async {
      adapter.enqueue(200, <String, dynamic>{});

      await tester.pumpWidget(_wrap(const PhoneEntryScreen(), auth));
      await tester.pump();

      await tester.enterText(find.byType(TextFormField).first, '+77771234567');
      await tester.tap(find.text('Получить код'));
      await _settle(tester);

      // После sendOtp кнопка переключается на «Подтвердить» — OTP-этап.
      expect(find.text('Подтвердить'), findsOneWidget);
    });
  });

  group('PhoneEntryScreen — ввод OTP кода', () {
    late MockDioAdapter adapter;
    late AuthProvider auth;

    setUp(() {
      adapter = MockDioAdapter();
      auth = _buildAuth(adapter);
    });

    // Переводит экран в OTP-этап.
    Future<void> navigateToOtpStage(WidgetTester tester) async {
      adapter.enqueue(200, <String, dynamic>{});
      await tester.pumpWidget(_wrap(const PhoneEntryScreen(), auth));
      await tester.pump();
      await tester.enterText(find.byType(TextFormField).first, '+77771234567');
      await tester.tap(find.text('Получить код'));
      await _settle(tester);
    }

    testWidgets('код короче 4 символов — confirmOtp не вызван', (tester) async {
      await navigateToOtpStage(tester);

      await tester.enterText(find.byType(TextFormField).first, '123');
      await tester.tap(find.text('Подтвердить'));
      await _settle(tester);

      expect(
        adapter.captured.any((r) => r.path.contains('verify-sms')),
        isFalse,
      );
    });

    testWidgets('успешный confirmOtp — AuthProvider.isLoggedIn == true',
        (tester) async {
      await navigateToOtpStage(tester);

      // verify-sms
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

      await tester.enterText(find.byType(TextFormField).first, '123456');
      await tester.tap(find.text('Подтвердить'));
      await _settle(tester);

      // Единственный источник истины о входе — AuthProvider.
      expect(auth.isLoggedIn, isTrue);
    });
  });
}
