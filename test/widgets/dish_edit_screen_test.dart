import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart' show ImageSource, CameraDevice;
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:piligrim/core/theme.dart';
import 'package:piligrim/data/models/api_category.dart';
import 'package:piligrim/data/models/api_dish.dart';
import 'package:piligrim/data/services/api_client.dart';
import 'package:piligrim/providers/menu_provider.dart';
import 'package:piligrim/screens/dish_edit_screen.dart';

import '../support/mock_dio_adapter.dart';

class _MockMenuProvider extends Mock implements MenuProvider {}

// Мок платформенного интерфейса ImagePicker — не использует method channel
class _MockImagePickerPlatform extends Mock
    with MockPlatformInterfaceMixin
    implements ImagePickerPlatform {}

class _MockSecureStoragePlatform extends Mock
    with MockPlatformInterfaceMixin
    implements FlutterSecureStoragePlatform {}

const _category = ApiCategory(id: 1, name: 'Горячее', order: 0);

ApiDish _makeDish({
  String videoStatus = 'pending',
  String? videoUrl = 'https://example.com/video.mp4',
}) =>
    ApiDish(
      id: 1,
      name: 'Бешбармак',
      description: 'Традиционное блюдо',
      price: 3500,
      category: 1,
      tags: const [],
      allergens: const [],
      weight: '350г',
      story: '',
      isActive: true,
      videoUrl: videoUrl,
      videoStatus: videoStatus,
    );

// JSON минимального валидного блюда для ответа сервера на create
const _dishJson = {
  'id': 99,
  'name': 'Тест',
  'description': '',
  'price': 1000,
  'category': {'id': 1, 'name': 'Горячее', 'order': 0},
  'tags': [],
  'allergens': [],
  'weight': '',
  'story': '',
  'is_active': true,
};

void main() {
  setUpAll(() {
    // Mocktail требует fallback-значения для non-nullable типов в any()
    registerFallbackValue(ImageSource.gallery);
    registerFallbackValue(CameraDevice.rear);
  });

  group('DishEditScreen video tests', () {
    late HttpClientAdapter originalAdapter;
    late MockDioAdapter mockAdapter;
    late _MockMenuProvider mockMenuProvider;
    late _MockSecureStoragePlatform mockSecureStoragePlatform;
    late _MockImagePickerPlatform mockImagePickerPlatform;
    late ImagePickerPlatform originalImagePickerPlatform;

    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      mockAdapter = MockDioAdapter();
      originalAdapter = DioClient.instance.dio.httpClientAdapter;
      DioClient.instance.dio.httpClientAdapter = mockAdapter;

      mockMenuProvider = _MockMenuProvider();
      when(() => mockMenuProvider.load()).thenAnswer((_) async {});

      // Сохраняем и подменяем ImagePickerPlatform
      originalImagePickerPlatform = ImagePickerPlatform.instance;
      mockImagePickerPlatform = _MockImagePickerPlatform();
      ImagePickerPlatform.instance = mockImagePickerPlatform;

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
      ImagePickerPlatform.instance = originalImagePickerPlatform;

      const channel = MethodChannel('plugins.itrix.io/flutter_secure_storage');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
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
            categories: const [_category],
          ),
        ),
      );
    }

    // Ожидает завершения _loadMetadata (теги + аллергены)
    Future<void> pumpAfterMetadata(WidgetTester tester) async {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }

    // Скроллирует форму вниз и нажимает кнопку
    Future<void> scrollAndTap(WidgetTester tester, String text) async {
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -3000),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      await tester.tap(find.text(text));
    }

    // ─── Video status badge tests ──────────────────────────────────────────────

    testWidgets(
      'test_video_section_shows_ready_badge — dish.videoStatus=ready → badge «ГОТОВО»',
      (tester) async {
        mockAdapter.enqueue(200, []); // GET /menu/tags/
        mockAdapter.enqueue(200, []); // GET /menu/allergens/

        await tester.pumpWidget(buildApp(dish: _makeDish(videoStatus: 'ready')));
        await pumpAfterMetadata(tester);

        expect(find.text('ГОТОВО'), findsOneWidget);
      },
    );

    testWidgets(
      'test_video_section_shows_pending_badge — dish.videoStatus=pending → badge «ОЖИДАЕТ»',
      (tester) async {
        mockAdapter.enqueue(200, []); // GET /menu/tags/
        mockAdapter.enqueue(200, []); // GET /menu/allergens/

        await tester.pumpWidget(buildApp(dish: _makeDish(videoStatus: 'pending')));
        await pumpAfterMetadata(tester);

        expect(find.text('ОЖИДАЕТ'), findsOneWidget);
      },
    );

    testWidgets(
      'test_video_section_shows_failed_badge — dish.videoStatus=failed → badge «ОШИБКА», цвет PiligrimColors.fruit',
      (tester) async {
        mockAdapter.enqueue(200, []); // GET /menu/tags/
        mockAdapter.enqueue(200, []); // GET /menu/allergens/

        await tester.pumpWidget(buildApp(dish: _makeDish(videoStatus: 'failed')));
        await pumpAfterMetadata(tester);

        expect(find.text('ОШИБКА'), findsOneWidget);

        final badgeText = tester.widget<Text>(find.text('ОШИБКА'));
        expect(badgeText.style?.color, PiligrimColors.fruit);
      },
    );

    // ─── Local video file pick test ────────────────────────────────────────────

    testWidgets(
      'test_video_section_shows_local_file_after_pick — после _pickVideo() → имя файла отображается',
      (tester) async {
        // dpr=1 чтобы physicalSize == логический размер вьюпорта
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetDevicePixelRatio);
        tester.view.physicalSize = const Size(800, 2000);
        addTearDown(tester.view.resetPhysicalSize);

        mockAdapter.enqueue(200, []); // GET /menu/tags/
        mockAdapter.enqueue(200, []); // GET /menu/allergens/

        // Синхронная запись — не нарушает fake event loop Flutter tests
        final tempFile = File('/tmp/test_piligrim_video.mp4');
        tempFile.writeAsBytesSync([0, 1, 2]);

        // Мокируем ImagePickerPlatform напрямую — без method channel
        when(() => mockImagePickerPlatform.getVideo(
              source: any(named: 'source'),
              preferredCameraDevice: any(named: 'preferredCameraDevice'),
              maxDuration: any(named: 'maxDuration'),
            )).thenAnswer((_) async => XFile(tempFile.path));

        await tester.pumpWidget(buildApp(dish: null));
        await pumpAfterMetadata(tester);

        await tester.tap(find.text('ВЫБРАТЬ ВИДЕО'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        expect(find.text('test_piligrim_video.mp4'), findsOneWidget);

        tempFile.deleteSync();
      },
    );

    // ─── Save with video test ──────────────────────────────────────────────────

    testWidgets(
      'test_save_passes_video_to_createDish — submit с _localVideoFile != null → createDish вызван с video',
      (tester) async {
        // dpr=1 чтобы physicalSize == логический размер вьюпорта
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetDevicePixelRatio);
        tester.view.physicalSize = const Size(800, 3000);
        addTearDown(tester.view.resetPhysicalSize);

        mockAdapter.enqueue(200, []); // GET /menu/tags/
        mockAdapter.enqueue(200, []); // GET /menu/allergens/
        mockAdapter.enqueue(201, _dishJson); // POST /menu/admin/dishes/

        // Синхронная запись — не нарушает fake event loop Flutter tests
        final tempFile = File('/tmp/test_piligrim_video_save.mp4');
        tempFile.writeAsBytesSync([0, 1, 2]);

        when(() => mockImagePickerPlatform.getVideo(
              source: any(named: 'source'),
              preferredCameraDevice: any(named: 'preferredCameraDevice'),
              maxDuration: any(named: 'maxDuration'),
            )).thenAnswer((_) async => XFile(tempFile.path));

        await tester.pumpWidget(buildApp(dish: null));
        await pumpAfterMetadata(tester);

        // Выбираем видео
        await tester.tap(find.text('ВЫБРАТЬ ВИДЕО'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        // Заполняем обязательные поля
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Введите название'),
          'Тест',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Введите цену (например, 4500)'),
          '1000',
        );

        // Сохраняем (кнопка видна в расширенном вьюпорте 3000px)
        await tester.tap(find.text('ОПУБЛИКОВАТЬ'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        // Проверяем, что POST-запрос содержит поле video
        final createReq = mockAdapter.captured.firstWhere(
          (r) => r.method == 'POST' && r.path.contains('/menu/admin/dishes/'),
        );
        expect(createReq.data, isA<FormData>());
        final formData = createReq.data as FormData;
        expect(formData.files.any((f) => f.key == 'video'), isTrue);

        tempFile.deleteSync();
      },
    );
  });
}
