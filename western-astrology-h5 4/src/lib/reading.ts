import type { LifeLabels, LifePoint, LifeReport, LifeSummary } from "./lifeReport";
import { reportContent, reportReference } from "./reportContent";
import copy from "../content/thai-test.json" with { type: "json" };

export type Language = "zh" | "th";
export type Reading = keyof typeof copy.zh.readings;
export const readings: Reading[] = [
  "overview",
  "annual",
  "money",
  "love",
  "work",
  "family",
];
export const readingCopy = (language: Language) => copy[language];
export interface Place {
  id: string;
  countryCode: string;
  nameEnglish: string;
  nameChinese?: string;
  nameThai?: string;
  labelChinese?: string;
  labelThai?: string;
  placeType?: "city" | "province";
  provinceId?: string;
  provinceNameEnglish?: string;
  provinceNameChinese?: string;
  provinceNameThai?: string;
  aliases?: string[];
  coordinateKind?: string;
  featureCode?: string;
  timeZone: string;
  latitude: number;
  longitude: number;
}
export function placeName(place: Place, language: Language) {
  const label = language === "zh" ? place.labelChinese : place.labelThai;
  if (label) return label;
  const names = ui[language].countryNames;
  const country = names[place.countryCode as keyof typeof names] || place.countryCode;
  return [country, (language === "zh" ? place.nameChinese : place.nameThai) || place.nameEnglish].filter(Boolean).join("，");
}
export interface ReadingInput {
  profile: {
    display_name: string;
    birth_date: string;
    birth_time: string | null;
    birthplace: string;
    timezone: string;
    language: Language;
    country_code: string;
    location_id: string | null;
    latitude: number | null;
    longitude: number | null;
  };
  reading: Reading;
  year: number;
}
export interface ReadingItem {
  title: string;
  text: string;
  period: { year: number; month: number } | null;
  signals?: string[];
  response?: string;
  steps?: string[];
  example?: string;
  pitfall?: string;
  check?: string;
}
export const ui = {
  zh: {
    date: "出生日期",
    ce: "阳历",
    time: "出生时间",
    unknown: "不记得确切时间",
    timeNote:
      "没有确切出生时间也可继续。报告按出生地中午12:00估算，部分解读可能存在偏差，建议结合实际情况参考。",
    timeRequired: "请填写出生时间，或勾选“不记得确切时间”。",
    city: "市区",
    country: "出生国家",
    countryPlaceholder: "请输入中国或泰国",
    province: "省份 / 府州",
    provincePlaceholder: "如：河北省",
    thaiProvincePlaceholder: "如：清迈府",
    countryFirst: "请先输入国家",
    provinceFirst: "请先确认省份 / 府州",
    invalidCountry: "目前支持中国和泰国，可输入中文、泰文或英文名称。",
    invalidProvince: "请从该国家的省份 / 府州中选择，也可输入完整名称。",
    cityPlaceholder: "如：邯郸市、丛台区",
    thaiCityPlaceholder: "如：Mueang Chiang Mai",
    chooseCity: "请选择对应的出生地点",
    searching: "正在识别出生地点…",
    placeHint: "先输入国家，再填写省份 / 府州和市区；支持中、泰、英文检索。",
    noCity: "暂未识别到地点，请补充省份或尝试其他名称。",
    locationError: "地点识别暂时不可用，请重试。",
    provinceNote: "按所选省份的省会或府治代表坐标排盘。",
    areaNote: "所选地点为行政区，采用该行政区的代表坐标排盘。",
    areaLabel: "行政区",
    cityLabel: "城镇",
    morePlaces: "查看更多地点",
    retryPlaces: "重新查找",
    selectedPlace: "已识别",
    invalidDate: "请选择有效的出生日期，范围为1901年起，不能晚于出生地的今天。",
    invalidPlace: "请输入出生地点，并确认识别结果。",
    invalidTimezone: "出生地点的时区信息无效，请重新输入或选择地点。",
    invalidYear: "请选择1901至2100之间的年份。",
    theme: "选择你想了解的主题",
    themeSub: "同一张个人星盘，从你关心的问题出发",
    formHint: "出生资料仅用于本次测算，不会修改你的个人档案。",
    network: "暂时连接不到解读服务，请稍后重试。",
    badResult: "这次没有收到完整的解读，请重试。",
    cancel: "取消",
    cancelHint: "报告需要一点时间整理，你也可以取消后修改资料。",
    close: "关闭",
    countryNames: { TH: "泰国", CN: "中国", VN: "越南", US: "美国" },
  },
  th: {
    date: "วันเกิด",
    ce: "ปี ค.ศ.",
    time: "เวลาเกิด",
    unknown: "ไม่ทราบเวลาเกิดที่แน่นอน",
    timeNote:
      "ไม่ทราบเวลาเกิดที่แน่นอนก็สร้างรายงานต่อได้ ระบบประมาณจากเวลาเที่ยง 12:00 ของสถานที่เกิด คำอ่านบางส่วนอาจคลาดเคลื่อน โปรดใช้ประกอบการพิจารณา",
    timeRequired: "กรอกเวลาเกิด หรือเลือกไม่ทราบเวลาเกิดที่แน่นอน",
    city: "เมือง / อำเภอ / เขต",
    country: "ประเทศเกิด",
    countryPlaceholder: "กรอกจีนหรือไทย",
    province: "มณฑล / จังหวัด",
    provincePlaceholder: "เช่น 河北省",
    thaiProvincePlaceholder: "เช่น เชียงใหม่",
    countryFirst: "กรอกประเทศก่อน",
    provinceFirst: "ยืนยันมณฑล / จังหวัดก่อน",
    invalidCountry: "รองรับจีนและไทย กรอกชื่อภาษาจีน ไทย หรืออังกฤษได้",
    invalidProvince: "เลือกมณฑล / จังหวัดของประเทศนี้ หรือกรอกชื่อเต็ม",
    cityPlaceholder: "เช่น 邯郸市 หรือ 丛台区",
    thaiCityPlaceholder: "เช่น เมืองเชียงใหม่",
    chooseCity: "เลือกสถานที่เกิดที่ตรงกับข้อมูลของคุณ",
    searching: "กำลังระบุสถานที่เกิด…",
    placeHint: "กรอกประเทศ แล้วกรอกมณฑล / จังหวัดและเมือง / เขต ค้นหาได้ด้วยภาษาจีน ไทย หรืออังกฤษ",
    noCity: "ยังไม่พบสถานที่ ลองเพิ่มจังหวัดหรือใช้ชื่ออื่น",
    locationError: "ยังระบุสถานที่ไม่ได้ กรุณาลองอีกครั้ง",
    provinceNote: "ใช้พิกัดตัวแทนของเมืองหลวงมณฑลหรือที่ตั้งศาลากลางจังหวัดในการคำนวณดวง",
    areaNote: "สถานที่ที่เลือกเป็นเขตปกครอง ระบบใช้พิกัดตัวแทนของเขตนั้นในการคำนวณ",
    areaLabel: "เขตปกครอง",
    cityLabel: "เมือง",
    morePlaces: "ดูสถานที่เพิ่มเติม",
    retryPlaces: "ค้นหาอีกครั้ง",
    selectedPlace: "ระบุสถานที่แล้ว",
    invalidDate:
      "เลือกวันเกิดที่ถูกต้อง ตั้งแต่ปี ค.ศ. 1901 และไม่เกินวันนี้ในเขตเวลาเกิด",
    invalidPlace: "กรอกสถานที่เกิดและยืนยันผลการค้นหา",
    invalidTimezone: "เขตเวลาของสถานที่เกิดไม่ถูกต้อง กรุณากรอกหรือเลือกสถานที่อีกครั้ง",
    invalidYear: "เลือกปี ค.ศ. ตั้งแต่ 1901 ถึง 2100",
    theme: "เลือกเรื่องที่คุณอยากเข้าใจ",
    themeSub: "จากดวงกำเนิดของคุณ สู่คำถามที่สำคัญในตอนนี้",
    formHint:
      "ข้อมูลเกิดใช้สำหรับการอ่านครั้งนี้เท่านั้น โดยไม่แก้ไขข้อมูลในโปรไฟล์ของคุณ",
    network: "ยังเชื่อมต่อบริการคำอ่านไม่ได้ โปรดลองอีกครั้ง",
    badResult: "ยังไม่ได้รับคำอ่านที่สมบูรณ์ โปรดลองอีกครั้ง",
    cancel: "ยกเลิก",
    cancelHint: "การจัดทำรายงานอาจใช้เวลาสักครู่ คุณยกเลิกเพื่อแก้ไขข้อมูลได้",
    close: "ปิด",
    countryNames: { TH: "ไทย", CN: "จีน", VN: "เวียดนาม", US: "สหรัฐอเมริกา" },
  },
};

export function periodLabel(
  period: { year: number; month: number },
  language: Language,
) {
  return new Intl.DateTimeFormat(language === "zh" ? "zh-CN" : "th-TH", {
    year: "numeric",
    month: "long",
    calendar: "gregory",
    timeZone: "UTC",
  }).format(new Date(Date.UTC(period.year, period.month - 1, 1)));
}

export class ApiError extends Error {
  constructor(message: string, readonly status: number, readonly retryAfterMs: number | null = null) {
    super(message);
    this.name = "ApiError";
  }
}

function retryAfterDelay(value: string | null): number | null {
  if (!value?.trim()) return null;
  const delay = /^\d+(\.\d+)?$/.test(value.trim()) ? Number(value) * 1000 : Date.parse(value) - Date.now();
  return Number.isFinite(delay) ? Math.max(0, Math.min(2147483647, delay)) : null;
}

export async function api<T>(
  path: string,
  language: Language,
  signal: AbortSignal,
  body?: unknown,
  extraHeaders: Record<string, string> = {},
): Promise<T> {
  let response: Response;
  try {
    response = await fetch(path, {
      method: body ? "POST" : "GET",
      signal,
      headers: {
        "Accept-Language": language,
        ...(body ? { "Content-Type": "application/json" } : {}),
        ...extraHeaders,
      },
      ...(body ? { body: JSON.stringify(body) } : {}),
    });
  } catch (error) {
    if (signal.aborted) throw error;
    throw new Error(ui[language].network);
  }
  const data = await response.json().catch(() => null);
  if (!response.ok)
    throw new ApiError(
      typeof data?.detail === "string" ? data.detail : ui[language].network,
      response.status,
      retryAfterDelay(response.headers.get("Retry-After")),
    );
  if (!data) throw new Error(ui[language].badResult);
  return data as T;
}

// Export only the server-returned preview until the complete version is ready.
export function reportHtml(result: LifeReport, c: LifeLabels): string {
  const language = result.input.profile.language;
  const sections = reportContent(result);
  const full = result.access === "full" && result.full_state === "ready";
  const escape = (text: string) => text.replace(/[&<>"']/g, char => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[char]!);
  const evidence = (item: LifeSummary) => '<details><summary>' + escape(c.evidence) + '</summary>' + item.evidence.map(fact => '<p><strong>' + escape(fact.title) + '</strong> ' + escape(fact.detail) + '</p>').join('') + '<p>' + escape(c.evidenceHint) + '</p></details>';
  const list = (items: string[], ordered = false) => '<' + (ordered ? 'ol' : 'ul') + '>' + items.map(text => '<li>' + escape(text) + '</li>').join('') + '</' + (ordered ? 'ol' : 'ul') + '>';
  const point = (item: LifePoint) => '<article><h4>' + escape(item.title) + '</h4><p>' + escape(item.text) + '</p>' + (item.signals ? list(item.signals) : '') + (item.response ? '<p>' + escape(item.response) + '</p>' : '') + (item.steps ? list(item.steps, true) : '') + (['example','pitfall','check'] as const).map(key => item[key] ? '<p>' + escape(item[key]!) + '</p>' : '').join('') + evidence(item) + '</article>';
  const answer = result.preview?.career_answer;
  const careerAnswer = answer && c.careerQuestionTitle ? '<h2>' + escape(c.careerQuestionTitle) + '</h2><p>' + escape(answer.text) + '</p>' + evidence(answer) : '';
  const typedQuestion = result.input.user_question ? '<h3>' + escape(result.input.user_question) + '</h3>' : '';
  const preview = result.preview ? '<section><p class="label">' + escape(c.preview) + '</p>' + careerAnswer + '<h2>' + escape(sections[1].title) + '</h2>' + typedQuestion + '<p class="takeaway">' + escape(result.preview.summary.text) + '</p>' + evidence(result.preview.summary) + '</section><section><h2>' + escape(sections[2].title) + '</h2>' + result.preview.traits.map(point).join('') + '</section>' : '';
  const catalog = '<section><h2>' + escape(c.catalog) + '</h2>' + sections.filter(section => full || !section.paid).map(section => '<h3>' + escape(section.title) + '</h3><p>' + escape(section.description) + '</p>').join('') + '</section>';
  const chapters = full ? sections.filter(section => section.paid && section.groups.length).map(section => '<section><h2>' + escape(section.title) + '</h2>' + section.summaries.map(summary => '<p class="takeaway">' + escape(summary.text) + '</p>' + evidence(summary)).join('') + section.groups.map(group => '<h3>' + escape(group.title) + '</h3>' + group.entries.map(entry => point(entry.point)).join('')).join('') + '</section>').join('') : '';
  const plan = full && result.plan ? '<section><h2>' + escape(sections[7].title) + '</h2><p>' + escape(sections[7].description) + '</p>' + result.plan.phases.map((phase,index) => '<h3>' + escape(c.priority) + ' ' + (index + 1) + '</h3><h4>' + escape(phase.title) + '</h4><p>' + escape(phase.text) + '</p>' + phase.actions.map(action => '<h4>' + escape(action.title) + '</h4>' + list(action.steps || [],true)).join('')).join('') + '</section>' : '';
  return '<!doctype html><html lang="' + language + '"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>' + escape(c.title) + '</title><style>html{background:#130c24;color-scheme:dark}*{box-sizing:border-box}body{max-width:820px;margin:0 auto;padding:40px 28px;background:radial-gradient(ellipse at 0 0,#352044,transparent 55%),#130c24;color:#fff5df;font:15px/1.95 "Noto Sans SC","Noto Sans Thai",system-ui,sans-serif}h1,h2,h3,h4,h5{break-after:avoid}h1{font-size:36px;font-weight:500}h2{font-size:25px;color:#e4bc78}h3{font-size:19px;color:#e4bc78}h4{font-size:17px;margin:0 0 12px}h5{font-size:14px;color:#e4bc78;margin-bottom:6px}p,li{overflow-wrap:anywhere;color:#d5c8e3}p{margin:12px 0}.label{font-size:12px;color:#e4bc78}.takeaway{font-size:20px;color:#fff5df}section{border-top:1px solid #e4bc7850;margin-top:34px;padding-top:18px}article{margin:26px 0;padding:18px;background:#21162f;border:1px solid #e4bc7830;border-radius:12px;break-inside:avoid}details{font-size:12px;background:#160f24;border:1px solid #e4bc7830;border-radius:8px;padding:12px;margin-top:16px;color:#b4a8c6}summary{color:#e4bc78;cursor:pointer}li{padding-left:4px;margin:10px 0}header{border:1px solid #e4bc7860;border-radius:16px;padding:24px;background:#241535}footer{margin-top:36px;font-size:11px;color:#b4a8c6}@page{size:A4;margin:16mm}@media print{html,body{background:#130c24!important;color:#fff5df;-webkit-print-color-adjust:exact;print-color-adjust:exact}body{padding:0;max-width:none;font-size:11pt}details{display:block}details>*{display:block}article{break-inside:auto}section{break-before:auto}}</style></head><body><header><p class="label">ASTRO · AI</p><h1>' + escape(c.title) + '</h1><p>' + escape(c.subtitle) + '</p><h2>' + escape(sections[0].title) + '</h2><p>' + escape(c.name) + ': ' + escape(result.input.profile.display_name || c.defaultName) + '</p><p>' + escape(result.input.profile.birth_date) + ' · ' + escape(result.input.profile.birth_time || c.timeUnknown) + '<br>' + escape(result.input.profile.birthplace) + ' · ' + escape(result.input.profile.timezone) + '</p>' + (!result.input.profile.birth_time ? '<p>' + escape(ui[language].timeNote) + '</p>' : '') + '<p class="label">' + escape(c.methodValue) + '<br>' + escape(c.timeRange) + ': ' + escape(reportReference(result, c)) + '<br>' + escape(result.id.toUpperCase()) + '</p></header>' + preview + catalog + chapters + plan + '<footer>' + escape(c.sourceVersion) + ' · ' + escape(result.method.version) + ' / ' + escape(result.version) + '</footer></body></html>';
}
