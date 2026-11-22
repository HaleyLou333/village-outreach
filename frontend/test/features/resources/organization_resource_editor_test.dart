import 'package:flutter_test/flutter_test.dart';
import 'package:village_outreach/core/localization/app_language.dart';

void main() {
  test('organization management strings are translated', () {
    final en = AppStrings('en');
    final es = AppStrings('es');
    expect(en.orgManageResources, 'Manage organization resources');
    expect(es.orgManageResources, 'Administrar recursos de la organización');
    expect(en.orgFieldLabel('source_url'), 'Source URL');
    expect(es.orgFieldLabel('source_url'), 'URL de origen');
    expect(en.orgDisablePrompt('Clinic'), contains('Clinic'));
    expect(es.orgDisablePrompt('Clínica'), contains('Clínica'));
    expect(es.orgMaxCharacters(160), contains('160'));
    expect(es.orgCoordinateRange(90), contains('90'));
  });
}
