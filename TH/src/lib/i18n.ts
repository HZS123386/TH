import { useMemo } from 'react';
import { createInstance } from 'i18next';
import { initReactI18next, useTranslation } from 'react-i18next';
import zh from '../locales/zh-CN.json';
import th from '../locales/th.json';
import vi from '../locales/vi.json';
import en from '../locales/en-US.json';
import { LANGUAGES, localeFor, normalizeLanguage, preferredLanguage } from './languages';
import type { Language } from '../types';

export type Copy = Record<keyof typeof zh, string>;
export const translations: Record<Language, Copy> = { zh, th, vi, en };
export const i18n = createInstance();
export const i18nReady = i18n.use(initReactI18next).init({
  resources: Object.fromEntries(
    LANGUAGES.map((item) => [item.locale, { translation: translations[item.id] }]),
  ),
  lng: localeFor(preferredLanguage()),
  supportedLngs: LANGUAGES.map((item) => item.locale),
  fallbackLng: 'en-US',
  load: 'currentOnly',
  keySeparator: false,
  interpolation: { escapeValue: false },
  initAsync: false,
});
function syncDocument(locale: string) {
  document.documentElement.lang = locale;
  document.title = i18n.t('pageTitle');
  document
    .querySelector('meta[name="description"]')
    ?.setAttribute('content', `${i18n.t('brandName')} · ${i18n.t('brandDescription')}`);
}
i18n.on('languageChanged', syncDocument);
void i18nReady.then(() => {
  syncDocument(i18n.language);
});

export function useLocale() {
  const { t: translate, i18n: instance } = useTranslation();
  const language = normalizeLanguage(instance.resolvedLanguage) || 'en';
  // i18next owns lookup and fallback; presentational components keep typed copy.
  const t = useMemo(
    () => Object.fromEntries(Object.keys(zh).map((key) => [key, translate(key)])) as Copy,
    [translate],
  );
  return { language, t };
}
export async function changeLanguage(language: Language) {
  await i18n.changeLanguage(localeFor(language));
}
