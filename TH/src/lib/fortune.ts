import { useEffect, useState } from 'react';
import { api } from './api';
import { bangkokDay, type Period, type Topic } from './wanjai';
import type { Language, Profile } from '../types';
import type { ThaiChart } from './thai';

export type FortunePeriod = Period;
export interface FortuneEvidence {
  date: string;
  time: string;
  planet: string;
  number: number;
  sign: number;
  longitude: number;
  reference_sign: number;
  position: number;
  code: string;
}
export interface FortuneReading {
  planet: string;
  number: number;
  code: 'supportive' | 'reflective' | 'steady' | 'mixed';
  consistent_across_birth_window: boolean;
  alternatives: {
    reference_sign: number;
    counts: Record<string, number>;
    dominant: string;
    evidence: FortuneEvidence[];
  }[];
}

export interface FortuneGeneration {
  available: boolean;
  state: 'rules' | 'ready' | 'fallback';
  cached: boolean;
  reason?: string;
  limit_scope?: 'personal' | 'network';
  retry_after?: number;
}

export interface FortuneFactor {
  id: string;
  kind: 'placement' | 'sign_change' | 'sign_relationship';
  bodies: string[];
  start: string;
  end: string;
  sign?: number;
  from_sign?: number;
  positions?: { reference_sign: number; position: number }[];
  sample_count?: number;
  total_samples?: number;
  relationship?: 'opposition' | 'square' | 'trine' | 'sextile';
  observed_dates?: string[];
}

export interface Fortune {
  engine: ThaiChart['engine'];
  guidance_version: string;
  period: FortunePeriod;
  period_start: string;
  period_end: string;
  as_of: string;
  time_zone: string;
  sampling: {
    method: 'current-minute' | 'daily-noon';
    count: number;
    dates: { date: string; time: string }[];
  };
  calendar: {
    date: string;
    civil_weekday: number;
    thai_lunar_date: ThaiChart['calendar']['thaiLunarDate'];
    moon: { sign: number; longitude: number; reference_positions: number[] };
  };
  narrative: {
    version: string;
    language: Language;
    date: string;
    affirmation: string;
    paragraphs: string[];
    topics: Record<Topic, { text: string; outlook: string }>;
    source?: 'rules' | 'ai';
    generated_at?: string;
    paragraph_evidence?: string[][];
  };
  generation?: FortuneGeneration;
  analysis?: {
    adapter_version: string;
    upstream: string;
    upstream_commit: string;
    signature: string;
    sampling: { count: number; method: string };
    factors: FortuneFactor[];
    topic_factors: Record<Topic, string[]>;
  };
  birth: {
    date: string;
    civil_weekday: number;
    thai_lunar_date: ThaiChart['calendar']['thaiLunarDate'];
    sun_window: { sign: number; longitude: number }[];
    sun_signs: number[];
    taksa: ThaiChart['taksa'];
    astrological_weekday: number | null;
    time_known: boolean;
    zone_known: boolean;
    basis: 'ascendant' | 'sun-sign' | 'sun-sign-range';
    reference_signs: number[];
    missing: string[];
  };
  readings: Record<Topic, FortuneReading>;
  limits: { predictive_accuracy: string; interpretation: string; natal_houses_used: boolean };
}
export function useFortune(
  profile: Profile | null,
  period: FortunePeriod,
  language: Language,
  owner: string,
) {
  const [day, setDay] = useState(() => bangkokDay());
  const [attempt, retry] = useState(0);
  const [snapshot, setSnapshot] = useState<{ key: string; value: Fortune } | null>(null);
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);
  const [writingKey, setWritingKey] = useState<string | null>(null);
  const serialized = profile ? JSON.stringify({ ...profile, language }) : '';
  const key = `${owner}|${serialized}|${period}|${day}`;
  useEffect(() => {
    const syncDay = () => setDay(bangkokDay());
    const remaining = Date.parse(`${day}T00:00:00+07:00`) + 86400000 - Date.now();
    const midnight = setTimeout(syncDay, Math.max(1, remaining + 50));
    const timer = setInterval(syncDay, 60000);
    window.addEventListener('focus', syncDay);
    document.addEventListener('visibilitychange', syncDay);
    return () => {
      clearTimeout(midnight);
      clearInterval(timer);
      window.removeEventListener('focus', syncDay);
      document.removeEventListener('visibilitychange', syncDay);
    };
  }, [day]);
  useEffect(() => {
    const controller = new AbortController();
    setError('');
    if (!serialized) {
      setLoading(false);
      return;
    }
    setLoading(true);
    let hasFacts = false;
    void (async () => {
      try {
        const body = { profile: JSON.parse(serialized) as Profile, period };
        const value = await api<Fortune>('/api/fortune', {
          method: 'POST',
          body: JSON.stringify(body),
          signal: controller.signal,
        });
        if (controller.signal.aborted) return;
        hasFacts = true;
        setSnapshot({ key, value });
        setLoading(false);
        if (!value.generation?.available || value.generation.state === 'ready') return;
        setWritingKey(key);
        const report = await api<{
          narrative: Fortune['narrative'];
          generation: FortuneGeneration;
          period: FortunePeriod;
          period_start: string;
          period_end: string;
          for_date: string;
          analysis_signature: string;
        }>('/api/fortune/narrative', {
          method: 'POST',
          body: JSON.stringify({ ...body, for_date: value.calendar.date }),
          signal: controller.signal,
        });
        if (controller.signal.aborted) return;
        if (
          report.period !== period ||
          report.for_date !== value.calendar.date ||
          report.period_start !== value.period_start ||
          report.period_end !== value.period_end ||
          report.analysis_signature !== value.analysis?.signature ||
          report.narrative.language !== language
        ) {
          throw new Error('Fortune response does not match the requested period');
        }
        setSnapshot((current) =>
          current?.key === key
            ? {
                key,
                value: {
                  ...current.value,
                  narrative: report.narrative,
                  generation: report.generation,
                },
              }
            : current,
        );
      } catch (cause) {
        if (!controller.signal.aborted) {
          if (!hasFacts) setError(cause instanceof Error ? cause.message : String(cause));
          else
            setSnapshot((current) =>
              current?.key === key
                ? {
                    key,
                    value: {
                      ...current.value,
                      generation: {
                        available: true,
                        state: 'fallback',
                        cached: false,
                        reason: 'unavailable',
                      },
                    },
                  }
                : current,
            );
        }
      } finally {
        if (!controller.signal.aborted) {
          setLoading(false);
          setWritingKey(null);
        }
      }
    })();
    return () => controller.abort();
  }, [serialized, period, key, attempt]);
  return {
    value: snapshot?.key === key ? snapshot.value : null,
    error,
    loading,
    writing: writingKey === key,
    retry: () => retry((value) => value + 1),
  };
}
export function fillCopy(text: string, values: Record<string, string | number>) {
  return text.replace(/\{\{(\w+)\}\}/g, (_, key: string) => String(values[key] ?? ''));
}
