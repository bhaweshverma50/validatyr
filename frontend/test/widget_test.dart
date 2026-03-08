import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/home/home_screen.dart';

void main() {
  testWidgets('home input dismisses focus on outside tap', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: HomeScreen())),
    );

    final textField = tester.widget<TextField>(find.byType(TextField));
    expect(textField.onTapOutside, isNotNull);
  });
}
