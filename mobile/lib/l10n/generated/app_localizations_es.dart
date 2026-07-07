// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appTitle => 'CloudyLog';

  @override
  String get homeTitle => 'Contador de Cloudings';

  @override
  String greeting(String name) {
    return '¡Hola, $name!';
  }

  @override
  String get todaysCloudingsLabel => 'Cloudings de hoy';

  @override
  String recommendedLabel(int count) {
    return 'Recomendado: $count';
  }

  @override
  String progressLabel(int current, int goal) {
    return '$current / $goal';
  }

  @override
  String progressPercentLabel(int percent) {
    return '$percent%';
  }

  @override
  String get goalReached => '¡Meta alcanzada!';

  @override
  String goalExceeded(int over) {
    return '$over sobre la meta';
  }

  @override
  String get incrementButton => '¡Clouding!';

  @override
  String get incrementTooltip => 'Añadir un Clouding';

  @override
  String get shareButton => 'Compartir';

  @override
  String get shareTooltip => 'Comparte tus resultados con amigos';

  @override
  String get shareSubject => 'Mis resultados de Clouding';

  @override
  String shareMessage(int count, int goal) {
    return 'Hice $count Cloudings hoy (meta: $goal). ¡Únete en CloudyLog!';
  }

  @override
  String get settingsTitle => 'Ajustes';

  @override
  String get settingsTooltip => 'Abrir ajustes';

  @override
  String get recommendedCountSetting => 'Cloudings diarios recomendados';

  @override
  String get recommendedCountHint => 'Introduce un número positivo';

  @override
  String get languageSetting => 'Idioma';

  @override
  String get displayNameSetting => 'Nombre mostrado';

  @override
  String get displayNameHint => 'Tu nombre visible';

  @override
  String get languageEnglish => 'Inglés';

  @override
  String get languageSpanish => 'Español';

  @override
  String get saveButton => 'Guardar';

  @override
  String get cancelButton => 'Cancelar';

  @override
  String get resetTodayButton => 'Reiniciar el contador de hoy';

  @override
  String get resetConfirmTitle => '¿Reiniciar los Cloudings de hoy?';

  @override
  String get resetConfirmMessage => 'Esto pondrá el contador de hoy en cero.';

  @override
  String get invalidNumberError => 'Introduce un número mayor que 0';

  @override
  String get loginTitle => 'Iniciar sesión';

  @override
  String get loginWelcome => 'Bienvenido a CloudyLog';

  @override
  String get loginSubtitle =>
      'Inicia sesión para sincronizar tus Cloudings con tu cuenta.';

  @override
  String get usernameLabel => 'Usuario o correo';

  @override
  String get passwordLabel => 'Contraseña';

  @override
  String get usernameRequired => 'El usuario es obligatorio';

  @override
  String get passwordRequired => 'La contraseña es obligatoria';

  @override
  String get signUpTitle => 'Crear cuenta';

  @override
  String get createAccountButton => 'Crear cuenta';

  @override
  String get haveAccountSignIn => '¿Ya tienes cuenta? Inicia sesión';

  @override
  String get noAccountSignUp => '¿Sin cuenta? Crea una';

  @override
  String get emailLabel => 'Correo electrónico';

  @override
  String get emailRequired => 'Introduce un correo válido';

  @override
  String get displayNameRequired => 'El nombre es obligatorio';

  @override
  String get errorInvalidCredentials => 'Correo o contraseña incorrectos.';

  @override
  String get errorEmailAlreadyRegistered => 'Este correo ya está registrado.';

  @override
  String get errorNetwork =>
      'No se pudo conectar con el servidor. Revisa tu conexión.';

  @override
  String get googleSignInUnavailable =>
      'El inicio de sesión con Google aún no está disponible.';

  @override
  String get proTitle => 'Cuenta y Pro';

  @override
  String get proTooltip => 'Cuenta y Pro';

  @override
  String get upgradeButton => 'Mejorar a Pro';

  @override
  String get accountHeader => 'Cuenta';

  @override
  String signedInAs(String email) {
    return 'Sesión iniciada como $email';
  }

  @override
  String get notSignedIn => 'Sin sesión iniciada';

  @override
  String get freeTierNote =>
      'La versión gratuita guarda todo en este dispositivo.';

  @override
  String get proBenefitsTitle => 'Hazte Pro';

  @override
  String get proBenefitStorage => 'Guarda tu historial en la nube';

  @override
  String get proBenefitCompare =>
      'Compara tus estadísticas con tu país y el mundo';

  @override
  String get proBenefitFriends => 'Añade amigos y comparte tus resultados';

  @override
  String get proPriceNote =>
      'Versión de desarrollo: la compra es simulada — sin cargo real.';

  @override
  String get subscribeButton => 'Activar Pro';

  @override
  String get signInRequiredForPro =>
      'Pro necesita una cuenta para sincronizar tus datos.';

  @override
  String get purchaseSuccess =>
      '¡Ya eres Pro! Tu historial se está sincronizando con la nube.';

  @override
  String get purchaseFailed => 'La compra falló. Inténtalo de nuevo.';

  @override
  String get manageSubscriptionTitle => 'Tu suscripción';

  @override
  String get subscriptionStatusActive => 'Pro — activa';

  @override
  String get subscriptionStatusCanceled =>
      'Pro — cancelada (activa hasta el vencimiento)';

  @override
  String expiresOn(String date) {
    return 'Válida hasta $date';
  }

  @override
  String get cancelSubscriptionButton => 'Cancelar suscripción';

  @override
  String get cancelSubscriptionConfirmTitle => '¿Cancelar Pro?';

  @override
  String get cancelSubscriptionConfirmMessage =>
      'Pro seguirá activa hasta la fecha de vencimiento y luego la app volverá a la versión gratuita. Tus datos permanecen en este dispositivo.';

  @override
  String get subscriptionCanceledMessage =>
      'Suscripción cancelada. Pro sigue activa hasta el vencimiento.';

  @override
  String get syncNowButton => 'Sincronizar ahora';

  @override
  String get proRequiredMessage =>
      'Esta función requiere una suscripción Pro activa.';

  @override
  String get statsTitle => 'Comparar';

  @override
  String get statsTooltip => 'Compárate con otros';

  @override
  String get statsWorldwide => 'Mundial';

  @override
  String statsCountry(String country) {
    return 'Tu país ($country)';
  }

  @override
  String get statsCountryUnknown => 'Tu país';

  @override
  String statsYourCountToday(int count) {
    return 'Tus Cloudings de hoy: $count';
  }

  @override
  String statsPercentile(int percentile) {
    return 'Por delante del $percentile% de participantes';
  }

  @override
  String statsParticipants(int count) {
    return '$count participantes hoy';
  }

  @override
  String get statsNoData =>
      'Aún no hay datos de comparación. Vuelve más tarde.';

  @override
  String get statsCountryNotSet =>
      'Configura tu país en Ajustes para ver el ranking nacional.';

  @override
  String get friendsTitle => 'Amigos';

  @override
  String get friendsTooltip => 'Amigos';

  @override
  String get friendsTodayHeader => 'Cloudings de hoy';

  @override
  String get friendsEmpty =>
      'Aún no tienes amigos. ¡Envía una solicitud arriba!';

  @override
  String get friendRequestsHeader => 'Solicitudes pendientes';

  @override
  String get addFriendLabel => 'Añadir un amigo por correo';

  @override
  String get sendRequestButton => 'Enviar';

  @override
  String get friendRequestSent => 'Solicitud de amistad enviada.';

  @override
  String get friendUserNotFound => 'No hay ningún usuario con ese correo.';

  @override
  String get friendCannotAddSelf => 'No puedes añadirte a ti mismo.';

  @override
  String get acceptButton => 'Aceptar';

  @override
  String get declineButton => 'Rechazar';

  @override
  String get countrySetting => 'País (código de 2 letras)';

  @override
  String get countryHint => 'p. ej. UY';

  @override
  String get invalidCountryError => 'Introduce un código de país de 2 letras';

  @override
  String get signInButton => 'Iniciar sesión';

  @override
  String get signInWithGoogleButton => 'Continuar con Google';

  @override
  String get orDivider => 'O';

  @override
  String get signOutButton => 'Cerrar sesión';

  @override
  String get signOutTooltip => 'Cerrar sesión';

  @override
  String get settingsSaved => 'Ajustes guardados';

  @override
  String get loginFailed => 'Inicio de sesión fallido. Inténtalo de nuevo.';

  @override
  String get calendarTitle => 'Historial';

  @override
  String get calendarTooltip => 'Abrir calendario de historial';

  @override
  String get legendGoalReached => 'Meta alcanzada';

  @override
  String get legendGoalClose => 'Cerca de la meta';

  @override
  String get legendGoalLow => 'Menos de la mitad';

  @override
  String get statusGoalReached => '¡Meta alcanzada! Buen trabajo.';

  @override
  String get statusGoalClose => 'Cerca — más de la mitad.';

  @override
  String get statusGoalLow => 'Menos de la mitad de la meta.';

  @override
  String get statusGoalNone => 'No hay Cloudings registrados este día.';
}
