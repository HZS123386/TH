// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Vietnamese (`vi`).
class AppLocalizationsVi extends AppLocalizations {
  AppLocalizationsVi([String locale = 'vi']) : super(locale);

  @override
  String get h5CodeLogin => 'Đăng nhập bằng mã từ web';

  @override
  String get h5CodeHelp =>
      'Nhập mã gồm 6 chữ cái và chữ số trên trang báo cáo H5 để đồng bộ báo cáo của trình duyệt đó.';

  @override
  String get h5CodeField => 'Mã đăng nhập từ web';

  @override
  String get h5CodeInvalid =>
      'Mã không hợp lệ, đã hết hạn hoặc đã được dùng. Hãy lấy mã mới trên web.';

  @override
  String get h5CodeRateLimited => 'Bạn đã thử quá nhiều lần. Hãy thử lại sau.';

  @override
  String get h5Account => 'Tài khoản web';

  @override
  String get h5Reports => 'Báo cáo từ web';

  @override
  String get h5ReportsEmpty => 'Trình duyệt này chưa có báo cáo.';

  @override
  String get h5LoadMore => 'Tải báo cáo cũ hơn';

  @override
  String get h5Refresh => 'Làm mới báo cáo';

  @override
  String get h5ReportUnavailable =>
      'Chưa mở được báo cáo này. Hãy làm mới hoặc xem trên web.';

  @override
  String get h5ReportQueued => 'Đã mở khóa · Đang xếp hàng';

  @override
  String get h5ReportGenerating => 'Đã mở khóa · Đang tạo báo cáo';

  @override
  String get h5ReportLimited => 'Đã mở khóa · Chạm giới hạn tạo báo cáo';

  @override
  String get h5ReportIncomplete => 'Đã mở khóa · Báo cáo chưa hoàn tất';

  @override
  String get h5ReportLimitedHelp =>
      'Bạn có thể đọc các chương đã hoàn tất. Hãy quay lại trang web ban đầu để tiếp tục tạo báo cáo sau.';

  @override
  String get h5Plan => 'Kế hoạch hành động';

  @override
  String get h5Insight => 'Điểm chính';

  @override
  String get h5Watchpoint => 'Điều cần lưu ý';

  @override
  String get h5Example => 'Ví dụ trong cuộc sống';

  @override
  String get h5Pitfall => 'Điều nên tránh';

  @override
  String get h5Check => 'Cách theo dõi tiến triển';

  @override
  String get actionTodo => 'Chờ thực hiện';

  @override
  String get actionReviewAvailable => 'Có thể xem lại';

  @override
  String get actionTypeService => 'Giúp đỡ và chia sẻ kiến thức';

  @override
  String get actionTypePractice => 'Rèn luyện bản thân';

  @override
  String get actionCompleted => 'Đã hoàn thành';

  @override
  String get newVisitorNote => 'Chọn người luận giải để bắt đầu';

  @override
  String get returningVisitorNote => 'Tiếp tục với bản luận giải trước';

  @override
  String get todayTab => 'Hôm nay';

  @override
  String get actionTab => 'Hành động';

  @override
  String get liveTab => 'Trực tiếp';

  @override
  String get objectsTab => 'Vật phẩm';

  @override
  String get todayQuestion => 'Hôm nay bạn muốn xem gì?';

  @override
  String get todayNote => 'Ba cách để tìm sự sáng tỏ';

  @override
  String get thaiGuide => 'Chiêm tinh Thái';

  @override
  String get sevenGuide => 'Thần số bảy số';

  @override
  String get tarotGuide => 'Bói bài Tarot';

  @override
  String get sirin => 'Sirin';

  @override
  String get arun => 'Arun';

  @override
  String get mira => 'Mira';

  @override
  String get sirinFocus => 'Vận hạn · Vận năm';

  @override
  String get arunFocus => 'Tính cách · Nhịp sống';

  @override
  String get miraFocus => 'Hiện tại · Bước tiếp theo';

  @override
  String get sirinHint => 'Xem vận gần đây để chọn thời điểm bước tiếp.';

  @override
  String get arunHint => 'Hiểu nhịp sống qua các con số ngày sinh.';

  @override
  String get miraHint => 'Mang theo một câu hỏi và rút lá bài cho hiện tại.';

  @override
  String get startThaiGuide => 'Nhập thông tin để xem chiêm tinh Thái';

  @override
  String get viewThaiGuide => 'Xem lá số Thái của tôi';

  @override
  String get startSevenGuide => 'Xem mẫu luận giải bảy số';

  @override
  String get startTarotGuide => 'Bắt đầu xem Tarot';

  @override
  String get textReading => 'Giải đáp qua tin nhắn';

  @override
  String get textReadingNote => 'Nhập câu hỏi và trò chuyện tiếp';

  @override
  String get voiceReading => 'Trò chuyện bằng giọng nói';

  @override
  String get voiceReadingNote => 'Nói ra điều đang băn khoăn';

  @override
  String get textChat => 'Nhắn tin';

  @override
  String get voiceChat => 'Đàm thoại';

  @override
  String get voicePreviewNotice =>
      'Bản xem trước chưa có đàm thoại. Bạn có thể nhắn tin tiếp.';

  @override
  String guideChatHeading(String name) {
    return 'Cùng $name gỡ rối';
  }

  @override
  String get startReading => 'Bắt đầu xem';

  @override
  String get guideChatDemo => 'Trò chuyện mẫu · Tin nhắn chỉ lưu trên thiết bị';

  @override
  String get guideGreeting => 'Hôm nay bạn muốn cùng tôi suy nghĩ về điều gì?';

  @override
  String get guidePromptWork => 'Gần đây tôi thấy mông lung về công việc';

  @override
  String get guidePromptLove => 'Tôi có nên chủ động trong tình cảm?';

  @override
  String get guideWorkReply =>
      'Hãy tách điều đã rõ khỏi điều còn chờ đợi. Tuần này bạn có thể chủ động xác nhận việc gì?';

  @override
  String get guideLoveReply =>
      'Bạn muốn người ấy hiểu điều gì nhất? Hãy thử nhắn lời hỏi thăm và để ý cảm xúc của mình.';

  @override
  String guideReflectReply(String question) {
    return 'Trong chuyện “$question”, hãy nghĩ xem hôm nay bạn làm chủ được điều gì. Việc nào có thể làm trong mười phút?';
  }

  @override
  String get continueSample => 'Tiếp tục cùng bản luận giải mẫu';

  @override
  String get readingSampleQuestion =>
      'Tôi đang chờ kết quả công việc. Tuần này có thể làm gì?';

  @override
  String get readingSampleLove => 'Bước tiếp theo trong mối quan hệ là gì?';

  @override
  String get readingSampleLife =>
      'Nhịp sống đã thay đổi. Tôi nên bắt đầu từ đâu?';

  @override
  String get recoverReports => 'Báo cáo của tôi';

  @override
  String get recentReadings => 'Luận giải gần đây';

  @override
  String get reportLookup => 'Link hoặc mã báo cáo';

  @override
  String get findReport => 'Tìm';

  @override
  String get reportLookupDemo =>
      'Dùng mã mẫu tại đây. Xem báo cáo cá nhân trong danh sách báo cáo.';

  @override
  String get reportCodeMissing =>
      'Không tìm thấy mẫu này. Hãy thử FATE-THAI-001.';

  @override
  String get newVisitor => 'Tôi là người dùng mới';

  @override
  String get returningVisitor => 'Tôi đã từng sử dụng';

  @override
  String get guideWelcomeLabel => 'Ba người luận giải · Ba phương pháp';

  @override
  String get guideWelcomeTitle => 'Trò chuyện\nvới vận mệnh.';

  @override
  String get guideWelcomeNote =>
      'Bắt đầu với một câu hỏi để nhìn lại bản thân.';

  @override
  String get onAirNow => 'Đang phát trực tiếp';

  @override
  String get demo => 'Mẫu';

  @override
  String get allItems => 'Tất cả';

  @override
  String get templeRoom => 'Lễ cầu phúc tại chùa';

  @override
  String get templeTeaser => 'Nghi lễ tại chùa';

  @override
  String get objectsRoom => 'Mở hộp vật phẩm';

  @override
  String get templeTeaserNote => 'Xem lễ · Nghe giới thiệu';

  @override
  String get objectsTeaserNote => 'Xem chi tiết · Cách dùng';

  @override
  String get templeRoomNote => 'Chùa đối tác A · Mẫu';

  @override
  String get switchRoom => 'Đổi phòng phát';

  @override
  String get templePosterTitle => 'Một điều ước,\nmột cuộc gặp trang trọng';

  @override
  String get objectsPosterTitle => 'Mang tâm ý\nvào mỗi ngày';

  @override
  String get liveDemoNotice => 'Xem thử · Cảnh minh họa';

  @override
  String get livestreamPause => 'Tạm dừng xem thử';

  @override
  String get livestreamPlay => 'Phát xem thử';

  @override
  String get fullScreenPreview => 'Mở rộng xem thử';

  @override
  String get templeRoomHeading => 'Mang điều ước đến chùa';

  @override
  String get templeService => 'Cầu phúc cá nhân';

  @override
  String get samplePrice => 'Giá mẫu';

  @override
  String get bookingInfo => 'Thông tin đặt lễ';

  @override
  String get bookingDemoNotice =>
      'Xem quy trình đặt lễ và mô tả nghi lễ. Lịch chính thức chưa mở.';

  @override
  String get roomChat => 'Tương tác';

  @override
  String get ceremonyInfo => 'Về nghi lễ';

  @override
  String get roomObjectsInfo => 'Vật phẩm giới thiệu';

  @override
  String get roomWelcomeDemo =>
      'Người dẫn · Mẫu    Chào mừng. Bạn có thể xem phần giới thiệu buổi này.';

  @override
  String get templeSegmentOne => 'Viết điều ước muốn mang đến chùa';

  @override
  String get templeSegmentTwo => 'Tìm hiểu quy trình lễ cầu phúc';

  @override
  String get templeSegmentThree => 'Lưu lại điều ước';

  @override
  String get roomMessageHint => 'Thử gửi một tin nhắn mẫu';

  @override
  String get myActions => 'Hành động của tôi';

  @override
  String get actionPending => 'Chờ thực hiện';

  @override
  String get actionDone => 'Đã hoàn thành';

  @override
  String get actionReady => 'Có thể xem lại';

  @override
  String get chooseFamilyAction => 'Lên ngày hành động cho gia đình';

  @override
  String get weeklyMoment => 'Dành một ngày để hành động';

  @override
  String get weeklyMomentNote =>
      'Chọn một ngày mỗi tuần để làm vài việc tốt nhỏ. Bạn có thể linh hoạt.';

  @override
  String get myWeeklyDay => 'Ngày hành động của tôi';

  @override
  String get arrangeDay => 'Chọn ngày';

  @override
  String get actionLedger => 'Sổ hành động của tôi';

  @override
  String get actionDailySuggestion => 'Gợi ý hôm nay';

  @override
  String get actionUseSuggestion => 'Thêm việc này';

  @override
  String get actionCustomPlan => 'Tự đặt việc cần làm';

  @override
  String get actionCompleteNow => 'Hoàn thành';

  @override
  String get actionSuggestionThanks => 'Nhắn lời cảm ơn đến người đã giúp bạn';

  @override
  String get actionSuggestionCheckIn => 'Hỏi thăm một người bạn';

  @override
  String get actionSuggestionShare => 'Chia sẻ một điều hữu ích với ai đó';

  @override
  String get offeringEnergy => 'Năng lượng hành động';

  @override
  String get offeringJasmine => 'Vòng hoa nhài';

  @override
  String get offeringLotus => 'Hoa sen dâng lễ';

  @override
  String get offeringMarigold => 'Vòng hoa vạn thọ';

  @override
  String offeringCollected(int count) {
    return 'Đã thu thập $count vật phẩm';
  }

  @override
  String offeringPerAction(int points) {
    return 'Hoàn thành một việc để nhận $points điểm năng lượng.';
  }

  @override
  String get offeringPresenting => 'Đang dâng lễ vật…';

  @override
  String get offeringComplete => 'Đã dâng lễ vật';

  @override
  String get offeringBlessing =>
      'Mong việc thiện nâng đỡ bạn, may mắn đồng hành và điều bạn ấp ủ thành hiện thực.';

  @override
  String get offeringNext => 'Việc tiếp theo sẽ bắt đầu một vật phẩm mới.';

  @override
  String get newPlan => 'Kế hoạch mới';

  @override
  String get noActionPlan => 'Những việc nhỏ bạn chọn làm sẽ hiện ở đây.';

  @override
  String get actionRecord => 'Bản ghi hành động của tôi';

  @override
  String get actionTitle => 'Điều tôi muốn làm';

  @override
  String get careAction => 'Giúp đỡ một người bên cạnh';

  @override
  String get familyAction => 'Làm vài việc nhỏ cho gia đình';

  @override
  String get actionCategory => 'Loại hành động';

  @override
  String get beneficiary => 'Dành cho ai';

  @override
  String get forSelf => 'Bản thân';

  @override
  String get forOthers => 'Người bên cạnh';

  @override
  String get forFamily => 'Gia đình';

  @override
  String get recordMethod => 'Cách ghi';

  @override
  String get recordOnDevice => 'Ghi chú trên thiết bị';

  @override
  String get actionDate => 'Ngày hành động';

  @override
  String get reviewDate => 'Ngày xem lại';

  @override
  String get actionNotes => 'Điều tôi đã làm';

  @override
  String get actionReview => 'Suy ngẫm của tôi';

  @override
  String get questionProgress => 'Câu hỏi ban đầu đã tiến triển ra sao?';

  @override
  String get actionReviewed => 'Đã xem lại';

  @override
  String get recordAction => 'Lưu một việc nhỏ';

  @override
  String get clearPrototypeRecords => 'Xóa hành động và hội thoại mẫu';

  @override
  String get storeTitle => 'Vật phẩm tâm ý';

  @override
  String get storeIntro => 'Mang những điều yêu thích vào cuộc sống mỗi ngày.';

  @override
  String get storeSearch => 'Tìm sổ tay, hương thơm, trang sức…';

  @override
  String get scentCategory => 'Hương thơm';

  @override
  String get jewelryCategory => 'Trang sức';

  @override
  String get journalCategory => 'Sổ tay';

  @override
  String get lifeCategory => 'Đời sống';

  @override
  String get sampleCatalog => 'Danh mục mẫu';

  @override
  String get objectJournal => 'Sổ hành động tâm ý';

  @override
  String get objectCandle => 'Nến thơm thư giãn';

  @override
  String get objectBracelet => 'Vòng tay điều ước';

  @override
  String get objectDiffuser => 'Tinh dầu khuếch tán ban mai';

  @override
  String get objectJournalNote => 'Biến điều ước thành bước tiếp theo';

  @override
  String get objectCandleNote => 'Dành cho mình một lúc yên tĩnh';

  @override
  String get objectBraceletNote => 'Mang theo một điều ước nhỏ';

  @override
  String get objectDiffuserNote => 'Bắt đầu ngày mới với mùi hương quen thuộc';

  @override
  String get shopOrders => 'Đơn của tôi';

  @override
  String get shopCart => 'Giỏ hàng';

  @override
  String get addToCart => 'Thêm vào giỏ';

  @override
  String get cartEmpty => 'Giỏ hàng còn trống';

  @override
  String get shopEmpty => 'Không tìm thấy vật phẩm phù hợp';

  @override
  String get shopOrdersEmpty => 'Chưa có đơn vật phẩm';

  @override
  String get shopDemoNotice => 'Đây là cửa hàng mẫu, chưa mở đặt hàng.';

  @override
  String get mySpace => 'Luận giải và ghi chép của tôi';

  @override
  String get mySpaceIntro => 'Báo cáo, hành động và dự định của bạn ở đây.';

  @override
  String get actionsAndReviews => 'Hành động và nhìn lại';

  @override
  String get resumeCompanion => 'Tiếp tục trò chuyện';

  @override
  String get fortunePeriods => 'Vận hôm nay, tuần, tháng và năm';

  @override
  String get thaiChartIntro => 'Xem lá số Thái theo ngày, giờ và nơi sinh.';

  @override
  String get sevenPreviewNote =>
      'Bản xem trước chưa tính được bảy số. Hãy thử trò chuyện mẫu với Arun.';

  @override
  String get country => 'Quốc gia / khu vực';

  @override
  String get countryTH => 'Thái Lan';

  @override
  String get countryCN => 'Trung Quốc';

  @override
  String get countryVN => 'Việt Nam';

  @override
  String get countryUS => 'Hoa Kỳ';

  @override
  String get noCityResults =>
      'Không tìm thấy thành phố phù hợp. Hãy thử tên khác hoặc quay lại nhập nơi sinh và múi giờ.';

  @override
  String get retryPurchase => 'Xác minh lại giao dịch';

  @override
  String get sampleLoveText =>
      'Góc vuông Sao Thủy–Sao Hỏa trong ví dụ gợi xem xét nhịp giao tiếp và hành động. Bạn có thể đã có cách giải quyết trong khi người kia vẫn cần được thấu hiểu. Hãy nhắc lại điều họ lo, rồi hỏi họ muốn được lắng nghe hay nhận gợi ý.';

  @override
  String get sampleLoveAction =>
      'Lần tới khi bất đồng, thử nói: “Tôi hiểu bạn lo về… có đúng không?” Đợi xác nhận, nói từng việc một, rồi thống nhất ai làm gì và khi nào trao đổi lại.';

  @override
  String get sampleWorkText =>
      'Góc đối Mặt Trời–Sao Thổ trong ví dụ gợi cân bằng giữa chủ động thể hiện và trách nhiệm. Mong làm tốt có thể khiến góp ý trở thành lời phán xét năng lực trong cảm nhận của bạn. Hãy chuyển góp ý thành từng phần việc cụ thể có thể sửa.';

  @override
  String get sampleWorkAction =>
      'Trước khi bắt đầu, ghi sản phẩm cần bàn giao, thời hạn và người duyệt. Khi nhận góp ý, hỏi hai điểm nên sửa trước. Ghi lại điều đã tốt hơn sau chỉnh sửa để thấy tiến bộ qua công việc thực tế.';

  @override
  String get sampleMoneyText =>
      'Góc tam hợp Sao Kim–Sao Hải Vương trong ví dụ gợi nhìn lại sở thích về cái đẹp và cuộc sống lý tưởng. Trước khi mua, tách công dụng thật khỏi hình ảnh cuộc sống mà món đồ đại diện. Phần này nói về thói quen chi tiêu, không dự báo lợi nhuận hay thị trường.';

  @override
  String get sampleMoneyAction =>
      'Lưu món ngoài kế hoạch và chưa thanh toán. Ngày hôm sau, ghi mục đích, tần suất dùng và ngân sách tháng còn lại. Nếu chi chung, thống nhất cách chia trước khi trả tiền.';

  @override
  String get sunMeaning =>
      'Mặt Trời tượng trưng cho cách bạn thể hiện bản thân và điều mang lại cảm giác có ý nghĩa.';

  @override
  String get moonMeaning =>
      'Mặt Trăng tượng trưng cho nhu cầu cảm xúc và điều giúp bạn cảm thấy an toàn.';

  @override
  String get mercuryMeaning =>
      'Sao Thủy tượng trưng cho thói quen suy nghĩ, học hỏi và giao tiếp.';

  @override
  String get venusMeaning =>
      'Sao Kim tượng trưng cho điều bạn trân trọng và cách thể hiện tình cảm, xây dựng quan hệ.';

  @override
  String get marsMeaning =>
      'Sao Hỏa tượng trưng cho cách hành động, theo đuổi mục tiêu và xử lý bất đồng.';

  @override
  String get jupiterMeaning =>
      'Sao Mộc tượng trưng cho việc học hỏi, tìm cơ hội và mở rộng góc nhìn.';

  @override
  String get saturnMeaning =>
      'Sao Thổ tượng trưng cho trách nhiệm, giới hạn và kỹ năng cần thời gian vun đắp.';

  @override
  String get uranusMeaning =>
      'Sao Thiên Vương tượng trưng cho việc thay đổi thói quen cũ và thử cách làm độc lập.';

  @override
  String get neptuneMeaning =>
      'Sao Hải Vương tượng trưng cho trí tưởng tượng, lý tưởng và việc phân biệt kỳ vọng với thực tế.';

  @override
  String get plutoMeaning =>
      'Sao Diêm Vương tượng trưng cho thay đổi sâu sắc, sự kiểm soát và việc tìm lại sức mạnh.';

  @override
  String get home => 'Trang chủ';

  @override
  String get chart => 'Bản đồ sao';

  @override
  String get reports => 'Báo cáo';

  @override
  String get mine => 'Cá nhân';

  @override
  String get system => 'Chiêm tinh phương Tây';

  @override
  String get heroTitle => 'Đọc bản đồ sao,\nhiểu chính mình';

  @override
  String get heroText =>
      'Khám phá tính cách, mối quan hệ và hướng đi từ thời điểm bạn chào đời.';

  @override
  String get heroBadge => 'Câu chuyện sao của riêng bạn';

  @override
  String get start => 'Bắt đầu bản đồ sao';

  @override
  String get birth => 'Thông tin sinh';

  @override
  String get birthNote => 'Ghi lại nơi và giờ sinh';

  @override
  String get birthIntro =>
      'Ngày, giờ và nơi sinh giúp xác định hành tinh, cung Mọc và các nhà. Bạn có thể chỉnh sửa bất cứ lúc nào.';

  @override
  String get chartNote => 'Hành tinh · Cung · Các nhà';

  @override
  String get reportNote => 'Tính cách · Quan hệ · Công việc';

  @override
  String get fullReport => 'Luận giải đầy đủ';

  @override
  String get fullNote => 'Gợi ý cụ thể và bước tiếp theo';

  @override
  String get homeReportTitle => 'Báo cáo kể về chính bạn';

  @override
  String get homeReportText =>
      'Hiểu các đặc điểm của mình, rồi khám phá lựa chọn trong quan hệ, công việc và thói quen tài chính.';

  @override
  String get viewReport => 'Xem luận giải';

  @override
  String get journey => 'Bắt đầu khám phá từng bước';

  @override
  String get stepBirth => 'Nhập thông tin sinh';

  @override
  String get stepChart => 'Khám phá bản đồ sao';

  @override
  String get stepReport => 'Đọc luận giải cá nhân';

  @override
  String get example => 'Xem bản đồ sao mẫu';

  @override
  String get exampleReport => 'Xem báo cáo mẫu';

  @override
  String get exampleBadge => 'Ví dụ minh họa';

  @override
  String get exampleNote =>
      'Minh họa cách đọc bản đồ sao và báo cáo, không được tính từ thông tin sinh của bạn.';

  @override
  String get myChart => 'Bản đồ sao của tôi';

  @override
  String get myChartText => 'Hiểu bản đồ sao bằng ngôn ngữ gần gũi.';

  @override
  String get noChart => 'Bản đồ sao bắt đầu từ bạn';

  @override
  String get noChartText =>
      'Nhập thông tin sinh để khám phá hành tinh, các cung và nhà của riêng bạn.';

  @override
  String get waiting => 'Đang chuẩn bị bản đồ sao';

  @override
  String get unavailable => 'Dịch vụ bản đồ sao chưa sẵn sàng';

  @override
  String get unavailableText =>
      'Thông tin sinh đã lưu trên thiết bị này. Bạn có thể xem ví dụ hoặc thử lấy kết quả sau.';

  @override
  String get retry => 'Lấy lại bản đồ sao';

  @override
  String get editBirth => 'Sửa thông tin sinh';

  @override
  String get sun => 'Mặt Trời';

  @override
  String get moon => 'Mặt Trăng';

  @override
  String get ascendant => 'Cung Mọc';

  @override
  String get planets => 'Vị trí hành tinh';

  @override
  String get houses => 'Mười hai nhà';

  @override
  String get aspects => 'Các góc chính';

  @override
  String get planetHint => 'Chạm vào hành tinh để tìm hiểu vai trò của nó.';

  @override
  String get unknownTime =>
      'Chưa biết giờ sinh nên không hiển thị cung Mọc và những nhà phụ thuộc vào giờ.';

  @override
  String get chartRead => 'Đọc bản đồ sao này';

  @override
  String get house => 'Nhà';

  @override
  String get emptyValue => 'Chờ kết quả';

  @override
  String get reportTitle => 'Báo cáo bản đồ sao cá nhân';

  @override
  String get reportIntro =>
      'Tìm hiểu từng bước, từ đặc điểm chung đến những lựa chọn hằng ngày.';

  @override
  String get free => 'Đọc thử miễn phí';

  @override
  String get premium => 'Nội dung đầy đủ';

  @override
  String get reportEmpty => 'Luận giải sẽ được lưu ở đây';

  @override
  String get reportEmptyText =>
      'Tạo bản đồ sao cá nhân trước để xem luận giải và trạng thái báo cáo.';

  @override
  String get generate => 'Tạo báo cáo của tôi';

  @override
  String get summary => 'Kết luận trước';

  @override
  String get traits => 'Đặc điểm bạn có thể nhận ra';

  @override
  String get watch => 'Điều cần lưu ý';

  @override
  String get advice => 'Các bước có thể thử';

  @override
  String get reportScope => 'Nội dung báo cáo';

  @override
  String get chapterPersonality => 'Tính cách và biểu đạt';

  @override
  String get chapterLove => 'Quan hệ và giao tiếp';

  @override
  String get chapterWork => 'Công việc và phát triển';

  @override
  String get chapterMoney => 'Thói quen tài chính';

  @override
  String get reportSaved => 'Đã lưu ví dụ';

  @override
  String get saveReport => 'Lưu ví dụ';

  @override
  String get savedReports => 'Ví dụ lưu trên thiết bị';

  @override
  String get openReport => 'Mở báo cáo';

  @override
  String get remove => 'Xóa';

  @override
  String get exampleSavedNote =>
      'Ví dụ được lưu riêng và không trở thành kết quả cá nhân của bạn.';

  @override
  String get unlock => 'Đọc luận giải đầy đủ';

  @override
  String get lockedTitle => 'Khám phá bản đồ sao sâu hơn';

  @override
  String get lockedText =>
      'Bản đầy đủ có lưu ý cụ thể, ví dụ gần gũi và các bước thực hành.';

  @override
  String get offerTitle => 'Mở khóa báo cáo bản đồ sao';

  @override
  String get offerText =>
      'Mua một lần để đọc nội dung đầy đủ trong phạm vi sản phẩm.';

  @override
  String get offerFeature1 => 'Đặc điểm cá nhân và bốn chủ đề cuộc sống';

  @override
  String get offerFeature2 => 'Lưu ý, ví dụ và gợi ý thực hành';

  @override
  String get offerFeature3 => 'Xem lại báo cáo và khôi phục giao dịch';

  @override
  String get appleBuy => 'Mua trong ứng dụng iOS';

  @override
  String get pricePending => 'Giá theo thông tin trên App Store';

  @override
  String get purchasePreview =>
      'Đây là bản xem trước trong trình duyệt, không thể mua qua Apple và không thu tiền.';

  @override
  String get restore => 'Khôi phục giao dịch';

  @override
  String get restoreNote =>
      'Hãy khôi phục trong ứng dụng iOS bằng tài khoản mua ban đầu. Trình duyệt này không đọc được giao dịch Apple.';

  @override
  String get previewFull => 'Xem toàn bộ ví dụ';

  @override
  String get previewFullNote =>
      'Chỉ mở ví dụ minh họa, không tạo giao dịch hay quyền báo cáo cá nhân.';

  @override
  String get purchaseHistory => 'Nội dung đã mua';

  @override
  String get noPurchases => 'Chưa có giao dịch được xác minh';

  @override
  String get noPurchasesText =>
      'Báo cáo sẽ xuất hiện sau khi giao dịch được xác minh trong ứng dụng iOS.';

  @override
  String get account => 'Tài khoản của tôi';

  @override
  String get guest => 'Khách';

  @override
  String get signedIn => 'Đã đăng nhập';

  @override
  String get accountText =>
      'Lưu thông tin và báo cáo để tiếp tục khám phá bản thân.';

  @override
  String get deviceProfile => 'Thông tin sinh';

  @override
  String get language => 'Ngôn ngữ';

  @override
  String get largeText => 'Chữ lớn';

  @override
  String get privacy => 'Thông tin và riêng tư';

  @override
  String get privacyText =>
      'Bản nháp và thông tin truy cập được lưu trên thiết bị. Thông tin sinh, bản đồ sao và báo cáo thuộc phiên khách hoặc tài khoản hiện tại. RoxyAPI tính bản đồ sao; AI tạo báo cáo chỉ nhận dữ kiện bản đồ sao, không nhận tên, tên thành phố hay lịch sử trò chuyện.\n\nTrò chuyện với thần hộ mệnh sẽ gửi tin nhắn, thông tin sinh, hội thoại liên quan, ký ức đã xác nhận và nội dung bạn chọn đã được phép xem tới dịch vụ AI để trả lời và tiếp tục câu chuyện. Xóa dữ liệu cục bộ không xóa bản ghi trên máy chủ.';

  @override
  String get clearBirth => 'Xóa thông tin sinh trong máy';

  @override
  String get clearConfirm => 'Xóa thông tin sinh đã lưu trên thiết bị này?';

  @override
  String get cleared => 'Đã xóa thông tin sinh trong máy';

  @override
  String get saved => 'Đã lưu thông tin sinh';

  @override
  String get saveBirth => 'Lưu và xem bản đồ sao';

  @override
  String get nickname => 'Tên muốn được gọi không bắt buộc';

  @override
  String get nicknamePlaceholder => 'Bạn muốn được gọi thế nào?';

  @override
  String get placeRequired => 'Chọn hoặc nhập nơi sinh';

  @override
  String get close => 'Đóng';

  @override
  String get cancel => 'Hủy';

  @override
  String get back => 'Quay lại';

  @override
  String get birthStorage =>
      'Tạo bản đồ sao và đọc báo cáo mà không cần đăng nhập. Bạn có thể xem lại kết quả trên thiết bị này.';

  @override
  String get profileMissing => 'Chưa có thông tin sinh';

  @override
  String get connection =>
      'Dịch vụ tạm thời không kết nối được. Bạn vẫn có thể xem ví dụ.';

  @override
  String get error => 'Chưa thể hoàn tất, vui lòng thử lại sau.';

  @override
  String get sampleSummary =>
      'Bạn có thể coi trọng việc làm tốt và muốn ý tưởng được ghi nhận. Hãy nói rõ trọng tâm rồi chừa chỗ cho sự hợp tác.';

  @override
  String get sampleTrait1Title => 'Muốn có tiếng nói riêng';

  @override
  String get sampleTrait1Text =>
      'Mặt Trời ở Sư Tử trong ví dụ gợi chuyện biểu đạt và sáng tạo. Với việc quen thuộc, bạn có thể muốn đề xuất trước. Khi ý tưởng không được chọn, hỏi lý do sẽ hữu ích hơn vội chứng minh mình đúng.';

  @override
  String get sampleTrait2Title => 'Cân bằng tự do với trách nhiệm';

  @override
  String get sampleTrait2Text =>
      'Xu hướng khám phá của Mặt Trăng và liên hệ Mặt Trời–Sao Thổ trong ví dụ gợi suy ngẫm về tự do và bổn phận. Đặt thời gian nghỉ rõ ràng và ghi lại điều đã hứa để cả hai nhu cầu đều có chỗ.';

  @override
  String get sampleWatch1Title => 'Ý kiến khác không nhất thiết phủ nhận bạn';

  @override
  String get sampleWatch1Text =>
      'Khi ai đó sửa kế hoạch hoặc chưa trả lời, hãy hỏi họ lo về cách làm hay mục tiêu. Quan sát việc giải thích gấp, ngắt lời hoặc kiểm tra tin nhắn liên tục. Hỏi “Phần nào khiến bạn lo nhất?” rồi cùng quyết định điều cần đổi.';

  @override
  String get sampleWatch2Title => 'Chừa thời gian trước khi nhận lời';

  @override
  String get sampleWatch2Text =>
      'Mong được công nhận có thể khiến bạn nhận quá sức. Kiểm tra lịch, khối lượng và cam kết hiện tại trước khi trả lời. Nếu chưa chắc, có thể nói “Để tôi xem lại lịch và trả lời vào ngày mai”, rồi nhận lời trong khả năng thực hiện.';

  @override
  String get sampleAdvice1Title => 'Chuẩn bị ba câu cho cuộc trao đổi';

  @override
  String get sampleAdvice1Text =>
      'Viết sự việc quan sát được, nhu cầu và một đề nghị cụ thể. Ví dụ: “Kế hoạch đổi hai lần tuần này, tôi muốn xác nhận hướng đi. Ta dành mười phút chốt ưu tiên được không?” Sau đó lắng nghe và ghi lại điều đã thống nhất.';

  @override
  String get sampleAdvice2Title => 'Biến mục tiêu thành việc nhỏ hôm nay';

  @override
  String get sampleAdvice2Text =>
      'Chọn một mục tiêu, ghi thông tin cần có, bước đầu và cách kiểm tra. Dành hai mươi phút thu thập ba phản hồi hoặc viết nháp email. Chỉ kiểm tra bước này đã hoàn thành chưa trước khi chọn bước tiếp theo.';

  @override
  String get sampleAdvice3Title => 'Dành thời gian nhìn lại mỗi tuần';

  @override
  String get sampleAdvice3Text =>
      'Ở một thời điểm cố định, ghi một điều hữu ích, một cuộc trao đổi chưa suôn sẻ và một điều nhỏ muốn thử khác đi. Dựa trên sự việc thật để xem gợi ý có phù hợp; có thể bỏ qua hoặc đổi cách nếu không giúp ích.';

  @override
  String get login => 'Đăng nhập';

  @override
  String get logout => 'Đăng xuất';

  @override
  String get register => 'Tạo tài khoản';

  @override
  String get username => 'Tên tài khoản';

  @override
  String get password => 'Mật khẩu';

  @override
  String get confirmPassword => 'Xác nhận mật khẩu';

  @override
  String get passwordMismatch => 'Hai mật khẩu không khớp';

  @override
  String get birthDate => 'Ngày sinh';

  @override
  String get birthTime => 'Giờ sinh';

  @override
  String get timezone => 'Múi giờ nơi sinh';

  @override
  String get birthplace => 'Thành phố nơi sinh';

  @override
  String get birthplacePlaceholder => 'Ví dụ: Hà Nội';

  @override
  String get pickerDone => 'Xong';

  @override
  String get pickerCancel => 'Hủy lựa chọn';

  @override
  String get chooseBirthDate => 'Chọn ngày sinh';

  @override
  String get chooseBirthTime => 'Chọn giờ sinh';

  @override
  String get searchBirthCity => 'Tìm thành phố hoặc quận';

  @override
  String get searchTimezone => 'Tìm múi giờ, ví dụ Asia/Bangkok';

  @override
  String get appleLogin => 'Đăng nhập bằng Apple';

  @override
  String get developmentLogin => 'Tài khoản thử nghiệm';

  @override
  String get nativeSetup =>
      'Đây là môi trường xem trước. Đăng nhập và mua trong ứng dụng cần cấu hình dịch vụ.';

  @override
  String get calendarGregorian => 'Dương lịch';

  @override
  String get calendarBuddhist => 'Phật lịch';

  @override
  String get timeUnknown => 'Không nhớ giờ sinh chính xác';

  @override
  String get reportPending =>
      'Báo cáo đang được tạo. Bạn có thể rời đi rồi quay lại.';

  @override
  String get resumeReport => 'Tiếp tục báo cáo gần nhất';

  @override
  String get loginRequired => 'Đăng nhập trước khi mua';

  @override
  String get serviceSetup =>
      'Dịch vụ chưa sẵn sàng. Bạn có thể xem ví dụ học tập.';

  @override
  String get exactBirth => 'Biết giờ sinh';

  @override
  String get dateOnly => 'Chỉ biết ngày sinh';

  @override
  String get dataPrecision => 'Độ chính xác thông tin sinh';

  @override
  String get cityDirectory => 'Tìm trong danh mục thành phố';

  @override
  String get findCity => 'Tìm thành phố';

  @override
  String get deleteAccount => 'Xóa tài khoản';

  @override
  String get deletionSetup =>
      'Cần bật dịch vụ xóa tài khoản trên máy chủ trước khi gửi yêu cầu.';

  @override
  String get aiConsent =>
      'Để soạn luận giải, dữ kiện bản đồ sao đã tính sẽ được gửi đến dịch vụ trí tuệ nhân tạo, không kèm tên, tên thành phố hoặc lịch sử trò chuyện. Bạn đồng ý chứ?';

  @override
  String get consentGenerate => 'Đồng ý và tạo';

  @override
  String get decline => 'Không đồng ý';

  @override
  String get purchaseVerifying =>
      'Giao dịch đang được xác minh. Hãy tải lại báo cáo sau.';

  @override
  String get personalReport => 'Báo cáo cá nhân';

  @override
  String get missingAngles =>
      'Chưa có cung Mọc và các nhà. Chỉ hiển thị vị trí hành tinh đã biết.';

  @override
  String get languageHelp => 'Đổi giữa tiếng Thái, Anh, Trung và Việt tại đây.';

  @override
  String get continueChart => 'Xem tiếp bản đồ sao';

  @override
  String get pSun => 'Mặt Trời';

  @override
  String get pMoon => 'Mặt Trăng';

  @override
  String get pMercury => 'Sao Thủy';

  @override
  String get pVenus => 'Sao Kim';

  @override
  String get pMars => 'Sao Hỏa';

  @override
  String get pJupiter => 'Sao Mộc';

  @override
  String get pSaturn => 'Sao Thổ';

  @override
  String get pUranus => 'Sao Thiên Vương';

  @override
  String get pNeptune => 'Sao Hải Vương';

  @override
  String get pPluto => 'Sao Diêm Vương';

  @override
  String get zAries => 'Bạch Dương';

  @override
  String get zTaurus => 'Kim Ngưu';

  @override
  String get zGemini => 'Song Tử';

  @override
  String get zCancer => 'Cự Giải';

  @override
  String get zLeo => 'Sư Tử';

  @override
  String get zVirgo => 'Xử Nữ';

  @override
  String get zLibra => 'Thiên Bình';

  @override
  String get zScorpio => 'Bọ Cạp';

  @override
  String get zSagittarius => 'Nhân Mã';

  @override
  String get zCapricorn => 'Ma Kết';

  @override
  String get zAquarius => 'Bảo Bình';

  @override
  String get zPisces => 'Song Ngư';

  @override
  String get skipOpening => 'Bỏ qua mở đầu';

  @override
  String get tarot => 'Bài Tarot';

  @override
  String get luckyNumbers => 'Con số may mắn';

  @override
  String get tarotDraw => 'Rút ba lá bài';

  @override
  String get tarotDrawHint =>
      'Nghĩ đến câu hỏi của bạn rồi chọn ba lá trong trải bài.';

  @override
  String tarotChooseCard(int position) {
    return 'Rút lá bài số $position';
  }

  @override
  String get tarotResult => 'Ba lá bài của bạn';

  @override
  String get tarotDrawAgain => 'Rút lại';

  @override
  String get todayLuckyNumber => 'Số may mắn hôm nay';

  @override
  String get luckyNumberHint => 'Gợi ý từ con số hôm nay';

  @override
  String get luckyNumberUpdates => 'Cập nhật theo ngày trên thiết bị của bạn';

  @override
  String get tarotFool => 'Kẻ Khờ';

  @override
  String get tarotFoolMeaning =>
      'Thử một hướng mới bằng một bước nhỏ và cho mình thời gian để điều chỉnh.';

  @override
  String get tarotMagician => 'Nhà Ảo Thuật';

  @override
  String get tarotMagicianMeaning =>
      'Xem lại những kỹ năng và nguồn lực bạn có, rồi chọn một ý tưởng để thực hiện hôm nay.';

  @override
  String get tarotHighPriestess => 'Nữ Tư Tế';

  @override
  String get tarotHighPriestessMeaning =>
      'Dành chút thời gian yên tĩnh để quan sát và lắng nghe cảm nhận của mình trước khi hành động.';

  @override
  String get tarotEmpress => 'Hoàng Hậu';

  @override
  String get tarotEmpressMeaning =>
      'Dành thời gian cho việc khơi gợi sáng tạo và nghỉ ngơi khi bạn cần.';

  @override
  String get tarotEmperor => 'Hoàng Đế';

  @override
  String get tarotEmperorMeaning =>
      'Đặt mục tiêu và giới hạn rõ ràng, rồi sắp xếp công việc theo mức độ ưu tiên.';

  @override
  String get tarotHierophant => 'Giáo Hoàng';

  @override
  String get tarotHierophantMeaning =>
      'Hỏi ý kiến người bạn tin tưởng và chọn lời khuyên phù hợp với hoàn cảnh của mình.';

  @override
  String get tarotLovers => 'Đôi Tình Nhân';

  @override
  String get tarotLoversMeaning =>
      'Khi đứng trước lựa chọn, hãy xác định điều mình coi trọng và chia sẻ thật lòng.';

  @override
  String get tarotChariot => 'Cỗ Xe';

  @override
  String get tarotChariotMeaning =>
      'Chọn một hướng đi rồi tập trung sức lực vào bước quan trọng nhất.';

  @override
  String get tarotStrength => 'Sức Mạnh';

  @override
  String get tarotStrengthMeaning =>
      'Khi có bất đồng, hãy bình tâm một chút rồi phản hồi kiên định và nhẹ nhàng.';

  @override
  String get tarotHermit => 'Ẩn Sĩ';

  @override
  String get tarotHermitMeaning =>
      'Tạm rời những ý kiến xung quanh để suy nghĩ về câu trả lời bạn đang tìm.';

  @override
  String get tarotWheelOfFortune => 'Bánh Xe Số Phận';

  @override
  String get tarotWheelOfFortuneMeaning =>
      'Giữ cho kế hoạch linh hoạt và bắt đầu với phần bạn có thể kiểm soát.';

  @override
  String get tarotJustice => 'Công Lý';

  @override
  String get tarotJusticeMeaning =>
      'Cân nhắc cả sự thật lẫn cảm xúc, rồi đưa ra lựa chọn mà bạn sẵn lòng chịu trách nhiệm.';

  @override
  String get tarotHangedMan => 'Người Treo Ngược';

  @override
  String get tarotHangedManMeaning =>
      'Nếu đang bế tắc, hãy dừng lại một chút và nhìn sự việc từ một góc khác.';

  @override
  String get tarotDeath => 'Cái Chết';

  @override
  String get tarotDeathMeaning =>
      'Khép lại một việc đã đến hồi kết để nhường chỗ cho thói quen hoặc lựa chọn mới.';

  @override
  String get tarotTemperance => 'Tiết Độ';

  @override
  String get tarotTemperanceMeaning =>
      'Điều chỉnh từng chút để tìm sự cân bằng giữa hai nhu cầu đang cạnh tranh.';

  @override
  String get tarotDevil => 'Ác Quỷ';

  @override
  String get tarotDevilMeaning =>
      'Nhận ra thói quen đang lấy đi quá nhiều năng lượng và thay đổi từ một bước nhỏ.';

  @override
  String get tarotTower => 'Tòa Tháp';

  @override
  String get tarotTowerMeaning =>
      'Nếu kế hoạch bị xáo trộn, hãy xử lý việc cấp thiết nhất trước khi sắp xếp lại.';

  @override
  String get tarotStar => 'Ngôi Sao';

  @override
  String get tarotStarMeaning =>
      'Cho mình thời gian hồi phục và chọn một mục tiêu nhỏ mà bạn vẫn mong đợi.';

  @override
  String get tarotMoon => 'Mặt Trăng';

  @override
  String get tarotMoonMeaning =>
      'Khi sự việc chưa rõ ràng, hãy kiểm tra thông tin bạn có trước khi kết luận.';

  @override
  String get tarotSun => 'Mặt Trời';

  @override
  String get tarotSunMeaning =>
      'Ghi nhận tiến bộ của mình và chia sẻ một tin vui với người bạn tin tưởng.';

  @override
  String get tarotJudgement => 'Phán Xét';

  @override
  String get tarotJudgementMeaning =>
      'Nhìn lại lựa chọn trước đây, nhận ra điều đã học và cân nhắc bước tiếp theo.';

  @override
  String get tarotWorld => 'Thế Giới';

  @override
  String get tarotWorldMeaning =>
      'Khép lại việc đã hoàn thành, ghi lại điều bạn nhận được và chuẩn bị cho chặng tiếp theo.';

  @override
  String get luckyNumberOne =>
      'Bắt đầu một việc mới bằng một hành động nhỏ có thể làm hôm nay.';

  @override
  String get luckyNumberTwo =>
      'Dành thời gian hợp tác và lắng nghe góc nhìn của người khác.';

  @override
  String get luckyNumberThree =>
      'Chia sẻ, viết ra hoặc tạo một thứ gì đó từ ý tưởng của bạn.';

  @override
  String get luckyNumberFour =>
      'Sắp xếp thứ tự ưu tiên và bắt đầu với một việc dễ thực hiện.';

  @override
  String get luckyNumberFive =>
      'Thử một cách làm khác và giữ cho kế hoạch có thể điều chỉnh.';

  @override
  String get luckyNumberSix =>
      'Dành thời gian cho người bạn quan tâm và chăm sóc cả bản thân.';

  @override
  String get luckyNumberSeven =>
      'Tìm một khoảng lặng để sắp xếp suy nghĩ và cân nhắc câu hỏi của mình.';

  @override
  String get luckyNumberEight =>
      'Tiến thêm một bước cụ thể cho điều đáng để đầu tư lâu dài.';

  @override
  String get luckyNumberNine =>
      'Hoàn tất phần còn dở và đặt xuống việc đã kết thúc.';

  @override
  String get tarotDrawTitle => 'Rút bài Tarot';

  @override
  String tarotProgress(int count, int total) {
    return 'Đã rút $count / $total';
  }

  @override
  String tarotCardPosition(int position) {
    return 'Lá $position';
  }

  @override
  String tarotCardsRemaining(int count) {
    return 'Chọn thêm $count lá trong trải bài';
  }

  @override
  String get tarotGestureHint => 'Chạm vào lá bài hoặc vuốt lên';

  @override
  String get tarotShuffle => 'Xáo lại';

  @override
  String get tarotSeerWaiting => 'Nhà chiêm tinh đang chờ câu hỏi của bạn';

  @override
  String get tarotRevealing => 'Đang lật lá bài…';

  @override
  String get tarotSeerReading => 'Đã đủ ba lá. Nhà chiêm tinh đang đọc bài.';

  @override
  String get tarotReadingComplete => 'Đã đọc xong';

  @override
  String get tarotReadingStepOne =>
      'Đang lắng nghe lời thì thầm của các vì sao…';

  @override
  String get tarotReadingStepTwo => 'Nhà chiêm tinh chạm vào bản đồ sao…';

  @override
  String get tarotReadingStepThree => 'Đang xem xét ba lá bài…';

  @override
  String get tarotReadingStepFour => 'Đang viết phần giải nghĩa…';

  @override
  String tarotMinorName(String suit, String rank) {
    return '$rank $suit';
  }

  @override
  String get tarotRankAce => 'Át';

  @override
  String get tarotRankTwo => 'Hai';

  @override
  String get tarotRankThree => 'Ba';

  @override
  String get tarotRankFour => 'Bốn';

  @override
  String get tarotRankFive => 'Năm';

  @override
  String get tarotRankSix => 'Sáu';

  @override
  String get tarotRankSeven => 'Bảy';

  @override
  String get tarotRankEight => 'Tám';

  @override
  String get tarotRankNine => 'Chín';

  @override
  String get tarotRankTen => 'Mười';

  @override
  String get tarotRankPage => 'Tiểu Đồng';

  @override
  String get tarotRankKnight => 'Hiệp Sĩ';

  @override
  String get tarotRankQueen => 'Nữ Hoàng';

  @override
  String get tarotRankKing => 'Vua';

  @override
  String get tarotSuitWands => 'Gậy';

  @override
  String get tarotWandsAceMeaning =>
      'Thử một bước nhỏ với ý tưởng khiến bạn hào hứng.';

  @override
  String get tarotWandsTwoMeaning =>
      'Xem các lựa chọn và quyết định bước tiếp theo.';

  @override
  String get tarotWandsThreeMeaning =>
      'Tìm cơ hội phát triển từ việc bạn đã bắt đầu thành công.';

  @override
  String get tarotWandsFourMeaning =>
      'Dành thời gian ăn mừng thành quả làm cùng người khác.';

  @override
  String get tarotWandsFiveMeaning =>
      'Khi có bất đồng, hãy lắng nghe vấn đề mỗi bên muốn giải quyết.';

  @override
  String get tarotWandsSixMeaning =>
      'Ghi nhận tiến bộ và chia sẻ công lao với người đã giúp đỡ.';

  @override
  String get tarotWandsSevenMeaning =>
      'Chọn ranh giới quan trọng rồi nói ra một cách bình tĩnh.';

  @override
  String get tarotWandsEightMeaning =>
      'Khi mọi việc tiến nhanh, hãy kiểm tra chi tiết và phản hồi kịp thời.';

  @override
  String get tarotWandsNineMeaning =>
      'Giữ sức cho mình và dành thời gian nghỉ ngơi.';

  @override
  String get tarotWandsTenMeaning =>
      'Chia sẻ một trách nhiệm quá nặng để tự gánh.';

  @override
  String get tarotWandsPageMeaning =>
      'Thử một việc nhỏ để theo đuổi sự tò mò của bạn.';

  @override
  String get tarotWandsKnightMeaning =>
      'Tận dụng nhiệt huyết để hành động và chuẩn bị bước kế tiếp.';

  @override
  String get tarotWandsQueenMeaning =>
      'Tự tin chia sẻ ý tưởng và mời người khác cùng đóng góp.';

  @override
  String get tarotWandsKingMeaning =>
      'Chọn một hướng đi mà mọi người có thể cùng theo đuổi.';

  @override
  String get tarotSuitCups => 'Cốc';

  @override
  String get tarotCupsAceMeaning =>
      'Dành chỗ cho cảm xúc mới và cho phép mình bày tỏ.';

  @override
  String get tarotCupsTwoMeaning =>
      'Nói điều bạn cần và để đối phương có thời gian đáp lại.';

  @override
  String get tarotCupsThreeMeaning =>
      'Ở bên những người ủng hộ bạn và chia sẻ điều đáng mừng.';

  @override
  String get tarotCupsFourMeaning =>
      'Nhận ra điều khiến bạn thiếu hứng thú rồi xem lựa chọn đã bỏ qua.';

  @override
  String get tarotCupsFiveMeaning =>
      'Cho phép mình buồn và chú ý đến sự hỗ trợ vẫn còn.';

  @override
  String get tarotCupsSixMeaning =>
      'Thử lại một hoạt động từng khiến bạn thấy dễ chịu.';

  @override
  String get tarotCupsSevenMeaning =>
      'Phân biệt ý tưởng có thể làm với điều vẫn chỉ là tưởng tượng.';

  @override
  String get tarotCupsEightMeaning =>
      'Nếu lối cũ không còn phù hợp, hãy nghĩ đến nơi bạn muốn đến.';

  @override
  String get tarotCupsNineMeaning =>
      'Tận hưởng một mong muốn đã thành hiện thực và hiểu nó đáp ứng điều gì.';

  @override
  String get tarotCupsTenMeaning =>
      'Chăm sóc một mối quan hệ mang lại cho bạn cảm giác thuộc về.';

  @override
  String get tarotCupsPageMeaning =>
      'Thử nói ra một cảm xúc mới mà không vội phán xét.';

  @override
  String get tarotCupsKnightMeaning =>
      'Bày tỏ cảm xúc của mình và cho đối phương thời gian trả lời.';

  @override
  String get tarotCupsQueenMeaning =>
      'Lắng nghe người khác và chừa chỗ cho cảm xúc của bạn.';

  @override
  String get tarotCupsKingMeaning =>
      'Đợi cảm xúc lắng xuống trước khi quyết định việc ảnh hưởng đến người khác.';

  @override
  String get tarotSuitSwords => 'Kiếm';

  @override
  String get tarotSwordsAceMeaning =>
      'Tìm một sự thật có thể kiểm chứng để làm rõ tình huống phức tạp.';

  @override
  String get tarotSwordsTwoMeaning =>
      'Cân nhắc cái giá của từng lựa chọn trước khi quyết định.';

  @override
  String get tarotSwordsThreeMeaning =>
      'Dành thời gian cho nỗi buồn và chia sẻ với người bạn tin tưởng.';

  @override
  String get tarotSwordsFourMeaning =>
      'Tạm dừng để nghỉ ngơi trước khi quay lại vấn đề khó.';

  @override
  String get tarotSwordsFiveMeaning =>
      'Tự hỏi thắng cuộc tranh luận có đáng với điều bạn phải đánh đổi không.';

  @override
  String get tarotSwordsSixMeaning =>
      'Chọn một bước giúp bạn rời khỏi tình huống làm mình kiệt sức.';

  @override
  String get tarotSwordsSevenMeaning =>
      'Xem lại động cơ của bạn và trao đổi thẳng thắn khi có thể.';

  @override
  String get tarotSwordsEightMeaning =>
      'Tách giới hạn thực tế khỏi nỗi lo và tìm một lựa chọn còn lại.';

  @override
  String get tarotSwordsNineMeaning =>
      'Viết ra những lo lắng lặp lại và chọn một việc bạn có thể xử lý hôm nay.';

  @override
  String get tarotSwordsTenMeaning =>
      'Chấp nhận một việc đã kết thúc và dành sức để hồi phục.';

  @override
  String get tarotSwordsPageMeaning =>
      'Đặt câu hỏi và kiểm tra thông tin trước khi chia sẻ.';

  @override
  String get tarotSwordsKnightMeaning =>
      'Hành động dứt khoát và kiểm tra lời nói cùng sự thật trước khi phản hồi.';

  @override
  String get tarotSwordsQueenMeaning =>
      'Nói rõ sự thật và ranh giới, đồng thời giữ cuộc trò chuyện cởi mở.';

  @override
  String get tarotSwordsKingMeaning =>
      'Dùng cùng một tiêu chuẩn và cân nhắc công bằng các góc nhìn.';

  @override
  String get tarotSuitPentacles => 'Tiền';

  @override
  String get tarotPentaclesAceMeaning =>
      'Biến một cơ hội thực tế thành một hành động cụ thể.';

  @override
  String get tarotPentaclesTwoMeaning =>
      'Sắp xếp lại thời gian và nguồn lực khi nhiều việc cùng đòi hỏi.';

  @override
  String get tarotPentaclesThreeMeaning =>
      'Cải thiện công việc cùng những người có kỹ năng khác nhau.';

  @override
  String get tarotPentaclesFourMeaning =>
      'Nhìn lại nguồn lực bạn có và chừa chỗ cho thay đổi.';

  @override
  String get tarotPentaclesFiveMeaning =>
      'Tìm sự hỗ trợ và chủ động nhờ giúp đỡ khi cần.';

  @override
  String get tarotPentaclesSixMeaning =>
      'Cân bằng cho và nhận bằng cách nói rõ mong đợi.';

  @override
  String get tarotPentaclesSevenMeaning =>
      'Cho công việc dài hạn thời gian và đặt ngày xem lại tiến độ.';

  @override
  String get tarotPentaclesEightMeaning =>
      'Luyện một kỹ năng và tích lũy những tiến bộ nhỏ.';

  @override
  String get tarotPentaclesNineMeaning =>
      'Ghi nhận sự ổn định và tự chủ bạn đã tạo dựng.';

  @override
  String get tarotPentaclesTenMeaning =>
      'Nghĩ xem hôm nay bạn có thể xây dựng điều gì để hỗ trợ tương lai.';

  @override
  String get tarotPentaclesPageMeaning =>
      'Chọn kỹ năng hữu ích và bắt đầu bằng một bước học cụ thể.';

  @override
  String get tarotPentaclesKnightMeaning =>
      'Hoàn thành một việc nhỏ mà bạn có thể làm tốt hôm nay.';

  @override
  String get tarotPentaclesQueenMeaning =>
      'Chăm sóc bản thân và người khác bằng một hành động thiết thực.';

  @override
  String get tarotPentaclesKingMeaning =>
      'Dùng sự ổn định đã có để chuẩn bị cho chặng tiếp theo.';

  @override
  String get thaiCalendarTitle => 'Lịch Thái hôm nay';

  @override
  String get thaiCalendarTimezone => 'Giờ Bangkok';

  @override
  String thaiCalendarCivilDate(String date, int year) {
    return '$date · Phật lịch $year';
  }

  @override
  String thaiCalendarWaxing(int day) {
    return 'Trăng lên ngày $day';
  }

  @override
  String thaiCalendarWaning(int day) {
    return 'Trăng tàn ngày $day';
  }

  @override
  String thaiCalendarLunarMonth(int month) {
    return 'Tháng $month âm lịch Thái';
  }

  @override
  String get thaiCalendarSecondEighth => 'Tháng 8 nhuận';

  @override
  String get thaiCalendarAuspicious => 'Ngày tốt';

  @override
  String get thaiCalendarCaution => 'Ngày cần thận trọng';

  @override
  String get thaiCalendarMixed => 'Có cả dấu hiệu tốt và cần thận trọng';

  @override
  String get thaiCalendarOrdinary => 'Ngày thường';

  @override
  String thaiCalendarHours(String hours) {
    return 'Giờ tốt $hours';
  }

  @override
  String get thaiCalendarDayRule =>
      'Ngày theo Kalayok dựa vào tiểu lịch tại giữa trưa ở Bangkok';

  @override
  String get thaiCalendarHourRule =>
      'Các giờ ban ngày theo bảng Ubakong truyền thống của từng thứ';

  @override
  String get thaiCalendarLoading => 'Đang tải lịch Thái hôm nay…';

  @override
  String get thaiCalendarUnavailable => 'Chưa tải được lịch Thái hôm nay';

  @override
  String get thaiCalendarLunarUnavailable =>
      'Chưa có ngày âm lịch Thái hôm nay';

  @override
  String get thaiCalendarRetry => 'Thử lại';

  @override
  String get dailyHoroscopeTitle => 'Vận trình hằng ngày';

  @override
  String dailyHoroscopeToday(String sign) {
    return '$sign hôm nay';
  }

  @override
  String get dailyHoroscopeMore => 'Xem thêm';

  @override
  String get dailyHoroscopeChooseSign => 'Chọn cung hoàng đạo';

  @override
  String get dailyHoroscopeForecast => 'Luận giải hôm nay';

  @override
  String get dailyHoroscopeBasis =>
      'Dựa trên vị trí các sao và Mặt Trăng theo chiêm tinh Thái Lan. Cập nhật theo ngày tại Bangkok.';

  @override
  String get dailyHoroscopeLoading => 'Đang tải vận trình hôm nay…';

  @override
  String get dailyHoroscopeUnavailable => 'Chưa thể tải vận trình hôm nay';

  @override
  String get dailyHoroscopeLove => 'Tình yêu';

  @override
  String get dailyHoroscopeWork => 'Sự nghiệp';

  @override
  String get dailyHoroscopeMoney => 'Tài chính';

  @override
  String get dailyHoroscopeLoveShort => 'Tình yêu';

  @override
  String get dailyHoroscopeWorkShort => 'Công việc';

  @override
  String get dailyHoroscopeMoneyShort => 'Tiền bạc';

  @override
  String get dailyHoroscopeHealth => 'Sức khỏe';

  @override
  String dailyHoroscopeReading(String planet, int house, String advice) {
    return '$planet đi qua nhà số $house. $advice';
  }

  @override
  String dailyHoroscopeLoveAdvice(String tone) {
    String _temp0 = intl.Intl.selectLogic(tone, {
      'supportive': 'Hãy chia sẻ cảm xúc và cho đối phương thời gian trả lời.',
      'reflective':
          'Nếu còn điều chưa rõ, hãy hỏi xem đối phương cảm thấy thế nào.',
      'other':
          'Dành thời gian trò chuyện và lắng nghe điều đối phương quan tâm.',
    });
    return '$_temp0';
  }

  @override
  String dailyHoroscopeWorkAdvice(String tone) {
    String _temp0 = intl.Intl.selectLogic(tone, {
      'supportive':
          'Chọn việc có thể tiến triển hôm nay và thống nhất bước tiếp theo với nhóm.',
      'reflective': 'Xem kỹ công việc đang làm trước khi nhận thêm nhiệm vụ.',
      'other': 'Đặt một ưu tiên rõ ràng và xử lý các việc còn lại theo thứ tự.',
    });
    return '$_temp0';
  }

  @override
  String dailyHoroscopeMoneyAdvice(String tone) {
    String _temp0 = intl.Intl.selectLogic(tone, {
      'supportive':
          'Xem lại chi tiêu gần đây và khoản có thể dành dụm trong tuần.',
      'reflective':
          'Cân nhắc thêm trước khi quyết định chi một khoản ngoài kế hoạch.',
      'other': 'Xem các khoản sắp đến hạn và để lại một phần dự phòng.',
    });
    return '$_temp0';
  }

  @override
  String dailyHoroscopeHealthAdvice(String tone) {
    String _temp0 = intl.Intl.selectLogic(tone, {
      'supportive':
          'Vận động nhẹ hoặc nghỉ một chút để giữ nhịp sinh hoạt dễ chịu.',
      'reflective': 'Chừa khoảng trống giữa các kế hoạch để có thời gian nghỉ.',
      'other': 'Giữ nhịp sinh hoạt quen thuộc và dành một lúc rời màn hình.',
    });
    return '$_temp0';
  }

  @override
  String get chartRules =>
      'Hoàng đạo nhiệt đới · Nhà Placidus · Nút Mặt Trăng thực';

  @override
  String get chartSource => 'RoxyAPI tính toán từ thông tin sinh của bạn';

  @override
  String get dateOnlyRules =>
      'Chưa rõ giờ sinh: vị trí hành tinh được ước tính lúc giữa trưa. Không hiển thị Mặt Trăng, cung Mọc, nhà, góc chiếu và cung chưa xác định chắc chắn.';

  @override
  String get calculateChart => 'Tính bản đồ sao của tôi';

  @override
  String get saveForChart =>
      'Hãy xác nhận và lưu thông tin sinh trước khi tạo bản đồ sao cá nhân.';

  @override
  String get retrograde => 'Nghịch hành';

  @override
  String get orb => 'Độ lệch góc';

  @override
  String get aspectConjunction => 'Góc trùng tụ';

  @override
  String get aspectSextile => 'Góc lục hợp';

  @override
  String get aspectSquare => 'Góc vuông';

  @override
  String get aspectTrine => 'Góc tam hợp';

  @override
  String get aspectOpposition => 'Góc đối đỉnh';

  @override
  String get fullReading => 'Bản luận giải đầy đủ của bạn';

  @override
  String get developmentReport =>
      'Bản xem thử khi phát triển cục bộ: báo cáo đầy đủ được mở miễn phí. Chưa phát sinh mua hàng hoặc thanh toán.';

  @override
  String get reportGeneratingText =>
      'Đang soạn luận giải từ hành tinh, nhà và góc chiếu của bạn. Kết quả sẽ tự hiện khi hoàn tất. Bạn có thể rời trang rồi quay lại xem tiếp.';

  @override
  String get reportFailedText =>
      'Chưa thể hoàn tất luận giải. Hãy trở về trang Báo cáo và tạo lại. Nội dung mẫu sẽ không thay thế kết quả của bạn.';

  @override
  String get roxyUnavailable =>
      'Dịch vụ tính bản đồ sao chưa sẵn sàng. Hãy thử lại sau.';

  @override
  String get roxyQuota =>
      'Hiện có quá nhiều yêu cầu tính toán. Hãy thử lại sau.';

  @override
  String get profileChanged =>
      'Thông tin sinh đã thay đổi. Hãy mở trang thông tin sinh, xác nhận và lưu lại.';

  @override
  String get birthRegion => 'Tỉnh / vùng';

  @override
  String get selectCountry => 'Chọn hoặc tìm quốc gia';

  @override
  String get selectRegion => 'Chọn hoặc tìm tỉnh';

  @override
  String get selectBirthCity => 'Chọn thành phố sinh từ danh sách gợi ý';

  @override
  String get countryFirst => 'Hãy chọn quốc gia trước';

  @override
  String get regionFirst => 'Hãy chọn tỉnh trước';

  @override
  String get regionNotNeeded => 'Không cần chọn';

  @override
  String get birthLocationHint =>
      'Nhập để tìm hoặc mở danh sách để chọn. Thông tin nơi sinh được xác định tự động.';

  @override
  String get moreLocations => 'Xem thêm địa điểm';

  @override
  String get guestReading =>
      'Xem bản đồ sao và báo cáo cá nhân mà không cần đăng nhập.';

  @override
  String get optionalLogin => 'Đăng nhập hoặc đăng ký (không bắt buộc)';

  @override
  String get templeNav => 'Đền';

  @override
  String get divinationNav => 'Khám phá';

  @override
  String get bondNav => 'Gắn kết';

  @override
  String get moreNav => 'Thêm';

  @override
  String get templeWelcome => 'Chậm lại một chút.\nMình lắng nghe.';

  @override
  String get templeIntro => 'Một nơi bình yên\ncho những điều trong lòng.';

  @override
  String get chooseGuardian => 'Hôm nay bạn muốn trò chuyện cùng ai?';

  @override
  String get aiCompanionNotice =>
      'Bạn đồng hành AI · giải trí và tự chiêm nghiệm';

  @override
  String get loveGuardian => 'Thần tình yêu';

  @override
  String get careerGuardian => 'Thần sự nghiệp';

  @override
  String get wealthGuardian => 'Thần tài vận';

  @override
  String get wellbeingGuardian => 'Thần an lành';

  @override
  String get loveGuardianNote => 'Tình yêu · kết nối';

  @override
  String get careerGuardianNote => 'Định hướng · phát triển';

  @override
  String get wealthGuardianNote => 'Tài chính · cân bằng';

  @override
  String get wellbeingGuardianNote => 'Nghỉ ngơi · chăm sóc bản thân';

  @override
  String get continueConversation => 'Tiếp tục câu chuyện';

  @override
  String get startConversation => 'Bắt đầu trò chuyện';

  @override
  String get listenIntro =>
      'Không cần tìm lời hoàn hảo. Hãy bắt đầu từ điều bạn muốn nói.';

  @override
  String get messageHint => 'Bạn đang nghĩ gì…';

  @override
  String get sendMessage => 'Gửi';

  @override
  String get assistantListening => 'Đang lắng nghe và chuẩn bị trả lời…';

  @override
  String get chatUnavailable =>
      'Trò chuyện hiện chưa khả dụng. Vui lòng thử lại sau.';

  @override
  String get chatProfileNeeded =>
      'Thêm thông tin ngày sinh để kết nối các bài đọc với bạn.';

  @override
  String get chatFailure =>
      'Câu trả lời chưa hoàn tất. Hãy thử lại; lượt này chưa được tính.';

  @override
  String get selectedReading => 'Bài đọc này';

  @override
  String get continueReading => 'Cùng thần tìm hiểu thêm';

  @override
  String get readingQuestion => 'Mình nên suy ngẫm điều gì trong bài đọc này?';

  @override
  String get divinationTitle => 'Một góc nhìn mới';

  @override
  String get divinationIntro =>
      'Rút một lá bài, khám phá các vì sao rồi cùng trò chuyện.';

  @override
  String get dailyDraw => 'Lá bài hôm nay';

  @override
  String get dailyDrawNote => 'Dành chút thời gian lắng nghe lòng mình';

  @override
  String get weeklyEvents => 'Tuần này';

  @override
  String get weeklyNote => 'Điều bạn quan tâm tuần này';

  @override
  String get weeklyPrompt =>
      'Tuần này có điều gì mình nên chú ý? Cùng suy nghĩ nhé.';

  @override
  String get lovePrompt => 'Mình muốn nói về một chuyện tình cảm.';

  @override
  String get careerPrompt => 'Gần đây mình phân vân về hướng đi công việc.';

  @override
  String get wealthPrompt => 'Mình muốn nhìn lại những áp lực tiền bạc.';

  @override
  String get wellbeingPrompt => 'Gần đây mình hơi mệt và muốn tâm sự.';

  @override
  String get bondTitle => 'Dần hiểu nhau hơn';

  @override
  String get bondIntro => 'Sự gắn kết đến từ những điều bạn chọn chia sẻ.';

  @override
  String get bondNew => 'Lần đầu gặp gỡ';

  @override
  String get bondFamiliar => 'Bắt đầu quen biết';

  @override
  String get bondGrowing => 'Dần thấu hiểu';

  @override
  String get bondCount => 'cuộc trò chuyện gần đây';

  @override
  String get bondRecentNote =>
      'Giai đoạn dựa trên các cuộc trò chuyện đã hoàn tất, không phải độ chính xác dự đoán.';

  @override
  String get bondMemory => 'Những điều bạn muốn được ghi nhớ';

  @override
  String get memoryEmpty =>
      'Chưa có ký ức được xác nhận. Hãy chia sẻ điều quan trọng với bạn.';

  @override
  String get addMemory => 'Thêm một ký ức';

  @override
  String get memoryHint => 'Ví dụ: Mình đang cân nhắc đổi công việc.';

  @override
  String get memoryHelp =>
      'Do bạn xác nhận, dùng chung cho bốn vị thần. Có thể sửa hoặc xóa bất cứ lúc nào.';

  @override
  String get recentConversations => 'Trò chuyện gần đây';

  @override
  String get noConversations => 'Sự gắn kết bắt đầu từ lời chào đầu tiên.';

  @override
  String get profileSelf => 'Về bạn';

  @override
  String get memoryDeleteConfirm => 'Xóa ký ức đã xác nhận này?';

  @override
  String get sharedHistory => 'Bốn vị thần dùng chung ký ức trò chuyện.';

  @override
  String get editMemory => 'Sửa ký ức';

  @override
  String get saveMemory => 'Lưu ký ức';

  @override
  String get guardianSectionNote => 'Bốn vị thần, cùng lắng nghe những tâm tư';

  @override
  String get dailyHoroscopeEmpty =>
      'Chọn cung hoàng đạo để xem gợi ý về tình yêu, công việc và cuộc sống hôm nay.';

  @override
  String get appleLoginUnavailable =>
      'Thiết bị này chưa hỗ trợ đăng nhập bằng Apple. Bạn có thể tiếp tục với tư cách khách.';

  @override
  String get purchaseUnavailable =>
      'Dịch vụ mua chưa khả dụng. Vui lòng quay lại sau.';

  @override
  String get chatTryAgain => 'Kết nối lại';

  @override
  String get copyLink => 'Sao chép liên kết';

  @override
  String get privacyCenter => 'Quyền riêng tư và cho phép';

  @override
  String get privacyIntro =>
      'Thông tin của bạn, lựa chọn của bạn. Xem và quản lý dữ liệu FATE sử dụng.';

  @override
  String get dataProfileTitle => 'Thông tin ngày sinh';

  @override
  String get dataProfileBody =>
      'Ngày, giờ, nơi sinh và múi giờ được lưu để lập bản đồ sao, gắn với phiên khách hoặc tài khoản đăng nhập.';

  @override
  String get dataChatTitle => 'Trò chuyện và bài đọc AI';

  @override
  String get dataChatBody =>
      'Sau khi bạn đồng ý, dữ liệu sao đã tính được gửi cho AI để viết báo cáo. Trò chuyện còn gửi tin nhắn, hồ sơ, hội thoại gần đây, ký ức đã lưu và bài đọc bạn chọn. Tránh nhập thông tin bạn không muốn AI xử lý.';

  @override
  String get dataPurchaseTitle => 'Giao dịch và quyền truy cập';

  @override
  String get dataPurchaseBody =>
      'Cửa hàng xử lý thanh toán. FATE xác minh giao dịch trên máy chủ trước khi cấp quyền. Ứng dụng không yêu cầu số thẻ; bản xem mẫu không tạo giao dịch.';

  @override
  String get dataControlTitle => 'Quản lý dữ liệu';

  @override
  String get dataControlBody =>
      'Bạn có thể sửa hồ sơ và ký ức, xóa lịch sử trò chuyện và rút quyền cho các cuộc trò chuyện AI sau này. Xóa thông tin ngày sinh tại đây chỉ xóa bản trên thiết bị. Xóa tài khoản là thao tác riêng cần máy chủ xác nhận.';

  @override
  String get aiPermission => 'Trước khi trò chuyện';

  @override
  String aiPermissionBody(String provider) {
    return 'Tin nhắn, hồ sơ ngày sinh, hội thoại gần đây, ký ức và bài đọc đã chọn sẽ được dịch vụ AI ($provider) xử lý để trả lời. Câu trả lời có thể sai. Bạn có thể từ chối và dùng công cụ khác, hoặc rút quyền trong mục Riêng tư. Rút quyền dừng việc chia sẻ tiếp theo trên thiết bị, không xóa dữ liệu đã xử lý.';
  }

  @override
  String get aiAllow => 'Đồng ý và tiếp tục';

  @override
  String get aiEnabled => 'Đã cho phép trò chuyện AI';

  @override
  String get aiPaused => 'Chưa cho phép trò chuyện AI';

  @override
  String get aiRevoke => 'Rút quyền trò chuyện';

  @override
  String get aiRevoked =>
      'Đã rút quyền. Ứng dụng sẽ hỏi lại trước tin nhắn mới.';

  @override
  String get privacyPolicy => 'Chính sách quyền riêng tư đầy đủ';

  @override
  String get policyUnavailable => 'Chưa có liên kết chính sách đã công bố.';

  @override
  String get termsTitle => 'Sử dụng FATE';

  @override
  String get termsBody =>
      'FATE cung cấp bạn đồng hành AI và chiêm tinh để suy ngẫm, giải trí. Bài đọc không phải dự đoán chắc chắn hay tư vấn y tế, tài chính, pháp lý. Các vị thần là nhân vật AI hư cấu. Nội dung trả phí chỉ mở sau khi xác minh thanh toán; giá và khả năng mua do cửa hàng cung cấp. Không dùng để quấy rối hoặc gửi nội dung trái pháp luật.';

  @override
  String get supportTitle => 'Trợ giúp và hỗ trợ';

  @override
  String get supportIntro => 'Hướng dẫn khi bạn cần.';

  @override
  String get supportUnavailable =>
      'Chưa có thông tin liên hệ hỗ trợ. Vui lòng thử lại sau.';

  @override
  String get supportContact => 'Liên hệ hỗ trợ';

  @override
  String get copyAddress => 'Sao chép email';

  @override
  String get copied => 'Đã sao chép';

  @override
  String get openFailed =>
      'Không mở được liên kết. Bạn có thể sao chép địa chỉ.';

  @override
  String get faqReportTitle => 'Bài đọc của tôi ở đâu?';

  @override
  String get faqReportBody =>
      'Mở Báo cáo để xem bài đọc đã lưu. Dùng cùng tài khoản và ngôn ngữ. Bài mẫu được gắn nhãn riêng, không phải kết quả cá nhân.';

  @override
  String get faqChatTitle => 'Tôi có thể tiếp tục cuộc trò chuyện cũ không?';

  @override
  String get faqChatBody =>
      'Dùng cùng trình duyệt hoặc bản cài ứng dụng và chọn cùng vị thần. Khách có thể mất quyền truy cập sau khi xóa dữ liệu hoặc cài lại. Xem và xóa ký ức trong Gắn kết.';

  @override
  String get faqPurchaseTitle => 'Đã trả tiền nhưng vẫn bị khóa?';

  @override
  String get faqPurchaseBody =>
      'Không mua lại khi đang chờ xác minh. Mở Mua và khôi phục, thử xác minh lại rồi làm mới báo cáo. Khôi phục yêu cầu kiểm tra với cửa hàng; chỉ máy chủ xác nhận quyền truy cập.';

  @override
  String get licenses => 'Giấy phép mã nguồn mở';

  @override
  String get deleteAccountBody =>
      'Thao tác này xóa vĩnh viễn tài khoản hiện tại cùng hồ sơ, hội thoại và ký ức khỏi dịch vụ. Dữ liệu cần cho hồ sơ giao dịch có thể được giữ lại. Xóa tài khoản không hoàn tiền. Phiên khách đã xóa không thể khôi phục.';

  @override
  String get deleteUnavailable =>
      'Dịch vụ chưa hỗ trợ xóa tài khoản. Chưa có dữ liệu nào bị xóa. Xóa dữ liệu cục bộ hoặc đăng xuất không xóa tài khoản.';

  @override
  String get deleteAcknowledge => 'Tôi hiểu rằng không thể hoàn tác.';

  @override
  String get deleteNow => 'Xóa vĩnh viễn';

  @override
  String get deleteSuccess => 'Đã xác nhận xóa tài khoản.';

  @override
  String get deleteFailure =>
      'Chưa xác nhận xóa. Phiên của bạn vẫn được giữ. Hãy thử lại hoặc liên hệ hỗ trợ.';

  @override
  String get clearHistory => 'Xóa hội thoại';

  @override
  String get clearHistoryBody =>
      'Thao tác này xóa lịch sử trò chuyện với cả bốn vị thần khỏi dịch vụ và không thể hoàn tác. Ký ức đã lưu vẫn ở Gắn kết và có thể xóa tại đó.';

  @override
  String get clearHistoryDone => 'Đã xóa lịch sử trò chuyện.';

  @override
  String get contentReport => 'Báo cáo nội dung';

  @override
  String get contentReportIntro =>
      'Cho chúng tôi biết vấn đề của câu trả lời AI này. Chỉ gửi mã tham chiếu và chi tiết bạn nhập, không đính kèm toàn bộ hội thoại.';

  @override
  String get reportReason => 'Lý do';

  @override
  String get reasonHarmful => 'Gây hại hoặc không an toàn';

  @override
  String get reasonSexual => 'Nội dung tình dục';

  @override
  String get reasonHate => 'Thù ghét hoặc quấy rối';

  @override
  String get reasonPrivacy => 'Thông tin cá nhân';

  @override
  String get reasonMisleading => 'Lời khuyên sai lệch';

  @override
  String get reasonOther => 'Vấn đề khác';

  @override
  String get reportDetails => 'Chi tiết thêm (không bắt buộc)';

  @override
  String get reportSend => 'Gửi báo cáo';

  @override
  String get reportUnavailable =>
      'Tạm thời không thể báo cáo. Chưa gửi báo cáo nào. Hãy thử lại sau hoặc xem Trợ giúp.';

  @override
  String reportReceived(String receipt) {
    return 'Đã nhận báo cáo · $receipt';
  }

  @override
  String get purchaseCenter => 'Mua và khôi phục';

  @override
  String get purchaseCenterIntro =>
      'Kiểm tra quyền truy cập và khôi phục giao dịch.';

  @override
  String get restoreCheck => 'Đang kiểm tra giao dịch…';

  @override
  String get restoreChecked =>
      'Đã kiểm tra với cửa hàng. Làm mới báo cáo để xem quyền đã xác minh. Thông báo này không xác nhận mua hàng.';

  @override
  String get verifiedContent => 'Thư viện báo cáo';

  @override
  String get verifiedContentIntro =>
      'Mở báo cáo để xem quyền hiện tại. Báo cáo đã lưu hay bài mẫu không đồng nghĩa đã mua.';

  @override
  String get reportLeave => 'Bỏ bản nháp báo cáo này?';

  @override
  String get serviceRetry => 'Thử lại';

  @override
  String get deleteCleanup =>
      'Máy chủ đã xác nhận xóa, nhưng một số dữ liệu cục bộ chưa xóa được. Phiên trong bộ nhớ đã kết thúc; hãy xóa bộ nhớ ứng dụng trên thiết bị này.';

  @override
  String get storeBuy => 'Mua qua cửa hàng';

  @override
  String get restoreUnavailable =>
      'Thiết bị hoặc tài khoản này chưa hỗ trợ khôi phục. Hãy dùng thiết bị được hỗ trợ, cùng tài khoản cửa hàng và FATE ban đầu.';

  @override
  String get calendarTitle => 'Lịch chiêm tinh';

  @override
  String get calendarOpen => 'Xem lịch';

  @override
  String get calendarToday => 'Hôm nay';

  @override
  String get calendarSubtitle => 'Chọn một ngày để lên kế hoạch';

  @override
  String calendarYears(int be, int ce) {
    return 'Phật lịch $be · Dương lịch $ce';
  }

  @override
  String calendarSmallEra(int year) {
    return 'Tiểu lịch $year';
  }

  @override
  String get calendarSelectHint => 'Chạm ngày để xem năm mục chi tiết';

  @override
  String get calendarLoading => 'Đang mở lịch…';

  @override
  String get calendarUnavailable =>
      'Không thể tải tháng này. Vui lòng thử lại.';

  @override
  String calendarRange(int start, int end) {
    return 'Xem ngoại tuyến · $start–$end';
  }

  @override
  String get calendarOutOfRange => 'Ngày này nằm ngoài phạm vi lịch.';

  @override
  String get calendarWanPhra => 'Ngày lễ Phật';

  @override
  String get calendarKalayokTitle => 'Kalayok · Loại ngày';

  @override
  String calendarFlag(String kind) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'thongchai': 'Ngày thắng lợi',
      'athibodi': 'Ngày chủ trì',
      'ubat': 'Ngày cần cẩn trọng',
      'other': 'Ngày tránh việc lớn',
    });
    return '$_temp0';
  }

  @override
  String calendarFlagBody(String kind) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'thongchai': 'Theo truyền thống, gắn với việc khởi đầu.',
      'athibodi': 'Theo truyền thống, gắn với dẫn dắt và tổ chức.',
      'ubat': 'Theo truyền thống, nên xem xét kế hoạch cẩn thận.',
      'other': 'Theo truyền thống, tránh vội quyết định việc lớn.',
    });
    return '$_temp0';
  }

  @override
  String get calendarNoKalayok => 'Không có dấu hiệu Kalayok';

  @override
  String get calendarMixedNote =>
      'Ngày này có nhiều dấu hiệu; tất cả đều được hiển thị.';

  @override
  String get calendarLunarTitle => 'Ngày âm lịch';

  @override
  String get calendarRiangMon => 'Dithi Riang Mon';

  @override
  String get calendarRiangMonBody =>
      'Ngày âm lịch được tham khảo khi chọn ngày cưới theo truyền thống.';

  @override
  String get calendarLunarOrdinary => 'Không phải ngày Dithi Riang Mon.';

  @override
  String get calendarUbakong => 'Ubakong · Giờ tốt';

  @override
  String get calendarDaylight => 'Ban ngày · 06:00–18:00 · Bangkok';

  @override
  String get calendarMansion => '27 cung Mặt Trăng';

  @override
  String calendarMansionPosition(int index, int quarter) {
    return 'Cung $index / 27 · Phần $quarter';
  }

  @override
  String get calendarMansionReference =>
      'Vị trí Mặt Trăng lúc trưa Bangkok; cung có thể đổi trong ngày.';

  @override
  String get calendarReference =>
      'Lịch Thái truyền thống · tham khảo văn hóa và giải trí';

  @override
  String calendarLunarShort(String phase, int day) {
    String _temp0 = intl.Intl.selectLogic(phase, {'waxing': 'T', 'other': 'G'});
    return '$_temp0$day';
  }

  @override
  String calendarMonth(String month) {
    String _temp0 = intl.Intl.selectLogic(month, {
      '1': 'Tháng Một',
      '2': 'Tháng Hai',
      '3': 'Tháng Ba',
      '4': 'Tháng Tư',
      '5': 'Tháng Năm',
      '6': 'Tháng Sáu',
      '7': 'Tháng Bảy',
      '8': 'Tháng Tám',
      '9': 'Tháng Chín',
      '10': 'Tháng Mười',
      '11': 'Tháng Mười Một',
      '12': 'Tháng Mười Hai',
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
}
