import { useCallback, useEffect, useRef, useState } from 'react';
import type { WanjaiView } from './wanjai';

export const viewPaths: Record<WanjaiView, string> = {
  overview: '/fortune',
  chart: '/chart',
  'chart-reading': '/chart/reading',
  'bazi-test': '/tools/bazi',
  'thai-test': '/thai-test',
  example: '/example',
  questions: '/questions',
  concern: '/reflection',
  daily: '/daily',
  journey: '/journey',
  solution: '/plan',
  life: '/life',
  shop: '/shop',
  mine: '/profile',
  share: '/share',
  favorites: '/favorites',
  inbox: '/messages',
  chat: '/consult',
  profile: '/birth',
  memories: '/memories',
  explore: '/explore',
  auth: '/login',
  orders: '/orders',
};

export function viewForPath(path: string): WanjaiView {
  if (path.replace(/\/$/, '') === '/bazi-test') return 'thai-test';
  const found = Object.entries(viewPaths).find(([, value]) => value === path.replace(/\/$/, ''));
  if (found) return found[0] as WanjaiView;
  if (/^\/(thai-chart|sun-sign)(\/|$)/.test(path)) return 'chart';
  if (/^\/(line-consult|readings|history)(\/|$)/.test(path)) return 'chat';
  if (path === '/settings') return 'mine';
  if (path === '/checkout') return 'shop';
  if (/^\/orders(\/|$)/.test(path)) return 'orders';
  return 'overview';
}

export function usePageRoute() {
  const [view, update] = useState(() => viewForPath(location.pathname));
  const current = useRef(view);
  useEffect(() => {
    const back = () => {
      current.current = viewForPath(location.pathname);
      update(current.current);
    };
    window.addEventListener('popstate', back);
    return () => window.removeEventListener('popstate', back);
  }, []);
  const setView = useCallback((value: WanjaiView | ((previous: WanjaiView) => WanjaiView)) => {
    const next = typeof value === 'function' ? value(current.current) : value;
    current.current = next;
    if (location.pathname !== viewPaths[next]) history.pushState(null, '', viewPaths[next]);
    update(next);
    window.scrollTo({ top: 0, behavior: 'instant' });
  }, []);
  return [view, setView] as const;
}
