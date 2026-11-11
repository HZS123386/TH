from fastapi import Request

LANGUAGES = ("zh", "th", "vi", "en")
LOCALES = {"zh": "zh-CN", "th": "th-TH", "vi": "vi-VN", "en": "en-US"}

# API messages live on the server; user content and previous messages are never rewritten.
MESSAGES = {
    "profile_changed": ("出生资料已更新，请重新确认并保存", "ข้อมูลเกิดเปลี่ยนแล้ว กรุณายืนยันและบันทึกอีกครั้ง", "Thông tin sinh đã đổi. Hãy xác nhận và lưu lại.", "Birth details changed. Confirm and save them again."),
    "consent_required": ("请先同意本次个人解读的数据处理说明", "กรุณายินยอมตามคำชี้แจงข้อมูลก่อนสร้างคำอ่าน", "Hãy đồng ý với thông báo xử lý dữ liệu trước khi tạo luận giải.", "Accept the reading data notice before generating a report."),
    "life_report_generating": ("报告仍在生成，请完成后再删除。", "รายงานยังสร้างอยู่ กรุณารอให้เสร็จก่อนลบ", "Báo cáo đang được tạo. Vui lòng đợi trước khi xóa.", "The report is still being generated. Wait until it finishes before deleting."),
    "landing_visit_not_found": ("暂时无法记录本次访问。", "ยังบันทึกการเข้าชมครั้งนี้ไม่ได้", "Chưa thể ghi nhận lượt truy cập này.", "This visit could not be recorded."),
    "landing_consent_required": ("请先确认资料使用说明。", "กรุณายืนยันการใช้ข้อมูลก่อน", "Vui lòng xác nhận việc sử dụng dữ liệu.", "Confirm the data-use notice first."),
    "thai_reading_details_required": ("请补充出生日期、准确时间和可识别的出生地点，再生成泰式解读", "กรุณาระบุวันเกิด เวลาเกิดที่แน่นอน และสถานที่เกิดที่ค้นหาได้ก่อนสร้างคำอ่าน", "Hãy bổ sung ngày sinh, giờ sinh chính xác và nơi sinh có thể xác định trước khi tạo luận giải Thái.", "Add your birth date, exact time and a recognized birthplace before creating a Thai reading."),
    "model_rate_limit": ("模型服务达到调用限额，请稍等片刻后再试", "บริการโมเดลถึงขีดจำกัด กรุณารอสักครู่แล้วลองใหม่", "Dịch vụ mô hình đã chạm hạn mức. Hãy đợi một chút rồi thử lại.", "The model service rate limit was reached. Please pause and retry."),
    "model_auth_failed": ("模型密钥验证失败，请检查服务端配置", "ตรวจสอบคีย์โมเดลไม่ผ่าน กรุณาตรวจการตั้งค่าฝั่งเซิร์ฟเวอร์", "Xác thực khóa mô hình thất bại. Hãy kiểm tra cấu hình máy chủ.", "Model authentication failed. Check the server configuration."),
    "model_access_denied": ("当前密钥没有该模型的调用权限，请检查服务端模型与地域配置", "คีย์นี้ไม่มีสิทธิ์ใช้โมเดล กรุณาตรวจโมเดลและภูมิภาคบนเซิร์ฟเวอร์", "Khóa hiện tại không có quyền dùng mô hình. Kiểm tra mô hình và khu vực trên máy chủ.", "This key cannot access the model. Check the server model and region settings."),
    "model_not_found": ("未找到配置的模型或接口地址，请检查服务端配置", "ไม่พบโมเดลหรือปลายทางที่ตั้งค่า กรุณาตรวจการตั้งค่าฝั่งเซิร์ฟเวอร์", "Không tìm thấy mô hình hoặc địa chỉ đã cấu hình. Hãy kiểm tra máy chủ.", "The configured model or endpoint was not found. Check the server settings."),
    "chat_daily_limit": ("今天的聊天次数已用完，请稍后再来；额度按最近24小时恢复", "ครบจำนวนแชตแล้ว กรุณากลับมาภายหลัง โควตาคืนตามช่วง 24 ชั่วโมงที่ผ่านมา", "Đã hết lượt trò chuyện; hạn mức phục hồi theo cửa sổ 24 giờ.", "Your chat limit is reached. It recovers on a rolling 24-hour window."),
    "chat_minute_limit": ("聊得有点快，请稍等片刻再发送", "ส่งข้อความเร็วไปนิด กรุณารอสักครู่", "Bạn gửi hơi nhanh. Hãy đợi một chút.", "Please pause briefly before sending another message."),
    "birth_date_does_not_exist_in_timezone": ("该出生日期在所选时区不存在，请核对日期或时区", "วันเกิดนี้ไม่มีอยู่ในเขตเวลาที่เลือก กรุณาตรวจสอบวันหรือเขตเวลา", "Ngày sinh không tồn tại trong múi giờ đã chọn. Hãy kiểm tra ngày hoặc múi giờ.", "This birth date does not exist in the selected time zone. Check the date or time zone."),
    "thai_engine_unavailable": ("泰式计算需要本机 Node.js 与已安装的 thai-astrology 依赖", "ต้องมี Node.js และแพ็กเกจ thai-astrology ในเครื่อง", "Cần Node.js và gói thai-astrology được cài cục bộ.", "Thai calculations require local Node.js and the installed thai-astrology package."),
    "thai_calculation_failed": ("泰式排盘暂时无法完成，请核对时间、地点或稍后重试", "คำนวณดวงไทยไม่สำเร็จ กรุณาตรวจสอบเวลาและสถานที่แล้วลองอีกครั้ง", "Chưa tính được bản đồ sao Thái. Kiểm tra giờ, nơi sinh và thử lại.", "Thai chart calculation failed. Check the time and place, then retry."),
    "request_too_large": ("请求内容过大", "ข้อมูลคำขอมีขนาดใหญ่เกินไป", "Nội dung yêu cầu quá lớn", "The request is too large."),
    "busy": ("服务繁忙，请稍后重试", "บริการกำลังยุ่ง โปรดลองภายหลัง", "Dịch vụ đang bận. Hãy thử lại sau.", "The service is busy. Please try again later."),
    "too_many_requests": (
        "操作过于频繁，请稍后重试",
        "ทำรายการบ่อยเกินไป โปรดลองภายหลัง",
        "Thao tác quá nhanh. Hãy thử lại sau.",
        "Too many requests. Please try again later.",
    ),
    "login_required": ("请先登录", "กรุณาเข้าสู่ระบบก่อน", "Vui lòng đăng nhập trước.", "Please sign in first."),
    "production_disabled": (
        "正式登录尚未配置，请使用本地开发模式",
        "ยังไม่ได้ตั้งค่าล็อกอินจริง โปรดใช้โหมดพัฒนา",
        "Chưa cấu hình đăng nhập chính thức. Hãy dùng chế độ phát triển.",
        "Production sign-in is not configured. Use local development mode.",
    ),
    "session_expired": (
        "登录已过期，请重新登录",
        "เซสชันหมดอายุ กรุณาเข้าสู่ระบบอีกครั้ง",
        "Phiên đăng nhập hết hạn. Hãy đăng nhập lại.",
        "Your session expired. Please sign in again.",
    ),
    "chat_in_progress": (
        "正在生成回复，请等待完成或停止后重试",
        "กำลังสร้างคำตอบ กรุณารอหรือหยุดก่อน",
        "Đang tạo câu trả lời. Hãy đợi hoặc dừng trước.",
        "A reply is in progress. Wait for it to finish or stop it first.",
    ),
    "credentials_invalid": ("账号或密码不正确", "ชื่อผู้ใช้หรือรหัสผ่านไม่ถูกต้อง", "Tên tài khoản hoặc mật khẩu không đúng.", "Incorrect username or password."),
    "memory_not_found": ("记忆不存在", "ไม่พบความทรงจำนี้", "Không tìm thấy ghi nhớ này.", "This memory was not found."),
    "profile_required": ("请先保存出生档案", "กรุณาบันทึกข้อมูลวันเกิดก่อน", "Hãy lưu hồ sơ ngày sinh trước.", "Please save your birth profile first."),
    "provider_unconfigured": (
        "该模型尚未配置，请选择可用模型",
        "ยังไม่ได้ตั้งค่าโมเดลนี้ โปรดเลือกโมเดลที่พร้อมใช้",
        "Mô hình này chưa được cấu hình. Hãy chọn mô hình khả dụng.",
        "This model is not configured. Choose an available model.",
    ),
    "model_failed": (
        "模型服务返回错误，请稍后重试",
        "บริการโมเดลขัดข้อง โปรดลองอีกครั้ง",
        "Dịch vụ mô hình gặp lỗi. Hãy thử lại sau.",
        "The model service returned an error. Please try again.",
    ),
    "reply_incomplete": (
        "模型回复未完整结束，本轮未保存",
        "คำตอบไม่สมบูรณ์และไม่ได้บันทึก",
        "Câu trả lời chưa hoàn chỉnh và chưa được lưu.",
        "The reply was incomplete and was not saved.",
    ),
    "reply_invalid": (
        "模型回复格式异常，本轮未保存",
        "รูปแบบคำตอบผิดปกติและไม่ได้บันทึก",
        "Định dạng câu trả lời không hợp lệ và chưa được lưu.",
        "The reply format was invalid and was not saved.",
    ),
    "upstream_unavailable": (
        "模型连接失败，本轮未保存，请稍后重试",
        "เชื่อมต่อโมเดลไม่ได้ คำตอบไม่ได้บันทึก โปรดลองอีกครั้ง",
        "Không thể kết nối mô hình. Câu trả lời chưa được lưu; hãy thử lại.",
        "Could not connect to the model. This reply was not saved. Please try again.",
    ),
    "upstream_interrupted": (
        "模型连接提前结束，本轮未保存",
        "การเชื่อมต่อโมเดลสิ้นสุดก่อนกำหนดและไม่ได้บันทึก",
        "Kết nối mô hình kết thúc sớm. Câu trả lời chưa được lưu.",
        "The model connection ended early. This reply was not saved.",
    ),
    "reply_too_long": (
        "回复超过长度限制，本轮未保存",
        "คำตอบยาวเกินกำหนดและไม่ได้บันทึก",
        "Câu trả lời vượt giới hạn độ dài và chưa được lưu.",
        "The reply exceeded the length limit and was not saved.",
    ),
    "empty_reply": (
        "模型返回空回复，本轮未保存",
        "โมเดลส่งคำตอบว่างและไม่ได้บันทึก",
        "Mô hình trả lời trống. Lượt này chưa được lưu.",
        "The model returned an empty reply. This turn was not saved.",
    ),
    "reply_timeout": (
        "回复超时，本轮未保存",
        "หมดเวลารอคำตอบและไม่ได้บันทึก",
        "Hết thời gian chờ. Câu trả lời chưa được lưu.",
        "The reply timed out and was not saved.",
    ),
    "request_failed": (
        "操作失败，请稍后重试",
        "ดำเนินการไม่สำเร็จ โปรดลองอีกครั้ง",
        "Thao tác không thành công. Hãy thử lại.",
        "The request failed. Please try again.",
    ),
    "timezone_invalid": ("请选择有效的出生地时区", "เลือกเขตเวลาเกิดที่ถูกต้อง", "Hãy chọn múi giờ nơi sinh hợp lệ.", "Choose a valid birth timezone."),
    "date_range": (
        "请使用 1901–2099 年公历日期；现代泰国佛历请先减 543",
        "ใช้ปีคริสต์ศักราช 1901–2099 ปีพุทธศักราชสมัยใหม่ให้ลบ 543",
        "Dùng năm dương lịch 1901–2099. Với Phật lịch Thái Lan hiện đại, trừ 543.",
        "Use a Gregorian year from 1901 to 2099. Subtract 543 from a modern Thai Buddhist year.",
    ),
    "future_birthdate": (
        "出生日期不能晚于出生地今天",
        "วันเกิดต้องไม่เกินวันนี้ตามเขตเวลาเกิด",
        "Ngày sinh không được sau hôm nay tại nơi sinh.",
        "Your birth date cannot be later than today in the birth timezone.",
    ),
    "birth_time_invalid": (
        "出生时刻处于夏令时重复或不存在的区间，请核实记录",
        "เวลาเกิดซ้ำหรือไม่มีอยู่เนื่องจากเวลาออมแสง โปรดตรวจสอบ",
        "Giờ sinh bị trùng hoặc không tồn tại do giờ mùa hè. Hãy kiểm tra lại.",
        "This birth time is ambiguous or nonexistent due to daylight saving time. Check your records.",
    ),
    "account_exists": (
        "账号已存在，请直接登录或使用其他账号",
        "มีชื่อผู้ใช้นี้แล้ว กรุณาเข้าสู่ระบบหรือเลือกชื่ออื่น",
        "Tài khoản đã tồn tại. Hãy đăng nhập hoặc dùng tên khác.",
        "This username already exists. Sign in or choose another one.",
    ),
    "memory_limit": (
        "最多保存 20 条记忆，请先删除一条",
        "บันทึกได้สูงสุด 20 รายการ กรุณาลบหนึ่งรายการก่อน",
        "Tối đa 20 ghi nhớ. Hãy xóa một ghi nhớ trước.",
        "You can save up to 20 memories. Delete one first.",
    ),
    "validation_failed": ("请检查填写内容后重试", "กรุณาตรวจสอบข้อมูลแล้วลองอีกครั้ง", "Hãy kiểm tra thông tin rồi thử lại.", "Check your information and try again."),
    "username_invalid": (
        "账号需为 3–32 位英文字母、数字或下划线",
        "ชื่อผู้ใช้ต้องเป็นอักษรอังกฤษ ตัวเลขหรือขีดล่าง 3–32 ตัว",
        "Tên tài khoản cần 3–32 chữ cái tiếng Anh, chữ số hoặc dấu gạch dưới.",
        "Use 3–32 letters, numbers, or underscores for your username.",
    ),
    "password_invalid": ("密码需为 8–128 个字符", "รหัสผ่านต้องมี 8–128 ตัวอักษร", "Mật khẩu cần từ 8 đến 128 ký tự.", "Your password must be 8–128 characters."),
    "birthdate_invalid": (
        "请填写有效的公历出生日期",
        "กรอกวันเกิดคริสต์ศักราชที่ถูกต้อง",
        "Hãy nhập ngày sinh dương lịch hợp lệ.",
        "Enter a valid Gregorian birth date.",
    ),
    "message_invalid": ("问题需为 1–2000 个字符", "คำถามต้องมี 1–2000 ตัวอักษร", "Câu hỏi cần từ 1 đến 2.000 ký tự.", "Your question must be 1–2,000 characters."),
    "content_invalid": ("记忆需为 1–500 个字符", "ความทรงจำต้องมี 1–500 ตัวอักษร", "Ghi nhớ cần từ 1 đến 500 ký tự.", "A memory must be 1–500 characters."),
    "language_invalid": ("请选择支持的语言", "กรุณาเลือกภาษาที่รองรับ", "Hãy chọn ngôn ngữ được hỗ trợ.", "Choose a supported language."),
}


# Roxy service failures are safe, localized codes; upstream error bodies stay private.
MESSAGES.update({'roxy_unconfigured': ('Roxy 尚未配置', 'ยังไม่ได้ตั้งค่า Roxy', 'Roxy chưa được cấu hình', 'Roxy is not configured'),
 'roxy_auth_failed': ('Roxy 密钥验证或权限失败',
                      'คีย์หรือสิทธิ์ Roxy ไม่ผ่าน',
                      'Khóa hoặc quyền Roxy không hợp lệ',
                      'Roxy authentication or permission failed'),
 'roxy_quota': ('Roxy 服务额度或速率已达到上限', 'ถึงโควตาหรือขีดจำกัด Roxy', 'Đạt hạn mức Roxy', 'Roxy quota or rate limit reached'),
 'roxy_local_limit': ('本地 Roxy 调用额度已达到上限', 'ถึงโควตาในเครื่อง', 'Đạt hạn mức cục bộ', 'Local Roxy quota reached'),
 'roxy_unavailable': ('Roxy 暂时不可用或超时，请稍后重试',
                      'Roxy ไม่พร้อมหรือหมดเวลา',
                      'Roxy tạm lỗi hoặc hết thời gian',
                      'Roxy is temporarily unavailable or timed out'),
 'roxy_invalid_response': ('Roxy 返回的结构或出生资料校验未通过',
                           'ตรวจสอบผล Roxy ไม่ผ่าน',
                           'Phản hồi hoặc dữ liệu sinh Roxy không hợp lệ',
                           'Roxy response or birth-data validation failed'),
 'roxy_input_rejected': ('Roxy 拒绝了输入，请核对生辰与口径',
                         'Roxy ไม่รับข้อมูลเกิดนี้',
                         'Roxy từ chối dữ liệu sinh',
                         'Roxy rejected the birth input'),
 'bazi_time_required': ('需要准确出生时分', 'ต้องมีเวลาเกิดที่แน่นอน', 'Cần giờ sinh chính xác', 'An exact birth time is required'),
 'bazi_gender_required': ('仅用于传统公式选择，请选择后再测大运。',
                          'ใช้เลือกสูตรดั้งเดิมเท่านั้น',
                          'Chỉ dùng để chọn công thức truyền thống.',
                          'This selects the traditional formula only.')})

MESSAGES.update({
    "life_report_not_found": ("找不到这份报告，请从本设备的报告列表重新打开。", "ไม่พบรายงานนี้ กรุณาเปิดจากรายการรายงานในอุปกรณ์นี้", "Không tìm thấy báo cáo này.", "This report was not found on this device."),
    "life_preview_required": ("请先完成免费试读，再查看完整报告。", "กรุณาสร้างคำอ่านเบื้องต้นก่อนเปิดรายงานฉบับเต็ม", "Hãy tạo bản đọc thử trước.", "Create the preview before unlocking the full report."),
    "life_payment_required": ("付款尚未确认，报告仍处于锁定状态。", "ยังไม่ได้รับการยืนยันการชำระเงิน รายงานยังล็อกอยู่", "Thanh toán chưa được xác nhận.", "Payment has not been confirmed."),
    "life_payment_unavailable": ("暂时无法连接测试支付，请稍后重试。", "ขณะนี้ระบบทดสอบการชำระเงินไม่พร้อมใช้งาน กรุณาลองอีกครั้ง", "Chưa thể kết nối thanh toán thử.", "Test payment is unavailable. Try again shortly."),
})


MESSAGES["landing_notice_outdated"] = (
    "页面已更新，请打开新版页面并重新确认资料使用说明。",
    "หน้าเว็บมีการอัปเดต กรุณาเปิดเวอร์ชันล่าสุดและยืนยันคำชี้แจงการใช้ข้อมูลอีกครั้ง",
    "Trang đã được cập nhật. Hãy mở phiên bản mới và xác nhận lại thông báo sử dụng dữ liệu.",
    "This page has been updated. Open the latest version and confirm the data-use notice again.",
)


def request_language(request: Request) -> str:
    for item in request.headers.get("accept-language", "zh").split(","):
        language = item.split(";", 1)[0].strip().lower().replace("_", "-").split("-", 1)[0]
        if language in LANGUAGES:
            return language
    return "zh"


def message(code: str, language: str) -> str:
    return MESSAGES.get(code, MESSAGES["request_failed"])[LANGUAGES.index(language if language in LANGUAGES else "zh")]
