import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import 'package:piligrim/core/theme.dart';
import 'package:piligrim/data/models/api_event.dart';
import 'package:piligrim/data/models/api_event_photo.dart';
import 'package:piligrim/providers/events_provider.dart';
import 'package:piligrim/screens/event_photo_report_screen.dart';
import 'package:piligrim/widgets/piligrim_loader.dart';

class _MockEventsProvider extends Mock implements EventsProvider {}

void main() {
  final someEvent = ApiEvent(
    id: 7,
    title: 'Вечер казахской музыки',
    description: 'Живое выступление домбристов',
    startsAt: DateTime(2025, 9, 15, 19, 0),
    format: ApiEventFormat.open,
    isPast: true,
  );

  const photo1 = ApiEventPhoto(id: 1, imageUrl: 'https://example.com/a.jpg', order: 0);
  const photo2 = ApiEventPhoto(id: 2, imageUrl: 'https://example.com/b.jpg', order: 1);

  group('EventPhotoReportScreen Widget Tests', () {
    late _MockEventsProvider mockEventsProvider;

    setUp(() {
      mockEventsProvider = _MockEventsProvider();
      when(() => mockEventsProvider.loadPhotoReport(any())).thenAnswer((_) async {});
      when(() => mockEventsProvider.isUploadingPhoto).thenReturn(false);
      when(() => mockEventsProvider.isLoadingPhotoReport).thenReturn(false);
      when(() => mockEventsProvider.photoReportError).thenReturn(null);
      when(() => mockEventsProvider.photoReport).thenReturn(const <ApiEventPhoto>[]);
      when(() => mockEventsProvider.deletePhotoFromReport(any(), any()))
          .thenAnswer((_) async {});
    });

    Widget buildApp() {
      return MultiProvider(
        providers: [
          ChangeNotifierProvider<EventsProvider>.value(value: mockEventsProvider),
        ],
        child: MaterialApp(
          theme: piligrimTheme,
          home: EventPhotoReportScreen(event: someEvent),
        ),
      );
    }

    testWidgets(
      'test_initState_calls_loadPhotoReport — экран запрашивает фотоотчёт при открытии',
      (tester) async {
        await tester.pumpWidget(buildApp());
        await tester.pump();

        verify(() => mockEventsProvider.loadPhotoReport(7)).called(1);
      },
    );

    testWidgets(
      'test_shows_loader_while_loading — isLoadingPhotoReport=true → PiligrimLoader виден',
      (tester) async {
        when(() => mockEventsProvider.isLoadingPhotoReport).thenReturn(true);

        await tester.pumpWidget(buildApp());
        await tester.pump();

        expect(find.byType(PiligrimLoader), findsOneWidget);
        expect(find.text('Нет фотографий'), findsNothing);
      },
    );

    testWidgets(
      'test_shows_error_and_retries — ошибка → текст + «Повторить» вызывает loadPhotoReport повторно',
      (tester) async {
        when(() => mockEventsProvider.photoReportError).thenReturn('Нет соединения');

        await tester.pumpWidget(buildApp());
        await tester.pump();

        expect(find.text('Нет соединения'), findsOneWidget);

        await tester.tap(find.text('Повторить'));
        await tester.pump();

        // Один раз при initState, второй раз по кнопке «Повторить».
        verify(() => mockEventsProvider.loadPhotoReport(7)).called(2);
      },
    );

    testWidgets(
      'test_shows_empty_state — пустой список → «Нет фотографий»',
      (tester) async {
        await tester.pumpWidget(buildApp());
        await tester.pump();

        expect(find.text('Нет фотографий'), findsOneWidget);
        expect(find.text('Нажмите + чтобы добавить фото в отчёт'), findsOneWidget);
      },
    );

    testWidgets(
      'test_renders_photo_grid — непустой список → сетка с плитками фото',
      (tester) async {
        when(() => mockEventsProvider.photoReport)
            .thenReturn(const [photo1, photo2]);

        await tester.pumpWidget(buildApp());
        await tester.pump();

        expect(find.text('Нет фотографий'), findsNothing);
        // Каждая плитка фото рендерит свою кнопку удаления (X).
        expect(find.byIcon(Icons.close_rounded), findsNWidgets(2));
      },
    );

    testWidgets(
      'test_delete_photo_confirmed_calls_deletePhotoFromReport — подтверждение → deletePhotoFromReport вызван',
      (tester) async {
        when(() => mockEventsProvider.photoReport).thenReturn(const [photo1]);

        await tester.pumpWidget(buildApp());
        await tester.pump();

        await tester.tap(find.byIcon(Icons.close_rounded));
        await tester.pumpAndSettle();

        expect(find.text('Удалить фото?'), findsOneWidget);

        await tester.tap(find.widgetWithText(TextButton, 'Удалить'));
        await tester.pump();

        verify(() => mockEventsProvider.deletePhotoFromReport(7, 1)).called(1);
      },
    );

    testWidgets(
      'test_delete_photo_cancelled_does_not_call_repository — отмена → deletePhotoFromReport не вызван',
      (tester) async {
        when(() => mockEventsProvider.photoReport).thenReturn(const [photo1]);

        await tester.pumpWidget(buildApp());
        await tester.pump();

        await tester.tap(find.byIcon(Icons.close_rounded));
        await tester.pumpAndSettle();

        await tester.tap(find.widgetWithText(TextButton, 'Отмена'));
        await tester.pump();

        verifyNever(() => mockEventsProvider.deletePhotoFromReport(any(), any()));
      },
    );

    testWidgets(
      'test_shows_upload_loader_instead_of_add_button — isUploadingPhoto=true → кнопка добавления скрыта',
      (tester) async {
        when(() => mockEventsProvider.isUploadingPhoto).thenReturn(true);

        await tester.pumpWidget(buildApp());
        await tester.pump();

        expect(find.byIcon(Icons.add_photo_alternate_outlined), findsNothing);
        expect(find.byType(FloatingActionButton), findsNothing);
      },
    );
  });
}
