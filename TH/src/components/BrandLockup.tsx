import type { Copy } from '../lib/i18n';
import { BrandMark } from './BrandMark';

export function BrandLockup({ t, compact = false }: { t: Copy; compact?: boolean }) {
  return (
    <span
      className={`inline-flex min-w-0 items-center text-accent ${compact ? 'gap-2 brandCompact:gap-1.5' : 'gap-3'}`}
      data-brand-lockup
    >
      <BrandMark
        className={
          compact ? 'h-8 w-8 shrink-0 brandCompact:h-7 brandCompact:w-7' : 'h-11 w-11 shrink-0'
        }
      />
      <span className="min-w-0" lang="en">
        <span
          className={`block whitespace-nowrap font-display font-medium leading-[1.25] tracking-[.1em] text-ink ${compact ? 'text-[18px] brandCompact:text-[15px] brandCompact:tracking-[.06em]' : 'text-[24px]'}`}
        >
          {t.brandName}
        </span>
        {!compact && (
          <span
            lang={t.dateLocale}
            className="mt-1.5 block max-w-[180px] text-[10px] font-normal leading-[1.7] tracking-normal text-muted"
          >
            {t.brandTagline}
          </span>
        )}
      </span>
    </span>
  );
}
