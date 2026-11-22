import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// CCVO-82: Device-local language preference. Never transmits a preference to an API.
class AppLanguageController extends ChangeNotifier {
  AppLanguageController({SharedPreferences? preferences}) {
    _preferences = preferences;
  }
  static const preferenceKey = 'village_outreach_language';
  SharedPreferences? _preferences;
  Locale _locale = const Locale('en');
  Locale get locale => _locale;

  Future<void> load() async {
    try {
      _preferences ??= await SharedPreferences.getInstance();
      final stored = _preferences!.getString(preferenceKey);
      _set(stored == 'es' ? 'es' : 'en');
    } catch (_) {
      // Storage failures leave the app usable in English.
      _set('en');
    }
  }

  Future<void> select(String code) async {
    if (code != 'en' && code != 'es') throw ArgumentError.value(code, 'code');
    _set(code);
    try {
      _preferences ??= await SharedPreferences.getInstance();
      await _preferences!.setString(preferenceKey, code);
    } catch (_) {
      // The current selection remains usable even if persistence fails.
    }
  }

  void _set(String code) {
    if (_locale.languageCode == code) return;
    _locale = Locale(code);
    notifyListeners();
  }
}

class AppLanguageScope extends InheritedNotifier<AppLanguageController> {
  const AppLanguageScope({
    super.key,
    required AppLanguageController controller,
    required super.child,
  }) : super(notifier: controller);

  static AppLanguageController? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppLanguageScope>()?.notifier;
}

/// Small, explicit string catalog for the initial localized surfaces.
class AppStrings {
  AppStrings(this.languageCode);
  final String languageCode;
  bool get spanish => languageCode == 'es';

  // CCVO-82: Final audit UI copy. Preserve API keys and brand name.
  String get accountCreationDisplayName =>
      spanish ? 'Nombre para mostrar' : 'Display name';
  String get brandLogoLabel =>
      spanish ? 'Logotipo de Village Outreach' : 'Village Outreach logo';
  String get updateRequestIntro => spanish
      ? 'Actualiza los detalles de tu solicitud.'
      : 'Update your request details.';
  String get createRequestIntro => spanish
      ? 'Cuéntales a tus vecinos qué ayuda necesitas.'
      : 'Tell your neighbors what help you need.';
  String get dismiss => spanish ? 'Cerrar' : 'Dismiss';
  String get brandLogoFailed =>
      spanish ? 'No se pudo cargar el logotipo' : 'Logo failed to load';
  String get brandTagline =>
      spanish ? 'Vecinos ayudando a vecinos' : 'Neighbors Helping Neighbors';
  String get brandDescription => spanish
      ? 'Encuentra apoyo local, conecta con voluntarios y fortalece tu comunidad.'
      : 'Find local support, connect with volunteers, and help strengthen your community.';
  String get brandCommunitySupport =>
      spanish ? 'Apoyo comunitario' : 'Community Support';
  String get brandCommunityDescription => spanish
      ? 'Explora recursos cercanos y oportunidades para ayudar a tus vecinos.'
      : 'Explore nearby resources and opportunities to help your neighbors.';
  String get brandRequestSupport =>
      spanish ? 'Solicitar apoyo' : 'Request Support';
  String get brandColors => spanish ? 'Colores de la marca' : 'Brand Colors';
  String get brandClosingTagline => spanish
      ? 'Vecinos más unidos. Un futuro más brillante.'
      : 'Stronger Neighbors. Brighter Tomorrows.';
  String get copyDiagnostics =>
      spanish ? 'Copiar diagnóstico' : 'Copy Diagnostics';
  // CCVO-82: Public resource discovery and details.
  String get publicResourcesTitle =>
      spanish ? 'Recursos comunitarios' : 'Community Resources';
  String get publicResourcesHeading =>
      spanish ? 'Encuentra apoyo local' : 'Find local support';
  String get publicResourcesIntro => spanish
      ? 'Explora recursos y servicios comunitarios verificados cerca de ti.'
      : 'Explore verified community resources and services near you.';
  String get publicAreaLabel =>
      spanish ? 'Ciudad o área de servicio' : 'City or service area';
  String get publicAreaHint => spanish ? 'Ingresa una ciudad' : 'Enter a city';
  String get publicSearchArea => spanish ? 'Buscar área' : 'Search area';
  String get publicAreaInvalid => spanish
      ? 'Ingresa una ciudad o área de servicio válida.'
      : 'Enter a valid city or service area.';
  String get publicFindingLocation =>
      spanish ? 'Buscando ubicación...' : 'Finding location...';
  String get publicUseLocation =>
      spanish ? 'Usar mi ubicación actual' : 'Use my current location';
  String publicShowingArea(String area) =>
      spanish ? 'Mostrando recursos en $area' : 'Showing resources in $area';
  String get publicShowingNearby => spanish
      ? 'Mostrando recursos en un radio de 10 km'
      : 'Showing resources within 10 km';
  String get publicMap => spanish ? 'Mapa' : 'Map';
  String get publicList => spanish ? 'Lista' : 'List';
  String get publicMapFallback => spanish
      ? '¿No carga el mapa? Usa la vista de lista'
      : 'Map not loading? Use list view';
  String get publicMapError => spanish
      ? 'El mapa no está disponible. Puedes seguir usando la lista de recursos.'
      : 'The map is unavailable. You can continue using the resource list.';
  String get publicLoadError => spanish
      ? 'No se pudieron cargar los recursos. Inténtalo de nuevo.'
      : 'Resources could not be loaded. Please try again.';
  String get publicEmpty => spanish
      ? 'No se encontraron recursos en esta área. Prueba otra área o usa tu ubicación.'
      : 'No resources found in this area. Try another area or use your location.';
  String publicFound(int count) =>
      spanish ? '$count recursos encontrados' : '$count resources found';
  String get publicLoadMore =>
      spanish ? 'Cargar más recursos' : 'Load more resources';
  String get publicOrganizationManagement =>
      spanish ? 'Administración de organizaciones' : 'Organization management';
  String get publicLastVerified =>
      spanish ? 'Última verificación' : 'Last verified';
  String publicVerifiedDate(String date) =>
      spanish ? 'Última verificación: $date' : 'Last verified: $date';
  String get publicViewDetails => spanish ? 'Ver detalles' : 'View details';
  String get publicDetailsTitle =>
      spanish ? 'Detalles del recurso' : 'Resource Details';
  String get publicDetailsError => spanish
      ? 'No se pudieron cargar los detalles del recurso. Inténtalo de nuevo.'
      : 'Resource details could not be loaded. Please try again.';
  String get publicLinkError =>
      spanish ? 'No se puede abrir este enlace.' : 'Unable to open this link.';
  String get publicInvalidWebsite => spanish
      ? 'La dirección del sitio web no es válida.'
      : 'Invalid website address.';
  String get publicAddress => spanish ? 'Dirección' : 'Address';
  String get publicServiceArea => spanish ? 'Área de servicio' : 'Service area';
  String get publicPhone => spanish ? 'Teléfono' : 'Phone';
  String get publicWebsite => spanish ? 'Sitio web' : 'Website';
  String get publicInformationSource =>
      spanish ? 'Fuente de información' : 'Information source';
  String get publicDisclaimer => spanish
      ? 'La información de los recursos puede cambiar. Comunícate directamente con la organización para confirmar la disponibilidad, los horarios y los requisitos.'
      : 'Resource information may change. Please contact the organization directly to confirm availability, hours, and eligibility.';

  // CCVO-82: Organization resource management.
  String get orgAccessError => spanish
      ? 'No se pudo verificar el acceso a la organización. Inténtalo de nuevo.'
      : 'Unable to verify organization access. Please retry.';
  String get orgDisableQuestion =>
      spanish ? '¿Desactivar el recurso?' : 'Disable resource?';
  String get orgCancel => spanish ? 'Cancelar' : 'Cancel';
  String get orgDisable => spanish ? 'Desactivar' : 'Disable';
  String get orgDisableError => spanish
      ? 'No se pudo desactivar el recurso. Inténtalo de nuevo.'
      : 'Could not disable resource. Please retry.';
  String get orgManageResources => spanish
      ? 'Administrar recursos de la organización'
      : 'Manage organization resources';
  String get orgRetry => spanish ? 'Reintentar' : 'Retry';
  String get orgNoMemberships => spanish
      ? 'No tienes membresías de organizaciones aprobadas.'
      : 'No approved organization memberships.';
  String get orgOrganization => spanish ? 'Organización' : 'Organization';
  String get orgAddResource => spanish ? 'Agregar recurso' : 'Add resource';
  String get orgActive => spanish ? 'Activo' : 'Active';
  String get orgDisabled => spanish ? 'Desactivado' : 'Disabled';
  String get orgEditResource => spanish ? 'Editar recurso' : 'Edit resource';
  String get orgDisableResource =>
      spanish ? 'Desactivar recurso' : 'Disable resource';
  String get orgRequired => spanish ? 'Campo obligatorio' : 'Required field';
  String get orgCategoryFormat => spanish
      ? 'Usa letras minúsculas, números y guiones bajos'
      : 'Use lowercase letters, digits, underscores';
  String get orgPhoneInvalid => spanish
      ? 'Ingresa un número de teléfono válido'
      : 'Enter a valid phone number';
  String get orgUrlInvalid =>
      spanish ? 'Ingresa una URL http(s) válida' : 'Enter a valid http(s) URL';
  String get orgSaveError => spanish
      ? 'No se pudo guardar. Revisa tus permisos y los campos e inténtalo de nuevo.'
      : 'Could not save. Check your permissions and fields, then retry.';
  String get orgSaving => spanish ? 'Guardando...' : 'Saving...';
  String get orgSaveResource => spanish ? 'Guardar recurso' : 'Save resource';
  String orgDisablePrompt(String name) => spanish
      ? '¿Ocultar $name de la lista pública de recursos?'
      : 'Hide $name from public resource browsing?';
  String orgMaxCharacters(int max) =>
      spanish ? 'Máximo $max caracteres' : 'Maximum $max characters';
  String orgCoordinateRange(int limit) => spanish
      ? 'Ingresa una coordenada entre -$limit y $limit'
      : 'Enter a coordinate between -$limit and $limit';
  String orgFieldLabel(String key) {
    switch (key) {
      case 'name':
        return spanish ? 'Nombre' : 'Name';
      case 'category':
        return spanish ? 'Categoría' : 'Category';
      case 'area':
        return spanish ? 'Zona' : 'Area';
      case 'address':
        return spanish ? 'Dirección' : 'Address';
      case 'latitude':
        return spanish ? 'Latitud' : 'Latitude';
      case 'longitude':
        return spanish ? 'Longitud' : 'Longitude';
      case 'phone':
        return spanish ? 'Teléfono' : 'Phone';
      case 'website':
        return spanish ? 'Sitio web' : 'Website';
      case 'source_url':
        return spanish ? 'URL de origen' : 'Source URL';
      default:
        return key.replaceAll('_', ' ');
    }
  }

  String get settings =>
      spanish ? 'Configuración de la cuenta' : 'Account Settings';
  String get language => spanish ? 'Idioma' : 'Language';
  String get languageHint =>
      spanish ? 'Elige el idioma de la aplicación' : 'Choose the app language';
  String get english => 'English';
  String get spanishLabel => 'Español';
  String get home => spanish ? 'Inicio' : 'Home';
  String get resources => spanish ? 'Recursos' : 'Resources';
  String get help => spanish ? 'Ayuda' : 'Help';
  String get profile => spanish ? 'Perfil' : 'Profile';
  String get notifications => spanish ? 'Notificaciones' : 'Notifications';
  String get signOut => spanish ? 'Cerrar sesión' : 'Sign Out';
  String get manageAccount =>
      spanish ? 'Administra tu cuenta' : 'Manage your account';
  String get accountDescription => spanish
      ? 'Consulta y actualiza tu perfil y la configuración de tu cuenta.'
      : 'View and update your Village Outreach profile and account settings.';
  String get displayName => spanish ? 'Nombre para mostrar' : 'Display Name';
  String get accountRole => spanish ? 'Rol de la cuenta' : 'Account Role';
  String get accountStatus =>
      spanish ? 'Estado de la cuenta' : 'Account Status';
  String get accountSession =>
      spanish ? 'Sesión de la cuenta' : 'Account Session';
  String get editProfile => spanish ? 'Editar perfil' : 'Edit Profile';
  String get saveChanges => spanish ? 'Guardar cambios' : 'Save Changes';
  String get cancel => spanish ? 'Cancelar' : 'Cancel';
  String get refreshProfile =>
      spanish ? 'Actualizar perfil' : 'Refresh profile';
  // CCVO-82: Nearby-request discovery and home actions.
  String get neighborsHelpingNeighbors =>
      spanish ? 'Vecinos ayudando a vecinos' : 'Neighbors helping neighbors';
  String get findLocalSupport => spanish
      ? 'Encuentra apoyo local o ayuda a alguien de tu comunidad.'
      : 'Find local support or lend a helping hand.';
  String get requestHelp => spanish ? 'Solicitar ayuda' : 'Request Help';
  String get offerHelp => spanish ? 'Ofrecer ayuda' : 'Offer Help';
  String get nearbyRequests =>
      spanish ? 'Solicitudes cercanas' : 'Nearby Requests';
  String get refreshNearbyRequests =>
      spanish ? 'Actualizar solicitudes cercanas' : 'Refresh nearby requests';
  String get liveCommunityRequests => spanish
      ? 'Solicitudes actuales de tu comunidad'
      : 'Live requests from your community';
  String get searchArea => spanish ? 'Buscar zona' : 'Search area';
  String get categoryFilter =>
      spanish ? 'Filtrar por categoría' : 'Category filter';
  String get allCategories =>
      spanish ? 'Todas las categorías' : 'All categories';
  String get urgencyFilter =>
      spanish ? 'Filtrar por urgencia' : 'Urgency filter';
  String get allUrgencyLevels =>
      spanish ? 'Todos los niveles de urgencia' : 'All urgency levels';
  String get standard => spanish ? 'Normal' : 'Standard';
  String get timeSensitive => spanish ? 'Urgente' : 'Time-sensitive';
  String get distanceFilter =>
      spanish ? 'Filtrar por distancia' : 'Distance filter';
  String withinKm(int distance) =>
      spanish ? 'A $distance km o menos' : 'Within $distance km';
  String get clearAll => spanish ? 'Borrar todo' : 'Clear All';
  String get clearAllFilters =>
      spanish ? 'Borrar todos los filtros' : 'Clear All Filters';
  String get retry => spanish ? 'Reintentar' : 'Retry';
  String get retryLoadingMore =>
      spanish ? 'Reintentar cargar más' : 'Retry loading more';
  String get loadMore => spanish ? 'Cargar más' : 'Load More';
  String get noFilteredRequests => spanish
      ? 'Ninguna solicitud coincide con tus filtros.\nCambia tus opciones o borra todos los filtros.'
      : 'No requests match your filters.\nTry changing your selections or clear all filters.';
  String get noNearbyRequests => spanish
      ? 'No se encontraron solicitudes activas cerca.\nPrueba otra zona o vuelve más tarde.'
      : 'No active requests found nearby.\nTry another area or check back later.';
  String get requestSubmitted => spanish
      ? 'Tu solicitud de ayuda se envió correctamente.'
      : 'Your help request was submitted successfully.';
  String signOutFailed(String reason) => spanish
      ? 'No se pudo cerrar sesión: $reason'
      : 'Unable to sign out: $reason';
  String get signOutUnexpected => spanish
      ? 'Ocurrió un error al cerrar sesión. Inténtalo de nuevo.'
      : 'Something went wrong while signing out. Please try again.';
  String get events => spanish ? 'Eventos' : 'Events';
  // CCVO-82: Authentication screens.
  String get welcomeBack => spanish ? 'Te damos la bienvenida' : 'Welcome Back';
  String get emailAddress => spanish ? 'Correo electrónico' : 'Email address';
  String get password => spanish ? 'Contraseña' : 'Password';
  String get showPassword => spanish ? 'Mostrar contraseña' : 'Show password';
  String get hidePassword => spanish ? 'Ocultar contraseña' : 'Hide password';
  String get invalidEmail => spanish
      ? 'Ingresa un correo electrónico válido'
      : 'Enter a valid email address';
  String get enterPassword =>
      spanish ? 'Ingresa tu contraseña' : 'Enter your password';
  String get signIn => spanish ? 'Iniciar sesión' : 'Sign In';
  String get createAnAccount =>
      spanish ? 'Crear una cuenta' : 'Create an account';
  String get forgotPassword =>
      spanish ? '¿Olvidaste tu contraseña?' : 'Forgot password?';
  String get resendConfirmation =>
      spanish ? 'Reenviar correo de confirmación' : 'Resend confirmation email';
  String get signInFailed => spanish
      ? 'No se pudo iniciar sesión. Inténtalo de nuevo.'
      : 'Unable to sign in. Please try again.';
  String get createAccount => spanish ? 'Crear cuenta' : 'Create Account';
  String get joinVillage =>
      spanish ? 'Únete a Village Outreach' : 'Join Village Outreach';
  String get enterName => spanish ? 'Ingresa tu nombre' : 'Enter your name';
  String get minEight =>
      spanish ? 'Usa al menos 8 caracteres' : 'Use at least 8 characters';
  String get creatingAccount =>
      spanish ? 'Creando cuenta...' : 'Creating account...';
  String get accountFailed => spanish
      ? 'No se pudo crear la cuenta. Inténtalo de nuevo.'
      : 'Account creation failed. Try again.';
  String get resetPassword =>
      spanish ? 'Restablecer contraseña' : 'Reset password';
  String get confirmEmail =>
      spanish ? 'Confirma tu correo electrónico' : 'Confirm your email';
  String get resetEmailInstruction => spanish
      ? 'Ingresa el correo de tu cuenta para solicitar un restablecimiento de contraseña.'
      : 'Enter your account email to request a password reset.';
  String get confirmationInstruction => spanish
      ? 'Ingresa el correo de tu cuenta para solicitar otro enlace de confirmación.'
      : 'Enter your account email to request another confirmation link.';
  String get checkInbox =>
      spanish ? 'Revisa tu bandeja de entrada' : 'Check your inbox';
  String get emailNotRequested =>
      spanish ? 'No se solicitó el correo' : 'Email not requested';
  String get sendingEmail =>
      spanish ? 'Enviando correo...' : 'Sending email...';
  String get sendAnother =>
      spanish ? 'Enviar otro correo' : 'Send another email';
  String get sendEmail => spanish ? 'Enviar correo' : 'Send email';
  String get backSignIn =>
      spanish ? 'Volver al inicio de sesión' : 'Back to sign in';
  String get backApp => spanish ? 'Volver a la aplicación' : 'Back to app';
  String get chooseNewPassword =>
      spanish ? 'Elige una contraseña nueva' : 'Choose a new password';
  String get passwordUpdated =>
      spanish ? 'Contraseña actualizada' : 'Password updated';
  String get passwordSavedMessage => spanish
      ? 'Tu nueva contraseña se guardó. Úsala la próxima vez que inicies sesión. Ya puedes continuar a Village Outreach.'
      : 'Your new password is saved. Use it the next time you sign in. You can continue to Village Outreach now.';
  String get continueVillage =>
      spanish ? 'Continuar a Village Outreach' : 'Continue to Village Outreach';
  String get resetVerified =>
      spanish ? 'Enlace de restablecimiento verificado' : 'Reset link verified';
  String get choosePasswordInstruction => spanish
      ? 'Elige una contraseña nueva para terminar de restablecer tu cuenta.'
      : 'Choose a new password to finish resetting your account.';
  String get passwordRule => spanish
      ? 'Usa al menos 8 caracteres y una contraseña diferente de la actual.'
      : 'Use at least 8 characters and a password different from your current one.';
  String get newPassword => spanish ? 'Contraseña nueva' : 'New password';
  String get confirmNewPassword =>
      spanish ? 'Confirmar contraseña nueva' : 'Confirm new password';
  String get passwordMismatch =>
      spanish ? 'Las contraseñas deben coincidir.' : 'Passwords must match.';
  String get passwordNotUpdated =>
      spanish ? 'No se actualizó la contraseña' : 'Password not updated';
  String get updatingPassword =>
      spanish ? 'Actualizando contraseña...' : 'Updating password...';
  String get updatePassword =>
      spanish ? 'Actualizar contraseña' : 'Update password';
  String get anotherResetEmail => spanish
      ? 'Solicitar otro correo de restablecimiento'
      : 'Request another reset email';
  String get invalidEmailPeriod => spanish
      ? 'Ingresa un correo electrónico válido.'
      : 'Enter a valid email address.';
  String get minEightPeriod =>
      spanish ? 'Usa al menos 8 caracteres.' : 'Use at least 8 characters.';
  String sendAgainIn(int seconds) =>
      spanish ? 'Volver a enviar en ${seconds}s' : 'Send again in ${seconds}s';
  String emailRequestAccepted(String email, {required bool resetPassword}) {
    if (spanish) {
      return 'Solicitud de correo aceptada para $email. Si esta cuenta cumple los requisitos, recibirás un enlace. Revisa también tu carpeta de spam.\n\nAbre el enlace más reciente en este dispositivo, donde lo solicitaste. ${resetPassword ? 'Después, elige una contraseña nueva.' : 'Después, vuelve aquí para iniciar sesión.'}';
    }
    return 'Email request accepted for $email. If this account is eligible, you will receive a link. Check your spam folder too.\n\nOpen the newest link on this device, where you requested it. ${resetPassword ? 'Then choose a new password.' : 'Then return here to sign in.'}';
  }

  // CCVO-82: Request form labels and feedback.
  String get editRequest => spanish ? 'Editar solicitud' : 'Edit Request';
  String get updateRequestDetails => spanish
      ? 'Actualiza los detalles de tu solicitud.'
      : 'Update your request details.';
  String get tellNeighbors => spanish
      ? 'Cuéntales a tus vecinos qué ayuda necesitas.'
      : 'Tell your neighbors what help you need.';
  String get requestTitle =>
      spanish ? 'Título de la solicitud' : 'Request title';
  String get requestTitleHint => spanish
      ? 'Necesito ayuda para recoger alimentos'
      : 'Need help picking up groceries';
  String get titleField => spanish ? 'Título' : 'Title';
  String get descriptionField => spanish ? 'Descripción' : 'Description';
  String get descriptionHint => spanish
      ? 'Describe la ayuda que necesitas...'
      : 'Describe the help you need...';
  String get categoryField => spanish ? 'Categoría' : 'Category';
  String get selectCategory =>
      spanish ? 'Selecciona una categoría.' : 'Select a category.';
  String get urgencyField => spanish ? 'Urgencia' : 'Urgency';
  String get standardUrgency => spanish ? 'Normal' : 'Standard';
  String get timeSensitiveUrgency => spanish ? 'Urgente' : 'Time-sensitive';
  String get areaField => spanish ? 'Zona' : 'Area';
  String get selectArea => spanish ? 'Selecciona una zona.' : 'Select an area.';
  String get areaExplanation => spanish
      ? 'La zona seleccionada permite mostrar tu solicitud a vecinos cercanos.'
      : 'Your selected area is used to display your request to nearby neighbors.';
  String get savingRequest => spanish ? 'Guardando...' : 'Saving...';
  String get submitRequest => spanish ? 'Enviar solicitud' : 'Submit Request';
  String get saveRequestError => spanish
      ? 'No se pudo guardar la solicitud. Inténtalo de nuevo.'
      : 'Unable to save the request. Please try again.';
  String get foodAssistance =>
      spanish ? 'Asistencia alimentaria' : 'Food Assistance';
  String get transportationCategory =>
      spanish ? 'Transporte' : 'Transportation';
  String get childcareCategory => spanish ? 'Cuidado infantil' : 'Childcare';
  String get donatedItemsCategory =>
      spanish ? 'Artículos donados' : 'Donated Items';
  String get deliveryHelpCategory =>
      spanish ? 'Ayuda con entregas' : 'Delivery Help';
  String get localServicesCategory =>
      spanish ? 'Servicios locales' : 'Local Services';
  String requiredField(String field) =>
      spanish ? '$field es obligatorio.' : '$field is required.';
  String maxLengthField(String field, int max) => spanish
      ? '$field debe tener $max caracteres o menos.'
      : '$field must be $max characters or fewer.';
  String unsupportedField(String field) => spanish
      ? '$field contiene caracteres no admitidos.'
      : '$field contains unsupported characters.';
  String requestCategory(String code) {
    switch (code) {
      case 'FOOD_ASSISTANCE':
        return foodAssistance;
      case 'TRANSPORTATION':
        return transportationCategory;
      case 'CHILDCARE':
        return childcareCategory;
      case 'DONATED_ITEMS':
        return donatedItemsCategory;
      case 'DELIVERY_HELP':
        return deliveryHelpCategory;
      case 'LOCAL_SERVICES':
        return localServicesCategory;
      default:
        return code;
    }
  }

  // CCVO-82: Request detail and owner status controls.
  String get requestDetails =>
      spanish ? 'Detalles de la solicitud' : 'Request Details';
  String get refreshRequest =>
      spanish ? 'Actualizar solicitud' : 'Refresh request';
  String get requestNotFound =>
      spanish ? 'No se encontró la solicitud.' : 'Request not found.';
  String get descriptionLabel => spanish ? 'Descripción' : 'Description';
  String get locationLabel => spanish ? 'Ubicación' : 'Location';
  String get statusLabel => spanish ? 'Estado' : 'Status';
  String get distanceUnavailable =>
      spanish ? 'Distancia no disponible' : 'Distance unavailable';
  String get requestClosed => spanish
      ? 'Esta solicitud está cerrada y ya no acepta ayuda.'
      : 'This request is closed and is no longer accepting help.';
  String get helperOffers => spanish ? 'Ofertas de ayuda' : 'Helper Offers';
  String get reviewOffers => spanish ? 'Revisar ofertas' : 'Review Offers';
  String get reviewOffersMessages =>
      spanish ? 'Revisar ofertas y mensajes' : 'Review Offers & Messages';
  String get viewOfferMessages =>
      spanish ? 'Ver oferta y mensajes' : 'View Offer & Messages';
  String get offerToHelp => spanish ? 'Ofrecer ayuda' : 'Offer to Help';
  String get communitySafety =>
      spanish ? 'Seguridad comunitaria' : 'Community Safety';
  String get reportSafetyHint => spanish
      ? 'Denuncia contenido o comportamientos inapropiados para mantener segura la comunidad.'
      : 'Report inappropriate content or behavior to help keep Village Outreach safe.';
  String get reportRequest =>
      spanish ? 'Denunciar solicitud' : 'Report Request';
  String get reportUser => spanish ? 'Denunciar usuario' : 'Report User';
  String get manageYourRequest =>
      spanish ? 'Administrar tu solicitud' : 'Manage Your Request';
  String get markCompleted =>
      spanish ? 'Marcar como completada' : 'Mark Completed';
  String get cancelRequest => spanish ? 'Cancelar solicitud' : 'Cancel Request';
  String get markCompletedTitle => spanish
      ? '¿Marcar la solicitud como completada?'
      : 'Mark Request Completed?';
  String get markCompletedMessage => spanish
      ? '¿Seguro que deseas marcar esta solicitud como completada? No podrás editarla después.'
      : 'Are you sure you want to mark this request as completed? You will not be able to edit it afterward.';
  String get cancelRequestTitle =>
      spanish ? '¿Cancelar solicitud?' : 'Cancel Request?';
  String get cancelRequestMessage => spanish
      ? '¿Seguro que deseas cancelar esta solicitud? Esta acción no se puede deshacer.'
      : 'Are you sure you want to cancel this request? This action cannot be undone.';
  String get goBack => spanish ? 'Volver' : 'Go Back';
  String get checkingOwnership => spanish
      ? 'Verificando la titularidad de la solicitud...'
      : 'Checking request ownership...';
  String get retryOwnership =>
      spanish ? 'Reintentar verificación' : 'Retry Ownership Check';
  String get closedOwnerNotice => spanish
      ? 'Ya no puedes editar ni cambiar el estado de esta solicitud.'
      : 'You can no longer edit or change the status of this request.';
  String get requestUpdated => spanish
      ? 'Solicitud actualizada correctamente.'
      : 'Request updated successfully.';
  String get requestCompleted => spanish
      ? 'Solicitud marcada como completada.'
      : 'Request marked as completed.';
  String get requestCanceled => spanish
      ? 'Solicitud cancelada correctamente.'
      : 'Request canceled successfully.';
  String get updateRequestFailed => spanish
      ? 'No se pudo actualizar la solicitud. Inténtalo de nuevo.'
      : 'Unable to update this request. Please try again.';
  String get diagnosticsCopied => spanish
      ? 'Diagnóstico de titularidad copiado.'
      : 'Ownership diagnostics copied.';
  String milesAway(String distance) =>
      spanish ? 'A $distance millas' : '$distance mi away';
  String ownershipFailure(String reason) => spanish
      ? 'No se pudo verificar la titularidad de la solicitud: $reason'
      : 'Unable to verify request ownership: $reason';
  // CCVO-82: Request photo selection, uploads, and private viewing.
  String get requestPhotos =>
      spanish ? 'Fotos de la solicitud' : 'Request Photos';
  String get photoOptionalHint => spanish
      ? 'Opcional. Tu solicitud seguirá disponible si falla la carga de una foto.'
      : 'Optional. Your request remains available if a photo fails.';
  String get choosePhoto => spanish ? 'Elegir foto' : 'Choose photo';
  String get photoPreviewUnavailable =>
      spanish ? 'Vista previa no disponible' : 'Preview unavailable';
  String get selectedPhoto => spanish ? 'Foto seleccionada' : 'Selected photo';
  String get uploadPhoto => spanish ? 'Subir foto' : 'Upload photo';
  String get retryPhotoUpload => spanish ? 'Reintentar carga' : 'Retry upload';
  String get photoUploaded => spanish ? 'Foto subida.' : 'Photo uploaded.';
  String get refreshPrivatePhotoLink => spanish
      ? 'Actualizar enlace privado de la foto'
      : 'Refresh private photo link';
  String get refreshExpiredPhotoLink => spanish
      ? 'Actualizar enlace vencido de la foto'
      : 'Refresh expired photo link';
  String get photoInvalidFormat => spanish
      ? 'Elige una imagen JPEG, PNG o WebP.'
      : 'Choose a JPEG, PNG, or WebP image.';
  String get photoInvalidSize => spanish
      ? 'Elige una imagen de menos de 5 MB.'
      : 'Choose an image smaller than 5 MB.';
  String get photoPermissionError => spanish
      ? 'No se puede acceder a las fotos. Revisa los permisos de archivos multimedia e inténtalo de nuevo.'
      : 'Unable to access photos. Check media permissions and try again.';
  String get photoUploadUnavailable => spanish
      ? 'La carga de fotos no está disponible hasta que se conecte la API de archivos adjuntos.'
      : 'Photo upload is not available until the request attachment API is connected.';
  String get photoViewingUnavailable => spanish
      ? 'La visualización privada de fotos aún no está disponible.'
      : 'Private photo viewing is not available yet.';
  String get photoOperationFailed => spanish
      ? 'No se pudo completar la operación con la foto. Inténtalo de nuevo.'
      : 'Unable to complete the photo operation. Please try again.';
  String photoErrorMessage(Object error) {
    final message = error.toString();
    if (message ==
        'Photo upload is not available until the request attachment API is connected.') {
      return photoUploadUnavailable;
    }
    if (message == 'Private photo viewing is not available yet.') {
      return photoViewingUnavailable;
    }
    return spanish ? photoOperationFailed : message;
  }

  // CCVO-82: Notification inbox display strings (API values remain unchanged).
  String get notificationsTitle => spanish ? 'Notificaciones' : 'Notifications';
  String get refreshNotifications =>
      spanish ? 'Actualizar notificaciones' : 'Refresh notifications';
  String get notificationsSignIn => spanish
      ? 'Inicia sesión para ver tus notificaciones.'
      : 'Sign in to view your notifications.';
  String get notificationsLoadFailed => spanish
      ? 'No se pudieron cargar las notificaciones. Inténtalo de nuevo.'
      : 'Unable to load notifications. Please try again.';
  String get notificationsMoreFailed => spanish
      ? 'No se pudieron cargar más notificaciones.'
      : 'Unable to load more notifications.';
  String get notificationsUnavailable => spanish
      ? 'Esta solicitud ya no está disponible o no tienes permiso para verla.'
      : 'This request is no longer available or you do not have permission to view it.';
  String get notificationsSessionExpired => spanish
      ? 'Es posible que tu sesión haya vencido. Inicia sesión de nuevo.'
      : 'Your session may have expired. Please sign in again.';
  String get notificationsOpenFailed => spanish
      ? 'No se pudo abrir esta notificación. Inténtalo de nuevo.'
      : 'Unable to open this notification. Please try again.';
  String get notificationsEmpty =>
      spanish ? 'Aún no hay notificaciones' : 'No notifications yet';
  String get notificationsEmptyHint => spanish
      ? 'Aquí aparecerán las novedades sobre tus solicitudes y conversaciones.'
      : 'Updates about your requests and conversations will appear here.';
  String get notificationsRetry => spanish ? 'Reintentar' : 'Retry';
  String get notificationsRetryMore =>
      spanish ? 'Reintentar cargar más' : 'Retry loading more';
  String get notificationsLoadMore => spanish ? 'Cargar más' : 'Load More';
  String get notificationOfferReceived =>
      spanish ? 'Nueva oferta recibida' : 'New Offer Received';
  String get notificationOfferAccepted =>
      spanish ? 'Tu oferta fue aceptada' : 'Your Offer Was Accepted';
  String get notificationMessageReceived =>
      spanish ? 'Nuevo mensaje' : 'New Message';
  String get notificationOfferReceivedDetail => spanish
      ? 'Alguien se ha ofrecido a ayudarte con tu solicitud.'
      : 'Someone has offered to help with your request.';
  String get notificationOfferAcceptedDetail => spanish
      ? 'Tu oferta fue aceptada. Consulta la solicitud para obtener detalles.'
      : 'Your offer was accepted. View the request for details.';
  String get notificationMessageReceivedDetail => spanish
      ? 'Tienes un mensaje nuevo sobre una solicitud.'
      : 'You have a new message about a request.';
  String get notificationJustNow => spanish ? 'Ahora mismo' : 'Just now';
  String notificationMinutesAgo(int count) =>
      spanish ? 'Hace $count min' : '${count}m ago';
  String notificationHoursAgo(int count) =>
      spanish ? 'Hace $count h' : '${count}h ago';
  String notificationDaysAgo(int count) =>
      spanish ? 'Hace $count d' : '${count}d ago';

  // CCVO-82: Private messaging interface strings.
  String get conversationTitle =>
      spanish ? 'Conversación privada' : 'Private Conversation';
  String get refreshMessages =>
      spanish ? 'Actualizar mensajes' : 'Refresh messages';
  String get messagesLoadFailed => spanish
      ? 'No se pudieron cargar los mensajes. Inténtalo de nuevo.'
      : 'Unable to load messages. Please try again.';
  String get messagesMoreFailed => spanish
      ? 'No se pudieron cargar más mensajes.'
      : 'Unable to load more messages.';
  String get messagesAccessDenied =>
      spanish ? 'Acceso denegado' : 'Access denied';
  String get messagesClosed => spanish
      ? 'Esta solicitud está cerrada. Los mensajes son de solo lectura.'
      : 'This request is closed. Messages are read-only.';
  String get messagesLoading => spanish ? 'Cargando...' : 'Loading...';
  String get messagesLoadMore =>
      spanish ? 'Cargar más mensajes' : 'Load more messages';
  String get messagesEmpty =>
      spanish ? 'Aún no hay mensajes.' : 'No messages yet.';
  String get messagesWrite =>
      spanish ? 'Escribe un mensaje' : 'Write a message';
  String get messagesSend => spanish ? 'Enviar mensaje' : 'Send message';
  String get messagesSending => spanish ? 'Enviando...' : 'Sending...';
  String get messagesFailed => spanish ? 'Fallido' : 'Failed';
  String get messagesSent => spanish ? 'Enviado' : 'Sent';
  String get messagesRetry => spanish ? 'Reintentar' : 'Retry';

  // CCVO-82: Offer submission and review UI.
  String get incomingOffers =>
      spanish ? 'Ofertas recibidas' : 'Incoming Offers';
  String get refreshOffers => spanish ? 'Actualizar ofertas' : 'Refresh offers';
  String get offerPending => spanish ? 'Pendiente' : 'Pending';
  String get offerAccepted => spanish ? 'Aceptada' : 'Accepted';
  String get offerDeclined => spanish ? 'Rechazada' : 'Declined';
  String get offerWithdrawn => spanish ? 'Retirada' : 'Withdrawn';
  String offerStatus(String status) =>
      spanish ? 'Estado: $status' : 'Status: $status';
  String get offersClosedNew => spanish
      ? 'Esta solicitud está cerrada. No se pueden enviar nuevas ofertas.'
      : 'This request is closed. New offers are unavailable.';
  String get yourOffer => spanish ? 'Tu oferta' : 'Your Offer';
  String get offersClosedHistory => spanish
      ? 'Esta solicitud está cerrada. El historial de conversación es de solo lectura.'
      : 'This request is closed. Conversation history is read-only.';
  String get yourOfferAccepted =>
      spanish ? '¡Tu oferta fue aceptada!' : 'Your offer was accepted!';
  String get openOfferConversation =>
      spanish ? 'Abrir conversación' : 'Open Conversation';
  String get offerHelpHint => spanish
      ? 'Cuéntale a la persona que hizo la solicitud cómo puedes ayudar.'
      : 'Let the requester know how you can help.';
  String get offerYourMessage => spanish ? 'Tu mensaje' : 'Your message';
  String get offerSubmitting => spanish ? 'Enviando...' : 'Submitting...';
  String get submitOffer => spanish ? 'Enviar oferta' : 'Submit Offer';
  String get noOffers => spanish
      ? 'Todavía no se han enviado ofertas para esta solicitud.'
      : 'No offers have been submitted for this request.';
  String get offersClosedExisting => spanish
      ? 'Esta solicitud está cerrada. Las conversaciones existentes son de solo lectura.'
      : 'This request is closed. Existing conversations are read-only.';
  String offerNumber(int number) =>
      spanish ? 'Oferta $number' : 'Offer $number';
  String get acceptOffer => spanish ? 'Aceptar oferta' : 'Accept Offer';

  // CCVO-82: Safety reporting and receipt localization.
  String get reportSubmitTitle =>
      spanish ? 'Enviar un reporte' : 'Submit a Report';
  String get reportSafetyHeading => spanish
      ? 'Ayuda a mantener segura nuestra comunidad'
      : 'Help keep our community safe';
  String get reportSafetyDescription => spanish
      ? 'Usa este formulario para reportar conductas inapropiadas, contenido inseguro u otras preocupaciones de seguridad comunitaria.'
      : 'Use this form to report inappropriate behavior, unsafe content, or other community safety concerns.';
  String get reportReasonHeading =>
      spanish ? 'Motivo del reporte' : 'Reason for reporting';
  String get reportReasonSelect =>
      spanish ? 'Selecciona un motivo' : 'Select a reason';
  String get reportDetailsLabel => spanish
      ? 'Detalles adicionales (opcional)'
      : 'Additional details (optional)';
  String get reportDetailsHint =>
      spanish ? 'Describe tu preocupación...' : 'Describe your concern...';
  String get reportImmediateHeading =>
      spanish ? '¿Peligro inmediato?' : 'Immediate danger?';
  String get reportEmergencyWarning => spanish
      ? 'Village Outreach no es un servicio de emergencias. Si tú u otra persona están en peligro inmediato, llama al 911.'
      : 'Village Outreach is not an emergency response service. If you or someone else is in immediate danger, call 911.';
  String get reportSubmitting => spanish ? 'Enviando...' : 'Submitting...';
  String get reportSubmitButton => spanish ? 'Enviar reporte' : 'Submit Report';
  String get reportReasonRequired => spanish
      ? 'Selecciona un motivo para el reporte.'
      : 'Please select a reason for reporting.';
  String get reportDetailsTooLong => spanish
      ? 'Los detalles adicionales no pueden superar los 1,000 caracteres.'
      : 'Additional details cannot exceed 1,000 characters.';
  String get reportSubmitFailed => spanish
      ? 'No se pudo enviar tu reporte. Inténtalo de nuevo.'
      : 'Unable to submit your report. Please try again.';
  String get reportSubmittedTitle =>
      spanish ? 'Reporte enviado' : 'Report Submitted';
  String get reportThankYou =>
      spanish ? 'Gracias por informarnos' : 'Thank you for speaking up';
  String get reportReceived => spanish
      ? 'Hemos recibido tu reporte. Gracias por ayudar a mantener segura nuestra comunidad.'
      : 'Your report has been received. Thank you for helping keep our community safe.';
  String get reportReceiptHeading =>
      spanish ? 'Comprobante de envío' : 'Submission receipt';
  String get reportReferenceId => spanish ? 'ID de referencia' : 'Reference ID';
  String get reportReferenceCopied =>
      spanish ? 'ID de referencia copiado.' : 'Reference ID copied.';
  String get reportCopyReference =>
      spanish ? 'Copiar referencia' : 'Copy reference';
  String get reportSubmissionStatus =>
      spanish ? 'Estado del envío' : 'Submission status';
  String get reportPendingReview =>
      spanish ? 'Pendiente de revisión' : 'Pending review';
  String get reportPrivacyNote => spanish
      ? 'Por privacidad y seguridad, los registros y las acciones de moderación no se muestran en la aplicación.'
      : 'For privacy and safety, moderation records and actions are not displayed in the application.';
  String get reportDone => spanish ? 'Listo' : 'Done';
  String get reportCancel => spanish ? 'Cancelar' : 'Cancel';
  String get reportTargetRequest => spanish ? 'Solicitud' : 'Request';
  String get reportTargetUser => spanish ? 'Usuario' : 'User';
  String get reportReasonSpam => spanish ? 'Spam' : 'Spam';
  String get reportReasonHarassment => spanish ? 'Acoso' : 'Harassment';
  String get reportReasonUnsafe =>
      spanish ? 'Contenido inseguro' : 'Unsafe content';
  String get reportReasonFraud => spanish ? 'Fraude' : 'Fraud';
  String get reportReasonOther => spanish ? 'Otro' : 'Other';
  String reportTargetLabel(String target) =>
      spanish ? 'Reportando $target' : 'Reporting $target';
  String reportReasonLabel(String reason) {
    switch (reason) {
      case 'spam':
        return reportReasonSpam;
      case 'harassment':
        return reportReasonHarassment;
      case 'unsafe_content':
        return reportReasonUnsafe;
      case 'fraud':
        return reportReasonFraud;
      default:
        return reportReasonOther;
    }
  }

  // CCVO-82: Profile actions, feedback, and session dialogs.
  String get profileNameInvalid => spanish
      ? 'El nombre para mostrar debe tener entre 1 y 100 caracteres.'
      : 'Display name must be between 1 and 100 characters.';
  String get profileSaveSuccess => spanish
      ? '¡Perfil actualizado correctamente!'
      : 'Profile updated successfully!';
  String get profileSignOutTitle => spanish ? '¿Cerrar sesión?' : 'Sign Out?';
  String get profileUnsavedSignOut => spanish
      ? 'Se perderán los cambios no guardados del perfil. ¿Seguro que quieres cerrar sesión?'
      : 'Unsaved profile changes will be lost. Are you sure you want to sign out?';
  String get profileConfirmSignOut => spanish
      ? '¿Seguro que quieres cerrar sesión en Village Outreach?'
      : 'Are you sure you want to sign out of Village Outreach?';
  String get profileSignOutFailed => spanish
      ? 'No se pudo cerrar sesión. Inténtalo de nuevo.'
      : 'Unable to sign out. Please try again.';
  String get profileLoadFailed =>
      spanish ? 'No se pudo cargar tu perfil.' : 'Unable to load your profile.';
  String get profileTryAgain => spanish ? 'Intentar de nuevo' : 'Try Again';
  String get profileEmail => spanish ? 'Correo electrónico' : 'Email';
  String get profileSaving => spanish ? 'Guardando...' : 'Saving...';
  String get profileSignOutHint => spanish
      ? 'Cierra la sesión de tu cuenta de Village Outreach en este dispositivo.'
      : 'Sign out of your Village Outreach account on this device.';
  String get profileSigningOut =>
      spanish ? 'Cerrando sesión...' : 'Signing Out...';

  String get homeIntro => spanish
      ? 'Conecta con tus vecinos para pedir ayuda, ofrecer apoyo y encontrar recursos en tu comunidad.'
      : 'Connect with neighbors to request help, offer support, and find resources in your community.';

  static AppStrings of(BuildContext context) => AppStrings(
    AppLanguageScope.maybeOf(context)?.locale.languageCode ?? 'en',
  );
}
