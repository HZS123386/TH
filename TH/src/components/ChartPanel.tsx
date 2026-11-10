import { ArrowUpRight, Info, Leaf, Pencil, Plus } from 'lucide-react';
import type { Copy } from '../lib/i18n';
import type { ProfileRecord } from '../types';
import { BrandMark } from './BrandMark';

const pillarKeys = ['year', 'month', 'day', 'hour'] as const;
const elements = [
  { key: '木', label: 'wood', color: '#9ac79a', tint: '#21352b' },
  { key: '火', label: 'fire', color: '#f0a397', tint: '#3a222e' },
  { key: '土', label: 'earth', color: '#e4bc78', tint: '#392c27' },
  { key: '金', label: 'metal', color: '#d4c2e5', tint: '#34263f' },
  { key: '水', label: 'water', color: '#9fc9e6', tint: '#202c43' },
] as const;
const charColors: Record<string, string> = Object.fromEntries([
  ...'甲乙寅卯'.split('').map((c) => [c, 'text-[#9ac79a]']),
  ...'丙丁巳午'.split('').map((c) => [c, 'text-[#f0a397]']),
  ...'戊己丑辰未戌'.split('').map((c) => [c, 'text-[#e4bc78]']),
  ...'庚辛申酉'.split('').map((c) => [c, 'text-[#d4c2e5]']),
  ...'壬癸子亥'.split('').map((c) => [c, 'text-[#9fc9e6]']),
]);

export function ChartPanel({
  record,
  t,
  onEdit,
  disabled,
}: {
  record: ProfileRecord | null;
  t: Copy;
  onEdit: () => void;
  disabled: boolean;
}) {
  return (
    <section className="panel overflow-hidden" aria-labelledby="chart-title">
      <div className="flex items-start justify-between gap-2 px-6 pb-5 pt-6">
        <div>
          <h2 id="chart-title" className="text-base font-semibold">
            {t.chart}
          </h2>
          <p className="mt-1.5 text-xs text-muted">{t.chartSub}</p>
        </div>
        <button
          className="btn-quiet -mr-2 -mt-1 !px-2"
          onClick={onEdit}
          disabled={disabled}
          aria-label={t.edit}
        >
          <Pencil size={15} />
        </button>
      </div>
      {record ? (
        <>
          <div className="mx-6 mb-5 flex items-center gap-2 border-b border-line pb-4 text-xs text-muted">
            <span className="font-medium text-ink">{record.profile.display_name || '—'}</span>
            <span>·</span>
            <span>{record.profile.birth_date}</span>
            <span>{record.profile.birth_time || t.unknown}</span>
          </div>
          <div className="grid grid-cols-4 gap-2.5 px-6">
            {pillarKeys.map((key) => (
              <div
                key={key}
                className={`rounded-xl px-1 py-4 text-center ${key === 'day' ? 'bg-surface ring-1 ring-accent/10' : 'bg-panel'}`}
              >
                <div className="text-xs font-medium">{t[key]}</div>
                <div className="mt-1 text-[9px] tracking-[.15em] text-muted">
                  {t[`${key}Caption`]}
                </div>
                <div
                  className={`mt-5 font-display text-3xl ${charColors[record.chart.pillars[key]?.[0] || ''] || 'text-muted/40'}`}
                >
                  {record.chart.pillars[key]?.[0] || '—'}
                </div>
                <div
                  className={`mt-3 font-display text-3xl ${charColors[record.chart.pillars[key]?.[1] || ''] || 'text-muted/40'}`}
                >
                  {record.chart.pillars[key]?.[1] || '—'}
                </div>
              </div>
            ))}
          </div>
          <div className="px-6 pb-6 pt-6">
            <div className="mb-4 flex items-center justify-between">
              <h3 className="text-xs font-medium">{t.elements}</h3>
              <span className="text-[10px] text-muted">{t.calculated}</span>
            </div>
            <div className="grid grid-cols-5 gap-2">
              {elements.map((element) => (
                <div key={element.key} className="text-center">
                  <div
                    style={{ backgroundColor: element.tint, color: element.color }}
                    className="mx-auto flex h-9 w-9 items-center justify-center rounded-full font-display text-lg"
                  >
                    {element.key}
                  </div>
                  <div className="mt-2 text-[10px] text-muted">{t[element.label]}</div>
                  <div className="mt-1 text-sm font-medium" data-testid={`element-${element.key}`}>
                    {record.chart.visible_element_counts[element.key]}
                  </div>
                </div>
              ))}
            </div>
            <p className="mt-5 text-[11px] leading-relaxed text-muted">{t.elementsNote}</p>
          </div>
          <div className="flex flex-wrap items-center justify-between gap-2 border-t border-line bg-canvas px-6 py-3 text-[10px] text-muted">
            <span className="flex items-center gap-1.5">
              <Leaf size={12} /> {record.chart.engine} {record.chart.engine_version}
            </span>
            <span>
              {t.revision} {record.revision}
            </span>
          </div>
        </>
      ) : (
        <div className="px-6 pb-7 text-center">
          <div className="relative mx-auto mb-6 mt-2 flex h-40 w-40 items-center justify-center rounded-full border border-accent/20 bg-surface shadow-[0_0_45px_-20px_#b67af3]">
            <div className="absolute inset-4 rounded-full border border-accent/20" />
            <BrandMark className="h-24 w-24 text-accent/80" />
            <span className="absolute -right-1 top-7 rounded-full border border-accent/30 bg-panel p-2.5">
              <Leaf size={16} className="text-accent" />
            </span>
          </div>
          <h3 className="text-sm font-medium leading-relaxed">{t.emptyChart}</h3>
          <p className="mx-auto mt-3 max-w-64 text-xs leading-6 text-muted">{t.emptyChartNote}</p>
          <button onClick={onEdit} className="btn-primary mt-6 w-full" disabled={disabled}>
            <Plus size={15} />
            {t.createProfile}
            <ArrowUpRight size={15} className="ml-auto" />
          </button>
          <div className="mt-6 grid grid-cols-4 gap-2" aria-hidden="true">
            {pillarKeys.map((key) => (
              <div key={key} className="rounded-lg border border-dashed border-line py-3">
                <div className="text-[10px] text-muted">{t[key]}</div>
                <div className="mt-2 text-lg text-muted/30">—</div>
              </div>
            ))}
          </div>
        </div>
      )}
      <details className="border-t border-line px-6 py-4 text-[11px] text-muted">
        <summary className="cursor-pointer select-none">
          <span className="ml-1 inline-flex items-center gap-1.5">
            <Info size={12} />
            {t.convention}
          </span>
        </summary>
        <p className="mt-3 leading-6">{t.conventionNote}</p>
      </details>
    </section>
  );
}
