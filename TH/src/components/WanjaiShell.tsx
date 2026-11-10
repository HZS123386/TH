import { useLayoutEffect, useRef, useState, type CSSProperties, type ReactNode } from 'react';
import {
  ArrowRight,
  BookOpen,
  House,
  LogOut,
  MoreHorizontal,
  Orbit,
  UserRound,
  LockKeyhole,
  X,
} from 'lucide-react';
import type { Copy } from '../lib/i18n';
import type { Language } from '../types';
import type { AppView } from '../lib/routes';
import { westernCopy } from '../lib/western';
import { BrandLockup } from './BrandLockup';
import { LanguageFlag } from './LanguageFlag';
import { Starfield } from './Starfield';

export interface WanjaiBottomAction {
  label: string;
  onClick: () => void;
  kind?: 'unlock';
  controls?: string;
}

export function WanjaiShell({
  children,
  t,
  language,
  view,
  navigate,
  onLanguages,
  onLogout,
  signedIn,
  disabled,
  busy,
  entry,
  bottomAction,
}: {
  children: ReactNode;
  t: Copy;
  language: Language;
  view: AppView;
  navigate: (view: AppView) => void;
  onLanguages: () => void;
  onLogout: () => void;
  signedIn: boolean;
  disabled: boolean;
  busy: boolean;
  entry: boolean;
  bottomAction?: WanjaiBottomAction;
}) {
  const [menu, setMenu] = useState(false);
  const bottomRef = useRef<HTMLDivElement>(null);
  const [bottomHeight, setBottomHeight] = useState(0);
  useLayoutEffect(() => {
    const footer = bottomRef.current;
    if (!footer) return;
    const measure = () => setBottomHeight(footer.getBoundingClientRect().height);
    measure();
    const observer = new ResizeObserver(measure);
    observer.observe(footer);
    return () => observer.disconnect();
  }, [entry]);
  const a = westernCopy(language);
  const group = ['profile', 'auth', 'orders'].includes(view) ? 'mine' : view === 'report' ? 'reports' : view;
  const items = [
    { id: 'overview', label: a.home, icon: House },
    { id: 'chart', label: a.chart, icon: Orbit },
    { id: 'reports', label: a.reports, icon: BookOpen },
    { id: 'mine', label: a.mine, icon: UserRound },
  ] as const;
  const go = (next: AppView) => {
    setMenu(false);
    navigate(next);
  };
  return (
    <div
      className="jy-app relative isolate mx-auto min-h-svh w-full max-w-[430px] bg-canvas shadow-[0_0_80px_#00000055]"
      data-layout="jy-react"
      data-screen={view}
      style={{ '--app-nav-height': `${bottomHeight || 82}px` } as CSSProperties}
    >
      <Starfield compact />
      <header className="sticky top-0 z-30 flex h-[62px] items-center justify-between gap-2 border-b border-gold/10 bg-canvas/95 px-[19px] backdrop-blur-xl">
        <button
          onClick={() => go('overview')}
          aria-label={t.homeLabel}
          className="min-w-0 text-left"
        >
          <BrandLockup t={t} compact />
        </button>
        <div className="flex shrink-0 items-center gap-0.5">
          {view !== 'mine' && (
            <button className="jy-icon" aria-label={t.languageLabel} onClick={onLanguages}>
              <LanguageFlag language={language} className="h-5 w-5" />
            </button>
          )}
          {signedIn ? (
            <button className="jy-icon" aria-label={t.logout} disabled={busy} onClick={onLogout}>
              <LogOut size={18} />
            </button>
          ) : (
            <button className="jy-icon" aria-label={t.login} onClick={() => go('auth')}>
              <UserRound size={19} />
            </button>
          )}
          <button
            className="jy-icon -mr-2"
            aria-label={t.openNavigation}
            aria-expanded={menu}
            onClick={() => setMenu(!menu)}
          >
            <MoreHorizontal size={20} />
          </button>
        </div>
      </header>
      {menu && (
        <>
          <button
            className="fixed inset-0 z-30 bg-night/70"
            aria-label={t.closeNavigation}
            onClick={() => setMenu(false)}
          />
          <aside
            aria-label={t.workspace}
            className="absolute right-3 top-[56px] z-40 w-64 rounded-2xl border border-line bg-panel p-4 shadow-xl"
          >
            <div className="mb-3 flex items-center justify-between text-sm">
              <span>{t.brandSpace}</span>
              <button aria-label={t.closeNavigation} onClick={() => setMenu(false)}>
                <X size={18} />
              </button>
            </div>
            {[
              { id: 'chart', label: a.myChart },
              { id: 'reports', label: a.reports },
              { id: 'profile', label: a.birth },
              { id: 'orders', label: a.purchaseHistory },
              { id: 'mine', label: a.mine },
            ].map((item) => (
              <button
                key={item.id}
                className="flex min-h-11 w-full items-center gap-3 border-t border-line py-2 text-left text-sm"
                disabled={disabled}
                onClick={() => go(item.id as AppView)}
              >
                <BookOpen size={15} className="text-gold" />
                {item.label}
              </button>
            ))}
          </aside>
        </>
      )}
      <main
        className="relative z-10 px-[19px] pb-[110px] pt-3"
        style={bottomAction ? { paddingBottom: bottomHeight + 24 } : undefined}
      >
        {children}
      </main>
      {!entry && (
        <div
          ref={bottomRef}
          className="fixed bottom-0 left-1/2 z-30 w-full max-w-[430px] -translate-x-1/2"
        >
          {bottomAction && (
            <div className="border-t border-line bg-panel/95 px-[19px] py-3 backdrop-blur-xl">
              <button
                type="button"
                data-testid={
                  bottomAction.kind === 'unlock' ? 'thai-unlock-button' : 'chart-reading-button'
                }
                aria-controls={bottomAction.controls}
                aria-expanded={bottomAction.kind === 'unlock' ? false : undefined}
                className="jy-primary w-full shadow-[0_4px_20px_-10px_#e4bc7866]"
                onClick={() => {
                  setMenu(false);
                  bottomAction.onClick();
                }}
              >
                {bottomAction.kind === 'unlock' ? (
                  <LockKeyhole size={18} className="shrink-0" />
                ) : (
                  <BookOpen size={18} className="shrink-0" />
                )}
                <span className="flex-1">{bottomAction.label}</span>
                <ArrowRight size={18} className="shrink-0" />
              </button>
            </div>
          )}
          <nav
            aria-label={t.workspace}
            className="grid grid-cols-4 gap-1 border-t border-line bg-panel/95 px-2 pb-[max(8px,env(safe-area-inset-bottom))] pt-1.5 backdrop-blur-xl"
          >
            {items.map(({ id, label, icon: Icon }) => (
              <button
                key={id}
                aria-current={group === id ? 'page' : undefined}
                disabled={disabled}
                className={`flex min-h-[62px] min-w-0 flex-col items-center justify-center gap-1 rounded-2xl px-0.5 text-[11px] ${group === id ? 'bg-surface text-accent' : 'text-muted'}`}
                onClick={() => go(id)}
              >
                <span className="px-3 py-1">
                  <Icon size={21} strokeWidth={1.5} />
                </span>
                <span>{label}</span>
              </button>
            ))}
          </nav>
        </div>
      )}
    </div>
  );
}
