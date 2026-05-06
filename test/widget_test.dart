import 'package:flutter_test/flutter_test.dart';
import 'package:panno_app/app.dart';

void main() {
  testWidgets('App starts with Piligrim home screen', (WidgetTester tester) async {
    await tester.pumpWidget(const PannoApp());
    expect(find.text('PILIGRIM'), findsWidgets);
  });
}
