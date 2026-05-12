// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'CloudyLog';

  @override
  String get homeTitle => 'Clouding Tracker';

  @override
  String greeting(String name) {
    return 'Hello, $name!';
  }

  @override
  String get todaysCloudingsLabel => 'Today\'s Cloudings';

  @override
  String recommendedLabel(int count) {
    return 'Recommended: $count';
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
  String get goalReached => 'Goal reached!';

  @override
  String goalExceeded(int over) {
    return '$over over goal';
  }

  @override
  String get incrementButton => 'Clouding!';

  @override
  String get incrementTooltip => 'Add one Clouding';

  @override
  String get shareButton => 'Share';

  @override
  String get shareTooltip => 'Share your results with friends';

  @override
  String get shareSubject => 'My Clouding results';

  @override
  String shareMessage(int count, int goal) {
    return 'I did $count Cloudings today (goal: $goal). Join me on CloudyLog!';
  }

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsTooltip => 'Open settings';

  @override
  String get recommendedCountSetting => 'Recommended daily Cloudings';

  @override
  String get recommendedCountHint => 'Enter a positive number';

  @override
  String get languageSetting => 'Language';

  @override
  String get displayNameSetting => 'Displayed user name';

  @override
  String get displayNameHint => 'Your display name';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageSpanish => 'Spanish';

  @override
  String get saveButton => 'Save';

  @override
  String get cancelButton => 'Cancel';

  @override
  String get resetTodayButton => 'Reset today\'s count';

  @override
  String get resetConfirmTitle => 'Reset today\'s Cloudings?';

  @override
  String get resetConfirmMessage =>
      'This will set today\'s count back to zero.';

  @override
  String get invalidNumberError => 'Please enter a number greater than 0';

  @override
  String get loginTitle => 'Sign in';

  @override
  String get loginWelcome => 'Welcome to CloudyLog';

  @override
  String get loginSubtitle => 'Sign in to start counting your Cloudings.';

  @override
  String get usernameLabel => 'Username or email';

  @override
  String get passwordLabel => 'Password';

  @override
  String get usernameRequired => 'Username is required';

  @override
  String get passwordRequired => 'Password is required';

  @override
  String get signInButton => 'Sign in';

  @override
  String get signInWithGoogleButton => 'Continue with Google';

  @override
  String get orDivider => 'OR';

  @override
  String get signOutButton => 'Sign out';

  @override
  String get signOutTooltip => 'Sign out';

  @override
  String get settingsSaved => 'Settings saved';

  @override
  String get loginFailed => 'Sign in failed. Please try again.';

  @override
  String get calendarTitle => 'History';

  @override
  String get calendarTooltip => 'Open history calendar';

  @override
  String get legendGoalReached => 'Goal reached';

  @override
  String get legendGoalClose => 'Close to goal';

  @override
  String get legendGoalLow => 'Less than half';

  @override
  String get statusGoalReached => 'Goal reached. Nice work!';

  @override
  String get statusGoalClose => 'Close — over halfway there.';

  @override
  String get statusGoalLow => 'Less than half of the goal.';

  @override
  String get statusGoalNone => 'No Cloudings logged this day.';
}
