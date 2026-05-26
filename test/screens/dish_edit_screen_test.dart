import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:piligrim/core/theme.dart';
import 'package:piligrim/data/models/api_category.dart';
import 'package:piligrim/data/models/api_dish.dart';
import 'package:piligrim/data/models/api_tag.dart';
import 'package:piligrim/data/services/api_client.dart';
import 'package:piligrim/providers/menu_provider.dart';
import 'package:piligrim/widgets/piligrim_loader.dart';
import 'package:piligrim/screens/dish_edit_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';

import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import '../support/mock_dio_adapter.dart';

class _MockMenuProvider extends Mock implements MenuProvider {}

class _MockSecureStoragePlatform extends Mock
    with MockPlatformInterfaceMixin
    implements FlutterSecureStoragePlatform {}

void main() {
  group('DishEditScreen Widget Tests', () {
    late HttpClientAdapter originalAdapter;
    late MockDioAdapter mockAdapter;
    late _MockMenuProvider mockMenuProvider;

    final categories = const [
      ApiCategory(id: 1, name: 'Горячее', order: 1),
      ApiCategory(id: 2, name: 'Закуски', order: 2),
    ];

    final someDish = ApiDish(
      id: 101,
      name: 'Плов',
      description: 'Вкусный плов',
      price: 3500,
      category: 1,
      tags: const [
        ApiTag(id: 1, name: 'Острое'),
      ],
      allergens: const ['глютен'],
      imageUrl: 'http://test.local/media/plov.jpg',
      weight: '350 г',
      story: 'История плова',
      isActive: true,
    );

    late _MockSecureStoragePlatform mockSecureStoragePlatform;

    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      mockAdapter = MockDioAdapter();
      originalAdapter = DioClient.instance.dio.httpClientAdapter;
      DioClient.instance.dio.httpClientAdapter = mockAdapter;
      mockMenuProvider = _MockMenuProvider();
      when(() => mockMenuProvider.load()).thenAnswer((_) async {});

      mockSecureStoragePlatform = _MockSecureStoragePlatform();
      FlutterSecureStoragePlatform.instance = mockSecureStoragePlatform;
      when(() => mockSecureStoragePlatform.read(key: any(named: 'key'), options: any(named: 'options')))
          .thenAnswer((_) async => null);
      when(() => mockSecureStoragePlatform.write(key: any(named: 'key'), value: any(named: 'value'), options: any(named: 'options')))
          .thenAnswer((_) async {});
      when(() => mockSecureStoragePlatform.delete(key: any(named: 'key'), options: any(named: 'options')))
          .thenAnswer((_) async {});

      const channel = MethodChannel('plugins.itrix.io/flutter_secure_storage');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        channel,
        (call) async {
          if (call.method == 'read') return null;
          if (call.method == 'write') return null;
          if (call.method == 'delete') return null;
          return null;
        },
      );
    });

    tearDown(() {
      DioClient.instance.dio.httpClientAdapter = originalAdapter;

      const channel = MethodChannel('plugins.itrix.io/flutter_secure_storage');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        channel,
        null,
      );
    });

    Widget buildApp({ApiDish? dish}) {
      return MultiProvider(
        providers: [
          ChangeNotifierProvider<MenuProvider>.value(value: mockMenuProvider),
        ],
        child: MaterialApp(
          theme: piligrimTheme,
          home: DishEditScreen(
            dish: dish,
            categories: categories,
          ),
        ),
      );
    }

    Future<void> settle(WidgetTester tester) async {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
    }

    testWidgets('test_screen_renders_in_create_mode — dish=null → поля пустые', (tester) async {
      // Подготовка моков для тегов и аллергенов в initState
      mockAdapter.enqueue(200, <Map<String, dynamic>>[]); // GET /menu/tags/
      mockAdapter.enqueue(200, <Map<String, dynamic>>[]); // GET /menu/allergens/

      await tester.pumpWidget(buildApp(dish: null));
      await settle(tester);

      // Проверяем заголовок экрана
      expect(find.text('Создать блюдо'), findsOneWidget);
      expect(find.text('Редактировать блюдо'), findsNothing);

      // Проверяем, что текстовые поля пустые (сравниваем через controller text)
      final nameField = tester.widget<TextFormField>(
        find.widgetWithText(TextFormField, 'Введите название'),
      );
      expect(nameField.controller?.text, '');

      final priceField = tester.widget<TextFormField>(
        find.widgetWithText(TextFormField, 'Введите цену (например, 4500)'),
      );
      expect(priceField.controller?.text, '');

      final weightField = tester.widget<TextFormField>(
        find.widgetWithText(TextFormField, 'Введите вес блюда'),
      );
      expect(weightField.controller?.text, '');

      final descField = tester.widget<TextFormField>(
        find.widgetWithText(TextFormField, 'Краткое описание ингредиентов и вкуса'),
      );
      expect(descField.controller?.text, '');

      final storyField = tester.widget<TextFormField>(
        find.widgetWithText(TextFormField, 'Исторический контекст или легенда создания блюда'),
      );
      expect(storyField.controller?.text, '');

      // Иконка корзины (delete) должна отсутствовать в режиме создания
      expect(find.byIcon(Icons.delete_outline_rounded), findsNothing);

      // Проверяем наличие плейсхолдера с иконкой камеры
      expect(find.byIcon(Icons.camera_alt_outlined), findsOneWidget);

      // Проверяем наличие кнопки «Выбрать фото»
      expect(find.text('ВЫБРАТЬ ФОТО'), findsOneWidget);
    });

    testWidgets('test_screen_renders_in_edit_mode — dish=someDish → поля заполнены данными блюда', (tester) async {
      // Подготовка моков для тегов и аллергенов в initState
      mockAdapter.enqueue(200, [
        {'id': 1, 'name': 'Острое'},
      ]); // GET /menu/tags/
      mockAdapter.enqueue(200, [
        {'id': 10, 'name': 'глютен'},
      ]); // GET /menu/allergens/

      await tester.pumpWidget(buildApp(dish: someDish));
      await settle(tester);

      // Проверяем заголовок экрана
      expect(find.text('Редактировать блюдо'), findsOneWidget);
      expect(find.text('Создать блюдо'), findsNothing);

      // Проверяем, что текстовые поля заполнены данными
      final nameField = tester.widget<TextFormField>(
        find.widgetWithText(TextFormField, 'Введите название'),
      );
      expect(nameField.controller?.text, 'Плов');

      final priceField = tester.widget<TextFormField>(
        find.widgetWithText(TextFormField, 'Введите цену (например, 4500)'),
      );
      expect(priceField.controller?.text, '3500');

      final weightField = tester.widget<TextFormField>(
        find.widgetWithText(TextFormField, 'Введите вес блюда'),
      );
      expect(weightField.controller?.text, '350 г');

      final descField = tester.widget<TextFormField>(
        find.widgetWithText(TextFormField, 'Краткое описание ингредиентов и вкуса'),
      );
      expect(descField.controller?.text, 'Вкусный плов');

      final storyField = tester.widget<TextFormField>(
        find.widgetWithText(TextFormField, 'Исторический контекст или легенда создания блюда'),
      );
      expect(storyField.controller?.text, 'История плова');

      // Иконка корзины (delete) должна быть видна в режиме редактирования
      expect(find.byIcon(Icons.delete_outline_rounded), findsOneWidget);

      // Проверяем наличие CachedNetworkImage с изображением блюда
      expect(find.byType(CachedNetworkImage), findsOneWidget);

      // Проверяем наличие кнопки «Выбрать фото»
      expect(find.text('ВЫБРАТЬ ФОТО'), findsOneWidget);
    });

    testWidgets('test_validation_name_required — submit без name → ошибка валидации', (tester) async {
      mockAdapter.enqueue(200, <Map<String, dynamic>>[]); // GET /menu/tags/
      mockAdapter.enqueue(200, <Map<String, dynamic>>[]); // GET /menu/allergens/

      await tester.pumpWidget(buildApp(dish: null));
      await settle(tester);

      // Убеждаемся, что названия нет, и жмем «ОПУБЛИКОВАТЬ»
      await tester.ensureVisible(find.text('ОПУБЛИКОВАТЬ'));
      await tester.tap(find.text('ОПУБЛИКОВАТЬ'));
      await settle(tester);

      // Должна отобразиться ошибка валидации названия
      expect(find.text('Укажите название блюда'), findsOneWidget);
    });

    testWidgets('test_validation_price_numeric — price="abc" → ошибка', (tester) async {
      mockAdapter.enqueue(200, <Map<String, dynamic>>[]); // GET /menu/tags/
      mockAdapter.enqueue(200, <Map<String, dynamic>>[]); // GET /menu/allergens/

      await tester.pumpWidget(buildApp(dish: null));
      await settle(tester);

      // Вводим корректное название
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Введите название'),
        'Лагман',
      );

      // Вводим некорректную цену
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Введите цену (например, 4500)'),
        'abc',
      );

      // Жмем «ОПУБЛИКОВАТЬ»
      await tester.ensureVisible(find.text('ОПУБЛИКОВАТЬ'));
      await tester.tap(find.text('ОПУБЛИКОВАТЬ'));
      await settle(tester);

      // Должна отобразиться ошибка валидации цены
      expect(find.text('Укажите корректное число больше 0'), findsOneWidget);
    });

    testWidgets('test_live_preview_updates_reactively — ввод названия и цены обновляет превью', (tester) async {
      mockAdapter.enqueue(200, <Map<String, dynamic>>[]); // GET /menu/tags/
      mockAdapter.enqueue(200, <Map<String, dynamic>>[]); // GET /menu/allergens/

      await tester.pumpWidget(buildApp(dish: null));
      await settle(tester);

      // Изначально имя пустое, цена пустая. Превью не должно падать
      expect(find.text(''), findsWidgets); // имя пустое
      expect(find.textContaining('₸'), findsOneWidget); // только лейбл "ЦЕНА (₸) *"

      // Вводим название
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Введите название'),
        'Плов по-самаркандски',
      );
      await settle(tester);

      // Проверяем, что название обновилось в превью
      expect(find.text('Плов по-самаркандски'), findsNWidgets(2));

      // Вводим цену
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Введите цену (например, 4500)'),
        '4500',
      );
      await settle(tester);

      // Проверяем, что цена обновилась в превью (форматированная "4 500 ₸")
      expect(find.text('4 500 ₸'), findsOneWidget);
      expect(find.textContaining('₸'), findsNWidgets(2)); // лейбл + цена в превью
    });

    testWidgets('test_save_calls_createDish_in_create_mode — mock repo, submit → createDish вызван', (tester) async {
      mockAdapter.enqueue(200, <Map<String, dynamic>>[]); // GET /menu/tags/
      mockAdapter.enqueue(200, <Map<String, dynamic>>[]); // GET /menu/allergens/
      mockAdapter.enqueue(201, someDish.toJson());        // POST /menu/admin/dishes/

      await tester.pumpWidget(buildApp(dish: null));
      await settle(tester);

      // Заполняем обязательные поля
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Введите название'),
        'Плов',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Введите цену (например, 4500)'),
        '3500',
      );
      await settle(tester);

      // Жмем «ОПУБЛИКОВАТЬ»
      await tester.ensureVisible(find.text('ОПУБЛИКОВАТЬ'));
      await tester.tap(find.text('ОПУБЛИКОВАТЬ'));
      await settle(tester);

      // Проверяем, что был выполнен POST запрос создания
      final createRequest = mockAdapter.captured.firstWhere(
        (req) => req.method == 'POST' && req.path.contains('/menu/admin/dishes/'),
      );
      expect(createRequest, isNotNull);
      
      // Проверяем, что сработал вызов load() в провайдере
      verify(() => mockMenuProvider.load()).called(1);
    });

    testWidgets('test_save_calls_updateDish_in_edit_mode — mock repo, submit → updateDish вызван с id', (tester) async {
      mockAdapter.enqueue(200, <Map<String, dynamic>>[]); // GET /menu/tags/
      mockAdapter.enqueue(200, <Map<String, dynamic>>[]); // GET /menu/allergens/
      mockAdapter.enqueue(200, someDish.toJson());        // PATCH /menu/admin/dishes/101/

      await tester.pumpWidget(buildApp(dish: someDish));
      await settle(tester);

      // Жмем «СОХРАНИТЬ ИЗМЕНЕНИЯ»
      await tester.ensureVisible(find.text('СОХРАНИТЬ ИЗМЕНЕНИЯ'));
      await tester.tap(find.text('СОХРАНИТЬ ИЗМЕНЕНИЯ'));
      await settle(tester);

      // Проверяем, что был выполнен PATCH запрос обновления
      final updateRequest = mockAdapter.captured.firstWhere(
        (req) => req.method == 'PATCH' && req.path.contains('/menu/admin/dishes/101/'),
      );
      expect(updateRequest, isNotNull);
      
      // Проверяем, что сработал вызов load() в провайдере
      verify(() => mockMenuProvider.load()).called(1);
    });

    testWidgets('test_save_disabled_while_saving — во время _isSaving кнопка неактивна', (tester) async {
      mockAdapter.enqueue(200, <Map<String, dynamic>>[]); // GET /menu/tags/
      mockAdapter.enqueue(200, <Map<String, dynamic>>[]); // GET /menu/allergens/
      mockAdapter.enqueue(200, someDish.toJson());        // PATCH /menu/admin/dishes/101/

      await tester.pumpWidget(buildApp(dish: someDish));
      await settle(tester);

      // Жмем кнопку сохранения
      await tester.ensureVisible(find.text('СОХРАНИТЬ ИЗМЕНЕНИЯ'));
      await tester.tap(find.text('СОХРАНИТЬ ИЗМЕНЕНИЯ'));
      
      // Делаем pump без ожидания settle
      await tester.pump();

      // Проверяем, что кнопка "СОХРАНИТЬ ИЗМЕНЕНИЯ" исчезла, и вместо нее появился PiligrimLoader
      expect(find.text('СОХРАНИТЬ ИЗМЕНЕНИЯ'), findsNothing);
      expect(find.byType(PiligrimLoader), findsOneWidget);

      // Даем асинхронным операциям завершиться
      await settle(tester);
    });

    testWidgets('test_delete_shows_confirmation_dialog — тап корзины → dialog', (tester) async {
      mockAdapter.enqueue(200, <Map<String, dynamic>>[]); // GET /menu/tags/
      mockAdapter.enqueue(200, <Map<String, dynamic>>[]); // GET /menu/allergens/

      await tester.pumpWidget(buildApp(dish: someDish));
      await settle(tester);

      // Находим иконку удаления в App Bar и тапаем ее
      expect(find.byIcon(Icons.delete_outline_rounded), findsOneWidget);
      await tester.tap(find.byIcon(Icons.delete_outline_rounded));
      await settle(tester);

      // Проверяем, что появился диалог подтверждения
      expect(find.text('Удалить блюдо?'), findsOneWidget);
      expect(find.text('Вы действительно хотите удалить блюдо "Плов"?'), findsOneWidget);
      expect(find.text('Отмена'), findsOneWidget);
      expect(find.text('Удалить'), findsOneWidget); // кнопка диалога
    });

    testWidgets('test_delete_confirmed_calls_deleteDish — подтверждение → deleteDish вызван', (tester) async {
      mockAdapter.enqueue(200, <Map<String, dynamic>>[]); // GET /menu/tags/
      mockAdapter.enqueue(200, <Map<String, dynamic>>[]); // GET /menu/allergens/
      mockAdapter.enqueue(204, null);                    // DELETE /menu/admin/dishes/101/

      await tester.pumpWidget(buildApp(dish: someDish));
      await settle(tester);

      // Тапаем иконку корзины
      await tester.tap(find.byIcon(Icons.delete_outline_rounded));
      await settle(tester);

      // Нажимаем «Удалить» в диалоге
      await tester.tap(find.widgetWithText(TextButton, 'Удалить'));
      await settle(tester);

      // Проверяем, что был выполнен DELETE запрос
      final deleteRequest = mockAdapter.captured.firstWhere(
        (req) => req.method == 'DELETE' && req.path.contains('/menu/admin/dishes/101/'),
      );
      expect(deleteRequest, isNotNull);

      // Проверяем, что сработал вызов load() в провайдере
      verify(() => mockMenuProvider.load()).called(1);
    });
  });
}
