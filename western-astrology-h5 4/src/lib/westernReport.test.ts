import { describe, expect, it } from "vitest";
import { inputFor, reportFixture } from "../../tests/fixtures/lifeReport";
import { isLifeReport, lifeLabels, westernTopicKeys, type LifeReport } from "./lifeReport";
import { previewIdentity, previewParagraphs, reportContent, reportReference } from "./reportContent";
import { reportHtml } from "./reading";
import copy from "../content/jy.json";

function westernFixture(language: "zh" | "th"): LifeReport {
  const report = reportFixture({ ...inputFor(language), report_kind: "fortune" }, true);
  report.format = "western-compact";
  report.method = { name: "RoxyAPI Western Astrology", house_system: "placidus", version: "v2" };
  const titles = copy.jy[language].report.westernSections;
  report.catalog = westernTopicKeys.map((key, index) => ({ ...report.catalog[index], key, title: titles[key] }));
  report.chapters = westernTopicKeys.map((key, index) => ({ ...report.chapters[index], key, title: titles[key] }));
  report.progress = { completed: 6, total: 6 };
  report.generation_progress = { percent: 100, sections: [...westernTopicKeys, "plan" as const].map(key => ({ key, percent: 100 })) };
  return report;
}

describe("Western report sections and exported source", () => {
  for (const language of ["zh", "th"] as const) {
    it(`includes all six unlocked sections with the Western source in ${language}`, () => {
      const report = westernFixture(language);
      expect(isLifeReport(report)).toBe(true);
      const sections = reportContent(report).filter(section => section.paid);
      expect(sections).toHaveLength(6);
      expect(sections.map(section => section.title)).toEqual(Object.values(copy.jy[language].report.westernSections));
      const labels = lifeLabels(report), html = reportHtml(report, labels);
      for (const section of sections) expect(html).toContain(`<h2>${section.title}</h2>`);
      expect(html).not.toContain(copy.jy[language].chart.western);
      expect(html).not.toContain("Suriyayatra");
      expect(reportReference(report, labels)).not.toContain(String(report.input.year));
    });

    it(`keeps paid body text out of a free export in ${language}`, () => {
      const report = westernFixture(language);
      report.access = "preview";
      const sections = reportContent(report).filter(section => section.paid);
      expect(sections.every(section => !section.ready && !section.groups.length)).toBe(true);
      const html = reportHtml(report, lifeLabels(report));
      expect(html).not.toContain(language === "zh" ? "付费专属分析正文" : "เนื้อหาฉบับเต็มสำหรับทดสอบ");
    });

    it(`exports identity as one paragraph with all unique evidence in ${language}`, () => {
      const report = westernFixture(language);
      report.access = "preview";
      const preview = report.preview!;
      const texts = language === "zh"
        ? ["你习惯先理清自己的感受。", "遇到选择时，你愿意先看清方向。", "面对变化，也会给自己留一点调整空间。", "在关系中，你更看重彼此愿意表达。"]
        : ["คุณมักอยากเข้าใจความรู้สึกของตัวเองก่อน", "เมื่อมีทางเลือก คุณอาจอยากมองทิศทางให้ชัด", "เมื่อสิ่งต่าง ๆ เปลี่ยนไป คุณยังเผื่อพื้นที่ให้ปรับตัว", "ในความสัมพันธ์ คุณให้ความสำคัญกับการพูดคุยกัน"];
      preview.summary.text = `  ${texts[0]}\n`;
      const shared = preview.summary.evidence[0];
      preview.summary.evidence = [shared];
      preview.traits.forEach((trait, index) => {
        trait.text = texts[index + 1];
        trait.evidence = [shared, { id: `identity-${trait.key}`, title: `identity source ${index}`, detail: `verified detail ${index}` }];
      });
      const original = JSON.stringify(preview);
      const expected = texts.join(language === "zh" ? "" : " ");
      const merged = previewIdentity(report)!;
      expect(merged.text).toBe(expected);
      expect(merged.evidence.map(fact => fact.id)).toEqual([shared.id, ...preview.traits.map(trait => `identity-${trait.key}`)]);
      const html = reportHtml(report, lifeLabels(report));
      const who = html.split(`<h2>${copy.jy[language].report.previewParagraphs.identity}</h2>`)[1].split("</section>")[0];
      expect(who).toContain(`<p class="takeaway">${expected}</p>`);
      expect(who.match(/<p class="takeaway">/gu)).toHaveLength(1);
      expect(who).not.toContain("<article>");
      expect(who).not.toContain("<h4>");
      for (const fact of merged.evidence) {
        expect(who).toContain(fact.title);
        expect(who).toContain(fact.detail);
      }
      expect(JSON.stringify(preview)).toBe(original);
      // A repeated legacy paragraph is shown once without losing its distinct supporting facts.
      preview.traits[1].text = `\n${preview.traits[0].text}  `;
      expect(previewIdentity(report)!.text).toBe([texts[0], texts[1], texts[3]].join(language === "zh" ? "" : " "));
      expect(previewIdentity(report)!.evidence).toEqual(merged.evidence);
    });
  }

  it("rejects an incomplete Western catalog or legacy progress keys", () => {
    const report = westernFixture("zh");
    report.catalog.pop();
    expect(isLifeReport(report)).toBe(false);
    const stale = westernFixture("zh");
    stale.generation_progress!.sections[0].key = "annual";
    expect(isLifeReport(stale)).toBe(false);
  });

  it("exports three complete paragraphs with grounded influences, the actual window and one free career response", () => {
    const report = westernFixture("zh");
    report.access = "preview";
    const summary = report.preview!.summary;
    const answer = (key: string, text: string) => ({ ...summary, text, evidence: [{ id: key, title: `source ${key}`, detail: `detail ${key}` }] });
    const actualWindow = { start: "2026-11-16", end: "2026-11-22", event_date: "2026-11-18", timezone: "UTC" };
    report.preview = { ...report.preview!, environment: answer('environment', '我的环境基础答案'),
      favorable: answer('favorable', '一个有利因素与依据'), unfavorable: answer('unfavorable', '一个需要留意的因素与依据'),
      recent: { ...answer('recent', '近期主题与初步趋势'), window: actualWindow },
      response: answer('response', '一条免费事业应对建议'), sample_topic: "career" };
    report.outlook = { state: "ready", start: "2026-11-16", end: "2027-02-13", timezone: "UTC" };
    const original = JSON.stringify(report);
    const paragraphs = previewParagraphs(report);
    expect(paragraphs.map(part => part.key)).toEqual(['identity', 'environment', 'recent']);
    expect(paragraphs[1].text).toContain(copy.jy.zh.report.questions.favorable + '：一个有利因素与依据');
    expect(paragraphs[1].text).toContain(copy.jy.zh.report.questions.unfavorable + '：一个需要留意的因素与依据');
    expect(paragraphs[1].evidence.map(fact => fact.id)).toEqual(['environment', 'favorable', 'unfavorable']);
    expect(paragraphs[2].window).toEqual(actualWindow);
    expect(paragraphs[2].text).toContain(copy.jy.zh.report.questions.freePeriod);
    expect(paragraphs[2].text).toContain(copy.jy.zh.report.questions.timingNote);
    expect(paragraphs[2].evidence.map(fact => fact.id)).toEqual(['recent', 'response']);
    const html = reportHtml(report, lifeLabels(report));
    for (const key of ['who','environment','influence','timing'] as const) expect(html).not.toContain(copy.jy.zh.report.questions[key]);
    for (const part of paragraphs) {
      expect(html).toContain(`<h2>${part.title}</h2>`);
      expect(html).toContain(`<p class="takeaway">${part.text}</p>`);
    }
    expect(html).toContain('我的环境基础答案');
    expect(html).toContain('一条免费事业应对建议');
    expect(html).toContain('2026-11-18');
    expect(html).toContain('Asia/Bangkok');
    expect(html).not.toContain('付费专属分析正文');
    expect(reportContent(report).filter(section => !section.paid).map(section => section.key)).toEqual(['basics','summary','environment','recent']);
    expect(JSON.stringify(report)).toBe(original);
  });

  it("shows one missing-content explanation per affected historical paragraph", () => {
    const report = westernFixture('zh');
    report.access = 'preview';
    report.preview!.response = { ...report.preview!.summary, text: '一条仍可使用的建议' };
    const paragraphs = previewParagraphs(report);
    expect(paragraphs[1].text).toBe(copy.jy.zh.report.previewParagraphs.legacyEnvironment);
    expect(paragraphs[2].text).toContain(copy.jy.zh.report.previewParagraphs.legacyRecent);
    expect(paragraphs[2].text).not.toContain('一条仍可使用的建议');
    expect(paragraphs[2].text).not.toContain(copy.jy.zh.report.questions.timingNote);
    expect(paragraphs[2].window).toBeUndefined();
    report.preview!.environment = { ...report.preview!.summary, text: '已保存的环境解读' };
    const partial = previewParagraphs(report)[1];
    expect(partial.text).toContain('已保存的环境解读');
    expect(partial.text.split(copy.jy.zh.report.previewParagraphs.legacyEnvironment)).toHaveLength(2);
    report.preview!.favorable = { ...report.preview!.summary, text: '  ' };
    report.preview!.unfavorable = { ...report.preview!.summary, text: '' };
    report.preview!.response = { ...report.preview!.summary, text: '\n' };
    const empty = previewParagraphs(report);
    expect(empty[1].text).not.toContain(copy.jy.zh.report.questions.favorable + '：');
    expect(empty[1].text).not.toContain(copy.jy.zh.report.questions.unfavorable + '：');
    expect(empty[2].text).not.toContain(copy.jy.zh.report.questions.freeResponse);
    expect(empty[2].evidence).toEqual([]);
    const legacyHtml = reportHtml(report, lifeLabels(report));
    expect(legacyHtml).not.toContain(copy.jy.zh.report.questions.legacy);
    expect(legacyHtml).not.toContain(copy.jy.zh.report.questions.timingNote);
  });

  for (const condition of ['unknown', 'unavailable', 'missing-window', 'empty-text', 'empty'] as const) {
    it(`keeps ${condition} timing explicit without inventing dates or retaining timing evidence`, () => {
      const report = westernFixture('zh');
      report.access = 'preview';
      const p = report.preview!;
      const timing = { ...p.summary, text: '不应显示的时段结论', evidence: [{ id: 'timing-only', title: 'unsupported time source', detail: 'not displayed' }],
        window: { start: '2026-11-16', end: '2026-11-22', event_date: '2026-11-18', timezone: 'UTC' } };
      report.preview!.recent = timing;
      report.preview!.response = { ...p.summary, text: '可在日常尝试的小建议', evidence: [{ id: 'response-only', title: 'natal advice', detail: 'verified advice source' }] };
      report.outlook = { state: condition === 'unavailable' ? 'unavailable' : 'ready' };
      if (condition === 'unknown') report.input.profile.birth_time = null;
      if (condition === 'missing-window') delete report.preview!.recent!.window;
      if (condition === 'empty-text') report.preview!.recent!.text = '  \n';
      if (condition === 'empty') delete report.preview!.recent;
      const paragraph = previewParagraphs(report)[2];
      expect(paragraph.window).toBeUndefined();
      expect(paragraph.text).not.toContain('不应显示的时段结论');
      expect(paragraph.text).not.toContain(copy.jy.zh.report.questions.timingNote);
      expect(paragraph.evidence).toEqual([]);
      expect(paragraph.text).not.toContain('可在日常尝试的小建议');
      expect(paragraph.text).toContain(condition === 'unknown' ? copy.jy.zh.report.questions.timeUnknown : condition === 'unavailable' ? copy.jy.zh.report.questions.unavailable : copy.jy.zh.report.questions.empty);
      const html = reportHtml(report, lifeLabels(report));
      expect(html).not.toContain('2026-11-18');
      expect(html).not.toContain('unsupported time source');
    });
  }

  it("preserves all complete prose and sources in a long saved Chinese preview without shortening it", () => {
    const report = westernFixture("zh");
    report.access = "preview";
    const p = report.preview!;
    const texts = [
      "你习惯先观察环境，再决定自己愿意投入多少。遇到新的安排，你会希望先看清它与你日常生活的关系，再留出适合自己的步调。",
      "安稳的节奏让你更能专注，也让你的耐心有机会变成实际成果。对你而言，把一件小事做得细致而舒服，往往比仓促完成很多事情更能获得满足。",
      "面对选择时，你往往愿意把不同方案的价值想清楚，再给出自己的判断。如果需要马上答复，你可以先问清最关键的条件，给后续的调整留一点空间。",
      "在人际交往中，你更希望彼此能够坦诚表达，也愿意给不同的步调留出空间。当双方暂时没有说到一起，你通常会先观察对方的感受，再尝试找到更舒服的说法。",
    ];
    p.summary.text = texts[0];
    p.traits.forEach((trait, index) => { trait.text = texts[index + 1]; });
    const original = JSON.stringify(p);
    const merged = previewIdentity(report)!;
    expect(merged.text).toBe(texts.join(''));
    expect(merged.text).not.toMatch(/[，,；;…]$/u);
    expect(merged.text).not.toContain('\n');
    expect(merged.evidence.length).toBeGreaterThan(0);
    expect(JSON.stringify(p)).toBe(original);
  });

  it("preserves complete Thai text and spaces between word groups", () => {
    const report = westernFixture("th");
    const p = report.preview!;
    const text = "คุณอาจต้องการเวลา เพื่อทำความเข้าใจความรู้สึกของตัวเอง ก่อนตัดสินใจรับสิ่งใหม่เข้ามา คุณให้ความสำคัญกับความสบายใจ และพื้นที่ที่ได้เป็นตัวเอง โดยยังพร้อมรับฟังความคิดเห็นที่แตกต่าง เมื่อได้พูดคุยอย่างตรงไปตรงมา คุณจะเห็นทางเลือกชัดเจนขึ้น และปรับจังหวะให้เหมาะกับตัวเองได้";
    p.summary.text = text;
    p.traits.forEach((trait, index) => { trait.text = text.replace('คุณอาจ', `ในด้านที่${index + 1} คุณอาจ`); });
    const merged = previewIdentity(report)!;
    expect(merged.text).toBe([p.summary.text, ...p.traits.map(trait => trait.text)].join(' '));
    expect(merged.text).toContain('คุณอาจต้องการเวลา เพื่อทำความเข้าใจความรู้สึกของตัวเอง');
    expect(merged.text).not.toContain('คุณอาจต้องการเวลาเพื่อทำความเข้าใจ');
  });

  it("keeps a dependent opening with its main clause instead of ending the excerpt halfway", () => {
    const report = westernFixture("zh");
    const p = report.preview!;
    p.summary.text = "无论是令人放松的一顿美食还是整洁有序的生活空间，都能让你在平凡日子里找到一种踏实感。适当接纳不同的体验，也能让生活保有新鲜感。";
    p.traits.forEach((trait, index) => {
      trait.text = `你在第${index + 1}种情境中仍然希望给自己留出思考空间，也愿意听听不同的意见。遇到不能马上确定的事情，你会先从较小的选择开始尝试，再根据实际感受调整自己的安排。`;
    });
    const merged = previewIdentity(report)!;
    expect(merged.text).toContain('生活空间，都能让你在平凡日子里找到一种踏实感。');
    expect(merged.text).not.toContain('生活空间。');
    expect(merged.text).not.toContain('…');
  });

  it("keeps a dependent clause after a colon together with its main clause", () => {
    const report = westernFixture("zh");
    const p = report.preview!;
    p.summary.text = "你更愿意在安稳的节奏里看清自己的感受，再决定哪些事情值得认真投入。遇到生活里的新变化，你也会给自己留下逐步适应的空间。";
    p.traits[0].text = "这种对质感的重视，也体现在生活里的小事上：无论是美食还是整洁的空间，都能为你补充精力。你能够从具体而细微的体验里找到满足，让平常的日子多一点生机。";
    p.traits.slice(1).forEach((trait, index) => {
      trait.text = `你在第${index + 1}种情境中仍然希望给自己留出思考空间，也愿意听听不同的意见。遇到不能马上确定的事情，你会先从较小的选择开始尝试，再根据实际感受调整自己的安排。`;
    });
    const merged = previewIdentity(report)!;
    expect(merged.text).toContain('无论是美食还是整洁的空间，都能为你补充精力。');
    expect(merged.text).not.toContain('无论是美食还是整洁的空间。');
  });
});
