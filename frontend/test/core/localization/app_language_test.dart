import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:village_outreach/core/localization/app_language.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('defaults to English and persists Spanish selection', () async {
    final controller = AppLanguageController();

    await controller.load();

    expect(controller.locale.languageCode, 'en');

    await controller.select('es');

    expect(controller.locale.languageCode, 'es');

    final prefs = await SharedPreferences.getInstance();

    expect(prefs.getString(AppLanguageController.preferenceKey), 'es');

    controller.dispose();

    final restored = AppLanguageController();

    await restored.load();

    expect(restored.locale.languageCode, 'es');

    restored.dispose();
  });

  test('unsupported language is rejected', () async {
    final controller = AppLanguageController();

    await expectLater(controller.select('fr'), throwsArgumentError);

    controller.dispose();
  });

  testWidgets('scope switches translated labels', (tester) async {
    final controller = AppLanguageController();

    await tester.pumpWidget(
      AppLanguageScope(
        controller: controller,
        child: MaterialApp(
          home: Builder(
            builder: (context) =>
                Scaffold(body: Text(AppStrings.of(context).settings)),
          ),
        ),
      ),
    );

    expect(find.text('Account Settings'), findsOneWidget);

    await controller.select('es');
    await tester.pump();

    expect(find.text('Configuración de la cuenta'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());

    controller.dispose();
  });
}
