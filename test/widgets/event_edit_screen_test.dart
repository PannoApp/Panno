import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:piligrim/core/theme.dart';
import 'package:piligrim/data/models/api_event.dart';
import 'package:piligrim/data/services/api_client.dart';
import 'package:piligrim/providers/events_provider.dart';
import 'package:piligrim/screens/event_edit_screen.dart';
import 'package:piligrim/widgets/piligrim_loader.dart';

import '../support/mock_dio_adapter.dart';

class _MockEventsProvider extends Mock implements EventsProvider {}

class _MockSecureStoragePlatform extends Mock
    with MockPlatformInterfaceMixin
    implements FlutterSecureStoragePlatform {}

void main() {
  final someEvent = ApiEvent(
    id: 42,
    title: 'Вечер казахской музыки',
    description: 'Живое выступление домбристов',
    startsAt: DateTime(2025, 9, 15, 19, 0),
    format: ApiEventFormat.closed,
    priceFrom: 3000,
    isPast: false,
    isActive: true,
    maxPlaces: 50,
  );

  group('EventEditScreen Widget Tests', () {
    late HttpClientAdapter originalAdapter;
    late MockDioAdapter mockAdapter;
    late _MockEventsProvider mockEventsProvider;
    late _MockSecureStoragePlatform mockSecureStoragePlatform;

    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      mockAdapter = MockDioAdapter();
      originalAdapter = DioClient.instance.dio.httpClientAdapter;
      DioClient.instance.dio.httpClientAdapter = mockAdapter;

      mockEventsProvider = _MockEventsProvider();
      when(() => mockEventsProvider.load()).thenAnswer((_) async {});

      mockSecureStoragePlatform = _MockSecureStoragePlatform();
      FlutterSecureStoragePlatform.instance = mockSecureStoragePlatform;
      when(() => mockSecureStoragePlatform.read(
            key: any(named: 'key'),
            options: any(named: 'options'),
          )).thenAnswer((_) async => null);
      when(() => mockSecureStoragePlatform.write(
            key: any(named: 'key'),
            value: any(named: 'value'),
            options: any(named: 'options'),
          )).thenAnswer((_) async {});
      when(() => mockSecureStoragePlatform.delete(
            key: any(named: 'key'),
            options: any(named: 'options'),
          )).thenAnswer((_) async {});

      const channel = MethodChannel('plugins.itrix.io/flutter_secure_storage');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'read') return null;
        if (call.method == 'write') return null;
        if (call.method == 'delete') return null;
        return null;
      });
    });

    tearDown(() {
      DioClient.instance.dio.httpClientAdapter = originalAdapter;
      const channel = MethodChannel('plugins.itrix.io/flutter_secure_storage');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    Widget buildApp({ApiEvent? event}) {
      return MultiProvider(
        providers: [
          ChangeNotifierProvider<EventsProvider>.value(value: mockEventsProvider),
        ],
        child: MaterialApp(
          theme: piligrimTheme,
          home: EventEditScreen(event: event),
        ),
      );
    }

    Future<void> settle(WidgetTester tester) async {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
    }

    // ─── Rendering ─────────────────────────────────────────────────────────────

    testWidgets(
      'test_renders_in_create_mode — event=null → поля пустые, нет иконки удаления',
      (tester) async {
        await tester.pumpWidget(buildApp(event: null));
        await tester.pump();

        expect(find.text('Создать мероприятие'), findsOneWidget);
        expect(find.text('Редактировать мероприятие'), findsNothing);

        final titleField = tester.widget<TextFormField>(
          find.widgetWithText(TextFormField, 'Введите название'),
        );
        expect(titleField.controller?.text, '');

        final descField = tester.widget<TextFormField>(
          find.widgetWithText(TextFormField, 'Краткое описание мероприятия'),
        );
        expect(descField.controller?.text, '');

        final priceField = tester.widget<TextFormField>(
          find.widgetWithText(TextFormField, 'Оставьте пустым для свободного входа'),
        );
        expect(priceField.controller?.text, '');

        expect(find.byIcon(Icons.delete_outline_rounded), findsNothing);
        expect(find.text('ОПУБЛИКОВАТЬ'), findsOneWidget);
      },
    );

    testWidgets(
      'test_renders_in_edit_mode — event=someEvent → поля заполнены, иконка удаления есть',
      (tester) async {
        await tester.pumpWidget(buildApp(event: someEvent));
        await tester.pump();

        expect(find.text('Редактировать мероприятие'), findsOneWidget);
        expect(find.text('Создать мероприятие'), findsNothing);

        final titleField = tester.widget<TextFormField>(
          find.widgetWithText(TextFormField, 'Введите название'),
        );
        expect(titleField.controller?.text, 'Вечер казахской музыки');

        final descField = tester.widget<TextFormField>(
          find.widgetWithText(TextFormField, 'Краткое описание мероприятия'),
        );
        expect(descField.controller?.text, 'Живое выступление домбристов');

        final priceField = tester.widget<TextFormField>(
          find.widgetWithText(TextFormField, 'Оставьте пустым для свободного входа'),
        );
        expect(priceField.controller?.text, '3000');

        expect(find.byIcon(Icons.delete_outline_rounded), findsOneWidget);
        expect(find.text('СОХРАНИТЬ ИЗМЕНЕНИЯ'), findsOneWidget);
        expect(find.text('15.09.2025, 19:00'), findsOneWidget);
      },
    );

    // ─── Validation ────────────────────────────────────────────────────────────

    testWidgets(
      'test_validation_title_required — submit без title → ошибка валидации',
      (tester) async {
        await tester.pumpWidget(buildApp(event: null));
        await tester.pump();

        await tester.ensureVisible(find.text('ОПУБЛИКОВАТЬ'));
        await tester.tap(find.text('ОПУБЛИКОВАТЬ'));
        await tester.pump();

        expect(find.text('Укажите название мероприятия'), findsOneWidget);
      },
    );

    testWidgets(
      'test_format_dropdown_has_two_options — два варианта: Открытое, Закрытое',
      (tester) async {
        await tester.pumpWidget(buildApp(event: null));
        await tester.pump();

        final dropdown = find.byType(DropdownButtonFormField<ApiEventFormat>);
        expect(dropdown, findsOneWidget);
        await tester.ensureVisible(dropdown);
        await tester.pumpAndSettle();
        await tester.tap(dropdown);
        await tester.pumpAndSettle();

        expect(find.text('Открытое'), findsWidgets);
        expect(find.text('Закрытое'), findsOneWidget);
      },
    );

    // ─── Save ──────────────────────────────────────────────────────────────────

    testWidgets(
      'test_save_calls_createEvent_in_create_mode — mock repo → createEvent вызван',
      (tester) async {
        mockAdapter.enqueue(201, null); // POST /events/admin/events/

        await tester.pumpWidget(buildApp(event: null));
        await tester.pump();

        // Вводим обязательное поле названия
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Введите название'),
          'Новое мероприятие',
        );

        // Устанавливаем дату через пикер: поле date-time — 3-й TextFormField (index 2)
        final dateField = find.byType(TextFormField).at(2);
        await tester.ensureVisible(dateField);
        await tester.pumpAndSettle();
        await tester.tap(dateField);
        await tester.pumpAndSettle();
        // Подтверждаем дату, затем время
        await tester.tap(find.text('OK'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('OK'));
        await tester.pumpAndSettle();

        // Нажимаем «ОПУБЛИКОВАТЬ»
        await tester.ensureVisible(find.text('ОПУБЛИКОВАТЬ'));
        await tester.tap(find.text('ОПУБЛИКОВАТЬ'));
        await settle(tester);

        // POST-запрос на создание мероприятия должен быть выполнен
        final createReq = mockAdapter.captured.firstWhere(
          (r) => r.method == 'POST' && r.path.contains('/events/admin/events/'),
        );
        expect(createReq, isNotNull);

        verify(() => mockEventsProvider.load()).called(1);
      },
    );

    testWidgets(
      'test_save_calls_updateEvent_in_edit_mode — mock repo → updateEvent(id, ...) вызван',
      (tester) async {
        mockAdapter.enqueue(200, null); // PATCH /events/admin/events/42/

        await tester.pumpWidget(buildApp(event: someEvent));
        await tester.pump();

        // Все поля уже заполнены из someEvent — сразу сохраняем
        await tester.ensureVisible(find.text('СОХРАНИТЬ ИЗМЕНЕНИЯ'));
        await tester.tap(find.text('СОХРАНИТЬ ИЗМЕНЕНИЯ'));
        await settle(tester);

        // PATCH-запрос с нужным id=42 должен быть выполнен
        final updateReq = mockAdapter.captured.firstWhere(
          (r) => r.method == 'PATCH' && r.path.contains('/events/admin/events/42/'),
        );
        expect(updateReq, isNotNull);

        verify(() => mockEventsProvider.load()).called(1);
      },
    );

    testWidgets(
      'test_save_disabled_while_saving — при _isSaving кнопка отсутствует, отображается PiligrimLoader',
      (tester) async {
        mockAdapter.enqueue(200, null); // PATCH /events/admin/events/42/

        await tester.pumpWidget(buildApp(event: someEvent));
        await tester.pump();

        // Нажимаем «СОХРАНИТЬ ИЗМЕНЕНИЯ»
        await tester.ensureVisible(find.text('СОХРАНИТЬ ИЗМЕНЕНИЯ'));
        await tester.tap(find.text('СОХРАНИТЬ ИЗМЕНЕНИЯ'));

        // Один кадр: _isSaving=true, кнопка заменяется лоадером
        await tester.pump();

        expect(find.text('СОХРАНИТЬ ИЗМЕНЕНИЯ'), findsNothing);
        expect(find.byType(PiligrimLoader), findsOneWidget);

        // Ждём завершения запроса
        await settle(tester);
      },
    );

    // ─── Delete ────────────────────────────────────────────────────────────────

    testWidgets(
      'test_delete_shows_confirmation_dialog — тап корзины → dialog',
      (tester) async {
        await tester.pumpWidget(buildApp(event: someEvent));
        await tester.pump();

        expect(find.byIcon(Icons.delete_outline_rounded), findsOneWidget);
        await tester.tap(find.byIcon(Icons.delete_outline_rounded));
        await tester.pumpAndSettle();

        expect(find.text('Удалить мероприятие?'), findsOneWidget);
        expect(
          find.text('Вы действительно хотите удалить "Вечер казахской музыки"?'),
          findsOneWidget,
        );
        expect(find.text('Отмена'), findsOneWidget);
        expect(find.text('Удалить'), findsOneWidget);
      },
    );

    testWidgets(
      'test_delete_confirmed_calls_deleteEvent — подтверждение → deleteEvent вызван с правильным id',
      (tester) async {
        mockAdapter.enqueue(204, null); // DELETE /events/admin/events/42/

        await tester.pumpWidget(buildApp(event: someEvent));
        await tester.pump();

        // Открываем диалог удаления
        await tester.tap(find.byIcon(Icons.delete_outline_rounded));
        await tester.pumpAndSettle();

        // Подтверждаем удаление
        await tester.tap(find.widgetWithText(TextButton, 'Удалить'));
        await settle(tester);

        // DELETE-запрос с id=42 должен быть выполнен
        final deleteReq = mockAdapter.captured.firstWhere(
          (r) => r.method == 'DELETE' && r.path.contains('/events/admin/events/42/'),
        );
        expect(deleteReq, isNotNull);

        verify(() => mockEventsProvider.load()).called(1);
      },
    );
  });
}
