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
  String get loginSubtitle =>
      'Sign in so your Cloudings can sync to your account.';

  @override
  String get usernameLabel => 'Username or email';

  @override
  String get passwordLabel => 'Password';

  @override
  String get usernameRequired => 'Username is required';

  @override
  String get passwordRequired => 'Password is required';

  @override
  String get signUpTitle => 'Create account';

  @override
  String get createAccountButton => 'Create account';

  @override
  String get haveAccountSignIn => 'Already have an account? Sign in';

  @override
  String get noAccountSignUp => 'No account? Create one';

  @override
  String get emailLabel => 'Email';

  @override
  String get emailRequired => 'Enter a valid email';

  @override
  String get displayNameRequired => 'Display name is required';

  @override
  String get errorInvalidCredentials => 'Wrong email or password.';

  @override
  String get errorEmailAlreadyRegistered => 'This email is already registered.';

  @override
  String get errorNetwork =>
      'Could not reach the server. Check your connection.';

  @override
  String get googleSignInUnavailable => 'Google sign-in isn\'t available yet.';

  @override
  String get proTitle => 'Account & Pro';

  @override
  String get proTooltip => 'Account & Pro';

  @override
  String get upgradeButton => 'Upgrade to Pro';

  @override
  String get accountHeader => 'Account';

  @override
  String signedInAs(String email) {
    return 'Signed in as $email';
  }

  @override
  String get notSignedIn => 'Not signed in';

  @override
  String get freeTierNote =>
      'The free version keeps everything on this device.';

  @override
  String get proBenefitsTitle => 'Go Pro';

  @override
  String get proBenefitStorage => 'Back up your history to the cloud';

  @override
  String get proBenefitCompare =>
      'Compare your stats with your country and the world';

  @override
  String get proBenefitFriends => 'Add friends and share your results';

  @override
  String get proPriceNote =>
      'Development build: the purchase is simulated — no real charge.';

  @override
  String get subscribeButton => 'Activate Pro';

  @override
  String get signInRequiredForPro =>
      'Pro needs an account so your data can sync.';

  @override
  String get purchaseSuccess =>
      'You\'re Pro now! Your history is syncing to the cloud.';

  @override
  String get purchaseFailed => 'Purchase failed. Please try again.';

  @override
  String get manageSubscriptionTitle => 'Your subscription';

  @override
  String get subscriptionStatusActive => 'Pro — active';

  @override
  String get subscriptionStatusCanceled =>
      'Pro — canceled (active until expiry)';

  @override
  String expiresOn(String date) {
    return 'Valid until $date';
  }

  @override
  String get cancelSubscriptionButton => 'Cancel subscription';

  @override
  String get cancelSubscriptionConfirmTitle => 'Cancel Pro?';

  @override
  String get cancelSubscriptionConfirmMessage =>
      'Pro stays active until the expiry date, then the app returns to the free tier. Your data stays on this device.';

  @override
  String get subscriptionCanceledMessage =>
      'Subscription canceled. Pro stays active until the expiry date.';

  @override
  String get syncNowButton => 'Sync now';

  @override
  String get proRequiredMessage =>
      'This feature needs an active Pro subscription.';

  @override
  String get statsTitle => 'Compare';

  @override
  String get statsTooltip => 'Compare with others';

  @override
  String get statsWorldwide => 'Worldwide';

  @override
  String statsCountry(String country) {
    return 'Your country ($country)';
  }

  @override
  String get statsCountryUnknown => 'Your country';

  @override
  String statsYourCountToday(int count) {
    return 'Your Cloudings today: $count';
  }

  @override
  String statsPercentile(int percentile) {
    return 'Ahead of $percentile% of participants';
  }

  @override
  String statsParticipants(int count) {
    return '$count participants today';
  }

  @override
  String get statsNoData => 'No comparison data yet. Check back later.';

  @override
  String get statsCountryNotSet =>
      'Set your country in Settings to see country rankings.';

  @override
  String get friendsTitle => 'Friends';

  @override
  String get friendsTooltip => 'Friends';

  @override
  String get friendsTodayHeader => 'Today\'s Cloudings';

  @override
  String get friendsEmpty => 'No friends yet. Send a request above!';

  @override
  String get friendRequestsHeader => 'Pending requests';

  @override
  String get addFriendLabel => 'Add a friend by email';

  @override
  String get sendRequestButton => 'Send';

  @override
  String get friendRequestSent => 'Friend request sent.';

  @override
  String get friendUserNotFound => 'No user with that email.';

  @override
  String get friendCannotAddSelf => 'You can\'t add yourself.';

  @override
  String get acceptButton => 'Accept';

  @override
  String get declineButton => 'Decline';

  @override
  String get countrySetting => 'Country (2-letter code)';

  @override
  String get countryHint => 'e.g. US';

  @override
  String get invalidCountryError => 'Enter a 2-letter country code';

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
