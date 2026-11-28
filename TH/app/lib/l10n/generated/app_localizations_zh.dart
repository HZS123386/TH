// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get h5CodeLogin => '使用网页登录码';

  @override
  String get h5CodeHelp => '输入 H5 报告页显示的 6 位字母数字码，同步该浏览器的报告。';

  @override
  String get h5CodeField => '网页登录码';

  @override
  String get h5CodeInvalid => '登录码无效、已用过或已过期，请回网页重新获取。';

  @override
  String get h5CodeRateLimited => '尝试次数过多，请稍后再试。';

  @override
  String get h5Account => '网页账号';

  @override
  String get h5Reports => '网页报告';

  @override
  String get h5ReportsEmpty => '这个浏览器还没有报告。';

  @override
  String get h5LoadMore => '加载更早的报告';

  @override
  String get h5Refresh => '刷新报告';

  @override
  String get h5ReportUnavailable => '暂时无法查看此报告，可刷新或回网页查看。';

  @override
  String get h5ReportQueued => '已解锁 · 排队中';

  @override
  String get h5ReportGenerating => '已解锁 · 生成中';

  @override
  String get h5ReportLimited => '已解锁 · 暂达生成上限';

  @override
  String get h5ReportIncomplete => '已解锁 · 报告尚未完成';

  @override
  String get h5ReportLimitedHelp => '已生成的章节仍可查看。请稍后回原网页继续生成。';

  @override
  String get h5Plan => '行动计划';

  @override
  String get h5Insight => '重点解读';

  @override
  String get h5Watchpoint => '需要留意';

  @override
  String get h5Example => '生活中的例子';

  @override
  String get h5Pitfall => '避免这样做';

  @override
  String get h5Check => '怎样检查效果';

  @override
  String get actionTodo => '待行动';

  @override
  String get actionReviewAvailable => '可回看';

  @override
  String get actionTypeService => '服务与分享知识';

  @override
  String get actionTypePractice => '自我修持';

  @override
  String get actionCompleted => '已完成';

  @override
  String get newVisitorNote => '选一位占卜师，开启第一次解读';

  @override
  String get returningVisitorNote => '继续解读，查看之前的报告';

  @override
  String get todayTab => '今日';

  @override
  String get quickAccess => '快速探索';

  @override
  String get luckyRevealHint => '点一下数字，展开今天的提示';

  @override
  String get readingBackToContents => '回到解读目录';

  @override
  String get actionTab => '行动力';

  @override
  String get liveTab => '直播';

  @override
  String get objectsTab => '好物';

  @override
  String get todayQuestion => '今天，想算点什么？';

  @override
  String get todayNote => '三种智慧，一份陪伴';

  @override
  String get thaiGuide => '泰式占星';

  @override
  String get sevenGuide => '七字命理';

  @override
  String get tarotGuide => '塔罗占卜';

  @override
  String get sirin => '希琳';

  @override
  String get arun => '阿伦';

  @override
  String get mira => '米拉';

  @override
  String get sirinFocus => '看运势 · 看流年';

  @override
  String get arunFocus => '看个性 · 看人生节奏';

  @override
  String get miraFocus => '看当下 · 看下一步';

  @override
  String get sirinHint => '看近期运势，找准下一步的时机。';

  @override
  String get arunHint => '从出生数字里，了解自己的节奏。';

  @override
  String get miraHint => '带着一个问题，看看此刻的牌。';

  @override
  String get startThaiGuide => '填写资料，开始泰式占星';

  @override
  String get homeChartExample => '先看西式星盘示例';

  @override
  String get viewThaiGuide => '查看我的泰式星盘';

  @override
  String get startSevenGuide => '体验阿伦的示例对话';

  @override
  String get arunSampleHeading => '阿伦的示例对话';

  @override
  String get arunSampleReply =>
      '先选一件十分钟内能做完的事。比如把明早要带的东西放在门口，或者写下明天最先要做的一件事。做完再看看，哪一步还需要调整。';

  @override
  String get startTarotGuide => '开始塔罗占卜';

  @override
  String get textReading => '文字解惑';

  @override
  String get textReadingNote => '打字问，接着聊';

  @override
  String get textChat => '文字聊天';

  @override
  String get voiceChat => '语音聊天';

  @override
  String get voicePreviewNotice => '语音聊天暂未接入。你可以在文字聊天里继续提问。';

  @override
  String guideChatHeading(String name) {
    return '和$name，聊清你的困惑';
  }

  @override
  String get startReading => '开始排盘';

  @override
  String get guideChatDemo => '演示对话 · 回复和记录仅在本机';

  @override
  String get guideGreeting => '今天有什么事，想和我一起理一理？';

  @override
  String get guidePromptWork => '最近工作有点迷茫';

  @override
  String get guidePromptLove => '感情里该主动一点吗？';

  @override
  String get guideWorkReply => '先把已确定的和还在等待的分开。这个星期，哪件事是你可以主动确认的？';

  @override
  String get guideLoveReply => '先想清楚你最想让对方知道什么。可以从一句轻松的问候开始，看看自己说完是什么感受。';

  @override
  String guideReflectReply(String question) {
    return '把「$question」放到今天能掌控的范围里。先选一件十分钟内能完成的小事，你会选哪件？';
  }

  @override
  String get continueSample => '带着上次的解读，接着聊';

  @override
  String get readingSampleQuestion => '我在等待一个工作结果，这一周可以做什么？';

  @override
  String get readingSampleLove => '该怎样迈出关系里的下一步？';

  @override
  String get readingSampleLife => '最近生活节奏变了，先从哪件事做起？';

  @override
  String get recoverReports => '我的报告';

  @override
  String get recoverReportAction => '找回报告';

  @override
  String get recentReadings => '最近的解读';

  @override
  String get reportLookup => '报告链接／编号';

  @override
  String get findReport => '查找';

  @override
  String get reportLookupDemo => '本机演示支持示例编号。个人报告请从报告列表查看。';

  @override
  String get reportCodeMissing => '找不到这个示例。请试试 FATE-THAI-001。';

  @override
  String get reportCodeRequired => '请先输入报告编号';

  @override
  String get newVisitor => '我是新用户';

  @override
  String get returningVisitor => '我是老用户';

  @override
  String get guideWelcomeLabel => '三位占卜师 · 三种解读';

  @override
  String get guideWelcomeTitle => '与命运，\n聊一聊。';

  @override
  String get guideWelcomeNote => '从一个问题开始，看看此刻的自己。';

  @override
  String get onAirNow => '此刻，正在直播';

  @override
  String get demo => '演示';

  @override
  String get allItems => '全部';

  @override
  String get templeRoom => '寺庙祈福现场';

  @override
  String get templeTeaser => '寺庙仪式现场';

  @override
  String get objectsRoom => '好物开箱现场';

  @override
  String get templeTeaserNote => '看仪式 · 听讲解';

  @override
  String get objectsTeaserNote => '看细节 · 聊用法';

  @override
  String get templeRoomNote => '合作寺庙 A · 示例';

  @override
  String get switchRoom => '切换直播';

  @override
  String get templePosterTitle => '一份心愿\n一次郑重的相遇';

  @override
  String get objectsPosterTitle => '喜欢的心意\n带回日常';

  @override
  String get liveDemoNotice => '直播演示 · 非实时';

  @override
  String get livePreview => '直播预览';

  @override
  String get liveWatch => '进入直播间';

  @override
  String get liveUpcoming => '直播预告';

  @override
  String get liveMyReservations => '我的预约';

  @override
  String get liveNoReservations => '你还没有预约场次。';

  @override
  String get liveReserve => '预约';

  @override
  String get liveReserved => '已预约';

  @override
  String get liveCancelReservation => '取消预约';

  @override
  String get liveReservationDemo => '演示预约仅在本次使用期间保留，不会发送通知。';

  @override
  String get liveTempleUpcoming => '寺庙祈福 · 心愿专场';

  @override
  String get liveObjectsUpcoming => '好物开箱 · 晚间香氛';

  @override
  String get liveAboutShow => '本场介绍';

  @override
  String get livestreamPause => '暂停预览';

  @override
  String get livestreamPlay => '播放预览';

  @override
  String get fullScreenPreview => '放大预览';

  @override
  String get templeRoomHeading => '把心愿，带到寺庙';

  @override
  String get samplePrice => '示例价';

  @override
  String get roomChat => '现场互动';

  @override
  String get ceremonyInfo => '本场仪式';

  @override
  String get roomObjectsInfo => '本场好物';

  @override
  String get roomWelcomeDemo => '场控 · 演示    欢迎来到预览。可以先看本场介绍。';

  @override
  String get templeSegmentOne => '写下想带去寺庙的心愿';

  @override
  String get templeSegmentTwo => '了解祈愿仪式与流程';

  @override
  String get templeSegmentThree => '为心愿留下一份记录';

  @override
  String get roomMessageHint => '在本机试发一条互动消息';

  @override
  String get myActions => '我的行动力';

  @override
  String get actionPending => '件待行动';

  @override
  String get actionDone => '件真实完成';

  @override
  String get actionReady => '件可回看';

  @override
  String get chooseFamilyAction => '为家人安排一个力日';

  @override
  String get weeklyMoment => '留一个自己的「力日」';

  @override
  String get weeklyMomentNote => '每周选一天，把几件小善事放在一起做。其他日子随心行动，跳过也没有关系。';

  @override
  String get myWeeklyDay => '我的力日';

  @override
  String get arrangeDay => '安排与调整';

  @override
  String get actionLedger => '我的行动账本';

  @override
  String get actionDailySuggestion => '今日建议';

  @override
  String get actionUseSuggestion => '加入待办';

  @override
  String get actionCustomPlan => '自己定一件事';

  @override
  String get actionCompleteNow => '完成';

  @override
  String get actionSuggestionThanks => '给帮过你的人发一条感谢消息';

  @override
  String get actionSuggestionCheckIn => '问候一位朋友';

  @override
  String get actionSuggestionShare => '给别人分享一个有用的小发现';

  @override
  String get offeringEnergy => '行动能量';

  @override
  String get offeringJasmine => '茉莉花环';

  @override
  String get offeringLotus => '供奉莲花';

  @override
  String get offeringMarigold => '万寿菊花环';

  @override
  String offeringCollected(int count) {
    return '已集齐 $count 件';
  }

  @override
  String offeringPerAction(int points) {
    return '每完成一件事，获得 $points 点能量';
  }

  @override
  String get offeringPresenting => '正在奉上供物…';

  @override
  String get offeringComplete => '供物已奉上';

  @override
  String get offeringBlessing => '愿功德护佑，好运相伴，所愿如意。';

  @override
  String get offeringNext => '下次完成事项时开始积攒下一件';

  @override
  String get newPlan => '新计划';

  @override
  String get noActionPlan => '这里会记录你选择做的小事。';

  @override
  String get actionRecord => '我的行动记录';

  @override
  String get actionTitle => '我想做的事';

  @override
  String get careAction => '为身边的人搭一把手';

  @override
  String get familyAction => '为家人做几件小事';

  @override
  String get actionCategory => '行为类别';

  @override
  String get beneficiary => '受益对象';

  @override
  String get forSelf => '自己';

  @override
  String get forOthers => '身边的人';

  @override
  String get forFamily => '家人';

  @override
  String get recordMethod => '记录方式';

  @override
  String get recordOnDevice => '本机文字记录';

  @override
  String get actionDate => '行动日期';

  @override
  String get reviewDate => '回看日期';

  @override
  String get actionNotes => '我做过的事';

  @override
  String get actionReview => '回看时，我这样记录';

  @override
  String get questionProgress => '原来的问题有什么进展？';

  @override
  String get actionReviewed => '已回看';

  @override
  String get recordAction => '记一件小行动';

  @override
  String get clearPrototypeRecords => '清除本机行动与演示对话';

  @override
  String get storeTitle => '心愿好物';

  @override
  String get storeIntro => '把喜欢的心意，带回每天的生活。';

  @override
  String get storeSearch => '搜索手账、香氛、饰品…';

  @override
  String get scentCategory => '香氛';

  @override
  String get jewelryCategory => '饰品';

  @override
  String get journalCategory => '手账';

  @override
  String get lifeCategory => '生活';

  @override
  String get sampleCatalog => '商品概念示意';

  @override
  String get objectJournal => '心愿行动手账';

  @override
  String get objectCandle => '晚间静心香氛';

  @override
  String get objectBracelet => '星愿珠串';

  @override
  String get objectDiffuser => '清晨香薰';

  @override
  String get objectJournalNote => '把愿望写成下一步';

  @override
  String get objectCandleNote => '给自己一段安静时间';

  @override
  String get objectBraceletNote => '把小小的心愿带在身边';

  @override
  String get objectDiffuserNote => '让熟悉的香气陪你开始一天';

  @override
  String get shopOrders => '我的订单';

  @override
  String get shopCart => '购物车';

  @override
  String get addToCart => '加入购物车';

  @override
  String get cartEmpty => '购物车还是空的';

  @override
  String get shopEmpty => '没有找到匹配的好物';

  @override
  String get shopOrdersEmpty => '暂无好物订单';

  @override
  String get shopDemoNotice => '演示订单不会扣款或发货。';

  @override
  String get shopSubtotal => '商品小计';

  @override
  String get shopReviewOrder => '确认订单';

  @override
  String get shopPlaceDemoOrder => '提交演示订单';

  @override
  String get shopOrderPlaced => '演示订单已创建';

  @override
  String get shopOrderNumber => '演示订单';

  @override
  String get shopIncreaseQuantity => '增加数量';

  @override
  String get mySpace => '我的陪伴与记录';

  @override
  String get mySpaceIntro => '报告、行动和已安排的心愿，都在这里。';

  @override
  String get actionsAndReviews => '行动与回看';

  @override
  String get resumeCompanion => '继续上次的陪伴';

  @override
  String get fortunePeriods => '今日、本周、本月与流年运势';

  @override
  String get thaiChartIntro => '按照出生日期、时间和地点查看泰式星盘。';

  @override
  String get country => '国家 / 地区';

  @override
  String get countryTH => '泰国';

  @override
  String get countryCN => '中国';

  @override
  String get countryVN => '越南';

  @override
  String get countryUS => '美国';

  @override
  String get noCityResults => '未找到匹配城市。请换一个名称，或返回手动填写地点和时区。';

  @override
  String get retryPurchase => '重新验证购买';

  @override
  String get sampleLoveText =>
      '示例中的水星与火星呈四分相，可以用来讨论说话节奏和行动节奏的差别：你已经想到解决办法，对方却可能还需要先被理解。意见不同的时候，先复述对方的担心，再问他此刻想要倾听还是建议，能减少越解释越着急的情况。';

  @override
  String get sampleLoveAction =>
      '下次有分歧时，先说“我听到你担心的是……，我理解得对吗？”得到确认后，一次只讨论一件事，并约定下一步由谁做、什么时候再沟通。';

  @override
  String get sampleWorkText =>
      '示例中的太阳与土星呈对分相，可以帮助讨论主动表现与承担责任之间的平衡。你可能很想拿出成绩，却也容易把一次反馈理解成对能力的评价。把评价对象缩小到具体任务，会更容易调整，而不必反复否定自己。';

  @override
  String get sampleWorkAction =>
      '接到任务后写清交付物、期限和验收人；第一次反馈时，只问最需要改的两点。把修改前后的差别记录下来，用完成情况判断进步，而不是只看别人有没有表扬。';

  @override
  String get sampleMoneyText =>
      '示例中的金星与海王星呈三分相，可用来讨论对美感、体验和理想生活的向往。喜欢一件东西时，可以留意自己购买的是实际用途，还是它代表的生活想象。这里讨论的是消费习惯，不提供收益或市场走势判断。';

  @override
  String get sampleMoneyAction =>
      '对计划外开支先保存商品，不立即付款。第二天写下用途、预计使用次数和本月剩余预算；三项都清楚后再决定。与他人共同支出时，在支付前说清分摊方式。';

  @override
  String get sunMeaning => '太阳象征你希望怎样表达自己，以及什么事情会让你感到有价值。';

  @override
  String get moonMeaning => '月亮象征你的情绪需要，以及怎样的相处方式会让你有安全感。';

  @override
  String get mercuryMeaning => '水星象征你思考、学习和沟通的习惯。';

  @override
  String get venusMeaning => '金星象征你欣赏什么，以及怎样表达喜欢、建立关系。';

  @override
  String get marsMeaning => '火星象征你采取行动、争取目标和处理分歧的方式。';

  @override
  String get jupiterMeaning => '木星象征你探索新机会、学习和拓展视野的倾向。';

  @override
  String get saturnMeaning => '土星象征责任、界限，以及需要时间积累的能力。';

  @override
  String get uranusMeaning => '天王星象征改变旧习惯、尝试独立做法的主题。';

  @override
  String get neptuneMeaning => '海王星象征想象力、理想，以及需要分清期待与现实的地方。';

  @override
  String get plutoMeaning => '冥王星象征深层改变、控制感和重新建立力量的主题。';

  @override
  String get home => '首页';

  @override
  String get chart => '星盘';

  @override
  String get reports => '报告';

  @override
  String get mine => '我的';

  @override
  String get system => '西洋占星';

  @override
  String get heroTitle => '读懂星盘，\n也读懂自己';

  @override
  String get heroText => '从你的出生时刻，探索性格、关系与人生方向。';

  @override
  String get heroBadge => '属于你的星盘故事';

  @override
  String get start => '开启我的星盘';

  @override
  String get birth => '出生资料';

  @override
  String get birthNote => '记录你的出生时刻';

  @override
  String get birthIntro => '日期、时间和地点帮助确定星体、上升与宫位。你可以随时修改。';

  @override
  String get chartNote => '行星 · 星座 · 十二宫';

  @override
  String get reportNote => '性格 · 关系 · 事业';

  @override
  String get fullReport => '完整解读';

  @override
  String get fullNote => '具体建议与行动方向';

  @override
  String get homeReportTitle => '一份真正关于你的报告';

  @override
  String get homeReportText => '先认识自己的特点，再看看关系、工作与金钱习惯中的选择。';

  @override
  String get viewReport => '查看解读报告';

  @override
  String get journey => '你的探索，从这里开始';

  @override
  String get stepBirth => '填写出生资料';

  @override
  String get stepChart => '认识本命星盘';

  @override
  String get stepReport => '阅读个人解读';

  @override
  String get example => '查看示例星盘';

  @override
  String get exampleReport => '查看报告示例';

  @override
  String get exampleBadge => '教学示例';

  @override
  String get exampleNote => '用于展示星盘与报告的阅读方式，不对应你填写的出生资料。';

  @override
  String get myChart => '我的本命星盘';

  @override
  String get myChartText => '把专业星盘，变成你能读懂的自己。';

  @override
  String get noChart => '你的星盘，还差一个开始';

  @override
  String get noChartText => '填写出生资料后，查看属于你的行星、星座和宫位。';

  @override
  String get waiting => '正在准备你的星盘';

  @override
  String get unavailable => '西洋星盘服务尚未就绪';

  @override
  String get unavailableText => '出生资料已保存在当前设备。可以先查看示例，或稍后重新获取你的结果。';

  @override
  String get retry => '重新获取星盘';

  @override
  String get editBirth => '修改出生资料';

  @override
  String get sun => '太阳';

  @override
  String get moon => '月亮';

  @override
  String get ascendant => '上升';

  @override
  String get planets => '行星位置';

  @override
  String get houses => '十二宫';

  @override
  String get aspects => '主要相位';

  @override
  String get planetHint => '点击星体，了解它在星盘中代表什么。';

  @override
  String get unknownTime => '未填写具体出生时间，将按出生地当地12:00展示估算星盘。你可以之后补充时间。';

  @override
  String get chartRead => '全部解读';

  @override
  String get house => '宫';

  @override
  String get emptyValue => '待生成';

  @override
  String get reportTitle => '个人本命报告';

  @override
  String get reportIntro => '从整体特点到生活中的选择，一步一步认识自己。';

  @override
  String get free => '免费试读';

  @override
  String get premium => '完整内容';

  @override
  String get reportEmpty => '你的解读会保存在这里';

  @override
  String get reportEmptyText => '生成个人星盘后，就可以查看对应的解读与报告状态。';

  @override
  String get generate => '生成我的报告';

  @override
  String get summary => '先看结论';

  @override
  String get traits => '你可能有的特点';

  @override
  String get watch => '需要留意的地方';

  @override
  String get advice => '你可以这样做';

  @override
  String get reportScope => '这份报告包含什么';

  @override
  String get chapterPersonality => '性格与表达';

  @override
  String get chapterLove => '关系与沟通';

  @override
  String get chapterWork => '事业与成长';

  @override
  String get chapterMoney => '金钱习惯';

  @override
  String get reportSaved => '已保存这份示例';

  @override
  String get saveReport => '保存示例';

  @override
  String get savedReports => '保存在本机的示例';

  @override
  String get openReport => '打开报告';

  @override
  String get remove => '移除';

  @override
  String get exampleSavedNote => '示例与个人报告分别保存；示例不会变成你的个人测算结果。';

  @override
  String get unlock => '查看完整解读';

  @override
  String get lockedTitle => '继续读懂你的星盘';

  @override
  String get lockedText => '完整解读包含具体提醒、生活例子和可以照着做的行动步骤。';

  @override
  String get offerTitle => '解锁个人本命报告';

  @override
  String get offerText => '一次购买，查看商品范围内的完整报告。';

  @override
  String get offerFeature1 => '个人特点与四个生活主题';

  @override
  String get offerFeature2 => '具体提醒、例子与行动建议';

  @override
  String get offerFeature3 => '已购报告再次查看与恢复购买';

  @override
  String get appleBuy => '在 iOS App 中购买';

  @override
  String get pricePending => '价格以 App Store 展示为准';

  @override
  String get purchasePreview => '当前为浏览器预览，无法发起 Apple 内购，也不会扣款。';

  @override
  String get restore => '恢复购买';

  @override
  String get restoreNote => '请在 iOS App 中使用原购买账号恢复。当前浏览器无法读取 Apple 交易。';

  @override
  String get previewFull => '预览完整示例';

  @override
  String get previewFullNote => '只展开教学示例，不产生购买或个人报告权益。';

  @override
  String get purchaseHistory => '已购内容';

  @override
  String get noPurchases => '还没有可验证的已购内容';

  @override
  String get noPurchasesText => '在 iOS App 中完成购买并验证后，报告会出现在你的账号中。';

  @override
  String get account => '我的账号';

  @override
  String get guest => '访客';

  @override
  String get signedIn => '已登录';

  @override
  String get accountText => '保留你的资料与报告，继续每一次探索。';

  @override
  String get deviceProfile => '出生资料';

  @override
  String get language => '语言';

  @override
  String get largeText => '大字阅读';

  @override
  String get privacy => '资料与隐私';

  @override
  String get privacyText =>
      '草稿与访问凭证保存在本机。测算资料、星盘和报告保存在当前游客会话或账号下。排盘由 RoxyAPI 计算；星盘报告的 AI 解读使用星盘事实，不发送姓名、城市文字或聊天记录。\n\n神明陪聊会把你发送的消息、出生资料、相关对话、确认的记忆和你选中的可见解读交给 AI 服务，用于回复和续聊。清除本机资料不会删除服务端记录。';

  @override
  String get clearBirth => '清除本机出生资料';

  @override
  String get clearConfirm => '清除当前设备保存的出生资料？';

  @override
  String get cleared => '已清除本机出生资料';

  @override
  String get saved => '出生资料已保存';

  @override
  String get saveBirth => '保存并查看星盘';

  @override
  String get nickname => '称呼（选填）';

  @override
  String get nicknamePlaceholder => '希望怎么称呼你';

  @override
  String get placeRequired => '请选择或填写出生地点';

  @override
  String get close => '关闭';

  @override
  String get cancel => '取消';

  @override
  String get back => '返回';

  @override
  String get birthStorage => '无需登录即可排盘和阅读报告，当前设备可继续查看本次结果。';

  @override
  String get profileMissing => '尚未填写出生资料';

  @override
  String get connection => '服务连接暂不可用，仍可浏览示例。';

  @override
  String get error => '暂时未能完成，请稍后重试。';

  @override
  String get sampleSummary =>
      '你可能很在意把事情做好，也希望自己的想法被看见。把想表达的重点说清楚，再给合作留一点余地，会更容易发挥优势。';

  @override
  String get sampleTrait1Title => '表达时，希望有自己的声音';

  @override
  String get sampleTrait1Text =>
      '示例中的太阳落在狮子座，可以读作重视表达与创造。面对熟悉的事情，你可能更愿意主动提出方案；当意见没被采纳时，先询问原因，会比急着证明自己更有帮助。';

  @override
  String get sampleTrait2Title => '在自由和责任之间找平衡';

  @override
  String get sampleTrait2Text =>
      '示例里月亮的探索倾向与太阳、土星的联系，可以用来讨论自由和责任的拉扯。给自己明确的休息时间，也把已经答应的事情写下来，让两种需要都有位置。';

  @override
  String get sampleWatch1Title => '别把不同意见都理解成否定';

  @override
  String get sampleWatch1Text =>
      '当别人修改你的方案，或没有立即回应时，可以先确认他是在讨论做法，还是确实不认同目标。留意自己是否急着解释、打断对方，或反复检查消息。先用一句“你最担心哪一部分？”把问题缩小，再一起决定需要改什么。';

  @override
  String get sampleWatch2Title => '给承诺留出实际空间';

  @override
  String get sampleWatch2Text =>
      '想被认可时，容易答应超过现有时间和精力的安排。答复前先打开日历，检查这件事需要几次投入，以及会占用哪些已经安排的时间。拿不准时可以说“我确认一下安排，明天给你答复”，让承诺建立在能做到的范围里。';

  @override
  String get sampleAdvice1Title => '用三句话准备一次重要沟通';

  @override
  String get sampleAdvice1Text =>
      '先写下你观察到的事实，再写自己的需要，最后提出一个具体请求。例如：“这周方案改了两次，我需要先确认方向。我们能不能用十分钟确定优先级？”说完给对方回应的时间，再把达成的安排记录下来。';

  @override
  String get sampleAdvice2Title => '把一个目标拆成今天能做的动作';

  @override
  String get sampleAdvice2Text =>
      '选一件最想推进的事，列出所需资料、第一步和检查方式。今天先用二十分钟完成一个小动作，例如整理三条反馈或写好一封邮件草稿。结束时只检查这一步有没有完成，再决定下一步，不急着评价整个人生方向。';

  @override
  String get sampleAdvice3Title => '给自己安排一次简短复盘';

  @override
  String get sampleAdvice3Text =>
      '每周找一个固定时段，写下本周让你感到有收获的一件事、一次沟通不顺的情况，以及下次愿意尝试的小调整。用真实发生的事情检查建议是否适合自己；觉得不适合的部分，可以放下或换一种做法。';

  @override
  String get login => '登录';

  @override
  String get logout => '退出登录';

  @override
  String get register => '创建账号';

  @override
  String get username => '账号';

  @override
  String get password => '密码';

  @override
  String get confirmPassword => '确认密码';

  @override
  String get passwordMismatch => '两次输入的密码不一致';

  @override
  String get birthDate => '出生日期';

  @override
  String get birthTime => '出生时间';

  @override
  String get timezone => '出生地时区';

  @override
  String get birthplace => '出生城市';

  @override
  String get birthplacePlaceholder => '例如：曼谷 Bangkok';

  @override
  String get pickerDone => '完成';

  @override
  String get pickerCancel => '取消选择';

  @override
  String get chooseBirthDate => '请选择出生日期';

  @override
  String get chooseBirthTime => '请选择出生时间';

  @override
  String get searchBirthCity => '搜索城市或区县';

  @override
  String get searchTimezone => '搜索时区，例如 Asia/Bangkok';

  @override
  String get appleLogin => '使用 Apple 登录';

  @override
  String get developmentLogin => '开发测试账号';

  @override
  String get nativeSetup => '当前为预览环境，原生登录与内购需要对应服务配置。';

  @override
  String get calendarGregorian => '公历';

  @override
  String get calendarBuddhist => '佛历';

  @override
  String get timeUnknown => '不记得准确时间';

  @override
  String get reportPending => '报告正在生成，可以离开后再回来查看。';

  @override
  String get resumeReport => '继续上次报告';

  @override
  String get loginRequired => '请先登录后购买';

  @override
  String get serviceSetup => '目前尚未接通该服务，可以先查看教学示例。';

  @override
  String get exactBirth => '时间已知';

  @override
  String get dateOnly => '仅出生日期';

  @override
  String get dataPrecision => '出生资料精度';

  @override
  String get cityDirectory => '用城市目录搜索';

  @override
  String get findCity => '查找城市';

  @override
  String get deleteAccount => '删除账号';

  @override
  String get deletionSetup => '需要服务端开启账号删除接口后，才能提交删除请求。';

  @override
  String get aiConsent =>
      '生成报告时，会把已计算的星盘事实发送给 AI 服务来整理解读，不发送姓名、城市文字或聊天记录。是否同意？';

  @override
  String get consentGenerate => '同意并生成';

  @override
  String get decline => '不同意';

  @override
  String get purchaseVerifying => '正在验证购买，请稍后刷新报告。';

  @override
  String get personalReport => '个人报告';

  @override
  String get missingAngles => '尚未提供上升与宫位，当前只展示已知行星。';

  @override
  String get languageHelp => '泰语、英文、中文和越南语可在这里切换。';

  @override
  String get continueChart => '继续我的星盘';

  @override
  String get pSun => '太阳';

  @override
  String get pMoon => '月亮';

  @override
  String get pMercury => '水星';

  @override
  String get pVenus => '金星';

  @override
  String get pMars => '火星';

  @override
  String get pJupiter => '木星';

  @override
  String get pSaturn => '土星';

  @override
  String get pUranus => '天王星';

  @override
  String get pNeptune => '海王星';

  @override
  String get pPluto => '冥王星';

  @override
  String get zAries => '白羊座';

  @override
  String get zTaurus => '金牛座';

  @override
  String get zGemini => '双子座';

  @override
  String get zCancer => '巨蟹座';

  @override
  String get zLeo => '狮子座';

  @override
  String get zVirgo => '处女座';

  @override
  String get zLibra => '天秤座';

  @override
  String get zScorpio => '天蝎座';

  @override
  String get zSagittarius => '射手座';

  @override
  String get zCapricorn => '摩羯座';

  @override
  String get zAquarius => '水瓶座';

  @override
  String get zPisces => '双鱼座';

  @override
  String get skipOpening => '跳过开场';

  @override
  String get tarot => '塔罗牌';

  @override
  String get luckyNumbers => '幸运数字';

  @override
  String get tarotDraw => '抽三张牌';

  @override
  String get tarotDrawHint => '静下心想一想你的问题，从散落的牌中抽取三张。';

  @override
  String tarotChooseCard(int position) {
    return '抽取第 $position 张散落牌';
  }

  @override
  String get tarotResult => '你的三张牌';

  @override
  String get tarotDrawAgain => '重新抽牌';

  @override
  String get todayLuckyNumber => '今日幸运数字';

  @override
  String get luckyNumberHint => '今日数字提示';

  @override
  String get luckyNumberUpdates => '按设备的本地日期更新';

  @override
  String get tarotFool => '愚者';

  @override
  String get tarotFoolMeaning => '新的方向值得试一试。先迈出一小步，给自己留一点调整的空间。';

  @override
  String get tarotMagician => '魔术师';

  @override
  String get tarotMagicianMeaning => '盘点手里的技能和资源，把一个具体想法变成今天能做的事。';

  @override
  String get tarotHighPriestess => '女祭司';

  @override
  String get tarotHighPriestessMeaning => '给自己一点安静观察的时间，听听内心的感受，再决定要不要行动。';

  @override
  String get tarotEmpress => '女皇';

  @override
  String get tarotEmpressMeaning => '把时间留给让你有创造力的事，也照顾好自己的休息和需求。';

  @override
  String get tarotEmperor => '皇帝';

  @override
  String get tarotEmperorMeaning => '先定下清晰的目标和边界，把眼前的事按优先级安排好。';

  @override
  String get tarotHierophant => '教皇';

  @override
  String get tarotHierophantMeaning => '向信任的人请教，看看哪些经验适合你，哪些需要自己调整。';

  @override
  String get tarotLovers => '恋人';

  @override
  String get tarotLoversMeaning => '面对选择时，先问自己真正看重什么，再坦诚地表达出来。';

  @override
  String get tarotChariot => '战车';

  @override
  String get tarotChariotMeaning => '选定一个方向，把分散的精力收回来，专心推进最重要的一步。';

  @override
  String get tarotStrength => '力量';

  @override
  String get tarotStrengthMeaning => '遇到摩擦时，先稳住自己的情绪，用坚定而温和的方式回应。';

  @override
  String get tarotHermit => '隐士';

  @override
  String get tarotHermitMeaning => '暂时远离外界的声音，独处片刻，理清你真正想要的答案。';

  @override
  String get tarotWheelOfFortune => '命运之轮';

  @override
  String get tarotWheelOfFortuneMeaning => '形势在变化，给计划留一点弹性，先处理你能够掌握的部分。';

  @override
  String get tarotJustice => '正义';

  @override
  String get tarotJusticeMeaning => '把事实和感受分别想清楚，做一个自己愿意承担后果的决定。';

  @override
  String get tarotHangedMan => '倒吊人';

  @override
  String get tarotHangedManMeaning => '如果一件事推不动，可以先停一停，换个角度再看。';

  @override
  String get tarotDeath => '死神';

  @override
  String get tarotDeathMeaning => '把一件已经告一段落的事放下，给新的习惯或选择腾出空间。';

  @override
  String get tarotTemperance => '节制';

  @override
  String get tarotTemperanceMeaning => '把节奏放慢一点，从小处调整，在两种需求之间找到平衡。';

  @override
  String get tarotDevil => '恶魔';

  @override
  String get tarotDevilMeaning => '留意哪个习惯正在占用太多精力，试着替换一个最容易改变的动作。';

  @override
  String get tarotTower => '高塔';

  @override
  String get tarotTowerMeaning => '当原来的计划被打乱，先处理最紧要的事，再重新安排。';

  @override
  String get tarotStar => '星星';

  @override
  String get tarotStarMeaning => '给自己一点恢复的时间，选一个仍让你期待的小目标。';

  @override
  String get tarotMoon => '月亮';

  @override
  String get tarotMoonMeaning => '有些细节还不明朗。先验证你掌握的信息，再作判断。';

  @override
  String get tarotSun => '太阳';

  @override
  String get tarotSunMeaning => '把取得的进展记下来，也可以把好消息分享给信任的人。';

  @override
  String get tarotJudgement => '审判';

  @override
  String get tarotJudgementMeaning => '回看过去的选择，认清学到的东西，再决定怎样走下一步。';

  @override
  String get tarotWorld => '世界';

  @override
  String get tarotWorldMeaning => '给已经完成的事做个收尾，记下收获，再准备进入下一阶段。';

  @override
  String get luckyNumberOne => '适合开启一件新事。选一个最小的动作，今天就做。';

  @override
  String get luckyNumberTwo => '给合作和沟通多一点时间，先听听对方的想法。';

  @override
  String get luckyNumberThree => '把一个点子说出来、写下来，或者用作品表达。';

  @override
  String get luckyNumberFour => '把手头的事按优先级排好，从一件容易落实的开始。';

  @override
  String get luckyNumberFive => '试着换一种做法，给计划留出调整的余地。';

  @override
  String get luckyNumberSix => '留一点时间给在意的人，也照顾好自己的状态。';

  @override
  String get luckyNumberSeven => '安排一段安静的时间，整理想法，把问题想清楚。';

  @override
  String get luckyNumberEight => '把精力放到一件值得长期投入的事上，推进一个具体步骤。';

  @override
  String get luckyNumberNine => '收好手上的尾巴，放下一件已经完成的事。';

  @override
  String get tarotDrawTitle => '塔罗抽牌';

  @override
  String tarotProgress(int count, int total) {
    return '已抽 $count / $total';
  }

  @override
  String tarotCardPosition(int position) {
    return '第 $position 张';
  }

  @override
  String tarotCardsRemaining(int count) {
    return '还差 $count 张，继续从牌堆抽取';
  }

  @override
  String get tarotGestureHint => '点按牌面，或按住牌面向上滑';

  @override
  String get tarotShuffle => '重新洗牌';

  @override
  String get tarotSeerWaiting => '占星师正静候你的问题';

  @override
  String get tarotRevealing => '正在翻开这一张牌…';

  @override
  String get tarotReadingComplete => '解读完成';

  @override
  String tarotMinorName(String suit, String rank) {
    return '$suit$rank';
  }

  @override
  String get tarotRankAce => '王牌';

  @override
  String get tarotRankTwo => '二';

  @override
  String get tarotRankThree => '三';

  @override
  String get tarotRankFour => '四';

  @override
  String get tarotRankFive => '五';

  @override
  String get tarotRankSix => '六';

  @override
  String get tarotRankSeven => '七';

  @override
  String get tarotRankEight => '八';

  @override
  String get tarotRankNine => '九';

  @override
  String get tarotRankTen => '十';

  @override
  String get tarotRankPage => '侍从';

  @override
  String get tarotRankKnight => '骑士';

  @override
  String get tarotRankQueen => '王后';

  @override
  String get tarotRankKing => '国王';

  @override
  String get tarotSuitWands => '权杖';

  @override
  String get tarotWandsAceMeaning => '一个新点子值得动手试试，今天就从简单的一步开始。';

  @override
  String get tarotWandsTwoMeaning => '看清眼前的选择，把下一步写成一件能行动的事。';

  @override
  String get tarotWandsThreeMeaning => '已经迈出的努力开始延伸，可以看看更远的机会。';

  @override
  String get tarotWandsFourMeaning => '给一段稳定的进展留个庆祝的时刻，也感谢身边的人。';

  @override
  String get tarotWandsFiveMeaning => '面对不同意见，先听清各方真正想解决的问题。';

  @override
  String get tarotWandsSixMeaning => '承认自己的进步，也把功劳分给一起努力的人。';

  @override
  String get tarotWandsSevenMeaning => '明确自己愿意守住的立场，用平和的方式说出来。';

  @override
  String get tarotWandsEightMeaning => '事情进展变快时，先确认信息，再及时回应。';

  @override
  String get tarotWandsNineMeaning => '累的时候留好边界，给自己一点恢复的时间。';

  @override
  String get tarotWandsTenMeaning => '看看哪些责任可以分出去，给自己的精力减负。';

  @override
  String get tarotWandsPageMeaning => '用一点好奇心试试新方向，先做一个小实验。';

  @override
  String get tarotWandsKnightMeaning => '有动力时可以向前，但出发前先想好怎么收尾。';

  @override
  String get tarotWandsQueenMeaning => '带着自信表达想法，也给别人留出参与的空间。';

  @override
  String get tarotWandsKingMeaning => '把眼光放长一些，挑一个方向带着大家往前走。';

  @override
  String get tarotSuitCups => '圣杯';

  @override
  String get tarotCupsAceMeaning => '给一种新的感受留出空间，也允许自己把它表达出来。';

  @override
  String get tarotCupsTwoMeaning => '关系靠双方回应，试着坦诚说出你需要的支持。';

  @override
  String get tarotCupsThreeMeaning => '和支持你的人相处片刻，把值得庆祝的事说出来。';

  @override
  String get tarotCupsFourMeaning => '察觉自己对什么提不起劲，也看看有没有被忽略的选择。';

  @override
  String get tarotCupsFiveMeaning => '允许自己为失去的东西难过，再看看身边还在的支持。';

  @override
  String get tarotCupsSixMeaning => '回忆能带来安慰，挑一件过去喜欢的事重新做做。';

  @override
  String get tarotCupsSevenMeaning => '选项太多时，先分清哪些能落实，哪些只是想象。';

  @override
  String get tarotCupsEightMeaning => '如果原来的方向已不适合，想想你愿意走向哪里。';

  @override
  String get tarotCupsNineMeaning => '享受一件已经实现的愿望，也留意它满足了什么需求。';

  @override
  String get tarotCupsTenMeaning => '珍惜能让你安心的关系，今天做一件小事来维护它。';

  @override
  String get tarotCupsPageMeaning => '试着用不带判断的方式说出一个新感受。';

  @override
  String get tarotCupsKnightMeaning => '可以认真表达心意，同时给对方时间和空间。';

  @override
  String get tarotCupsQueenMeaning => '倾听别人的感受，也记得照顾自己的情绪边界。';

  @override
  String get tarotCupsKingMeaning => '情绪激动时先慢下来，再做一个体谅各方的决定。';

  @override
  String get tarotSuitSwords => '宝剑';

  @override
  String get tarotSwordsAceMeaning => '把复杂的事说清楚，先抓住一个可以验证的事实。';

  @override
  String get tarotSwordsTwoMeaning => '犹豫时给自己一点空间，想清两边各自的代价。';

  @override
  String get tarotSwordsThreeMeaning => '给受伤的感受一点时间，也试着向可信的人说出来。';

  @override
  String get tarotSwordsFourMeaning => '先暂停手上的事，等思路恢复再处理难题。';

  @override
  String get tarotSwordsFiveMeaning => '争执里问一问自己，赢下这句话是否值得。';

  @override
  String get tarotSwordsSixMeaning => '把注意力放在下一步，逐渐离开消耗你的处境。';

  @override
  String get tarotSwordsSevenMeaning => '行动前想清楚动机，能坦诚沟通的地方就别绕开。';

  @override
  String get tarotSwordsEightMeaning => '把现实限制和自己担心的事分开，找一个还能做的选择。';

  @override
  String get tarotSwordsNineMeaning => '把反复担心的事写下来，分出你今天能处理的一项。';

  @override
  String get tarotSwordsTenMeaning => '承认一件事已经结束，先把精力用在恢复上。';

  @override
  String get tarotSwordsPageMeaning => '用好奇心提问，听到新消息后先核实再转述。';

  @override
  String get tarotSwordsKnightMeaning => '行动可以果断，开口前再确认语气和事实。';

  @override
  String get tarotSwordsQueenMeaning => '把边界和事实讲清楚，同时让对话保留温度。';

  @override
  String get tarotSwordsKingMeaning => '用一致的标准做判断，给每个观点同样的考虑机会。';

  @override
  String get tarotSuitPentacles => '星币';

  @override
  String get tarotPentaclesAceMeaning => '从手头可以落实的小机会开始，把计划变成行动。';

  @override
  String get tarotPentaclesTwoMeaning => '同时忙几件事时，把时间和资源重新排个顺序。';

  @override
  String get tarotPentaclesThreeMeaning => '找人一起打磨作品，让不同的专长互相补足。';

  @override
  String get tarotPentaclesFourMeaning => '整理你已经有的资源，也给变化留一点余地。';

  @override
  String get tarotPentaclesFiveMeaning => '遇到困难时可以求助，先看看周围有哪些支持。';

  @override
  String get tarotPentaclesSixMeaning => '在给予和接受之间找平衡，先说清双方的期待。';

  @override
  String get tarotPentaclesSevenMeaning => '给长期投入一些时间，定个日期回头检查进展。';

  @override
  String get tarotPentaclesEightMeaning => '练习一个具体技能，把小进步一步步积累起来。';

  @override
  String get tarotPentaclesNineMeaning => '留意自己已经建立的独立和稳定，给努力一点肯定。';

  @override
  String get tarotPentaclesTenMeaning => '想想哪些积累能给未来带来长期的支持。';

  @override
  String get tarotPentaclesPageMeaning => '选一项实用的技能，列出今天就能做的第一步。';

  @override
  String get tarotPentaclesKnightMeaning => '稳稳完成一件小事，比把计划一下拉得很大更实际。';

  @override
  String get tarotPentaclesQueenMeaning => '用实际的行动照顾自己和身边的人，先把今天安顿好。';

  @override
  String get tarotPentaclesKingMeaning => '把已经建立的稳定用好，为下一阶段留足资源。';

  @override
  String get thaiCalendarTitle => '今日泰历';

  @override
  String get thaiCalendarTimezone => '曼谷时间';

  @override
  String thaiCalendarCivilDate(String date, int year) {
    return '$date · 佛历 $year 年';
  }

  @override
  String thaiCalendarWaxing(int day) {
    return '盈月第 $day 日';
  }

  @override
  String thaiCalendarWaning(int day) {
    return '亏月第 $day 日';
  }

  @override
  String thaiCalendarLunarMonth(int month) {
    return '农历 $month 月';
  }

  @override
  String get thaiCalendarSecondEighth => '农历闰八月';

  @override
  String get thaiCalendarAuspicious => '吉日';

  @override
  String get thaiCalendarCaution => '谨慎日';

  @override
  String get thaiCalendarMixed => '吉凶并见';

  @override
  String get thaiCalendarOrdinary => '平常日';

  @override
  String thaiCalendarHours(String hours) {
    return '吉时 $hours';
  }

  @override
  String get thaiCalendarDayRule => '泰式择日（กาลโยค）以曼谷正午的小历年为准';

  @override
  String get thaiCalendarHourRule => '按星期查泰式อุบากอง择时表，显示白天吉时';

  @override
  String get thaiCalendarLoading => '正在读取今日泰历…';

  @override
  String get thaiCalendarUnavailable => '今日泰历暂时无法加载';

  @override
  String get thaiCalendarLunarUnavailable => '当日农历资料暂不可用';

  @override
  String get thaiCalendarRetry => '重试';

  @override
  String get dailyHoroscopeTitle => '每日星座运势';

  @override
  String dailyHoroscopeToday(String sign) {
    return '今日$sign运势';
  }

  @override
  String get dailyHoroscopeMore => '查看更多';

  @override
  String get dailyHoroscopeChooseSign => '选择星座';

  @override
  String get dailyHoroscopeForecast => '今日运势解读';

  @override
  String get dailyHoroscopeBasis => '依据泰式行运的宫位与月亮位置生成，按曼谷日期更新。';

  @override
  String get dailyHoroscopeLoading => '正在读取今日运势…';

  @override
  String get dailyHoroscopeUnavailable => '今日运势暂时无法加载';

  @override
  String get dailyHoroscopeLove => '爱情';

  @override
  String get dailyHoroscopeWork => '事业';

  @override
  String get dailyHoroscopeMoney => '财运';

  @override
  String get dailyHoroscopeLoveShort => '爱情';

  @override
  String get dailyHoroscopeWorkShort => '事业';

  @override
  String get dailyHoroscopeMoneyShort => '财运';

  @override
  String get dailyHoroscopeHealth => '健康';

  @override
  String dailyHoroscopeReading(String planet, int house, String advice) {
    return '$planet行经第 $house 宫，$advice';
  }

  @override
  String dailyHoroscopeLoveAdvice(String tone) {
    String _temp0 = intl.Intl.selectLogic(tone, {
      'supportive': '适合把心里的话说清楚，给对方留出回应的时间。',
      'reflective': '遇到没说清楚的事，可以先问问对方的感受。',
      'other': '找个轻松的时间聊聊，听听对方最近在意什么。',
    });
    return '$_temp0';
  }

  @override
  String dailyHoroscopeWorkAdvice(String tone) {
    String _temp0 = intl.Intl.selectLogic(tone, {
      'supportive': '挑一件今天能推进的事，和同事把下一步定下来。',
      'reflective': '先检查手头工作的细节，再决定要不要接新任务。',
      'other': '先定好今天最重要的一件事，再按顺序处理。',
    });
    return '$_temp0';
  }

  @override
  String dailyHoroscopeMoneyAdvice(String tone) {
    String _temp0 = intl.Intl.selectLogic(tone, {
      'supportive': '适合整理近期账单，看看这周能留出多少储蓄。',
      'reflective': '遇到计划外的开销，可以缓一缓再决定。',
      'other': '看一下接下来的固定支出，给预算留点余地。',
    });
    return '$_temp0';
  }

  @override
  String dailyHoroscopeHealthAdvice(String tone) {
    String _temp0 = intl.Intl.selectLogic(tone, {
      'supportive': '可以安排一点轻松的活动，让今天的节奏更舒展。',
      'reflective': '日程别排太满，给自己留一段休息时间。',
      'other': '照平时的节奏安排作息，忙起来也记得歇一会儿。',
    });
    return '$_temp0';
  }

  @override
  String get chartRules => '热带黄道 · Placidus 宫制 · 真实交点';

  @override
  String get chartSource => '根据你的出生资料，由 RoxyAPI 实际排盘';

  @override
  String get dateOnlyRules =>
      '出生时间未知：以当地中午估算行星位置，不展示月亮、上升、宫位及相位。接近星座交界的位置也会隐藏。';

  @override
  String get calculateChart => '生成我的星盘';

  @override
  String get saveForChart => '请先确认并保存出生资料，再生成个人星盘。';

  @override
  String get retrograde => '逆行';

  @override
  String get orb => '容许度';

  @override
  String get aspectConjunction => '合相';

  @override
  String get aspectSextile => '六分相';

  @override
  String get aspectSquare => '四分相';

  @override
  String get aspectTrine => '三分相';

  @override
  String get aspectOpposition => '对分相';

  @override
  String get fullReading => '你的完整解读';

  @override
  String get developmentReport => '本地开发预览：本报告免费展示完整内容，未产生内购或付款。';

  @override
  String get reportGeneratingText =>
      '正在结合你的行星、宫位与相位整理个人解读。生成后会自动显示，离开页面后也可以回来继续查看。';

  @override
  String get reportFailedText => '本次解读暂未完成，请点击下方按钮重新生成。你的星盘已保留。';

  @override
  String get roxyUnavailable => '排盘服务暂时不可用，请稍后重试。';

  @override
  String get roxyQuota => '当前排盘请求较多，请稍后重试。';

  @override
  String get profileChanged => '出生资料已更新，请重新打开资料页确认并保存。';

  @override
  String get birthRegion => '省／府';

  @override
  String get selectCountry => '选择或输入国家';

  @override
  String get selectRegion => '选择或搜索省／府';

  @override
  String get selectBirthCity => '请从候选列表中选择出生城市';

  @override
  String get countryFirst => '请先选择国家';

  @override
  String get regionFirst => '请先选择省／府';

  @override
  String get regionNotNeeded => '无需选择';

  @override
  String get birthLocationHint => '可输入搜索，也可展开列表选择。选定城市后自动匹配出生地信息。';

  @override
  String get moreLocations => '加载更多地点';

  @override
  String get guestReading => '无需登录也能查看个人星盘与报告。';

  @override
  String get optionalLogin => '登录／注册（可选）';

  @override
  String get templeNav => '神殿';

  @override
  String get divinationNav => '占卜';

  @override
  String get bondNav => '羁绊';

  @override
  String get moreNav => '更多';

  @override
  String get templeWelcome => '在这里，\n慢慢说。';

  @override
  String get templeIntro => '为今天的心事，\n找一个温柔的落点。';

  @override
  String get chooseGuardian => '今天，想向谁倾诉？';

  @override
  String get aiCompanionNotice => 'AI 神明陪伴 · 仅供娱乐与自我探索';

  @override
  String get loveGuardian => '爱情神明';

  @override
  String get careerGuardian => '事业神明';

  @override
  String get wealthGuardian => '财运神明';

  @override
  String get wellbeingGuardian => '健康神明';

  @override
  String get loveGuardianNote => '感情 · 关系 · 心事';

  @override
  String get careerGuardianNote => '方向 · 选择 · 成长';

  @override
  String get wealthGuardianNote => '金钱 · 规划 · 安定';

  @override
  String get wellbeingGuardianNote => '情绪 · 休息 · 自我照顾';

  @override
  String get continueConversation => '接着上次聊';

  @override
  String get startConversation => '开始倾诉';

  @override
  String get listenIntro => '不必整理好心情，从你想说的那一句开始。';

  @override
  String get messageHint => '说说此刻的心事…';

  @override
  String get sendMessage => '发送';

  @override
  String get assistantListening => '正在倾听，整理回复…';

  @override
  String get chatUnavailable => '陪聊暂时不可用，请稍后再来。';

  @override
  String get chatProfileNeeded => '先完善出生资料，让后续解读与你对应。';

  @override
  String get chatFailure => '消息未完成，请重试；这次不会计入互动记录。';

  @override
  String get selectedReading => '本次解读';

  @override
  String get continueReading => '请神明继续解读';

  @override
  String get readingQuestion => '这份解读里，哪些部分值得我关注？';

  @override
  String get divinationTitle => '给心事，一点新视角';

  @override
  String get divinationIntro => '抽一张牌，看看星象，再把想问的留给神明。';

  @override
  String get dailyDraw => '今日一签';

  @override
  String get dailyDrawNote => '片刻静心，听听内心的声音';

  @override
  String get weeklyEvents => '本周关注';

  @override
  String get weeklyNote => '本周计划与心事';

  @override
  String get weeklyPrompt => '这周有哪些事情值得我关注？我想一起梳理一下。';

  @override
  String get lovePrompt => '我有一件感情上的事想聊聊。';

  @override
  String get careerPrompt => '最近对工作方向有些犹豫。';

  @override
  String get wealthPrompt => '我想理一理最近的金钱压力。';

  @override
  String get wellbeingPrompt => '最近有点累，想把心情说出来。';

  @override
  String get bondTitle => '我们的羁绊';

  @override
  String get bondIntro => '把聊过的心事，变成慢慢积累的了解。';

  @override
  String get bondNew => '初次相遇';

  @override
  String get bondFamiliar => '开始熟悉';

  @override
  String get bondGrowing => '渐渐了解';

  @override
  String get bondCount => '次近期对话';

  @override
  String get bondRecentNote => '关系阶段依据近期完成的对话；不代表预测准确度。';

  @override
  String get bondMemory => '你希望被记住的事';

  @override
  String get memoryEmpty => '还没有确认的记忆。你可以告诉神明什么对你很重要。';

  @override
  String get addMemory => '添加一条记忆';

  @override
  String get memoryHint => '例如：我正在考虑换工作，希望先聊职业方向。';

  @override
  String get memoryHelp => '由你确认，四位神明共用；随时可以修改或删除。';

  @override
  String get recentConversations => '最近聊过';

  @override
  String get noConversations => '羁绊从第一句倾诉开始。';

  @override
  String get profileSelf => '关于你';

  @override
  String get memoryDeleteConfirm => '删除这条已确认的记忆？';

  @override
  String get sharedHistory => '当前四位神明共用对话记忆。';

  @override
  String get editMemory => '修改记忆';

  @override
  String get saveMemory => '保存记忆';

  @override
  String get guardianSectionNote => '四位神明，陪你聊不同的心事';

  @override
  String get dailyHoroscopeEmpty => '选择你的星座，看看今天的感情、工作与生活提醒。';

  @override
  String get appleLoginUnavailable => '此设备暂时无法使用 Apple 登录，你可以先以访客身份继续。';

  @override
  String get purchaseUnavailable => '购买服务暂未开放，请稍后再来查看。';

  @override
  String get chatTryAgain => '重新连接';

  @override
  String get copyLink => '复制链接';

  @override
  String get privacyCenter => '隐私与授权';

  @override
  String get privacyIntro => '查看 FATE 使用哪些资料，并管理你的选择。';

  @override
  String get dataProfileTitle => '出生资料';

  @override
  String get dataProfileBody => '出生日期、时间、地点和时区用于排盘。保存的资料关联当前访客会话或登录账号。';

  @override
  String get dataChatTitle => 'AI 陪聊与解读';

  @override
  String get dataChatBody =>
      '星盘报告经你同意后，将计算结果交给 AI 服务商。陪聊还会传递你的消息、个人资料、近期对话、已保存的记忆及你选择继续讨论的解读。请勿输入不希望 AI 处理的信息。';

  @override
  String get dataPurchaseTitle => '购买与内容权益';

  @override
  String get dataPurchaseBody =>
      '付款由商店处理，FATE 经服务端核验交易后开放权益。App 不收集银行卡号，本地示例不构成购买。';

  @override
  String get dataControlTitle => '管理你的资料';

  @override
  String get dataControlBody =>
      '可编辑个人资料和记忆、清除聊天记录、撤回今后陪聊的 AI 授权。这里清除出生资料只移除本机副本；删除账号是独立操作，需服务端确认完成。';

  @override
  String get aiPermission => '开始陪聊之前';

  @override
  String aiPermissionBody(String provider) {
    return '你的消息、出生资料、近期聊天、已保存的记忆及选中的解读，将由当前 AI 服务（$provider）处理以生成回复。回复可能有误。你可拒绝并继续使用其他工具，也可随时在隐私页撤回。撤回会停止本机今后的发送，不会删除已处理的数据。';
  }

  @override
  String get aiAllow => '同意并继续';

  @override
  String get aiEnabled => '已允许 AI 处理陪聊资料';

  @override
  String get aiPaused => '尚未授权 AI 陪聊';

  @override
  String get aiRevoke => '撤回陪聊授权';

  @override
  String get aiRevoked => '已撤回授权，下次发送前会重新征求同意。';

  @override
  String get privacyPolicy => '完整隐私政策';

  @override
  String get policyUnavailable => '公开隐私政策链接暂未提供。';

  @override
  String get termsTitle => '使用说明';

  @override
  String get termsBody =>
      'FATE 提供用于自我思考与娱乐的 AI 陪聊和占卜。解读不是确定预言，也不替代医疗、投资或法律意见。神明是原创虚拟 AI 角色。付费内容仅在交易核验后开放，价格与可购买状态以商店为准。请勿利用产品骚扰他人或提交违法内容。';

  @override
  String get supportTitle => '帮助与支持';

  @override
  String get supportIntro => '遇到问题，在这里找到下一步。';

  @override
  String get supportUnavailable => '暂未提供客服联系方式，请稍后重试。';

  @override
  String get supportContact => '联系客服';

  @override
  String get copyAddress => '复制邮箱';

  @override
  String get copied => '已复制';

  @override
  String get openFailed => '无法打开链接，可复制地址后使用。';

  @override
  String get faqReportTitle => '我的报告在哪里？';

  @override
  String get faqReportBody => '在报告页查看已保存的解读，请使用原来的账号和语言。教学示例有单独标识，不代表你的个人计算结果。';

  @override
  String get faqChatTitle => '如何接着上次聊？';

  @override
  String get faqChatBody =>
      '在同一浏览器或同一次 App 安装中，选择原来的神明继续。访客清除应用数据或重装后可能无法找回会话。已保存的记忆可在羁绊页查看和删除。';

  @override
  String get faqPurchaseTitle => '已购买却没有解锁？';

  @override
  String get faqPurchaseBody =>
      '核验中请勿重复购买。在“购买与恢复”重试核验，然后刷新报告。恢复操作会向商店查询，最终权益以服务端确认为准。';

  @override
  String get licenses => '开源许可';

  @override
  String get deleteAccountBody =>
      '此操作永久删除当前账号及关联的个人资料、聊天和记忆。交易记录中依法必须保留的数据可能继续留存。删除账号不会自动退款，删除后的访客会话无法恢复。';

  @override
  String get deleteUnavailable => '账号删除服务暂不可用，目前未删除任何数据。清除本机资料或退出登录不会删除账号。';

  @override
  String get deleteAcknowledge => '我已了解此操作无法撤销。';

  @override
  String get deleteNow => '永久删除';

  @override
  String get deleteSuccess => '已确认删除账号。';

  @override
  String get deleteFailure => '尚未收到删除完成确认，当前会话已保留。请重试或联系客服。';

  @override
  String get clearHistory => '清除聊天记录';

  @override
  String get clearHistoryBody =>
      '这会从服务端删除与四位神明的聊天记录，无法撤销。已保存的记忆仍保留在羁绊页，可在那里单独删除。';

  @override
  String get clearHistoryDone => '已清除聊天记录。';

  @override
  String get contentReport => '举报内容';

  @override
  String get contentReportIntro =>
      '告诉我们这条 AI 内容有什么问题。仅提交内容编号和你填写的说明，不附带整段聊天记录。';

  @override
  String get reportReason => '举报原因';

  @override
  String get reasonHarmful => '有害或危险';

  @override
  String get reasonSexual => '色情内容';

  @override
  String get reasonHate => '仇恨或骚扰';

  @override
  String get reasonPrivacy => '泄露隐私';

  @override
  String get reasonMisleading => '误导性建议';

  @override
  String get reasonOther => '其他问题';

  @override
  String get reportDetails => '补充说明（选填）';

  @override
  String get reportSend => '提交举报';

  @override
  String get reportUnavailable => '举报服务暂不可用，尚未发送任何举报。你可稍后重试或查看帮助与支持。';

  @override
  String reportReceived(String receipt) {
    return '已收到举报 · $receipt';
  }

  @override
  String get purchaseCenter => '购买与恢复';

  @override
  String get purchaseCenterIntro => '查看权益状态，恢复已有购买。';

  @override
  String get restoreCheck => '正在检查已有购买…';

  @override
  String get restoreChecked => '商店查询已结束，请刷新报告查看服务端确认的权益。此提示不代表购买或解锁成功。';

  @override
  String get verifiedContent => '我的报告库';

  @override
  String get verifiedContentIntro => '打开报告可查看当前访问权益。已保存的报告或教学示例不代表已购买。';

  @override
  String get reportLeave => '放弃本次举报草稿？';

  @override
  String get serviceRetry => '重试';

  @override
  String get deleteCleanup => '服务端已确认删除，但部分本机数据未能清理。当前会话已退出，请清除这台设备上的应用存储。';

  @override
  String get storeBuy => '通过商店购买';

  @override
  String get restoreUnavailable => '当前设备或账号无法恢复购买，请在受支持的设备上使用原商店账号及 FATE 账号操作。';

  @override
  String get calendarTitle => '占星日历';

  @override
  String get calendarOpen => '查看月历';

  @override
  String get calendarToday => '今天';

  @override
  String get calendarSubtitle => '选一个日子，慢慢安排生活';

  @override
  String calendarYears(int be, int ce) {
    return '佛历 $be 年 · 公历 $ce 年';
  }

  @override
  String calendarSmallEra(int year) {
    return '小历 $year 年';
  }

  @override
  String get calendarSelectHint => '轻点日期，查看当天的五项详情';

  @override
  String get calendarLoading => '正在展开月历…';

  @override
  String get calendarUnavailable => '这个月暂时无法读取，请重试。';

  @override
  String calendarRange(int start, int end) {
    return '可离线查看 · 公历 $start–$end 年';
  }

  @override
  String get calendarOutOfRange => '该日期不在当前日历范围内。';

  @override
  String get calendarWanPhra => '佛日';

  @override
  String get calendarKalayokTitle => '时辰吉凶 · 日类';

  @override
  String calendarFlag(String kind) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'thongchai': '胜旗日',
      'athibodi': '主宰日',
      'ubat': '凶日',
      'other': '灾厄日',
    });
    return '$_temp0';
  }

  @override
  String calendarFlagBody(String kind) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'thongchai': '传统择日中，象征开启与推进。',
      'athibodi': '传统择日中，关联主持与安排事务。',
      'ubat': '传统择日中，提醒做事多留余地。',
      'other': '传统择日中，提醒重大安排避免仓促。',
    });
    return '$_temp0';
  }

  @override
  String get calendarNoKalayok => '普通日 · 无特别日类标记';

  @override
  String get calendarMixedNote => '这一天同时符合多种日类，吉凶标记一并展示。';

  @override
  String get calendarLunarTitle => '月相日';

  @override
  String get calendarRiangMon => '枕席日';

  @override
  String get calendarRiangMonBody => '传统上用于婚嫁择日的月相日。';

  @override
  String get calendarLunarOrdinary => '今日不属于枕席日。';

  @override
  String get calendarUbakong => '乌巴空 · 吉时';

  @override
  String get calendarDaylight => '白昼时段 · 06:00–18:00 · 曼谷时间';

  @override
  String get calendarMansion => '二十七宿';

  @override
  String calendarMansionPosition(int index, int quarter) {
    return '第 $index 宿 / 共 27 宿 · 第 $quarter 足';
  }

  @override
  String get calendarMansionReference => '取曼谷正午的月亮位置，星宿可能在日内变化。';

  @override
  String get calendarReference => '泰国传统历法 · 用于文化参考与娱乐';

  @override
  String calendarLunarShort(String phase, int day) {
    String _temp0 = intl.Intl.selectLogic(phase, {'waxing': '盈', 'other': '亏'});
    return '$_temp0$day';
  }

  @override
  String calendarMonth(String month) {
    String _temp0 = intl.Intl.selectLogic(month, {
      '1': '一月',
      '2': '二月',
      '3': '三月',
      '4': '四月',
      '5': '五月',
      '6': '六月',
      '7': '七月',
      '8': '八月',
      '9': '九月',
      '10': '十月',
      '11': '十一月',
      '12': '十二月',
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
      '16': '毗舍佉宿 · Vishakha',
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
  String get estimated => '估算';

  @override
  String get estimatedChart => '估算星盘 · 当地12:00';

  @override
  String get estimatedChartNote =>
      '未填写具体出生时间，本盘按出生地当地12:00生成。月亮、上升、宫位及相位均为估算，可能随实际出生时间变化。补充时间后可重新排盘。';

  @override
  String get readingChart => '这份解读对应的星盘';

  @override
  String get readingChartIntro => '下面的解读都来自这张本命星盘。点击星体可以查看它的位置。';

  @override
  String get readingContents => '解读目录';

  @override
  String get readingContentsHint => '点击主题，直接阅读对应的内容。';

  @override
  String get backToChart => '返回星盘';

  @override
  String get savedReadings => '历史解读';

  @override
  String get noSavedReports => '暂无报告';

  @override
  String get reportRecords => '报告记录';

  @override
  String get reportRecordsIntro => '报告按生成时间排列，输入编号即可查找对应记录。';

  @override
  String get searchReportNumber => '输入报告编号搜索';

  @override
  String get clearSearch => '清空搜索';

  @override
  String get noMatchingReports => '未找到对应编号的报告，请检查编号后重试。';

  @override
  String get reportNumberLabel => '报告编号';

  @override
  String get generatedAt => '生成时间';

  @override
  String get reportReady => '已生成';

  @override
  String get reportRunning => '生成中';

  @override
  String get reportFailedShort => '生成未完成';

  @override
  String get deleteReport => '删除报告';

  @override
  String get deleteReportConfirm => '确定删除这条报告记录吗？删除后将无法从记录中再次打开。';

  @override
  String get reportDeleted => '报告记录已删除';

  @override
  String get deleteReportFailed => '删除失败，记录已保留，请稍后重试。';

  @override
  String get reportDeleteBusy => '报告仍在生成，请完成后再删除。';

  @override
  String get loadReportsFailed => '暂时无法读取报告记录，请重新加载。';

  @override
  String get refreshRecords => '重新加载';

  @override
  String get chartReportsLocation => '星盘解读已在独立页面展示，请从“星盘”进入查看。';

  @override
  String get progressTitle => '正在生成你的解读';

  @override
  String get progressIntro => '逐步整理六个主题并检查整份报告，完成后将自动打开解读页面。';

  @override
  String get progressPreparing => '正在准备解读资料';

  @override
  String get progressWriting => '正在整理个人解读';

  @override
  String get progressChecking => '正在检查整份报告';

  @override
  String get progressRefining => '正在完善解读建议';

  @override
  String get progressComplete => '报告已完成，正在打开';

  @override
  String get progressFailed => '这次解读暂未完成';

  @override
  String progressTopics(Object completed, Object total) {
    return '已整理 $completed/$total 个主题';
  }

  @override
  String get progressReturn => '返回报告';

  @override
  String get progressReconnect => '重新连接';

  @override
  String get progressDisconnected => '暂时无法获取最新进度，后台任务不会因此取消。你可以重新连接或稍后回来查看。';

  @override
  String get progressLater => '稍后再看';

  @override
  String get progressPersonality => '个人特质';

  @override
  String get progressCareer => '事业发展';

  @override
  String get progressMoney => '财务习惯';

  @override
  String get progressRelationships => '感情与家庭';

  @override
  String get progressWatch => '需要留意的地方';

  @override
  String get progressActions => '行动建议';

  @override
  String get reportServiceBusy => '解读服务暂时繁忙，报告尚未完成。你的星盘已保留，请稍后重试。';

  @override
  String get reportServiceTimeout => '这次解读等待超时，报告尚未完成。你的星盘已保留，请稍后重试。';
}
