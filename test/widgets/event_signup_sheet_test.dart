import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:piligrim/core/theme.dart';
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
                eventId: 42,
                eventTitle: 'Джаз',
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.add_circle_outline));
      await tester.pump();

      await tester.tap(find.text('ЗАПИСАТЬСЯ'));
      await tester.pumpAndSettle();

      verify(() => events.reserveEvent(42, 2)).called(1);
    });
  });
}
