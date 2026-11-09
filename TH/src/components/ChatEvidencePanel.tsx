import type { ChatEvidence } from '../types';
import type { Copy } from '../lib/i18n';
import { fillCopy } from '../lib/fortune';

export function ChatEvidencePanel({ value, t }: { value: ChatEvidence; t: Copy }) {
  const mode = value.recall.mode;
  return (
    <details
      className="mt-4 rounded-xl border border-gold/25 bg-panel/60 p-3 text-[11px] leading-6"
      data-testid="chat-evidence"
    >
      <summary className="cursor-pointer text-muted">{t.m_why}</summary>
      <p className="mt-2">
        {t.m_profile} · {t.w_bangkok} ·{' '}
        {new Intl.DateTimeFormat(t.dateLocale, {
          dateStyle: 'medium',
          timeStyle: 'short',
          timeZone: 'Asia/Bangkok',
        }).format(new Date(value.calculated_at))}
      </p>
      <p>
        {
          t[
            mode === 'semantic'
              ? 'm_semantic'
              : mode === 'recent-unavailable'
                ? 'm_fallback'
                : mode === 'recent-unindexed'
                  ? 'm_unindexed'
                  : 'm_recent'
          ]
        }
      </p>
      <p>
        {fillCopy(t.m_counts, { notes: value.recall.confirmed_count, turns: value.recall.count })}
      </p>
      {value.generation?.response_provider && (
        <p data-testid="chat-model-workflow" className="mt-2 border-t border-line pt-2">
          {value.generation.reviewed
            ? t.m_cooperativeReply
            : fillCopy(t.m_singleReply, {
                model: value.generation.response_provider === 'qwen' ? 'Qwen' : 'Kimi',
              })}
        </p>
      )}
      {value.fortunes.map((item) => (
        <p key={item.period} className="mt-2 border-t border-line pt-2">
          {t[`w_${item.period}`]} ·{' '}
          {item.status === 'unavailable'
            ? t.m_toolUnavailable
            : `${item.period_start} — ${item.period_end}`}
          <span className="block text-muted">
            {item.birth && (item.birth.basis === 'ascendant' ? t.f_basisAsc : t.f_basisSun)}
          </span>
        </p>
      ))}
    </details>
  );
}
