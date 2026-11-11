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
  /// **'Birth time is unknown. The ascendant and time-dependent houses are not displayed.'**
  String get unknownTime;

  /// No description provided for @chartRead.
  ///
  /// In en, this message translates to:
  /// **'Read this chart'**
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
  /// **'Drafts and access credentials stay on this device. Birth details, charts and reports belong to your current guest session or account. RoxyAPI calculates charts; the AI service receives chart facts without your name, city text or chat history. Clearing local details does not delete server records.'**
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
  /// **'This reading could not be completed. Return to Reports and generate it again. Sample content will never replace your result.'**
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
