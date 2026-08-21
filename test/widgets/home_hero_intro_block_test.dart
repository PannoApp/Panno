import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:piligrim/data/models/core_info.dart';
import 'package:piligrim/providers/core_info_provider.dart';
import 'package:piligrim/widgets/home_hero_intro_block.dart';

CoreInfo _coreInfo({String? conceptDescription, String? conceptDescriptionKz}) =>
    CoreInfo(
      address: 'Астана',
      workingHours: '12:00–23:00',
      isOpenNow: true,
      phone: '+77001234567',
      socialLinks: const [],
      heroSlides: const [],
      visitRules: const [],
      privacyPolicy: 'https://api.piligrim.kz/privacy',
      conceptDescription: conceptDescription,
      conceptDescriptionKz: conceptDescriptionKz,
    );

void main() {
  group('HomeHeroIntroBlock', () {
    Widget buildApp(CoreInfoProvider core) {
      return ChangeNotifierProvider<CoreInfoProvider>.value(
        value: core,
        child: const MaterialApp(
          home: Scaffold(body: HomeHeroIntroBlock()),
        ),
      );
    }

    // Каждый Text обёрнут в .animate().fadeIn(delay: ..., duration: ...) —
    // самая долгая цепочка (KZ-блок) заканчивается к ~1560мс. Не довести до
    // конца — тест падает с "A Timer is still pending" при разрушении дерева.
    Future<void> settle(WidgetTester tester) async {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1600));
    }

    testWidgets('Заголовок kHeroTitle виден всегда, независимо от бэкенда',
        (tester) async {
      await tester.pumpWidget(buildApp(CoreInfoProvider()));
      await settle(tester);

      expect(find.textContaining('Вкус жизни'), findsOneWidget);
      expect(find.textContaining('Путь героя'), findsOneWidget);
    });

    testWidgets('RU-фолбэк концепции виден, если coreInfo не загружен',
        (tester) async {
      await tester.pumpWidget(buildApp(CoreInfoProvider()));
      await settle(tester);

      expect(find.textContaining('У жизни есть вкус'), findsOneWidget);
    });

    testWidgets('RU-текст с бэкенда переопределяет фолбэк', (tester) async {
      final core = CoreInfoProvider()
        ..coreInfo = _coreInfo(conceptDescription: 'Кастомный текст концепции');

      await tester.pumpWidget(buildApp(core));
      await settle(tester);

      expect(find.text('Кастомный текст концепции'), findsOneWidget);
      expect(find.textContaining('У жизни есть вкус'), findsNothing);
    });

    testWidgets('KZ-блок не рендерится, если conceptDescriptionKz не задан',
        (tester) async {
      final core = CoreInfoProvider()..coreInfo = _coreInfo();

      await tester.pumpWidget(buildApp(core));
      await settle(tester);

      // Единственный текстовый блок концепции — RU-фолбэк, KZ-варианта нет.
      expect(find.textContaining('У жизни есть вкус'), findsOneWidget);
    });

    testWidgets('KZ-блок рендерится, когда conceptDescriptionKz задан',
        (tester) async {
      final core = CoreInfoProvider()
        ..coreInfo = _coreInfo(
          conceptDescription: 'RU текст',
          conceptDescriptionKz: 'KZ мәтін',
        );

      await tester.pumpWidget(buildApp(core));
      await settle(tester);

      expect(find.text('RU текст'), findsOneWidget);
      expect(find.text('KZ мәтін'), findsOneWidget);
    });
  });
}
