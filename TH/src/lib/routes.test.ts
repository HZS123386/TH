import { act, renderHook } from '@testing-library/react';
import { afterEach, expect, it, vi } from 'vitest';
import { usePageRoute, viewForPath } from './routes';

afterEach(() => vi.restoreAllMocks());
it('opens JY links using the React screens, including the existing service aliases', () => {
  expect(viewForPath('/fortune')).toBe('overview');
  expect(viewForPath('/profile')).toBe('mine');
  expect(viewForPath('/birth')).toBe('profile');
  expect(viewForPath('/line-consult')).toBe('chat');
  expect(viewForPath('/readings/saved-turn')).toBe('chat');
  expect(viewForPath('/thai-chart/123')).toBe('chart');
  expect(viewForPath('/chart/reading')).toBe('chart-reading');
  expect(viewForPath('/chart/reading/')).toBe('chart-reading');
  expect(viewForPath('/plan')).toBe('solution');
  expect(viewForPath('/orders')).toBe('orders');
  expect(viewForPath('/orders/demo-1')).toBe('orders');
  expect(viewForPath('/example')).toBe('example');
  expect(viewForPath('/bazi-test')).toBe('thai-test');
  expect(viewForPath('/bazi-test/')).toBe('thai-test');
  expect(viewForPath('/thai-test')).toBe('thai-test');
  expect(viewForPath('/tools/bazi')).toBe('bazi-test');
});
it('preserves a page on refresh and reacts to browser Back without adding another history entry', () => {
  vi.spyOn(window, 'scrollTo').mockImplementation(() => {});
  history.replaceState(null, '', '/shop');
  const { result } = renderHook(() => usePageRoute());
  expect(result.current[0]).toBe('shop');
  act(() => result.current[1]('mine'));
  expect(location.pathname).toBe('/profile');
  const length = history.length;
  act(() => {
    history.replaceState(null, '', '/shop');
    window.dispatchEvent(new PopStateEvent('popstate'));
  });
  expect(result.current[0]).toBe('shop');
  expect(history.length).toBe(length);
});
