import type { Language } from "../lib/reading";
import type { LifePoint } from "../lib/lifeReport";
import { EvidenceDetails } from "./EvidenceDetails";

export function ReportItems({
  items,
  language,
  ids,
}: {
  items: LifePoint[];
  language: Language;
  ids?: (string | undefined)[];
}) {
  return (
    <div className="space-y-7">
      {items.map((item, index) => (
        <article key={index} id={ids?.[index]} className="min-w-0 scroll-mt-24">
          <h5 className="m-0 flex items-center gap-2 text-[16px] font-semibold leading-7 text-cream">
            {item.title}
          </h5>
          <p className="mt-3 text-[15px] leading-[1.95] text-[#d5c8e3]">
            {item.text}
          </p>
          {item.signals && (
            <div className="mt-4">
              <ul className="mt-2 list-disc space-y-2 pl-5 text-sm leading-7 text-[#d5c8e3]">
                {item.signals.map((text, i) => (
                  <li key={i}>{text}</li>
                ))}
              </ul>
            </div>
          )}
          {item.response && (
            <div className="mt-4">
              <p className="mt-2 text-sm leading-7 text-[#d5c8e3]">
                {item.response}
              </p>
            </div>
          )}
          {item.steps && (
            <ol className="mt-4 list-decimal space-y-3 pl-5 text-sm leading-7 text-[#d5c8e3]">
              {item.steps.map((step, i) => (
                <li key={i} className="pl-1">
                  {step}
                </li>
              ))}
            </ol>
          )}
          {(["example", "pitfall", "check"] as const).map(
            (key) =>
              item[key] && (
                <div
                  key={key}
                  className={`mt-4 ${key === "example" ? "rounded-xl border border-solid border-gold/15 bg-gold/5 p-4" : ""}`}
                >
                  <p className="mt-2 text-sm leading-7 text-[#d5c8e3]">
                    {item[key]}
                  </p>
                </div>
              ),
          )}
          <EvidenceDetails evidence={item.evidence} language={language} />
        </article>
      ))}
    </div>
  );
}
