// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get h5CodeLogin => 'Sign in with a web code';

  @override
  String get h5CodeHelp =>
      'Enter the six-character code shown on the H5 report screen to sync that browser’s reports.';

  @override
  String get h5CodeField => 'Web sign-in code';

  @override
  String get h5CodeInvalid =>
      'This code is invalid, expired or already used. Get a new code on H5.';

  @override
  String get h5CodeRateLimited =>
      'Too many attempts. Try again in a few minutes.';

  @override
  String get h5Account => 'Web account';

  @override
  String get h5Reports => 'Reports from H5';

  @override
  String get h5ReportsEmpty => 'This browser has no reports yet.';

  @override
  String get h5LoadMore => 'Load older reports';

  @override
  String get h5Refresh => 'Refresh reports';

  @override
  String get h5ReportUnavailable =>
      'This report could not be loaded. Refresh or view it on H5.';

  @override
  String get h5ReportQueued => 'Unlocked · In queue';

  @override
  String get h5ReportGenerating => 'Unlocked · Generating';

  @override
  String get h5ReportLimited => 'Unlocked · Generation limit reached';

  @override
  String get h5ReportIncomplete => 'Unlocked · Report unfinished';

  @override
  String get h5ReportLimitedHelp =>
      'Completed chapters are available. Return to the original web page to continue generating the report later.';

  @override
  String get h5Plan => 'Action plan';

  @override
  String get h5Insight => 'Insights';

  @override
  String get h5Watchpoint => 'What to watch for';

  @override
  String get h5Example => 'Everyday example';

  @override
  String get h5Pitfall => 'What to avoid';

  @override
  String get h5Check => 'How to check your progress';

  @override
  String get actionTodo => 'To do';

  @override
  String get actionReviewAvailable => 'Ready to review';

  @override
  String get actionTypeService => 'Help and share knowledge';

  @override
  String get actionTypePractice => 'Personal practice';

  @override
  String get actionCompleted => 'Completed';

  @override
  String get newVisitorNote => 'Choose a reader to begin';

  @override
  String get returningVisitorNote => 'Continue with a previous reading';

  @override
  String get todayTab => 'Today';

  @override
  String get actionTab => 'Actions';

  @override
  String get liveTab => 'Live';

  @override
  String get objectsTab => 'Objects';

  @override
  String get todayQuestion => 'What would you like to explore today?';

  @override
  String get todayNote => 'Three ways to find clarity';

  @override
  String get thaiGuide => 'Thai astrology';

  @override
  String get sevenGuide => 'Seven characters';

  @override
  String get tarotGuide => 'Tarot reading';

  @override
  String get sirin => 'Sirin';

  @override
  String get arun => 'Arun';

  @override
  String get mira => 'Mira';

  @override
  String get sirinFocus => 'Fortune · Year ahead';

  @override
  String get arunFocus => 'Character · Life rhythms';

  @override
  String get miraFocus => 'The present · The next step';

  @override
  String get sirinHint => 'Explore your timing for the next step.';

  @override
  String get arunHint => 'Explore your rhythms through birth numbers.';

  @override
  String get miraHint => 'Bring a question and see what the cards say.';

  @override
  String get startThaiGuide => 'Enter birth details to begin';

  @override
  String get viewThaiGuide => 'View my Thai chart';

  @override
  String get startSevenGuide => 'Preview seven-character readings';

  @override
  String get startTarotGuide => 'Start a tarot reading';

  @override
  String get textReading => 'Text reading';

  @override
  String get textReadingNote => 'Ask and keep talking';

  @override
  String get voiceReading => 'Voice chat';

  @override
  String get voiceReadingNote => 'Talk through your question';

  @override
  String get textChat => 'Text chat';

  @override
  String get voiceChat => 'Voice chat';

  @override
  String get voicePreviewNotice =>
      'Voice chat is unavailable in this preview. You can continue by text.';

  @override
  String guideChatHeading(String name) {
    return 'Talk it through with $name';
  }

  @override
  String get startReading => 'Start reading';

  @override
  String get guideChatDemo =>
      'Demo chat · Replies and history stay on this device';

  @override
  String get guideGreeting => 'What’s on your mind today?';

  @override
  String get guidePromptWork => 'I feel unsure about work';

  @override
  String get guidePromptLove => 'Should I take the lead in my relationship?';

  @override
  String get guideWorkReply =>
      'Separate what you know from what you’re waiting for. What could you clarify this week?';

  @override
  String get guideLoveReply =>
      'What would you like the other person to know? Start with a simple hello and notice how you feel.';

  @override
  String guideReflectReply(String question) {
    return 'Think about what you can control in “$question”. What’s one thing you could do in ten minutes?';
  }

  @override
  String get continueSample => 'Continue with your example reading';

  @override
  String get readingSampleQuestion =>
      'I’m waiting to hear back about work. What can I do this week?';

  @override
  String get readingSampleLove => 'What’s the next step in this relationship?';

  @override
  String get readingSampleLife => 'My routine changed. Where should I start?';

  @override
  String get recoverReports => 'My reports';

  @override
  String get recentReadings => 'Recent readings';

  @override
  String get reportLookup => 'Report link or code';

  @override
  String get findReport => 'Look up';

  @override
  String get reportLookupDemo =>
      'Use an example code here. Personal reports are in your report library.';

  @override
  String get reportCodeMissing => 'Example not found. Try FATE-THAI-001.';

  @override
  String get newVisitor => 'I’m new here';

  @override
  String get returningVisitor => 'I’m returning';

  @override
  String get guideWelcomeLabel => 'Three readers · Three traditions';

  @override
  String get guideWelcomeTitle => 'A conversation\nwith destiny.';

  @override
  String get guideWelcomeNote =>
      'Start with one question and see where you stand.';

  @override
  String get onAirNow => 'On air now';

  @override
  String get demo => 'Demo';

  @override
  String get allItems => 'All';

  @override
  String get templeRoom => 'Temple blessing';

  @override
  String get templeTeaser => 'Temple ceremony';

  @override
  String get objectsRoom => 'Objects unboxing';

  @override
  String get templeTeaserNote => 'Watch the ritual';

  @override
  String get objectsTeaserNote => 'See how it’s used';

  @override
  String get templeRoomNote => 'Partner Temple A · Example';

  @override
  String get switchRoom => 'Switch room';

  @override
  String get templePosterTitle => 'One wish,\none special encounter';

  @override
  String get objectsPosterTitle => 'Bring a little intention\ninto every day';

  @override
  String get liveDemoNotice => 'Live preview · Illustrative scenes';

  @override
  String get livestreamPause => 'Pause preview';

  @override
  String get livestreamPlay => 'Play preview';

  @override
  String get fullScreenPreview => 'Enlarge preview';

  @override
  String get templeRoomHeading => 'Bring your wish to the temple';

  @override
  String get templeService => 'Personal blessing';

  @override
  String get samplePrice => 'Sample price';

  @override
  String get bookingInfo => 'Booking information';

  @override
  String get bookingDemoNotice =>
      'Preview the ceremony and booking steps. Actual dates are pending.';

  @override
  String get roomChat => 'Room chat';

  @override
  String get ceremonyInfo => 'About the ceremony';

  @override
  String get roomObjectsInfo => 'Featured objects';

  @override
  String get roomWelcomeDemo =>
      'Host · Demo    Welcome. Take a look at the room details below.';

  @override
  String get templeSegmentOne => 'Write down your wish';

  @override
  String get templeSegmentTwo => 'Learn about the blessing ritual';

  @override
  String get templeSegmentThree => 'Keep a record of your wish';

  @override
  String get roomMessageHint => 'Try a local chat message';

  @override
  String get myActions => 'My actions';

  @override
  String get actionPending => 'To do';

  @override
  String get actionDone => 'Completed';

  @override
  String get actionReady => 'Ready to review';

  @override
  String get chooseFamilyAction => 'Plan a day for family';

  @override
  String get weeklyMoment => 'Set aside a day for action';

  @override
  String get weeklyMomentNote =>
      'Pick one day a week for a few small acts. Keep it flexible.';

  @override
  String get myWeeklyDay => 'My action day';

  @override
  String get arrangeDay => 'Set a day';

  @override
  String get actionLedger => 'My action journal';

  @override
  String get actionDailySuggestion => 'Today\'s suggestion';

  @override
  String get actionUseSuggestion => 'Add this';

  @override
  String get actionCustomPlan => 'Set my own action';

  @override
  String get actionCompleteNow => 'Mark done';

  @override
  String get actionSuggestionThanks =>
      'Send a thank-you to someone who helped you';

  @override
  String get actionSuggestionCheckIn => 'Check in with a friend';

  @override
  String get actionSuggestionShare => 'Share something useful with someone';

  @override
  String get offeringEnergy => 'Action energy';

  @override
  String get offeringJasmine => 'Jasmine garland';

  @override
  String get offeringLotus => 'Lotus offering';

  @override
  String get offeringMarigold => 'Marigold garland';

  @override
  String offeringCollected(int count) {
    return 'Collected $count';
  }

  @override
  String offeringPerAction(int points) {
    return 'Complete an action to add $points energy.';
  }

  @override
  String get offeringPresenting => 'Presenting your offering…';

  @override
  String get offeringComplete => 'Offering presented';

  @override
  String get offeringBlessing =>
      'May your good deeds lift you up. May good fortune stay with you, and may your hopes come true.';

  @override
  String get offeringNext => 'Your next action starts a new offering.';

  @override
  String get newPlan => 'New plan';

  @override
  String get noActionPlan =>
      'The small things you choose to do will appear here.';

  @override
  String get actionRecord => 'My action record';

  @override
  String get actionTitle => 'What I want to do';

  @override
  String get careAction => 'Give someone a helping hand';

  @override
  String get familyAction => 'Do a few small things for family';

  @override
  String get actionCategory => 'Action type';

  @override
  String get beneficiary => 'Who it’s for';

  @override
  String get forSelf => 'Myself';

  @override
  String get forOthers => 'Someone nearby';

  @override
  String get forFamily => 'Family';

  @override
  String get recordMethod => 'Recording method';

  @override
  String get recordOnDevice => 'Notes on this device';

  @override
  String get actionDate => 'Action date';

  @override
  String get reviewDate => 'Review date';

  @override
  String get actionNotes => 'What I did';

  @override
  String get actionReview => 'My reflection on this action';

  @override
  String get questionProgress => 'What changed about the original question?';

  @override
  String get actionReviewed => 'Reviewed';

  @override
  String get recordAction => 'Save a small action';

  @override
  String get clearPrototypeRecords => 'Clear local actions and demo chats';

  @override
  String get storeTitle => 'Objects with intention';

  @override
  String get storeIntro => 'Bring the things you love into everyday life.';

  @override
  String get storeSearch => 'Search journals, scents, jewelry…';

  @override
  String get scentCategory => 'Fragrance';

  @override
  String get jewelryCategory => 'Jewelry';

  @override
  String get journalCategory => 'Journals';

  @override
  String get lifeCategory => 'Living';

  @override
  String get sampleCatalog => 'Sample catalog';

  @override
  String get objectJournal => 'Action journal';

  @override
  String get objectCandle => 'Evening candle';

  @override
  String get objectBracelet => 'Wish bracelet';

  @override
  String get objectDiffuser => 'Morning diffuser';

  @override
  String get objectJournalNote => 'Turn a wish into a next step';

  @override
  String get objectCandleNote => 'Give yourself a quiet moment';

  @override
  String get objectBraceletNote => 'Carry a little wish with you';

  @override
  String get objectDiffuserNote => 'Start the day with a familiar scent';

  @override
  String get shopOrders => 'My orders';

  @override
  String get shopCart => 'Cart';

  @override
  String get addToCart => 'Add to cart';

  @override
  String get cartEmpty => 'Your cart is empty';

  @override
  String get shopEmpty => 'No matching objects';

  @override
  String get shopOrdersEmpty => 'No object orders yet';

  @override
  String get shopDemoNotice =>
      'This sample shop is browsing-only. Orders are unavailable.';

  @override
  String get mySpace => 'My readings and records';

  @override
  String get mySpaceIntro => 'Find your reports, actions, and plans here.';

  @override
  String get actionsAndReviews => 'Actions & review';

  @override
  String get resumeCompanion => 'Continue your conversation';

  @override
  String get fortunePeriods => 'Today, week, month & year outlook';

  @override
  String get thaiChartIntro =>
      'See the Thai chart for your birth date, time, and place.';

  @override
  String get sevenPreviewNote =>
      'Seven-character calculations are unavailable in this preview. Try a demo conversation with Arun.';

  @override
  String get country => 'Country / region';

  @override
  String get countryTH => 'Thailand';

  @override
  String get countryCN => 'China';

  @override
  String get countryVN => 'Vietnam';

  @override
  String get countryUS => 'United States';

  @override
  String get noCityResults =>
      'No matching city. Try another name, or return to enter the place and timezone manually.';

  @override
  String get retryPurchase => 'Retry purchase verification';

  @override
  String get sampleLoveText =>
      'Mercury square Mars in this example invites a look at differences between speaking and acting. You may already have a solution while someone else still needs to feel understood. Reflect their concern first, then ask whether they want listening or suggestions.';

  @override
  String get sampleLoveAction =>
      'During the next disagreement, try: “I hear that you are concerned about… Have I understood?” Wait for confirmation, discuss one issue at a time, and agree who will do what and when to check in.';

  @override
  String get sampleWorkText =>
      'The Sun opposite Saturn in this example invites reflection on initiative and responsibility. Wanting to do well can make feedback feel like a verdict on your ability. Turn feedback into specific tasks you can change, rather than a judgment of yourself.';

  @override
  String get sampleWorkAction =>
      'Before starting, write the deliverable, deadline and reviewer. At the first review, ask for the two most useful changes. Record what improved after editing, so progress is based on completed work as well as recognition.';

  @override
  String get sampleMoneyText =>
      'Venus trine Neptune in this example invites reflection on beauty, experiences and an ideal lifestyle. Before buying, separate a practical use from the lifestyle you imagine it represents. This section concerns spending habits, not market or return forecasts.';

  @override
  String get sampleMoneyAction =>
      'Save an unplanned purchase without checking out. The next day, write its purpose, likely frequency of use and your remaining monthly budget. Agree how shared costs will be split before paying.';

  @override
  String get sunMeaning =>
      'The Sun represents how you express yourself and what gives you a sense of purpose.';

  @override
  String get moonMeaning =>
      'The Moon represents emotional needs and what helps you feel secure.';

  @override
  String get mercuryMeaning =>
      'Mercury represents habits of thinking, learning and communication.';

  @override
  String get venusMeaning =>
      'Venus represents what you appreciate and how you express affection and build relationships.';

  @override
  String get marsMeaning =>
      'Mars represents how you take action, pursue goals and handle disagreement.';

  @override
  String get jupiterMeaning =>
      'Jupiter represents learning, exploring opportunities and widening your perspective.';

  @override
  String get saturnMeaning =>
      'Saturn represents responsibility, boundaries and skills developed over time.';

  @override
  String get uranusMeaning =>
      'Uranus represents changing old habits and trying independent approaches.';

  @override
  String get neptuneMeaning =>
      'Neptune represents imagination, ideals and separating expectations from reality.';

  @override
  String get plutoMeaning =>
      'Pluto represents deep change, control and rebuilding a sense of strength.';

  @override
  String get home => 'Home';

  @override
  String get chart => 'Chart';

  @override
  String get reports => 'Reports';

  @override
  String get mine => 'My space';

  @override
  String get system => 'Western astrology';

  @override
  String get heroTitle => 'Read the stars.\nUnderstand yourself.';

  @override
  String get heroText =>
      'Explore personality, relationships, and direction through your birth moment.';

  @override
  String get heroBadge => 'Your own celestial story';

  @override
  String get start => 'Start my birth chart';

  @override
  String get birth => 'Birth details';

  @override
  String get birthNote => 'Your place and moment in time';

  @override
  String get birthIntro =>
      'Your date, time, and location help determine planets, the ascendant, and houses. You can edit them anytime.';

  @override
  String get chartNote => 'Planets · Signs · Houses';

  @override
  String get reportNote => 'Personality · Relationships · Work';

  @override
  String get fullReport => 'Full reading';

  @override
  String get fullNote => 'Practical advice and next steps';

  @override
  String get homeReportTitle => 'A reading about you';

  @override
  String get homeReportText =>
      'Understand your patterns, then explore choices in relationships, work, and money habits.';

  @override
  String get viewReport => 'Explore my reading';

  @override
  String get journey => 'Your exploration starts here';

  @override
  String get stepBirth => 'Add birth details';

  @override
  String get stepChart => 'Meet your birth chart';

  @override
  String get stepReport => 'Read your interpretation';

  @override
  String get example => 'View example chart';

  @override
  String get exampleReport => 'View example report';

  @override
  String get exampleBadge => 'Teaching example';

  @override
  String get exampleNote =>
      'This demonstrates the reading experience. It is not calculated from your birth details.';

  @override
  String get myChart => 'My birth chart';

  @override
  String get myChartText => 'Make your chart easier to understand.';

  @override
  String get noChart => 'Your chart starts with you';

  @override
  String get noChartText =>
      'Add birth details to explore your planets, signs, and houses.';

  @override
  String get waiting => 'Preparing your chart';

  @override
  String get unavailable => 'Western chart service is not ready';

  @override
  String get unavailableText =>
      'Your birth details are saved on this device. Explore an example, or request your result again later.';

  @override
  String get retry => 'Request my chart again';

  @override
  String get editBirth => 'Edit birth details';

  @override
  String get sun => 'Sun';

  @override
  String get moon => 'Moon';

  @override
  String get ascendant => 'Ascendant';

  @override
  String get planets => 'Planet positions';

  @override
  String get houses => 'Twelve houses';

  @override
  String get aspects => 'Major aspects';

  @override
  String get planetHint => 'Tap a planet to explore its role in the chart.';

  @override
  String get unknownTime =>
      'Without a birth time, an estimated chart uses 12:00 local time at your birthplace. You can add your time later.';

  @override
  String get chartRead => 'Full reading';

  @override
  String get house => 'House';

  @override
  String get emptyValue => 'Pending';

  @override
  String get reportTitle => 'Personal birth report';

  @override
  String get reportIntro =>
      'From your overall patterns to practical choices, explore one step at a time.';

  @override
  String get free => 'Free preview';

  @override
  String get premium => 'Full reading';

  @override
  String get reportEmpty => 'Your readings will live here';

  @override
  String get reportEmptyText =>
      'Create a personal birth chart to see its reading and report status.';

  @override
  String get generate => 'Create my report';

  @override
  String get summary => 'Start with the takeaway';

  @override
  String get traits => 'Patterns you may recognize';

  @override
  String get watch => 'What to watch for';

  @override
  String get advice => 'Steps you can try';

  @override
  String get reportScope => 'Inside this report';

  @override
  String get chapterPersonality => 'Personality and expression';

  @override
  String get chapterLove => 'Relationships and communication';

  @override
  String get chapterWork => 'Work and growth';

  @override
  String get chapterMoney => 'Money habits';

  @override
  String get reportSaved => 'Example saved';

  @override
  String get saveReport => 'Save example';

  @override
  String get savedReports => 'Examples saved on this device';

  @override
  String get openReport => 'Open report';

  @override
  String get remove => 'Remove';

  @override
  String get exampleSavedNote =>
      'Examples are stored separately from personal reports and never become your calculation results.';

  @override
  String get unlock => 'Read the full interpretation';

  @override
  String get lockedTitle => 'Explore your chart further';

  @override
  String get lockedText =>
      'The full reading includes specific watch points, everyday examples, and practical steps.';

  @override
  String get offerTitle => 'Unlock your birth report';

  @override
  String get offerText =>
      'A one-time purchase for the full report within the product\'s scope.';

  @override
  String get offerFeature1 => 'Personal patterns and four life topics';

  @override
  String get offerFeature2 => 'Watch points, examples, and practical advice';

  @override
  String get offerFeature3 => 'Revisit reports and restore purchases';

  @override
  String get appleBuy => 'Purchase in the iOS app';

  @override
  String get pricePending => 'Price is provided by the App Store';

  @override
  String get purchasePreview =>
      'This is a browser preview. Apple purchases are unavailable and no payment will be taken.';

  @override
  String get restore => 'Restore purchases';

  @override
  String get restoreNote =>
      'Restore in the iOS app with your original purchasing account. This browser cannot read Apple transactions.';

  @override
  String get previewFull => 'Preview the full example';

  @override
  String get previewFullNote =>
      'Only the teaching example is expanded. No purchase or personal report entitlement is created.';

  @override
  String get purchaseHistory => 'Purchased content';

  @override
  String get noPurchases => 'No verified purchases yet';

  @override
  String get noPurchasesText =>
      'Reports appear in your account after a purchase is verified in the iOS app.';

  @override
  String get account => 'My account';

  @override
  String get guest => 'Guest';

  @override
  String get signedIn => 'Signed in';

  @override
  String get accountText =>
      'Keep your details and reports, and return to your exploration.';

  @override
  String get deviceProfile => 'Birth details';

  @override
  String get language => 'Language';

  @override
  String get largeText => 'Larger text';

  @override
  String get privacy => 'Details and privacy';

  @override
  String get privacyText =>
      'Drafts and access credentials stay on this device. Birth details, charts and reports belong to your current guest session or account. RoxyAPI calculates charts; AI chart reports use chart facts without your name, city text or chat history.\n\nGuardian chat sends your messages, birth details, relevant conversations, confirmed memories and selected visible readings to the AI service for replies and continuity. Clearing local details does not delete server records.';

  @override
  String get clearBirth => 'Clear local birth details';

  @override
  String get clearConfirm => 'Clear birth details saved on this device?';

  @override
  String get cleared => 'Local birth details cleared';

  @override
  String get saved => 'Birth details saved';

  @override
  String get saveBirth => 'Save and view my chart';

  @override
  String get nickname => 'Preferred name (optional)';

  @override
  String get nicknamePlaceholder => 'What should we call you?';

  @override
  String get placeRequired => 'Choose or enter your birth location';

  @override
  String get close => 'Close';

  @override
  String get cancel => 'Cancel';

  @override
  String get back => 'Back';

  @override
  String get birthStorage =>
      'Create your chart and read your report without signing in. You can return to your results on this device.';

  @override
  String get profileMissing => 'No birth details yet';

  @override
  String get connection =>
      'The service is temporarily unavailable. Examples remain available.';

  @override
  String get error => 'We could not finish this. Please try again later.';

  @override
  String get sampleSummary =>
      'You may care about doing things well and having your ideas recognized. State your main point clearly, then leave room for cooperation.';

  @override
  String get sampleTrait1Title => 'You want a voice of your own';

  @override
  String get sampleTrait1Text =>
      'The example Sun in Leo offers a way to discuss expression and creativity. When a subject feels familiar, you may want to suggest a plan first. If it is not chosen, asking why can help more than rushing to prove yourself.';

  @override
  String get sampleTrait2Title => 'Balance freedom with responsibility';

  @override
  String get sampleTrait2Text =>
      'The example Moon\'s exploratory themes and the Sun–Saturn connection can prompt reflection on freedom and duty. Set aside clear rest time and write down commitments, giving both needs a place.';

  @override
  String get sampleWatch1Title => 'Different opinions need not reject you';

  @override
  String get sampleWatch1Text =>
      'When someone changes a plan or has not replied, check whether they question the method or the goal. Notice rushed explanations, interruptions, or repeated message checking. Ask, “Which part concerns you most?” before agreeing on what to change.';

  @override
  String get sampleWatch2Title => 'Leave room before making commitments';

  @override
  String get sampleWatch2Text =>
      'Wanting recognition can lead to accepting more than your time allows. Check your calendar, the effort involved, and existing commitments before answering. If unsure, say, “Let me check my schedule and get back to you tomorrow.”';

  @override
  String get sampleAdvice1Title => 'Prepare three sentences for a conversation';

  @override
  String get sampleAdvice1Text =>
      'Write the observable fact, your need, and one specific request. For example: “The plan changed twice this week. I need to confirm the direction. Could we use ten minutes to agree on priorities?” Pause for their response and record the agreement.';

  @override
  String get sampleAdvice2Title => 'Turn one goal into an action for today';

  @override
  String get sampleAdvice2Text =>
      'Choose one goal. List what you need, the first action, and how to check it. Spend twenty minutes on a small step, such as gathering three pieces of feedback or drafting an email. Check that step before choosing the next.';

  @override
  String get sampleAdvice3Title => 'Make room for a short weekly review';

  @override
  String get sampleAdvice3Text =>
      'At a regular time, record one useful experience, one difficult conversation, and one adjustment to try. Use actual events to see whether the advice fits. Leave aside or change approaches that do not help.';

  @override
  String get login => 'Sign in';

  @override
  String get logout => 'Sign out';

  @override
  String get register => 'Create account';

  @override
  String get username => 'Username';

  @override
  String get password => 'Password';

  @override
  String get confirmPassword => 'Confirm password';

  @override
  String get passwordMismatch => 'Passwords do not match';

  @override
  String get birthDate => 'Birth date';

  @override
  String get birthTime => 'Birth time';

  @override
  String get timezone => 'Birth timezone';

  @override
  String get birthplace => 'Birth city';

  @override
  String get birthplacePlaceholder => 'For example: Bangkok';

  @override
  String get pickerDone => 'Done';

  @override
  String get pickerCancel => 'Cancel selection';

  @override
  String get chooseBirthDate => 'Choose your birth date';

  @override
  String get chooseBirthTime => 'Choose your birth time';

  @override
  String get searchBirthCity => 'Search city or district';

  @override
  String get searchTimezone => 'Search time zones, e.g. Asia/Bangkok';

  @override
  String get appleLogin => 'Sign in with Apple';

  @override
  String get developmentLogin => 'Development test account';

  @override
  String get nativeSetup =>
      'This is a preview environment. Native sign-in and purchases require service configuration.';

  @override
  String get calendarGregorian => 'Gregorian';

  @override
  String get calendarBuddhist => 'Buddhist Era';

  @override
  String get timeUnknown => 'I do not know the exact time';

  @override
  String get reportPending =>
      'Your report is being generated. You can leave and return later.';

  @override
  String get resumeReport => 'Resume the latest report';

  @override
  String get loginRequired => 'Sign in before purchasing';

  @override
  String get serviceSetup =>
      'This service is not ready. You can explore a teaching example.';

  @override
  String get exactBirth => 'Known birth time';

  @override
  String get dateOnly => 'Date only';

  @override
  String get dataPrecision => 'Birth data precision';

  @override
  String get cityDirectory => 'Search the city directory';

  @override
  String get findCity => 'Find a city';

  @override
  String get deleteAccount => 'Delete account';

  @override
  String get deletionSetup =>
      'Account deletion must be enabled on the server before a request can be submitted.';

  @override
  String get aiConsent =>
      'To prepare the report, calculated chart facts will be sent to the AI service without your name, city text or chat history. Do you agree?';

  @override
  String get consentGenerate => 'Agree and generate';

  @override
  String get decline => 'Decline';

  @override
  String get purchaseVerifying =>
      'Your purchase is being verified. Refresh the report shortly.';

  @override
  String get personalReport => 'Personal report';

  @override
  String get missingAngles =>
      'Ascendant and houses are unavailable. Only supplied planet positions are shown.';

  @override
  String get languageHelp =>
      'Switch between Thai, English, Chinese and Vietnamese here.';

  @override
  String get continueChart => 'Continue my chart';

  @override
  String get pSun => 'Sun';

  @override
  String get pMoon => 'Moon';

  @override
  String get pMercury => 'Mercury';

  @override
  String get pVenus => 'Venus';

  @override
  String get pMars => 'Mars';

  @override
  String get pJupiter => 'Jupiter';

  @override
  String get pSaturn => 'Saturn';

  @override
  String get pUranus => 'Uranus';

  @override
  String get pNeptune => 'Neptune';

  @override
  String get pPluto => 'Pluto';

  @override
  String get zAries => 'Aries';

  @override
  String get zTaurus => 'Taurus';

  @override
  String get zGemini => 'Gemini';

  @override
  String get zCancer => 'Cancer';

  @override
  String get zLeo => 'Leo';

  @override
  String get zVirgo => 'Virgo';

  @override
  String get zLibra => 'Libra';

  @override
  String get zScorpio => 'Scorpio';

  @override
  String get zSagittarius => 'Sagittarius';

  @override
  String get zCapricorn => 'Capricorn';

  @override
  String get zAquarius => 'Aquarius';

  @override
  String get zPisces => 'Pisces';

  @override
  String get skipOpening => 'Skip intro';

  @override
  String get tarot => 'Tarot';

  @override
  String get luckyNumbers => 'Lucky numbers';

  @override
  String get tarotDraw => 'Draw three cards';

  @override
  String get tarotDrawHint =>
      'Think of a question, then choose three cards from the spread.';

  @override
  String tarotChooseCard(int position) {
    return 'Draw scattered card $position';
  }

  @override
  String get tarotResult => 'Your three cards';

  @override
  String get tarotDrawAgain => 'Draw again';

  @override
  String get todayLuckyNumber => 'Today’s lucky number';

  @override
  String get luckyNumberHint => 'A prompt for today';

  @override
  String get luckyNumberUpdates => 'Updates using your device’s local date';

  @override
  String get tarotFool => 'The Fool';

  @override
  String get tarotFoolMeaning =>
      'Try a new direction with one small step, leaving yourself room to adjust.';

  @override
  String get tarotMagician => 'The Magician';

  @override
  String get tarotMagicianMeaning =>
      'Take stock of the skills and tools you have, then act on one idea today.';

  @override
  String get tarotHighPriestess => 'The High Priestess';

  @override
  String get tarotHighPriestessMeaning =>
      'Give yourself a quiet moment to observe and listen to your instincts before acting.';

  @override
  String get tarotEmpress => 'The Empress';

  @override
  String get tarotEmpressMeaning =>
      'Make time for something that nourishes your creativity, and give yourself time to rest.';

  @override
  String get tarotEmperor => 'The Emperor';

  @override
  String get tarotEmperorMeaning =>
      'Set a clear goal and boundaries, then put your tasks in order of importance.';

  @override
  String get tarotHierophant => 'The Hierophant';

  @override
  String get tarotHierophantMeaning =>
      'Ask someone you trust for guidance, and keep the advice that fits your situation.';

  @override
  String get tarotLovers => 'The Lovers';

  @override
  String get tarotLoversMeaning =>
      'When making a choice, name what matters to you and communicate it honestly.';

  @override
  String get tarotChariot => 'The Chariot';

  @override
  String get tarotChariotMeaning =>
      'Pick one direction and focus your energy on the next step that matters most.';

  @override
  String get tarotStrength => 'Strength';

  @override
  String get tarotStrengthMeaning =>
      'When tension arises, take a moment to settle and respond with calm resolve.';

  @override
  String get tarotHermit => 'The Hermit';

  @override
  String get tarotHermitMeaning =>
      'Step away from outside opinions for a moment and reflect on what you want to know.';

  @override
  String get tarotWheelOfFortune => 'Wheel of Fortune';

  @override
  String get tarotWheelOfFortuneMeaning =>
      'Leave some flexibility in your plans and start with what you can control.';

  @override
  String get tarotJustice => 'Justice';

  @override
  String get tarotJusticeMeaning =>
      'Consider the facts and your feelings, then make a choice you can stand behind.';

  @override
  String get tarotHangedMan => 'The Hanged Man';

  @override
  String get tarotHangedManMeaning =>
      'If you feel stuck, pause and look at the situation from a different angle.';

  @override
  String get tarotDeath => 'Death';

  @override
  String get tarotDeathMeaning =>
      'Set aside something that has run its course to make room for a new habit or choice.';

  @override
  String get tarotTemperance => 'Temperance';

  @override
  String get tarotTemperanceMeaning =>
      'Make a small adjustment that gives two competing needs a little more balance.';

  @override
  String get tarotDevil => 'The Devil';

  @override
  String get tarotDevilMeaning =>
      'Notice a habit that takes too much of your energy and change one small part of it.';

  @override
  String get tarotTower => 'The Tower';

  @override
  String get tarotTowerMeaning =>
      'When a plan falls apart, deal with what is most urgent before making a new one.';

  @override
  String get tarotStar => 'The Star';

  @override
  String get tarotStarMeaning =>
      'Give yourself time to recharge and choose one small goal you still look forward to.';

  @override
  String get tarotMoon => 'The Moon';

  @override
  String get tarotMoonMeaning =>
      'If something feels unclear, check the information you have before drawing a conclusion.';

  @override
  String get tarotSun => 'The Sun';

  @override
  String get tarotSunMeaning =>
      'Take note of your progress and share a piece of good news with someone you trust.';

  @override
  String get tarotJudgement => 'Judgement';

  @override
  String get tarotJudgementMeaning =>
      'Reflect on a past choice, recognize what you learned, and decide what comes next.';

  @override
  String get tarotWorld => 'The World';

  @override
  String get tarotWorldMeaning =>
      'Close out a completed task, note what you gained, and prepare for the next stage.';

  @override
  String get luckyNumberOne =>
      'Start something new with one small action you can take today.';

  @override
  String get luckyNumberTwo =>
      'Make time for collaboration and listen to another point of view.';

  @override
  String get luckyNumberThree =>
      'Give an idea a voice by sharing it, writing it down, or making something.';

  @override
  String get luckyNumberFour =>
      'Set your priorities and begin with one task you can put into practice.';

  @override
  String get luckyNumberFive =>
      'Try a different approach and leave a little flexibility in your plan.';

  @override
  String get luckyNumberSix =>
      'Make time for the people you care about and look after yourself too.';

  @override
  String get luckyNumberSeven =>
      'Find a quiet moment to organize your thoughts and consider a question.';

  @override
  String get luckyNumberEight =>
      'Take one concrete step toward something worth pursuing over time.';

  @override
  String get luckyNumberNine =>
      'Tie up a loose end and let go of something that is already complete.';

  @override
  String get tarotDrawTitle => 'Draw Tarot';

  @override
  String tarotProgress(int count, int total) {
    return 'Drawn $count / $total';
  }

  @override
  String tarotCardPosition(int position) {
    return 'Card $position';
  }

  @override
  String tarotCardsRemaining(int count) {
    return 'Choose $count more from the spread';
  }

  @override
  String get tarotGestureHint => 'Tap a card or swipe up on it';

  @override
  String get tarotShuffle => 'Shuffle';

  @override
  String get tarotSeerWaiting => 'The astrologer is waiting for your question';

  @override
  String get tarotRevealing => 'Turning over your card…';

  @override
  String get tarotSeerReading =>
      'All three cards are ready. The astrologer is reading them.';

  @override
  String get tarotReadingComplete => 'Reading complete';

  @override
  String get tarotReadingStepOne => 'Listening to the stars…';

  @override
  String get tarotReadingStepTwo => 'The astrologer touches the glowing chart…';

  @override
  String get tarotReadingStepThree => 'Exploring the three cards…';

  @override
  String get tarotReadingStepFour => 'Writing your reading…';

  @override
  String tarotMinorName(String suit, String rank) {
    return '$rank of $suit';
  }

  @override
  String get tarotRankAce => 'Ace';

  @override
  String get tarotRankTwo => 'Two';

  @override
  String get tarotRankThree => 'Three';

  @override
  String get tarotRankFour => 'Four';

  @override
  String get tarotRankFive => 'Five';

  @override
  String get tarotRankSix => 'Six';

  @override
  String get tarotRankSeven => 'Seven';

  @override
  String get tarotRankEight => 'Eight';

  @override
  String get tarotRankNine => 'Nine';

  @override
  String get tarotRankTen => 'Ten';

  @override
  String get tarotRankPage => 'Page';

  @override
  String get tarotRankKnight => 'Knight';

  @override
  String get tarotRankQueen => 'Queen';

  @override
  String get tarotRankKing => 'King';

  @override
  String get tarotSuitWands => 'Wands';

  @override
  String get tarotWandsAceMeaning =>
      'Try a small step toward an idea that excites you.';

  @override
  String get tarotWandsTwoMeaning =>
      'Look at your options and decide which step to take next.';

  @override
  String get tarotWandsThreeMeaning =>
      'Look beyond your first success for a chance to build on it.';

  @override
  String get tarotWandsFourMeaning =>
      'Take time to celebrate something you have built with others.';

  @override
  String get tarotWandsFiveMeaning =>
      'When opinions clash, listen for the problem each person wants to solve.';

  @override
  String get tarotWandsSixMeaning =>
      'Acknowledge your progress and share credit with those who helped.';

  @override
  String get tarotWandsSevenMeaning =>
      'Decide which boundary matters and express it calmly.';

  @override
  String get tarotWandsEightMeaning =>
      'When things speed up, check the details and respond promptly.';

  @override
  String get tarotWandsNineMeaning =>
      'Protect your energy and make time to recover.';

  @override
  String get tarotWandsTenMeaning =>
      'Share a responsibility that has become too heavy to carry alone.';

  @override
  String get tarotWandsPageMeaning =>
      'Follow your curiosity with one small experiment.';

  @override
  String get tarotWandsKnightMeaning =>
      'Act on your enthusiasm with a plan for what comes after the first step.';

  @override
  String get tarotWandsQueenMeaning =>
      'Share your idea with confidence and invite others to contribute.';

  @override
  String get tarotWandsKingMeaning =>
      'Choose a direction people can work toward together.';

  @override
  String get tarotSuitCups => 'Cups';

  @override
  String get tarotCupsAceMeaning =>
      'Make room for a new feeling and let yourself express it.';

  @override
  String get tarotCupsTwoMeaning =>
      'Ask for what you need and leave room for the other person to respond.';

  @override
  String get tarotCupsThreeMeaning =>
      'Spend a moment with supportive people and share something worth celebrating.';

  @override
  String get tarotCupsFourMeaning =>
      'Notice what feels uninteresting, then look for an option you may have overlooked.';

  @override
  String get tarotCupsFiveMeaning =>
      'Give yourself time to feel the loss and notice what support remains.';

  @override
  String get tarotCupsSixMeaning =>
      'Revisit a small activity that once brought you comfort.';

  @override
  String get tarotCupsSevenMeaning =>
      'Separate ideas you can act on from ones you are still imagining.';

  @override
  String get tarotCupsEightMeaning =>
      'If a path no longer fits, consider what you want to move toward.';

  @override
  String get tarotCupsNineMeaning =>
      'Enjoy a wish that has come true and notice what need it met.';

  @override
  String get tarotCupsTenMeaning =>
      'Care for a relationship that gives you a sense of belonging.';

  @override
  String get tarotCupsPageMeaning =>
      'Put a new feeling into words without judging it.';

  @override
  String get tarotCupsKnightMeaning =>
      'Express what you feel and give the other person time to respond.';

  @override
  String get tarotCupsQueenMeaning =>
      'Listen with care and keep space for your own feelings.';

  @override
  String get tarotCupsKingMeaning =>
      'Let strong feelings settle before making a decision that affects others.';

  @override
  String get tarotSuitSwords => 'Swords';

  @override
  String get tarotSwordsAceMeaning =>
      'Find one fact you can check to make a complicated situation clearer.';

  @override
  String get tarotSwordsTwoMeaning =>
      'Consider the cost of each option before making a decision.';

  @override
  String get tarotSwordsThreeMeaning =>
      'Give a painful feeling some time and share it with someone you trust.';

  @override
  String get tarotSwordsFourMeaning =>
      'Pause and rest before you return to a hard problem.';

  @override
  String get tarotSwordsFiveMeaning =>
      'Ask whether winning an argument is worth what it might cost.';

  @override
  String get tarotSwordsSixMeaning =>
      'Focus on one next step away from a draining situation.';

  @override
  String get tarotSwordsSevenMeaning =>
      'Be clear about your motives and speak openly where you can.';

  @override
  String get tarotSwordsEightMeaning =>
      'Separate real limits from worries and look for one choice you still have.';

  @override
  String get tarotSwordsNineMeaning =>
      'Write down recurring worries and choose one you can address today.';

  @override
  String get tarotSwordsTenMeaning =>
      'Accept that one chapter has ended and put your energy into recovery.';

  @override
  String get tarotSwordsPageMeaning =>
      'Ask questions and check information before you pass it on.';

  @override
  String get tarotSwordsKnightMeaning =>
      'Act decisively and check your tone and facts before speaking.';

  @override
  String get tarotSwordsQueenMeaning =>
      'Be clear about the facts and your boundaries while staying open to a conversation.';

  @override
  String get tarotSwordsKingMeaning =>
      'Use a consistent standard and consider each point of view fairly.';

  @override
  String get tarotSuitPentacles => 'Pentacles';

  @override
  String get tarotPentaclesAceMeaning =>
      'Turn a practical opportunity into one action you can take.';

  @override
  String get tarotPentaclesTwoMeaning =>
      'Rebalance your time and resources when several demands compete.';

  @override
  String get tarotPentaclesThreeMeaning =>
      'Improve your work with people who bring different skills.';

  @override
  String get tarotPentaclesFourMeaning =>
      'Take stock of what you have and leave room for change.';

  @override
  String get tarotPentaclesFiveMeaning =>
      'Look for support and ask for it when you need it.';

  @override
  String get tarotPentaclesSixMeaning =>
      'Balance giving and receiving by being clear about expectations.';

  @override
  String get tarotPentaclesSevenMeaning =>
      'Give steady work time to grow and set a date to check your progress.';

  @override
  String get tarotPentaclesEightMeaning =>
      'Practice one skill and let small improvements add up.';

  @override
  String get tarotPentaclesNineMeaning =>
      'Recognize the stability and independence you have worked for.';

  @override
  String get tarotPentaclesTenMeaning =>
      'Consider what you can build now that will support you in the future.';

  @override
  String get tarotPentaclesPageMeaning =>
      'Choose a useful skill and take one step toward learning it.';

  @override
  String get tarotPentaclesKnightMeaning =>
      'Follow through on a small task you can do well today.';

  @override
  String get tarotPentaclesQueenMeaning =>
      'Care for yourself and others with something practical you can do today.';

  @override
  String get tarotPentaclesKingMeaning =>
      'Use the stability you have built to prepare for the next stage.';

  @override
  String get thaiCalendarTitle => 'Thai calendar today';

  @override
  String get thaiCalendarTimezone => 'Bangkok time';

  @override
  String thaiCalendarCivilDate(String date, int year) {
    return '$date · B.E. $year';
  }

  @override
  String thaiCalendarWaxing(int day) {
    return 'Waxing day $day';
  }

  @override
  String thaiCalendarWaning(int day) {
    return 'Waning day $day';
  }

  @override
  String thaiCalendarLunarMonth(int month) {
    return 'Lunar month $month';
  }

  @override
  String get thaiCalendarSecondEighth => 'Second lunar month 8';

  @override
  String get thaiCalendarAuspicious => 'Auspicious day';

  @override
  String get thaiCalendarCaution => 'Caution day';

  @override
  String get thaiCalendarMixed => 'Mixed indications';

  @override
  String get thaiCalendarOrdinary => 'Ordinary day';

  @override
  String thaiCalendarHours(String hours) {
    return 'Good hours $hours';
  }

  @override
  String get thaiCalendarDayRule =>
      'Kalayok day indications use the small-era year at Bangkok noon';

  @override
  String get thaiCalendarHourRule =>
      'Daytime periods from the traditional Ubakong weekday table';

  @override
  String get thaiCalendarLoading => 'Loading today’s Thai calendar…';

  @override
  String get thaiCalendarUnavailable => 'Today’s Thai calendar is unavailable';

  @override
  String get thaiCalendarLunarUnavailable => 'Lunar date unavailable for today';

  @override
  String get thaiCalendarRetry => 'Retry';

  @override
  String get dailyHoroscopeTitle => 'Daily horoscope';

  @override
  String dailyHoroscopeToday(String sign) {
    return '$sign today';
  }

  @override
  String get dailyHoroscopeMore => 'See more';

  @override
  String get dailyHoroscopeChooseSign => 'Choose a zodiac sign';

  @override
  String get dailyHoroscopeForecast => 'Today’s reading';

  @override
  String get dailyHoroscopeBasis =>
      'Based on Thai astrological transits and the Moon’s position. Updated by Bangkok date.';

  @override
  String get dailyHoroscopeLoading => 'Loading today’s horoscope…';

  @override
  String get dailyHoroscopeUnavailable => 'Today’s horoscope is unavailable';

  @override
  String get dailyHoroscopeLove => 'Love';

  @override
  String get dailyHoroscopeWork => 'Career';

  @override
  String get dailyHoroscopeMoney => 'Finances';

  @override
  String get dailyHoroscopeLoveShort => 'Love';

  @override
  String get dailyHoroscopeWorkShort => 'Work';

  @override
  String get dailyHoroscopeMoneyShort => 'Money';

  @override
  String get dailyHoroscopeHealth => 'Health';

  @override
  String dailyHoroscopeReading(String planet, int house, String advice) {
    return '$planet transits house $house. $advice';
  }

  @override
  String dailyHoroscopeLoveAdvice(String tone) {
    String _temp0 = intl.Intl.selectLogic(tone, {
      'supportive':
          'A good day to share how you feel and give the other person time to respond.',
      'reflective':
          'Pause before reading into a silence. Ask how the other person feels.',
      'other':
          'Make time for a relaxed conversation and listen to what matters to the other person.',
    });
    return '$_temp0';
  }

  @override
  String dailyHoroscopeWorkAdvice(String tone) {
    String _temp0 = intl.Intl.selectLogic(tone, {
      'supportive':
          'Pick a task you can move forward today and agree on the next step with your team.',
      'reflective':
          'Review the details of a task in progress before taking on a new commitment.',
      'other': 'Set one clear priority and handle the rest in order.',
    });
    return '$_temp0';
  }

  @override
  String dailyHoroscopeMoneyAdvice(String tone) {
    String _temp0 = intl.Intl.selectLogic(tone, {
      'supportive':
          'Make time to review your spending and see what you can set aside.',
      'reflective':
          'Give yourself time to think through any unplanned purchase.',
      'other': 'Check upcoming expenses and keep some room in your budget.',
    });
    return '$_temp0';
  }

  @override
  String dailyHoroscopeHealthAdvice(String tone) {
    String _temp0 = intl.Intl.selectLogic(tone, {
      'supportive':
          'A little movement or a short break can help you keep a steady rhythm today.',
      'reflective':
          'Leave some space between plans and take a break when you need one.',
      'other':
          'Keep your usual routine and step away from the screen for a moment.',
    });
    return '$_temp0';
  }

  @override
  String get chartRules => 'Tropical zodiac · Placidus houses · True node';

  @override
  String get chartSource => 'Calculated by RoxyAPI from your birth details';

  @override
  String get dateOnlyRules =>
      'Birth time unknown: planetary positions are noon estimates. Moon, angles, houses, aspects and uncertain sign placements are omitted.';

  @override
  String get calculateChart => 'Calculate my chart';

  @override
  String get saveForChart =>
      'Confirm and save your birth details before creating your personal chart.';

  @override
  String get retrograde => 'Retrograde';

  @override
  String get orb => 'Orb';

  @override
  String get aspectConjunction => 'Conjunction';

  @override
  String get aspectSextile => 'Sextile';

  @override
  String get aspectSquare => 'Square';

  @override
  String get aspectTrine => 'Trine';

  @override
  String get aspectOpposition => 'Opposition';

  @override
  String get fullReading => 'Your full reading';

  @override
  String get developmentReport =>
      'Local development preview: the full report is free here. No purchase or payment has taken place.';

  @override
  String get reportGeneratingText =>
      'We are preparing your reading from your planets, houses and aspects. It will appear automatically. You can leave and return to it later.';

  @override
  String get reportFailedText =>
      'This reading could not be completed yet. Use the button below to try again. Your chart has been kept.';

  @override
  String get roxyUnavailable =>
      'The chart service is unavailable. Please try again later.';

  @override
  String get roxyQuota =>
      'There are too many chart requests. Please try again later.';

  @override
  String get profileChanged =>
      'Your birth details changed. Open the birth details page, confirm and save them again.';

  @override
  String get birthRegion => 'Province / region';

  @override
  String get selectCountry => 'Choose or search a country';

  @override
  String get selectRegion => 'Choose or search a region';

  @override
  String get selectBirthCity => 'Select your birth city from the suggestions';

  @override
  String get countryFirst => 'Choose a country first';

  @override
  String get regionFirst => 'Choose a region first';

  @override
  String get regionNotNeeded => 'Not required';

  @override
  String get birthLocationHint =>
      'Type to search or open the list to choose. Location details are matched automatically.';

  @override
  String get moreLocations => 'Load more places';

  @override
  String get guestReading => 'View your chart and report without signing in.';

  @override
  String get optionalLogin => 'Sign in or register (optional)';

  @override
  String get templeNav => 'Temple';

  @override
  String get divinationNav => 'Discover';

  @override
  String get bondNav => 'Our bond';

  @override
  String get moreNav => 'More';

  @override
  String get templeWelcome => 'Take a breath.\nYou are heard.';

  @override
  String get templeIntro => 'A quiet place for\nwhatever is on your mind.';

  @override
  String get chooseGuardian => 'Who is on your mind today?';

  @override
  String get aiCompanionNotice =>
      'AI companions · for entertainment and reflection';

  @override
  String get loveGuardian => 'Love guardian';

  @override
  String get careerGuardian => 'Career guardian';

  @override
  String get wealthGuardian => 'Wealth guardian';

  @override
  String get wellbeingGuardian => 'Wellbeing guardian';

  @override
  String get loveGuardianNote => 'Love · connection';

  @override
  String get careerGuardianNote => 'Direction · growth';

  @override
  String get wealthGuardianNote => 'Resources · balance';

  @override
  String get wellbeingGuardianNote => 'Rest · self-care';

  @override
  String get continueConversation => 'Pick up our conversation';

  @override
  String get startConversation => 'Start a conversation';

  @override
  String get listenIntro =>
      'You do not need the perfect words. Start wherever you like.';

  @override
  String get messageHint => 'What is on your mind?';

  @override
  String get sendMessage => 'Send';

  @override
  String get assistantListening => 'Listening and putting thoughts together…';

  @override
  String get chatUnavailable =>
      'Conversation is unavailable right now. Please try again later.';

  @override
  String get chatProfileNeeded =>
      'Add your birth details to connect readings to you.';

  @override
  String get chatFailure =>
      'The reply did not finish. Please retry; this turn is not counted.';

  @override
  String get selectedReading => 'This reading';

  @override
  String get continueReading => 'Discuss with a guardian';

  @override
  String get readingQuestion => 'What in this reading should I reflect on?';

  @override
  String get divinationTitle => 'A little perspective';

  @override
  String get divinationIntro =>
      'Draw a card, explore your stars, then talk it through.';

  @override
  String get dailyDraw => 'A card for today';

  @override
  String get dailyDrawNote => 'A quiet moment to reflect';

  @override
  String get weeklyEvents => 'This week';

  @override
  String get weeklyNote => 'Your week, in perspective';

  @override
  String get weeklyPrompt =>
      'What should I pay attention to this week? Let us think it through.';

  @override
  String get lovePrompt =>
      'There is something about a relationship I want to talk about.';

  @override
  String get careerPrompt => 'I have been unsure about my direction at work.';

  @override
  String get wealthPrompt => 'I want to think through some money worries.';

  @override
  String get wellbeingPrompt => 'I have been tired lately and want to talk.';

  @override
  String get bondTitle => 'Getting to know you';

  @override
  String get bondIntro =>
      'A connection built from the things you choose to share.';

  @override
  String get bondNew => 'First meeting';

  @override
  String get bondFamiliar => 'Getting acquainted';

  @override
  String get bondGrowing => 'Growing understanding';

  @override
  String get bondCount => 'recent conversations';

  @override
  String get bondRecentNote =>
      'Stages reflect recent completed conversations, not prediction accuracy.';

  @override
  String get bondMemory => 'What you want remembered';

  @override
  String get memoryEmpty =>
      'No confirmed memories yet. Share what matters to you.';

  @override
  String get addMemory => 'Add a memory';

  @override
  String get memoryHint => 'For example: I am considering a job change.';

  @override
  String get memoryHelp =>
      'Confirmed by you, shared by all four guardians. Edit or delete anytime.';

  @override
  String get recentConversations => 'Recent conversations';

  @override
  String get noConversations => 'Every connection starts with a hello.';

  @override
  String get profileSelf => 'About you';

  @override
  String get memoryDeleteConfirm => 'Delete this confirmed memory?';

  @override
  String get sharedHistory => 'The four guardians share conversation memory.';

  @override
  String get editMemory => 'Edit memory';

  @override
  String get saveMemory => 'Save memory';

  @override
  String get guardianSectionNote => 'Four guardians, a place for every feeling';

  @override
  String get dailyHoroscopeEmpty =>
      'Choose your zodiac sign for today\'s love, work and life guidance.';

  @override
  String get appleLoginUnavailable =>
      'Apple sign-in is unavailable on this device. You can continue as a guest.';

  @override
  String get purchaseUnavailable =>
      'Purchases are not available yet. Please check back later.';

  @override
  String get chatTryAgain => 'Reconnect';

  @override
  String get copyLink => 'Copy link';

  @override
  String get privacyCenter => 'Privacy & permissions';

  @override
  String get privacyIntro =>
      'Your information, your choices. Review what FATE uses and manage it here.';

  @override
  String get dataProfileTitle => 'Birth information';

  @override
  String get dataProfileBody =>
      'Your date, time, birthplace and time zone are saved to prepare your chart. Your saved profile is linked to your guest session or signed-in account.';

  @override
  String get dataChatTitle => 'AI conversations & readings';

  @override
  String get dataChatBody =>
      'Chart reports send calculated chart facts to an AI provider after your permission. Companion chat also shares your message, profile, recent conversation, saved memories and any reading you choose to discuss. Avoid entering information you do not want processed by AI.';

  @override
  String get dataPurchaseTitle => 'Purchases & access';

  @override
  String get dataPurchaseBody =>
      'The store handles payment. FATE verifies the transaction with its server before granting access. This app does not ask for your card number. Local previews do not create a purchase.';

  @override
  String get dataControlTitle => 'Managing your data';

  @override
  String get dataControlBody =>
      'You can edit your profile and saved memories, clear conversation history, and withdraw permission for future AI chats. Clearing birth information here removes only the local copy. Account deletion is a separate action and requires confirmation from the service.';

  @override
  String get aiPermission => 'Before you talk';

  @override
  String aiPermissionBody(String provider) {
    return 'Your message, birth profile, recent chats, saved memories and selected reading will be processed by the configured AI service ($provider) to reply to you. Replies may be inaccurate. You can decline and still use other tools, or withdraw permission in Privacy at any time. Withdrawal stops future sharing on this device; it does not delete data already processed.';
  }

  @override
  String get aiAllow => 'Allow & continue';

  @override
  String get aiEnabled => 'AI chat permission is on';

  @override
  String get aiPaused => 'AI chat permission is off';

  @override
  String get aiRevoke => 'Withdraw chat permission';

  @override
  String get aiRevoked => 'Permission withdrawn. New messages will ask again.';

  @override
  String get privacyPolicy => 'Full privacy policy';

  @override
  String get policyUnavailable =>
      'The published policy link is not available yet.';

  @override
  String get termsTitle => 'Using FATE';

  @override
  String get termsBody =>
      'FATE offers AI companionship and astrology for reflection and entertainment. Readings are not guaranteed predictions or medical, financial or legal advice. Guardians are fictional AI characters. Paid content is available only after verified payment; price and availability come from the store. Do not use FATE to harass others or submit unlawful content.';

  @override
  String get supportTitle => 'Help & support';

  @override
  String get supportIntro => 'A little guidance, whenever you need it.';

  @override
  String get supportUnavailable =>
      'Support contact details are not available yet. Please try again later.';

  @override
  String get supportContact => 'Contact support';

  @override
  String get copyAddress => 'Copy email address';

  @override
  String get copied => 'Copied';

  @override
  String get openFailed =>
      'Unable to open this link. You can copy the address instead.';

  @override
  String get faqReportTitle => 'Where are my readings?';

  @override
  String get faqReportBody =>
      'Open Readings to view your saved reports. Use the same account and language. Example readings are labelled separately and do not represent a personal calculation.';

  @override
  String get faqChatTitle => 'Can I continue an earlier chat?';

  @override
  String get faqChatBody =>
      'Use the same browser or app installation and choose the same guardian. Guests may lose access after clearing app data or reinstalling. Saved memories can be reviewed and removed in Bonds.';

  @override
  String get faqPurchaseTitle => 'Paid but still locked?';

  @override
  String get faqPurchaseBody =>
      'Do not buy again while verification is pending. Open Purchases & restore and retry verification, then refresh your report. Restoring requests a store check; only the server can confirm access.';

  @override
  String get licenses => 'Open-source licenses';

  @override
  String get deleteAccountBody =>
      'This permanently removes the current account and associated profile, conversations and memories from the service. Data required for transaction records may be retained. Deletion does not issue a refund. A guest session cannot be recovered after deletion.';

  @override
  String get deleteUnavailable =>
      'Account deletion is not available from the service yet. Nothing has been deleted. Clearing local information or signing out does not delete your account.';

  @override
  String get deleteAcknowledge => 'I understand that this cannot be undone.';

  @override
  String get deleteNow => 'Permanently delete';

  @override
  String get deleteSuccess => 'Account deletion confirmed.';

  @override
  String get deleteFailure =>
      'Deletion was not confirmed. Your session has been kept. Please retry or contact support.';

  @override
  String get clearHistory => 'Clear conversations';

  @override
  String get clearHistoryBody =>
      'This deletes your conversation history from the service for all four guardians. Saved memories remain in Bonds and can be deleted there. This cannot be undone.';

  @override
  String get clearHistoryDone => 'Conversation history cleared.';

  @override
  String get contentReport => 'Report content';

  @override
  String get contentReportIntro =>
      'Tell us what is wrong with this AI response. Only its reference and the details you enter are included; your full conversation is not attached.';

  @override
  String get reportReason => 'Reason';

  @override
  String get reasonHarmful => 'Harmful or unsafe';

  @override
  String get reasonSexual => 'Sexual content';

  @override
  String get reasonHate => 'Hate or harassment';

  @override
  String get reasonPrivacy => 'Personal information';

  @override
  String get reasonMisleading => 'Misleading advice';

  @override
  String get reasonOther => 'Something else';

  @override
  String get reportDetails => 'More details (optional)';

  @override
  String get reportSend => 'Submit report';

  @override
  String get reportUnavailable =>
      'Reporting is temporarily unavailable. No report has been sent. You can try again later or check Help & support.';

  @override
  String reportReceived(String receipt) {
    return 'Report received · $receipt';
  }

  @override
  String get purchaseCenter => 'Purchases & restore';

  @override
  String get purchaseCenterIntro =>
      'Check access and recover an existing purchase.';

  @override
  String get restoreCheck => 'Checking your purchases…';

  @override
  String get restoreChecked =>
      'The store check has finished. Refresh your reports to see server-confirmed access. This message is not a purchase confirmation.';

  @override
  String get verifiedContent => 'Your report library';

  @override
  String get verifiedContentIntro =>
      'Open a report to see its current access. A saved report or example does not by itself mean it has been purchased.';

  @override
  String get reportLeave => 'Discard this report draft?';

  @override
  String get serviceRetry => 'Try again';

  @override
  String get deleteCleanup =>
      'The server confirmed deletion, but some local data could not be cleared. Sign-in has been cleared from memory; clear this app’s storage on this device.';

  @override
  String get storeBuy => 'Buy in the store';

  @override
  String get restoreUnavailable =>
      'Restore is unavailable on this device or account. Use a supported device with the original store and FATE account.';

  @override
  String get calendarTitle => 'Astrology calendar';

  @override
  String get calendarOpen => 'View calendar';

  @override
  String get calendarToday => 'Today';

  @override
  String get calendarSubtitle => 'A little space to plan your days';

  @override
  String calendarYears(int be, int ce) {
    return 'B.E. $be · C.E. $ce';
  }

  @override
  String calendarSmallEra(int year) {
    return 'Chula Sakarat $year';
  }

  @override
  String get calendarSelectHint => 'Choose a date to explore its five details';

  @override
  String get calendarLoading => 'Opening your calendar…';

  @override
  String get calendarUnavailable =>
      'This month could not be loaded. Please try again.';

  @override
  String calendarRange(int start, int end) {
    return 'Available offline · $start–$end C.E.';
  }

  @override
  String get calendarOutOfRange =>
      'This date is outside the available calendar.';

  @override
  String get calendarWanPhra => 'Buddhist observance';

  @override
  String get calendarKalayokTitle => 'Kalayok · day indications';

  @override
  String calendarFlag(String kind) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'thongchai': 'Thongchai · victory',
      'athibodi': 'Athibodi · authority',
      'ubat': 'Ubat · caution',
      'other': 'Lokawinas · caution',
    });
    return '$_temp0';
  }

  @override
  String calendarFlagBody(String kind) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'thongchai': 'Traditionally associated with a new beginning.',
      'athibodi': 'Traditionally associated with leading and organising.',
      'ubat': 'Traditionally a day to review plans with care.',
      'other': 'Traditionally a day to avoid rushing major commitments.',
    });
    return '$_temp0';
  }

  @override
  String get calendarNoKalayok => 'No Kalayok day indication';

  @override
  String get calendarMixedNote =>
      'More than one tradition applies today; all indications are shown.';

  @override
  String get calendarLunarTitle => 'Lunar day';

  @override
  String get calendarRiangMon => 'Dithi Riang Mon';

  @override
  String get calendarRiangMonBody =>
      'A lunar date traditionally considered when choosing a wedding day.';

  @override
  String get calendarLunarOrdinary => 'Not a Dithi Riang Mon date.';

  @override
  String get calendarUbakong => 'Ubakong · good hours';

  @override
  String get calendarDaylight => 'Daytime · 06:00–18:00 · Bangkok';

  @override
  String get calendarMansion => 'The 27 lunar mansions';

  @override
  String calendarMansionPosition(int index, int quarter) {
    return 'Mansion $index of 27 · quarter $quarter';
  }

  @override
  String get calendarMansionReference =>
      'Moon position at Bangkok noon; the mansion may change within the day.';

  @override
  String get calendarReference =>
      'Traditional Thai calendar · for cultural reference and entertainment.';

  @override
  String calendarLunarShort(String phase, int day) {
    String _temp0 = intl.Intl.selectLogic(phase, {'waxing': 'W', 'other': 'D'});
    return '$_temp0$day';
  }

  @override
  String calendarMonth(String month) {
    String _temp0 = intl.Intl.selectLogic(month, {
      '1': 'January',
      '2': 'February',
      '3': 'March',
      '4': 'April',
      '5': 'May',
      '6': 'June',
      '7': 'July',
      '8': 'August',
      '9': 'September',
      '10': 'October',
      '11': 'November',
      '12': 'December',
      'other': '',
    });
    return '$_temp0';
  }

  @override
  String calendarMansionName(String index) {
    String _temp0 = intl.Intl.selectLogic(index, {
      '1': 'Ashwini',
      '2': 'Bharani',
      '3': 'Krittika',
      '4': 'Rohini',
      '5': 'Mrigashira',
      '6': 'Ardra',
      '7': 'Punarvasu',
      '8': 'Pushya',
      '9': 'Ashlesha',
      '10': 'Magha',
      '11': 'Purva Phalguni',
      '12': 'Uttara Phalguni',
      '13': 'Hasta',
      '14': 'Chitra',
      '15': 'Swati',
      '16': 'Vishakha',
      '17': 'Anuradha',
      '18': 'Jyeshtha',
      '19': 'Mula',
      '20': 'Purva Ashadha',
      '21': 'Uttara Ashadha',
      '22': 'Shravana',
      '23': 'Dhanishta',
      '24': 'Shatabhisha',
      '25': 'Purva Bhadrapada',
      '26': 'Uttara Bhadrapada',
      '27': 'Revati',
      'other': '',
    });
    return '$_temp0';
  }

  @override
  String get estimated => 'Estimated';

  @override
  String get estimatedChart => 'Estimated chart · 12:00 local time';

  @override
  String get estimatedChartNote =>
      'No exact birth time was provided. This chart uses 12:00 local time at your birthplace. The Moon, ascendant, houses and aspects are estimates and may change with your actual birth time. Add your time to recalculate.';

  @override
  String get readingChart => 'The chart behind this reading';

  @override
  String get readingChartIntro =>
      'The reading below is based on this natal chart. Tap a planet to see its position.';

  @override
  String get readingContents => 'In this reading';

  @override
  String get readingContentsHint => 'Choose a topic to jump to that section.';

  @override
  String get backToChart => 'Back to my chart';

  @override
  String get savedReadings => 'Reading history';

  @override
  String get noSavedReports => 'No reports yet';

  @override
  String get reportRecords => 'Report records';

  @override
  String get reportRecordsIntro =>
      'Reports are sorted by generation time. Search by report number to find a record.';

  @override
  String get searchReportNumber => 'Search by report number';

  @override
  String get clearSearch => 'Clear search';

  @override
  String get noMatchingReports =>
      'No report matches this number. Check the number and try again.';

  @override
  String get reportNumberLabel => 'Report number';

  @override
  String get generatedAt => 'Generated on';

  @override
  String get reportReady => 'Ready';

  @override
  String get reportRunning => 'Generating';

  @override
  String get reportFailedShort => 'Not completed';

  @override
  String get deleteReport => 'Delete report';

  @override
  String get deleteReportConfirm =>
      'Delete this report record? You will no longer be able to open it from your records.';

  @override
  String get reportDeleted => 'Report record deleted';

  @override
  String get deleteReportFailed =>
      'The report was kept because deletion failed. Please try again later.';

  @override
  String get reportDeleteBusy =>
      'This report is still generating. Wait until it finishes before deleting it.';

  @override
  String get loadReportsFailed =>
      'Report records could not be loaded. Please try again.';

  @override
  String get refreshRecords => 'Reload records';

  @override
  String get chartReportsLocation =>
      'Chart readings have their own page. Open Chart to read yours.';

  @override
  String get progressTitle => 'Creating your reading';

  @override
  String get progressIntro =>
      'Six topics are being prepared and checked. Your reading will open automatically when it is ready.';

  @override
  String get progressPreparing => 'Preparing your chart details';

  @override
  String get progressWriting => 'Writing your personal reading';

  @override
  String get progressChecking => 'Checking the complete report';

  @override
  String get progressRefining => 'Refining your reading and advice';

  @override
  String get progressComplete => 'Your report is ready. Opening it now';

  @override
  String get progressFailed => 'Your reading is not complete yet';

  @override
  String progressTopics(Object completed, Object total) {
    return '$completed of $total topics prepared';
  }

  @override
  String get progressReturn => 'Return to report';

  @override
  String get progressReconnect => 'Reconnect';

  @override
  String get progressDisconnected =>
      'The latest progress is temporarily unavailable. Your background task has not been cancelled. Reconnect or come back later.';

  @override
  String get progressLater => 'Come back later';

  @override
  String get progressPersonality => 'Personality and strengths';

  @override
  String get progressCareer => 'Career development';

  @override
  String get progressMoney => 'Money habits';

  @override
  String get progressRelationships => 'Relationships and family';

  @override
  String get progressWatch => 'Patterns to watch';

  @override
  String get progressActions => 'Practical next steps';

  @override
  String get reportServiceBusy =>
      'The reading service is temporarily busy, so your report is not ready yet. Your chart has been saved. Please try again later.';

  @override
  String get reportServiceTimeout =>
      'The reading request timed out before your report was ready. Your chart has been saved. Please try again later.';
}
