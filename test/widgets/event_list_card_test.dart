// Тесты admin overlay (кнопка карандаша) на _EventListCard и _NewsCard.
// Виджеты приватные, тестируем через полный EventsScreen с реальными провайдерами.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import 'package:piligrim/data/events_news_data.dart';
import 'package:piligrim/data/models/api_event.dart';
import 'package:piligrim/providers/auth_provider.dart';
import 'package:piligrim/providers/core_info_provider.dart';
import 'package:piligrim/providers/events_provider.dart';
import 'package:piligrim/screens/event_edit_screen.dart';
import 'package:piligrim/screens/events_screen.dart';
import 'package:piligrim/screens/news_edit_screen.dart';

class _MockAuthProvider extends Mock implements AuthProvider {}

// Фиктивное мероприятие для тестов.
final _event = ApiEvent(
  id: 1,
  title: 'Тестовое мероприятие',
  description: 'Описание',
  startsAt: DateTime(2026, 6, 15, 19, 0),
  format: ApiEventFormat.open,
  isPast: false,
);

// Фиктивная новость для тестов.
final _news = PiligrimNewsPost(
  id: '1',
  title: 'Тестовая новость',
  body: 'Текст новости',
  publishedAt: DateTime.utc(2026, 5, 1),
);

Widget _buildScreen({
  required _MockAuthProvider auth,
  List<ApiEvent> upcoming = const [],
  List<ApiEvent> archived = const [],
  List<PiligrimNewsPost> news = const [],
  bool showNewsTab = false,
}) {
  final eventsProvider = EventsProvider();
  eventsProvider.upcoming = upcoming;
  eventsProvider.archived = archived;
  eventsProvider.news = news;

  final coreInfoProvider = CoreInfoProvider();

  return MultiProvider(
    providers: [
      ChangeNotifierProvider<EventsProvider>.value(value: eventsProvider),
      ChangeNotifierProvider<AuthProvider>.value(value: auth),
      ChangeNotifierProvider<CoreInfoProvider>.value(value: coreInfoProvider),
    ],
    child: const MaterialApp(home: EventsScreen()),
  );
}

void main() {
  group('_EventListCard admin overlay', () {
    late _MockAuthProvider auth;

    setUp(() {
      auth = _MockAuthProvider();
    });

    testWidgets('test_admin_button_visible_when_is_admin', (tester) async {
      when(() => auth.isAdmin).thenReturn(true);

      await tester.pumpWidget(
        _buildScreen(auth: auth, upcoming: [_event]),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
    });

    testWidgets('test_admin_button_absent_for_regular_user', (tester) async {
      when(() => auth.isAdmin).thenReturn(false);

      await tester.pumpWidget(
        _buildScreen(auth: auth, upcoming: [_event]),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byIcon(Icons.edit_outlined), findsNothing);
    });
  });

  group('FAB admin visibility', () {
    late _MockAuthProvider auth;

    setUp(() {
      auth = _MockAuthProvider();
    });

    testWidgets('test_fab_visible_for_admin', (tester) async {
      when(() => auth.isAdmin).thenReturn(true);

      await tester.pumpWidget(_buildScreen(auth: auth));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(FloatingActionButton), findsOneWidget);
    });

    testWidgets('test_fab_hidden_for_regular_user', (tester) async {
      when(() => auth.isAdmin).thenReturn(false);

      await tester.pumpWidget(_buildScreen(auth: auth));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(FloatingActionButton), findsNothing);
    });

    testWidgets('test_fab_opens_event_edit_in_events_view', (tester) async {
      when(() => auth.isAdmin).thenReturn(true);

      await tester.pumpWidget(_buildScreen(auth: auth));
      await tester.pump(const Duration(milliseconds: 100));

      // Default tab is _AfichaView.events — tap FAB
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      expect(find.byType(EventEditScreen), findsOneWidget);
    });

    testWidgets('test_fab_opens_news_edit_in_news_view', (tester) async {
      when(() => auth.isAdmin).thenReturn(true);

      await tester.pumpWidget(_buildScreen(auth: auth));
      await tester.pump(const Duration(milliseconds: 100));

      // Switch to «Новости» tab
      await tester.tap(find.text('Новости'));
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      expect(find.byType(NewsEditScreen), findsOneWidget);
    });
  });

  group('_NewsCard admin overlay', () {
    late _MockAuthProvider auth;

    setUp(() {
      auth = _MockAuthProvider();
    });

    testWidgets('test_news_card_admin_button_visible', (tester) async {
      when(() => auth.isAdmin).thenReturn(true);

      await tester.pumpWidget(
        _buildScreen(auth: auth, news: [_news], showNewsTab: true),
      );
      // Переключаемся на вкладку «Новости»
      await tester.tap(find.text('Новости'));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
    });
  });
}
