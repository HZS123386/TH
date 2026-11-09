import { BookOpenCheck } from "lucide-react";
import { lifeCopy, type LifeEvidence } from "../lib/lifeReport";
import type { Language } from "../lib/reading";

export function EvidenceDetails({ evidence, language }: { evidence: LifeEvidence[]; language: Language }) {
  if (!evidence.length) return null;
  const c = lifeCopy[language];
  return (
    <details className="evidence-details mt-4 rounded-xl border border-solid border-gold/20 bg-night/60 p-3 text-xs">
      <summary className="cursor-pointer text-gold"><BookOpenCheck size={13} className="mr-1 inline-block align-middle" />{c.evidence}</summary>
      <ul className="m-0 mt-3 list-none space-y-3 p-0 text-lavender">
        {evidence.map(item => <li key={item.id}><strong className="font-medium text-cream">{item.title}</strong><p className="mt-1 leading-6">{item.detail}</p></li>)}
      </ul>
      <p className="mt-3 border-0 border-t border-solid border-gold/15 pt-3 text-[10px] leading-5 text-lavender">{c.evidenceHint}</p>
    </details>
  );
}
