import { contentFor, type Topic } from '../lib/wanjai';
import { planetNumbers, taksaKeys, taksaThai } from '../lib/thai';
import type { WanjaiPageProps } from './wanjai/WanjaiShared';

export const topicFactors = {
  love: { house: 7, taksa: 'si' },
  money: { house: 2, taksa: 'mula' },
  family: { house: 4, taksa: 'boriwan' },
  work: { house: 10, taksa: 'utsaha' },
} as const;

/** Show computed evidence beside editorial advice without inventing a forecast. */
export function ThaiBasis({ p, topic }: { p: WanjaiPageProps; topic?: Topic }) {
  const { t, thai } = p;
  const value = thai.value;
  const factor = topic && topicFactors[topic];
  const house = factor && value?.chart?.houses.find((h) => h.number === factor.house);
  const taksa = factor && value?.taksa?.[factor.taksa];
  const signs = contentFor(p.language).signs;
  return (
    <section
      className="mb-6 rounded-xl border border-gold/35 bg-surface p-5"
      aria-label={t.th_facts}
    >
      <h2 className="mb-3 text-sm text-accent">{t.th_facts}</h2>
      {thai.loading ? (
        <p role="status" className="text-xs">
          {t.th_loading}
        </p>
      ) : thai.error ? (
        <div role="alert" className="text-xs">
          <p>{thai.error}</p>
          <button className="btn-quiet mt-2" onClick={thai.retry}>
            {t.retry}
          </button>
        </div>
      ) : !value ? (
        <p className="text-xs leading-6 text-muted">{t.w_noBirth}</p>
      ) : (
        <>
          {value.chart && (
            <p className="text-sm leading-7">
              {t.th_asc} · {signs[value.chart.points.ascendant.sign].name} ·{' '}
              {value.chart.points.ascendant.degrees}°{' '}
              {value.chart.points.ascendant.minutes.toFixed(1)}′
            </p>
          )}
          {house && (
            <p className="mt-2 text-xs leading-7">
              {t.th_house} {house.number} · {house.nameThai} · {signs[house.sign].name} ·{' '}
              {t.th_ruler} {house.ruler.number} {house.ruler.nameThai}
            </p>
          )}
          {taksa !== undefined && factor && (
            <p className="text-xs leading-7">
              {taksaThai[taksaKeys.indexOf(factor.taksa)]} · {taksa}{' '}
              {value.chart?.points[planetNumbers[taksa] as keyof typeof value.chart.points]
                ?.nameThai || ''}
            </p>
          )}
          {value.status !== 'ready' && (
            <p className="text-xs leading-6 text-muted">
              {value.status === 'time-unknown' ? t.th_unknown : t.th_missingPlace}
            </p>
          )}
        </>
      )}
      <p className="mt-3 text-[11px] leading-6 text-muted">{t.th_lensNote}</p>
      <button className="btn-quiet mt-2 !px-0 !text-xs" onClick={() => p.navigate('chart')}>
        {t.th_personal} →
      </button>
    </section>
  );
}
