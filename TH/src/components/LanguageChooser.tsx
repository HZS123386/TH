import { useEffect, useRef, useState, type FormEvent } from 'react';
import { ArrowLeft, ArrowRight, Check, Globe2, LoaderCircle } from 'lucide-react';
import type { Language } from '../types';
import type { Copy } from '../lib/i18n';
import { LANGUAGES } from '../lib/languages';
import { BrandLockup } from './BrandLockup';
import { LanguageFlag } from './LanguageFlag';
import { ZodiacWheel } from './ZodiacWheel';

export function LanguageChooser({
  language,
  t,
  canCancel,
  onPreview,
  onConfirm,
  onCancel,
}: {
  language: Language;
  t: Copy;
  canCancel: boolean;
  onPreview: (language: Language) => Promise<void>;
  onConfirm: () => Promise<void>;
  onCancel: () => void;
}) {
  const [pending, setPending] = useState(false);
  const [error, setError] = useState('');
  const dialog = useRef<HTMLDialogElement>(null);
  const heading = useRef<HTMLHeadingElement>(null);
  useEffect(() => {
    const panel = dialog.current;
    const previousOverflow = document.body.style.overflow;
    document.body.style.overflow = 'hidden';
    panel?.showModal();
    heading.current?.focus();
    return () => {
      panel?.close();
      document.body.style.overflow = previousOverflow;
    };
  }, []);
  async function submit(event: FormEvent) {
    event.preventDefault();
    setPending(true);
    setError('');
    try {
      await onConfirm();
    } catch (err) {
      setError(err instanceof Error ? err.message : t.requestFailed);
    } finally {
      setPending(false);
    }
  }
  return (
    <dialog
      ref={dialog}
      className="language-dialog fixed inset-0 m-auto max-h-[calc(100dvh_-_24px)] w-[calc(100%_-_24px)] max-w-[520px] overflow-hidden rounded-[28px] border border-gold/35 bg-panel p-0 text-ink shadow-[0_24px_90px_-28px_rgb(86_61_33_/_0.38)] languageTight:rounded-[22px] languageWide:max-w-[640px]"
      aria-labelledby="language-title"
      aria-describedby="language-subtitle"
      aria-modal="true"
      onCancel={(event) => {
        event.preventDefault();
        if (canCancel && !pending) onCancel();
      }}
    >
      <form onSubmit={submit} className="flex min-w-0 flex-col">
        <div className="relative isolate min-w-0 px-5 py-5 sm:px-7 languageCompact:px-[16px] languageCompact:py-[16px] languageTight:px-[12px] languageTight:py-[12px] languageWide:px-[12px] languageWide:py-[10px]">
          <div className="mb-4 flex min-w-0 items-center justify-between gap-3 languageCompact:mb-3 languageTight:mb-2 languageWide:mb-1.5 languageTiny:mb-0">
            <span className="min-w-0 languageTiny:hidden">
              <BrandLockup t={t} compact />
            </span>
            {canCancel && (
              <button
                type="button"
                className="btn-quiet !px-2 !text-xs"
                onClick={onCancel}
                disabled={pending}
              >
                <ArrowLeft size={15} />
                {t.back}
              </button>
            )}
          </div>
          <div
            aria-hidden="true"
            className="pointer-events-none absolute inset-0 -z-10 overflow-hidden"
          >
            <ZodiacWheel monochrome className="absolute -right-14 top-16 h-56 w-56 text-gold/10" />
          </div>
          <div className="mb-4 min-w-0 languageCompact:mb-3 languageTight:mb-2">
            <p className="mb-1 text-[10px] tracking-[.12em] text-gold languageTight:hidden">
              {t.languageEyebrow}
            </p>
            <h1
              ref={heading}
              tabIndex={-1}
              id="language-title"
              className="break-words font-display text-[27px] font-semibold leading-[1.25] outline-none languageCompact:text-[25px] languageTight:text-[24px] languageWide:text-[22px] languageTiny:text-[20px]"
            >
              {t.selectLanguage}
            </h1>
            <p
              id="language-subtitle"
              className="mt-2 max-w-md text-[13px] leading-[20px] text-muted languageCompact:mt-1 languageCompact:text-[12px] languageCompact:leading-[18px] languageTight:hidden"
            >
              {t.languageSubtitle}
            </p>
          </div>
          <fieldset
            disabled={pending}
            className="grid min-w-0 grid-cols-1 gap-[10px] languageCompact:gap-[8px] languageTight:gap-[6px] languageWide:grid-cols-2"
            aria-label={t.selectLanguage}
          >
            {LANGUAGES.map((item) => (
              <label
                key={item.id}
                className={`group relative flex min-h-[72px] min-w-0 cursor-pointer items-center gap-3 rounded-2xl border px-4 py-3 transition-colors languageCompact:min-h-[62px] languageCompact:px-[12px] languageCompact:py-[8px] languageTight:min-h-[54px] languageTight:gap-[8px] languageTight:py-[6px] languageWide:min-h-[56px] languageWide:px-[8px] ${language === item.id ? 'border-accent/65 bg-surface ring-1 ring-accent/10' : 'border-line bg-canvas/60 hover:border-gold/60 hover:bg-panel'}`}
              >
                <input
                  type="radio"
                  name="interface-language"
                  value={item.id}
                  checked={language === item.id}
                  onChange={() => {
                    setError('');
                    void onPreview(item.id).catch((cause: unknown) => {
                      setError(cause instanceof Error ? cause.message : t.requestFailed);
                    });
                  }}
                  className="peer absolute inset-0 z-10 m-0 h-full w-full cursor-pointer appearance-none rounded-2xl opacity-0 disabled:cursor-wait"
                />
                <LanguageFlag
                  language={item.id}
                  className="h-[40px] w-[40px] shrink-0 languageCompact:h-[36px] languageCompact:w-[36px] languageTight:h-[32px] languageTight:w-[32px] languageWide:h-[28px] languageWide:w-[28px]"
                />
                <span className="min-w-0 flex-1">
                  <span
                    lang={item.locale}
                    className="block break-words text-[16px] font-semibold leading-[24px] text-ink languageCompact:text-[15px] languageTight:text-[14px] languageTight:leading-[20px] languageWide:text-[13px] languageWide:leading-[18px]"
                  >
                    {item.label}
                  </span>
                  <span className="mt-1 block text-[10px] tracking-wide text-muted languageCompact:mt-0 languageTight:hidden">
                    {item.caption}
                  </span>
                </span>
                <span
                  className={`flex h-[24px] w-[24px] shrink-0 items-center justify-center rounded-full border peer-focus-visible:ring-2 peer-focus-visible:ring-accent peer-focus-visible:ring-offset-4 peer-focus-visible:ring-offset-panel languageTight:h-[20px] languageTight:w-[20px] languageWide:h-[18px] languageWide:w-[18px] ${language === item.id ? 'border-primary bg-primary text-on-primary' : 'border-line bg-panel text-muted'}`}
                >
                  {language === item.id && <Check size={16} strokeWidth={2.5} />}
                </span>
              </label>
            ))}
          </fieldset>
          {error && (
            <p
              role="alert"
              className="mt-3 break-words text-[12px] leading-[18px] text-accent languageTight:mt-2"
            >
              {error}
            </p>
          )}
        </div>
        <div className="min-w-0 shrink-0 border-t border-line bg-panel px-5 py-4 sm:px-7 languageCompact:px-[16px] languageCompact:py-[12px] languageTight:px-[12px] languageTight:py-[10px]">
          <button
            type="submit"
            className="btn-primary min-h-[44px] w-full min-w-0 !gap-2 !rounded-xl !px-3 !py-[12px] text-[14px] leading-[20px] languageTight:!py-[8px] languageWide:text-[13px]"
            disabled={pending}
          >
            {pending ? <LoaderCircle size={17} className="animate-spin" /> : <Globe2 size={16} />}
            <span className="min-w-0 flex-1">{t.confirmLanguage}</span>
            <ArrowRight size={17} />
          </button>
          <p className="mx-auto mt-2 max-w-md text-center text-[11px] leading-[18px] text-muted languageTight:hidden">
            {t.languageSaved}
          </p>
        </div>
      </form>
    </dialog>
  );
}
