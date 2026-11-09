import type { Language } from '../types';
import terms from '../content/bazi-terms.json';
const { stems, branches, stemNames, branchNames, elementNames, godIds, godNames } = terms;
export const baziFactorNames = terms.baziFactorNames;
export const baziElementName = (value: unknown, language: Language) => {
  const index = ['木', '火', '土', '金', '水'].indexOf(String(value));
  const english = ['wood', 'fire', 'earth', 'metal', 'water'].indexOf(String(value).toLowerCase());
  return elementNames[language][index >= 0 ? index : english] || '—';
};
export const baziStemName = (value: unknown, language: Language) =>
  stemNames[language][stems.indexOf(String(value))] || '—';
export function baziPillarName(value: string | null | undefined, language: Language) {
  if (!value || value.length !== 2) return '—';
  const stem = baziStemName(value[0], language),
    branch = branchNames[language][branches.indexOf(value[1])] || '—';
  return stem + (language === 'zh' ? '' : ' ') + branch;
}
export function baziProseMatches(text: unknown, language: Language): text is string {
  if (typeof text !== 'string' || !text.trim()) return false;
  const cjk = /[\u3400-\u9fff]/.test(text),
    thai = /[\u0e00-\u0e7f]/.test(text),
    latin = /[a-zA-Z]/.test(text);
  const vietnamese = /[\u1ea0-\u1ef9ăâđêôơưĂÂĐÊÔƠƯ]/.test(text);
  if (language === 'zh') return cjk && !thai && !latin;
  if (language === 'th') return thai && !cjk && !latin;
  const words = text.match(/\p{L}+/gu) || [];
  const accented = words.filter((word) =>
    /[\u1ea0-\u1ef9ăâđêôơưĂÂĐÊÔƠƯàáảãạèéẻẽẹìíỉĩịòóỏõọùúủũụỳýỷỹỵ]/.test(word),
  ).length;
  const english = words.some((word) =>
    ['the', 'and', 'your', 'you', 'is', 'are', 'with', 'should', 'this', 'that'].includes(
      word.toLowerCase(),
    ),
  );
  return (
    latin &&
    !cjk &&
    !thai &&
    (language === 'vi'
      ? vietnamese && accented / Math.max(words.length, 1) >= 0.25 && !english
      : !vietnamese)
  );
}
export function baziGodName(value: Record<string, unknown>, language: Language) {
  let index = godIds.indexOf(String(value.id));
  if (index < 0)
    index = [
      '比肩',
      '劫財',
      '食神',
      '傷官',
      '正財',
      '偏財',
      '正官',
      '七殺',
      '正印',
      '偏印',
    ].indexOf(String(value.chinese));
  if (index < 0) index = godNames.zh.indexOf(String(value.chinese || value.nameLocalized));
  if (index < 0)
    index = godNames.en.findIndex(
      (name) => name.toLowerCase() === String(value.name).toLowerCase(),
    );
  if (index >= 0) return godNames[language][index];
  return baziProseMatches(value.nameLocalized, language) ? value.nameLocalized : '—';
}
