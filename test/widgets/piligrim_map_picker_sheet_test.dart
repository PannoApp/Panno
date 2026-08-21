import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:piligrim/widgets/piligrim_map_picker_sheet.dart';

void main() {
  group('buildMapOptions', () {
    test('без адреса и без twogisLink — пустой список', () {
      final options = buildMapOptions(address: '');
      expect(options, isEmpty);
    });

    test('есть адрес, twogisLink не задан — 2ГИС отсутствует', () {
      final options = buildMapOptions(address: 'Астана, ул. Туран 24');
      expect(options.map((o) => o.label), isNot(contains('2ГИС')));
      expect(options.map((o) => o.label), contains('Google Карты'));
      expect(options.map((o) => o.label), contains('Яндекс Карты'));
    });

    test('twogisLink задан — 2ГИС первым в списке, ссылка используется как есть', () {
      final options = buildMapOptions(
        address: 'Астана, ул. Туран 24',
        twogisLink: 'https://2gis.kz/astana/firm/piligrim',
      );
      expect(options.first.label, '2ГИС');
      expect(options.first.url, 'https://2gis.kz/astana/firm/piligrim');
    });

    test('адрес кодируется в URL для Google/Яндекс', () {
      final options = buildMapOptions(address: 'Астана, ул. Туран 24');
      final google = options.firstWhere((o) => o.label == 'Google Карты');
      expect(google.url, contains(Uri.encodeComponent('Астана, ул. Туран 24')));
    });

    test('координаты заданы — Google/Яндекс используют lat/lng, не текст адреса', () {
      final options = buildMapOptions(
        address: 'Астана, ул. Туран 24',
        latitude: 51.128207,
        longitude: 71.430411,
      );

      final google = options.firstWhere((o) => o.label == 'Google Карты');
      expect(google.url, 'https://www.google.com/maps/search/?api=1&query=51.128207,71.430411');
      expect(google.url, isNot(contains(Uri.encodeComponent('Туран'))));

      // Яндекс.Карты: порядок в pt — «долгота,широта».
      final yandex = options.firstWhere((o) => o.label == 'Яндекс Карты');
      expect(yandex.url, 'https://yandex.ru/maps/?pt=71.430411,51.128207&z=17&l=map');
    });

    test('координаты не заданы — фолбэк на текстовый поиск по адресу', () {
      final options = buildMapOptions(address: 'Астана, ул. Туран 24');
      final google = options.firstWhere((o) => o.label == 'Google Карты');
      expect(google.url, startsWith('https://www.google.com/maps/search/?api=1&query='));
      expect(google.url, isNot(contains(',71.')));
    });

    test('координаты без адреса — варианты всё равно строятся', () {
      final options = buildMapOptions(address: '', latitude: 51.1, longitude: 71.4);
      expect(options.map((o) => o.label), contains('Google Карты'));
      expect(options.map((o) => o.label), contains('Яндекс Карты'));
    });
  });

  group('showPiligrimMapPickerSheet', () {
    testWidgets('рендерит все переданные варианты, тап вызывает onLaunch с нужным url',
        (tester) async {
      String? launched;
      final options = [
        const MapOption(label: '2ГИС', url: 'https://2gis.kz/x'),
        const MapOption(label: 'Google Карты', url: 'https://maps.google.com/x'),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showPiligrimMapPickerSheet(
                context,
                options: options,
                onLaunch: (url) async => launched = url,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('2ГИС'), findsOneWidget);
      expect(find.text('Google Карты'), findsOneWidget);

      await tester.tap(find.text('Google Карты'));
      await tester.pumpAndSettle();

      expect(launched, 'https://maps.google.com/x');
      // Шторка закрывается после выбора.
      expect(find.text('Открыть в приложении'), findsNothing);
    });
  });
}
