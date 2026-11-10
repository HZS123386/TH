import { act, renderHook } from '@testing-library/react';
import { afterEach, expect, it, vi } from 'vitest';
import { usePageRoute, viewForPath } from './routes';

afterEach(() => vi.restoreAllMocks());
it('opens the Western-only first-version APP routes', () => {
  expect(viewForPath('/fortune')).toBe('overview');
  expect(viewForPath('/profile')).toBe('mine');
  expect(viewForPath('/birth')).toBe('profile');
  expect(viewForPath('/chart')).toBe('chart');
  expect(viewForPath('/reports/reading')).toBe('report');
  expect(viewForPath('/reports/reading/')).toBe('report');
  expect(viewForPath('/reports')).toBe('reports');
  expect(viewForPath('/login')).toBe('auth');
  expect(viewForPath('/orders')).toBe('orders');
  expect(viewForPath('/orders/demo-1')).toBe('orders');
  for (const path of ['/line-consult', '/thai-chart/123', '/bazi-test', '/thai-test', '/shop', '/tarot'])
    expect(viewForPath(path)).toBe('overview');
});
it('preserves a page on refresh and reacts to browser Back without adding another history entry', () => {
  vi.spyOn(window, 'scrollTo').mockImplementation(() => {});
  history.replaceState(null, '', '/reports');
  const { result } = renderHook(() => usePageRoute());
  expect(result.current[0]).toBe('reports');
  act(() => result.current[1]('mine'));
  expect(location.pathname).toBe('/profile');
  const length = history.length;
  act(() => {
    history.replaceState(null, '', '/reports');
    window.dispatchEvent(new PopStateEvent('popstate'));
  });
  expect(result.current[0]).toBe('reports');
  expect(history.length).toBe(length);
});
