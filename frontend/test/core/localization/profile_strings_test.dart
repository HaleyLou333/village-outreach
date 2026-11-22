import 'package:flutter_test/flutter_test.dart';
import 'package:village_outreach/core/localization/app_language.dart';

void main() {
  test('profile feedback and dialogs are localized', () {
    final en = AppStrings('en');
    final es = AppStrings('es');
    expect(en.profileSaveSuccess, 'Profile updated successfully!');
    expect(es.profileSaveSuccess, '¡Perfil actualizado correctamente!');
    expect(en.profileSignOutTitle, 'Sign Out?');
    expect(es.profileSignOutTitle, '¿Cerrar sesión?');
    expect(en.profileLoadFailed, 'Unable to load your profile.');
    expect(es.profileLoadFailed, 'No se pudo cargar tu perfil.');
    expect(en.profileSigningOut, 'Signing Out...');
    expect(es.profileSigningOut, 'Cerrando sesión...');
  });
}
