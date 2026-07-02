// Тесты admin overlay (кнопка карандаша) на _ClassicDishCard.
// _ClassicDishCard — приватный виджет menu_screen.dart, поэтому тестируем
// через полный MenuScreen в режиме classic с подменёнными провайдерами.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import 'package:piligrim/data/models/api_category.dart';
import 'package:piligrim/data/models/api_dish.dart';
import 'package:piligrim/providers/auth_provider.dart';
import 'package:piligrim/providers/menu_provider.dart';
import 'package:piligrim/screens/menu_screen.dart';

class _MockMenuProvider extends Mock implements MenuProvider {}

class _MockAuthProvider extends Mock implements AuthProvider {}

const _dish = ApiDish(
  id: 1,
  name: 'Бешбармак',
  description: 'Традиционное казахское блюдо',
  price: 3500,
  category: 1,
  tags: [],
  allergens: [],
  weight: '350г',
  story: '',
  isActive: true,
);

void main() {
  group('_ClassicDishCard admin overlay', () {
    late _MockMenuProvider menu;
    late _MockAuthProvider auth;

    setUp(() {
      menu = _MockMenuProvider();
      auth = _MockAuthProvider();

      // Classic mode with one visible dish, no loading/error state.
      when(() => menu.loaded).thenReturn(true);
      when(() => menu.mode).thenReturn(MenuViewMode.classic);
      when(() => menu.dishes).thenReturn(const [_dish]);
      when(() => menu.isLoading).thenReturn(false);
      when(() => menu.error).thenReturn(null);
      when(() => menu.hasMore).thenReturn(false);
      when(() => menu.isLoadingMore).thenReturn(false);
      when(() => menu.categories).thenReturn(
        const [ApiCategory(id: 1, name: 'Горячее', order: 0)],
      );
      when(() => menu.availableTags).thenReturn(const []);
      when(() => menu.activeTagIds).thenReturn(const []);
      when(() => menu.activeCategoryId).thenReturn(null);
      when(() => menu.searchQuery).thenReturn('');
    });

    Widget buildScreen() => MultiProvider(
          providers: [
            ChangeNotifierProvider<MenuProvider>.value(value: menu),
            ChangeNotifierProvider<AuthProvider>.value(value: auth),
          ],
          child: const MaterialApp(home: MenuScreen()),
        );

    testWidgets('admin edit button visible when isAdmin=true', (tester) async {
      when(() => auth.isAdmin).thenReturn(true);

      await tester.pumpWidget(buildScreen());
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
    });

    testWidgets('admin edit button absent for regular user', (tester) async {
      when(() => auth.isAdmin).thenReturn(false);

      await tester.pumpWidget(buildScreen());
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byIcon(Icons.edit_outlined), findsNothing);
    });
  });

  group('FAB «Добавить блюдо»', () {
    late _MockMenuProvider menu;
    late _MockAuthProvider auth;

    setUp(() {
      menu = _MockMenuProvider();
      auth = _MockAuthProvider();

      when(() => menu.loaded).thenReturn(true);
      when(() => menu.dishes).thenReturn(const [_dish]);
      when(() => menu.isLoading).thenReturn(false);
      when(() => menu.error).thenReturn(null);
      when(() => menu.hasMore).thenReturn(false);
      when(() => menu.isLoadingMore).thenReturn(false);
      when(() => menu.categories).thenReturn(
        const [ApiCategory(id: 1, name: 'Горячее', order: 0)],
      );
      when(() => menu.availableTags).thenReturn(const []);
      when(() => menu.activeTagIds).thenReturn(const []);
      when(() => menu.activeCategoryId).thenReturn(null);
      when(() => menu.searchQuery).thenReturn('');
    });

    Widget buildScreen() => MultiProvider(
          providers: [
            ChangeNotifierProvider<MenuProvider>.value(value: menu),
            ChangeNotifierProvider<AuthProvider>.value(value: auth),
          ],
          child: const MaterialApp(home: MenuScreen()),
        );

    testWidgets('test_fab_visible_for_admin_in_classic_mode', (tester) async {
      when(() => menu.mode).thenReturn(MenuViewMode.classic);
      when(() => auth.isAdmin).thenReturn(true);

      await tester.pumpWidget(buildScreen());
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(FloatingActionButton), findsOneWidget);
    });

    testWidgets('test_fab_hidden_for_regular_user', (tester) async {
      when(() => menu.mode).thenReturn(MenuViewMode.classic);
      when(() => auth.isAdmin).thenReturn(false);

      await tester.pumpWidget(buildScreen());
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(FloatingActionButton), findsNothing);
    });

    testWidgets('test_fab_hidden_in_video_mode', (tester) async {
      when(() => menu.mode).thenReturn(MenuViewMode.feed);
      when(() => auth.isAdmin).thenReturn(true);
      when(() => menu.feedDishes).thenReturn(const [_dish]);
      when(() => menu.isLoadingFeed).thenReturn(false);
      when(() => menu.feedError).thenReturn(null);
      when(() => menu.hasMoreFeed).thenReturn(false);
      when(() => menu.feedStartIndex).thenReturn(null);

      await tester.pumpWidget(buildScreen());
      // Assert before any animation timer fires.
      expect(find.byType(FloatingActionButton), findsNothing);
      // DishVideoCard has flutter_animate chain: delay 1800ms + fadeIn 600ms
      // + then-delay 2000ms + fadeOut 500ms = 4900ms total.
      // Pump past all timers so teardown doesn't fail on pending timers.
      await tester.pump(const Duration(milliseconds: 5000));
    });
  });
}
