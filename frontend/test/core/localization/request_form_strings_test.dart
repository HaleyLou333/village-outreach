import 'package:flutter_test/flutter_test.dart';
import 'package:village_outreach/core/localization/app_language.dart';

void main() {
  test('request form strings support English and Spanish', () {
    final en = AppStrings('en');
    final es = AppStrings('es');
    expect(en.submitRequest, 'Submit Request');
    expect(es.submitRequest, 'Enviar solicitud');
    expect(es.selectCategory, 'Selecciona una categoría.');
    expect(es.requiredField('Título'), 'Título es obligatorio.');
    expect(
      en.maxLengthField('Title', 120),
      'Title must be 120 characters or fewer.',
    );
    expect(es.requestCategory('FOOD_ASSISTANCE'), 'Asistencia alimentaria');
    expect(en.requestCategory('FOOD_ASSISTANCE'), 'Food Assistance');
    expect(es.requestCategory('UNKNOWN'), 'UNKNOWN');
  });
}
