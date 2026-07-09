import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';

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
  static const List<Locale> supportedLocales = <Locale>[Locale('en')];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Puff'**
  String get appTitle;

  /// No description provided for @navHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// No description provided for @navStats.
  ///
  /// In en, this message translates to:
  /// **'Stats'**
  String get navStats;

  /// No description provided for @navDuels.
  ///
  /// In en, this message translates to:
  /// **'Duels'**
  String get navDuels;

  /// No description provided for @navYou.
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get navYou;

  /// No description provided for @streakPill.
  ///
  /// In en, this message translates to:
  /// **'{days}-day streak'**
  String streakPill(int days);

  /// No description provided for @tootsToday.
  ///
  /// In en, this message translates to:
  /// **'toots today'**
  String get tootsToday;

  /// No description provided for @tapHint.
  ///
  /// In en, this message translates to:
  /// **'Tap when it happens'**
  String get tapHint;

  /// No description provided for @tapSemantics.
  ///
  /// In en, this message translates to:
  /// **'Log a toot, {count} today'**
  String tapSemantics(int count);

  /// No description provided for @worldAvgQuiet.
  ///
  /// In en, this message translates to:
  /// **'world average 10–20 · all quiet so far'**
  String get worldAvgQuiet;

  /// No description provided for @worldAvgOnPace.
  ///
  /// In en, this message translates to:
  /// **'world average 10–20 · you\'re on pace'**
  String get worldAvgOnPace;

  /// No description provided for @worldAvgBreezy.
  ///
  /// In en, this message translates to:
  /// **'world average 10–20 · breezy day'**
  String get worldAvgBreezy;

  /// No description provided for @thisWeek.
  ///
  /// In en, this message translates to:
  /// **'This week'**
  String get thisWeek;

  /// No description provided for @weekTotal.
  ///
  /// In en, this message translates to:
  /// **'{count} total'**
  String weekTotal(int count);

  /// No description provided for @tagSilent.
  ///
  /// In en, this message translates to:
  /// **'Silent'**
  String get tagSilent;

  /// No description provided for @tagSqueaky.
  ///
  /// In en, this message translates to:
  /// **'Squeaky'**
  String get tagSqueaky;

  /// No description provided for @tagThunder.
  ///
  /// In en, this message translates to:
  /// **'Thunder'**
  String get tagThunder;

  /// No description provided for @tagSbd.
  ///
  /// In en, this message translates to:
  /// **'SBD'**
  String get tagSbd;

  /// No description provided for @tagWindy.
  ///
  /// In en, this message translates to:
  /// **'Windy'**
  String get tagWindy;

  /// No description provided for @tagOops.
  ///
  /// In en, this message translates to:
  /// **'Oops'**
  String get tagOops;

  /// No description provided for @addTagButton.
  ///
  /// In en, this message translates to:
  /// **'+ tag'**
  String get addTagButton;

  /// No description provided for @addTagTitle.
  ///
  /// In en, this message translates to:
  /// **'Your own tag'**
  String get addTagTitle;

  /// No description provided for @addTagHint.
  ///
  /// In en, this message translates to:
  /// **'Name your wind'**
  String get addTagHint;

  /// No description provided for @addButton.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get addButton;

  /// No description provided for @cancelButton.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancelButton;

  /// No description provided for @statsTitle.
  ///
  /// In en, this message translates to:
  /// **'Stats'**
  String get statsTitle;

  /// No description provided for @statsTodayVsWorld.
  ///
  /// In en, this message translates to:
  /// **'Today vs the world'**
  String get statsTodayVsWorld;

  /// No description provided for @statsWorldRange.
  ///
  /// In en, this message translates to:
  /// **'Most people land between 10 and 20 a day.'**
  String get statsWorldRange;

  /// No description provided for @statsPercentile.
  ///
  /// In en, this message translates to:
  /// **'Ahead of {percent}% of tooters'**
  String statsPercentile(int percent);

  /// No description provided for @statsParticipants.
  ///
  /// In en, this message translates to:
  /// **'{count} tooters counted · updated daily'**
  String statsParticipants(int count);

  /// No description provided for @statsNoGlobalData.
  ///
  /// In en, this message translates to:
  /// **'Not enough wind data yet — check back tomorrow.'**
  String get statsNoGlobalData;

  /// No description provided for @statsHistory.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get statsHistory;

  /// No description provided for @statsTimeOfDay.
  ///
  /// In en, this message translates to:
  /// **'Time of day'**
  String get statsTimeOfDay;

  /// No description provided for @statsTimeOfDayHint.
  ///
  /// In en, this message translates to:
  /// **'When the wind blows, last 30 days'**
  String get statsTimeOfDayHint;

  /// No description provided for @statsWeekday.
  ///
  /// In en, this message translates to:
  /// **'Weekday patterns'**
  String get statsWeekday;

  /// No description provided for @statsWeekdayHint.
  ///
  /// In en, this message translates to:
  /// **'Average per weekday, last 8 weeks'**
  String get statsWeekdayHint;

  /// No description provided for @statsEmptyDay.
  ///
  /// In en, this message translates to:
  /// **'All quiet on the wind front.'**
  String get statsEmptyDay;

  /// No description provided for @historyLockedNote.
  ///
  /// In en, this message translates to:
  /// **'Free keeps the last 7 days on this phone. Pro remembers everything.'**
  String get historyLockedNote;

  /// No description provided for @lockedProCard.
  ///
  /// In en, this message translates to:
  /// **'Unlock with Pro'**
  String get lockedProCard;

  /// No description provided for @proChip.
  ///
  /// In en, this message translates to:
  /// **'PRO'**
  String get proChip;

  /// No description provided for @disclaimer.
  ///
  /// In en, this message translates to:
  /// **'Patterns, not diagnoses — Puff isn\'t medical advice.'**
  String get disclaimer;

  /// No description provided for @duelsComingSoon.
  ///
  /// In en, this message translates to:
  /// **'Duels are coming soon'**
  String get duelsComingSoon;

  /// No description provided for @duelsComingSoonBody.
  ///
  /// In en, this message translates to:
  /// **'Challenge a friend to a head-to-head week. Gust is stretching.'**
  String get duelsComingSoonBody;

  /// No description provided for @youTitle.
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get youTitle;

  /// No description provided for @totalToots.
  ///
  /// In en, this message translates to:
  /// **'{count} toots all time'**
  String totalToots(int count);

  /// No description provided for @bestDayLabel.
  ///
  /// In en, this message translates to:
  /// **'best day · {count}'**
  String bestDayLabel(int count);

  /// No description provided for @badgesHeader.
  ///
  /// In en, this message translates to:
  /// **'Badges'**
  String get badgesHeader;

  /// No description provided for @badgeFirstPuff.
  ///
  /// In en, this message translates to:
  /// **'First puff'**
  String get badgeFirstPuff;

  /// No description provided for @badgeFirstPuffDesc.
  ///
  /// In en, this message translates to:
  /// **'Logged your very first toot'**
  String get badgeFirstPuffDesc;

  /// No description provided for @badgeDoubleDigits.
  ///
  /// In en, this message translates to:
  /// **'Double digits'**
  String get badgeDoubleDigits;

  /// No description provided for @badgeDoubleDigitsDesc.
  ///
  /// In en, this message translates to:
  /// **'10 in a single day'**
  String get badgeDoubleDigitsDesc;

  /// No description provided for @badgeStreak3.
  ///
  /// In en, this message translates to:
  /// **'Warm front'**
  String get badgeStreak3;

  /// No description provided for @badgeStreak3Desc.
  ///
  /// In en, this message translates to:
  /// **'3-day streak'**
  String get badgeStreak3Desc;

  /// No description provided for @badgeStreak7.
  ///
  /// In en, this message translates to:
  /// **'Jet stream'**
  String get badgeStreak7;

  /// No description provided for @badgeStreak7Desc.
  ///
  /// In en, this message translates to:
  /// **'7-day streak'**
  String get badgeStreak7Desc;

  /// No description provided for @badgeStreak30.
  ///
  /// In en, this message translates to:
  /// **'Trade winds'**
  String get badgeStreak30;

  /// No description provided for @badgeStreak30Desc.
  ///
  /// In en, this message translates to:
  /// **'30-day streak'**
  String get badgeStreak30Desc;

  /// No description provided for @badgeCentury.
  ///
  /// In en, this message translates to:
  /// **'Century club'**
  String get badgeCentury;

  /// No description provided for @badgeCenturyDesc.
  ///
  /// In en, this message translates to:
  /// **'100 toots all time'**
  String get badgeCenturyDesc;

  /// No description provided for @badgeGaleForce.
  ///
  /// In en, this message translates to:
  /// **'Gale force'**
  String get badgeGaleForce;

  /// No description provided for @badgeGaleForceDesc.
  ///
  /// In en, this message translates to:
  /// **'20 or more in one day'**
  String get badgeGaleForceDesc;

  /// No description provided for @badgeTagCollector.
  ///
  /// In en, this message translates to:
  /// **'Connoisseur'**
  String get badgeTagCollector;

  /// No description provided for @badgeTagCollectorDesc.
  ///
  /// In en, this message translates to:
  /// **'Used all four classic tags'**
  String get badgeTagCollectorDesc;

  /// No description provided for @badgeRegular.
  ///
  /// In en, this message translates to:
  /// **'Regular'**
  String get badgeRegular;

  /// No description provided for @badgeRegularDesc.
  ///
  /// In en, this message translates to:
  /// **'Logged on 14 different days'**
  String get badgeRegularDesc;

  /// No description provided for @wrappedButton.
  ///
  /// In en, this message translates to:
  /// **'Your year in wind'**
  String get wrappedButton;

  /// No description provided for @wrappedTitle.
  ///
  /// In en, this message translates to:
  /// **'{year}, wrapped'**
  String wrappedTitle(int year);

  /// No description provided for @wrappedTotal.
  ///
  /// In en, this message translates to:
  /// **'{count} toots'**
  String wrappedTotal(int count);

  /// No description provided for @wrappedBestDay.
  ///
  /// In en, this message translates to:
  /// **'best day · {count}'**
  String wrappedBestDay(int count);

  /// No description provided for @wrappedStreak.
  ///
  /// In en, this message translates to:
  /// **'longest streak · {days} days'**
  String wrappedStreak(int days);

  /// No description provided for @wrappedTopTag.
  ///
  /// In en, this message translates to:
  /// **'signature move · {tag}'**
  String wrappedTopTag(String tag);

  /// No description provided for @wrappedNoData.
  ///
  /// In en, this message translates to:
  /// **'Nothing logged yet — your wind year starts now.'**
  String get wrappedNoData;

  /// No description provided for @shareButton.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get shareButton;

  /// No description provided for @closeButton.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get closeButton;

  /// No description provided for @shareCardStreakHeadline.
  ///
  /// In en, this message translates to:
  /// **'{days} days of dedication'**
  String shareCardStreakHeadline(int days);

  /// No description provided for @shareCardFooter.
  ///
  /// In en, this message translates to:
  /// **'puff · every toot counts'**
  String get shareCardFooter;

  /// No description provided for @shareStreakText.
  ///
  /// In en, this message translates to:
  /// **'My {days}-day streak on Puff. Every toot counts.'**
  String shareStreakText(int days);

  /// No description provided for @shareBadgeText.
  ///
  /// In en, this message translates to:
  /// **'Just earned \"{badge}\" on Puff. Every toot counts.'**
  String shareBadgeText(String badge);

  /// No description provided for @shareWrappedText.
  ///
  /// In en, this message translates to:
  /// **'My year in wind, by Puff.'**
  String get shareWrappedText;

  /// No description provided for @proHeader.
  ///
  /// In en, this message translates to:
  /// **'Puff Pro'**
  String get proHeader;

  /// No description provided for @goProButton.
  ///
  /// In en, this message translates to:
  /// **'Go Pro'**
  String get goProButton;

  /// No description provided for @maybeLaterButton.
  ///
  /// In en, this message translates to:
  /// **'Maybe later'**
  String get maybeLaterButton;

  /// No description provided for @paywallLead.
  ///
  /// In en, this message translates to:
  /// **'Keep every day, see your patterns, back it all up.'**
  String get paywallLead;

  /// No description provided for @paywallBenefitHistory.
  ///
  /// In en, this message translates to:
  /// **'Unlimited history, synced to the cloud'**
  String get paywallBenefitHistory;

  /// No description provided for @paywallBenefitStats.
  ///
  /// In en, this message translates to:
  /// **'Percentiles, heatmaps and weekday patterns'**
  String get paywallBenefitStats;

  /// No description provided for @paywallBenefitBadges.
  ///
  /// In en, this message translates to:
  /// **'The full badge collection'**
  String get paywallBenefitBadges;

  /// No description provided for @paywallBenefitSoon.
  ///
  /// In en, this message translates to:
  /// **'Coming soon: the trigger food detective'**
  String get paywallBenefitSoon;

  /// No description provided for @paywallPrice.
  ///
  /// In en, this message translates to:
  /// **'\$2.49 a month or \$17.99 a year — under \$1.50 a month.'**
  String get paywallPrice;

  /// No description provided for @paywallDevNote.
  ///
  /// In en, this message translates to:
  /// **'Development build: purchases are simulated, no real charge.'**
  String get paywallDevNote;

  /// No description provided for @purchaseSuccess.
  ///
  /// In en, this message translates to:
  /// **'You\'re Pro. Gust salutes you.'**
  String get purchaseSuccess;

  /// No description provided for @purchaseFailed.
  ///
  /// In en, this message translates to:
  /// **'That didn\'t go through. Try again?'**
  String get purchaseFailed;

  /// No description provided for @proStatusActive.
  ///
  /// In en, this message translates to:
  /// **'Pro — active'**
  String get proStatusActive;

  /// No description provided for @proStatusCanceled.
  ///
  /// In en, this message translates to:
  /// **'Pro — canceled, runs until expiry'**
  String get proStatusCanceled;

  /// No description provided for @proValidUntil.
  ///
  /// In en, this message translates to:
  /// **'valid until {date}'**
  String proValidUntil(String date);

  /// No description provided for @cancelProButton.
  ///
  /// In en, this message translates to:
  /// **'Cancel subscription'**
  String get cancelProButton;

  /// No description provided for @cancelProConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Cancel Pro?'**
  String get cancelProConfirmTitle;

  /// No description provided for @cancelProConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'Pro keeps working until the expiry date. Your data stays on this phone either way.'**
  String get cancelProConfirmBody;

  /// No description provided for @proCanceledMessage.
  ///
  /// In en, this message translates to:
  /// **'Canceled. Pro runs until the expiry date.'**
  String get proCanceledMessage;

  /// No description provided for @accountHeader.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get accountHeader;

  /// No description provided for @accountAnonymous.
  ///
  /// In en, this message translates to:
  /// **'No account — your toots live on this phone'**
  String get accountAnonymous;

  /// No description provided for @accountNoAccountHint.
  ///
  /// In en, this message translates to:
  /// **'You don\'t need an account to track toots. Log in to bring Puff Pro to a new phone.'**
  String get accountNoAccountHint;

  /// No description provided for @createAccountButton.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get createAccountButton;

  /// No description provided for @logInButton.
  ///
  /// In en, this message translates to:
  /// **'Log in'**
  String get logInButton;

  /// No description provided for @logOutButton.
  ///
  /// In en, this message translates to:
  /// **'Log out'**
  String get logOutButton;

  /// No description provided for @authHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Already have an account? Log in'**
  String get authHaveAccount;

  /// No description provided for @authNeedAccount.
  ///
  /// In en, this message translates to:
  /// **'New here? Create an account'**
  String get authNeedAccount;

  /// No description provided for @emailLabel.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get emailLabel;

  /// No description provided for @passwordLabel.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get passwordLabel;

  /// No description provided for @confirmPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Repeat password'**
  String get confirmPasswordLabel;

  /// No description provided for @emailInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email'**
  String get emailInvalid;

  /// No description provided for @passwordTooShort.
  ///
  /// In en, this message translates to:
  /// **'At least 8 characters'**
  String get passwordTooShort;

  /// No description provided for @passwordMismatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords don\'t match'**
  String get passwordMismatch;

  /// No description provided for @passwordRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter your password'**
  String get passwordRequired;

  /// No description provided for @accountCreated.
  ///
  /// In en, this message translates to:
  /// **'Account linked. Same you, safer data.'**
  String get accountCreated;

  /// No description provided for @signInSuccess.
  ///
  /// In en, this message translates to:
  /// **'Welcome back!'**
  String get signInSuccess;

  /// No description provided for @signInFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t sign in. Check your email and password.'**
  String get signInFailed;

  /// No description provided for @signOutConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Log out?'**
  String get signOutConfirmTitle;

  /// No description provided for @signOutConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'Your toots stay on this phone. Sign back in anytime to sync. Pro features pause until you do.'**
  String get signOutConfirmBody;

  /// No description provided for @signOutDone.
  ///
  /// In en, this message translates to:
  /// **'Signed out.'**
  String get signOutDone;

  /// No description provided for @accountEmail.
  ///
  /// In en, this message translates to:
  /// **'Signed in as {email}'**
  String accountEmail(String email);

  /// No description provided for @accountUpgradeFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t link the account. Try again online.'**
  String get accountUpgradeFailed;

  /// No description provided for @syncNowButton.
  ///
  /// In en, this message translates to:
  /// **'Sync now'**
  String get syncNowButton;

  /// No description provided for @syncDone.
  ///
  /// In en, this message translates to:
  /// **'Synced.'**
  String get syncDone;

  /// No description provided for @restoreButton.
  ///
  /// In en, this message translates to:
  /// **'Restore from cloud'**
  String get restoreButton;

  /// No description provided for @restoreDone.
  ///
  /// In en, this message translates to:
  /// **'History restored.'**
  String get restoreDone;

  /// No description provided for @deleteAccountButton.
  ///
  /// In en, this message translates to:
  /// **'Delete my cloud data'**
  String get deleteAccountButton;

  /// No description provided for @deleteConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete everything?'**
  String get deleteConfirmTitle;

  /// No description provided for @deleteConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'Cloud data and account: gone forever. Data on this phone stays unless you uninstall.'**
  String get deleteConfirmBody;

  /// No description provided for @deleteDone.
  ///
  /// In en, this message translates to:
  /// **'Cloud data deleted.'**
  String get deleteDone;

  /// No description provided for @settingsHeader.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsHeader;

  /// No description provided for @themeSetting.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get themeSetting;

  /// No description provided for @themeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get themeSystem;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @soundSetting.
  ///
  /// In en, this message translates to:
  /// **'Tap sound'**
  String get soundSetting;

  /// No description provided for @soundSettingHint.
  ///
  /// In en, this message translates to:
  /// **'One tasteful pop. Off by default.'**
  String get soundSettingHint;

  /// No description provided for @diagnosticsSetting.
  ///
  /// In en, this message translates to:
  /// **'Diagnostics'**
  String get diagnosticsSetting;

  /// No description provided for @diagnosticsSettingHint.
  ///
  /// In en, this message translates to:
  /// **'Errors the app caught quietly, kept for debugging'**
  String get diagnosticsSettingHint;

  /// No description provided for @diagnosticsTitle.
  ///
  /// In en, this message translates to:
  /// **'Diagnostics'**
  String get diagnosticsTitle;

  /// No description provided for @diagnosticsIntro.
  ///
  /// In en, this message translates to:
  /// **'When something fails quietly — a sync, a fetch, a crash — it lands here with its stack trace. Nothing in this log leaves your phone unless you share it.'**
  String get diagnosticsIntro;

  /// No description provided for @diagnosticsEmpty.
  ///
  /// In en, this message translates to:
  /// **'Squeaky clean — nothing has gone wrong yet.'**
  String get diagnosticsEmpty;

  /// No description provided for @diagnosticsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} recorded'**
  String diagnosticsCount(int count);

  /// No description provided for @diagnosticsCountTruncated.
  ///
  /// In en, this message translates to:
  /// **'{total} recorded · showing the newest {shown}'**
  String diagnosticsCountTruncated(int total, int shown);

  /// No description provided for @diagnosticsCopied.
  ///
  /// In en, this message translates to:
  /// **'Copied to clipboard.'**
  String get diagnosticsCopied;

  /// No description provided for @diagnosticsCleared.
  ///
  /// In en, this message translates to:
  /// **'Log cleared.'**
  String get diagnosticsCleared;

  /// No description provided for @diagnosticsShareText.
  ///
  /// In en, this message translates to:
  /// **'Puff diagnostics log'**
  String get diagnosticsShareText;

  /// No description provided for @copyButton.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get copyButton;

  /// No description provided for @clearButton.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clearButton;

  /// No description provided for @privacyNote.
  ///
  /// In en, this message translates to:
  /// **'Your log lives on this phone. World stats use one anonymous number a day — your daily count, nothing else. Cloud sync is Pro-only, and deleting your data is one tap.'**
  String get privacyNote;

  /// No description provided for @errorNetwork.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t reach the cloud. Everything still counts — it\'s saved on your phone.'**
  String get errorNetwork;
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
      <String>['en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
