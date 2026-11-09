import zh from '../data/wanjai-zh.json';
import th from '../data/wanjai-th.json';
import en from '../data/wanjai-en.json';
import vi from '../data/wanjai-vi.json';
import type { Language } from '../types';

export type WanjaiContent = typeof zh;
export type Topic = keyof typeof zh.guidance;
export type Period = 'today' | 'week' | 'month';
export type WanjaiView =
  | 'overview'
  | 'chart'
  | 'chart-reading'
  | 'bazi-test'
  | 'thai-test'
  | 'example'
  | 'questions'
  | 'concern'
  | 'daily'
  | 'journey'
  | 'solution'
  | 'life'
  | 'shop'
  | 'mine'
  | 'share'
  | 'favorites'
  | 'inbox'
  | 'chat'
  | 'profile'
  | 'memories'
  | 'explore'
  | 'auth'
  | 'orders';
export const contentFor = (language: Language): WanjaiContent => ({ zh, th, en, vi })[language];
export const referenceContent = zh;
export function bangkokDay(date = new Date()) {
  return new Intl.DateTimeFormat('en-CA', {
    timeZone: 'Asia/Bangkok',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).format(date);
}
export function zodiacIndex(date: string | undefined): number | null {
  if (!date || !/^\d{4}-\d{2}-\d{2}$/.test(date)) return null;
  const [, month, day] = date.split('-').map(Number);
  if (month < 1 || month > 12 || day < 1 || day > 31) return null;
  const value = month * 100 + day;
  const boundaries = [321, 420, 521, 622, 723, 823, 923, 1024, 1123, 1222];
  if (value < 120 || value >= 1222) return 9;
  if (value < 219) return 10;
  if (value < 321) return 11;
  for (let i = boundaries.length - 1; i >= 0; i--) if (value >= boundaries[i]) return i;
  return null;
}

export interface CompanionState {
  concern: string | null;
  option: 'a' | 'b' | null;
  topic: Topic;
  period: Period;
  mood: 'steady' | 'ready' | 'tired';
  frequency: 'daily' | 'weekly' | 'off';
  routine: 'day' | 'late';
  reminder_time: string;
  wish: string;
  favorites: string[];
  demo_unlocks: ('solution' | 'life')[];
  records: { concern: string; day: string; feedback: 'good' | 'ordinary' | 'hard' }[];
  paused: boolean;
  helpful: boolean | null;
  large_text: boolean;
  checks: string[];
  taste: {
    style: 'any' | 'warm' | 'soft' | 'cool';
    category: 'all' | 'bracelet' | 'crystal' | 'charm';
    budget: number;
  };
  demo_orders: {
    id: string;
    product: string;
    size: string;
    quantity: number;
    total: number;
    day: string;
  }[];
}
export const defaultCompanion: CompanionState = {
  concern: null,
  option: null,
  topic: 'love',
  period: 'today',
  mood: 'steady',
  frequency: 'off',
  routine: 'day',
  reminder_time: '09:00',
  wish: '',
  favorites: [],
  demo_unlocks: [],
  records: [],
  paused: false,
  helpful: null,
  large_text: false,
  checks: [],
  taste: { style: 'any', category: 'all', budget: 1000 },
  demo_orders: [],
};

export function cleanCompanion(raw: unknown): CompanionState {
  if (!raw || typeof raw !== 'object' || Array.isArray(raw)) return { ...defaultCompanion };
  const value = raw as Record<string, unknown>;
  const one = <T extends string>(key: string, choices: readonly T[], fallback: T): T =>
    choices.includes(value[key] as T) ? (value[key] as T) : fallback;
  const ids = zh.concernLibrary.map((c) => c.id);
  const taste =
    value.taste && typeof value.taste === 'object' ? (value.taste as Record<string, unknown>) : {};
  const records: CompanionState['records'] = [];
  if (Array.isArray(value.records))
    for (const row of value.records) {
      if (
        row &&
        ids.includes(row.concern) &&
        /^\d{4}-\d{2}-\d{2}$/.test(row.day) &&
        row.day <= bangkokDay() &&
        ['good', 'ordinary', 'hard'].includes(row.feedback) &&
        !records.some((r) => r.concern === row.concern && r.day === row.day) &&
        records.filter((r) => r.concern === row.concern).length < 7
      )
        records.push({ concern: row.concern, day: row.day, feedback: row.feedback });
    }
  return {
    taste: {
      style: ['any', 'warm', 'soft', 'cool'].includes(String(taste.style))
        ? (taste.style as CompanionState['taste']['style'])
        : 'any',
      category: ['all', 'bracelet', 'crystal', 'charm'].includes(String(taste.category))
        ? (taste.category as CompanionState['taste']['category'])
        : 'all',
      budget: [300, 500, 1000].includes(Number(taste.budget)) ? Number(taste.budget) : 1000,
    },
    demo_orders: Array.isArray(value.demo_orders)
      ? value.demo_orders
          .filter(
            (row) =>
              row &&
              typeof row.id === 'string' &&
              /^[a-zA-Z0-9-]{1,64}$/.test(row.id) &&
              zh.products.some((p) => p.id === row.product) &&
              ['14 cm', '16 cm', '18 cm', 'standard'].includes(row.size) &&
              Number.isInteger(row.quantity) &&
              row.quantity >= 1 &&
              row.quantity <= 9 &&
              Number.isInteger(row.total) &&
              row.total > 0 &&
              row.total <= 100000 &&
              /^\d{4}-\d{2}-\d{2}$/.test(row.day) &&
              row.day <= bangkokDay(),
          )
          .slice(-20)
          .map((row) => ({
            id: row.id,
            product: row.product,
            size: row.size,
            quantity: row.quantity,
            total: row.total,
            day: row.day,
          }))
      : [],
    concern: ids.includes(String(value.concern)) ? String(value.concern) : null,
    option: value.option === 'a' || value.option === 'b' ? value.option : null,
    topic: one('topic', ['love', 'money', 'family', 'work'], 'love'),
    period: one('period', ['today', 'week', 'month'], 'today'),
    mood: one('mood', ['steady', 'ready', 'tired'], 'steady'),
    frequency: one('frequency', ['off', 'daily', 'weekly'], 'off'),
    routine: one('routine', ['day', 'late'], 'day'),
    reminder_time:
      typeof value.reminder_time === 'string' &&
      /^([01]\d|2[0-3]):[0-5]\d$/.test(value.reminder_time)
        ? value.reminder_time
        : '09:00',
    wish: typeof value.wish === 'string' ? value.wish.slice(0, 1000) : '',
    favorites: Array.isArray(value.favorites)
      ? [
          ...new Set(
            value.favorites.filter((id): id is string => zh.products.some((p) => p.id === id)),
          ),
        ].slice(0, 6)
      : [],
    demo_unlocks: Array.isArray(value.demo_unlocks)
      ? [
          ...new Set(
            value.demo_unlocks.filter(
              (id): id is 'solution' | 'life' => id === 'solution' || id === 'life',
            ),
          ),
        ]
      : [],
    records,
    paused: value.paused === true,
    helpful: typeof value.helpful === 'boolean' ? value.helpful : null,
    large_text: value.large_text === true,
    checks: Array.isArray(value.checks)
      ? [
          ...new Set(
            value.checks.filter(
              (c): c is string =>
                typeof c === 'string' &&
                /^\d{4}-\d{2}-\d{2}:[a-z_]+:[0-2]$/.test(c) &&
                ids.includes(c.split(':')[1]),
            ),
          ),
        ].slice(-210)
      : [],
  };
}
