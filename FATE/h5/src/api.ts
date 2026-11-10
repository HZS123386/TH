import { topics, type Topic } from './copy';

export interface Place {
  id: string;
  name: string;
  name_th: string;
  name_zh?: string;
  country: string;
  timezone: string;
}

export interface Region {
  id: string;
  name: string;
  name_th: string;
  name_zh: string;
}

export interface Planet {
  id: string;
  label: string;
  sign?: string;
  sign_name: string;
  longitude: number | null;
  degree: number | null;
  house: number | null;
}

export interface ChartResult {
  precision: 'exact' | 'date_only';
  engine: string;
  place: string;
  planets: Planet[];
  houses: { number: number; longitude: number }[];
  aspects: { from: string; to: string; type: string; label: string }[];
  reading: { id: string; title: string; basis: string; text: string }[];
}

export interface Reading {
  status: 'queued' | 'running' | 'ready' | 'failed';
  result: ChartResult | null;
  error: string | null;
}

export async function api<T>(
  path: string,
  options: { method?: string; key?: string; body?: unknown; signal?: AbortSignal } = {},
): Promise<T> {
  const headers: Record<string, string> = {};
  if (options.body !== undefined) headers['Content-Type'] = 'application/json';
  if (options.key) headers.Authorization = 'Bearer ' + options.key;
  const response = await fetch('/api/v1' + path, {
    method: options.method,
    headers,
    body: options.body === undefined ? undefined : JSON.stringify(options.body),
    signal: options.signal,
    cache: 'no-store',
  });
  if (response.status === 204) return undefined as T;
  const result = await response.json();
  if (!response.ok) throw new Error(result.detail || 'calculation_unavailable');
  return result;
}

export function readingKey(): string {
  return Array.from(crypto.getRandomValues(new Uint8Array(32)), b => b.toString(16).padStart(2, '0')).join('');
}

export type SavedReading = { key: string; topic: Topic; date: number; locked?: true };
const historyKey = 'fate-report-history';

export function recentReadings(): SavedReading[] {
  try {
    const rows = JSON.parse(sessionStorage.getItem(historyKey) || '[]') as SavedReading[];
    return Array.isArray(rows) ? rows.filter(row => row && /^[a-f0-9]{64}$/.test(row.key) &&
      topics.includes(row.topic) && Number.isFinite(row.date) && Date.now() - row.date < 86400000) : [];
  } catch {
    return [];
  }
}

export function updateReadingHistory(key: string, entry?: Pick<SavedReading, 'topic' | 'locked'>) {
  const readings = recentReadings().filter(row => row.key !== key);
  if (entry) readings.unshift({ key, ...entry, date: Date.now() });
  try { sessionStorage.setItem(historyKey, JSON.stringify(readings.slice(0, 12))); } catch { /* The current report remains visible. */ }
}

export async function recordVisit(): Promise<string | undefined> {
  if ((navigator as Navigator & { globalPrivacyControl?: boolean }).globalPrivacyControl ||
      navigator.doNotTrack === '1') return undefined;
  try {
    let id = sessionStorage.getItem('fate-visit');
    if (!id) {
      id = crypto.randomUUID();
      sessionStorage.setItem('fate-visit', id);
    }
    const params = new URLSearchParams(location.search);
    const tag = (name: string) => (params.get(name) ?? '').replace(/[^A-Za-z0-9_.~-]/g, '').slice(0, 64);
    await api('/visits', {
      method: 'POST', body: { id, source: tag('utm_source'), campaign: tag('utm_campaign') },
      signal: AbortSignal.timeout(2500),
    });
    return id;
  } catch {
    return undefined;
  }
}
