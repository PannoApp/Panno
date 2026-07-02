import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:piligrim/core/theme.dart';
import 'package:piligrim/data/events_news_data.dart';
import 'package:piligrim/data/services/api_client.dart';
import 'package:piligrim/providers/events_provider.dart';
import 'package:piligrim/screens/news_edit_screen.dart';

import '../support/mock_dio_adapter.dart';

class _MockEventsProvider extends Mock implements EventsProvider {}

class _MockSecureStoragePlatform extends Mock
    with MockPlatformInterfaceMixin
    implements FlutterSecureStoragePlatform {}

void main() {
  final someNews = PiligrimNewsPost(
    id: '7',
    title: 'Открытие летней веранды',
    body: 'Приглашаем всех гостей на открытие нашей летней веранды.',
    publishedAt: DateTime(2025, 6, 1, 12, 0),
    imageUrl: null,
  );

  group('NewsEditScreen Widget Tests', () {
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
      when(() => mockEventsProvider.loadNews()).thenAnswer((_) async {});

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

    Widget buildApp({PiligrimNewsPost? news}) {
      return MultiProvider(
        providers: [
          ChangeNotifierProvider<EventsProvider>.value(value: mockEventsProvider),
        ],
        child: MaterialApp(
          theme: piligrimTheme,
          home: NewsEditScreen(news: news),
        ),
      );
    }

    Future<void> settle(WidgetTester tester) async {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
    }

    // ─── Rendering ─────────────────────────────────────────────────────────────

    testWidgets(
      'test_renders_in_create_mode — news=null → поля пустые, нет иконки удаления',
      (tester) async {
        await tester.pumpWidget(buildApp(news: null));
        await tester.pump();

        expect(find.text('Новая новость'), findsOneWidget);
        expect(find.text('Редактировать новость'), findsNothing);

        final titleField = tester.widget<TextFormField>(
          find.widgetWithText(TextFormField, 'Введите заголовок'),
        );
        expect(titleField.controller?.text, '');

        final contentField = tester.widget<TextFormField>(
          find.widgetWithText(TextFormField, 'Введите текст новости'),
        );
        expect(contentField.controller?.text, '');

        expect(find.byIcon(Icons.delete_outline_rounded), findsNothing);
        expect(find.text('ОПУБЛИКОВАТЬ'), findsOneWidget);
      },
    );

    testWidgets(
      'test_renders_in_edit_mode — news=someNews → title и content заполнены, иконка удаления есть',
      (tester) async {
        await tester.pumpWidget(buildApp(news: someNews));
        await tester.pump();

        expect(find.text('Редактировать новость'), findsOneWidget);
        expect(find.text('Новая новость'), findsNothing);

        final titleField = tester.widget<TextFormField>(
          find.widgetWithText(TextFormField, 'Введите заголовок'),
        );
        expect(titleField.controller?.text, 'Открытие летней веранды');

        final contentField = tester.widget<TextFormField>(
          find.widgetWithText(TextFormField, 'Введите текст новости'),
        );
        expect(contentField.controller?.text, 'Приглашаем всех гостей на открытие нашей летней веранды.');

        expect(find.byIcon(Icons.delete_outline_rounded), findsOneWidget);
        expect(find.text('СОХРАНИТЬ ИЗМЕНЕНИЯ'), findsOneWidget);
      },
    );

    // ─── Validation ────────────────────────────────────────────────────────────

    testWidgets(
      'test_validation_title_required — submit без title → ошибка валидации',
      (tester) async {
        await tester.pumpWidget(buildApp(news: null));
        await tester.pump();

        // Вводим только текст, заголовок оставляем пустым
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Введите текст новости'),
          'Какой-то текст',
        );

        await tester.ensureVisible(find.text('ОПУБЛИКОВАТЬ'));
        await tester.tap(find.text('ОПУБЛИКОВАТЬ'));
        await tester.pump();

        expect(find.text('Укажите заголовок новости'), findsOneWidget);
      },
    );

    testWidgets(
      'test_validation_content_required — submit без content → ошибка валидации',
      (tester) async {
        await tester.pumpWidget(buildApp(news: null));
        await tester.pump();

        // Вводим только заголовок, текст оставляем пустым
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Введите заголовок'),
          'Заголовок',
        );

        await tester.ensureVisible(find.text('ОПУБЛИКОВАТЬ'));
        await tester.tap(find.text('ОПУБЛИКОВАТЬ'));
        await tester.pump();

        expect(find.text('Укажите текст новости'), findsOneWidget);
      },
    );

    // ─── Save ──────────────────────────────────────────────────────────────────

    testWidgets(
      'test_save_calls_createNews_in_create_mode — mock repo → createNews вызван',
      (tester) async {
        mockAdapter.enqueue(201, null); // POST /events/admin/news/

        await tester.pumpWidget(buildApp(news: null));
        await tester.pump();

        await tester.enterText(
          find.widgetWithText(TextFormField, 'Введите заголовок'),
          'Тестовая новость',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Введите текст новости'),
          'Текст тестовой новости',
        );

        await tester.ensureVisible(find.text('ОПУБЛИКОВАТЬ'));
        await tester.tap(find.text('ОПУБЛИКОВАТЬ'));
        await settle(tester);

        // POST-запрос на создание новости должен быть выполнен
        final createReq = mockAdapter.captured.firstWhere(
          (r) => r.method == 'POST' && r.path.contains('/events/admin/news/'),
        );
        expect(createReq, isNotNull);

        verify(() => mockEventsProvider.loadNews()).called(1);
      },
    );

    testWidgets(
      'test_save_calls_updateNews_in_edit_mode — mock repo → updateNews(numericId, ...) вызван',
      (tester) async {
        mockAdapter.enqueue(200, null); // PATCH /events/admin/news/7/

        await tester.pumpWidget(buildApp(news: someNews));
        await tester.pump();

        // Все поля уже заполнены из someNews — сразу сохраняем
        await tester.ensureVisible(find.text('СОХРАНИТЬ ИЗМЕНЕНИЯ'));
        await tester.tap(find.text('СОХРАНИТЬ ИЗМЕНЕНИЯ'));
        await settle(tester);

        // PATCH-запрос с нужным id=7 должен быть выполнен
        final updateReq = mockAdapter.captured.firstWhere(
          (r) => r.method == 'PATCH' && r.path.contains('/events/admin/news/7/'),
        );
        expect(updateReq, isNotNull);

        verify(() => mockEventsProvider.loadNews()).called(1);
      },
    );

    // ─── Delete ────────────────────────────────────────────────────────────────

    testWidgets(
      'test_delete_confirmed_calls_deleteNews — confirm dialog → deleteNews вызван',
      (tester) async {
        mockAdapter.enqueue(204, null); // DELETE /events/admin/news/7/

        await tester.pumpWidget(buildApp(news: someNews));
        await tester.pump();

        // Открываем диалог удаления
        await tester.tap(find.byIcon(Icons.delete_outline_rounded));
        await tester.pumpAndSettle();

        expect(find.text('Удалить новость?'), findsOneWidget);
        expect(find.text('Отмена'), findsOneWidget);
        expect(find.text('Удалить'), findsOneWidget);

        // Подтверждаем удаление
        await tester.tap(find.widgetWithText(TextButton, 'Удалить'));
        await settle(tester);

        // DELETE-запрос с id=7 должен быть выполнен
        final deleteReq = mockAdapter.captured.firstWhere(
          (r) => r.method == 'DELETE' && r.path.contains('/events/admin/news/7/'),
        );
        expect(deleteReq, isNotNull);

        verify(() => mockEventsProvider.loadNews()).called(1);
      },
    );
  });
}
