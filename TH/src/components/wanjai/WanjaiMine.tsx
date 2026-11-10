import { useState } from 'react';
import {
  Bell,
  BookOpen,
  CalendarDays,
  ChevronRight,
  Download,
  Heart,
  Leaf,
  Star,
} from 'lucide-react';
import { type WanjaiView } from '../../lib/wanjai';
import { LANGUAGES } from '../../lib/languages';
import { PickerDialog } from '../PickerDialog';
import { WanjaiMark } from '../WanjaiArtwork';
import { brandColors, drawBrandMark } from '../../lib/brand';
import { type WanjaiPageProps, PageIntro, Note, usePage } from './WanjaiShared';

export function WanjaiMine(p: WanjaiPageProps) {
  const { t, state, update, navigate } = p;
  const { data, concern, solution } = usePage(p);
  const [wish, setWish] = useState<string | null>(null);
  const [forget, setForget] = useState(false);
  const [advisor, setAdvisor] = useState(false);
  const option = solution?.options.find((row) => row.id === state.option);
  const rows = [
    { view: 'reports', label: t.ux_reports, icon: BookOpen },
    { view: 'journey', label: t.w_journey, icon: CalendarDays },
    { view: 'shop', label: t.ux_shopPreview, icon: Star },
    { view: 'favorites', label: `${t.w_favorites} · ${state.favorites.length}`, icon: Heart },
    { view: 'orders', label: t.j_orders, icon: BookOpen },
    { view: 'daily', label: t.w_reminder, icon: Bell },
    { view: 'share', label: t.w_share, icon: Leaf },
  ];
  return (
    <div className="space-y-5" data-testid="jy-profile-page">
      <PageIntro title={t.j_mineTitle} sub={t.j_mineIntro} />
      <section className="relative overflow-hidden rounded-[22px] border border-line bg-surface p-6">
        <div className="absolute -right-6 -top-5 text-gold/30">
          <WanjaiMark className="h-40 w-40" />
        </div>
        <div className="relative">
          <p className="jy-kicker">
            {t.w_mine} · {p.account?.username || t.brandName}
          </p>
          <h2 className="my-3 text-[26px] leading-9">{p.profile?.display_name || t.brandName}</h2>
          <p className="text-sm text-muted">{p.profile?.birth_date || t.w_noBirth}</p>
          <p className="mb-5 mt-2 text-xs leading-6 text-muted">
            {p.profile?.birth_time || t.timeUnknown} · {p.profile?.birthplace || t.birthplace}
          </p>
          <button
            className="jy-outline !border-gold/35"
            aria-label={t.edit}
            onClick={() => navigate('profile')}
          >
            {t.j_editBirth}
            <ChevronRight size={15} />
          </button>
        </div>
      </section>
      <button
        className="flex w-full items-center gap-3 rounded-[17px] border border-line bg-surface p-4 text-left"
        onClick={() => navigate('chat')}
      >
        <span className="grid h-11 w-11 shrink-0 place-items-center rounded-[15px] bg-primary text-on-primary">
          <BookOpen size={23} />
        </span>
        <span className="flex-1">
          <b className="block text-[16px] font-medium">{t.j_continue}</b>
          <span className="mt-1 block text-xs leading-6 text-muted">{t.j_topicCaption}</span>
        </span>
        <ChevronRight size={16} />
      </button>
      {concern && (
        <section className="jy-card">
          <div className="mb-3 flex items-center justify-between gap-3">
            <h2 className="text-[16px]">{t.j_rememberContext}</h2>
            <button className="text-xs text-accent" onClick={() => navigate('questions')}>
              {t.edit}
            </button>
          </div>
          <p className="mb-2 text-sm leading-7">{concern.question}</p>
          <p className="jy-copy">{option?.summary || concern.lead}</p>
          <p className="mt-3 text-xs leading-6 text-muted">{t.w_savedContext}</p>
          <button
            className="mt-3 text-xs text-gold underline underline-offset-4"
            onClick={() => setForget(true)}
          >
            {t.j_forgetContext}
          </button>
        </section>
      )}
      <button
        className="jy-card flex w-full items-center justify-between text-left"
        onClick={() => navigate('shop')}
      >
        <div>
          <h2 className="text-[16px]">{t.j_myPreferences}</h2>
          <p className="mt-2 text-xs leading-6 text-muted">
            {
              t[
                ({ any: 'j_anyStyle', warm: 'j_warm', soft: 'j_soft', cool: 'j_cool' } as const)[
                  state.taste.style
                ]
              ]
            }{' '}
            · ฿{state.taste.budget}
          </p>
        </div>
        <ChevronRight size={16} className="text-gold" />
      </button>
      <section className="jy-card">
        <h2 className="mb-3 text-[16px]">{t.j_myFocus}</h2>
        <div className="grid grid-cols-2 gap-2">
          {data.topics.map((topic) => (
            <button
              key={topic.id}
              aria-pressed={state.topic === topic.id}
              className={`jy-outline !px-3 ${state.topic === topic.id ? '!border-primary !bg-surface !text-accent' : ''}`}
              onClick={() => update({ topic: topic.id as typeof state.topic })}
            >
              {topic.name}
            </button>
          ))}
        </div>
      </section>
      <section className="jy-card">
        <h2 className="mb-3 text-[17px]">{t.w_wish}</h2>
        {state.wish ? (
          <blockquote className="mb-4 rounded-xl bg-surface p-4 text-[15px] leading-8">
            “{state.wish}”
          </blockquote>
        ) : (
          <p className="jy-copy mb-4">{t.w_wishHint}</p>
        )}
        <button className="jy-outline" aria-label={t.w_wish} onClick={() => setWish(state.wish)}>
          {state.wish ? t.j_editWish : t.j_writeWish} ↗
        </button>
      </section>
      <section className="jy-card !py-1">
        {rows.map(({ view, label, icon: Icon }) => (
          <button key={view} className="jy-link" onClick={() => navigate(view as WanjaiView)}>
            <Icon size={18} className="shrink-0 text-gold" />
            <span className="flex-1">{label}</span>
            <ChevronRight size={15} className="text-muted" />
          </button>
        ))}
        <button className="jy-link" onClick={() => navigate('memories')}>
          <BookOpen size={18} className="text-gold" />
          <span className="flex-1">{t.memoryTitle}</span>
          <ChevronRight size={15} />
        </button>
      </section>
      <section className="jy-card">
        <div className="flex items-center justify-between gap-3">
          <div>
            <h2 className="text-[17px]">{t.languageLabel}</h2>
            <p className="mt-2 text-xs text-muted">
              {LANGUAGES.find((row) => row.id === p.language)?.label}
            </p>
          </div>
          <button className="jy-outline" aria-label={t.languageLabel} onClick={p.openLanguages}>
            {t.languageLabel}
            <ChevronRight size={15} />
          </button>
        </div>
        <label className="mt-5 flex items-center justify-between border-t border-line pt-4 text-sm">
          {t.w_readingSize}
          <input
            type="checkbox"
            className="h-5 w-5 accent-primary"
            checked={state.large_text}
            onChange={(e) => update({ large_text: e.target.checked })}
          />
        </label>
      </section>
      <details className="jy-card !p-4">
        <summary className="cursor-pointer text-sm text-muted">{t.w_about}</summary>
        <p className="my-4 text-xs leading-7 text-muted">
          {t.w_sunNote}
          <br />
          {t.w_lineOff}
          <br />
          {t.w_productNote}
          <br />
          {t.w_paymentNote}
        </p>
        <a
          className="jy-link text-accent"
          href="/reports/wanjai-feasibility.html"
          target="_blank"
          rel="noreferrer"
        >
          {t.w_feasibility} ↗
        </a>
        <a
          className="jy-link text-accent"
          href={`/reports/thai-validation.html?lang=${p.language}`}
          target="_blank"
          rel="noreferrer"
        >
          {t.th_validation} ↗
        </a>
        <button className="jy-link text-accent" onClick={() => setAdvisor(true)}>
          {t.w_advisor} ↗
        </button>
      </details>
      {wish !== null && (
        <PickerDialog
          title={t.w_wish}
          t={t}
          confirmLabel={t.w_save}
          onCancel={() => setWish(null)}
          onConfirm={() => {
            update({ wish });
            setWish(null);
          }}
        >
          <label htmlFor="my-wish" className="label">
            {t.w_wish}
          </label>
          <textarea
            id="my-wish"
            className="field min-h-36 resize-y"
            maxLength={1000}
            value={wish}
            onChange={(e) => setWish(e.target.value)}
            placeholder={t.w_wishHint}
          />
        </PickerDialog>
      )}
      {forget && (
        <PickerDialog
          title={t.j_forgetContext}
          t={t}
          onCancel={() => setForget(false)}
          onConfirm={() => {
            update({ concern: null, option: null });
            setForget(false);
          }}
        >
          <p className="jy-copy">{t.j_forgotNote}</p>
        </PickerDialog>
      )}
      {advisor && (
        <PickerDialog
          title={t.w_advisor}
          t={t}
          onCancel={() => setAdvisor(false)}
          onConfirm={() => setAdvisor(false)}
        >
          <p className="jy-copy">{t.w_advisorNote}</p>
        </PickerDialog>
      )}
    </div>
  );
}

export function WanjaiShare(p: WanjaiPageProps) {
  const { t } = p;
  async function download() {
    await document.fonts.ready;
    const canvas = document.createElement('canvas');
    canvas.width = 900;
    canvas.height = 1200;
    const ctx = canvas.getContext('2d');
    if (!ctx) return;
    ctx.fillStyle = brandColors.canvas;
    ctx.fillRect(0, 0, 900, 1200);
    ctx.strokeStyle = brandColors.gold;
    ctx.lineWidth = 2;
    ctx.strokeRect(48, 48, 804, 1104);
    ctx.fillStyle = brandColors.ink;
    ctx.textAlign = 'center';
    drawBrandMark(ctx, 394, 112, 112);
    ctx.font = '48px \"Noto Sans Thai\", \"Microsoft YaHei\", Georgia, serif';
    ctx.fillText(t.brandName, 450, 290);
    ctx.font = '32px "Noto Sans Thai", "Microsoft YaHei", sans-serif';
    let line = '',
      y = 450;
    for (const char of t.w_shareQuote) {
      if (ctx.measureText(line + char).width > 640) {
        ctx.fillText(line, 450, y);
        y += 64;
        line = char;
      } else line += char;
    }
    ctx.fillText(line, 450, y);
    ctx.fillStyle = brandColors.muted;
    ctx.font = '22px \"Noto Sans Thai\", \"Microsoft YaHei\", sans-serif';
    ctx.fillText(t.brandRitual, 450, 1000);
    canvas.toBlob((blob) => {
      if (!blob) return;
      const url = URL.createObjectURL(blob);
      const link = document.createElement('a');
      link.href = url;
      link.download = `${t.brandName}-a-little-comfort.png`;
      link.click();
      window.setTimeout(() => URL.revokeObjectURL(url), 1000);
    });
  }
  return (
    <div className="mx-auto max-w-xl">
      <PageIntro title={t.w_share} sub={t.w_shareIntro} />
      <div className="rounded-2xl border border-gold/40 bg-surface p-6 sm:p-8">
        <div className="border border-gold/50 px-6 py-14 text-center">
          <WanjaiMark className="mx-auto mb-5 h-14 w-14 text-accent" />
          <p className="font-display text-2xl tracking-[.15em] text-accent">{t.brandName}</p>
          <p className="my-14 font-display text-xl leading-[2.2]">{t.w_shareQuote}</p>
          <p className="text-[9px] tracking-[.18em] text-gold">{t.brandRitual}</p>
        </div>
      </div>
      <button className="btn-primary mt-6 w-full" onClick={download}>
        <Download size={17} />
        {t.w_download}
      </button>
      <Note>{t.w_shareNote}</Note>
    </div>
  );
}
