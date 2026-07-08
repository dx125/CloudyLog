// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Puff';

  @override
  String get navHome => 'Home';

  @override
  String get navStats => 'Stats';

  @override
  String get navDuels => 'Duels';

  @override
  String get navYou => 'You';

  @override
  String streakPill(int days) {
    return '$days-day streak';
  }

  @override
  String get tootsToday => 'toots today';

  @override
  String get tapHint => 'Tap when it happens';

  @override
  String tapSemantics(int count) {
    return 'Log a toot, $count today';
  }

  @override
  String get worldAvgQuiet => 'world average 10–20 · all quiet so far';

  @override
  String get worldAvgOnPace => 'world average 10–20 · you\'re on pace';

  @override
  String get worldAvgBreezy => 'world average 10–20 · breezy day';

  @override
  String get thisWeek => 'This week';

  @override
  String weekTotal(int count) {
    return '$count total';
  }

  @override
  String get tagSilent => 'Silent';

  @override
  String get tagSqueaky => 'Squeaky';

  @override
  String get tagThunder => 'Thunder';

  @override
  String get tagSbd => 'SBD';

  @override
  String get tagWindy => 'Windy';

  @override
  String get tagOops => 'Oops';

  @override
  String get addTagButton => '+ tag';

  @override
  String get addTagTitle => 'Your own tag';

  @override
  String get addTagHint => 'Name your wind';

  @override
  String get addButton => 'Add';

  @override
  String get cancelButton => 'Cancel';

  @override
  String get statsTitle => 'Stats';

  @override
  String get statsTodayVsWorld => 'Today vs the world';

  @override
  String get statsWorldRange => 'Most people land between 10 and 20 a day.';

  @override
  String statsPercentile(int percent) {
    return 'Ahead of $percent% of tooters';
  }

  @override
  String statsParticipants(int count) {
    return '$count tooters counted · updated daily';
  }

  @override
  String get statsNoGlobalData =>
      'Not enough wind data yet — check back tomorrow.';

  @override
  String get statsHistory => 'History';

  @override
  String get statsTimeOfDay => 'Time of day';

  @override
  String get statsTimeOfDayHint => 'When the wind blows, last 30 days';

  @override
  String get statsWeekday => 'Weekday patterns';

  @override
  String get statsWeekdayHint => 'Average per weekday, last 8 weeks';

  @override
  String get statsEmptyDay => 'All quiet on the wind front.';

  @override
  String get historyLockedNote =>
      'Free keeps the last 7 days on this phone. Pro remembers everything.';

  @override
  String get lockedProCard => 'Unlock with Pro';

  @override
  String get proChip => 'PRO';

  @override
  String get disclaimer =>
      'Patterns, not diagnoses — Puff isn\'t medical advice.';

  @override
  String get duelsComingSoon => 'Duels are coming soon';

  @override
  String get duelsComingSoonBody =>
      'Challenge a friend to a head-to-head week. Gust is stretching.';

  @override
  String get youTitle => 'You';

  @override
  String totalToots(int count) {
    return '$count toots all time';
  }

  @override
  String bestDayLabel(int count) {
    return 'best day · $count';
  }

  @override
  String get badgesHeader => 'Badges';

  @override
  String get badgeFirstPuff => 'First puff';

  @override
  String get badgeFirstPuffDesc => 'Logged your very first toot';

  @override
  String get badgeDoubleDigits => 'Double digits';

  @override
  String get badgeDoubleDigitsDesc => '10 in a single day';

  @override
  String get badgeStreak3 => 'Warm front';

  @override
  String get badgeStreak3Desc => '3-day streak';

  @override
  String get badgeStreak7 => 'Jet stream';

  @override
  String get badgeStreak7Desc => '7-day streak';

  @override
  String get badgeStreak30 => 'Trade winds';

  @override
  String get badgeStreak30Desc => '30-day streak';

  @override
  String get badgeCentury => 'Century club';

  @override
  String get badgeCenturyDesc => '100 toots all time';

  @override
  String get badgeGaleForce => 'Gale force';

  @override
  String get badgeGaleForceDesc => '20 or more in one day';

  @override
  String get badgeTagCollector => 'Connoisseur';

  @override
  String get badgeTagCollectorDesc => 'Used all four classic tags';

  @override
  String get badgeRegular => 'Regular';

  @override
  String get badgeRegularDesc => 'Logged on 14 different days';

  @override
  String get wrappedButton => 'Your year in wind';

  @override
  String wrappedTitle(int year) {
    return '$year, wrapped';
  }

  @override
  String wrappedTotal(int count) {
    return '$count toots';
  }

  @override
  String wrappedBestDay(int count) {
    return 'best day · $count';
  }

  @override
  String wrappedStreak(int days) {
    return 'longest streak · $days days';
  }

  @override
  String wrappedTopTag(String tag) {
    return 'signature move · $tag';
  }

  @override
  String get wrappedNoData => 'Nothing logged yet — your wind year starts now.';

  @override
  String get shareButton => 'Share';

  @override
  String get closeButton => 'Close';

  @override
  String shareCardStreakHeadline(int days) {
    return '$days days of dedication';
  }

  @override
  String get shareCardFooter => 'puff · every toot counts';

  @override
  String shareStreakText(int days) {
    return 'My $days-day streak on Puff. Every toot counts.';
  }

  @override
  String shareBadgeText(String badge) {
    return 'Just earned \"$badge\" on Puff. Every toot counts.';
  }

  @override
  String get shareWrappedText => 'My year in wind, by Puff.';

  @override
  String get proHeader => 'Puff Pro';

  @override
  String get goProButton => 'Go Pro';

  @override
  String get maybeLaterButton => 'Maybe later';

  @override
  String get paywallLead =>
      'Keep every day, see your patterns, back it all up.';

  @override
  String get paywallBenefitHistory => 'Unlimited history, synced to the cloud';

  @override
  String get paywallBenefitStats =>
      'Percentiles, heatmaps and weekday patterns';

  @override
  String get paywallBenefitBadges => 'The full badge collection';

  @override
  String get paywallBenefitSoon => 'Coming soon: the trigger food detective';

  @override
  String get paywallPrice =>
      '\$2.49 a month or \$17.99 a year — under \$1.50 a month.';

  @override
  String get paywallDevNote =>
      'Development build: purchases are simulated, no real charge.';

  @override
  String get purchaseSuccess => 'You\'re Pro. Gust salutes you.';

  @override
  String get purchaseFailed => 'That didn\'t go through. Try again?';

  @override
  String get proStatusActive => 'Pro — active';

  @override
  String get proStatusCanceled => 'Pro — canceled, runs until expiry';

  @override
  String proValidUntil(String date) {
    return 'valid until $date';
  }

  @override
  String get cancelProButton => 'Cancel subscription';

  @override
  String get cancelProConfirmTitle => 'Cancel Pro?';

  @override
  String get cancelProConfirmBody =>
      'Pro keeps working until the expiry date. Your data stays on this phone either way.';

  @override
  String get proCanceledMessage => 'Canceled. Pro runs until the expiry date.';

  @override
  String get accountHeader => 'Account';

  @override
  String get accountAnonymous => 'Anonymous — your data lives on this phone';

  @override
  String get accountUpgradeHint =>
      'Add an email so Pro and backups survive a lost phone.';

  @override
  String get createAccountButton => 'Create account';

  @override
  String get emailLabel => 'Email';

  @override
  String get passwordLabel => 'Password';

  @override
  String get emailInvalid => 'Enter a valid email';

  @override
  String get passwordTooShort => 'At least 8 characters';

  @override
  String get accountCreated => 'Account linked. Same you, safer data.';

  @override
  String accountEmail(String email) {
    return 'Signed in as $email';
  }

  @override
  String get accountUpgradeFailed =>
      'Couldn\'t link the account. Try again online.';

  @override
  String get syncNowButton => 'Sync now';

  @override
  String get syncDone => 'Synced.';

  @override
  String get restoreButton => 'Restore from cloud';

  @override
  String get restoreDone => 'History restored.';

  @override
  String get deleteAccountButton => 'Delete my cloud data';

  @override
  String get deleteConfirmTitle => 'Delete everything?';

  @override
  String get deleteConfirmBody =>
      'Cloud data and account: gone forever. Data on this phone stays unless you uninstall.';

  @override
  String get deleteDone => 'Cloud data deleted.';

  @override
  String get settingsHeader => 'Settings';

  @override
  String get themeSetting => 'Theme';

  @override
  String get themeSystem => 'System';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get soundSetting => 'Tap sound';

  @override
  String get soundSettingHint => 'One tasteful pop. Off by default.';

  @override
  String get diagnosticsSetting => 'Diagnostics';

  @override
  String get diagnosticsSettingHint =>
      'Errors the app caught quietly, kept for debugging';

  @override
  String get diagnosticsTitle => 'Diagnostics';

  @override
  String get diagnosticsIntro =>
      'When something fails quietly — a sync, a fetch, a crash — it lands here with its stack trace. Nothing in this log leaves your phone unless you share it.';

  @override
  String get diagnosticsEmpty => 'Squeaky clean — nothing has gone wrong yet.';

  @override
  String diagnosticsCount(int count) {
    return '$count recorded';
  }

  @override
  String diagnosticsCountTruncated(int total, int shown) {
    return '$total recorded · showing the newest $shown';
  }

  @override
  String get diagnosticsCopied => 'Copied to clipboard.';

  @override
  String get diagnosticsCleared => 'Log cleared.';

  @override
  String get diagnosticsShareText => 'Puff diagnostics log';

  @override
  String get copyButton => 'Copy';

  @override
  String get clearButton => 'Clear';

  @override
  String get privacyNote =>
      'Your log lives on this phone. World stats use one anonymous number a day — your daily count, nothing else. Cloud sync is Pro-only, and deleting your data is one tap.';

  @override
  String get errorNetwork =>
      'Couldn\'t reach the cloud. Everything still counts — it\'s saved on your phone.';
}
