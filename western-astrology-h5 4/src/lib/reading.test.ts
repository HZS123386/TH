import { describe, expect, it } from "vitest";
import { periodLabel, reportHtml } from "./reading";
import { isLifeReport, lifeCopy, lifeSignature } from "./lifeReport";
import { reportContent } from "./reportContent";
import { inputFor, reportFixture } from "../../tests/fixtures/lifeReport";

const result = reportFixture(inputFor(), true);

describe("report exports", () => {
  it("omits all full chapters and action plans from a preview file", () => {
    const preview = { ...result, access: "preview" as const };
    const html = reportHtml(preview, lifeCopy.zh);
    expect(html).toContain(result.preview!.summary.text);
    expect(html).toContain("<h2>基础信息</h2>");
    expect(html).toContain("<h2>报告摘要</h2>");
    expect(html).toContain("<h2>个人特点</h2>");
    expect(html).not.toContain("付费专属分析正文");
    expect(html).not.toContain("<h2>事业发展</h2>");
    expect(html).not.toContain("<h2>总结建议</h2>");
  });
  it("exports five paid sections with direct headings and escapes service-supplied strings", () => {
    const copy = structuredClone(result);
    copy.preview!.summary.text = '<script>alert(1)</script>';
    const html = reportHtml(copy, lifeCopy.zh);
    expect(html).toContain("付费专属分析正文");
    for (const title of ["事业发展", "财务方面", "感情与家庭", "近期关注", "总结建议"]) expect(html).toContain(`<h2>${title}</h2>`);
    expect(html).toContain("工作风格");
    expect(html).toContain("发展建议");
    expect(html).not.toContain("这对你意味着什么");
    expect(html).not.toContain("你可以这样做");
    expect(html).toContain("&lt;script&gt;alert(1)&lt;/script&gt;");
    expect(html).not.toContain("<script>");
    expect(html).toContain("#130c24");
  });
  it("keeps an in-progress export as a preview until the whole version is ready", () => {
    expect(reportHtml({ ...result, full_state: "generating" }, lifeCopy.zh)).not.toContain("付费专属分析正文");
  });
  it("keeps the first three sections free and gates paid source data in the shared outline", () => {
    const sections = reportContent({ ...result, access: "preview" });
    expect(sections.map(section => section.title)).toEqual(["基础信息", "报告摘要", "个人特点", "事业发展", "财务方面", "感情与家庭", "近期关注", "总结建议"]);
    expect(sections.map(section => section.paid)).toEqual([false, false, false, true, true, true, true, true]);
    expect(sections.slice(3).every(section => !section.ready && section.groups.length === 0 && section.summaries.length === 0)).toBe(true);
  });
  it("combines relationship and family writing without losing their source actions", () => {
    const section = reportContent(result).find(section => section.key === "relationships")!;
    expect(section.ready).toBe(true);
    expect(section.groups).toHaveLength(4);
    const actionIds = section.groups.flatMap(group => group.entries.map(entry => entry.id).filter(Boolean));
    expect(actionIds).toEqual(["life-action-love-0", "life-action-love-1", "life-action-family-0", "life-action-family-1"]);
  });
  it("keeps an unknown birth time and its estimate warning in exported reports", () => {
    const unknown = structuredClone(result);
    unknown.input.profile.birth_time = null;
    const html = reportHtml(unknown, lifeCopy.zh);
    expect(html).toContain("出生时间未知");
    expect(html).toContain("12:00估算");
    expect(html).toContain("部分解读可能存在偏差");
  });
  it("ties the report signature to birth data, language and target year", () => {
    const input = inputFor();
    expect(lifeSignature(input)).not.toBe(lifeSignature({ ...input, year: 2027 }));
    expect(lifeSignature(input)).not.toBe(lifeSignature(inputFor("th")));
    expect(lifeSignature(input)).not.toBe(lifeSignature({ ...input, profile: { ...input.profile, birth_time: "10:15" } }));
  });
  it("recognizes the new report and rejects the old single-topic response", () => {
    expect(isLifeReport(result)).toBe(true);
    expect(isLifeReport({ report_id: "old", report: { sections: [] } })).toBe(false);
  });
  it("keeps annual labels in the selected Gregorian year in Thai", () => {
    expect(periodLabel({ year: 2026, month: 7 }, "th")).toContain("2026");
    expect(periodLabel({ year: 2026, month: 7 }, "th")).not.toContain("2569");
    expect(periodLabel({ year: 2026, month: 7 }, "zh")).toContain("2026年7月");
  });
});
