import { api, ApiError, ui, type Language, type Place, type Reading, type ReadingInput, type ReadingItem } from "./reading";
import { fortuneCopy, fortuneTopicKeys, type FortuneTopicKey } from "./fortuneTopics";

export type CareerStage = "unspecified" | "considering" | "searching" | "offer";
export type CareerFocus = "decision" | "stay" | "move" | "next";
type CareerQuestion = { stage: CareerStage; start: string; focus?: CareerFocus | null };
export type LifeInput = Omit<ReadingInput, "reading"> & { report_kind?: "life" | "fortune"; career?: CareerQuestion; career_question?: CareerQuestion; user_question?: string };
export type ReportTopic = Reading | FortuneTopicKey;
export type LifeState = "not_started" | "pending" | "generating" | "ready" | "limited" | "unavailable" | "unconfigured";
export type Feedback = "close" | "partly" | "different";
export interface LifeEvidence { id: string; title: string; detail: string }
export interface LifeSummary { text: string; evidence: LifeEvidence[]; period: { year: number; month: number } | null }
export interface LifePoint extends ReadingItem { evidence: LifeEvidence[] }
export interface LifeChapter {
  key: ReportTopic;
  title: string;
  summary: LifeSummary;
  insights: LifePoint[];
  watchpoints: LifePoint[];
  actions: LifePoint[];
}
export interface LifeReport {
  id: string;
  version: string;
  title: string;
  input: LifeInput;
  reference_period?: { start: string; end: string };
  created_at: string;
  location: Partial<Place> & { nameEnglish: string; timeZone: string };
  method: { name: string; house_system: string; version: string };
  time_accuracy?: { mode: "exact" | "estimated"; assumed_local_time: string | null };
  price: { amount: number; currency: string; display: string; mode: "direct" | "payso_test" };
  preview_state: LifeState;
  full_state: LifeState;
  access: "preview" | "full";
  feedback: Feedback | null;
  progress: { completed: number; total: number };
  generation_progress?: { percent: number; sections: { key: "work" | "money" | "relationships" | "annual" | "plan" | FortuneTopicKey; percent: number }[] };
  preview_generation_progress?: { percent: number; sections: { key: "preview_summary" | "preview_strength" | "preview_decisions" | "preview_relationships"; percent: number }[] };
  catalog: { key: ReportTopic; title: string; questions: string[]; houses: number[]; ready: boolean }[];
  preview: { summary: LifeSummary; traits: (LifePoint & { key: "strength" | "decisions" | "relationships" })[]; career_answer?: LifeSummary } | null;
  chapters: LifeChapter[];
  plan: { phases: { key: "observe" | "adjust" | "review"; title: string; text: string; actions: (LifePoint & { chapter: ReportTopic; index: number })[] }[] } | null;
}
export type LifeHistory = Pick<LifeReport, "id" | "input" | "created_at" | "access" | "full_state">;

export const lifeCopy = {
  zh: {
    title: "人生报告", eyebrow: "为你的出生时刻而写", subtitle: "理解自己的习惯，找到更适合自己的选择。",
    generate: "立即解析", generating: "正在解析你的运程…", includes: "七大主题，读懂你的运程",
    includesHint: "个人特点免费查看，七大运程主题解锁后完整呈现。",
    downloadApp: "下载 APP 免费解读", downloadAppShort: "下载 APP", appFree: "免费解读", buyReading: "购买解析",
    preview: "免费试读", takeaway: "先看你的人生主线", traits: "先认识自己的三个特点", birth: "本次出生资料", created: "生成时间", number: "报告编号",
    timeUnknown: "出生时间未知",
    name: "称呼", defaultName: "本人", timeRange: "参考时间范围", yearReference: "年度参考", freeContent: "免费查看", priority: "优先事项",
    method: "解读体系", methodValue: "泰式 Suriyayatra · 整宫制", evidence: "查看解读依据", evidenceHint: "这些是本次实际计算的因素。生活含义属于传统占星解读，不是对现实经历的核实。",
    summaryEvidence: "这条结论的依据", feedback: "这些特点与你接近吗？", feedbackOptions: ["很接近", "部分接近", "不太符合"], feedbackSaved: "已记录，谢谢你的反馈。", feedbackHint: "反馈帮助我们评估内容，不会改写本次计算结果。",
    catalog: "报告目录", catalogHint: "前三部分免费查看，解锁后继续阅读五个完整主题。", locked: "解锁后阅读", available: "已生成", chapter: "主题",
    offerTitle: "继续读懂你的事业、金钱与关系", offerText: "你已经看到了自己的三个特点。完整报告会继续解释：这些特点怎样影响你的选择，以及可以怎样做得更适合自己。",
    benefits: ["工作风格与发展建议", "金钱态度与规划参考", "关系需求与沟通建议", "近期关注与具体行动"], unlock: "解锁完整人生报告", direct: "当前为支付演示，不会扣款。", once: "一份完整报告 · 对应本次出生资料与年份",
    backgroundGenerating: "完整版正在后台生成，你可以先阅读免费试读。", backgroundReady: "完整版已生成，解锁后即可查看。", backgroundRetry: "选择 APP 免费解读，或购买网页版完整解析。",
    unlocking: "正在打开完整报告…", full: "完整报告已解锁", progress: "正在生成你的完整报告", progressHint: "完整内容正在后台生成，每完成一章就会显示在这里。你也可以稍后从“我的报告”继续查看。", pausedHint: "点击继续生成，只补齐未完成的内容。已完成的章节会保留，也可以稍后从“我的报告”继续。", progressUnit: "项已完成",
    retry: "继续生成报告", retryPreview: "重新生成免费试读", previewStates: { not_started: "免费试读尚未生成，你可以使用当前资料重新生成。", pending: "相同资料的免费试读正在生成，请稍后重新打开。", generating: "正在生成你的免费试读…", ready: "免费试读已生成。", limited: "免费试读服务暂时达到限额，请稍后重试。出生资料已保留。", unavailable: "免费试读暂未生成成功。出生资料已保留，请点击下方按钮重新生成。", unconfigured: "出生资料已计算完成，免费试读服务暂不可用。" }, states: { not_started: "点击解锁后开始生成完整内容。", pending: "相同资料正在整理，请稍后再试。", generating: "完整报告正在后台生成。", ready: "完整报告已生成。", limited: "解读服务暂时达到限额，已完成的内容已保留，请稍后继续。", unavailable: "这次生成未完成，已完成的章节已保留，可以继续生成。", unconfigured: "星盘已计算完成，解读服务尚未配置。" },
    plan: "总结建议", viewAction: "回到对应主题", navigation: "报告目录", save: "保存完整报告（网页）", savePreview: "保存免费试读（网页）", exportPdf: "保存为 PDF", pdfPreparing: "正在生成 PDF…", pdfSaved: "PDF 已保存到所选位置。", pdfDownloaded: "PDF 已交给浏览器保存，位置由浏览器或系统的下载设置决定。", pdfError: "PDF 暂未保存成功，请重试。",
    htmlPreparing: "正在保存网页报告…", htmlDownloaded: "网页报告已交给浏览器保存。", htmlError: "网页报告暂未保存成功，请重试。",
    history: "我的报告", historyHint: "本设备生成的报告会保留在这里。", emptyHistory: "还没有保存的报告。", close: "关闭", open: "继续阅读", historyError: "暂时无法读取报告列表，请重试。", previewVersion: "免费试读", fullVersion: "已解锁", loading: "正在打开报告…", printHint: "未解锁时只保存免费部分；完整报告解锁并生成后，保存免费与完整内容。", chapterCount: "八个报告部分", source: "依据说明", sourceVersion: "计算与报告版本", done: "完整报告已生成", resume: "已完成的内容会保留在本设备的报告列表中。",
  },
  th: {
    title: "รายงานชีวิต", eyebrow: "เขียนจากช่วงเวลาที่คุณเกิด", subtitle: "เข้าใจนิสัยของตัวเอง แล้วเลือกแนวทางที่เหมาะกับคุณ",
    generate: "ดูดวงเลย", generating: "กำลังวิเคราะห์ดวงของคุณ…", includes: "อ่านแนวโน้มชีวิตครบเจ็ดหัวข้อ",
    includesHint: "อ่านลักษณะส่วนตัวฟรี เปิดฉบับเต็มเพื่ออ่านทั้งเจ็ดหัวข้อ",
    downloadApp: "ดาวน์โหลดแอป อ่านฟรี", downloadAppShort: "ดาวน์โหลดแอป", appFree: "อ่านฟรี", buyReading: "ซื้อคำอ่าน",
    preview: "อ่านเบื้องต้นฟรี", takeaway: "ประเด็นหลักในชีวิตของคุณ", traits: "รู้จักลักษณะของคุณสามด้าน", birth: "ข้อมูลเกิดที่ใช้ครั้งนี้", created: "เวลาที่จัดทำ", number: "หมายเลขรายงาน",
    timeUnknown: "ไม่ทราบเวลาเกิด",
    name: "ชื่อ", defaultName: "เจ้าของรายงาน", timeRange: "ช่วงเวลาที่ใช้อ้างอิง", yearReference: "ข้อมูลอ้างอิงประจำปี", freeContent: "อ่านฟรี", priority: "สิ่งสำคัญลำดับที่",
    method: "วิธีการอ่าน", methodValue: "สุริยยาตร์ไทย · เรือนแบบราศี", evidence: "ดูข้อมูลที่ใช้ตีความ", evidenceHint: "นี่คือข้อมูลที่คำนวณในการอ่านครั้งนี้ ความหมายเป็นการตีความตามโหราศาสตร์ ไม่ใช่การยืนยันเหตุการณ์จริงในชีวิต",
    summaryEvidence: "ข้อมูลที่ใช้สรุปประเด็นนี้", feedback: "คำอ่านนี้ใกล้เคียงกับคุณไหม", feedbackOptions: ["ใกล้เคียงมาก", "ใกล้เคียงบางส่วน", "ไม่ค่อยตรง"], feedbackSaved: "บันทึกแล้ว ขอบคุณสำหรับความคิดเห็น", feedbackHint: "ความคิดเห็นช่วยประเมินเนื้อหา โดยไม่เปลี่ยนผลคำนวณครั้งนี้",
    catalog: "สารบัญรายงาน", catalogHint: "สามส่วนแรกอ่านฟรี เปิดฉบับเต็มเพื่ออ่านต่ออีกห้าเรื่อง", locked: "เปิดอ่านฉบับเต็ม", available: "จัดทำแล้ว", chapter: "หัวข้อ",
    offerTitle: "เข้าใจงาน เงิน และความสัมพันธ์ให้มากขึ้น", offerText: "คุณได้เห็นลักษณะของตัวเองแล้ว ฉบับเต็มจะอธิบายว่าสิ่งเหล่านี้เกี่ยวข้องกับการเลือกในชีวิตอย่างไร และลองทำอะไรให้เหมาะกับตัวเองได้บ้าง",
    benefits: ["รูปแบบการทำงานและแนวทางพัฒนา", "ทัศนคติต่อเงินและการวางแผน", "ความต้องการและแนวทางสื่อสาร", "ประเด็นช่วงนี้และการลงมือทำ"], unlock: "เปิดรายงานชีวิตฉบับเต็ม", direct: "เป็นการทดลองชำระเงิน ไม่มีการเรียกเก็บเงินจริง", once: "รายงานฉบับเดียว · สำหรับข้อมูลเกิดและปีที่ยืนยันครั้งนี้",
    backgroundGenerating: "กำลังสร้างฉบับเต็มระหว่างที่คุณอ่านคำอ่านเบื้องต้น", backgroundReady: "ฉบับเต็มพร้อมแล้ว เปิดอ่านได้ทันทีหลังปลดล็อก", backgroundRetry: "เลือกอ่านฟรีในแอป หรือซื้อคำอ่านฉบับเต็มบนเว็บ",
    unlocking: "กำลังเปิดรายงานฉบับเต็ม…", full: "เปิดรายงานฉบับเต็มแล้ว", progress: "กำลังสร้างรายงานฉบับเต็ม", progressHint: "หัวข้อที่เสร็จแล้วจะแสดงที่นี่ คุณกลับมาอ่านต่อจากรายงานของฉันได้", pausedHint: "กดจัดทำรายงานต่อเพื่อเติมเฉพาะส่วนที่ยังไม่เสร็จ ส่วนที่เสร็จแล้วถูกบันทึกไว้ คุณกลับมาทำต่อจากรายงานของฉันได้", progressUnit: "ส่วนที่เสร็จแล้ว",
    retry: "จัดทำรายงานต่อ", retryPreview: "สร้างคำอ่านเบื้องต้นอีกครั้ง", previewStates: { not_started: "ยังไม่ได้สร้างคำอ่านเบื้องต้น คุณสร้างใหม่ด้วยข้อมูลเดิมได้", pending: "กำลังสร้างคำอ่านเบื้องต้นสำหรับข้อมูลเดียวกัน โปรดลองเปิดอีกครั้งภายหลัง", generating: "กำลังสร้างคำอ่านเบื้องต้น…", ready: "สร้างคำอ่านเบื้องต้นแล้ว", limited: "บริการคำอ่านเบื้องต้นถึงขีดจำกัดชั่วคราว ข้อมูลเกิดยังอยู่ โปรดลองภายหลัง", unavailable: "ยังสร้างคำอ่านเบื้องต้นไม่สำเร็จ ข้อมูลเกิดยังอยู่ กดปุ่มด้านล่างเพื่อลองอีกครั้ง", unconfigured: "คำนวณข้อมูลเกิดแล้ว แต่บริการคำอ่านเบื้องต้นยังไม่พร้อม" }, states: { not_started: "กดเปิดฉบับเต็มเพื่อเริ่มสร้างเนื้อหา", pending: "ข้อมูลเดียวกันกำลังจัดทำ โปรดลองอีกครั้งภายหลัง", generating: "กำลังจัดทำรายงาน", ready: "รายงานฉบับเต็มจัดทำเสร็จแล้ว", limited: "บริการคำอ่านถึงขีดจำกัดชั่วคราว ส่วนที่เสร็จแล้วถูกบันทึกไว้ ลองทำต่อภายหลัง", unavailable: "ยังจัดทำไม่ครบ ส่วนที่เสร็จแล้วถูกบันทึกไว้ คุณลองใหม่ได้", unconfigured: "คำนวณดวงแล้ว แต่ยังไม่ได้ตั้งค่าบริการคำอ่าน" },
    plan: "ข้อเสนอแนะโดยรวม", viewAction: "กลับไปดูหัวข้อที่เกี่ยวข้อง", navigation: "สารบัญรายงาน", save: "บันทึกฉบับเต็ม (เว็บ)", savePreview: "บันทึกคำอ่านฟรี (เว็บ)", exportPdf: "บันทึกเป็น PDF", pdfPreparing: "กำลังสร้าง PDF…", pdfSaved: "บันทึก PDF ไปยังตำแหน่งที่เลือกแล้ว", pdfDownloaded: "ส่ง PDF ให้เบราว์เซอร์บันทึกแล้ว ตำแหน่งขึ้นอยู่กับการตั้งค่าดาวน์โหลดของเบราว์เซอร์หรือระบบ", pdfError: "ยังบันทึก PDF ไม่สำเร็จ โปรดลองใหม่",
    htmlPreparing: "กำลังบันทึกรายงานเว็บ…", htmlDownloaded: "ส่งรายงานเว็บให้เบราว์เซอร์บันทึกแล้ว", htmlError: "ยังบันทึกรายงานเว็บไม่สำเร็จ โปรดลองใหม่",
    history: "รายงานของฉัน", historyHint: "รายงานที่สร้างในอุปกรณ์นี้จะอยู่ที่นี่", emptyHistory: "ยังไม่มีรายงานที่บันทึกไว้", close: "ปิด", open: "อ่านต่อ", historyError: "ยังโหลดรายการรายงานไม่ได้ โปรดลองใหม่", previewVersion: "คำอ่านเบื้องต้น", fullVersion: "เปิดอ่านแล้ว", loading: "กำลังเปิดรายงาน…", printHint: "ก่อนเปิดฉบับเต็มจะบันทึกเฉพาะส่วนฟรี เมื่อสร้างและเปิดฉบับเต็มแล้วจึงรวมเนื้อหาทั้งหมด", chapterCount: "รายงานแปดส่วน", source: "ข้อมูลประกอบคำอ่าน", sourceVersion: "รุ่นการคำนวณและรายงาน", done: "รายงานฉบับเต็มจัดทำเสร็จแล้ว", resume: "ส่วนที่เสร็จแล้วจะอยู่ในรายการรายงานของอุปกรณ์นี้",
  },
};
export type LifeLabels = typeof lifeCopy[Language] & { careerQuestionTitle?: string };

export const careerCopy = {
  zh: {
    chooseQuestion: "事业问题（可选）",
    customQuestion: "此刻你最想知道的事情",
    writeQuestion: "写我的问题",
    browseQuestions: "选题",
    questionSelected: "已选",
    questionPurpose: "选一道或自己写，免费报告会先回答",
    questionHint: "上下滑动换题，点一下选中，再点一次取消。",
    situations: {
      unspecified: { label: "留还是走", question: "我该换工作吗？", details: {
        decision: "怎么判断还有没有转机？", stay: "留下来，什么值得争取？",
        move: "怎么防止换了工作还踩坑？", next: "今天先问什么，才能看清去留？",
      } },
      considering: { label: "想辞职", question: "还没下家，我该辞职吗？", details: {
        decision: "没下家，今天能提离职吗？", stay: "暂时留下，怎么少耗一点？",
        move: "下家还没影，先从哪找？", next: "真想走，今天先准备什么？",
      } },
      searching: { label: "等结果", question: "面试没回音，我该跟进吗？", details: {
        decision: "过了回复日，今天要催吗？", stay: "要等结果再跟现公司谈吗？",
        move: "面试没回音，要继续投吗？", next: "跟进消息怎么发？",
      } },
      offer: { label: "待答复", question: "这份 Offer，我该接吗？", details: {
        decision: "新工作能解决我想走的原因吗？", stay: "留下的条件，怎么确认会兑现？",
        move: "答复前，哪些条件一定要问清？", next: "到答复前还没问清，怎么办？",
      } },
    },
    generate: "免费看这条行运", shortTitle: "留任与换岗对照", subtitle: "结合这段事业行运，先看眼下怎么做。",
    takeaway: "先看这段时间的倾向",
    offerTitle: "把两条路放进未来 30 天一起看", offerText: "继续看留任和换岗各自值得留意的时间，以及什么时候可以重新比较。",
    benefits: ["留任的观察时段", "换岗的观察时段", "行运依据", "下一次比较的节点"],
    unlock: "解锁未来 30 天留任与换岗对照", once: "本次事业解读 · 单次解锁",
    catalogHint: "先免费读两条路，再展开未来 30 天的对照。", chapterCount: "留任与换岗", feedback: "这条解读回应了你的问题吗？",
    previewHint: "正在计算近期行运，整理留下和换走两条路…", fullHint: "正在展开未来 30 天的留任与换岗对照…",
  },
  th: {
    chooseQuestion: "คำถามเรื่องงาน (ข้ามได้)",
    customQuestion: "ตอนนี้คุณอยากรู้เรื่องอะไรที่สุด",
    writeQuestion: "พิมพ์คำถาม",
    browseQuestions: "เลือกคำถาม",
    questionSelected: "เลือกแล้ว",
    questionPurpose: "เลือกสักข้อหรือพิมพ์เอง รายงานฟรีจะตอบก่อน",
    questionHint: "เลื่อนขึ้นลงเพื่อเปลี่ยนคำถาม แตะเพื่อเลือกหรือแตะซ้ำเพื่อยกเลิก",
    situations: {
      unspecified: { label: "อยู่หรือไป", question: "ควรย้ายงานไหม?", details: {
        decision: "ดูยังไงว่างานเดิมจะดีขึ้น?", stay: "ถ้าอยู่ต่อ ควรขอปรับอะไร?",
        move: "ย้ายงานยังไงให้ไม่เจอปัญหาเดิม?", next: "วันนี้ควรถามอะไรเพื่อตัดสินใจ?",
      } },
      considering: { label: "ลาออก", question: "ยังไม่มีงานใหม่ ควรลาออกไหม?", details: {
        decision: "ยังไม่มีงานใหม่ ลาออกวันนี้ดีไหม?", stay: "อยู่ต่อยังไงให้เหนื่อยน้อยลง?",
        move: "ยังไม่มีที่ใหม่ เริ่มหาจากไหน?", next: "ถ้าอยากออก วันนี้เตรียมอะไร?",
      } },
      searching: { label: "รอผล", question: "สัมภาษณ์แล้วเงียบ ควรทักไปถามไหม?", details: {
        decision: "เลยวันนัดแล้ว วันนี้ควรทักไหม?", stay: "ควรรอผลก่อนคุยกับที่เดิมไหม?",
        move: "ยังไม่ตอบ ควรสมัครที่อื่นต่อไหม?", next: "เขียนข้อความตามผลยังไง?",
      } },
      offer: { label: "รอตอบ", question: "ควรรับข้อเสนองานนี้ไหม?", details: {
        decision: "งานใหม่จะแก้ปัญหาเดิมได้ไหม?", stay: "จะรู้ได้ยังไงว่าที่เดิมทำตามที่ตกลง?",
        move: "ก่อนตอบรับ ต้องถามอะไรให้ชัด?", next: "ถึงกำหนดตอบแต่ข้อมูลยังไม่ครบ ทำยังไง?",
      } },
    },
    generate: "อ่านดวงงานฟรี", shortTitle: "เปรียบเทียบอยู่ต่อกับเปลี่ยนงาน", subtitle: "ดูดาวจรด้านการงาน แล้วเลือกสิ่งที่ทำได้ตอนนี้",
    takeaway: "แนวโน้มช่วงนี้",
    offerTitle: "ดูทั้งสองทางใน 30 วันข้างหน้า", offerText: "อ่านต่อว่าช่วงไหนควรสังเกตหากอยู่ต่อหรือเปลี่ยนงาน และเมื่อไรควรกลับมาเทียบอีกครั้ง",
    benefits: ["ช่วงที่ควรสังเกตหากอยู่ต่อ", "ช่วงที่ควรสังเกตหากเปลี่ยนงาน", "ข้อมูลดาวที่ใช้ตีความ", "จุดทบทวนทางเลือก"],
    unlock: "เปิดอ่านเปรียบเทียบการงาน 30 วัน", once: "คำอ่านการงานครั้งนี้ · เปิดอ่านครั้งเดียว",
    catalogHint: "อ่านสองทางเลือกเบื้องต้นฟรี แล้วเปิดดูจังหวะ 30 วันฉบับเต็ม", chapterCount: "อยู่ต่อหรือเปลี่ยนงาน", feedback: "คำอ่านนี้ตอบเรื่องที่คุณอยากรู้ไหม?",
    previewHint: "กำลังคำนวณดาวจรช่วงนี้ แล้วเปรียบเทียบการอยู่ต่อกับเปลี่ยนงาน…", fullHint: "กำลังจัดทำคำอ่านเปรียบเทียบการงาน 30 วัน…",
  },
};

export function lifeLabels(report: LifeReport): LifeLabels {
  const language = report.input.profile.language;
  const labels = { ...lifeCopy[language], ...(report.input.report_kind === "fortune" ? fortuneCopy[language] : {}) };
  const question = report.input.career_question;
  if (question) {
    const situation = careerCopy[language].situations[question.stage];
    return { ...labels, careerQuestionTitle: question.focus ? situation.details[question.focus] : situation.question };
  }
  const input = report.input.career;
  if (!input) return labels;
  const career = careerCopy[language];
  const title = input.focus ? career.situations[input.stage].details[input.focus] : report.title;
  return { ...labels, ...career, title };
}

let reportKey: string | undefined;
export function getReportKey(language: Language = "zh"): string {
  const keyName = "astro-life-report-key";
  const stores: Storage[] = [];
  for (const name of ["localStorage", "sessionStorage"] as const) {
    try {
      const storage = window[name], saved = storage.getItem(keyName);
      stores.push(storage);
      if (!reportKey && saved && /^[A-Za-z0-9_-]{32,128}$/.test(saved)) reportKey = saved;
    } catch { /* The other store may still survive navigation in this tab. */ }
  }
  if (!reportKey) {
    reportKey = Array.from(crypto.getRandomValues(new Uint8Array(24)), value => value.toString(16).padStart(2, "0")).join("");
  }
  let persisted = false;
  for (const storage of stores) {
    try {
      if (storage.getItem(keyName) !== reportKey) storage.setItem(keyName, reportKey);
      persisted ||= storage.getItem(keyName) === reportKey;
    } catch { /* Preserve a readable existing key even when writes are denied. */ }
  }
  // A full-page report must be able to read the same owner key after navigation.
  if (!persisted) { reportKey = undefined; throw new Error(generationCopy[language].storage); }
  return reportKey;
}
export async function lifeApi<T>(path: string, language: Language, signal: AbortSignal, body?: unknown) {
  return api<T>(path, language, signal, body, { "X-Report-Key": getReportKey(language) });
}
export function lifeSignature(input: LifeInput): string {
  const p = input.profile;
  const question = input.career_question;
  return JSON.stringify([p.birth_date, p.birth_time, p.birthplace, p.timezone, p.language, p.country_code, p.location_id, p.latitude, p.longitude, input.year, input.career?.stage, input.career?.start, input.career?.focus, question?.stage, question?.start, question?.focus, input.user_question, input.report_kind]);
}
const fullProgressKeys = ["work", "money", "relationships", "annual", "plan"];
const fortuneProgressKeys = [...fortuneTopicKeys, "plan"];
const careerProgressKeys = ["work"];
const previewProgressKeys = ["preview_summary", "preview_strength", "preview_decisions", "preview_relationships"];
function isContentProgress(value: unknown, keys: string[]): boolean {
  if (!value || typeof value !== "object") return false;
  const progress = value as { percent: number; sections: { key: string; percent: number }[] };
  return Number.isInteger(progress.percent) && progress.percent >= 0 && progress.percent <= 100
    && Array.isArray(progress.sections) && progress.sections.length === keys.length
    && progress.sections.every(section => !!section && keys.includes(section.key) && Number.isFinite(section.percent) && section.percent >= 0 && section.percent <= 100)
    && new Set(progress.sections.map(section => section.key)).size === keys.length;
}
export function isLifeReport(value: unknown): value is LifeReport {
  if (!value || typeof value !== "object") return false;
  const report = value as LifeReport;
  return typeof report.id === "string" && !!report.input?.profile && ["zh", "th"].includes(report.input.profile.language)
    && Array.isArray(report.catalog) && report.catalog.length === (report.input.career ? 1 : report.input.report_kind === "fortune" ? 7 : 5) && Array.isArray(report.chapters)
    && (report.input.report_kind !== "fortune" || new Set(report.catalog.map(item => item.key)).size === 7 && report.catalog.every(item => fortuneTopicKeys.includes(item.key as FortuneTopicKey)))
    && (!report.preview || Array.isArray(report.preview.traits) && report.preview.traits.length === 3)
    && ["preview", "full"].includes(report.access) && Number.isInteger(report.progress?.completed)
    && Number.isInteger(report.progress?.total) && report.progress.total > 0 && report.progress.completed >= 0 && report.progress.completed <= report.progress.total
    && (!report.generation_progress || isContentProgress(report.generation_progress, report.input.career ? careerProgressKeys : report.input.report_kind === "fortune" ? fortuneProgressKeys : fullProgressKeys))
    && (!report.preview_generation_progress || isContentProgress(report.preview_generation_progress, previewProgressKeys));
}

export interface GenerationProgress {
  percent: number;
  completed: number;
  total: number;
  phase: "preview" | "full" | "reconnecting" | "waiting" | "ready";
  sections?: (NonNullable<LifeReport["generation_progress"]>["sections"][number] | NonNullable<LifeReport["preview_generation_progress"]>["sections"][number])[];
}
export const initialGenerationProgress: GenerationProgress = { percent: 0, completed: 0, total: 100, phase: "full" };
export const initialPreviewProgress: GenerationProgress = { ...initialGenerationProgress, phase: "preview" };

export const generationCopy = {
  zh: { title: "正在生成完整运程解析", previewTitle: "正在生成你的免费解析", previewFailed: "免费报告暂未生成完成", sections: {preview_summary: "报告摘要", preview_strength: "性格与优势", preview_decisions: "判断与选择", preview_relationships: "相处特点", work: "事业发展", money: "财务方面", relationships: "感情与家庭", annual: "年度运程", overall: "整体运程", pattern: "格局解读", marriage: "婚姻情感", wealth: "财运事业", risk: "风险提醒", romance: "姻缘", plan: "总结建议"}, returnReport: "返回试读报告", preview: "正在计算出生资料，整理报告摘要与个人特点…", full: "正在整理完整主题与行动建议…", reconnecting: "连接暂时中断，正在重新查询生成进度…", waiting: "进度查询暂时受限，稍后自动继续。报告仍在后台生成…", queryError: "暂时无法查询报告进度，已完成的内容已保留，请稍后重试。", ready: "报告已生成，正在打开…", failed: "报告暂未生成完成", cancel: "取消等待", back: "返回填写资料", retry: "重试", missing: "未找到报告，请返回页面重新生成。", busy: "报告服务当前繁忙，请稍后点击继续生成。已完成的内容会保留。", storage: "浏览器暂时无法保存报告的访问凭据，请允许此网站使用存储后重试。" },
  th: { title: "กำลังจัดทำคำอ่านดวงฉบับเต็ม", previewTitle: "กำลังสร้างคำอ่านเบื้องต้นฟรี", previewFailed: "ยังสร้างคำอ่านฟรีไม่เสร็จ", sections: {preview_summary: "สรุปรายงาน", preview_strength: "นิสัยและจุดแข็ง", preview_decisions: "การตัดสินใจ", preview_relationships: "การอยู่ร่วมกับผู้อื่น", work: "การงานและการเติบโต", money: "การเงิน", relationships: "ความรักและครอบครัว", annual: "ดวงรายปี", overall: "ภาพรวมชีวิต", pattern: "โครงสร้างพื้นดวง", marriage: "ชีวิตคู่และความรัก", wealth: "การเงินและการงาน", risk: "ข้อควรระวัง", romance: "คู่ครองและการพบรัก", plan: "ข้อเสนอแนะโดยรวม"}, returnReport: "กลับไปอ่านคำอ่านเบื้องต้น", preview: "กำลังคำนวณข้อมูลเกิดและเรียบเรียงสรุปกับลักษณะส่วนตัว…", full: "กำลังจัดทำหัวข้อฉบับเต็มและคำแนะนำ…", reconnecting: "การเชื่อมต่อขาดหายชั่วคราว กำลังตรวจความคืบหน้าอีกครั้ง…", waiting: "พักการตรวจความคืบหน้าชั่วคราว แล้วจะตรวจต่ออัตโนมัติ รายงานยังสร้างอยู่เบื้องหลัง…", queryError: "ยังตรวจความคืบหน้าไม่ได้ ส่วนที่เสร็จแล้วถูกบันทึกไว้ โปรดลองอีกครั้งภายหลัง", ready: "สร้างรายงานแล้ว กำลังเปิดอ่าน…", failed: "ยังสร้างรายงานไม่เสร็จ", cancel: "ยกเลิกการรอ", back: "กลับไปกรอกข้อมูลเกิด", retry: "ลองอีกครั้ง", missing: "ไม่พบรายงาน กรุณากลับไปสร้างรายงานอีกครั้ง", busy: "บริการรายงานกำลังมีผู้ใช้งานมาก โปรดกดจัดทำรายงานต่อภายหลัง ส่วนที่เสร็จแล้วถูกบันทึกไว้", storage: "เบราว์เซอร์ยังบันทึกสิทธิ์อ่านรายงานไม่ได้ โปรดอนุญาตให้เว็บไซต์ใช้พื้นที่จัดเก็บแล้วลองอีกครั้ง" },
} as const;

export function reportGenerationProgress(report: LifeReport): GenerationProgress {
  const { completed, total } = report.progress;
  if (!Number.isInteger(total) || total < 1 || !Number.isInteger(completed) || completed < 0 || completed > total) {
    throw new Error(ui[report.input.profile.language].badResult);
  }
  const preview = report.preview !== null && report.preview_state === "ready";
  const ready = preview && report.full_state === "ready" && completed === total;
  const detailed = report.generation_progress;
  if (detailed && !isContentProgress(detailed, report.input.career ? careerProgressKeys : report.input.report_kind === "fortune" ? fortuneProgressKeys : fullProgressKeys)) throw new Error(ui[report.input.profile.language].badResult);
  const percent = ready ? 100 : Math.min(99, detailed?.percent ?? Math.floor(completed / total * 100));
  return {
    percent, completed: percent, total: 100, sections: detailed?.sections,
    phase: ready ? "ready" : preview ? "full" : "preview",
  };
}

export function previewGenerationProgress(report: LifeReport): GenerationProgress {
  const detailed = report.preview_generation_progress;
  if (detailed && !isContentProgress(detailed, previewProgressKeys)) throw new Error(ui[report.input.profile.language].badResult);
  const ready = report.preview !== null && report.preview_state === "ready";
  const percent = ready ? 100 : Math.min(99, detailed?.percent ?? 0);
  return { percent, completed: percent, total: 100, phase: ready ? "ready" : "preview", sections: detailed?.sections };
}

// The API allows 30 requests per path per minute; leave room for opening a saved report.
export const lifeReportPollInterval = 3000;

function generationPause(signal: AbortSignal, delay: number): Promise<void> {
  signal.throwIfAborted();
  return new Promise((resolve, reject) => {
    const abort = () => { window.clearTimeout(timer); reject(signal.reason); };
    const timer = window.setTimeout(() => { signal.removeEventListener("abort", abort); resolve(); }, delay);
    signal.addEventListener("abort", abort, { once: true });
  });
}

export async function generateLifeReport(input: LifeInput, signal: AbortSignal, onProgress: (progress: GenerationProgress) => void = () => {}): Promise<LifeReport> {
  const language = input.profile.language;
  const report = await lifeApi<unknown>("/api/life-reports?wait=false", language, signal, input);
  return waitForLifeReport(input, report, "preview", signal, onProgress);
}

export async function unlockLifeReport(initial: LifeReport, signal: AbortSignal, onProgress: (progress: GenerationProgress) => void): Promise<LifeReport> {
  const report = await lifeApi<unknown>(`/api/life-reports/${initial.id}/unlock`, initial.input.profile.language, signal, {});
  return waitForLifeReport(initial.input, report, "full", signal, onProgress, initial.id);
}

async function waitForLifeReport(input: LifeInput, report: unknown, kind: "preview" | "full", signal: AbortSignal, onProgress: (progress: GenerationProgress) => void, identifier?: string): Promise<LifeReport> {
  const language = input.profile.language, labels = lifeCopy[language];
  const signature = lifeSignature(input);
  let failures = 0;
  for (;;) {
    signal.throwIfAborted();
    if (!isLifeReport(report) || lifeSignature(report.input) !== signature || identifier && report.id !== identifier || kind === "full" && report.access !== "full") throw new Error(ui[language].badResult);
    identifier = report.id;
    const progress = kind === "preview" ? previewGenerationProgress(report) : reportGenerationProgress(report);
    onProgress(progress);
    if (progress.phase === "ready") return report;
    if (kind === "preview" && report.preview_state === "ready" && !report.preview) throw new Error(ui[language].badResult);
    // The provider's pending response is a busy rejection, not a queued background job.
    if ((!report.preview && report.preview_state === "pending") || (kind === "full" && report.full_state === "pending")) throw new Error(generationCopy[language].busy);
    if ((kind === "preview" || !report.preview) && report.preview_state !== "generating") throw new Error(labels.previewStates[report.preview_state]);
    if (kind === "full" && ["limited", "unavailable", "unconfigured", "not_started"].includes(report.full_state)) throw new Error(labels.states[report.full_state]);
    let delay = lifeReportPollInterval;
    for (;;) {
      await generationPause(signal, delay);
      try {
        report = await lifeApi(`/api/life-reports/${encodeURIComponent(identifier)}`, language, signal);
        failures = 0;
        break;
      } catch (cause) {
        if (signal.aborted) throw cause;
        if (cause instanceof ApiError && cause.status === 404) throw new Error(generationCopy[language].missing);
        if (cause instanceof ApiError && cause.status === 429) {
          // Throttled reads do not stop the background job or consume network-failure retries.
          delay = Math.max(lifeReportPollInterval, cause.retryAfterMs ?? 60000);
          onProgress({ ...progress, phase: "waiting" });
          continue;
        }
        if (++failures >= 3) throw new Error(generationCopy[language].queryError);
        delay = lifeReportPollInterval * 2 ** failures;
        onProgress({ ...progress, phase: "reconnecting" });
      }
    }
  }
}

export function lifeReportUrl(report: LifeReport): string {
  const url = new URL("report.html", document.baseURI);
  url.searchParams.set("id", report.id);
  url.searchParams.set("lang", report.input.profile.language);
  return url.href;
}
