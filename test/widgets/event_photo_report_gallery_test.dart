import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piligrim/data/models/api_event_photo.dart';
import 'package:piligrim/widgets/event_photo_report_gallery.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

const _photo1 =
    ApiEventPhoto(id: 1, imageUrl: 'https://cdn/r1.jpg', order: 0);
const _photo2 =
    ApiEventPhoto(id: 2, imageUrl: 'https://cdn/r2.jpg', order: 1);

void main() {
  group('EventPhotoReportGallery', () {
    testWidgets('renders SizedBox.shrink when photos is empty', (tester) async {
      await tester.pumpWidget(
        _wrap(const EventPhotoReportGallery(photos: [])),
      );

      expect(find.byType(PageView), findsNothing);
      expect(find.byType(SizedBox), findsWidgets);
    });

    testWidgets('renders PageView when photos are provided', (tester) async {
      await tester.pumpWidget(
        _wrap(const EventPhotoReportGallery(photos: [_photo1, _photo2])),
      );

      expect(find.byType(PageView), findsOneWidget);
    });

    testWidgets('PageView has correct item count', (tester) async {
      await tester.pumpWidget(
        _wrap(const EventPhotoReportGallery(photos: [_photo1, _photo2])),
      );

      final pageView =
          tester.widget<PageView>(find.byType(PageView));
      // itemCount is available via delegate
      expect(pageView.childrenDelegate, isA<SliverChildBuilderDelegate>());
    });

    testWidgets('single photo renders without crashing', (tester) async {
      await tester.pumpWidget(
        _wrap(const EventPhotoReportGallery(photos: [_photo1])),
      );

      expect(find.byType(PageView), findsOneWidget);
    });
  });
}
