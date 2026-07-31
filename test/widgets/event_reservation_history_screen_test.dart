import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import 'package:piligrim/core/theme.dart';
import 'package:piligrim/data/models/api_event.dart';
import 'package:piligrim/data/models/api_event_reservation.dart';
import 'package:piligrim/providers/events_provider.dart';
import 'package:piligrim/screens/event_reservation_history_screen.dart';
import 'package:piligrim/widgets/piligrim_loader.dart';

class _MockEventsProvider extends Mock implements EventsProvider {}

void main() {
  final someEvent = ApiEvent(
    id: 5,
    title: 'Вечер казахской музыки',
    description: 'Живое выступление домбристов',
    startsAt: DateTime(2025, 9, 15, 19, 0),
    format: ApiEventFormat.open,
    isPast: false,
  );

  final someReservation = ApiEventReservation(
    id: 1,
    eventId: 5,
    eventDetails: someEvent,
    guestsCount: 2,
    createdAt: DateTime(2025, 8, 1),
  );

  group('EventReservationHistoryScreen Widget Tests', () {
    late _MockEventsProvider mockEventsProvider;

    setUp(() {
      mockEventsProvider = _MockEventsProvider();
      when(() => mockEventsProvider.loadMyReservations()).thenAnswer((_) async {});
      when(() => mockEventsProvider.isLoadingMyReservations).thenReturn(false);
      when(() => mockEventsProvider.myReservationsError).thenReturn(null);
      when(() => mockEventsProvider.myReservations)
          .thenReturn(const <ApiEventReservation>[]);
    });

    Widget buildApp() {
      return MultiProvider(
        providers: [
          ChangeNotifierProvider<EventsProvider>.value(value: mockEventsProvider),
        ],
        child: MaterialApp(
          theme: piligrimTheme,
          home: const EventReservationHistoryScreen(),
        ),
      );
    }

    testWidgets(
      'test_initState_calls_loadMyReservations — экран запрашивает список при открытии',
      (tester) async {
        await tester.pumpWidget(buildApp());
        await tester.pumpAndSettle();

        verify(() => mockEventsProvider.loadMyReservations()).called(1);
      },
    );

    testWidgets(
      'test_shows_loader_while_loading — isLoadingMyReservations=true → PiligrimLoader виден',
      (tester) async {
        when(() => mockEventsProvider.isLoadingMyReservations).thenReturn(true);

        await tester.pumpWidget(buildApp());
        // PiligrimLoader крутится бесконечно — pumpAndSettle никогда не
        // «осядет». Продвигаем время вручную, чтобы flutter_animate
        // (fadeIn заголовка, 400ms) успел освободить свой внутренний таймер.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        expect(find.byType(PiligrimLoader), findsOneWidget);
        expect(find.text('Мероприятий пока нет'), findsNothing);
      },
    );

    testWidgets(
      'test_shows_error_and_retries — ошибка → текст + «Повторить» вызывает loadMyReservations повторно',
      (tester) async {
        when(() => mockEventsProvider.myReservationsError).thenReturn('Нет соединения');

        await tester.pumpWidget(buildApp());
        await tester.pumpAndSettle();

        expect(find.text('Не удалось загрузить данные'), findsOneWidget);

        await tester.tap(find.text('Повторить'));
        await tester.pumpAndSettle();

        // Один раз при initState, второй раз по кнопке «Повторить».
        verify(() => mockEventsProvider.loadMyReservations()).called(2);
      },
    );

    testWidgets(
      'test_shows_empty_state — пустой список → «Мероприятий пока нет»',
      (tester) async {
        await tester.pumpWidget(buildApp());
        await tester.pumpAndSettle();

        expect(find.text('Мероприятий пока нет'), findsOneWidget);
        expect(find.text('Здесь появятся ваши записи на события'), findsOneWidget);
      },
    );

    testWidgets(
      'test_renders_reservation_card — запись отображает событие, дату, время, гостей и бейдж статуса',
      (tester) async {
        when(() => mockEventsProvider.myReservations)
            .thenReturn([someReservation]);

        await tester.pumpWidget(buildApp());
        await tester.pumpAndSettle();

        expect(find.text('Вечер казахской музыки'), findsOneWidget);
        expect(find.text('15 сен 2025  ·  19:00  ·  2 героя'), findsOneWidget);
        expect(find.text('ПРЕДСТОИТ'), findsOneWidget);
      },
    );

    testWidgets(
      'test_renders_past_event_badge — прошедшее событие → бейдж «ЗАВЕРШЕНО»',
      (tester) async {
        final pastReservation = ApiEventReservation(
          id: 2,
          eventId: 5,
          eventDetails: ApiEvent(
            id: 5,
            title: 'Прошедшее событие',
            description: '',
            startsAt: DateTime(2024, 1, 1, 18, 0),
            format: ApiEventFormat.open,
            isPast: true,
          ),
          guestsCount: 1,
          createdAt: DateTime(2024, 1, 1),
        );
        when(() => mockEventsProvider.myReservations)
            .thenReturn([pastReservation]);

        await tester.pumpWidget(buildApp());
        await tester.pumpAndSettle();

        expect(find.text('ЗАВЕРШЕНО'), findsOneWidget);
        expect(find.text('1 янв 2024  ·  18:00  ·  1 герой'), findsOneWidget);
      },
    );
  });
}
