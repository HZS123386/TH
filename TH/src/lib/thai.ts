import type { ThaiHoroscope, HoroscopeTransitResult, AstrologyLocation } from 'thai-astrology';
import { useEffect, useState } from 'react';
import { api } from './api';
import type { Profile, ProfileRecord } from '../types';

export interface ThaiChart {
  status: 'ready' | 'time-unknown' | 'location-required';
  profile_revision: number;
  engine: {
    name: string;
    version: string;
    source: string;
    commit: string;
    rules: string;
    weekdayBoundary: string;
    planetaryFrameSeconds: number;
    houseSystem: string;
  };
  calendar: Pick<ThaiHoroscope['calendar'], 'civilWeekday' | 'thaiLunarDate'> & {
    astrologicalWeekday: number | null;
  };
  taksa: ThaiHoroscope['taksa'] | null;
  chart: ThaiHoroscope | null;
  location:
    (Omit<Partial<AstrologyLocation>, 'coordinateKind'> & { coordinateKind: string }) | null;
  time_known: boolean;
  required: string[];
  calculation_input?: {
    local_datetime: string;
    utc_datetime: string;
    utc_offset_seconds: number;
    time_zone: string;
    zodiac_model: 'suriyayatra-classical-longitudes';
    ascendant_model: 'sunrise-fixed-anto';
    house_system: 'whole-sign';
    relationship_model: 'sign-based';
  };
}
export interface ThaiTransits extends Pick<HoroscopeTransitResult, 'transit' | 'comparison'> {
  status: string;
  calculated_at: string;
  transit_location: string;
}
export function useThaiChart(
  userId: string | undefined,
  record: ProfileRecord | null,
  guestProfile: Profile | null = null,
) {
  const [result, setResult] = useState<{
    owner: string;
    revision: number;
    value: ThaiChart;
    key: string;
  } | null>(null);
  const [error, setError] = useState('');
  const [attempt, setAttempt] = useState(0);
  const [loading, setLoading] = useState(false);
  const revision = record?.revision ?? (guestProfile ? 0 : undefined);
  const serialized = !userId && guestProfile ? JSON.stringify(guestProfile) : '';
  const key = userId ? `${userId}:${revision}` : `guest:${serialized}`;
  useEffect(() => {
    const controller = new AbortController();
    setError('');
    if (revision === undefined || (!userId && !serialized)) {
      setLoading(false);
      return;
    }
    setLoading(true);
    void api<ThaiChart>(userId ? '/api/thai-chart' : '/api/thai-chart/preview', {
      signal: controller.signal,
      ...(userId ? {} : { method: 'POST', body: serialized }),
    })
      .then((value) => {
        if (!controller.signal.aborted && value.profile_revision === revision)
          setResult({ owner: userId || 'guest', revision, value, key });
      })
      .catch((cause: unknown) => {
        if (!controller.signal.aborted)
          setError(cause instanceof Error ? cause.message : String(cause));
      })
      .finally(() => {
        if (!controller.signal.aborted) setLoading(false);
      });
    return () => controller.abort();
  }, [userId, revision, serialized, key, attempt]);
  return {
    value: result?.key === key ? result.value : null,
    error,
    loading,
    retry: () => setAttempt((n) => n + 1),
  };
}

export const taksaKeys = [
  'boriwan',
  'ayu',
  'det',
  'si',
  'mula',
  'utsaha',
  'montri',
  'kalakini',
] as const;
export const taksaThai = ['บริวาร', 'อายุ', 'เดช', 'ศรี', 'มูละ', 'อุตสาหะ', 'มนตรี', 'กาลกิณี'];
export const planetNumbers: Record<number, string> = {
  1: 'sun',
  2: 'moon',
  3: 'mars',
  4: 'mercury',
  5: 'jupiter',
  6: 'venus',
  7: 'saturn',
  8: 'rahu',
  9: 'ketu',
  0: 'uranus',
};
export const thaiSignNames = [
  'เมษ',
  'พฤษภ',
  'มิถุน',
  'กรกฎ',
  'สิงห์',
  'กันย์',
  'ตุล',
  'พิจิก',
  'ธนู',
  'มกร',
  'กุมภ์',
  'มีน',
];
