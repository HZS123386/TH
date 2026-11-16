import english from "../content/en.json";
import vietnamese from "../content/vi.json";

import burmese from "../content/my.json";
import khmer from "../content/km.json";
import lao from "../content/lo.json";
import malay from "../content/ms.json";
import indonesian from "../content/id.json";

export { english, vietnamese };
export const additionalLocales = { en: english, vi: vietnamese, my: burmese, km: khmer, lo: lao, ms: malay, id: indonesian };
export function additionalCopy<K extends keyof typeof english>(group: K) {
  return Object.fromEntries(Object.entries(additionalLocales).map(([code, copy]) => [code, copy[group]])) as {
    [L in keyof typeof additionalLocales]: (typeof additionalLocales)[L][K]
  };
}
export const languages = ["th", "en", "zh", "vi", "my", "km", "lo", "ms", "id"] as const;
export type Language = typeof languages[number];
export const localeTag = (language: Language) => ({ th: "th-TH", en: "en-SG", zh: "zh-CN", vi: "vi-VN", my: "my-MM", km: "km-KH", lo: "lo-LA", ms: "ms-MY", id: "id-ID" })[language];
