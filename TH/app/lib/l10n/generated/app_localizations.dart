import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_th.dart';
import 'app_localizations_vi.dart';
import 'app_localizations_zh.dart';

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

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
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
    Locale('th'),
    Locale('vi'),
    Locale('zh'),
  ];

  /// No description provided for @h5CodeLogin.
  ///
  /// In en, this message translates to:
  /// **'Sign in with a web code'**
  String get h5CodeLogin;

  /// No description provided for @h5CodeHelp.
  ///
  /// In en, this message translates to:
  /// **'Enter the six-character code shown on the H5 report screen to sync that browser’s reports.'**
  String get h5CodeHelp;

  /// No description provided for @h5CodeField.
  ///
  /// In en, this message translates to:
  /// **'Web sign-in code'**
  String get h5CodeField;

  /// No description provided for @h5CodeInvalid.
  ///
  /// In en, this message translates to:
  /// **'This code is invalid, expired or already used. Get a new code on H5.'**
  String get h5CodeInvalid;

  /// No description provided for @h5CodeRateLimited.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Try again in a few minutes.'**
  String get h5CodeRateLimited;

  /// No description provided for @h5Account.
  ///
  /// In en, this message translates to:
  /// **'Web account'**
  String get h5Account;

  /// No description provided for @h5Reports.
  ///
  /// In en, this message translates to:
  /// **'Reports from H5'**
  String get h5Reports;

  /// No description provided for @h5ReportsEmpty.
  ///
  /// In en, this message translates to:
  /// **'This browser has no reports yet.'**
  String get h5ReportsEmpty;

  /// No description provided for @h5LoadMore.
  ///
  /// In en, this message translates to:
  /// **'Load older reports'**
  String get h5LoadMore;

  /// No description provided for @h5Refresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh reports'**
  String get h5Refresh;

  /// No description provided for @h5ReportUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This report could not be loaded. Refresh or view it on H5.'**
  String get h5ReportUnavailable;

  /// No description provided for @h5ReportQueued.
  ///
  /// In en, this message translates to:
  /// **'Unlocked · In queue'**
  String get h5ReportQueued;

  /// No description provided for @h5ReportGenerating.
  ///
  /// In en, this message translates to:
  /// **'Unlocked · Generating'**
  String get h5ReportGenerating;

  /// No description provided for @h5ReportLimited.
  ///
  /// In en, this message translates to:
  /// **'Unlocked · Generation limit reached'**
  String get h5ReportLimited;

  /// No description provided for @h5ReportIncomplete.
  ///
  /// In en, this message translates to:
  /// **'Unlocked · Report unfinished'**
  String get h5ReportIncomplete;

  /// No description provided for @h5ReportLimitedHelp.
  ///
  /// In en, this message translates to:
  /// **'Completed chapters are available. Return to the original web page to continue generating the report later.'**
  String get h5ReportLimitedHelp;

  /// No description provided for @h5Plan.
  ///
  /// In en, this message translates to:
  /// **'Action plan'**
  String get h5Plan;

  /// No description provided for @h5Insight.
  ///
  /// In en, this message translates to:
  /// **'Insights'**
  String get h5Insight;

  /// No description provided for @h5Watchpoint.
  ///
  /// In en, this message translates to:
  /// **'What to watch for'**
  String get h5Watchpoint;

  /// No description provided for @h5Example.
  ///
  /// In en, this message translates to:
  /// **'Everyday example'**
  String get h5Example;

  /// No description provided for @h5Pitfall.
  ///
  /// In en, this message translates to:
  /// **'What to avoid'**
  String get h5Pitfall;

  /// No description provided for @h5Check.
  ///
  /// In en, this message translates to:
  /// **'How to check your progress'**
  String get h5Check;

  /// No description provided for @actionTodo.
  ///
  /// In en, this message translates to:
  /// **'To do'**
  String get actionTodo;

  /// No description provided for @actionReviewAvailable.
  ///
  /// In en, this message translates to:
  /// **'Ready to review'**
  String get actionReviewAvailable;

  /// No description provided for @actionTypeService.
  ///
  /// In en, this message translates to:
  /// **'Help and share knowledge'**
  String get actionTypeService;

  /// No description provided for @actionTypePractice.
  ///
  /// In en, this message translates to:
  /// **'Personal practice'**
  String get actionTypePractice;

  /// No description provided for @actionCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get actionCompleted;

  /// No description provided for @newVisitorNote.
  ///
  /// In en, this message translates to:
  /// **'Choose a reader to begin'**
  String get newVisitorNote;

  /// No description provided for @returningVisitorNote.
  ///
  /// In en, this message translates to:
  /// **'Continue with a previous reading'**
  String get returningVisitorNote;

  /// No description provided for @todayTab.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get todayTab;

  /// No description provided for @actionTab.
  ///
  /// In en, this message translates to:
  /// **'Actions'**
  String get actionTab;

  /// No description provided for @liveTab.
  ///
  /// In en, this message translates to:
  /// **'Live'**
  String get liveTab;

  /// No description provided for @objectsTab.
  ///
  /// In en, this message translates to:
  /// **'Objects'**
  String get objectsTab;

  /// No description provided for @todayQuestion.
  ///
  /// In en, this message translates to:
  /// **'What would you like to explore today?'**
  String get todayQuestion;

  /// No description provided for @todayNote.
  ///
  /// In en, this message translates to:
  /// **'Three ways to find clarity'**
  String get todayNote;

  /// No description provided for @thaiGuide.
  ///
  /// In en, this message translates to:
  /// **'Thai astrology'**
  String get thaiGuide;

  /// No description provided for @sevenGuide.
  ///
  /// In en, this message translates to:
  /// **'Seven characters'**
  String get sevenGuide;

  /// No description provided for @tarotGuide.
  ///
  /// In en, this message translates to:
  /// **'Tarot reading'**
  String get tarotGuide;

  /// No description provided for @sirin.
  ///
  /// In en, this message translates to:
  /// **'Sirin'**
  String get sirin;

  /// No description provided for @arun.
  ///
  /// In en, this message translates to:
  /// **'Arun'**
  String get arun;

  /// No description provided for @mira.
  ///
  /// In en, this message translates to:
  /// **'Mira'**
  String get mira;

  /// No description provided for @sirinFocus.
  ///
  /// In en, this message translates to:
  /// **'Fortune · Year ahead'**
  String get sirinFocus;

  /// No description provided for @arunFocus.
  ///
  /// In en, this message translates to:
  /// **'Character · Life rhythms'**
  String get arunFocus;

  /// No description provided for @miraFocus.
  ///
  /// In en, this message translates to:
  /// **'The present · The next step'**
  String get miraFocus;

  /// No description provided for @sirinHint.
  ///
  /// In en, this message translates to:
  /// **'Explore your timing for the next step.'**
  String get sirinHint;

  /// No description provided for @arunHint.
  ///
  /// In en, this message translates to:
  /// **'Explore your rhythms through birth numbers.'**
  String get arunHint;

  /// No description provided for @miraHint.
  ///
  /// In en, this message translates to:
  /// **'Bring a question and see what the cards say.'**
  String get miraHint;

  /// No description provided for @startThaiGuide.
  ///
  /// In en, this message translates to:
  /// **'Enter birth details to begin'**
  String get startThaiGuide;

  /// No description provided for @viewThaiGuide.
  ///
  /// In en, this message translates to:
  /// **'View my Thai chart'**
  String get viewThaiGuide;

  /// No description provided for @startSevenGuide.
  ///
  /// In en, this message translates to:
  /// **'Preview seven-character readings'**
  String get startSevenGuide;

  /// No description provided for @startTarotGuide.
  ///
  /// In en, this message translates to:
  /// **'Start a tarot reading'**
  String get startTarotGuide;

  /// No description provided for @textReading.
  ///
  /// In en, this message translates to:
  /// **'Text reading'**
  String get textReading;

  /// No description provided for @textReadingNote.
  ///
  /// In en, this message translates to:
  /// **'Ask and keep talking'**
  String get textReadingNote;

  /// No description provided for @voiceReading.
  ///
  /// In en, this message translates to:
  /// **'Voice chat'**
  String get voiceReading;

  /// No description provided for @voiceReadingNote.
  ///
  /// In en, this message translates to:
  /// **'Talk through your question'**
  String get voiceReadingNote;

  /// No description provided for @textChat.
  ///
  /// In en, this message translates to:
  /// **'Text chat'**
  String get textChat;

  /// No description provided for @voiceChat.
  ///
  /// In en, this message translates to:
  /// **'Voice chat'**
  String get voiceChat;

  /// No description provided for @voicePreviewNotice.
  ///
  /// In en, this message translates to:
  /// **'Voice chat is unavailable in this preview. You can continue by text.'**
  String get voicePreviewNotice;

  /// No description provided for @guideChatHeading.
  ///
  /// In en, this message translates to:
  /// **'Talk it through with {name}'**
  String guideChatHeading(String name);

  /// No description provided for @startReading.
  ///
  /// In en, this message translates to:
  /// **'Start reading'**
  String get startReading;

  /// No description provided for @guideChatDemo.
  ///
  /// In en, this message translates to:
  /// **'Demo chat · Replies and history stay on this device'**
  String get guideChatDemo;

  /// No description provided for @guideGreeting.
  ///
  /// In en, this message translates to:
  /// **'What’s on your mind today?'**
  String get guideGreeting;

  /// No description provided for @guidePromptWork.
  ///
  /// In en, this message translates to:
  /// **'I feel unsure about work'**
  String get guidePromptWork;

  /// No description provided for @guidePromptLove.
  ///
  /// In en, this message translates to:
  /// **'Should I take the lead in my relationship?'**
  String get guidePromptLove;

  /// No description provided for @guideWorkReply.
  ///
  /// In en, this message translates to:
  /// **'Separate what you know from what you’re waiting for. What could you clarify this week?'**
  String get guideWorkReply;

  /// No description provided for @guideLoveReply.
  ///
  /// In en, this message translates to:
  /// **'What would you like the other person to know? Start with a simple hello and notice how you feel.'**
  String get guideLoveReply;

  /// No description provided for @guideReflectReply.
  ///
  /// In en, this message translates to:
  /// **'Think about what you can control in “{question}”. What’s one thing you could do in ten minutes?'**
  String guideReflectReply(String question);

  /// No description provided for @continueSample.
  ///
  /// In en, this message translates to:
  /// **'Continue with your example reading'**
  String get continueSample;

  /// No description provided for @readingSampleQuestion.
  ///
  /// In en, this message translates to:
  /// **'I’m waiting to hear back about work. What can I do this week?'**
  String get readingSampleQuestion;

  /// No description provided for @readingSampleLove.
  ///
  /// In en, this message translates to:
  /// **'What’s the next step in this relationship?'**
  String get readingSampleLove;

  /// No description provided for @readingSampleLife.
  ///
  /// In en, this message translates to:
  /// **'My routine changed. Where should I start?'**
  String get readingSampleLife;

  /// No description provided for @recoverReports.
  ///
  /// In en, this message translates to:
  /// **'My reports'**
  String get recoverReports;

  /// No description provided for @recentReadings.
  ///
  /// In en, this message translates to:
  /// **'Recent readings'**
  String get recentReadings;

  /// No description provided for @reportLookup.
  ///
  /// In en, this message translates to:
  /// **'Report link or code'**
  String get reportLookup;

  /// No description provided for @findReport.
  ///
  /// In en, this message translates to:
  /// **'Look up'**
  String get findReport;

  /// No description provided for @reportLookupDemo.
  ///
  /// In en, this message translates to:
  /// **'Use an example code here. Personal reports are in your report library.'**
  String get reportLookupDemo;

  /// No description provided for @reportCodeMissing.
  ///
  /// In en, this message translates to:
  /// **'Example not found. Try FATE-THAI-001.'**
  String get reportCodeMissing;

  /// No description provided for @newVisitor.
  ///
  /// In en, this message translates to:
  /// **'I’m new here'**
  String get newVisitor;

  /// No description provided for @returningVisitor.
  ///
  /// In en, this message translates to:
  /// **'I’m returning'**
  String get returningVisitor;

  /// No description provided for @guideWelcomeLabel.
  ///
  /// In en, this message translates to:
  /// **'Three readers · Three traditions'**
  String get guideWelcomeLabel;

  /// No description provided for @guideWelcomeTitle.
  ///
  /// In en, this message translates to:
  /// **'A conversation\nwith destiny.'**
  String get guideWelcomeTitle;

  /// No description provided for @guideWelcomeNote.
  ///
  /// In en, this message translates to:
  /// **'Start with one question and see where you stand.'**
  String get guideWelcomeNote;

  /// No description provided for @onAirNow.
  ///
  /// In en, this message translates to:
  /// **'On air now'**
  String get onAirNow;

  /// No description provided for @demo.
  ///
  /// In en, this message translates to:
  /// **'Demo'**
  String get demo;

  /// No description provided for @allItems.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get allItems;

  /// No description provided for @templeRoom.
  ///
  /// In en, this message translates to:
  /// **'Temple blessing'**
  String get templeRoom;

  /// No description provided for @templeTeaser.
  ///
  /// In en, this message translates to:
  /// **'Temple ceremony'**
  String get templeTeaser;

  /// No description provided for @objectsRoom.
  ///
  /// In en, this message translates to:
  /// **'Objects unboxing'**
  String get objectsRoom;

  /// No description provided for @templeTeaserNote.
  ///
  /// In en, this message translates to:
  /// **'Watch the ritual'**
  String get templeTeaserNote;

  /// No description provided for @objectsTeaserNote.
  ///
  /// In en, this message translates to:
  /// **'See how it’s used'**
  String get objectsTeaserNote;

  /// No description provided for @templeRoomNote.
  ///
  /// In en, this message translates to:
  /// **'Partner Temple A · Example'**
  String get templeRoomNote;

  /// No description provided for @switchRoom.
  ///
  /// In en, this message translates to:
  /// **'Switch room'**
  String get switchRoom;

  /// No description provided for @templePosterTitle.
  ///
  /// In en, this message translates to:
  /// **'One wish,\none special encounter'**
  String get templePosterTitle;

  /// No description provided for @objectsPosterTitle.
  ///
  /// In en, this message translates to:
  /// **'Bring a little intention\ninto every day'**
  String get objectsPosterTitle;

  /// No description provided for @liveDemoNotice.
  ///
  /// In en, this message translates to:
  /// **'Live preview · Illustrative scenes'**
  String get liveDemoNotice;

  /// No description provided for @livestreamPause.
  ///
  /// In en, this message translates to:
  /// **'Pause preview'**
  String get livestreamPause;

  /// No description provided for @livestreamPlay.
  ///
  /// In en, this message translates to:
  /// **'Play preview'**
  String get livestreamPlay;

  /// No description provided for @fullScreenPreview.
  ///
  /// In en, this message translates to:
  /// **'Enlarge preview'**
  String get fullScreenPreview;

  /// No description provided for @templeRoomHeading.
  ///
  /// In en, this message translates to:
  /// **'Bring your wish to the temple'**
  String get templeRoomHeading;

  /// No description provided for @templeService.
  ///
  /// In en, this message translates to:
  /// **'Personal blessing'**
  String get templeService;

  /// No description provided for @samplePrice.
  ///
  /// In en, this message translates to:
  /// **'Sample price'**
  String get samplePrice;

  /// No description provided for @bookingInfo.
  ///
  /// In en, this message translates to:
  /// **'Booking information'**
  String get bookingInfo;

  /// No description provided for @bookingDemoNotice.
  ///
  /// In en, this message translates to:
  /// **'Preview the ceremony and booking steps. Actual dates are pending.'**
  String get bookingDemoNotice;

  /// No description provided for @roomChat.
  ///
  /// In en, this message translates to:
  /// **'Room chat'**
  String get roomChat;

  /// No description provided for @ceremonyInfo.
  ///
  /// In en, this message translates to:
  /// **'About the ceremony'**
  String get ceremonyInfo;

  /// No description provided for @roomObjectsInfo.
  ///
  /// In en, this message translates to:
  /// **'Featured objects'**
  String get roomObjectsInfo;

  /// No description provided for @roomWelcomeDemo.
  ///
  /// In en, this message translates to:
  /// **'Host · Demo    Welcome. Take a look at the room details below.'**
  String get roomWelcomeDemo;

  /// No description provided for @templeSegmentOne.
  ///
  /// In en, this message translates to:
  /// **'Write down your wish'**
  String get templeSegmentOne;

  /// No description provided for @templeSegmentTwo.
  ///
  /// In en, this message translates to:
  /// **'Learn about the blessing ritual'**
  String get templeSegmentTwo;

  /// No description provided for @templeSegmentThree.
  ///
  /// In en, this message translates to:
  /// **'Keep a record of your wish'**
  String get templeSegmentThree;

  /// No description provided for @roomMessageHint.
  ///
  /// In en, this message translates to:
  /// **'Try a local chat message'**
  String get roomMessageHint;

  /// No description provided for @myActions.
  ///
  /// In en, this message translates to:
  /// **'My actions'**
  String get myActions;

  /// No description provided for @actionPending.
  ///
  /// In en, this message translates to:
  /// **'To do'**
  String get actionPending;

  /// No description provided for @actionDone.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get actionDone;

  /// No description provided for @actionReady.
  ///
  /// In en, this message translates to:
  /// **'Ready to review'**
  String get actionReady;

  /// No description provided for @chooseFamilyAction.
  ///
  /// In en, this message translates to:
  /// **'Plan a day for family'**
  String get chooseFamilyAction;

  /// No description provided for @weeklyMoment.
  ///
  /// In en, this message translates to:
  /// **'Set aside a day for action'**
  String get weeklyMoment;

  /// No description provided for @weeklyMomentNote.
  ///
  /// In en, this message translates to:
  /// **'Pick one day a week for a few small acts. Keep it flexible.'**
  String get weeklyMomentNote;

  /// No description provided for @myWeeklyDay.
  ///
  /// In en, this message translates to:
  /// **'My action day'**
  String get myWeeklyDay;

  /// No description provided for @arrangeDay.
  ///
  /// In en, this message translates to:
  /// **'Set a day'**
  String get arrangeDay;

  /// No description provided for @actionLedger.
  ///
  /// In en, this message translates to:
  /// **'My action journal'**
  String get actionLedger;

  /// No description provided for @actionDailySuggestion.
  ///
  /// In en, this message translates to:
  /// **'Today\'s suggestion'**
  String get actionDailySuggestion;

  /// No description provided for @actionUseSuggestion.
  ///
  /// In en, this message translates to:
  /// **'Add this'**
  String get actionUseSuggestion;

  /// No description provided for @actionCustomPlan.
  ///
  /// In en, this message translates to:
  /// **'Set my own action'**
  String get actionCustomPlan;

  /// No description provided for @actionCompleteNow.
  ///
  /// In en, this message translates to:
  /// **'Mark done'**
  String get actionCompleteNow;

  /// No description provided for @actionSuggestionThanks.
  ///
  /// In en, this message translates to:
  /// **'Send a thank-you to someone who helped you'**
  String get actionSuggestionThanks;

  /// No description provided for @actionSuggestionCheckIn.
  ///
  /// In en, this message translates to:
  /// **'Check in with a friend'**
  String get actionSuggestionCheckIn;

  /// No description provided for @actionSuggestionShare.
  ///
  /// In en, this message translates to:
  /// **'Share something useful with someone'**
  String get actionSuggestionShare;

  /// No description provided for @offeringEnergy.
  ///
  /// In en, this message translates to:
  /// **'Action energy'**
  String get offeringEnergy;

  /// No description provided for @offeringJasmine.
  ///
  /// In en, this message translates to:
  /// **'Jasmine garland'**
  String get offeringJasmine;

  /// No description provided for @offeringLotus.
  ///
  /// In en, this message translates to:
  /// **'Lotus offering'**
  String get offeringLotus;

  /// No description provided for @offeringMarigold.
  ///
  /// In en, this message translates to:
  /// **'Marigold garland'**
  String get offeringMarigold;

  /// No description provided for @offeringCollected.
  ///
  /// In en, this message translates to:
  /// **'Collected {count}'**
  String offeringCollected(int count);

  /// No description provided for @offeringPerAction.
  ///
  /// In en, this message translates to:
  /// **'Complete an action to add {points} energy.'**
  String offeringPerAction(int points);

  /// No description provided for @offeringPresenting.
  ///
  /// In en, this message translates to:
  /// **'Presenting your offering…'**
  String get offeringPresenting;

  /// No description provided for @offeringComplete.
  ///
  /// In en, this message translates to:
  /// **'Offering presented'**
  String get offeringComplete;

  /// No description provided for @offeringBlessing.
  ///
  /// In en, this message translates to:
  /// **'May your good deeds lift you up. May good fortune stay with you, and may your hopes come true.'**
  String get offeringBlessing;

  /// No description provided for @offeringNext.
  ///
  /// In en, this message translates to:
  /// **'Your next action starts a new offering.'**
  String get offeringNext;

  /// No description provided for @newPlan.
  ///
  /// In en, this message translates to:
  /// **'New plan'**
  String get newPlan;

  /// No description provided for @noActionPlan.
  ///
  /// In en, this message translates to:
  /// **'The small things you choose to do will appear here.'**
  String get noActionPlan;

  /// No description provided for @actionRecord.
  ///
  /// In en, this message translates to:
  /// **'My action record'**
  String get actionRecord;

  /// No description provided for @actionTitle.
  ///
  /// In en, this message translates to:
  /// **'What I want to do'**
  String get actionTitle;

  /// No description provided for @careAction.
  ///
  /// In en, this message translates to:
  /// **'Give someone a helping hand'**
  String get careAction;

  /// No description provided for @familyAction.
  ///
  /// In en, this message translates to:
  /// **'Do a few small things for family'**
  String get familyAction;

  /// No description provided for @actionCategory.
  ///
  /// In en, this message translates to:
  /// **'Action type'**
  String get actionCategory;

  /// No description provided for @beneficiary.
  ///
  /// In en, this message translates to:
  /// **'Who it’s for'**
  String get beneficiary;

  /// No description provided for @forSelf.
  ///
  /// In en, this message translates to:
  /// **'Myself'**
  String get forSelf;

  /// No description provided for @forOthers.
  ///
  /// In en, this message translates to:
  /// **'Someone nearby'**
  String get forOthers;

  /// No description provided for @forFamily.
  ///
  /// In en, this message translates to:
  /// **'Family'**
  String get forFamily;

  /// No description provided for @recordMethod.
  ///
  /// In en, this message translates to:
  /// **'Recording method'**
  String get recordMethod;

  /// No description provided for @recordOnDevice.
  ///
  /// In en, this message translates to:
  /// **'Notes on this device'**
  String get recordOnDevice;

  /// No description provided for @actionDate.
  ///
  /// In en, this message translates to:
  /// **'Action date'**
  String get actionDate;

  /// No description provided for @reviewDate.
  ///
  /// In en, this message translates to:
  /// **'Review date'**
  String get reviewDate;

  /// No description provided for @actionNotes.
  ///
  /// In en, this message translates to:
  /// **'What I did'**
  String get actionNotes;

  /// No description provided for @actionReview.
  ///
  /// In en, this message translates to:
  /// **'My reflection on this action'**
  String get actionReview;

  /// No description provided for @questionProgress.
  ///
  /// In en, this message translates to:
  /// **'What changed about the original question?'**
  String get questionProgress;

  /// No description provided for @actionReviewed.
  ///
  /// In en, this message translates to:
  /// **'Reviewed'**
  String get actionReviewed;

  /// No description provided for @recordAction.
  ///
  /// In en, this message translates to:
  /// **'Save a small action'**
  String get recordAction;

  /// No description provided for @clearPrototypeRecords.
  ///
  /// In en, this message translates to:
  /// **'Clear local actions and demo chats'**
  String get clearPrototypeRecords;

  /// No description provided for @storeTitle.
  ///
  /// In en, this message translates to:
  /// **'Objects with intention'**
  String get storeTitle;

  /// No description provided for @storeIntro.
  ///
  /// In en, this message translates to:
  /// **'Bring the things you love into everyday life.'**
  String get storeIntro;

  /// No description provided for @storeSearch.
  ///
  /// In en, this message translates to:
  /// **'Search journals, scents, jewelry…'**
  String get storeSearch;

  /// No description provided for @scentCategory.
  ///
  /// In en, this message translates to:
  /// **'Fragrance'**
  String get scentCategory;

  /// No description provided for @jewelryCategory.
  ///
  /// In en, this message translates to:
  /// **'Jewelry'**
  String get jewelryCategory;

  /// No description provided for @journalCategory.
  ///
  /// In en, this message translates to:
  /// **'Journals'**
  String get journalCategory;

  /// No description provided for @lifeCategory.
  ///
  /// In en, this message translates to:
  /// **'Living'**
  String get lifeCategory;

  /// No description provided for @sampleCatalog.
  ///
  /// In en, this message translates to:
  /// **'Sample catalog'**
  String get sampleCatalog;

  /// No description provided for @objectJournal.
  ///
  /// In en, this message translates to:
  /// **'Action journal'**
  String get objectJournal;

  /// No description provided for @objectCandle.
  ///
  /// In en, this message translates to:
  /// **'Evening candle'**
  String get objectCandle;

  /// No description provided for @objectBracelet.
  ///
  /// In en, this message translates to:
  /// **'Wish bracelet'**
  String get objectBracelet;

  /// No description provided for @objectDiffuser.
  ///
  /// In en, this message translates to:
  /// **'Morning diffuser'**
  String get objectDiffuser;

  /// No description provided for @objectJournalNote.
  ///
  /// In en, this message translates to:
  /// **'Turn a wish into a next step'**
  String get objectJournalNote;

  /// No description provided for @objectCandleNote.
  ///
  /// In en, this message translates to:
  /// **'Give yourself a quiet moment'**
  String get objectCandleNote;

  /// No description provided for @objectBraceletNote.
  ///
  /// In en, this message translates to:
  /// **'Carry a little wish with you'**
  String get objectBraceletNote;

  /// No description provided for @objectDiffuserNote.
  ///
  /// In en, this message translates to:
  /// **'Start the day with a familiar scent'**
  String get objectDiffuserNote;

  /// No description provided for @shopOrders.
  ///
  /// In en, this message translates to:
  /// **'My orders'**
  String get shopOrders;

  /// No description provided for @shopCart.
  ///
  /// In en, this message translates to:
  /// **'Cart'**
  String get shopCart;

  /// No description provided for @addToCart.
  ///
  /// In en, this message translates to:
  /// **'Add to cart'**
  String get addToCart;

  /// No description provided for @cartEmpty.
  ///
  /// In en, this message translates to:
  /// **'Your cart is empty'**
  String get cartEmpty;

  /// No description provided for @shopEmpty.
  ///
  /// In en, this message translates to:
  /// **'No matching objects'**
  String get shopEmpty;

  /// No description provided for @shopOrdersEmpty.
  ///
  /// In en, this message translates to:
  /// **'No object orders yet'**
  String get shopOrdersEmpty;

  /// No description provided for @shopDemoNotice.
  ///
  /// In en, this message translates to:
  /// **'This sample shop is browsing-only. Orders are unavailable.'**
  String get shopDemoNotice;

  /// No description provided for @mySpace.
  ///
  /// In en, this message translates to:
  /// **'My readings and records'**
  String get mySpace;

  /// No description provided for @mySpaceIntro.
  ///
  /// In en, this message translates to:
  /// **'Find your reports, actions, and plans here.'**
  String get mySpaceIntro;

  /// No description provided for @actionsAndReviews.
  ///
  /// In en, this message translates to:
  /// **'Actions & review'**
  String get actionsAndReviews;

  /// No description provided for @resumeCompanion.
  ///
  /// In en, this message translates to:
  /// **'Continue your conversation'**
  String get resumeCompanion;

  /// No description provided for @fortunePeriods.
  ///
  /// In en, this message translates to:
  /// **'Today, week, month & year outlook'**
  String get fortunePeriods;

  /// No description provided for @thaiChartIntro.
  ///
  /// In en, this message translates to:
  /// **'See the Thai chart for your birth date, time, and place.'**
  String get thaiChartIntro;

  /// No description provided for @sevenPreviewNote.
  ///
  /// In en, this message translates to:
  /// **'Seven-character calculations are unavailable in this preview. Try a demo conversation with Arun.'**
  String get sevenPreviewNote;

  /// No description provided for @country.
  ///
  /// In en, this message translates to:
  /// **'Country / region'**
  String get country;

  /// No description provided for @countryTH.
  ///
  /// In en, this message translates to:
  /// **'Thailand'**
  String get countryTH;

  /// No description provided for @countryCN.
  ///
  /// In en, this message translates to:
  /// **'China'**
  String get countryCN;

  /// No description provided for @countryVN.
  ///
  /// In en, this message translates to:
  /// **'Vietnam'**
  String get countryVN;

  /// No description provided for @countryUS.
  ///
  /// In en, this message translates to:
  /// **'United States'**
  String get countryUS;

  /// No description provided for @noCityResults.
  ///
  /// In en, this message translates to:
  /// **'No matching city. Try another name, or return to enter the place and timezone manually.'**
  String get noCityResults;

  /// No description provided for @retryPurchase.
  ///
  /// In en, this message translates to:
  /// **'Retry purchase verification'**
  String get retryPurchase;

  /// No description provided for @sampleLoveText.
  ///
  /// In en, this message translates to:
  /// **'Mercury square Mars in this example invites a look at differences between speaking and acting. You may already have a solution while someone else still needs to feel understood. Reflect their concern first, then ask whether they want listening or suggestions.'**
  String get sampleLoveText;

  /// No description provided for @sampleLoveAction.
  ///
  /// In en, this message translates to:
  /// **'During the next disagreement, try: “I hear that you are concerned about… Have I understood?” Wait for confirmation, discuss one issue at a time, and agree who will do what and when to check in.'**
  String get sampleLoveAction;

  /// No description provided for @sampleWorkText.
  ///
  /// In en, this message translates to:
  /// **'The Sun opposite Saturn in this example invites reflection on initiative and responsibility. Wanting to do well can make feedback feel like a verdict on your ability. Turn feedback into specific tasks you can change, rather than a judgment of yourself.'**
  String get sampleWorkText;

  /// No description provided for @sampleWorkAction.
  ///
  /// In en, this message translates to:
  /// **'Before starting, write the deliverable, deadline and reviewer. At the first review, ask for the two most useful changes. Record what improved after editing, so progress is based on completed work as well as recognition.'**
  String get sampleWorkAction;

  /// No description provided for @sampleMoneyText.
  ///
  /// In en, this message translates to:
  /// **'Venus trine Neptune in this example invites reflection on beauty, experiences and an ideal lifestyle. Before buying, separate a practical use from the lifestyle you imagine it represents. This section concerns spending habits, not market or return forecasts.'**
  String get sampleMoneyText;

  /// No description provided for @sampleMoneyAction.
  ///
  /// In en, this message translates to:
  /// **'Save an unplanned purchase without checking out. The next day, write its purpose, likely frequency of use and your remaining monthly budget. Agree how shared costs will be split before paying.'**
  String get sampleMoneyAction;

  /// No description provided for @sunMeaning.
  ///
  /// In en, this message translates to:
  /// **'The Sun represents how you express yourself and what gives you a sense of purpose.'**
  String get sunMeaning;

  /// No description provided for @moonMeaning.
  ///
  /// In en, this message translates to:
  /// **'The Moon represents emotional needs and what helps you feel secure.'**
  String get moonMeaning;

  /// No description provided for @mercuryMeaning.
  ///
  /// In en, this message translates to:
  /// **'Mercury represents habits of thinking, learning and communication.'**
  String get mercuryMeaning;

  /// No description provided for @venusMeaning.
  ///
  /// In en, this message translates to:
  /// **'Venus represents what you appreciate and how you express affection and build relationships.'**
  String get venusMeaning;

  /// No description provided for @marsMeaning.
  ///
  /// In en, this message translates to:
  /// **'Mars represents how you take action, pursue goals and handle disagreement.'**
  String get marsMeaning;

  /// No description provided for @jupiterMeaning.
  ///
  /// In en, this message translates to:
  /// **'Jupiter represents learning, exploring opportunities and widening your perspective.'**
  String get jupiterMeaning;

  /// No description provided for @saturnMeaning.
  ///
  /// In en, this message translates to:
  /// **'Saturn represents responsibility, boundaries and skills developed over time.'**
  String get saturnMeaning;

  /// No description provided for @uranusMeaning.
  ///
  /// In en, this message translates to:
  /// **'Uranus represents changing old habits and trying independent approaches.'**
  String get uranusMeaning;

  /// No description provided for @neptuneMeaning.
  ///
  /// In en, this message translates to:
  /// **'Neptune represents imagination, ideals and separating expectations from reality.'**
  String get neptuneMeaning;

  /// No description provided for @plutoMeaning.
  ///
  /// In en, this message translates to:
  /// **'Pluto represents deep change, control and rebuilding a sense of strength.'**
  String get plutoMeaning;

  /// No description provided for @home.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// No description provided for @chart.
  ///
  /// In en, this message translates to:
  /// **'Chart'**
  String get chart;

  /// No description provided for @reports.
  ///
  /// In en, this message translates to:
  /// **'Reports'**
  String get reports;

  /// No description provided for @mine.
  ///
  /// In en, this message translates to:
  /// **'My space'**
  String get mine;

  /// No description provided for @system.
  ///
  /// In en, this message translates to:
  /// **'Western astrology'**
  String get system;

  /// No description provided for @heroTitle.
  ///
  /// In en, this message translates to:
  /// **'Read the stars.\nUnderstand yourself.'**
  String get heroTitle;

  /// No description provided for @heroText.
  ///
  /// In en, this message translates to:
  /// **'Explore personality, relationships, and direction through your birth moment.'**
  String get heroText;

  /// No description provided for @heroBadge.
  ///
  /// In en, this message translates to:
  /// **'Your own celestial story'**
  String get heroBadge;

  /// No description provided for @start.
  ///
  /// In en, this message translates to:
  /// **'Start my birth chart'**
  String get start;

  /// No description provided for @birth.
  ///
  /// In en, this message translates to:
  /// **'Birth details'**
  String get birth;

  /// No description provided for @birthNote.
  ///
  /// In en, this message translates to:
  /// **'Your place and moment in time'**
  String get birthNote;

  /// No description provided for @birthIntro.
  ///
  /// In en, this message translates to:
  /// **'Your date, time, and location help determine planets, the ascendant, and houses. You can edit them anytime.'**
  String get birthIntro;

  /// No description provided for @chartNote.
  ///
  /// In en, this message translates to:
  /// **'Planets · Signs · Houses'**
  String get chartNote;

  /// No description provided for @reportNote.
  ///
  /// In en, this message translates to:
  /// **'Personality · Relationships · Work'**
  String get reportNote;

  /// No description provided for @fullReport.
  ///
  /// In en, this message translates to:
  /// **'Full reading'**
  String get fullReport;

  /// No description provided for @fullNote.
  ///
  /// In en, this message translates to:
  /// **'Practical advice and next steps'**
  String get fullNote;

  /// No description provided for @homeReportTitle.
  ///
  /// In en, this message translates to:
  /// **'A reading about you'**
  String get homeReportTitle;

  /// No description provided for @homeReportText.
  ///
  /// In en, this message translates to:
  /// **'Understand your patterns, then explore choices in relationships, work, and money habits.'**
  String get homeReportText;

  /// No description provided for @viewReport.
  ///
  /// In en, this message translates to:
  /// **'Explore my reading'**
  String get viewReport;

  /// No description provided for @journey.
  ///
  /// In en, this message translates to:
  /// **'Your exploration starts here'**
  String get journey;

  /// No description provided for @stepBirth.
  ///
  /// In en, this message translates to:
  /// **'Add birth details'**
  String get stepBirth;

  /// No description provided for @stepChart.
  ///
  /// In en, this message translates to:
  /// **'Meet your birth chart'**
  String get stepChart;

  /// No description provided for @stepReport.
  ///
  /// In en, this message translates to:
  /// **'Read your interpretation'**
  String get stepReport;

  /// No description provided for @example.
  ///
  /// In en, this message translates to:
  /// **'View example chart'**
  String get example;

  /// No description provided for @exampleReport.
  ///
  /// In en, this message translates to:
  /// **'View example report'**
  String get exampleReport;

  /// No description provided for @exampleBadge.
  ///
  /// In en, this message translates to:
  /// **'Teaching example'**
  String get exampleBadge;

  /// No description provided for @exampleNote.
  ///
  /// In en, this message translates to:
  /// **'This demonstrates the reading experience. It is not calculated from your birth details.'**
  String get exampleNote;

  /// No description provided for @myChart.
  ///
  /// In en, this message translates to:
  /// **'My birth chart'**
  String get myChart;

  /// No description provided for @myChartText.
  ///
  /// In en, this message translates to:
  /// **'Make your chart easier to understand.'**
  String get myChartText;

  /// No description provided for @noChart.
  ///
  /// In en, this message translates to:
  /// **'Your chart starts with you'**
  String get noChart;

  /// No description provided for @noChartText.
  ///
  /// In en, this message translates to:
  /// **'Add birth details to explore your planets, signs, and houses.'**
  String get noChartText;

  /// No description provided for @waiting.
  ///
  /// In en, this message translates to:
  /// **'Preparing your chart'**
  String get waiting;

  /// No description provided for @unavailable.
  ///
  /// In en, this message translates to:
  /// **'Western chart service is not ready'**
  String get unavailable;

  /// No description provided for @unavailableText.
  ///
  /// In en, this message translates to:
  /// **'Your birth details are saved on this device. Explore an example, or request your result again later.'**
  String get unavailableText;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Request my chart again'**
  String get retry;

  /// No description provided for @editBirth.
  ///
  /// In en, this message translates to:
  /// **'Edit birth details'**
  String get editBirth;

  /// No description provided for @sun.
  ///
  /// In en, this message translates to:
  /// **'Sun'**
  String get sun;

  /// No description provided for @moon.
  ///
  /// In en, this message translates to:
  /// **'Moon'**
  String get moon;

  /// No description provided for @ascendant.
  ///
  /// In en, this message translates to:
  /// **'Ascendant'**
  String get ascendant;

  /// No description provided for @planets.
  ///
  /// In en, this message translates to:
  /// **'Planet positions'**
  String get planets;

  /// No description provided for @houses.
  ///
  /// In en, this message translates to:
  /// **'Twelve houses'**
  String get houses;

  /// No description provided for @aspects.
  ///
  /// In en, this message translates to:
  /// **'Major aspects'**
  String get aspects;

  /// No description provided for @planetHint.
  ///
  /// In en, this message translates to:
  /// **'Tap a planet to explore its role in the chart.'**
  String get planetHint;

  /// No description provided for @unknownTime.
  ///
  /// In en, this message translates to:
  /// **'Without a birth time, an estimated chart uses 12:00 local time at your birthplace. You can add your time later.'**
  String get unknownTime;

  /// No description provided for @chartRead.
  ///
  /// In en, this message translates to:
  /// **'Full reading'**
  String get chartRead;

  /// No description provided for @house.
  ///
  /// In en, this message translates to:
  /// **'House'**
  String get house;

  /// No description provided for @emptyValue.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get emptyValue;

  /// No description provided for @reportTitle.
  ///
  /// In en, this message translates to:
  /// **'Personal birth report'**
  String get reportTitle;

  /// No description provided for @reportIntro.
  ///
  /// In en, this message translates to:
  /// **'From your overall patterns to practical choices, explore one step at a time.'**
  String get reportIntro;

  /// No description provided for @free.
  ///
  /// In en, this message translates to:
  /// **'Free preview'**
  String get free;

  /// No description provided for @premium.
  ///
  /// In en, this message translates to:
  /// **'Full reading'**
  String get premium;

  /// No description provided for @reportEmpty.
  ///
  /// In en, this message translates to:
  /// **'Your readings will live here'**
  String get reportEmpty;

  /// No description provided for @reportEmptyText.
  ///
  /// In en, this message translates to:
  /// **'Create a personal birth chart to see its reading and report status.'**
  String get reportEmptyText;

  /// No description provided for @generate.
  ///
  /// In en, this message translates to:
  /// **'Create my report'**
  String get generate;

  /// No description provided for @summary.
  ///
  /// In en, this message translates to:
  /// **'Start with the takeaway'**
  String get summary;

  /// No description provided for @traits.
  ///
  /// In en, this message translates to:
  /// **'Patterns you may recognize'**
  String get traits;

  /// No description provided for @watch.
  ///
  /// In en, this message translates to:
  /// **'What to watch for'**
  String get watch;

  /// No description provided for @advice.
  ///
  /// In en, this message translates to:
  /// **'Steps you can try'**
  String get advice;

  /// No description provided for @reportScope.
  ///
  /// In en, this message translates to:
  /// **'Inside this report'**
  String get reportScope;

  /// No description provided for @chapterPersonality.
  ///
  /// In en, this message translates to:
  /// **'Personality and expression'**
  String get chapterPersonality;

  /// No description provided for @chapterLove.
  ///
  /// In en, this message translates to:
  /// **'Relationships and communication'**
  String get chapterLove;

  /// No description provided for @chapterWork.
  ///
  /// In en, this message translates to:
  /// **'Work and growth'**
  String get chapterWork;

  /// No description provided for @chapterMoney.
  ///
  /// In en, this message translates to:
  /// **'Money habits'**
  String get chapterMoney;

  /// No description provided for @reportSaved.
  ///
  /// In en, this message translates to:
  /// **'Example saved'**
  String get reportSaved;

  /// No description provided for @saveReport.
  ///
  /// In en, this message translates to:
  /// **'Save example'**
  String get saveReport;

  /// No description provided for @savedReports.
  ///
  /// In en, this message translates to:
  /// **'Examples saved on this device'**
  String get savedReports;

  /// No description provided for @openReport.
  ///
  /// In en, this message translates to:
  /// **'Open report'**
  String get openReport;

  /// No description provided for @remove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get remove;

  /// No description provided for @exampleSavedNote.
  ///
  /// In en, this message translates to:
  /// **'Examples are stored separately from personal reports and never become your calculation results.'**
  String get exampleSavedNote;

  /// No description provided for @unlock.
  ///
  /// In en, this message translates to:
  /// **'Read the full interpretation'**
  String get unlock;

  /// No description provided for @lockedTitle.
  ///
  /// In en, this message translates to:
  /// **'Explore your chart further'**
  String get lockedTitle;

  /// No description provided for @lockedText.
  ///
  /// In en, this message translates to:
  /// **'The full reading includes specific watch points, everyday examples, and practical steps.'**
  String get lockedText;

  /// No description provided for @offerTitle.
  ///
  /// In en, this message translates to:
  /// **'Unlock your birth report'**
  String get offerTitle;

  /// No description provided for @offerText.
  ///
  /// In en, this message translates to:
  /// **'A one-time purchase for the full report within the product\'s scope.'**
  String get offerText;

  /// No description provided for @offerFeature1.
  ///
  /// In en, this message translates to:
  /// **'Personal patterns and four life topics'**
  String get offerFeature1;

  /// No description provided for @offerFeature2.
  ///
  /// In en, this message translates to:
  /// **'Watch points, examples, and practical advice'**
  String get offerFeature2;

  /// No description provided for @offerFeature3.
  ///
  /// In en, this message translates to:
  /// **'Revisit reports and restore purchases'**
  String get offerFeature3;

  /// No description provided for @appleBuy.
  ///
  /// In en, this message translates to:
  /// **'Purchase in the iOS app'**
  String get appleBuy;

  /// No description provided for @pricePending.
  ///
  /// In en, this message translates to:
  /// **'Price is provided by the App Store'**
  String get pricePending;

  /// No description provided for @purchasePreview.
  ///
  /// In en, this message translates to:
  /// **'This is a browser preview. Apple purchases are unavailable and no payment will be taken.'**
  String get purchasePreview;

  /// No description provided for @restore.
  ///
  /// In en, this message translates to:
  /// **'Restore purchases'**
  String get restore;

  /// No description provided for @restoreNote.
  ///
  /// In en, this message translates to:
  /// **'Restore in the iOS app with your original purchasing account. This browser cannot read Apple transactions.'**
  String get restoreNote;

  /// No description provided for @previewFull.
  ///
  /// In en, this message translates to:
  /// **'Preview the full example'**
  String get previewFull;

  /// No description provided for @previewFullNote.
  ///
  /// In en, this message translates to:
  /// **'Only the teaching example is expanded. No purchase or personal report entitlement is created.'**
  String get previewFullNote;

  /// No description provided for @purchaseHistory.
  ///
  /// In en, this message translates to:
  /// **'Purchased content'**
  String get purchaseHistory;

  /// No description provided for @noPurchases.
  ///
  /// In en, this message translates to:
  /// **'No verified purchases yet'**
  String get noPurchases;

  /// No description provided for @noPurchasesText.
  ///
  /// In en, this message translates to:
  /// **'Reports appear in your account after a purchase is verified in the iOS app.'**
  String get noPurchasesText;

  /// No description provided for @account.
  ///
  /// In en, this message translates to:
  /// **'My account'**
  String get account;

  /// No description provided for @guest.
  ///
  /// In en, this message translates to:
  /// **'Guest'**
  String get guest;

  /// No description provided for @signedIn.
  ///
  /// In en, this message translates to:
  /// **'Signed in'**
  String get signedIn;

  /// No description provided for @accountText.
  ///
  /// In en, this message translates to:
  /// **'Keep your details and reports, and return to your exploration.'**
  String get accountText;

  /// No description provided for @deviceProfile.
  ///
  /// In en, this message translates to:
  /// **'Birth details'**
  String get deviceProfile;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @largeText.
  ///
  /// In en, this message translates to:
  /// **'Larger text'**
  String get largeText;

  /// No description provided for @privacy.
  ///
  /// In en, this message translates to:
  /// **'Details and privacy'**
  String get privacy;

  /// No description provided for @privacyText.
  ///
  /// In en, this message translates to:
  /// **'Drafts and access credentials stay on this device. Birth details, charts and reports belong to your current guest session or account. RoxyAPI calculates charts; AI chart reports use chart facts without your name, city text or chat history.\n\nGuardian chat sends your messages, birth details, relevant conversations, confirmed memories and selected visible readings to the AI service for replies and continuity. Clearing local details does not delete server records.'**
  String get privacyText;

  /// No description provided for @clearBirth.
  ///
  /// In en, this message translates to:
  /// **'Clear local birth details'**
  String get clearBirth;

  /// No description provided for @clearConfirm.
  ///
  /// In en, this message translates to:
  /// **'Clear birth details saved on this device?'**
  String get clearConfirm;

  /// No description provided for @cleared.
  ///
  /// In en, this message translates to:
  /// **'Local birth details cleared'**
  String get cleared;

  /// No description provided for @saved.
  ///
  /// In en, this message translates to:
  /// **'Birth details saved'**
  String get saved;

  /// No description provided for @saveBirth.
  ///
  /// In en, this message translates to:
  /// **'Save and view my chart'**
  String get saveBirth;

  /// No description provided for @nickname.
  ///
  /// In en, this message translates to:
  /// **'Preferred name (optional)'**
  String get nickname;

  /// No description provided for @nicknamePlaceholder.
  ///
  /// In en, this message translates to:
  /// **'What should we call you?'**
  String get nicknamePlaceholder;

  /// No description provided for @placeRequired.
  ///
  /// In en, this message translates to:
  /// **'Choose or enter your birth location'**
  String get placeRequired;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @birthStorage.
  ///
  /// In en, this message translates to:
  /// **'Create your chart and read your report without signing in. You can return to your results on this device.'**
  String get birthStorage;

  /// No description provided for @profileMissing.
  ///
  /// In en, this message translates to:
  /// **'No birth details yet'**
  String get profileMissing;

  /// No description provided for @connection.
  ///
  /// In en, this message translates to:
  /// **'The service is temporarily unavailable. Examples remain available.'**
  String get connection;

  /// No description provided for @error.
  ///
  /// In en, this message translates to:
  /// **'We could not finish this. Please try again later.'**
  String get error;

  /// No description provided for @sampleSummary.
  ///
  /// In en, this message translates to:
  /// **'You may care about doing things well and having your ideas recognized. State your main point clearly, then leave room for cooperation.'**
  String get sampleSummary;

  /// No description provided for @sampleTrait1Title.
  ///
  /// In en, this message translates to:
  /// **'You want a voice of your own'**
  String get sampleTrait1Title;

  /// No description provided for @sampleTrait1Text.
  ///
  /// In en, this message translates to:
  /// **'The example Sun in Leo offers a way to discuss expression and creativity. When a subject feels familiar, you may want to suggest a plan first. If it is not chosen, asking why can help more than rushing to prove yourself.'**
  String get sampleTrait1Text;

  /// No description provided for @sampleTrait2Title.
  ///
  /// In en, this message translates to:
  /// **'Balance freedom with responsibility'**
  String get sampleTrait2Title;

  /// No description provided for @sampleTrait2Text.
  ///
  /// In en, this message translates to:
  /// **'The example Moon\'s exploratory themes and the Sun–Saturn connection can prompt reflection on freedom and duty. Set aside clear rest time and write down commitments, giving both needs a place.'**
  String get sampleTrait2Text;

  /// No description provided for @sampleWatch1Title.
  ///
  /// In en, this message translates to:
  /// **'Different opinions need not reject you'**
  String get sampleWatch1Title;

  /// No description provided for @sampleWatch1Text.
  ///
  /// In en, this message translates to:
  /// **'When someone changes a plan or has not replied, check whether they question the method or the goal. Notice rushed explanations, interruptions, or repeated message checking. Ask, “Which part concerns you most?” before agreeing on what to change.'**
  String get sampleWatch1Text;

  /// No description provided for @sampleWatch2Title.
  ///
  /// In en, this message translates to:
  /// **'Leave room before making commitments'**
  String get sampleWatch2Title;

  /// No description provided for @sampleWatch2Text.
  ///
  /// In en, this message translates to:
  /// **'Wanting recognition can lead to accepting more than your time allows. Check your calendar, the effort involved, and existing commitments before answering. If unsure, say, “Let me check my schedule and get back to you tomorrow.”'**
  String get sampleWatch2Text;

  /// No description provided for @sampleAdvice1Title.
  ///
  /// In en, this message translates to:
  /// **'Prepare three sentences for a conversation'**
  String get sampleAdvice1Title;

  /// No description provided for @sampleAdvice1Text.
  ///
  /// In en, this message translates to:
  /// **'Write the observable fact, your need, and one specific request. For example: “The plan changed twice this week. I need to confirm the direction. Could we use ten minutes to agree on priorities?” Pause for their response and record the agreement.'**
  String get sampleAdvice1Text;

  /// No description provided for @sampleAdvice2Title.
  ///
  /// In en, this message translates to:
  /// **'Turn one goal into an action for today'**
  String get sampleAdvice2Title;

  /// No description provided for @sampleAdvice2Text.
  ///
  /// In en, this message translates to:
  /// **'Choose one goal. List what you need, the first action, and how to check it. Spend twenty minutes on a small step, such as gathering three pieces of feedback or drafting an email. Check that step before choosing the next.'**
  String get sampleAdvice2Text;

  /// No description provided for @sampleAdvice3Title.
  ///
  /// In en, this message translates to:
  /// **'Make room for a short weekly review'**
  String get sampleAdvice3Title;

  /// No description provided for @sampleAdvice3Text.
  ///
  /// In en, this message translates to:
  /// **'At a regular time, record one useful experience, one difficult conversation, and one adjustment to try. Use actual events to see whether the advice fits. Leave aside or change approaches that do not help.'**
  String get sampleAdvice3Text;

  /// No description provided for @login.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get login;

  /// No description provided for @logout.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get logout;

  /// No description provided for @register.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get register;

  /// No description provided for @username.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get username;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @confirmPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm password'**
  String get confirmPassword;

  /// No description provided for @passwordMismatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match'**
  String get passwordMismatch;

  /// No description provided for @birthDate.
  ///
  /// In en, this message translates to:
  /// **'Birth date'**
  String get birthDate;

  /// No description provided for @birthTime.
  ///
  /// In en, this message translates to:
  /// **'Birth time'**
  String get birthTime;

  /// No description provided for @timezone.
  ///
  /// In en, this message translates to:
  /// **'Birth timezone'**
  String get timezone;

  /// No description provided for @birthplace.
  ///
  /// In en, this message translates to:
  /// **'Birth city'**
  String get birthplace;

  /// No description provided for @birthplacePlaceholder.
  ///
  /// In en, this message translates to:
  /// **'For example: Bangkok'**
  String get birthplacePlaceholder;

  /// No description provided for @pickerDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get pickerDone;

  /// No description provided for @pickerCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel selection'**
  String get pickerCancel;

  /// No description provided for @chooseBirthDate.
  ///
  /// In en, this message translates to:
  /// **'Choose your birth date'**
  String get chooseBirthDate;

  /// No description provided for @chooseBirthTime.
  ///
  /// In en, this message translates to:
  /// **'Choose your birth time'**
  String get chooseBirthTime;

  /// No description provided for @searchBirthCity.
  ///
  /// In en, this message translates to:
  /// **'Search city or district'**
  String get searchBirthCity;

  /// No description provided for @searchTimezone.
  ///
  /// In en, this message translates to:
  /// **'Search time zones, e.g. Asia/Bangkok'**
  String get searchTimezone;

  /// No description provided for @appleLogin.
  ///
  /// In en, this message translates to:
  /// **'Sign in with Apple'**
  String get appleLogin;

  /// No description provided for @developmentLogin.
  ///
  /// In en, this message translates to:
  /// **'Development test account'**
  String get developmentLogin;

  /// No description provided for @nativeSetup.
  ///
  /// In en, this message translates to:
  /// **'This is a preview environment. Native sign-in and purchases require service configuration.'**
  String get nativeSetup;

  /// No description provided for @calendarGregorian.
  ///
  /// In en, this message translates to:
  /// **'Gregorian'**
  String get calendarGregorian;

  /// No description provided for @calendarBuddhist.
  ///
  /// In en, this message translates to:
  /// **'Buddhist Era'**
  String get calendarBuddhist;

  /// No description provided for @timeUnknown.
  ///
  /// In en, this message translates to:
  /// **'I do not know the exact time'**
  String get timeUnknown;

  /// No description provided for @reportPending.
  ///
  /// In en, this message translates to:
  /// **'Your report is being generated. You can leave and return later.'**
  String get reportPending;

  /// No description provided for @resumeReport.
  ///
  /// In en, this message translates to:
  /// **'Resume the latest report'**
  String get resumeReport;

  /// No description provided for @loginRequired.
  ///
  /// In en, this message translates to:
  /// **'Sign in before purchasing'**
  String get loginRequired;

  /// No description provided for @serviceSetup.
  ///
  /// In en, this message translates to:
  /// **'This service is not ready. You can explore a teaching example.'**
  String get serviceSetup;

  /// No description provided for @exactBirth.
  ///
  /// In en, this message translates to:
  /// **'Known birth time'**
  String get exactBirth;

  /// No description provided for @dateOnly.
  ///
  /// In en, this message translates to:
  /// **'Date only'**
  String get dateOnly;

  /// No description provided for @dataPrecision.
  ///
  /// In en, this message translates to:
  /// **'Birth data precision'**
  String get dataPrecision;

  /// No description provided for @cityDirectory.
  ///
  /// In en, this message translates to:
  /// **'Search the city directory'**
  String get cityDirectory;

  /// No description provided for @findCity.
  ///
  /// In en, this message translates to:
  /// **'Find a city'**
  String get findCity;

  /// No description provided for @deleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete account'**
  String get deleteAccount;

  /// No description provided for @deletionSetup.
  ///
  /// In en, this message translates to:
  /// **'Account deletion must be enabled on the server before a request can be submitted.'**
  String get deletionSetup;

  /// No description provided for @aiConsent.
  ///
  /// In en, this message translates to:
  /// **'To prepare the report, calculated chart facts will be sent to the AI service without your name, city text or chat history. Do you agree?'**
  String get aiConsent;

  /// No description provided for @consentGenerate.
  ///
  /// In en, this message translates to:
  /// **'Agree and generate'**
  String get consentGenerate;

  /// No description provided for @decline.
  ///
  /// In en, this message translates to:
  /// **'Decline'**
  String get decline;

  /// No description provided for @purchaseVerifying.
  ///
  /// In en, this message translates to:
  /// **'Your purchase is being verified. Refresh the report shortly.'**
  String get purchaseVerifying;

  /// No description provided for @personalReport.
  ///
  /// In en, this message translates to:
  /// **'Personal report'**
  String get personalReport;

  /// No description provided for @missingAngles.
  ///
  /// In en, this message translates to:
  /// **'Ascendant and houses are unavailable. Only supplied planet positions are shown.'**
  String get missingAngles;

  /// No description provided for @languageHelp.
  ///
  /// In en, this message translates to:
  /// **'Switch between Thai, English, Chinese and Vietnamese here.'**
  String get languageHelp;

  /// No description provided for @continueChart.
  ///
  /// In en, this message translates to:
  /// **'Continue my chart'**
  String get continueChart;

  /// No description provided for @pSun.
  ///
  /// In en, this message translates to:
  /// **'Sun'**
  String get pSun;

  /// No description provided for @pMoon.
  ///
  /// In en, this message translates to:
  /// **'Moon'**
  String get pMoon;

  /// No description provided for @pMercury.
  ///
  /// In en, this message translates to:
  /// **'Mercury'**
  String get pMercury;

  /// No description provided for @pVenus.
  ///
  /// In en, this message translates to:
  /// **'Venus'**
  String get pVenus;

  /// No description provided for @pMars.
  ///
  /// In en, this message translates to:
  /// **'Mars'**
  String get pMars;

  /// No description provided for @pJupiter.
  ///
  /// In en, this message translates to:
  /// **'Jupiter'**
  String get pJupiter;

  /// No description provided for @pSaturn.
  ///
  /// In en, this message translates to:
  /// **'Saturn'**
  String get pSaturn;

  /// No description provided for @pUranus.
  ///
  /// In en, this message translates to:
  /// **'Uranus'**
  String get pUranus;

  /// No description provided for @pNeptune.
  ///
  /// In en, this message translates to:
  /// **'Neptune'**
  String get pNeptune;

  /// No description provided for @pPluto.
  ///
  /// In en, this message translates to:
  /// **'Pluto'**
  String get pPluto;

  /// No description provided for @zAries.
  ///
  /// In en, this message translates to:
  /// **'Aries'**
  String get zAries;

  /// No description provided for @zTaurus.
  ///
  /// In en, this message translates to:
  /// **'Taurus'**
  String get zTaurus;

  /// No description provided for @zGemini.
  ///
  /// In en, this message translates to:
  /// **'Gemini'**
  String get zGemini;

  /// No description provided for @zCancer.
  ///
  /// In en, this message translates to:
  /// **'Cancer'**
  String get zCancer;

  /// No description provided for @zLeo.
  ///
  /// In en, this message translates to:
  /// **'Leo'**
  String get zLeo;

  /// No description provided for @zVirgo.
  ///
  /// In en, this message translates to:
  /// **'Virgo'**
  String get zVirgo;

  /// No description provided for @zLibra.
  ///
  /// In en, this message translates to:
  /// **'Libra'**
  String get zLibra;

  /// No description provided for @zScorpio.
  ///
  /// In en, this message translates to:
  /// **'Scorpio'**
  String get zScorpio;

  /// No description provided for @zSagittarius.
  ///
  /// In en, this message translates to:
  /// **'Sagittarius'**
  String get zSagittarius;

  /// No description provided for @zCapricorn.
  ///
  /// In en, this message translates to:
  /// **'Capricorn'**
  String get zCapricorn;

  /// No description provided for @zAquarius.
  ///
  /// In en, this message translates to:
  /// **'Aquarius'**
  String get zAquarius;

  /// No description provided for @zPisces.
  ///
  /// In en, this message translates to:
  /// **'Pisces'**
  String get zPisces;

  /// No description provided for @skipOpening.
  ///
  /// In en, this message translates to:
  /// **'Skip intro'**
  String get skipOpening;

  /// No description provided for @tarot.
  ///
  /// In en, this message translates to:
  /// **'Tarot'**
  String get tarot;

  /// No description provided for @luckyNumbers.
  ///
  /// In en, this message translates to:
  /// **'Lucky numbers'**
  String get luckyNumbers;

  /// No description provided for @tarotDraw.
  ///
  /// In en, this message translates to:
  /// **'Draw three cards'**
  String get tarotDraw;

  /// No description provided for @tarotDrawHint.
  ///
  /// In en, this message translates to:
  /// **'Think of a question, then choose three cards from the spread.'**
  String get tarotDrawHint;

  /// No description provided for @tarotChooseCard.
  ///
  /// In en, this message translates to:
  /// **'Draw scattered card {position}'**
  String tarotChooseCard(int position);

  /// No description provided for @tarotResult.
  ///
  /// In en, this message translates to:
  /// **'Your three cards'**
  String get tarotResult;

  /// No description provided for @tarotDrawAgain.
  ///
  /// In en, this message translates to:
  /// **'Draw again'**
  String get tarotDrawAgain;

  /// No description provided for @todayLuckyNumber.
  ///
  /// In en, this message translates to:
  /// **'Today’s lucky number'**
  String get todayLuckyNumber;

  /// No description provided for @luckyNumberHint.
  ///
  /// In en, this message translates to:
  /// **'A prompt for today'**
  String get luckyNumberHint;

  /// No description provided for @luckyNumberUpdates.
  ///
  /// In en, this message translates to:
  /// **'Updates using your device’s local date'**
  String get luckyNumberUpdates;

  /// No description provided for @tarotFool.
  ///
  /// In en, this message translates to:
  /// **'The Fool'**
  String get tarotFool;

  /// No description provided for @tarotFoolMeaning.
  ///
  /// In en, this message translates to:
  /// **'Try a new direction with one small step, leaving yourself room to adjust.'**
  String get tarotFoolMeaning;

  /// No description provided for @tarotMagician.
  ///
  /// In en, this message translates to:
  /// **'The Magician'**
  String get tarotMagician;

  /// No description provided for @tarotMagicianMeaning.
  ///
  /// In en, this message translates to:
  /// **'Take stock of the skills and tools you have, then act on one idea today.'**
  String get tarotMagicianMeaning;

  /// No description provided for @tarotHighPriestess.
  ///
  /// In en, this message translates to:
  /// **'The High Priestess'**
  String get tarotHighPriestess;

  /// No description provided for @tarotHighPriestessMeaning.
  ///
  /// In en, this message translates to:
  /// **'Give yourself a quiet moment to observe and listen to your instincts before acting.'**
  String get tarotHighPriestessMeaning;

  /// No description provided for @tarotEmpress.
  ///
  /// In en, this message translates to:
  /// **'The Empress'**
  String get tarotEmpress;

  /// No description provided for @tarotEmpressMeaning.
  ///
  /// In en, this message translates to:
  /// **'Make time for something that nourishes your creativity, and give yourself time to rest.'**
  String get tarotEmpressMeaning;

  /// No description provided for @tarotEmperor.
  ///
  /// In en, this message translates to:
  /// **'The Emperor'**
  String get tarotEmperor;

  /// No description provided for @tarotEmperorMeaning.
  ///
  /// In en, this message translates to:
  /// **'Set a clear goal and boundaries, then put your tasks in order of importance.'**
  String get tarotEmperorMeaning;

  /// No description provided for @tarotHierophant.
  ///
  /// In en, this message translates to:
  /// **'The Hierophant'**
  String get tarotHierophant;

  /// No description provided for @tarotHierophantMeaning.
  ///
  /// In en, this message translates to:
  /// **'Ask someone you trust for guidance, and keep the advice that fits your situation.'**
  String get tarotHierophantMeaning;

  /// No description provided for @tarotLovers.
  ///
  /// In en, this message translates to:
  /// **'The Lovers'**
  String get tarotLovers;

  /// No description provided for @tarotLoversMeaning.
  ///
  /// In en, this message translates to:
  /// **'When making a choice, name what matters to you and communicate it honestly.'**
  String get tarotLoversMeaning;

  /// No description provided for @tarotChariot.
  ///
  /// In en, this message translates to:
  /// **'The Chariot'**
  String get tarotChariot;

  /// No description provided for @tarotChariotMeaning.
  ///
  /// In en, this message translates to:
  /// **'Pick one direction and focus your energy on the next step that matters most.'**
  String get tarotChariotMeaning;

  /// No description provided for @tarotStrength.
  ///
  /// In en, this message translates to:
  /// **'Strength'**
  String get tarotStrength;

  /// No description provided for @tarotStrengthMeaning.
  ///
  /// In en, this message translates to:
  /// **'When tension arises, take a moment to settle and respond with calm resolve.'**
  String get tarotStrengthMeaning;

  /// No description provided for @tarotHermit.
  ///
  /// In en, this message translates to:
  /// **'The Hermit'**
  String get tarotHermit;

  /// No description provided for @tarotHermitMeaning.
  ///
  /// In en, this message translates to:
  /// **'Step away from outside opinions for a moment and reflect on what you want to know.'**
  String get tarotHermitMeaning;

  /// No description provided for @tarotWheelOfFortune.
  ///
  /// In en, this message translates to:
  /// **'Wheel of Fortune'**
  String get tarotWheelOfFortune;

  /// No description provided for @tarotWheelOfFortuneMeaning.
  ///
  /// In en, this message translates to:
  /// **'Leave some flexibility in your plans and start with what you can control.'**
  String get tarotWheelOfFortuneMeaning;

  /// No description provided for @tarotJustice.
  ///
  /// In en, this message translates to:
  /// **'Justice'**
  String get tarotJustice;

  /// No description provided for @tarotJusticeMeaning.
  ///
  /// In en, this message translates to:
  /// **'Consider the facts and your feelings, then make a choice you can stand behind.'**
  String get tarotJusticeMeaning;

  /// No description provided for @tarotHangedMan.
  ///
  /// In en, this message translates to:
  /// **'The Hanged Man'**
  String get tarotHangedMan;

  /// No description provided for @tarotHangedManMeaning.
  ///
  /// In en, this message translates to:
  /// **'If you feel stuck, pause and look at the situation from a different angle.'**
  String get tarotHangedManMeaning;

  /// No description provided for @tarotDeath.
  ///
  /// In en, this message translates to:
  /// **'Death'**
  String get tarotDeath;

  /// No description provided for @tarotDeathMeaning.
  ///
  /// In en, this message translates to:
  /// **'Set aside something that has run its course to make room for a new habit or choice.'**
  String get tarotDeathMeaning;

  /// No description provided for @tarotTemperance.
  ///
  /// In en, this message translates to:
  /// **'Temperance'**
  String get tarotTemperance;

  /// No description provided for @tarotTemperanceMeaning.
  ///
  /// In en, this message translates to:
  /// **'Make a small adjustment that gives two competing needs a little more balance.'**
  String get tarotTemperanceMeaning;

  /// No description provided for @tarotDevil.
  ///
  /// In en, this message translates to:
  /// **'The Devil'**
  String get tarotDevil;

  /// No description provided for @tarotDevilMeaning.
  ///
  /// In en, this message translates to:
  /// **'Notice a habit that takes too much of your energy and change one small part of it.'**
  String get tarotDevilMeaning;

  /// No description provided for @tarotTower.
  ///
  /// In en, this message translates to:
  /// **'The Tower'**
  String get tarotTower;

  /// No description provided for @tarotTowerMeaning.
  ///
  /// In en, this message translates to:
  /// **'When a plan falls apart, deal with what is most urgent before making a new one.'**
  String get tarotTowerMeaning;

  /// No description provided for @tarotStar.
  ///
  /// In en, this message translates to:
  /// **'The Star'**
  String get tarotStar;

  /// No description provided for @tarotStarMeaning.
  ///
  /// In en, this message translates to:
  /// **'Give yourself time to recharge and choose one small goal you still look forward to.'**
  String get tarotStarMeaning;

  /// No description provided for @tarotMoon.
  ///
  /// In en, this message translates to:
  /// **'The Moon'**
  String get tarotMoon;

  /// No description provided for @tarotMoonMeaning.
  ///
  /// In en, this message translates to:
  /// **'If something feels unclear, check the information you have before drawing a conclusion.'**
  String get tarotMoonMeaning;

  /// No description provided for @tarotSun.
  ///
  /// In en, this message translates to:
  /// **'The Sun'**
  String get tarotSun;

  /// No description provided for @tarotSunMeaning.
  ///
  /// In en, this message translates to:
  /// **'Take note of your progress and share a piece of good news with someone you trust.'**
  String get tarotSunMeaning;

  /// No description provided for @tarotJudgement.
  ///
  /// In en, this message translates to:
  /// **'Judgement'**
  String get tarotJudgement;

  /// No description provided for @tarotJudgementMeaning.
  ///
  /// In en, this message translates to:
  /// **'Reflect on a past choice, recognize what you learned, and decide what comes next.'**
  String get tarotJudgementMeaning;

  /// No description provided for @tarotWorld.
  ///
  /// In en, this message translates to:
  /// **'The World'**
  String get tarotWorld;

  /// No description provided for @tarotWorldMeaning.
  ///
  /// In en, this message translates to:
  /// **'Close out a completed task, note what you gained, and prepare for the next stage.'**
  String get tarotWorldMeaning;

  /// No description provided for @luckyNumberOne.
  ///
  /// In en, this message translates to:
  /// **'Start something new with one small action you can take today.'**
  String get luckyNumberOne;

  /// No description provided for @luckyNumberTwo.
  ///
  /// In en, this message translates to:
  /// **'Make time for collaboration and listen to another point of view.'**
  String get luckyNumberTwo;

  /// No description provided for @luckyNumberThree.
  ///
  /// In en, this message translates to:
  /// **'Give an idea a voice by sharing it, writing it down, or making something.'**
  String get luckyNumberThree;

  /// No description provided for @luckyNumberFour.
  ///
  /// In en, this message translates to:
  /// **'Set your priorities and begin with one task you can put into practice.'**
  String get luckyNumberFour;

  /// No description provided for @luckyNumberFive.
  ///
  /// In en, this message translates to:
  /// **'Try a different approach and leave a little flexibility in your plan.'**
  String get luckyNumberFive;

  /// No description provided for @luckyNumberSix.
  ///
  /// In en, this message translates to:
  /// **'Make time for the people you care about and look after yourself too.'**
  String get luckyNumberSix;

  /// No description provided for @luckyNumberSeven.
  ///
  /// In en, this message translates to:
  /// **'Find a quiet moment to organize your thoughts and consider a question.'**
  String get luckyNumberSeven;

  /// No description provided for @luckyNumberEight.
  ///
  /// In en, this message translates to:
  /// **'Take one concrete step toward something worth pursuing over time.'**
  String get luckyNumberEight;

  /// No description provided for @luckyNumberNine.
  ///
  /// In en, this message translates to:
  /// **'Tie up a loose end and let go of something that is already complete.'**
  String get luckyNumberNine;

  /// No description provided for @tarotDrawTitle.
  ///
  /// In en, this message translates to:
  /// **'Draw Tarot'**
  String get tarotDrawTitle;

  /// No description provided for @tarotProgress.
  ///
  /// In en, this message translates to:
  /// **'Drawn {count} / {total}'**
  String tarotProgress(int count, int total);

  /// No description provided for @tarotCardPosition.
  ///
  /// In en, this message translates to:
  /// **'Card {position}'**
  String tarotCardPosition(int position);

  /// No description provided for @tarotCardsRemaining.
  ///
  /// In en, this message translates to:
  /// **'Choose {count} more from the spread'**
  String tarotCardsRemaining(int count);

  /// No description provided for @tarotGestureHint.
  ///
  /// In en, this message translates to:
  /// **'Tap a card or swipe up on it'**
  String get tarotGestureHint;

  /// No description provided for @tarotShuffle.
  ///
  /// In en, this message translates to:
  /// **'Shuffle'**
  String get tarotShuffle;

  /// No description provided for @tarotSeerWaiting.
  ///
  /// In en, this message translates to:
  /// **'The astrologer is waiting for your question'**
  String get tarotSeerWaiting;

  /// No description provided for @tarotRevealing.
  ///
  /// In en, this message translates to:
  /// **'Turning over your card…'**
  String get tarotRevealing;

  /// No description provided for @tarotSeerReading.
  ///
  /// In en, this message translates to:
  /// **'All three cards are ready. The astrologer is reading them.'**
  String get tarotSeerReading;

  /// No description provided for @tarotReadingComplete.
  ///
  /// In en, this message translates to:
  /// **'Reading complete'**
  String get tarotReadingComplete;

  /// No description provided for @tarotReadingStepOne.
  ///
  /// In en, this message translates to:
  /// **'Listening to the stars…'**
  String get tarotReadingStepOne;

  /// No description provided for @tarotReadingStepTwo.
  ///
  /// In en, this message translates to:
  /// **'The astrologer touches the glowing chart…'**
  String get tarotReadingStepTwo;

  /// No description provided for @tarotReadingStepThree.
  ///
  /// In en, this message translates to:
  /// **'Exploring the three cards…'**
  String get tarotReadingStepThree;

  /// No description provided for @tarotReadingStepFour.
  ///
  /// In en, this message translates to:
  /// **'Writing your reading…'**
  String get tarotReadingStepFour;

  /// No description provided for @tarotMinorName.
  ///
  /// In en, this message translates to:
  /// **'{rank} of {suit}'**
  String tarotMinorName(String suit, String rank);

  /// No description provided for @tarotRankAce.
  ///
  /// In en, this message translates to:
  /// **'Ace'**
  String get tarotRankAce;

  /// No description provided for @tarotRankTwo.
  ///
  /// In en, this message translates to:
  /// **'Two'**
  String get tarotRankTwo;

  /// No description provided for @tarotRankThree.
  ///
  /// In en, this message translates to:
  /// **'Three'**
  String get tarotRankThree;

  /// No description provided for @tarotRankFour.
  ///
  /// In en, this message translates to:
  /// **'Four'**
  String get tarotRankFour;

  /// No description provided for @tarotRankFive.
  ///
  /// In en, this message translates to:
  /// **'Five'**
  String get tarotRankFive;

  /// No description provided for @tarotRankSix.
  ///
  /// In en, this message translates to:
  /// **'Six'**
  String get tarotRankSix;

  /// No description provided for @tarotRankSeven.
  ///
  /// In en, this message translates to:
  /// **'Seven'**
  String get tarotRankSeven;

  /// No description provided for @tarotRankEight.
  ///
  /// In en, this message translates to:
  /// **'Eight'**
  String get tarotRankEight;

  /// No description provided for @tarotRankNine.
  ///
  /// In en, this message translates to:
  /// **'Nine'**
  String get tarotRankNine;

  /// No description provided for @tarotRankTen.
  ///
  /// In en, this message translates to:
  /// **'Ten'**
  String get tarotRankTen;

  /// No description provided for @tarotRankPage.
  ///
  /// In en, this message translates to:
  /// **'Page'**
  String get tarotRankPage;

  /// No description provided for @tarotRankKnight.
  ///
  /// In en, this message translates to:
  /// **'Knight'**
  String get tarotRankKnight;

  /// No description provided for @tarotRankQueen.
  ///
  /// In en, this message translates to:
  /// **'Queen'**
  String get tarotRankQueen;

  /// No description provided for @tarotRankKing.
  ///
  /// In en, this message translates to:
  /// **'King'**
  String get tarotRankKing;

  /// No description provided for @tarotSuitWands.
  ///
  /// In en, this message translates to:
  /// **'Wands'**
  String get tarotSuitWands;

  /// No description provided for @tarotWandsAceMeaning.
  ///
  /// In en, this message translates to:
  /// **'Try a small step toward an idea that excites you.'**
  String get tarotWandsAceMeaning;

  /// No description provided for @tarotWandsTwoMeaning.
  ///
  /// In en, this message translates to:
  /// **'Look at your options and decide which step to take next.'**
  String get tarotWandsTwoMeaning;

  /// No description provided for @tarotWandsThreeMeaning.
  ///
  /// In en, this message translates to:
  /// **'Look beyond your first success for a chance to build on it.'**
  String get tarotWandsThreeMeaning;

  /// No description provided for @tarotWandsFourMeaning.
  ///
  /// In en, this message translates to:
  /// **'Take time to celebrate something you have built with others.'**
  String get tarotWandsFourMeaning;

  /// No description provided for @tarotWandsFiveMeaning.
  ///
  /// In en, this message translates to:
  /// **'When opinions clash, listen for the problem each person wants to solve.'**
  String get tarotWandsFiveMeaning;

  /// No description provided for @tarotWandsSixMeaning.
  ///
  /// In en, this message translates to:
  /// **'Acknowledge your progress and share credit with those who helped.'**
  String get tarotWandsSixMeaning;

  /// No description provided for @tarotWandsSevenMeaning.
  ///
  /// In en, this message translates to:
  /// **'Decide which boundary matters and express it calmly.'**
  String get tarotWandsSevenMeaning;

  /// No description provided for @tarotWandsEightMeaning.
  ///
  /// In en, this message translates to:
  /// **'When things speed up, check the details and respond promptly.'**
  String get tarotWandsEightMeaning;

  /// No description provided for @tarotWandsNineMeaning.
  ///
  /// In en, this message translates to:
  /// **'Protect your energy and make time to recover.'**
  String get tarotWandsNineMeaning;

  /// No description provided for @tarotWandsTenMeaning.
  ///
  /// In en, this message translates to:
  /// **'Share a responsibility that has become too heavy to carry alone.'**
  String get tarotWandsTenMeaning;

  /// No description provided for @tarotWandsPageMeaning.
  ///
  /// In en, this message translates to:
  /// **'Follow your curiosity with one small experiment.'**
  String get tarotWandsPageMeaning;

  /// No description provided for @tarotWandsKnightMeaning.
  ///
  /// In en, this message translates to:
  /// **'Act on your enthusiasm with a plan for what comes after the first step.'**
  String get tarotWandsKnightMeaning;

  /// No description provided for @tarotWandsQueenMeaning.
  ///
  /// In en, this message translates to:
  /// **'Share your idea with confidence and invite others to contribute.'**
  String get tarotWandsQueenMeaning;

  /// No description provided for @tarotWandsKingMeaning.
  ///
  /// In en, this message translates to:
  /// **'Choose a direction people can work toward together.'**
  String get tarotWandsKingMeaning;

  /// No description provided for @tarotSuitCups.
  ///
  /// In en, this message translates to:
  /// **'Cups'**
  String get tarotSuitCups;

  /// No description provided for @tarotCupsAceMeaning.
  ///
  /// In en, this message translates to:
  /// **'Make room for a new feeling and let yourself express it.'**
  String get tarotCupsAceMeaning;

  /// No description provided for @tarotCupsTwoMeaning.
  ///
  /// In en, this message translates to:
  /// **'Ask for what you need and leave room for the other person to respond.'**
  String get tarotCupsTwoMeaning;

  /// No description provided for @tarotCupsThreeMeaning.
  ///
  /// In en, this message translates to:
  /// **'Spend a moment with supportive people and share something worth celebrating.'**
  String get tarotCupsThreeMeaning;

  /// No description provided for @tarotCupsFourMeaning.
  ///
  /// In en, this message translates to:
  /// **'Notice what feels uninteresting, then look for an option you may have overlooked.'**
  String get tarotCupsFourMeaning;

  /// No description provided for @tarotCupsFiveMeaning.
  ///
  /// In en, this message translates to:
  /// **'Give yourself time to feel the loss and notice what support remains.'**
  String get tarotCupsFiveMeaning;

  /// No description provided for @tarotCupsSixMeaning.
  ///
  /// In en, this message translates to:
  /// **'Revisit a small activity that once brought you comfort.'**
  String get tarotCupsSixMeaning;

  /// No description provided for @tarotCupsSevenMeaning.
  ///
  /// In en, this message translates to:
  /// **'Separate ideas you can act on from ones you are still imagining.'**
  String get tarotCupsSevenMeaning;

  /// No description provided for @tarotCupsEightMeaning.
  ///
  /// In en, this message translates to:
  /// **'If a path no longer fits, consider what you want to move toward.'**
  String get tarotCupsEightMeaning;

  /// No description provided for @tarotCupsNineMeaning.
  ///
  /// In en, this message translates to:
  /// **'Enjoy a wish that has come true and notice what need it met.'**
  String get tarotCupsNineMeaning;

  /// No description provided for @tarotCupsTenMeaning.
  ///
  /// In en, this message translates to:
  /// **'Care for a relationship that gives you a sense of belonging.'**
  String get tarotCupsTenMeaning;

  /// No description provided for @tarotCupsPageMeaning.
  ///
  /// In en, this message translates to:
  /// **'Put a new feeling into words without judging it.'**
  String get tarotCupsPageMeaning;

  /// No description provided for @tarotCupsKnightMeaning.
  ///
  /// In en, this message translates to:
  /// **'Express what you feel and give the other person time to respond.'**
  String get tarotCupsKnightMeaning;

  /// No description provided for @tarotCupsQueenMeaning.
  ///
  /// In en, this message translates to:
  /// **'Listen with care and keep space for your own feelings.'**
  String get tarotCupsQueenMeaning;

  /// No description provided for @tarotCupsKingMeaning.
  ///
  /// In en, this message translates to:
  /// **'Let strong feelings settle before making a decision that affects others.'**
  String get tarotCupsKingMeaning;

  /// No description provided for @tarotSuitSwords.
  ///
  /// In en, this message translates to:
  /// **'Swords'**
  String get tarotSuitSwords;

  /// No description provided for @tarotSwordsAceMeaning.
  ///
  /// In en, this message translates to:
  /// **'Find one fact you can check to make a complicated situation clearer.'**
  String get tarotSwordsAceMeaning;

  /// No description provided for @tarotSwordsTwoMeaning.
  ///
  /// In en, this message translates to:
  /// **'Consider the cost of each option before making a decision.'**
  String get tarotSwordsTwoMeaning;

  /// No description provided for @tarotSwordsThreeMeaning.
  ///
  /// In en, this message translates to:
  /// **'Give a painful feeling some time and share it with someone you trust.'**
  String get tarotSwordsThreeMeaning;

  /// No description provided for @tarotSwordsFourMeaning.
  ///
  /// In en, this message translates to:
  /// **'Pause and rest before you return to a hard problem.'**
  String get tarotSwordsFourMeaning;

  /// No description provided for @tarotSwordsFiveMeaning.
  ///
  /// In en, this message translates to:
  /// **'Ask whether winning an argument is worth what it might cost.'**
  String get tarotSwordsFiveMeaning;

  /// No description provided for @tarotSwordsSixMeaning.
  ///
  /// In en, this message translates to:
  /// **'Focus on one next step away from a draining situation.'**
  String get tarotSwordsSixMeaning;

  /// No description provided for @tarotSwordsSevenMeaning.
  ///
  /// In en, this message translates to:
  /// **'Be clear about your motives and speak openly where you can.'**
  String get tarotSwordsSevenMeaning;

  /// No description provided for @tarotSwordsEightMeaning.
  ///
  /// In en, this message translates to:
  /// **'Separate real limits from worries and look for one choice you still have.'**
  String get tarotSwordsEightMeaning;

  /// No description provided for @tarotSwordsNineMeaning.
  ///
  /// In en, this message translates to:
  /// **'Write down recurring worries and choose one you can address today.'**
  String get tarotSwordsNineMeaning;

  /// No description provided for @tarotSwordsTenMeaning.
  ///
  /// In en, this message translates to:
  /// **'Accept that one chapter has ended and put your energy into recovery.'**
  String get tarotSwordsTenMeaning;

  /// No description provided for @tarotSwordsPageMeaning.
  ///
  /// In en, this message translates to:
  /// **'Ask questions and check information before you pass it on.'**
  String get tarotSwordsPageMeaning;

  /// No description provided for @tarotSwordsKnightMeaning.
  ///
  /// In en, this message translates to:
  /// **'Act decisively and check your tone and facts before speaking.'**
  String get tarotSwordsKnightMeaning;

  /// No description provided for @tarotSwordsQueenMeaning.
  ///
  /// In en, this message translates to:
  /// **'Be clear about the facts and your boundaries while staying open to a conversation.'**
  String get tarotSwordsQueenMeaning;

  /// No description provided for @tarotSwordsKingMeaning.
  ///
  /// In en, this message translates to:
  /// **'Use a consistent standard and consider each point of view fairly.'**
  String get tarotSwordsKingMeaning;

  /// No description provided for @tarotSuitPentacles.
  ///
  /// In en, this message translates to:
  /// **'Pentacles'**
  String get tarotSuitPentacles;

  /// No description provided for @tarotPentaclesAceMeaning.
  ///
  /// In en, this message translates to:
  /// **'Turn a practical opportunity into one action you can take.'**
  String get tarotPentaclesAceMeaning;

  /// No description provided for @tarotPentaclesTwoMeaning.
  ///
  /// In en, this message translates to:
  /// **'Rebalance your time and resources when several demands compete.'**
  String get tarotPentaclesTwoMeaning;

  /// No description provided for @tarotPentaclesThreeMeaning.
  ///
  /// In en, this message translates to:
  /// **'Improve your work with people who bring different skills.'**
  String get tarotPentaclesThreeMeaning;

  /// No description provided for @tarotPentaclesFourMeaning.
  ///
  /// In en, this message translates to:
  /// **'Take stock of what you have and leave room for change.'**
  String get tarotPentaclesFourMeaning;

  /// No description provided for @tarotPentaclesFiveMeaning.
  ///
  /// In en, this message translates to:
  /// **'Look for support and ask for it when you need it.'**
  String get tarotPentaclesFiveMeaning;

  /// No description provided for @tarotPentaclesSixMeaning.
  ///
  /// In en, this message translates to:
  /// **'Balance giving and receiving by being clear about expectations.'**
  String get tarotPentaclesSixMeaning;

  /// No description provided for @tarotPentaclesSevenMeaning.
  ///
  /// In en, this message translates to:
  /// **'Give steady work time to grow and set a date to check your progress.'**
  String get tarotPentaclesSevenMeaning;

  /// No description provided for @tarotPentaclesEightMeaning.
  ///
  /// In en, this message translates to:
  /// **'Practice one skill and let small improvements add up.'**
  String get tarotPentaclesEightMeaning;

  /// No description provided for @tarotPentaclesNineMeaning.
  ///
  /// In en, this message translates to:
  /// **'Recognize the stability and independence you have worked for.'**
  String get tarotPentaclesNineMeaning;

  /// No description provided for @tarotPentaclesTenMeaning.
  ///
  /// In en, this message translates to:
  /// **'Consider what you can build now that will support you in the future.'**
  String get tarotPentaclesTenMeaning;

  /// No description provided for @tarotPentaclesPageMeaning.
  ///
  /// In en, this message translates to:
  /// **'Choose a useful skill and take one step toward learning it.'**
  String get tarotPentaclesPageMeaning;

  /// No description provided for @tarotPentaclesKnightMeaning.
  ///
  /// In en, this message translates to:
  /// **'Follow through on a small task you can do well today.'**
  String get tarotPentaclesKnightMeaning;

  /// No description provided for @tarotPentaclesQueenMeaning.
  ///
  /// In en, this message translates to:
  /// **'Care for yourself and others with something practical you can do today.'**
  String get tarotPentaclesQueenMeaning;

  /// No description provided for @tarotPentaclesKingMeaning.
  ///
  /// In en, this message translates to:
  /// **'Use the stability you have built to prepare for the next stage.'**
  String get tarotPentaclesKingMeaning;

  /// No description provided for @thaiCalendarTitle.
  ///
  /// In en, this message translates to:
  /// **'Thai calendar today'**
  String get thaiCalendarTitle;

  /// No description provided for @thaiCalendarTimezone.
  ///
  /// In en, this message translates to:
  /// **'Bangkok time'**
  String get thaiCalendarTimezone;

  /// No description provided for @thaiCalendarCivilDate.
  ///
  /// In en, this message translates to:
  /// **'{date} · B.E. {year}'**
  String thaiCalendarCivilDate(String date, int year);

  /// No description provided for @thaiCalendarWaxing.
  ///
  /// In en, this message translates to:
  /// **'Waxing day {day}'**
  String thaiCalendarWaxing(int day);

  /// No description provided for @thaiCalendarWaning.
  ///
  /// In en, this message translates to:
  /// **'Waning day {day}'**
  String thaiCalendarWaning(int day);

  /// No description provided for @thaiCalendarLunarMonth.
  ///
  /// In en, this message translates to:
  /// **'Lunar month {month}'**
  String thaiCalendarLunarMonth(int month);

  /// No description provided for @thaiCalendarSecondEighth.
  ///
  /// In en, this message translates to:
  /// **'Second lunar month 8'**
  String get thaiCalendarSecondEighth;

  /// No description provided for @thaiCalendarAuspicious.
  ///
  /// In en, this message translates to:
  /// **'Auspicious day'**
  String get thaiCalendarAuspicious;

  /// No description provided for @thaiCalendarCaution.
  ///
  /// In en, this message translates to:
  /// **'Caution day'**
  String get thaiCalendarCaution;

  /// No description provided for @thaiCalendarMixed.
  ///
  /// In en, this message translates to:
  /// **'Mixed indications'**
  String get thaiCalendarMixed;

  /// No description provided for @thaiCalendarOrdinary.
  ///
  /// In en, this message translates to:
  /// **'Ordinary day'**
  String get thaiCalendarOrdinary;

  /// No description provided for @thaiCalendarHours.
  ///
  /// In en, this message translates to:
  /// **'Good hours {hours}'**
  String thaiCalendarHours(String hours);

  /// No description provided for @thaiCalendarDayRule.
  ///
  /// In en, this message translates to:
  /// **'Kalayok day indications use the small-era year at Bangkok noon'**
  String get thaiCalendarDayRule;

  /// No description provided for @thaiCalendarHourRule.
  ///
  /// In en, this message translates to:
  /// **'Daytime periods from the traditional Ubakong weekday table'**
  String get thaiCalendarHourRule;

  /// No description provided for @thaiCalendarLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading today’s Thai calendar…'**
  String get thaiCalendarLoading;

  /// No description provided for @thaiCalendarUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Today’s Thai calendar is unavailable'**
  String get thaiCalendarUnavailable;

  /// No description provided for @thaiCalendarLunarUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Lunar date unavailable for today'**
  String get thaiCalendarLunarUnavailable;

  /// No description provided for @thaiCalendarRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get thaiCalendarRetry;

  /// No description provided for @dailyHoroscopeTitle.
  ///
  /// In en, this message translates to:
  /// **'Daily horoscope'**
  String get dailyHoroscopeTitle;

  /// No description provided for @dailyHoroscopeToday.
  ///
  /// In en, this message translates to:
  /// **'{sign} today'**
  String dailyHoroscopeToday(String sign);

  /// No description provided for @dailyHoroscopeMore.
  ///
  /// In en, this message translates to:
  /// **'See more'**
  String get dailyHoroscopeMore;

  /// No description provided for @dailyHoroscopeChooseSign.
  ///
  /// In en, this message translates to:
  /// **'Choose a zodiac sign'**
  String get dailyHoroscopeChooseSign;

  /// No description provided for @dailyHoroscopeForecast.
  ///
  /// In en, this message translates to:
  /// **'Today’s reading'**
  String get dailyHoroscopeForecast;

  /// No description provided for @dailyHoroscopeBasis.
  ///
  /// In en, this message translates to:
  /// **'Based on Thai astrological transits and the Moon’s position. Updated by Bangkok date.'**
  String get dailyHoroscopeBasis;

  /// No description provided for @dailyHoroscopeLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading today’s horoscope…'**
  String get dailyHoroscopeLoading;

  /// No description provided for @dailyHoroscopeUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Today’s horoscope is unavailable'**
  String get dailyHoroscopeUnavailable;

  /// No description provided for @dailyHoroscopeLove.
  ///
  /// In en, this message translates to:
  /// **'Love'**
  String get dailyHoroscopeLove;

  /// No description provided for @dailyHoroscopeWork.
  ///
  /// In en, this message translates to:
  /// **'Career'**
  String get dailyHoroscopeWork;

  /// No description provided for @dailyHoroscopeMoney.
  ///
  /// In en, this message translates to:
  /// **'Finances'**
  String get dailyHoroscopeMoney;

  /// No description provided for @dailyHoroscopeLoveShort.
  ///
  /// In en, this message translates to:
  /// **'Love'**
  String get dailyHoroscopeLoveShort;

  /// No description provided for @dailyHoroscopeWorkShort.
  ///
  /// In en, this message translates to:
  /// **'Work'**
  String get dailyHoroscopeWorkShort;

  /// No description provided for @dailyHoroscopeMoneyShort.
  ///
  /// In en, this message translates to:
  /// **'Money'**
  String get dailyHoroscopeMoneyShort;

  /// No description provided for @dailyHoroscopeHealth.
  ///
  /// In en, this message translates to:
  /// **'Health'**
  String get dailyHoroscopeHealth;

  /// No description provided for @dailyHoroscopeReading.
  ///
  /// In en, this message translates to:
  /// **'{planet} transits house {house}. {advice}'**
  String dailyHoroscopeReading(String planet, int house, String advice);

  /// No description provided for @dailyHoroscopeLoveAdvice.
  ///
  /// In en, this message translates to:
  /// **'{tone, select, supportive{A good day to share how you feel and give the other person time to respond.} reflective{Pause before reading into a silence. Ask how the other person feels.} other{Make time for a relaxed conversation and listen to what matters to the other person.}}'**
  String dailyHoroscopeLoveAdvice(String tone);

  /// No description provided for @dailyHoroscopeWorkAdvice.
  ///
  /// In en, this message translates to:
  /// **'{tone, select, supportive{Pick a task you can move forward today and agree on the next step with your team.} reflective{Review the details of a task in progress before taking on a new commitment.} other{Set one clear priority and handle the rest in order.}}'**
  String dailyHoroscopeWorkAdvice(String tone);

  /// No description provided for @dailyHoroscopeMoneyAdvice.
  ///
  /// In en, this message translates to:
  /// **'{tone, select, supportive{Make time to review your spending and see what you can set aside.} reflective{Give yourself time to think through any unplanned purchase.} other{Check upcoming expenses and keep some room in your budget.}}'**
  String dailyHoroscopeMoneyAdvice(String tone);

  /// No description provided for @dailyHoroscopeHealthAdvice.
  ///
  /// In en, this message translates to:
  /// **'{tone, select, supportive{A little movement or a short break can help you keep a steady rhythm today.} reflective{Leave some space between plans and take a break when you need one.} other{Keep your usual routine and step away from the screen for a moment.}}'**
  String dailyHoroscopeHealthAdvice(String tone);

  /// No description provided for @chartRules.
  ///
  /// In en, this message translates to:
  /// **'Tropical zodiac · Placidus houses · True node'**
  String get chartRules;

  /// No description provided for @chartSource.
  ///
  /// In en, this message translates to:
  /// **'Calculated by RoxyAPI from your birth details'**
  String get chartSource;

  /// No description provided for @dateOnlyRules.
  ///
  /// In en, this message translates to:
  /// **'Birth time unknown: planetary positions are noon estimates. Moon, angles, houses, aspects and uncertain sign placements are omitted.'**
  String get dateOnlyRules;

  /// No description provided for @calculateChart.
  ///
  /// In en, this message translates to:
  /// **'Calculate my chart'**
  String get calculateChart;

  /// No description provided for @saveForChart.
  ///
  /// In en, this message translates to:
  /// **'Confirm and save your birth details before creating your personal chart.'**
  String get saveForChart;

  /// No description provided for @retrograde.
  ///
  /// In en, this message translates to:
  /// **'Retrograde'**
  String get retrograde;

  /// No description provided for @orb.
  ///
  /// In en, this message translates to:
  /// **'Orb'**
  String get orb;

  /// No description provided for @aspectConjunction.
  ///
  /// In en, this message translates to:
  /// **'Conjunction'**
  String get aspectConjunction;

  /// No description provided for @aspectSextile.
  ///
  /// In en, this message translates to:
  /// **'Sextile'**
  String get aspectSextile;

  /// No description provided for @aspectSquare.
  ///
  /// In en, this message translates to:
  /// **'Square'**
  String get aspectSquare;

  /// No description provided for @aspectTrine.
  ///
  /// In en, this message translates to:
  /// **'Trine'**
  String get aspectTrine;

  /// No description provided for @aspectOpposition.
  ///
  /// In en, this message translates to:
  /// **'Opposition'**
  String get aspectOpposition;

  /// No description provided for @fullReading.
  ///
  /// In en, this message translates to:
  /// **'Your full reading'**
  String get fullReading;

  /// No description provided for @developmentReport.
  ///
  /// In en, this message translates to:
  /// **'Local development preview: the full report is free here. No purchase or payment has taken place.'**
  String get developmentReport;

  /// No description provided for @reportGeneratingText.
  ///
  /// In en, this message translates to:
  /// **'We are preparing your reading from your planets, houses and aspects. It will appear automatically. You can leave and return to it later.'**
  String get reportGeneratingText;

  /// No description provided for @reportFailedText.
  ///
  /// In en, this message translates to:
  /// **'This reading could not be completed yet. Use the button below to try again. Your chart has been kept.'**
  String get reportFailedText;

  /// No description provided for @roxyUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The chart service is unavailable. Please try again later.'**
  String get roxyUnavailable;

  /// No description provided for @roxyQuota.
  ///
  /// In en, this message translates to:
  /// **'There are too many chart requests. Please try again later.'**
  String get roxyQuota;

  /// No description provided for @profileChanged.
  ///
  /// In en, this message translates to:
  /// **'Your birth details changed. Open the birth details page, confirm and save them again.'**
  String get profileChanged;

  /// No description provided for @birthRegion.
  ///
  /// In en, this message translates to:
  /// **'Province / region'**
  String get birthRegion;

  /// No description provided for @selectCountry.
  ///
  /// In en, this message translates to:
  /// **'Choose or search a country'**
  String get selectCountry;

  /// No description provided for @selectRegion.
  ///
  /// In en, this message translates to:
  /// **'Choose or search a region'**
  String get selectRegion;

  /// No description provided for @selectBirthCity.
  ///
  /// In en, this message translates to:
  /// **'Select your birth city from the suggestions'**
  String get selectBirthCity;

  /// No description provided for @countryFirst.
  ///
  /// In en, this message translates to:
  /// **'Choose a country first'**
  String get countryFirst;

  /// No description provided for @regionFirst.
  ///
  /// In en, this message translates to:
  /// **'Choose a region first'**
  String get regionFirst;

  /// No description provided for @regionNotNeeded.
  ///
  /// In en, this message translates to:
  /// **'Not required'**
  String get regionNotNeeded;

  /// No description provided for @birthLocationHint.
  ///
  /// In en, this message translates to:
  /// **'Type to search or open the list to choose. Location details are matched automatically.'**
  String get birthLocationHint;

  /// No description provided for @moreLocations.
  ///
  /// In en, this message translates to:
  /// **'Load more places'**
  String get moreLocations;

  /// No description provided for @guestReading.
  ///
  /// In en, this message translates to:
  /// **'View your chart and report without signing in.'**
  String get guestReading;

  /// No description provided for @optionalLogin.
  ///
  /// In en, this message translates to:
  /// **'Sign in or register (optional)'**
  String get optionalLogin;

  /// No description provided for @templeNav.
  ///
  /// In en, this message translates to:
  /// **'Temple'**
  String get templeNav;

  /// No description provided for @divinationNav.
  ///
  /// In en, this message translates to:
  /// **'Discover'**
  String get divinationNav;

  /// No description provided for @bondNav.
  ///
  /// In en, this message translates to:
  /// **'Our bond'**
  String get bondNav;

  /// No description provided for @moreNav.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get moreNav;

  /// No description provided for @templeWelcome.
  ///
  /// In en, this message translates to:
  /// **'Take a breath.\nYou are heard.'**
  String get templeWelcome;

  /// No description provided for @templeIntro.
  ///
  /// In en, this message translates to:
  /// **'A quiet place for\nwhatever is on your mind.'**
  String get templeIntro;

  /// No description provided for @chooseGuardian.
  ///
  /// In en, this message translates to:
  /// **'Who is on your mind today?'**
  String get chooseGuardian;

  /// No description provided for @aiCompanionNotice.
  ///
  /// In en, this message translates to:
  /// **'AI companions · for entertainment and reflection'**
  String get aiCompanionNotice;

  /// No description provided for @loveGuardian.
  ///
  /// In en, this message translates to:
  /// **'Love guardian'**
  String get loveGuardian;

  /// No description provided for @careerGuardian.
  ///
  /// In en, this message translates to:
  /// **'Career guardian'**
  String get careerGuardian;

  /// No description provided for @wealthGuardian.
  ///
  /// In en, this message translates to:
  /// **'Wealth guardian'**
  String get wealthGuardian;

  /// No description provided for @wellbeingGuardian.
  ///
  /// In en, this message translates to:
  /// **'Wellbeing guardian'**
  String get wellbeingGuardian;

  /// No description provided for @loveGuardianNote.
  ///
  /// In en, this message translates to:
  /// **'Love · connection'**
  String get loveGuardianNote;

  /// No description provided for @careerGuardianNote.
  ///
  /// In en, this message translates to:
  /// **'Direction · growth'**
  String get careerGuardianNote;

  /// No description provided for @wealthGuardianNote.
  ///
  /// In en, this message translates to:
  /// **'Resources · balance'**
  String get wealthGuardianNote;

  /// No description provided for @wellbeingGuardianNote.
  ///
  /// In en, this message translates to:
  /// **'Rest · self-care'**
  String get wellbeingGuardianNote;

  /// No description provided for @continueConversation.
  ///
  /// In en, this message translates to:
  /// **'Pick up our conversation'**
  String get continueConversation;

  /// No description provided for @startConversation.
  ///
  /// In en, this message translates to:
  /// **'Start a conversation'**
  String get startConversation;

  /// No description provided for @listenIntro.
  ///
  /// In en, this message translates to:
  /// **'You do not need the perfect words. Start wherever you like.'**
  String get listenIntro;

  /// No description provided for @messageHint.
  ///
  /// In en, this message translates to:
  /// **'What is on your mind?'**
  String get messageHint;

  /// No description provided for @sendMessage.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get sendMessage;

  /// No description provided for @assistantListening.
  ///
  /// In en, this message translates to:
  /// **'Listening and putting thoughts together…'**
  String get assistantListening;

  /// No description provided for @chatUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Conversation is unavailable right now. Please try again later.'**
  String get chatUnavailable;

  /// No description provided for @chatProfileNeeded.
  ///
  /// In en, this message translates to:
  /// **'Add your birth details to connect readings to you.'**
  String get chatProfileNeeded;

  /// No description provided for @chatFailure.
  ///
  /// In en, this message translates to:
  /// **'The reply did not finish. Please retry; this turn is not counted.'**
  String get chatFailure;

  /// No description provided for @selectedReading.
  ///
  /// In en, this message translates to:
  /// **'This reading'**
  String get selectedReading;

  /// No description provided for @continueReading.
  ///
  /// In en, this message translates to:
  /// **'Discuss with a guardian'**
  String get continueReading;

  /// No description provided for @readingQuestion.
  ///
  /// In en, this message translates to:
  /// **'What in this reading should I reflect on?'**
  String get readingQuestion;

  /// No description provided for @divinationTitle.
  ///
  /// In en, this message translates to:
  /// **'A little perspective'**
  String get divinationTitle;

  /// No description provided for @divinationIntro.
  ///
  /// In en, this message translates to:
  /// **'Draw a card, explore your stars, then talk it through.'**
  String get divinationIntro;

  /// No description provided for @dailyDraw.
  ///
  /// In en, this message translates to:
  /// **'A card for today'**
  String get dailyDraw;

  /// No description provided for @dailyDrawNote.
  ///
  /// In en, this message translates to:
  /// **'A quiet moment to reflect'**
  String get dailyDrawNote;

  /// No description provided for @weeklyEvents.
  ///
  /// In en, this message translates to:
  /// **'This week'**
  String get weeklyEvents;

  /// No description provided for @weeklyNote.
  ///
  /// In en, this message translates to:
  /// **'Your week, in perspective'**
  String get weeklyNote;

  /// No description provided for @weeklyPrompt.
  ///
  /// In en, this message translates to:
  /// **'What should I pay attention to this week? Let us think it through.'**
  String get weeklyPrompt;

  /// No description provided for @lovePrompt.
  ///
  /// In en, this message translates to:
  /// **'There is something about a relationship I want to talk about.'**
  String get lovePrompt;

  /// No description provided for @careerPrompt.
  ///
  /// In en, this message translates to:
  /// **'I have been unsure about my direction at work.'**
  String get careerPrompt;

  /// No description provided for @wealthPrompt.
  ///
  /// In en, this message translates to:
  /// **'I want to think through some money worries.'**
  String get wealthPrompt;

  /// No description provided for @wellbeingPrompt.
  ///
  /// In en, this message translates to:
  /// **'I have been tired lately and want to talk.'**
  String get wellbeingPrompt;

  /// No description provided for @bondTitle.
  ///
  /// In en, this message translates to:
  /// **'Getting to know you'**
  String get bondTitle;

  /// No description provided for @bondIntro.
  ///
  /// In en, this message translates to:
  /// **'A connection built from the things you choose to share.'**
  String get bondIntro;

  /// No description provided for @bondNew.
  ///
  /// In en, this message translates to:
  /// **'First meeting'**
  String get bondNew;

  /// No description provided for @bondFamiliar.
  ///
  /// In en, this message translates to:
  /// **'Getting acquainted'**
  String get bondFamiliar;

  /// No description provided for @bondGrowing.
  ///
  /// In en, this message translates to:
  /// **'Growing understanding'**
  String get bondGrowing;

  /// No description provided for @bondCount.
  ///
  /// In en, this message translates to:
  /// **'recent conversations'**
  String get bondCount;

  /// No description provided for @bondRecentNote.
  ///
  /// In en, this message translates to:
  /// **'Stages reflect recent completed conversations, not prediction accuracy.'**
  String get bondRecentNote;

  /// No description provided for @bondMemory.
  ///
  /// In en, this message translates to:
  /// **'What you want remembered'**
  String get bondMemory;

  /// No description provided for @memoryEmpty.
  ///
  /// In en, this message translates to:
  /// **'No confirmed memories yet. Share what matters to you.'**
  String get memoryEmpty;

  /// No description provided for @addMemory.
  ///
  /// In en, this message translates to:
  /// **'Add a memory'**
  String get addMemory;

  /// No description provided for @memoryHint.
  ///
  /// In en, this message translates to:
  /// **'For example: I am considering a job change.'**
  String get memoryHint;

  /// No description provided for @memoryHelp.
  ///
  /// In en, this message translates to:
  /// **'Confirmed by you, shared by all four guardians. Edit or delete anytime.'**
  String get memoryHelp;

  /// No description provided for @recentConversations.
  ///
  /// In en, this message translates to:
  /// **'Recent conversations'**
  String get recentConversations;

  /// No description provided for @noConversations.
  ///
  /// In en, this message translates to:
  /// **'Every connection starts with a hello.'**
  String get noConversations;

  /// No description provided for @profileSelf.
  ///
  /// In en, this message translates to:
  /// **'About you'**
  String get profileSelf;

  /// No description provided for @memoryDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete this confirmed memory?'**
  String get memoryDeleteConfirm;

  /// No description provided for @sharedHistory.
  ///
  /// In en, this message translates to:
  /// **'The four guardians share conversation memory.'**
  String get sharedHistory;

  /// No description provided for @editMemory.
  ///
  /// In en, this message translates to:
  /// **'Edit memory'**
  String get editMemory;

  /// No description provided for @saveMemory.
  ///
  /// In en, this message translates to:
  /// **'Save memory'**
  String get saveMemory;

  /// No description provided for @guardianSectionNote.
  ///
  /// In en, this message translates to:
  /// **'Four guardians, a place for every feeling'**
  String get guardianSectionNote;

  /// No description provided for @dailyHoroscopeEmpty.
  ///
  /// In en, this message translates to:
  /// **'Choose your zodiac sign for today\'s love, work and life guidance.'**
  String get dailyHoroscopeEmpty;

  /// No description provided for @appleLoginUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Apple sign-in is unavailable on this device. You can continue as a guest.'**
  String get appleLoginUnavailable;

  /// No description provided for @purchaseUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Purchases are not available yet. Please check back later.'**
  String get purchaseUnavailable;

  /// No description provided for @chatTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Reconnect'**
  String get chatTryAgain;

  /// No description provided for @copyLink.
  ///
  /// In en, this message translates to:
  /// **'Copy link'**
  String get copyLink;

  /// No description provided for @privacyCenter.
  ///
  /// In en, this message translates to:
  /// **'Privacy & permissions'**
  String get privacyCenter;

  /// No description provided for @privacyIntro.
  ///
  /// In en, this message translates to:
  /// **'Your information, your choices. Review what FATE uses and manage it here.'**
  String get privacyIntro;

  /// No description provided for @dataProfileTitle.
  ///
  /// In en, this message translates to:
  /// **'Birth information'**
  String get dataProfileTitle;

  /// No description provided for @dataProfileBody.
  ///
  /// In en, this message translates to:
  /// **'Your date, time, birthplace and time zone are saved to prepare your chart. Your saved profile is linked to your guest session or signed-in account.'**
  String get dataProfileBody;

  /// No description provided for @dataChatTitle.
  ///
  /// In en, this message translates to:
  /// **'AI conversations & readings'**
  String get dataChatTitle;

  /// No description provided for @dataChatBody.
  ///
  /// In en, this message translates to:
  /// **'Chart reports send calculated chart facts to an AI provider after your permission. Companion chat also shares your message, profile, recent conversation, saved memories and any reading you choose to discuss. Avoid entering information you do not want processed by AI.'**
  String get dataChatBody;

  /// No description provided for @dataPurchaseTitle.
  ///
  /// In en, this message translates to:
  /// **'Purchases & access'**
  String get dataPurchaseTitle;

  /// No description provided for @dataPurchaseBody.
  ///
  /// In en, this message translates to:
  /// **'The store handles payment. FATE verifies the transaction with its server before granting access. This app does not ask for your card number. Local previews do not create a purchase.'**
  String get dataPurchaseBody;

  /// No description provided for @dataControlTitle.
  ///
  /// In en, this message translates to:
  /// **'Managing your data'**
  String get dataControlTitle;

  /// No description provided for @dataControlBody.
  ///
  /// In en, this message translates to:
  /// **'You can edit your profile and saved memories, clear conversation history, and withdraw permission for future AI chats. Clearing birth information here removes only the local copy. Account deletion is a separate action and requires confirmation from the service.'**
  String get dataControlBody;

  /// No description provided for @aiPermission.
  ///
  /// In en, this message translates to:
  /// **'Before you talk'**
  String get aiPermission;

  /// No description provided for @aiPermissionBody.
  ///
  /// In en, this message translates to:
  /// **'Your message, birth profile, recent chats, saved memories and selected reading will be processed by the configured AI service ({provider}) to reply to you. Replies may be inaccurate. You can decline and still use other tools, or withdraw permission in Privacy at any time. Withdrawal stops future sharing on this device; it does not delete data already processed.'**
  String aiPermissionBody(String provider);

  /// No description provided for @aiAllow.
  ///
  /// In en, this message translates to:
  /// **'Allow & continue'**
  String get aiAllow;

  /// No description provided for @aiEnabled.
  ///
  /// In en, this message translates to:
  /// **'AI chat permission is on'**
  String get aiEnabled;

  /// No description provided for @aiPaused.
  ///
  /// In en, this message translates to:
  /// **'AI chat permission is off'**
  String get aiPaused;

  /// No description provided for @aiRevoke.
  ///
  /// In en, this message translates to:
  /// **'Withdraw chat permission'**
  String get aiRevoke;

  /// No description provided for @aiRevoked.
  ///
  /// In en, this message translates to:
  /// **'Permission withdrawn. New messages will ask again.'**
  String get aiRevoked;

  /// No description provided for @privacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Full privacy policy'**
  String get privacyPolicy;

  /// No description provided for @policyUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The published policy link is not available yet.'**
  String get policyUnavailable;

  /// No description provided for @termsTitle.
  ///
  /// In en, this message translates to:
  /// **'Using FATE'**
  String get termsTitle;

  /// No description provided for @termsBody.
  ///
  /// In en, this message translates to:
  /// **'FATE offers AI companionship and astrology for reflection and entertainment. Readings are not guaranteed predictions or medical, financial or legal advice. Guardians are fictional AI characters. Paid content is available only after verified payment; price and availability come from the store. Do not use FATE to harass others or submit unlawful content.'**
  String get termsBody;

  /// No description provided for @supportTitle.
  ///
  /// In en, this message translates to:
  /// **'Help & support'**
  String get supportTitle;

  /// No description provided for @supportIntro.
  ///
  /// In en, this message translates to:
  /// **'A little guidance, whenever you need it.'**
  String get supportIntro;

  /// No description provided for @supportUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Support contact details are not available yet. Please try again later.'**
  String get supportUnavailable;

  /// No description provided for @supportContact.
  ///
  /// In en, this message translates to:
  /// **'Contact support'**
  String get supportContact;

  /// No description provided for @copyAddress.
  ///
  /// In en, this message translates to:
  /// **'Copy email address'**
  String get copyAddress;

  /// No description provided for @copied.
  ///
  /// In en, this message translates to:
  /// **'Copied'**
  String get copied;

  /// No description provided for @openFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to open this link. You can copy the address instead.'**
  String get openFailed;

  /// No description provided for @faqReportTitle.
  ///
  /// In en, this message translates to:
  /// **'Where are my readings?'**
  String get faqReportTitle;

  /// No description provided for @faqReportBody.
  ///
  /// In en, this message translates to:
  /// **'Open Readings to view your saved reports. Use the same account and language. Example readings are labelled separately and do not represent a personal calculation.'**
  String get faqReportBody;

  /// No description provided for @faqChatTitle.
  ///
  /// In en, this message translates to:
  /// **'Can I continue an earlier chat?'**
  String get faqChatTitle;

  /// No description provided for @faqChatBody.
  ///
  /// In en, this message translates to:
  /// **'Use the same browser or app installation and choose the same guardian. Guests may lose access after clearing app data or reinstalling. Saved memories can be reviewed and removed in Bonds.'**
  String get faqChatBody;

  /// No description provided for @faqPurchaseTitle.
  ///
  /// In en, this message translates to:
  /// **'Paid but still locked?'**
  String get faqPurchaseTitle;

  /// No description provided for @faqPurchaseBody.
  ///
  /// In en, this message translates to:
  /// **'Do not buy again while verification is pending. Open Purchases & restore and retry verification, then refresh your report. Restoring requests a store check; only the server can confirm access.'**
  String get faqPurchaseBody;

  /// No description provided for @licenses.
  ///
  /// In en, this message translates to:
  /// **'Open-source licenses'**
  String get licenses;

  /// No description provided for @deleteAccountBody.
  ///
  /// In en, this message translates to:
  /// **'This permanently removes the current account and associated profile, conversations and memories from the service. Data required for transaction records may be retained. Deletion does not issue a refund. A guest session cannot be recovered after deletion.'**
  String get deleteAccountBody;

  /// No description provided for @deleteUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Account deletion is not available from the service yet. Nothing has been deleted. Clearing local information or signing out does not delete your account.'**
  String get deleteUnavailable;

  /// No description provided for @deleteAcknowledge.
  ///
  /// In en, this message translates to:
  /// **'I understand that this cannot be undone.'**
  String get deleteAcknowledge;

  /// No description provided for @deleteNow.
  ///
  /// In en, this message translates to:
  /// **'Permanently delete'**
  String get deleteNow;

  /// No description provided for @deleteSuccess.
  ///
  /// In en, this message translates to:
  /// **'Account deletion confirmed.'**
  String get deleteSuccess;

  /// No description provided for @deleteFailure.
  ///
  /// In en, this message translates to:
  /// **'Deletion was not confirmed. Your session has been kept. Please retry or contact support.'**
  String get deleteFailure;

  /// No description provided for @clearHistory.
  ///
  /// In en, this message translates to:
  /// **'Clear conversations'**
  String get clearHistory;

  /// No description provided for @clearHistoryBody.
  ///
  /// In en, this message translates to:
  /// **'This deletes your conversation history from the service for all four guardians. Saved memories remain in Bonds and can be deleted there. This cannot be undone.'**
  String get clearHistoryBody;

  /// No description provided for @clearHistoryDone.
  ///
  /// In en, this message translates to:
  /// **'Conversation history cleared.'**
  String get clearHistoryDone;

  /// No description provided for @contentReport.
  ///
  /// In en, this message translates to:
  /// **'Report content'**
  String get contentReport;

  /// No description provided for @contentReportIntro.
  ///
  /// In en, this message translates to:
  /// **'Tell us what is wrong with this AI response. Only its reference and the details you enter are included; your full conversation is not attached.'**
  String get contentReportIntro;

  /// No description provided for @reportReason.
  ///
  /// In en, this message translates to:
  /// **'Reason'**
  String get reportReason;

  /// No description provided for @reasonHarmful.
  ///
  /// In en, this message translates to:
  /// **'Harmful or unsafe'**
  String get reasonHarmful;

  /// No description provided for @reasonSexual.
  ///
  /// In en, this message translates to:
  /// **'Sexual content'**
  String get reasonSexual;

  /// No description provided for @reasonHate.
  ///
  /// In en, this message translates to:
  /// **'Hate or harassment'**
  String get reasonHate;

  /// No description provided for @reasonPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Personal information'**
  String get reasonPrivacy;

  /// No description provided for @reasonMisleading.
  ///
  /// In en, this message translates to:
  /// **'Misleading advice'**
  String get reasonMisleading;

  /// No description provided for @reasonOther.
  ///
  /// In en, this message translates to:
  /// **'Something else'**
  String get reasonOther;

  /// No description provided for @reportDetails.
  ///
  /// In en, this message translates to:
  /// **'More details (optional)'**
  String get reportDetails;

  /// No description provided for @reportSend.
  ///
  /// In en, this message translates to:
  /// **'Submit report'**
  String get reportSend;

  /// No description provided for @reportUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Reporting is temporarily unavailable. No report has been sent. You can try again later or check Help & support.'**
  String get reportUnavailable;

  /// No description provided for @reportReceived.
  ///
  /// In en, this message translates to:
  /// **'Report received · {receipt}'**
  String reportReceived(String receipt);

  /// No description provided for @purchaseCenter.
  ///
  /// In en, this message translates to:
  /// **'Purchases & restore'**
  String get purchaseCenter;

  /// No description provided for @purchaseCenterIntro.
  ///
  /// In en, this message translates to:
  /// **'Check access and recover an existing purchase.'**
  String get purchaseCenterIntro;

  /// No description provided for @restoreCheck.
  ///
  /// In en, this message translates to:
  /// **'Checking your purchases…'**
  String get restoreCheck;

  /// No description provided for @restoreChecked.
  ///
  /// In en, this message translates to:
  /// **'The store check has finished. Refresh your reports to see server-confirmed access. This message is not a purchase confirmation.'**
  String get restoreChecked;

  /// No description provided for @verifiedContent.
  ///
  /// In en, this message translates to:
  /// **'Your report library'**
  String get verifiedContent;

  /// No description provided for @verifiedContentIntro.
  ///
  /// In en, this message translates to:
  /// **'Open a report to see its current access. A saved report or example does not by itself mean it has been purchased.'**
  String get verifiedContentIntro;

  /// No description provided for @reportLeave.
  ///
  /// In en, this message translates to:
  /// **'Discard this report draft?'**
  String get reportLeave;

  /// No description provided for @serviceRetry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get serviceRetry;

  /// No description provided for @deleteCleanup.
  ///
  /// In en, this message translates to:
  /// **'The server confirmed deletion, but some local data could not be cleared. Sign-in has been cleared from memory; clear this app’s storage on this device.'**
  String get deleteCleanup;

  /// No description provided for @storeBuy.
  ///
  /// In en, this message translates to:
  /// **'Buy in the store'**
  String get storeBuy;

  /// No description provided for @restoreUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Restore is unavailable on this device or account. Use a supported device with the original store and FATE account.'**
  String get restoreUnavailable;

  /// No description provided for @calendarTitle.
  ///
  /// In en, this message translates to:
  /// **'Astrology calendar'**
  String get calendarTitle;

  /// No description provided for @calendarOpen.
  ///
  /// In en, this message translates to:
  /// **'View calendar'**
  String get calendarOpen;

  /// No description provided for @calendarToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get calendarToday;

  /// No description provided for @calendarSubtitle.
  ///
  /// In en, this message translates to:
  /// **'A little space to plan your days'**
  String get calendarSubtitle;

  /// No description provided for @calendarYears.
  ///
  /// In en, this message translates to:
  /// **'B.E. {be} · C.E. {ce}'**
  String calendarYears(int be, int ce);

  /// No description provided for @calendarSmallEra.
  ///
  /// In en, this message translates to:
  /// **'Chula Sakarat {year}'**
  String calendarSmallEra(int year);

  /// No description provided for @calendarSelectHint.
  ///
  /// In en, this message translates to:
  /// **'Choose a date to explore its five details'**
  String get calendarSelectHint;

  /// No description provided for @calendarLoading.
  ///
  /// In en, this message translates to:
  /// **'Opening your calendar…'**
  String get calendarLoading;

  /// No description provided for @calendarUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This month could not be loaded. Please try again.'**
  String get calendarUnavailable;

  /// No description provided for @calendarRange.
  ///
  /// In en, this message translates to:
  /// **'Available offline · {start}–{end} C.E.'**
  String calendarRange(int start, int end);

  /// No description provided for @calendarOutOfRange.
  ///
  /// In en, this message translates to:
  /// **'This date is outside the available calendar.'**
  String get calendarOutOfRange;

  /// No description provided for @calendarWanPhra.
  ///
  /// In en, this message translates to:
  /// **'Buddhist observance'**
  String get calendarWanPhra;

  /// No description provided for @calendarKalayokTitle.
  ///
  /// In en, this message translates to:
  /// **'Kalayok · day indications'**
  String get calendarKalayokTitle;

  /// No description provided for @calendarFlag.
  ///
  /// In en, this message translates to:
  /// **'{kind, select, thongchai{Thongchai · victory} athibodi{Athibodi · authority} ubat{Ubat · caution} other{Lokawinas · caution}}'**
  String calendarFlag(String kind);

  /// No description provided for @calendarFlagBody.
  ///
  /// In en, this message translates to:
  /// **'{kind, select, thongchai{Traditionally associated with a new beginning.} athibodi{Traditionally associated with leading and organising.} ubat{Traditionally a day to review plans with care.} other{Traditionally a day to avoid rushing major commitments.}}'**
  String calendarFlagBody(String kind);

  /// No description provided for @calendarNoKalayok.
  ///
  /// In en, this message translates to:
  /// **'No Kalayok day indication'**
  String get calendarNoKalayok;

  /// No description provided for @calendarMixedNote.
  ///
  /// In en, this message translates to:
  /// **'More than one tradition applies today; all indications are shown.'**
  String get calendarMixedNote;

  /// No description provided for @calendarLunarTitle.
  ///
  /// In en, this message translates to:
  /// **'Lunar day'**
  String get calendarLunarTitle;

  /// No description provided for @calendarRiangMon.
  ///
  /// In en, this message translates to:
  /// **'Dithi Riang Mon'**
  String get calendarRiangMon;

  /// No description provided for @calendarRiangMonBody.
  ///
  /// In en, this message translates to:
  /// **'A lunar date traditionally considered when choosing a wedding day.'**
  String get calendarRiangMonBody;

  /// No description provided for @calendarLunarOrdinary.
  ///
  /// In en, this message translates to:
  /// **'Not a Dithi Riang Mon date.'**
  String get calendarLunarOrdinary;

  /// No description provided for @calendarUbakong.
  ///
  /// In en, this message translates to:
  /// **'Ubakong · good hours'**
  String get calendarUbakong;

  /// No description provided for @calendarDaylight.
  ///
  /// In en, this message translates to:
  /// **'Daytime · 06:00–18:00 · Bangkok'**
  String get calendarDaylight;

  /// No description provided for @calendarMansion.
  ///
  /// In en, this message translates to:
  /// **'The 27 lunar mansions'**
  String get calendarMansion;

  /// No description provided for @calendarMansionPosition.
  ///
  /// In en, this message translates to:
  /// **'Mansion {index} of 27 · quarter {quarter}'**
  String calendarMansionPosition(int index, int quarter);

  /// No description provided for @calendarMansionReference.
  ///
  /// In en, this message translates to:
  /// **'Moon position at Bangkok noon; the mansion may change within the day.'**
  String get calendarMansionReference;

  /// No description provided for @calendarReference.
  ///
  /// In en, this message translates to:
  /// **'Traditional Thai calendar · for cultural reference and entertainment.'**
  String get calendarReference;

  /// No description provided for @calendarLunarShort.
  ///
  /// In en, this message translates to:
  /// **'{phase, select, waxing{W} other{D}}{day}'**
  String calendarLunarShort(String phase, int day);

  /// No description provided for @calendarMonth.
  ///
  /// In en, this message translates to:
  /// **'{month, select, 1{January} 2{February} 3{March} 4{April} 5{May} 6{June} 7{July} 8{August} 9{September} 10{October} 11{November} 12{December} other{}}'**
  String calendarMonth(String month);

  /// No description provided for @calendarMansionName.
  ///
  /// In en, this message translates to:
  /// **'{index, select, 1{Ashwini} 2{Bharani} 3{Krittika} 4{Rohini} 5{Mrigashira} 6{Ardra} 7{Punarvasu} 8{Pushya} 9{Ashlesha} 10{Magha} 11{Purva Phalguni} 12{Uttara Phalguni} 13{Hasta} 14{Chitra} 15{Swati} 16{Vishakha} 17{Anuradha} 18{Jyeshtha} 19{Mula} 20{Purva Ashadha} 21{Uttara Ashadha} 22{Shravana} 23{Dhanishta} 24{Shatabhisha} 25{Purva Bhadrapada} 26{Uttara Bhadrapada} 27{Revati} other{}}'**
  String calendarMansionName(String index);

  /// No description provided for @estimated.
  ///
  /// In en, this message translates to:
  /// **'Estimated'**
  String get estimated;

  /// No description provided for @estimatedChart.
  ///
  /// In en, this message translates to:
  /// **'Estimated chart · 12:00 local time'**
  String get estimatedChart;

  /// No description provided for @estimatedChartNote.
  ///
  /// In en, this message translates to:
  /// **'No exact birth time was provided. This chart uses 12:00 local time at your birthplace. The Moon, ascendant, houses and aspects are estimates and may change with your actual birth time. Add your time to recalculate.'**
  String get estimatedChartNote;

  /// No description provided for @readingChart.
  ///
  /// In en, this message translates to:
  /// **'The chart behind this reading'**
  String get readingChart;

  /// No description provided for @readingChartIntro.
  ///
  /// In en, this message translates to:
  /// **'The reading below is based on this natal chart. Tap a planet to see its position.'**
  String get readingChartIntro;

  /// No description provided for @readingContents.
  ///
  /// In en, this message translates to:
  /// **'In this reading'**
  String get readingContents;

  /// No description provided for @readingContentsHint.
  ///
  /// In en, this message translates to:
  /// **'Choose a topic to jump to that section.'**
  String get readingContentsHint;

  /// No description provided for @backToChart.
  ///
  /// In en, this message translates to:
  /// **'Back to my chart'**
  String get backToChart;

  /// No description provided for @savedReadings.
  ///
  /// In en, this message translates to:
  /// **'Reading history'**
  String get savedReadings;

  /// No description provided for @noSavedReports.
  ///
  /// In en, this message translates to:
  /// **'No reports yet'**
  String get noSavedReports;

  /// No description provided for @reportRecords.
  ///
  /// In en, this message translates to:
  /// **'Report records'**
  String get reportRecords;

  /// No description provided for @reportRecordsIntro.
  ///
  /// In en, this message translates to:
  /// **'Reports are sorted by generation time. Search by report number to find a record.'**
  String get reportRecordsIntro;

  /// No description provided for @searchReportNumber.
  ///
  /// In en, this message translates to:
  /// **'Search by report number'**
  String get searchReportNumber;

  /// No description provided for @clearSearch.
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get clearSearch;

  /// No description provided for @noMatchingReports.
  ///
  /// In en, this message translates to:
  /// **'No report matches this number. Check the number and try again.'**
  String get noMatchingReports;

  /// No description provided for @reportNumberLabel.
  ///
  /// In en, this message translates to:
  /// **'Report number'**
  String get reportNumberLabel;

  /// No description provided for @generatedAt.
  ///
  /// In en, this message translates to:
  /// **'Generated on'**
  String get generatedAt;

  /// No description provided for @reportReady.
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get reportReady;

  /// No description provided for @reportRunning.
  ///
  /// In en, this message translates to:
  /// **'Generating'**
  String get reportRunning;

  /// No description provided for @reportFailedShort.
  ///
  /// In en, this message translates to:
  /// **'Not completed'**
  String get reportFailedShort;

  /// No description provided for @deleteReport.
  ///
  /// In en, this message translates to:
  /// **'Delete report'**
  String get deleteReport;

  /// No description provided for @deleteReportConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete this report record? You will no longer be able to open it from your records.'**
  String get deleteReportConfirm;

  /// No description provided for @reportDeleted.
  ///
  /// In en, this message translates to:
  /// **'Report record deleted'**
  String get reportDeleted;

  /// No description provided for @deleteReportFailed.
  ///
  /// In en, this message translates to:
  /// **'The report was kept because deletion failed. Please try again later.'**
  String get deleteReportFailed;

  /// No description provided for @reportDeleteBusy.
  ///
  /// In en, this message translates to:
  /// **'This report is still generating. Wait until it finishes before deleting it.'**
  String get reportDeleteBusy;

  /// No description provided for @loadReportsFailed.
  ///
  /// In en, this message translates to:
  /// **'Report records could not be loaded. Please try again.'**
  String get loadReportsFailed;

  /// No description provided for @refreshRecords.
  ///
  /// In en, this message translates to:
  /// **'Reload records'**
  String get refreshRecords;

  /// No description provided for @chartReportsLocation.
  ///
  /// In en, this message translates to:
  /// **'Chart readings have their own page. Open Chart to read yours.'**
  String get chartReportsLocation;

  /// No description provided for @progressTitle.
  ///
  /// In en, this message translates to:
  /// **'Creating your reading'**
  String get progressTitle;

  /// No description provided for @progressIntro.
  ///
  /// In en, this message translates to:
  /// **'Six topics are being prepared and checked. Your reading will open automatically when it is ready.'**
  String get progressIntro;

  /// No description provided for @progressPreparing.
  ///
  /// In en, this message translates to:
  /// **'Preparing your chart details'**
  String get progressPreparing;

  /// No description provided for @progressWriting.
  ///
  /// In en, this message translates to:
  /// **'Writing your personal reading'**
  String get progressWriting;

  /// No description provided for @progressChecking.
  ///
  /// In en, this message translates to:
  /// **'Checking the complete report'**
  String get progressChecking;

  /// No description provided for @progressRefining.
  ///
  /// In en, this message translates to:
  /// **'Refining your reading and advice'**
  String get progressRefining;

  /// No description provided for @progressComplete.
  ///
  /// In en, this message translates to:
  /// **'Your report is ready. Opening it now'**
  String get progressComplete;

  /// No description provided for @progressFailed.
  ///
  /// In en, this message translates to:
  /// **'Your reading is not complete yet'**
  String get progressFailed;

  /// No description provided for @progressTopics.
  ///
  /// In en, this message translates to:
  /// **'{completed} of {total} topics prepared'**
  String progressTopics(Object completed, Object total);

  /// No description provided for @progressReturn.
  ///
  /// In en, this message translates to:
  /// **'Return to report'**
  String get progressReturn;

  /// No description provided for @progressReconnect.
  ///
  /// In en, this message translates to:
  /// **'Reconnect'**
  String get progressReconnect;

  /// No description provided for @progressDisconnected.
  ///
  /// In en, this message translates to:
  /// **'The latest progress is temporarily unavailable. Your background task has not been cancelled. Reconnect or come back later.'**
  String get progressDisconnected;

  /// No description provided for @progressLater.
  ///
  /// In en, this message translates to:
  /// **'Come back later'**
  String get progressLater;

  /// No description provided for @progressPersonality.
  ///
  /// In en, this message translates to:
  /// **'Personality and strengths'**
  String get progressPersonality;

  /// No description provided for @progressCareer.
  ///
  /// In en, this message translates to:
  /// **'Career development'**
  String get progressCareer;

  /// No description provided for @progressMoney.
  ///
  /// In en, this message translates to:
  /// **'Money habits'**
  String get progressMoney;

  /// No description provided for @progressRelationships.
  ///
  /// In en, this message translates to:
  /// **'Relationships and family'**
  String get progressRelationships;

  /// No description provided for @progressWatch.
  ///
  /// In en, this message translates to:
  /// **'Patterns to watch'**
  String get progressWatch;

  /// No description provided for @progressActions.
  ///
  /// In en, this message translates to:
  /// **'Practical next steps'**
  String get progressActions;

  /// No description provided for @reportServiceBusy.
  ///
  /// In en, this message translates to:
  /// **'The reading service is temporarily busy, so your report is not ready yet. Your chart has been saved. Please try again later.'**
  String get reportServiceBusy;

  /// No description provided for @reportServiceTimeout.
  ///
  /// In en, this message translates to:
  /// **'The reading request timed out before your report was ready. Your chart has been saved. Please try again later.'**
  String get reportServiceTimeout;
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
      <String>['en', 'th', 'vi', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'th':
      return AppLocalizationsTh();
    case 'vi':
      return AppLocalizationsVi();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
