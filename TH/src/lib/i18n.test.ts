import { afterEach, describe, expect, it } from 'vitest';
import { changeLanguage, i18n, i18nReady, translations } from './i18n';
import { LANGUAGES, localeFor, normalizeLanguage } from './languages';

afterEach(() => changeLanguage('zh'));
describe('global language resources', () => {
  it('has complete, nonempty copy for every supported language', () => {
    const keys = Object.keys(translations.zh).sort();
    for (const option of LANGUAGES) {
      expect(Object.keys(translations[option.id]).sort()).toEqual(keys);
      expect(
        Object.values(translations[option.id]).every(
          (value) => typeof value === 'string' && value.trim(),
        ),
      ).toBe(true);
    }
  });
  it.each(LANGUAGES)('updates document and messages for $locale', async (option) => {
    await i18nReady;
    await changeLanguage(option.id);
    expect(document.documentElement.lang).toBe(option.locale);
    expect(document.title).toBe(translations[option.id].pageTitle);
    expect(i18n.t('login')).toBe(translations[option.id].login);
    expect(i18n.t('networkError')).toBe(translations[option.id].networkError);
  });
  it('uses US English consistently, including migrated English preferences', () => {
    expect(normalizeLanguage('en-GB')).toBe('en');
    expect(localeFor('en')).toBe('en-US');
    expect(translations.en.dateLocale).toBe('en-US');
    expect(LANGUAGES.find((item) => item.id === 'en')!.region).toBe('US');
    expect(normalizeLanguage('vi-VN')).toBe('vi');
    expect(normalizeLanguage('unsupported')).toBeNull();
  });
});
