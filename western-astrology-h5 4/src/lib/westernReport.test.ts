import { describe, expect, it } from "vitest";
import { inputFor, reportFixture } from "../../tests/fixtures/lifeReport";
import { isLifeReport, lifeLabels, westernTopicKeys, type LifeReport } from "./lifeReport";
import { reportContent, reportReference } from "./reportContent";
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
      expect(html).toContain("RoxyAPI Western Astrology · Placidus");
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
  }

  it("rejects an incomplete Western catalog or legacy progress keys", () => {
    const report = westernFixture("zh");
    report.catalog.pop();
    expect(isLifeReport(report)).toBe(false);
    const stale = westernFixture("zh");
    stale.generation_progress!.sections[0].key = "annual";
    expect(isLifeReport(stale)).toBe(false);
  });
});
