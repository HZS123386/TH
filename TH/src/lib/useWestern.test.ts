import { act, renderHook, waitFor } from '@testing-library/react';
import { afterEach, describe, expect, it, vi } from 'vitest';
import type { Config } from '../types';
import { useWestern } from './useWestern';
import { westernExample } from './western';
import * as westernApi from './western';

const config = (status: 'ready' | 'planned') =>
  ({ modules: [{ id: 'western_astrology', status }] }) as Config;
const profile = { profile_id: 'profile-a', revision: 1 };
afterEach(() => vi.restoreAllMocks());
describe('Western request state', () => {
  it('does not call a paid or unrelated calculation while Western is unavailable', async () => {
    const request = vi.spyOn(westernApi, 'requestWesternCalculation');
    const { result } = renderHook(() => useWestern(config('planned'), profile, 'zh', 'a'));
    await act(() => result.current.calculate());
    expect(result.current.status).toBe('unavailable');
    expect(request).not.toHaveBeenCalled();
  });
  it('prevents double submission and discards a response after an account change', async () => {
    let resolve!: (value: typeof westernExample) => void;
    const request = vi.spyOn(westernApi, 'requestWesternCalculation').mockReturnValue(
      new Promise((done) => {
        resolve = done;
      }),
    );
    const { result, rerender } = renderHook(
      ({ owner }) => useWestern(config('ready'), profile, 'zh', owner),
      { initialProps: { owner: 'a' } },
    );
    let pending!: Promise<void>;
    act(() => {
      pending = result.current.calculate();
      void result.current.calculate();
    });
    expect(request).toHaveBeenCalledTimes(1);
    rerender({ owner: 'b' });
    expect(result.current.result).toBeNull();
    await act(async () => {
      resolve(westernExample);
      await pending;
    });
    expect(result.current.result).toBeNull();
    expect(request.mock.calls[0][2]?.aborted).toBe(true);
  });
  it('reuses the idempotency key on a retry of the same operation', async () => {
    const request = vi
      .spyOn(westernApi, 'requestWesternCalculation')
      .mockRejectedValueOnce(new Error('network'))
      .mockResolvedValue(westernExample);
    const { result } = renderHook(() => useWestern(config('ready'), profile, 'zh', 'a'));
    await act(() => result.current.calculate());
    expect(result.current.status).toBe('error');
    await act(() => result.current.calculate());
    await waitFor(() => expect(result.current.result).toEqual(westernExample));
    expect(request.mock.calls[0][1]).toBe(request.mock.calls[1][1]);
  });
});
