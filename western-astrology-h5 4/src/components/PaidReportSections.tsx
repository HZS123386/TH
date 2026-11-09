import { lifeCopy, type LifeReport } from "../lib/lifeReport";
import { reportContent } from "../lib/reportContent";
import { EvidenceDetails } from "./EvidenceDetails";
import { ReportItems } from "./ReportItems";

export function PaidReportSections({ report, onNavigate }: { report: LifeReport; onNavigate: (id: string) => void }) {
  if (report.access !== "full") return null;
  const language = report.input.profile.language;
  const c = lifeCopy[language];
  const sections = reportContent(report);
  return <>
    <nav aria-label={c.navigation} className="my-6 flex flex-wrap gap-2">{sections.filter(section => section.ready).map(section => <button key={section.key} type="button" onClick={() => onNavigate(`life-section-${section.key}`)} className="rounded-full border border-solid border-gold/30 bg-plum/50 px-3 py-2 text-[10px] text-gold">{section.title}</button>)}</nav>
    {sections.filter(section => section.paid && section.groups.length).map(section => <section key={section.key} id={`life-section-${section.key}`} tabIndex={-1} className="scroll-mt-6 border-0 border-t border-solid border-gold/25 py-7" data-testid={`life-section-${section.key}`}>
      <h3 className="mb-5 mt-2 text-[23px] font-medium leading-9 text-cream">{section.title}</h3>
      {section.summaries.map((summary, index) => <div key={index} className="mb-5 rounded-xl border border-solid border-gold/25 bg-plum/60 p-4"><p className="text-[16px] leading-8 text-cream">{summary.text}</p><EvidenceDetails evidence={summary.evidence} language={language} /></div>)}
      {section.groups.map(group => <div key={group.title} className="mt-8"><h4 className="mb-5 text-base font-semibold text-gold">{group.title}</h4><ReportItems items={group.entries.map(entry => entry.point)} ids={group.entries.map(entry => entry.id)} language={language} /></div>)}
    </section>)}
    {report.plan && <section id="life-section-advice" tabIndex={-1} className="scroll-mt-6 border-0 border-t border-solid border-gold/30 pt-7" data-testid="life-action-plan"><h3 className="text-2xl font-medium leading-9 text-cream">{sections[7].title}</h3><p className="mt-3 text-xs leading-7 text-lavender">{sections[7].description}</p><div className="mt-6 space-y-5">{report.plan.phases.map((phase, index) => <article key={phase.key} className="rounded-xl border border-solid border-gold/25 bg-plum/50 p-4"><p className="text-[10px] text-gold">{c.priority} {index + 1}</p><h4 className="mb-2 mt-2 text-base font-semibold leading-7">{phase.title}</h4><p className="text-sm leading-8 text-lavender">{phase.text}</p><ul className="mb-0 mt-5 list-none space-y-6 p-0">{phase.actions.map(action => <li key={`${action.chapter}:${action.index}`}><strong className="text-sm font-medium text-cream">{action.title}</strong><ol className="mt-3 list-decimal space-y-2 pl-5 text-sm leading-7 text-lavender">{action.steps?.map((step, stepIndex) => <li key={stepIndex}>{step}</li>)}</ol><button type="button" className="mt-2 bg-transparent p-0 text-[10px] text-gold underline" onClick={() => onNavigate(action.chapter === "overview" ? "life-section-traits" : `life-action-${action.chapter}-${action.index}`)}>{c.viewAction} ↗</button></li>)}</ul></article>)}</div></section>}
  </>;
}
