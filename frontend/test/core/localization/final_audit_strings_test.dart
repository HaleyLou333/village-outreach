import 'package:flutter_test/flutter_test.dart';
import 'package:village_outreach/core/localization/app_language.dart';

void main() {
  test('final audit labels provide English and Spanish text', () {
    final en = AppStrings('en');
    final es = AppStrings('es');
    expect(en.brandLogoFailed, 'Logo failed to load');
    expect(es.brandLogoFailed, 'No se pudo cargar el logotipo');
    expect(en.createRequestIntro, 'Tell your neighbors what help you need.');
    expect(
      es.createRequestIntro,
      'Cuéntales a tus vecinos qué ayuda necesitas.',
    );
    expect(en.dismiss, 'Dismiss');
    expect(es.dismiss, 'Cerrar');
    expect(en.copyDiagnostics, 'Copy Diagnostics');
    expect(es.copyDiagnostics, 'Copiar diagnóstico');
    expect(en.brandColors, 'Brand Colors');
    expect(es.brandColors, 'Colores de la marca');
  });
}
