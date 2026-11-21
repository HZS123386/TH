import { describe, expect, it } from "vitest";
import { additionalLocales, english, languages, type Language } from "./locales";
import { inputFor, reportFixture } from "../../tests/fixtures/lifeReport";
import { isLifeReport, lifeLabels, westernTopicKeys } from "./lifeReport";
import { reportContent } from "./reportContent";
import { reportHtml } from "./reading";
import original from "../content/jy.json";

function paths(value: unknown, prefix = ""): string[] {
  if (Array.isArray(value)) return value.flatMap((item, index) => paths(item, `${prefix}[${index}]`));
  if (value && typeof value === "object") return Object.entries(value).flatMap(([key, item]) => paths(item, `${prefix}.${key}`));
  return [prefix];
}

describe("complete, distinct landing languages", () => {
  it("offers nine distinct languages with one English entry", () => {
    expect(languages).toEqual(["th", "en", "zh", "vi", "my", "km", "lo", "ms", "id"]);
    expect(new Set(languages).size).toBe(9);
  });
  for (const [code, copy] of Object.entries(additionalLocales)) {
    const language = code as Language;
    it(`covers the existing landing page and exports a gated Western report in ${language}`, () => {
      // The quick privacy summary ships in the original campaign languages.
      // The full policy is tested separately in all nine languages.
      const required = paths(original.jy.zh).filter(path =>
        ![".welcome.guideName", ".welcome.guideTitle"].includes(path) && !path.startsWith(".privacyDetails[")
      );
      expect(paths(copy.jy)).toEqual(expect.arrayContaining(required));
      expect(paths(copy)).toEqual(paths(english));
      expect(JSON.stringify(copy)).not.toMatch(/[\u3400-\u9fff\u0e00-\u0e7f]/u);
      const report = reportFixture({ ...inputFor(language), report_kind: "fortune" }, true);
      report.format = "western-compact";
      report.price = { amount: 3000, currency: "THB", display: "฿30", mode: "sunlands_order_only" };
      report.method = { name: "RoxyAPI Western Astrology", house_system: "placidus", version: "v2" };
      report.catalog = westernTopicKeys.map((key, index) => ({ ...report.catalog[index], key, title: copy.jy.report.westernSections[key] }));
      report.chapters = westernTopicKeys.map((key, index) => ({ ...report.chapters[index], key, title: copy.jy.report.westernSections[key] }));
      report.progress = { completed: 6, total: 6 };
      report.generation_progress = { percent: 100, sections: [...westernTopicKeys, "plan" as const].map(key => ({ key, percent: 100 })) };
      const secret = `${copy.life.fullVersion} — private test content ${language}`;
      report.chapters[0].insights[0].text = secret;
      expect(isLifeReport(report)).toBe(true);
      expect(lifeLabels(report).methodValue).toBe(copy.jy.chart.western);
      expect(reportContent(report).filter(section => section.paid)).toHaveLength(6);
      const html = reportHtml(report, lifeLabels(report));
      expect(html).not.toContain(copy.jy.chart.western);
      expect(html).toContain(copy.jy.report.westernSections.plan);
      expect(html).toContain(secret);
      expect(html).not.toContain("Suriyayatra");
      report.access = "preview";
      expect(reportHtml(report, lifeLabels(report))).not.toContain(secret);
    });
  }
});
