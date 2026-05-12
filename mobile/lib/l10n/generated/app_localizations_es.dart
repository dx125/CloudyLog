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
      'Inicia sesión para empezar a contar tus Cloudings.';

  @override
  String get usernameLabel => 'Usuario o correo';

  @override
  String get passwordLabel => 'Contraseña';

  @override
  String get usernameRequired => 'El usuario es obligatorio';

  @override
  String get passwordRequired => 'La contraseña es obligatoria';

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
