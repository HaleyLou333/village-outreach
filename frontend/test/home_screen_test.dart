import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:village_outreach/core/theme/app_theme.dart';
import 'package:village_outreach/features/home/home_screen.dart';

void main() {
  testWidgets('Home screen shows static nearby requests', (tester) async {
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.lightTheme, home: const HomeScreen()),
    );

    expect(find.text('Nearby Requests'), findsOneWidget);
    expect(find.text('Grocery Pickup'), findsOneWidget);
    expect(find.text('Ride to Appointment'), findsOneWidget);
    expect(find.text('Request Help'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Help With Yard Work'),
      150,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('Help With Yard Work'), findsOneWidget);
  });
}
