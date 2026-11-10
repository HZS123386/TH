import { useCallback, useEffect, useRef, useState } from 'react';
export type AppView = 'overview' | 'chart' | 'reports' | 'report' | 'mine' | 'auth' | 'profile' | 'orders';

export const viewPaths: Record<AppView, string> = {
  overview: '/fortune',
  chart: '/chart',
  reports: '/reports',
  report: '/reports/reading',
  mine: '/profile',
  profile: '/birth',
  auth: '/login',
  orders: '/orders',
};

export function viewForPath(path: string): AppView {
  const found = Object.entries(viewPaths).find(([, value]) => value === path.replace(/\/$/, ''));
  if (found) return found[0] as AppView;
  if (path === '/settings') return 'mine';
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
  const setView = useCallback((value: AppView | ((previous: AppView) => AppView)) => {
    const next = typeof value === 'function' ? value(current.current) : value;
    current.current = next;
    if (location.pathname !== viewPaths[next]) history.pushState(null, '', viewPaths[next]);
    update(next);
    window.scrollTo({ top: 0, behavior: 'instant' });
  }, []);
  return [view, setView] as const;
}
