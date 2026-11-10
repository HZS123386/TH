import { describe, expect, it } from "vitest";
import { inputFor, reportFixture } from "../../tests/fixtures/lifeReport";
import { isLifeReport, lifeLabels, type LifeReport } from "./lifeReport";
import { fortuneTopics, fortuneTopicTitle } from "./fortuneTopics";
import { reportContent } from "./reportContent";
import { reportHtml } from "./reading";

describe("fortune report outline and export permissions", () => {
  for (const language of ["zh", "th"] as const) {
    it(`keeps all seven paid subjects out of the free export in ${language}`, () => {
      const input = { ...inputFor(language), report_kind: "fortune" as const, year: 2027 };
      const report = reportFixture(input, true);
      report.access = "preview";
      expect(isLifeReport(report)).toBe(true);
      const sections = reportContent(report);
      expect(sections.filter(section => !section.paid)).toHaveLength(3);
      expect(sections.filter(section => section.paid && section.key !== "advice")).toHaveLength(7);
      expect(sections.filter(section => section.paid).every(section => !section.ready && !section.groups.length && !section.summaries.length)).toBe(true);
      const html = reportHtml(report, lifeLabels(report));
      for (const topic of fortuneTopics) expect(sections.map(section => section.title)).toContain(fortuneTopicTitle(topic.key, language, 2027));
      expect(html).not.toContain(`<h2>${fortuneTopicTitle("annual", language, 2027)}</h2>`);
      expect(html).not.toContain(language === "zh" ? "付费专属分析正文" : "เนื้อหาฉบับเต็มสำหรับทดสอบ");
    });

    it(`exports all seven unlocked subjects and the actual advice section in ${language}`, () => {
      const report = reportFixture({ ...inputFor(language), report_kind: "fortune", year: 2027 }, true);
      const sections = reportContent(report);
      expect(sections).toHaveLength(11);
      expect(sections.filter(section => section.groups.length).map(section => section.key)).toEqual(["annual", "overall", "pattern", "marriage", "wealth", "risk", "romance"]);
      const html = reportHtml(report, lifeLabels(report));
      expect(html).toContain(language === "zh" ? "付费专属分析正文" : "เนื้อหาฉบับเต็มสำหรับทดสอบ");
      expect(html).toContain(`<h2>${sections.find(section => section.key === "advice")!.title}</h2>`);
      for (const topic of fortuneTopics) expect(html).toContain(fortuneTopicTitle(topic.key, language, 2027));
    });
  }

  it("reads saved five-topic reports separately and rejects an incomplete new catalog", () => {
    const legacy = reportFixture(inputFor(), true);
    expect(isLifeReport(legacy)).toBe(true);
    expect(reportContent(legacy)).toHaveLength(8);
    const malformed: LifeReport = { ...legacy, input: { ...legacy.input, report_kind: "fortune" } };
    expect(isLifeReport(malformed)).toBe(false);
  });
});
