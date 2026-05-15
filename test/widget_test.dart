import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:piligrim/core/theme.dart';

void main() {
  testWidgets('piligrimTheme loads', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: piligrimTheme,
        debugShowCheckedModeBanner: false,
        home: const Scaffold(
          body: SizedBox.shrink(),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
