import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:piligrim/core/theme.dart';
import 'package:piligrim/data/models/api_event.dart';
import 'package:piligrim/providers/events_provider.dart';
import 'package:piligrim/widgets/event_signup_sheet.dart';
import 'package:provider/provider.dart';

class _MockEventsProvider extends Mock implements EventsProvider {}

void main() {
  group('Event signup sheet', () {
    late _MockEventsProvider events;

    setUp(() {
      events = _MockEventsProvider();
      when(() => events.reserveError).thenReturn(null);
    });

    Widget wrap(Widget child) {
      return MaterialApp(
        theme: ThemeData(
          scaffoldBackgroundColor: PiligrimColors.earth,
        ),
        home: ChangeNotifierProvider<EventsProvider>.value(
          value: events,
          child: Scaffold(body: child),
        ),
      );
    }

    testWidgets('submit calls reserveEvent with guest count', (tester) async {
      when(() => events.reserveEvent(42, 2)).thenAnswer((_) async {});

      await tester.pumpWidget(
        wrap(
          Builder(
            builder: (context) => TextButton(
              onPressed: () => showEventSignupSheet(
                context,
                event: ApiEvent(
                  id: 42,
                  title: 'Джаз',
                  description: 'Джазовый вечер',
                  startsAt: DateTime.now().add(const Duration(days: 1)),
                  format: ApiEventFormat.open,
                  isPast: false,
                  maxPlaces: 10,
                  occupiedPlaces: 0,
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );

      // PathCta (кнопка «ЗАПИСАТЬСЯ») крутит бесконечную idle-анимацию
      // (_idleCtrl..repeat(reverse: true)) — pumpAndSettle() никогда не
      // «осядет», поэтому продвигаем время вручную фиксированными шагами.
      await tester.tap(find.text('open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.byIcon(Icons.add_circle_outline));
      await tester.pump();

      await tester.tap(find.text('ЗАПИСАТЬСЯ'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      verify(() => events.reserveEvent(42, 2)).called(1);

      // PiligrimToast.show(...) на успехе ставит собственный Timer на 3с
      // автозакрытия + dismiss-анимацию (400+280ms) — дожидаемся, иначе
      // таймер остаётся висеть после разрушения дерева виджетов.
      await tester.pump(const Duration(seconds: 4));
    });
  });
}
