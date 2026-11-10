import { Download, LoaderCircle, LockKeyhole } from "lucide-react";
import { lifeCopy } from "../lib/lifeReport";
import type { Language } from "../lib/reading";

export function ReportUnlockActions({ language, price, opening, onPurchase, compact = false }: {
  language: Language;
  price: string;
  opening: boolean;
  onPurchase: () => void;
  compact?: boolean;
}) {
  const c = lifeCopy[language];
  const purchaseLabel = opening ? c.unlocking : `${price} ${c.buyReading}`;
  return <div className={`grid ${compact ? "grid-cols-2 gap-2" : "mt-5 gap-3"}`}>
    <button type="button" disabled={opening} aria-label={c.downloadApp}
      className={`primary !m-0 !min-h-[54px] !px-3 !py-2 ${compact ? "!gap-2 !text-xs" : "!text-sm"}`}
      data-testid={compact ? "life-sticky-app" : "life-app-button"}>
      <Download size={compact ? 16 : 18} strokeWidth={1.6} className="shrink-0" aria-hidden="true" />
      {compact ? <span className="min-w-0 text-center leading-5"><span className="block text-[10px] font-medium">{c.downloadAppShort}</span><span className="block text-xs font-bold">{c.appFree}</span></span> : <span className="min-w-0 leading-6">{c.downloadApp}</span>}
    </button>
    <button type="button" disabled={opening} onClick={onPurchase} aria-label={purchaseLabel}
      className={`flex min-h-[54px] w-full items-center justify-center gap-2 rounded-[9px] border border-solid border-gold/60 bg-gold/[0.06] px-3 py-2 font-bold text-gold disabled:cursor-default disabled:opacity-60 ${compact ? "text-xs" : "text-sm"}`}
      data-testid={compact ? "life-sticky-buy" : "life-unlock-button"}>
      {opening ? <LoaderCircle size={16} className="shrink-0 animate-spin" aria-hidden="true" /> : <LockKeyhole size={compact ? 16 : 18} strokeWidth={1.6} className="shrink-0" aria-hidden="true" />}
      {opening ? <span className="min-w-0 leading-5">{c.unlocking}</span> : compact
        ? <span className="min-w-0 text-center leading-5"><span className="block text-[11px]">{price}</span><span className="block text-xs">{c.buyReading}</span></span>
        : <span className="min-w-0 leading-6">{purchaseLabel}</span>}
    </button>
  </div>;
}
