import type { Copy } from '../lib/i18n';
import type { ThaiChart } from '../lib/thai';

export function ChartCalculationNote({ value, t }: { value: ThaiChart; t: Copy }) {
  return (
    <section
      className="mb-5 rounded-2xl border border-line bg-surface p-3 text-xs leading-6 text-muted"
      data-testid="chart-calculation-settings"
    >
      <h3 className="sr-only">{t.q_settings}</h3>
      <div className="flex flex-wrap gap-2">
        {[t.q_system, t.q_houses, t.q_lines].map((label) => (
          <span
            key={label}
            className="rounded-lg border border-line bg-panel px-2 py-1 text-[10px] leading-5"
          >
            {label}
          </span>
        ))}
      </div>
      <details className="mt-2">
        <summary className="cursor-pointer text-accent">{t.q_compare}</summary>
        <p className="mt-2">{t.q_views}</p>
        <p className="mt-2">{t.q_difference}</p>
        <p className="mt-2">{t.q_precision}</p>
        {value.calculation_input && (
          <dl className="mt-3 space-y-2 border-t border-line pt-3 text-[11px] [overflow-wrap:anywhere]">
            <div>
              <dt className="text-muted">{t.q_localInput}</dt>
              <dd>
                {value.calculation_input.local_datetime} · {value.calculation_input.time_zone}
              </dd>
            </div>
            <div>
              <dt className="text-muted">{t.q_utcInput}</dt>
              <dd>{value.calculation_input.utc_datetime}</dd>
            </div>
            {value.location?.latitude != null && value.location.longitude != null && (
              <div>
                <dt className="text-muted">{t.th_locationTitle}</dt>
                <dd>
                  {value.location.latitude}, {value.location.longitude}
                </dd>
              </div>
            )}
          </dl>
        )}
      </details>
    </section>
  );
}
