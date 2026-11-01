import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:village_outreach/core/theme/app_theme.dart';
import 'package:village_outreach/features/home/home_screen.dart';

void main() {
  testWidgets('Home screen displays nearby requests', (tester) async {
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.lightTheme, home: const HomeScreen()),
    );

    expect(find.text('Nearby Requests'), findsOneWidget);
    expect(find.text('Grocery Pickup'), findsOneWidget);
    expect(find.text('Request Help'), findsOneWidget);
  });

  testWidgets('Home screen displays bottom navigation', (tester) async {
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.lightTheme, home: const HomeScreen()),
    );

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('Profile'), findsWidgets);
  });
}
