import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:village_outreach/app/app.dart';

void main() {
  testWidgets('Village Outreach application loads', (tester) async {
    await tester.pumpWidget(const VillageOutreachApp());

    expect(find.text('Village Outreach'), findsOneWidget);
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}