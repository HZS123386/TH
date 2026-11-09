import { act, cleanup, renderHook } from '@testing-library/react';
import { afterEach, expect, it, vi } from 'vitest';
import { api } from './api';
import { useFortune, type Fortune, type FortunePeriod } from './fortune';
import type { Profile } from '../types';

vi.mock('./api', () => ({ api: vi.fn() }));
const profile: Profile = {
  display_name: '',
  birth_date: '1999-02-20',
  birth_time: null,
  birthplace: '',
  timezone: 'Asia/Bangkok',
  language: 'zh',
};
afterEach(() => {
  cleanup();
  vi.useRealTimers();
  vi.resetAllMocks();
});

it('recalculates at Bangkok midnight while the page stays open', async () => {
  vi.useFakeTimers();
  vi.setSystemTime(new Date('2026-11-06T16:59:55Z'));
  vi.mocked(api).mockResolvedValue({ period: 'today', calendar: { date: '2026-11-06' } });
  const hook = renderHook(() => useFortune(profile, 'today', 'zh', 'guest'));
  await act(async () => {});
  expect(api).toHaveBeenCalledTimes(1);
  vi.mocked(api).mockResolvedValue({ period: 'today', calendar: { date: '2026-11-07' } });
  await act(async () => {
    await vi.advanceTimersByTimeAsync(5100);
  });
  expect(api).toHaveBeenCalledTimes(2);
  expect(hook.result.current.value?.calendar.date).toBe('2026-11-07');
});

it('refreshes after returning from a suspended tab without waiting for the next interval', async () => {
  vi.useFakeTimers();
  vi.setSystemTime(new Date('2026-11-06T15:00:00Z'));
  vi.mocked(api).mockResolvedValue({ period: 'today', calendar: { date: '2026-11-06' } });
  const hook = renderHook(() => useFortune(profile, 'today', 'zh', 'guest'));
  await act(async () => {});
  vi.setSystemTime(new Date('2026-11-06T18:00:00Z'));
  vi.mocked(api).mockResolvedValue({ period: 'today', calendar: { date: '2026-11-07' } });
  await act(async () => {
    document.dispatchEvent(new Event('visibilitychange'));
  });
  expect(api).toHaveBeenCalledTimes(2);
  expect(hook.result.current.value?.calendar.date).toBe('2026-11-07');
});

function facts(period: FortunePeriod = 'today', signature = 'current', ready = false): Fortune {
  return {
    period,
    period_start: '2026-11-06',
    period_end: '2026-11-06',
    calendar: { date: '2026-11-06' },
    analysis: { signature },
    narrative: {
      language: 'zh',
      source: ready ? 'ai' : 'rules',
      paragraphs: [ready ? 'Cached reading' : 'Reference reading'],
    },
    generation: { available: true, state: ready ? 'ready' : 'rules', cached: ready },
  } as Fortune;
}

function report(value: Fortune) {
  return {
    period: value.period,
    period_start: value.period_start,
    period_end: value.period_end,
    for_date: value.calendar.date,
    analysis_signature: value.analysis?.signature,
    narrative: { ...value.narrative, source: 'ai', paragraphs: ['New personalized reading'] },
    generation: { available: true, state: 'ready', cached: false },
  };
}

it('shows facts immediately and replaces only the matching narrative when writing finishes', async () => {
  let complete!: (value: unknown) => void;
  const value = facts();
  vi.mocked(api)
    .mockResolvedValueOnce(value)
    .mockReturnValueOnce(
      new Promise((resolve) => {
        complete = resolve;
      }),
    );
  const hook = renderHook(() => useFortune(profile, 'today', 'zh', 'guest'));
  await act(async () => {});
  expect(hook.result.current.loading).toBe(false);
  expect(hook.result.current.writing).toBe(true);
  expect(hook.result.current.value?.narrative.paragraphs).toEqual(['Reference reading']);
  const init = vi.mocked(api).mock.calls[1][1]!;
  expect(JSON.parse(init.body as string).for_date).toBe('2026-11-06');
  await act(async () => complete(report(value)));
  expect(hook.result.current.value?.narrative.paragraphs).toEqual(['New personalized reading']);
  expect(hook.result.current.writing).toBe(false);
});

it('prevents an old daily writer from overwriting a newly selected week', async () => {
  let complete!: (value: unknown) => void;
  const old = facts();
  vi.mocked(api)
    .mockResolvedValueOnce(old)
    .mockReturnValueOnce(
      new Promise((resolve) => {
        complete = resolve;
      }),
    )
    .mockResolvedValueOnce(facts('week', 'week', true));
  const hook = renderHook(({ period }) => useFortune(profile, period, 'zh', 'guest'), {
    initialProps: { period: 'today' as FortunePeriod },
  });
  await act(async () => {});
  const oldSignal = vi.mocked(api).mock.calls[1][1]!.signal;
  await act(async () => hook.rerender({ period: 'week' }));
  expect(oldSignal?.aborted).toBe(true);
  await act(async () => complete(report(old)));
  expect(hook.result.current.value?.period).toBe('week');
  expect(hook.result.current.value?.narrative.paragraphs).toEqual(['Cached reading']);
});

it('keeps reference facts usable when the model request fails and can retry from cache', async () => {
  vi.mocked(api)
    .mockResolvedValueOnce(facts())
    .mockRejectedValueOnce(new Error('upstream unavailable'))
    .mockResolvedValueOnce(facts('today', 'current', true));
  const hook = renderHook(() => useFortune(profile, 'today', 'zh', 'guest'));
  await act(async () => {});
  expect(hook.result.current.error).toBe('');
  expect(hook.result.current.value?.generation?.state).toBe('fallback');
  expect(hook.result.current.value?.narrative.source).toBe('rules');
  await act(async () => hook.result.current.retry());
  expect(hook.result.current.value?.generation?.state).toBe('ready');
  expect(api).toHaveBeenCalledTimes(3);
});

it('rejects mismatched report evidence instead of displaying it', async () => {
  const value = facts();
  vi.mocked(api)
    .mockResolvedValueOnce(value)
    .mockResolvedValueOnce({ ...report(value), analysis_signature: 'another-birth' });
  const hook = renderHook(() => useFortune(profile, 'today', 'zh', 'guest'));
  await act(async () => {});
  expect(hook.result.current.value?.narrative.source).toBe('rules');
  expect(hook.result.current.value?.generation?.state).toBe('fallback');
});

it('discards delayed responses after changing account, birthday and language', async () => {
  let complete!: (value: unknown) => void;
  const old = facts();
  vi.mocked(api)
    .mockResolvedValueOnce(old)
    .mockReturnValueOnce(
      new Promise((resolve) => {
        complete = resolve;
      }),
    )
    .mockResolvedValueOnce({
      ...facts('today', 'new-birth', true),
      narrative: { language: 'th', source: 'ai', paragraphs: ['คำอ่านใหม่'] },
    });
  const hook = renderHook(
    ({ owner, birth, language }) =>
      useFortune({ ...profile, birth_date: birth }, 'today', language, owner),
    {
      initialProps: {
        owner: 'account:a',
        birth: profile.birth_date,
        language: 'zh' as 'zh' | 'th',
      },
    },
  );
  await act(async () => {});
  await act(async () => hook.rerender({ owner: 'account:b', birth: '2001-03-11', language: 'th' }));
  await act(async () => complete(report(old)));
  expect(hook.result.current.value?.narrative.paragraphs).toEqual(['คำอ่านใหม่']);
});
