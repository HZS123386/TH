import {
  BookOpen,
  CalendarDays,
  ChevronRight,
  Crown,
  Globe2,
  LogOut,
  ShieldCheck,
  Type,
  UserRound,
} from 'lucide-react';
import type { Account, Language, Profile } from '../types';
import type { Copy } from '../lib/i18n';
import { westernCopy } from '../lib/western';
import { BrandMark } from './BrandMark';

export function WesternProfile({
  language,
  t,
  account,
  profile,
  largeText,
  onBirth,
  onReports,
  onPurchases,
  onLanguages,
  onLargeText,
  onLogin,
  onLogout,
  onClear,
}: {
  language: Language;
  t: Copy;
  account: Account | null;
  profile: Profile | null;
  largeText: boolean;
  onBirth: () => void;
  onReports: () => void;
  onPurchases: () => void;
  onLanguages: () => void;
  onLargeText: (value: boolean) => void;
  onLogin: () => void;
  onLogout: () => void;
  onClear: () => void;
}) {
  const a = westernCopy(language);
  const rows = [
    { label: a.birth, icon: CalendarDays, action: onBirth },
    { label: a.reports, icon: BookOpen, action: onReports },
    { label: a.purchaseHistory, icon: Crown, action: onPurchases },
    { label: a.language, icon: Globe2, action: onLanguages },
  ];
  return (
    <div className="space-y-5" data-testid="western-profile">
      <h1 className="text-[24px] font-semibold leading-9">{a.mine}</h1>
      <section className="relative isolate overflow-hidden rounded-[24px] border border-gold/25 bg-[radial-gradient(ellipse_at_top_right,#49315c77,#20152f_80%)] p-5">
        <BrandMark className="absolute -right-5 -top-5 -z-10 h-44 w-44 opacity-10" />
        <div className="mb-4 flex items-center gap-3">
          <span className="grid h-12 w-12 place-items-center rounded-full border border-gold/25 bg-canvas/45 text-gold">
            <UserRound size={23} strokeWidth={1.3} />
          </span>
          <div>
            <h2 className="text-lg font-medium">
              {account?.username || profile?.display_name || a.guest}
            </h2>
            <p className="mt-1 text-[10px] text-gold/75">FATE · {account ? a.signedIn : a.guest}</p>
          </div>
        </div>
        <p className="text-xs leading-7 text-muted">{a.accountText}</p>
        <button onClick={account ? onBirth : onLogin} className="jy-outline mt-4 w-full">
          {account ? a.editBirth : t.login}
          <ChevronRight size={15} />
        </button>
      </section>
      <section className="rounded-[22px] border border-line bg-panel/60 px-4">
        {rows.map(({ label, icon: Icon, action }) => (
          <button
            key={label}
            onClick={action}
            className="flex min-h-[58px] w-full items-center gap-3 border-b border-line/65 py-3 text-left text-[13px] last:border-0"
          >
            <Icon size={18} strokeWidth={1.4} className="text-gold" />
            <span className="flex-1">{label}</span>
            <ChevronRight size={16} className="text-muted" />
          </button>
        ))}
      </section>
      <label className="flex min-h-16 items-center gap-3 rounded-2xl border border-line bg-panel/60 px-4 py-3">
        <Type size={18} strokeWidth={1.4} className="text-gold" />
        <span className="flex-1 text-[13px]">{a.largeText}</span>
        <input
          type="checkbox"
          aria-label={a.largeText}
          checked={largeText}
          onChange={(event) => onLargeText(event.target.checked)}
          className="h-5 w-5 accent-[#e4bc78]"
        />
      </label>
      <details className="rounded-2xl border border-line bg-panel/40 px-4 py-1">
        <summary className="flex min-h-12 cursor-pointer items-center gap-3 text-[13px]">
          <ShieldCheck size={18} className="text-gold" />
          {a.privacy}
        </summary>
        <p className="pb-3 text-xs leading-7 text-muted">{a.privacyText}</p>
        {profile && (
          <button
            onClick={onClear}
            className="mb-3 min-h-10 text-xs text-gold underline underline-offset-4"
          >
            {a.clearBirth}
          </button>
        )}
      </details>
      {account && (
        <button onClick={onLogout} className="jy-outline w-full">
          <LogOut size={16} />
          {t.logout}
        </button>
      )}
    </div>
  );
}
