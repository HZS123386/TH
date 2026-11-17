import { describe, expect, it } from "vitest";
import { inputFor, reportFixture } from "../../tests/fixtures/lifeReport";
import { hasLifePreview, isLifeReport, lifeLabels, personalTopicKeys, previewGenerationProgress, reportGenerationProgress, type LifeReport } from "./lifeReport";
import { reportContent } from "./reportContent";
import { reportHtml } from "./reading";
import { languages } from "./locales";
import { additionalLocales } from "./locales";
import copy from "../content/jy.json";

function personalFixture(language: typeof languages[number] = "zh", full = false): LifeReport {
  const report = reportFixture(inputFor(language));
  return { ...report, format: "western-personal", preview: null, chapters: [], plan: null,
    preview_state: "ready", full_state: full ? "ready" : "not_started", access: full ? "full" : "preview",
    progress: { completed: full ? 4 : 0, total: 4 }, generation_progress: undefined,
    catalog: personalTopicKeys.map(key => ({ key, title: key, questions: [], houses: [], ready: full })),
    personal: { free_lines: ["Synthetic free line one.", "Synthetic free line two.", "Synthetic free line three."], sun_sign: "Cancer", ascendant_sign: "Leo",
      traits: [0,1,2].map(i => ({ title: `Personal trait ${i}`, text: `Everyday behavior ${i}.` })),
      opportunity_action: "Prepare one example to share.",
      availability: { full_report: true, reason: "ready" },
      talent: full ? { text: "PRIVATE_TALENT", directions: [0,1,2].map(i => ({ title: `Direction ${i}`, text: `PRIVATE_DIRECTION_${i}` })) } : null,
      nodes: full ? [1,2,3].map(i => ({ month: `2027-0${i}`, theme: `PRIVATE_THEME_${i}`, benefit: `PRIVATE_BENEFIT_${i}`, caution: `PRIVATE_CAUTION_${i}`, action: `PRIVATE_ACTION_${i}`, evidence: [] })) : [],
    },
  };
}

describe("personal Western report contract and export", () => {
  for (const language of languages) {
    it(`shows three distinct free areas and isolates four paid blocks in ${language}`, () => {
      const report = personalFixture(language, true);
      expect(isLifeReport(report)).toBe(true);
      expect(hasLifePreview(report)).toBe(true);
      expect(previewGenerationProgress(report).phase).toBe("ready");
      expect(reportGenerationProgress(report).percent).toBe(100);
      expect(reportContent(report).filter(section => section.paid).map(section => section.key)).toEqual(personalTopicKeys);
      const full = reportHtml(report, lifeLabels(report));
      expect(full).toContain("PRIVATE_TALENT");
      expect(full).toContain("PRIVATE_THEME_3");
      expect(full).not.toContain(report.input.profile.birth_date);
      expect(full).not.toContain(report.input.profile.birthplace);
      report.access = "preview";
      const free = reportHtml(report, lifeLabels(report));
      const labels = language === 'zh' || language === 'th' ? copy.jy[language].personal : additionalLocales[language].jy.personal;
      expect(free.match(/class="personal-free-line"/gu)).toHaveLength(2);
      expect(free).toContain('class="personal-signs"');
      expect(free).toContain('Cancer');
      expect(free).toContain('Leo');
      for (const key of ['keywords', 'traits', 'opportunity'] as const) expect(free).toContain(`<h3>${labels[key]}</h3>`);
      expect(free).not.toContain(report.personal!.free_lines[0]);
      for (const line of report.personal!.free_lines.slice(1)) expect(free.split(line)).toHaveLength(2);
      for (const [index, trait] of report.personal!.traits!.entries()) {
        expect(free.split(trait.title)).toHaveLength(index < 2 ? 3 : 2);
        expect(free.split(trait.text)).toHaveLength(2);
      }
      expect(free.split(report.personal!.opportunity_action!)).toHaveLength(2);
      expect(free).not.toContain('RoxyAPI');
      expect(free).not.toContain('Placidus');
      expect(free).not.toContain(report.method.version);
      expect(free).not.toContain(report.version);
      expect(full).not.toContain('RoxyAPI');
      expect(full).not.toContain('Placidus');
      expect(free).not.toContain("PRIVATE_");
      expect(free).not.toContain("2027-01");
      expect(free).not.toContain("<details>");
      expect(free).not.toContain(report.input.profile.birth_date);
    });
  }
  it("preserves saved three-line previews and escapes new free details in exports", () => {
    const report = personalFixture();
    report.personal!.traits![0].title = 'Clear <expression>';
    report.personal!.opportunity_action = 'Prepare <one> example & share.';
    const html = reportHtml(report, lifeLabels(report));
    expect(html).toContain('Clear &lt;expression&gt;');
    expect(html).toContain('Prepare &lt;one&gt; example &amp; share.');
    delete report.personal!.traits;
    delete report.personal!.opportunity_action;
    expect(isLifeReport(report)).toBe(true);
    expect(reportHtml(report, lifeLabels(report)).match(/class="personal-free-line"/gu)).toHaveLength(3);
    report.personal!.traits = [{ title: 'Incomplete', text: '' }];
    expect(isLifeReport(report)).toBe(false);
  });
  it("rejects incomplete full personal content and fabricated unknown-time ascendant", () => {
    const report = personalFixture('zh', true);
    report.personal!.nodes.pop();
    expect(isLifeReport(report)).toBe(false);
    report.access = 'preview';
    report.input.profile.birth_time = null;
    expect(isLifeReport(report)).toBe(false);
    report.personal!.ascendant_sign = null;
    report.personal!.availability = { full_report: false, reason: 'time_unknown' };
    expect(isLifeReport(report)).toBe(true);
    expect(hasLifePreview(report)).toBe(true);
    const malformed = personalFixture('zh', true);
    malformed.personal!.talent!.text = 42 as unknown as string;
    expect(isLifeReport(malformed)).toBe(false);
  });
  it("accepts the initial generation state without manufacturing legacy preview fields", () => {
    const report = personalFixture();
    report.preview_state = 'generating';
    report.personal!.free_lines = [];
    expect(isLifeReport(report)).toBe(true);
    expect(previewGenerationProgress(report).percent).toBe(0);
    expect(hasLifePreview(report)).toBe(false);
  });
});
