import { useLayoutEffect, useRef, useState, type ReactNode } from 'react';
import {
  Bell,
  ArrowRight,
  BookOpen,
  Heart,
  LogOut,
  MessageCircle,
  MoreHorizontal,
  ShoppingBag,
  Sparkles,
  Sun,
  UserRound,
  LockKeyhole,
  X,
} from 'lucide-react';
import type { Copy } from '../lib/i18n';
import type { Language } from '../types';
import type { WanjaiView } from '../lib/wanjai';
import { BrandLockup } from './BrandLockup';
import { LanguageFlag } from './LanguageFlag';

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
  view: WanjaiView;
  navigate: (view: WanjaiView) => void;
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
  const group = ['questions', 'concern', 'solution', 'chat'].includes(view)
    ? 'chat'
    : ['profile', 'auth', 'memories', 'share', 'orders', 'bazi-test', 'thai-test'].includes(view)
      ? 'mine'
      : ['daily', 'journey', 'inbox'].includes(view)
        ? 'overview'
        : ['life', 'example', 'chart-reading'].includes(view)
          ? 'chart'
          : view === 'favorites'
            ? 'shop'
            : view;
  const items = [
    { id: 'overview', label: t.w_home, icon: Sun },
    { id: 'chart', label: t.w_chart, icon: Sparkles },
    { id: 'chat', label: t.w_questions, icon: MessageCircle },
    { id: 'shop', label: t.w_shop, icon: ShoppingBag },
    { id: 'mine', label: t.w_mine, icon: Heart },
  ] as const;
  const go = (next: WanjaiView) => {
    setMenu(false);
    navigate(next);
  };
  return (
    <div
      className="jy-app relative mx-auto min-h-svh w-full max-w-[430px] bg-[#f7f4ed] shadow-[0_0_70px_#40372d14]"
      data-layout="jy-react"
      data-screen={view}
    >
      <header className="sticky top-0 z-30 flex h-[62px] items-center justify-between gap-2 bg-[#f7f4ed]/95 px-[19px] backdrop-blur-xl">
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
          <button
            className="jy-icon"
            aria-label={t.w_inbox}
            disabled={disabled}
            onClick={() => go('inbox')}
          >
            <Bell size={20} />
          </button>
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
            className="fixed inset-0 z-30 bg-ink/20"
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
              { id: 'thai-test', label: t.th_readingTool },
              { id: 'questions', label: t.w_chooseQuestion },
              { id: 'daily', label: t.w_daily },
              { id: 'journey', label: t.w_journey },
              { id: 'memories', label: t.memories },
              { id: 'orders', label: t.j_orders },
              { id: 'explore', label: t.w_bazi },
            ].map((item) => (
              <button
                key={item.id}
                className="flex min-h-11 w-full items-center gap-3 border-t border-line py-2 text-left text-sm"
                disabled={disabled}
                onClick={() => go(item.id as WanjaiView)}
              >
                <BookOpen size={15} className="text-gold" />
                {item.label}
              </button>
            ))}
          </aside>
        </>
      )}
      <main
        className={view === 'chat' && !entry ? '' : 'px-[19px] pb-[110px] pt-3'}
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
            <div className="border-t border-[#e3d8c8] bg-[#f7f4ed]/95 px-[19px] py-3 backdrop-blur-xl">
              <button
                type="button"
                data-testid={
                  bottomAction.kind === 'unlock' ? 'thai-unlock-button' : 'chart-reading-button'
                }
                aria-controls={bottomAction.controls}
                aria-expanded={bottomAction.kind === 'unlock' ? false : undefined}
                className="jy-primary w-full shadow-[0_4px_16px_-8px_#8a3f31]"
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
            className="grid grid-cols-5 gap-1 border-t border-[#dfd6c5] bg-[#f6f0e5]/95 px-2 pb-[max(8px,env(safe-area-inset-bottom))] pt-1.5 backdrop-blur-xl"
          >
            {items.map(({ id, label, icon: Icon }) => (
              <button
                key={id}
                aria-current={group === id ? 'page' : undefined}
                disabled={disabled}
                className={`flex min-h-[62px] min-w-0 flex-col items-center justify-center gap-1 rounded-2xl px-0.5 text-[11px] ${group === id ? 'bg-[#ead7c6] text-accent' : 'text-[#73644f]'}`}
                onClick={() => go(id)}
              >
                <span
                  className={
                    id === 'chat' && group === id
                      ? 'rounded-xl bg-primary px-3 py-1 text-white'
                      : 'px-3 py-1'
                  }
                >
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
