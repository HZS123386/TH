import { type ReactNode } from 'react';
import {
  ArrowRight,
  BookOpen,
  BriefcaseBusiness,
  Heart,
  House,
  Leaf,
  Sparkles,
  Wallet,
} from 'lucide-react';
import { useLocale, type Copy as UiCopy } from '../../lib/i18n';
import type { Account, Language, Profile, ProfileRecord } from '../../types';
import { contentFor, type CompanionState, type WanjaiView } from '../../lib/wanjai';
import type { useThaiChart } from '../../lib/thai';

export interface WanjaiPageProps {
  view: WanjaiView;
  language: Language;
  t: UiCopy;
  state: CompanionState;
  update: (patch: Partial<CompanionState>) => void;
  record: ProfileRecord | null;
  profile: Profile | null;
  account: Account | null;
  thai: ReturnType<typeof useThaiChart>;
  navigate: (view: WanjaiView) => void;
  openLanguages: () => void;
  ask: (question: string) => void;
  children?: ReactNode;
}

export const topicIcons = { love: Heart, money: Wallet, family: House, work: BriefcaseBusiness };

export const concernIcons = [
  Wallet,
  BriefcaseBusiness,
  Heart,
  BookOpen,
  BriefcaseBusiness,
  House,
  Heart,
  Heart,
  Leaf,
  Sparkles,
];

export const feedbackNames = { good: 'w_good', ordinary: 'w_ordinary', hard: 'w_hard' } as const;

export const palettes = [
  ['#cba482', '#f2e8d5'],
  ['#99a58b', '#d8c9ae'],
  ['#8dabb5', '#d7d6cf'],
  ['#c69e9a', '#d9c8aa'],
];

export function PageIntro({ title, sub }: { title: string; sub?: string }) {
  const { t } = useLocale();
  return (
    <header className="mb-5 mt-1">
      <p className="jy-kicker">{t.brandTagline}</p>
      <h1 className="jy-title mt-1">{title}</h1>
      {sub && <p className="jy-copy mt-2">{sub}</p>}
    </header>
  );
}

export function ArrowButton({
  children,
  onClick,
  quiet = false,
}: {
  children: ReactNode;
  onClick: () => void;
  quiet?: boolean;
}) {
  return (
    <button type="button" className={quiet ? 'btn-quiet' : 'btn-primary'} onClick={onClick}>
      {children}
      <ArrowRight size={16} />
    </button>
  );
}

export function Note({ children }: { children: ReactNode }) {
  return <p className="mt-5 text-xs leading-6 text-muted">{children}</p>;
}

export function usePage(p: WanjaiPageProps) {
  const data = contentFor(p.language);
  const index = p.thai.value?.chart?.points.ascendant.sign ?? null;
  const concern = data.concernLibrary.find((c) => c.id === p.state.concern);
  const solution = concern
    ? data.solutionLibrary[concern.id as keyof typeof data.solutionLibrary]
    : null;
  return {
    data,
    sign: index === null ? null : data.signs[index],
    signIndex: index,
    concern,
    solution,
  };
}
