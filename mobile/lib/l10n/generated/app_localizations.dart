import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('es')
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'CloudyLog'**
  String get appTitle;

  /// No description provided for @homeTitle.
  ///
  /// In en, this message translates to:
  /// **'Clouding Tracker'**
  String get homeTitle;

  /// No description provided for @greeting.
  ///
  /// In en, this message translates to:
  /// **'Hello, {name}!'**
  String greeting(String name);

  /// No description provided for @todaysCloudingsLabel.
  ///
  /// In en, this message translates to:
  /// **'Today\'s Cloudings'**
  String get todaysCloudingsLabel;

  /// No description provided for @recommendedLabel.
  ///
  /// In en, this message translates to:
  /// **'Recommended: {count}'**
  String recommendedLabel(int count);

  /// No description provided for @progressLabel.
  ///
  /// In en, this message translates to:
  /// **'{current} / {goal}'**
  String progressLabel(int current, int goal);

  /// No description provided for @progressPercentLabel.
  ///
  /// In en, this message translates to:
  /// **'{percent}%'**
  String progressPercentLabel(int percent);

  /// No description provided for @goalReached.
  ///
  /// In en, this message translates to:
  /// **'Goal reached!'**
  String get goalReached;

  /// No description provided for @goalExceeded.
  ///
  /// In en, this message translates to:
  /// **'{over} over goal'**
  String goalExceeded(int over);

  /// No description provided for @incrementButton.
  ///
  /// In en, this message translates to:
  /// **'Clouding!'**
  String get incrementButton;

  /// No description provided for @incrementTooltip.
  ///
  /// In en, this message translates to:
  /// **'Add one Clouding'**
  String get incrementTooltip;

  /// No description provided for @shareButton.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get shareButton;

  /// No description provided for @shareTooltip.
  ///
  /// In en, this message translates to:
  /// **'Share your results with friends'**
  String get shareTooltip;

  /// No description provided for @shareSubject.
  ///
  /// In en, this message translates to:
  /// **'My Clouding results'**
  String get shareSubject;

  /// No description provided for @shareMessage.
  ///
  /// In en, this message translates to:
  /// **'I did {count} Cloudings today (goal: {goal}). Join me on CloudyLog!'**
  String shareMessage(int count, int goal);

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsTooltip.
  ///
  /// In en, this message translates to:
  /// **'Open settings'**
  String get settingsTooltip;

  /// No description provided for @recommendedCountSetting.
  ///
  /// In en, this message translates to:
  /// **'Recommended daily Cloudings'**
  String get recommendedCountSetting;

  /// No description provided for @recommendedCountHint.
  ///
  /// In en, this message translates to:
  /// **'Enter a positive number'**
  String get recommendedCountHint;

  /// No description provided for @languageSetting.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get languageSetting;

  /// No description provided for @displayNameSetting.
  ///
  /// In en, this message translates to:
  /// **'Displayed user name'**
  String get displayNameSetting;

  /// No description provided for @displayNameHint.
  ///
  /// In en, this message translates to:
  /// **'Your display name'**
  String get displayNameHint;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageSpanish.
  ///
  /// In en, this message translates to:
  /// **'Spanish'**
  String get languageSpanish;

  /// No description provided for @saveButton.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get saveButton;

  /// No description provided for @cancelButton.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancelButton;

  /// No description provided for @resetTodayButton.
  ///
  /// In en, this message translates to:
  /// **'Reset today\'s count'**
  String get resetTodayButton;

  /// No description provided for @resetConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset today\'s Cloudings?'**
  String get resetConfirmTitle;

  /// No description provided for @resetConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'This will set today\'s count back to zero.'**
  String get resetConfirmMessage;

  /// No description provided for @invalidNumberError.
  ///
  /// In en, this message translates to:
  /// **'Please enter a number greater than 0'**
  String get invalidNumberError;

  /// No description provided for @loginTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get loginTitle;

  /// No description provided for @loginWelcome.
  ///
  /// In en, this message translates to:
  /// **'Welcome to CloudyLog'**
  String get loginWelcome;

  /// No description provided for @loginSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in so your Cloudings can sync to your account.'**
  String get loginSubtitle;

  /// No description provided for @usernameLabel.
  ///
  /// In en, this message translates to:
  /// **'Username or email'**
  String get usernameLabel;

  /// No description provided for @passwordLabel.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get passwordLabel;

  /// No description provided for @usernameRequired.
  ///
  /// In en, this message translates to:
  /// **'Username is required'**
  String get usernameRequired;

  /// No description provided for @passwordRequired.
  ///
  /// In en, this message translates to:
  /// **'Password is required'**
  String get passwordRequired;

  /// No description provided for @signUpTitle.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get signUpTitle;

  /// No description provided for @createAccountButton.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get createAccountButton;

  /// No description provided for @haveAccountSignIn.
  ///
  /// In en, this message translates to:
  /// **'Already have an account? Sign in'**
  String get haveAccountSignIn;

  /// No description provided for @noAccountSignUp.
  ///
  /// In en, this message translates to:
  /// **'No account? Create one'**
  String get noAccountSignUp;

  /// No description provided for @emailLabel.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get emailLabel;

  /// No description provided for @emailRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email'**
  String get emailRequired;

  /// No description provided for @displayNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Display name is required'**
  String get displayNameRequired;

  /// No description provided for @errorInvalidCredentials.
  ///
  /// In en, this message translates to:
  /// **'Wrong email or password.'**
  String get errorInvalidCredentials;

  /// No description provided for @errorEmailAlreadyRegistered.
  ///
  /// In en, this message translates to:
  /// **'This email is already registered.'**
  String get errorEmailAlreadyRegistered;

  /// No description provided for @errorNetwork.
  ///
  /// In en, this message translates to:
  /// **'Could not reach the server. Check your connection.'**
  String get errorNetwork;

  /// No description provided for @googleSignInUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Google sign-in isn\'t available yet.'**
  String get googleSignInUnavailable;

  /// No description provided for @proTitle.
  ///
  /// In en, this message translates to:
  /// **'Account & Pro'**
  String get proTitle;

  /// No description provided for @proTooltip.
  ///
  /// In en, this message translates to:
  /// **'Account & Pro'**
  String get proTooltip;

  /// No description provided for @upgradeButton.
  ///
  /// In en, this message translates to:
  /// **'Upgrade to Pro'**
  String get upgradeButton;

  /// No description provided for @accountHeader.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get accountHeader;

  /// No description provided for @signedInAs.
  ///
  /// In en, this message translates to:
  /// **'Signed in as {email}'**
  String signedInAs(String email);

  /// No description provided for @notSignedIn.
  ///
  /// In en, this message translates to:
  /// **'Not signed in'**
  String get notSignedIn;

  /// No description provided for @freeTierNote.
  ///
  /// In en, this message translates to:
  /// **'The free version keeps everything on this device.'**
  String get freeTierNote;

  /// No description provided for @proBenefitsTitle.
  ///
  /// In en, this message translates to:
  /// **'Go Pro'**
  String get proBenefitsTitle;

  /// No description provided for @proBenefitStorage.
  ///
  /// In en, this message translates to:
  /// **'Back up your history to the cloud'**
  String get proBenefitStorage;

  /// No description provided for @proBenefitCompare.
  ///
  /// In en, this message translates to:
  /// **'Compare your stats with your country and the world'**
  String get proBenefitCompare;

  /// No description provided for @proBenefitFriends.
  ///
  /// In en, this message translates to:
  /// **'Add friends and share your results'**
  String get proBenefitFriends;

  /// No description provided for @proPriceNote.
  ///
  /// In en, this message translates to:
  /// **'Development build: the purchase is simulated — no real charge.'**
  String get proPriceNote;

  /// No description provided for @subscribeButton.
  ///
  /// In en, this message translates to:
  /// **'Activate Pro'**
  String get subscribeButton;

  /// No description provided for @signInRequiredForPro.
  ///
  /// In en, this message translates to:
  /// **'Pro needs an account so your data can sync.'**
  String get signInRequiredForPro;

  /// No description provided for @purchaseSuccess.
  ///
  /// In en, this message translates to:
  /// **'You\'re Pro now! Your history is syncing to the cloud.'**
  String get purchaseSuccess;

  /// No description provided for @purchaseFailed.
  ///
  /// In en, this message translates to:
  /// **'Purchase failed. Please try again.'**
  String get purchaseFailed;

  /// No description provided for @manageSubscriptionTitle.
  ///
  /// In en, this message translates to:
  /// **'Your subscription'**
  String get manageSubscriptionTitle;

  /// No description provided for @subscriptionStatusActive.
  ///
  /// In en, this message translates to:
  /// **'Pro — active'**
  String get subscriptionStatusActive;

  /// No description provided for @subscriptionStatusCanceled.
  ///
  /// In en, this message translates to:
  /// **'Pro — canceled (active until expiry)'**
  String get subscriptionStatusCanceled;

  /// No description provided for @expiresOn.
  ///
  /// In en, this message translates to:
  /// **'Valid until {date}'**
  String expiresOn(String date);

  /// No description provided for @cancelSubscriptionButton.
  ///
  /// In en, this message translates to:
  /// **'Cancel subscription'**
  String get cancelSubscriptionButton;

  /// No description provided for @cancelSubscriptionConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Cancel Pro?'**
  String get cancelSubscriptionConfirmTitle;

  /// No description provided for @cancelSubscriptionConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'Pro stays active until the expiry date, then the app returns to the free tier. Your data stays on this device.'**
  String get cancelSubscriptionConfirmMessage;

  /// No description provided for @subscriptionCanceledMessage.
  ///
  /// In en, this message translates to:
  /// **'Subscription canceled. Pro stays active until the expiry date.'**
  String get subscriptionCanceledMessage;

  /// No description provided for @syncNowButton.
  ///
  /// In en, this message translates to:
  /// **'Sync now'**
  String get syncNowButton;

  /// No description provided for @proRequiredMessage.
  ///
  /// In en, this message translates to:
  /// **'This feature needs an active Pro subscription.'**
  String get proRequiredMessage;

  /// No description provided for @statsTitle.
  ///
  /// In en, this message translates to:
  /// **'Compare'**
  String get statsTitle;

  /// No description provided for @statsTooltip.
  ///
  /// In en, this message translates to:
  /// **'Compare with others'**
  String get statsTooltip;

  /// No description provided for @statsWorldwide.
  ///
  /// In en, this message translates to:
  /// **'Worldwide'**
  String get statsWorldwide;

  /// No description provided for @statsCountry.
  ///
  /// In en, this message translates to:
  /// **'Your country ({country})'**
  String statsCountry(String country);

  /// No description provided for @statsCountryUnknown.
  ///
  /// In en, this message translates to:
  /// **'Your country'**
  String get statsCountryUnknown;

  /// No description provided for @statsYourCountToday.
  ///
  /// In en, this message translates to:
  /// **'Your Cloudings today: {count}'**
  String statsYourCountToday(int count);

  /// No description provided for @statsPercentile.
  ///
  /// In en, this message translates to:
  /// **'Ahead of {percentile}% of participants'**
  String statsPercentile(int percentile);

  /// No description provided for @statsParticipants.
  ///
  /// In en, this message translates to:
  /// **'{count} participants today'**
  String statsParticipants(int count);

  /// No description provided for @statsNoData.
  ///
  /// In en, this message translates to:
  /// **'No comparison data yet. Check back later.'**
  String get statsNoData;

  /// No description provided for @statsCountryNotSet.
  ///
  /// In en, this message translates to:
  /// **'Set your country in Settings to see country rankings.'**
  String get statsCountryNotSet;

  /// No description provided for @friendsTitle.
  ///
  /// In en, this message translates to:
  /// **'Friends'**
  String get friendsTitle;

  /// No description provided for @friendsTooltip.
  ///
  /// In en, this message translates to:
  /// **'Friends'**
  String get friendsTooltip;

  /// No description provided for @friendsTodayHeader.
  ///
  /// In en, this message translates to:
  /// **'Today\'s Cloudings'**
  String get friendsTodayHeader;

  /// No description provided for @friendsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No friends yet. Send a request above!'**
  String get friendsEmpty;

  /// No description provided for @friendRequestsHeader.
  ///
  /// In en, this message translates to:
  /// **'Pending requests'**
  String get friendRequestsHeader;

  /// No description provided for @addFriendLabel.
  ///
  /// In en, this message translates to:
  /// **'Add a friend by email'**
  String get addFriendLabel;

  /// No description provided for @sendRequestButton.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get sendRequestButton;

  /// No description provided for @friendRequestSent.
  ///
  /// In en, this message translates to:
  /// **'Friend request sent.'**
  String get friendRequestSent;

  /// No description provided for @friendUserNotFound.
  ///
  /// In en, this message translates to:
  /// **'No user with that email.'**
  String get friendUserNotFound;

  /// No description provided for @friendCannotAddSelf.
  ///
  /// In en, this message translates to:
  /// **'You can\'t add yourself.'**
  String get friendCannotAddSelf;

  /// No description provided for @acceptButton.
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get acceptButton;

  /// No description provided for @declineButton.
  ///
  /// In en, this message translates to:
  /// **'Decline'**
  String get declineButton;

  /// No description provided for @countrySetting.
  ///
  /// In en, this message translates to:
  /// **'Country (2-letter code)'**
  String get countrySetting;

  /// No description provided for @countryHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. US'**
  String get countryHint;

  /// No description provided for @invalidCountryError.
  ///
  /// In en, this message translates to:
  /// **'Enter a 2-letter country code'**
  String get invalidCountryError;

  /// No description provided for @signInButton.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get signInButton;

  /// No description provided for @signInWithGoogleButton.
  ///
  /// In en, this message translates to:
  /// **'Continue with Google'**
  String get signInWithGoogleButton;

  /// No description provided for @orDivider.
  ///
  /// In en, this message translates to:
  /// **'OR'**
  String get orDivider;

  /// No description provided for @signOutButton.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get signOutButton;

  /// No description provided for @signOutTooltip.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get signOutTooltip;

  /// No description provided for @settingsSaved.
  ///
  /// In en, this message translates to:
  /// **'Settings saved'**
  String get settingsSaved;

  /// No description provided for @loginFailed.
  ///
  /// In en, this message translates to:
  /// **'Sign in failed. Please try again.'**
  String get loginFailed;

  /// No description provided for @calendarTitle.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get calendarTitle;

  /// No description provided for @calendarTooltip.
  ///
  /// In en, this message translates to:
  /// **'Open history calendar'**
  String get calendarTooltip;

  /// No description provided for @legendGoalReached.
  ///
  /// In en, this message translates to:
  /// **'Goal reached'**
  String get legendGoalReached;

  /// No description provided for @legendGoalClose.
  ///
  /// In en, this message translates to:
  /// **'Close to goal'**
  String get legendGoalClose;

  /// No description provided for @legendGoalLow.
  ///
  /// In en, this message translates to:
  /// **'Less than half'**
  String get legendGoalLow;

  /// No description provided for @statusGoalReached.
  ///
  /// In en, this message translates to:
  /// **'Goal reached. Nice work!'**
  String get statusGoalReached;

  /// No description provided for @statusGoalClose.
  ///
  /// In en, this message translates to:
  /// **'Close — over halfway there.'**
  String get statusGoalClose;

  /// No description provided for @statusGoalLow.
  ///
  /// In en, this message translates to:
  /// **'Less than half of the goal.'**
  String get statusGoalLow;

  /// No description provided for @statusGoalNone.
  ///
  /// In en, this message translates to:
  /// **'No Cloudings logged this day.'**
  String get statusGoalNone;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'es'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
