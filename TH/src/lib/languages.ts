import type { Language } from '../types';

export const LANGUAGE_KEY = 'sabai.language';
export const LANGUAGE_CONFIRMED_KEY = 'sabai.languageConfirmed';
export const LANGUAGES = [
  { id: 'zh', locale: 'zh-CN', label: '简体中文', caption: 'Chinese · Simplified', region: 'CN' },
  { id: 'th', locale: 'th-TH', label: 'ภาษาไทย', caption: 'Thai · Thailand', region: 'TH' },
  { id: 'vi', locale: 'vi-VN', label: 'Tiếng Việt', caption: 'Vietnamese · Vietnam', region: 'VN' },
  {
    id: 'en',
    locale: 'en-US',
    label: 'English (US)',
    caption: 'English · United States',
    region: 'US',
  },
] as const;

export function normalizeLanguage(value: string | null | undefined): Language | null {
  const base = value?.toLowerCase().replace('_', '-').split('-')[0];
  return base === 'zh' || base === 'th' || base === 'vi' || base === 'en' ? base : null;
}
export function preferredLanguage(): Language {
  return (
    normalizeLanguage(localStorage.getItem(LANGUAGE_KEY)) ||
    normalizeLanguage(navigator.language) ||
    'zh'
  );
}
export function localeFor(language: Language) {
  return LANGUAGES.find((item) => item.id === language)!.locale;
}
