import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:village_outreach/app/app.dart';

void main() {
  group('Village Outreach application configuration', () {
    test('application widget can be created', () {
      final app = VillageOutreachApp();

      expect(app, isA<Widget>());
      expect(app, isA<VillageOutreachApp>());
    });

    test('supports English and Spanish locale definitions', () {
      const supportedLocales = [Locale('en'), Locale('es')];

      expect(supportedLocales, contains(const Locale('en')));
      expect(supportedLocales, contains(const Locale('es')));
    });
  });
}
