import { describe, expect, it } from "vitest";
import { inputFor, reportFixture } from "../../tests/fixtures/lifeReport";
import { hasLifePreview, isLifeReport, lifeLabels, personalTopicKeys, legacyPersonalTopicKeys, marriagePreviewKeys, marriageTopicKeys, relationshipTopicKeys, previewGenerationProgress, reportGenerationProgress, type LifeReport } from "./lifeReport";
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

it("exports the Thai marriage outline for the authorized edition", () => {
  const report: LifeReport = {
    ...reportFixture({ ...inputFor("zh"), report_kind: "marriage" }),
    format: "thai-marriage", version: "thai-marriage-1", title: "泰式占星 · 婚姻关系报告",
    preview: null, chapters: [], plan: null, generation_progress: undefined,
    preview_state: "ready", access: "preview", full_state: "not_started",
    progress: { completed: 0, total: marriageTopicKeys.length },
    catalog: marriageTopicKeys.map(key => ({ key, title: key, questions: [], houses: [], ready: false })),
    marriage: {
      preview: marriagePreviewKeys.map(key => ({ key, title: key, paragraphs: ["FREE_" + key], visible: key !== "relationship_snapshot" })),
      full: marriageTopicKeys.map(key => ({ key, title: key, paragraphs: ["PRIVATE_" + key] })),
    },
  };
  expect(isLifeReport(report)).toBe(true);
  expect(reportContent(report).map(section => section.key)).toEqual(marriagePreviewKeys.filter(key => key !== "relationship_snapshot"));
  expect(reportHtml(report, lifeLabels(report))).toContain("<p>FREE_unlock_offer</p>");
  expect(reportHtml(report, lifeLabels(report))).not.toContain("FREE_relationship_snapshot");
  expect(reportHtml(report, lifeLabels(report))).not.toContain("PRIVATE_");
  report.access = "full";
  report.full_state = "generating";
  expect(reportHtml(report, lifeLabels(report))).not.toContain("PRIVATE_");
  report.full_state = "ready";
  report.progress.completed = marriageTopicKeys.length;
  expect(isLifeReport(report)).toBe(true);
  expect(reportContent(report).map(section => section.key)).toEqual(marriageTopicKeys);
  const document = reportHtml(report, lifeLabels(report));
  expect(document.match(/<h2>.*?<\/h2>/g)).toEqual(marriageTopicKeys.map(key => "<h2>" + key + "</h2>"));
  expect(document).not.toContain("FREE_");
});

describe("personal Western report contract and export", () => {
  it("exports exactly the judgment and chart basis for the authorized edition", () => {
    const report = personalFixture("zh", true);
    report.title = "爱情人物影响解读报告";
    report.input.relationship = { status: "single", source: "unspecified" };
    report.version = "western-relationship-3";
    report.catalog = relationshipTopicKeys.map((key, index) => ({
      key, title: ["判断", "星盘依据"][index], houses: [], questions: [], ready: true,
    }));
    report.progress = { completed: 2, total: 2 };
    report.personal!.free_lines = [];
    report.personal!.relationship = null;
    report.personal!.talent = null;
    report.personal!.themes = null;
    report.personal!.nodes = [];
    report.personal!.relationship_preview_sections = { judgment: ["FREE_JUDGMENT"], basis: ["水星 · 金星\nFREE_BASIS"] };
    report.personal!.relationship_sections = { judgment: ["PAID_JUDGMENT"], basis: ["月亮 · 水星\nPAID_BASIS"] };
    expect(isLifeReport(report)).toBe(true);
    expect(hasLifePreview(report)).toBe(true);
    const complete = reportHtml(report, lifeLabels(report));
    expect(complete).toContain("<h1>爱情人物影响解读报告</h1>");
    expect(complete.match(/<h2>.*?<\/h2>/g)).toEqual(["<h2>判断</h2>", "<h2>星盘依据</h2>"]);
    expect(complete).toContain("<h2>判断</h2><p>PAID_JUDGMENT</p>");
    expect(complete).toContain("<h2>星盘依据</h2><p>月亮 · 水星</p><p>PAID_BASIS</p>");
    expect(complete).not.toContain("FREE_JUDGMENT");
    report.access = "preview";
    const free = reportHtml(report, lifeLabels(report));
    expect(free.match(/<h2>.*?<\/h2>/g)).toEqual(["<h2>判断</h2>", "<h2>星盘依据</h2>"]);
    expect(free).toContain("<p>FREE_JUDGMENT</p>");
    expect(free).toContain("<p>水星 · 金星</p><p>FREE_BASIS</p>");
    expect(free).not.toContain("PAID_");
    report.access = "full";
    report.full_state = "generating";
    expect(reportHtml(report, lifeLabels(report))).not.toContain("PAID_");
    expect(reportHtml(report, lifeLabels(report))).toContain("FREE_JUDGMENT");
  });
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
  it("renders each relationship answer as a separate paragraph only in the full export", () => {
    const report = personalFixture('zh', true);
    report.personal!.themes!.love.text = [
      '听到体贴的话时，你可能会提前空出见面的时间。',
      '“你愿意一起定下次见面的时间吗？”',
      '有变动也主动另约，可以再约一次看看。',
      '反复迟迟未确认，就照常安排自己的行程。',
    ].join('\n\n');
    const paragraphs = report.personal!.themes!.love.text.split('\n\n').map(answer => '<p>' + answer + '</p>').join('');
    expect(reportHtml(report, lifeLabels(report))).toContain('<h2>感情姻缘</h2>' + paragraphs);
    report.access = "preview";
    expect(reportHtml(report, lifeLabels(report))).not.toContain(paragraphs);
  });
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
