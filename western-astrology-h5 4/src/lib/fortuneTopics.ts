import catalog from "../../../TH/backend/content/fortune-topics.json" with { type: "json" };
import type { Language } from "./reading";

export type FortuneTopicKey = "annual" | "overall" | "pattern" | "marriage" | "wealth" | "risk" | "romance";
interface TopicCopy { title: string; subtitle: string; questions: string[]; groups: string[] }
interface FortuneTopic { key: FortuneTopicKey; houses: number[]; zh: TopicCopy; th: TopicCopy }

// The landing page, report outline and server use the same seven-topic catalog.
export const fortuneTopics = catalog.topics as FortuneTopic[];
export const fortuneTopicKeys = fortuneTopics.map(topic => topic.key);
export function fortuneTopicTitle(key: FortuneTopicKey, language: Language, year: number): string {
  if (key === "annual") return language === "zh" ? `${year}年运程` : `ดวงปี ${year}`;
  return fortuneTopics.find(topic => topic.key === key)![language].title;
}

export const fortuneCopy = {
  zh: {
    title: "运程解析", subtitle: "从年度节奏到关系与选择，读懂属于你的运程。",
    catalog: "运程解析目录", catalogHint: "基础信息、运程摘要与个人特点免费查看；七大运程主题及行动建议解锁后阅读。",
    chapterCount: "三项免费内容 · 七大解锁主题", takeaway: "先看你的运程主线",
    offerTitle: "解锁你的七大运程解析", offerText: "继续查看年度运程、整体运程、格局解读、婚姻情感、财运事业、风险提醒与姻缘，每一项都结合本次排盘给出分析和建议。",
    benefits: ["年度节奏与人生主线", "优势格局与财运事业", "婚姻情感与姻缘倾向", "风险提醒与具体行动"],
    unlock: "解锁完整运程解析", full: "完整运程解析已解锁", progress: "正在整理完整运程解析", done: "完整运程解析已生成",
    once: "七大主题一次解锁 · 对应本次出生资料与年份",
  },
  th: {
    title: "วิเคราะห์ดวงชะตา", subtitle: "เข้าใจจังหวะชีวิต ความสัมพันธ์ และทางเลือกจากข้อมูลเกิดของคุณ",
    catalog: "หัวข้อวิเคราะห์ดวง", catalogHint: "ข้อมูลพื้นฐาน สรุป และลักษณะส่วนตัวอ่านฟรี เปิดฉบับเต็มเพื่ออ่านเจ็ดหัวข้อพร้อมคำแนะนำ",
    chapterCount: "สามส่วนอ่านฟรี · เจ็ดหัวข้อฉบับเต็ม", takeaway: "เริ่มจากแนวโน้มสำคัญของคุณ",
    offerTitle: "เปิดอ่านดวงครบเจ็ดหัวข้อ", offerText: "อ่านดวงรายปี ภาพรวมชีวิต โครงสร้างพื้นดวง ชีวิตคู่ การเงินและการงาน ข้อควรระวัง และคู่ครอง พร้อมแนวทางจากข้อมูลเกิดครั้งนี้",
    benefits: ["จังหวะรายปีและภาพรวมชีวิต", "จุดแข็ง การเงิน และการงาน", "ชีวิตคู่และการพบรัก", "ข้อควรระวังและสิ่งที่ลองทำได้"],
    unlock: "เปิดคำอ่านดวงฉบับเต็ม", full: "เปิดคำอ่านดวงฉบับเต็มแล้ว", progress: "กำลังจัดทำคำอ่านฉบับเต็ม", done: "จัดทำคำอ่านดวงฉบับเต็มแล้ว",
    once: "เปิดเจ็ดหัวข้อในครั้งเดียว · สำหรับข้อมูลเกิดและปีที่เลือก",
  },
};
