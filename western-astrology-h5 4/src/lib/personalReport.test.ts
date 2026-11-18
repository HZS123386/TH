import { describe, expect, it } from "vitest";
import { inputFor, reportFixture } from "../../tests/fixtures/lifeReport";
import { hasLifePreview, isLifeReport, lifeLabels, personalTopicKeys, legacyPersonalTopicKeys, previewGenerationProgress, reportGenerationProgress, type LifeReport } from "./lifeReport";
import { reportContent } from "./reportContent";
import { reportHtml } from "./reading";
import { languages } from "./locales";
import { additionalLocales } from "./locales";
import copy from "../content/jy.json";

function personalFixture(language: typeof languages[number] = "zh", full = false): LifeReport {
  const report = reportFixture(inputFor(language));
  return { ...report, format: "western-personal", version: "western-personal-8", preview: null, chapters: [], plan: null,
    preview_state: "ready", full_state: full ? "ready" : "not_started", access: full ? "full" : "preview",
    progress: { completed: full ? personalTopicKeys.length : 0, total: personalTopicKeys.length }, generation_progress: undefined,
    catalog: personalTopicKeys.map(key => ({ key, title: key, questions: [], houses: [], ready: full })),
    personal: { free_lines: ["Synthetic free line one.", "Synthetic free line two.", "Synthetic free line three."], sun_sign: "Cancer", ascendant_sign: "Leo",
      relationship: {text:'FREE_RELATIONSHIP_TEXT',action:'FREE_RELATIONSHIP_ACTION',evidence:[0,1].map(i=>({id:`relationship-${i}`,title:`Relationship factor ${i}`,detail:`Verified relationship factor ${i}`}))},
      traits: [0,1,2].map(i => ({ title: `Personal trait ${i}`, text: `Everyday behavior ${i}.` })),
      opportunity_action: "Prepare one example to share.",
      availability: { full_report: true, reason: "ready" },
      talent: full ? { text: "PRIVATE_TALENT", directions: [0,1,2].map(i => ({ title: `Direction ${i}`, text: `PRIVATE_DIRECTION_${i}` })) } : null,
      themes: full ? Object.fromEntries(['wealth','love','risk'].map(key => [key, {text: `PRIVATE_${key.toUpperCase()}`, evidence: [0,1].map(i => ({id:`${key}-${i}`,title:`Factor ${i}`,detail:`Verified position ${i}`}))}])) as NonNullable<LifeReport['personal']>['themes'] : null,
      nodes: full ? [1,2,3].map(i => ({ month: `2027-0${i}`, theme: `PRIVATE_THEME_${i}`, benefit: `PRIVATE_BENEFIT_${i}`, caution: `PRIVATE_CAUTION_${i}`, action: `PRIVATE_ACTION_${i}`, evidence: [] })) : [],
    },
  };
}

describe("personal Western report contract and export", () => {
  it("accepts free content while paid calculations are deferred", () => {
    const report = personalFixture();
    report.outlook = { state: 'not_started' };
    report.personal!.availability = { full_report: true, reason: 'not_started' };
    expect(isLifeReport(report)).toBe(true);
    expect(hasLifePreview(report)).toBe(true);
    expect(reportHtml(report, lifeLabels(report))).toContain(report.personal!.free_lines[1]);
    expect(reportHtml(report, lifeLabels(report))).not.toContain('PRIVATE_');
  });
  for (const language of languages) {
    it(`shows three distinct free areas and isolates six paid blocks in ${language}`, () => {
      const report = personalFixture(language, true);
      expect(isLifeReport(report)).toBe(true);
      expect(hasLifePreview(report)).toBe(true);
      expect(previewGenerationProgress(report).phase).toBe("ready");
      expect(reportGenerationProgress(report).percent).toBe(100);
      expect(reportContent(report).filter(section => section.paid).map(section => section.key)).toEqual(personalTopicKeys);
      const full = reportHtml(report, lifeLabels(report));
      expect(full).toContain("PRIVATE_TALENT");
      expect(full).toContain("PRIVATE_THEME_3");
      const names = language === 'zh' || language === 'th' ? copy.jy[language].report.westernSections : additionalLocales[language].jy.report.westernSections;
      for (const key of personalTopicKeys) expect(full.split(`<h2>${names[key]}</h2>`)).toHaveLength(2);
      for (const key of ['WEALTH','LOVE','RISK']) expect(full.split(`PRIVATE_${key}`)).toHaveLength(2);
      expect(full).not.toContain(report.input.profile.birth_date);
      expect(full).not.toContain(report.input.profile.birthplace);
      report.access = "preview";
      const free = reportHtml(report, lifeLabels(report));
      const labels = language === 'zh' || language === 'th' ? copy.jy[language].personal : additionalLocales[language].jy.personal;
      expect(free.indexOf(labels.relationshipTitle)).toBeLessThan(free.indexOf(labels.keywords));
      expect(free.split('FREE_RELATIONSHIP_TEXT')).toHaveLength(2);
      expect(free.split('FREE_RELATIONSHIP_ACTION')).toHaveLength(2);
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
      expect(free.match(/<details>/gu)).toHaveLength(1);
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
  it("requires all three added subjects in a six-topic full report", () => {
    for (const key of ['wealth', 'love', 'risk'] as const) {
      const report = personalFixture('zh', true);
      delete (report.personal!.themes as Partial<NonNullable<typeof report.personal>['themes']>)![key];
      expect(isLifeReport(report)).toBe(false);
    }
  });
  it("preserves older four-part reports without manufacturing missing subjects", () => {
    const report = personalFixture('zh', true);
    report.catalog = legacyPersonalTopicKeys.map(key => ({key, title:key, questions:[], houses:[], ready:true}));
    report.progress = {completed:4, total:4};
    report.version = 'western-personal-7';
    delete report.personal!.relationship;
    delete report.personal!.themes;
    expect(isLifeReport(report)).toBe(true);
    expect(reportGenerationProgress(report).percent).toBe(100);
    expect(reportContent(report).filter(section => section.paid).map(section => section.key)).toEqual(legacyPersonalTopicKeys);
    const html = reportHtml(report, lifeLabels(report));
    expect(html).toContain('PRIVATE_THEME_3');
    expect(html).not.toContain('PRIVATE_WEALTH');
  });
  it("requires a complete relationship preview in new reports but reads old saved previews", () => {
    const report = personalFixture();
    delete report.personal!.relationship;
    expect(isLifeReport(report)).toBe(false);
    report.version = 'western-personal-7';
    expect(isLifeReport(report)).toBe(true);
    expect(reportHtml(report,lifeLabels(report))).not.toContain(copy.jy.zh.personal.relationshipTitle);
    report.personal!.relationship = {text:'<script>unsafe</script>',action:'Ask <one> question',evidence:[0,1].map(i=>({id:`r-${i}`,title:'Factor',detail:'Detail'}))};
    const html = reportHtml(report,lifeLabels(report));
    expect(html).toContain('&lt;script&gt;unsafe&lt;/script&gt;');
    expect(html).not.toContain('<script>unsafe</script>');
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
