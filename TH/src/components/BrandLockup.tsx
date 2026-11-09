import type { Copy } from '../lib/i18n';
import { BrandMark } from './BrandMark';

export function BrandLockup({ t, compact = false }: { t: Copy; compact?: boolean }) {
  return (
    <span
      className={`inline-flex min-w-0 items-center text-accent ${compact ? 'gap-2' : 'gap-3'}`}
      data-brand-lockup
    >
      <BrandMark className={compact ? 'h-8 w-8 shrink-0' : 'h-11 w-11 shrink-0'} />
      <span className="min-w-0" lang={t.dateLocale}>
        <span
          className={`block whitespace-nowrap font-semibold leading-[1.25] ${compact ? 'text-[21px]' : t.dateLocale.startsWith('en') ? 'text-[22px]' : 'text-[27px]'} ${t.dateLocale.startsWith('th') ? 'font-sans tracking-normal' : 'font-display tracking-[.015em]'}`}
        >
          {t.brandName}
        </span>
        {!compact && (
          <span className="mt-1.5 block max-w-[130px] text-[10px] font-normal leading-[1.7] tracking-normal text-gold">
            {t.brandTagline}
          </span>
        )}
      </span>
    </span>
  );
}
