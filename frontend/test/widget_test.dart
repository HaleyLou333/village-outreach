import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:village_outreach/app/app.dart';

void main() {
  testWidgets('Village Outreach configures its application correctly', (
    tester,
  ) async {
    // Inspect the application widget's configuration without
    // mounting AuthGate (which requires Supabase initialization).
    final app = const VillageOutreachApp();

    await tester.pumpWidget(
      Builder(
        builder: (context) {
          final materialApp = app.build(context) as MaterialApp;

          expect(materialApp.title, 'Village Outreach');
          expect(materialApp.debugShowCheckedModeBanner, isFalse);
          expect(materialApp.theme, isNotNull);
          expect(materialApp.home, isA<AuthGate>());

          return const SizedBox.shrink();
        },
      ),
    );
  });
}
