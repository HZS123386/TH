import type { LifeLabels, LifePoint, LifeReport, LifeSummary, ReportTopic } from "./lifeReport";
import { fortuneTopics, fortuneTopicTitle, type FortuneTopicKey } from "./fortuneTopics";

export type ReportSectionKey = "basics" | "summary" | "traits" | "work" | "money" | "relationships" | "recent" | "advice" | FortuneTopicKey;
export interface ReportEntry { point: LifePoint; id?: string }
export interface ReportGroup { title: string; entries: ReportEntry[] }
export interface ReportSection {
  key: ReportSectionKey;
  title: string;
  description: string;
  paid: boolean;
  ready: boolean;
  summaries: LifeSummary[];
  groups: ReportGroup[];
}

const copy = {
  zh: {
    sections: [
      ["basics", "基础信息", "称呼、解读方式与参考时间范围"],
      ["summary", "报告摘要", "主要结论与关注重点"],
      ["traits", "个人特点", "性格、优势与改进方向"],
      ["work", "事业发展", "工作风格与发展建议"],
      ["money", "财务方面", "金钱态度与规划参考"],
      ["relationships", "感情与家庭", "关系需求与沟通建议"],
      ["recent", "近期关注", "近期主题与行动参考"],
      ["advice", "总结建议", "优先事项与具体行动"],
    ],
    groups: { work: ["工作风格", "发展建议"], money: ["金钱态度", "规划参考"], love: ["关系需求", "相处与沟通建议"], family: ["家庭中的需要与责任", "家庭沟通建议"], annual: ["近期关注的主题", "行动参考"] },
  },
  th: {
    sections: [
      ["basics", "ข้อมูลพื้นฐาน", "ชื่อ วิธีการอ่าน และช่วงเวลาที่ใช้อ้างอิง"],
      ["summary", "สรุปรายงาน", "ข้อสรุปหลักและสิ่งที่ควรให้ความสำคัญ"],
      ["traits", "ลักษณะส่วนตัว", "นิสัย จุดแข็ง และสิ่งที่ค่อย ๆ ปรับได้"],
      ["work", "การงานและการเติบโต", "รูปแบบการทำงานและแนวทางพัฒนา"],
      ["money", "การเงิน", "ทัศนคติต่อเงินและแนวทางวางแผน"],
      ["relationships", "ความสัมพันธ์และครอบครัว", "ความต้องการและแนวทางสื่อสาร"],
      ["recent", "เรื่องที่ควรใส่ใจช่วงนี้", "ประเด็นและแนวทางลงมือทำ"],
      ["advice", "ข้อเสนอแนะโดยรวม", "สิ่งสำคัญและการลงมือทำอย่างเป็นรูปธรรม"],
    ],
    groups: { work: ["รูปแบบการทำงาน", "แนวทางพัฒนา"], money: ["ทัศนคติต่อเงิน", "แนวทางวางแผน"], love: ["ความต้องการในความสัมพันธ์", "แนวทางพูดคุยและอยู่ร่วมกัน"], family: ["ความต้องการและหน้าที่ในครอบครัว", "แนวทางสื่อสารกับครอบครัว"], annual: ["ประเด็นที่ควรใส่ใจช่วงนี้", "แนวทางลงมือทำ"] },
  },
} as const;

// One outline is shared by the screen, saved HTML and PDF. Paid data is gated here too.
export function reportContent(report: LifeReport): ReportSection[] {
  const language = report.input.profile.language;
  const labels = copy[language];
  const chapters = new Map((report.access === "full" ? report.chapters : []).map(chapter => [chapter.key, chapter]));
  if (report.input.career) {
    const work = chapters.get("work");
    const title = report.catalog[0].title;
    const sections: ReportSection[] = [
      { key: "basics", title: labels.sections[0][1], description: labels.sections[0][2], ready: true, paid: false, summaries: [], groups: [] },
      { key: "summary", title: language === "zh" ? "眼下先怎么做" : "ตอนนี้ควรทำอะไรก่อน", description: language === "zh" ? "近期行运的简要回答" : "คำอ่านดาวจรช่วงนี้", ready: !!report.preview, paid: false, summaries: [], groups: [] },
      { key: "traits", title: language === "zh" ? "留下、换走与眼下的第一步" : "อยู่ต่อ เปลี่ยนงาน และสิ่งที่เริ่มทำได้ตอนนี้", description: language === "zh" ? "两条路各值得留意什么" : "สิ่งที่ควรใส่ใจในแต่ละทาง", ready: !!report.preview, paid: false, summaries: [], groups: [] },
      { key: "work", title, description: report.catalog[0].questions.join(" · "), ready: !!work, paid: true,
        summaries: [], groups: work ? [{ title: language === "zh" ? "日期与具体行动" : "ช่วงเวลาและสิ่งที่ทำได้", entries: work.insights.map(point => ({ point })) }] : [] },
    ];
    return sections;
  }
  const groupFor = (reading: ReportTopic, titles: readonly string[]): ReportGroup[] => {
    const chapter = chapters.get(reading);
    if (!chapter) return [];
    return [
      { title: titles[0], entries: chapter.insights.map(point => ({ point })) },
      { title: titles[1], entries: [
        ...chapter.watchpoints.map(point => ({ point })),
        ...chapter.actions.map((point, index) => ({ point, id: `life-action-${reading}-${index}` })),
      ] },
    ];
  };
  if (report.input.report_kind === "fortune") {
    const free: ReportSection[] = labels.sections.slice(0, 3).map(([key, title, description]) => ({
      key, title: key === "summary" ? language === "zh" ? "运程摘要" : "สรุปแนวโน้มชีวิต" : title,
      description, paid: false, ready: key === "basics" || !!report.preview, summaries: [], groups: [],
    }));
    const paid: ReportSection[] = fortuneTopics.map(topic => {
      const chapter = chapters.get(topic.key);
      return { key: topic.key, title: fortuneTopicTitle(topic.key, language, report.input.year),
        description: topic[language].questions.join(" · "), paid: true, ready: !!chapter,
        summaries: chapter ? [chapter.summary] : [], groups: groupFor(topic.key, topic[language].groups) };
    });
    return [...free, ...paid, { key: "advice", title: labels.sections[7][1], description: labels.sections[7][2],
      paid: true, ready: report.access === "full" && !!report.plan, summaries: [], groups: [] }];
  }
  return labels.sections.map(([key, title, description], index) => {
    const section: ReportSection = { key, title, description, paid: index >= 3, ready: false, summaries: [], groups: [] };
    if (key === "basics") section.ready = true;
    if (key === "summary" || key === "traits") section.ready = !!report.preview;
    if (key === "work" || key === "money") {
      section.ready = chapters.has(key);
      section.groups = groupFor(key, labels.groups[key]);
      if (chapters.has(key)) section.summaries = [chapters.get(key)!.summary];
    }
    if (key === "relationships") {
      section.ready = chapters.has("love") && chapters.has("family");
      section.groups = [...groupFor("love", labels.groups.love), ...groupFor("family", labels.groups.family)];
      section.summaries = [chapters.get("love")?.summary, chapters.get("family")?.summary].filter((item): item is LifeSummary => !!item);
    }
    if (key === "recent") {
      section.ready = chapters.has("annual");
      section.groups = groupFor("annual", labels.groups.annual);
      if (chapters.has("annual")) section.summaries = [chapters.get("annual")!.summary];
    }
    if (key === "advice") section.ready = report.access === "full" && !!report.plan;
    return section;
  });
}

export function reportReference(report: LifeReport, labels: LifeLabels): string {
  const period = report.reference_period;
  return period ? `${period.start} – ${period.end}` : `${report.input.year} · ${labels.yearReference}`;
}
