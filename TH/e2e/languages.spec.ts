import { expect, test, type Page } from '@playwright/test';
import zh from '../src/locales/zh-CN.json' with { type: 'json' };
import th from '../src/locales/th.json' with { type: 'json' };
import vi from '../src/locales/vi.json' with { type: 'json' };
import en from '../src/locales/en-US.json' with { type: 'json' };
import { LANGUAGES } from '../src/lib/languages';
import { selectWheel } from './pickers';
const translations = { zh, th, vi, en };

async function choose(page: Page, id: 'zh' | 'th' | 'vi' | 'en') {
  const option = LANGUAGES.find((item) => item.id === id)!;
  await page
    .getByRole('radio', { name: new RegExp(option.label.replace(/[()]/g, '\\$&')) })
    .check();
  await page
    .getByRole('button', { name: translations[id].confirmLanguage, exact: true })
    .last()
    .click();
}

for (const option of LANGUAGES) {
  test(`first language selection persists globally: ${option.locale}`, async ({
    page,
  }, testInfo) => {
    await page.goto('/');
    await expect(page.getByRole('radio')).toHaveCount(4);
    await expect(page.getByRole('radio', { name: /English \(US\)/ })).toBeVisible();
    await expect(
      page.getByRole('button', { name: translations.en.login, exact: true }),
    ).not.toBeVisible();
    await page
      .getByRole('radio', { name: new RegExp(option.label.replace(/[()]/g, '\\$&')) })
      .check();
    await expect(
      page.locator('[aria-labelledby="language-title"] [data-brand-lockup]'),
    ).toContainText(translations[option.id].brandName);
    await page.screenshot({
      path: `test-results/${testInfo.project.name}-language-${option.id}.png`,
      fullPage: true,
      animations: 'disabled',
    });
    await page
      .getByRole('button', { name: translations[option.id].confirmLanguage, exact: true })
      .last()
      .click();
    await expect(page.locator('html')).toHaveAttribute('lang', option.locale);
    await expect(page).toHaveTitle(translations[option.id].pageTitle);
    await expect(page.locator('meta[name="description"]')).toHaveAttribute(
      'content',
      `${translations[option.id].brandName} · ${translations[option.id].brandDescription}`,
    );
    const lockup = page.locator('[data-brand-lockup]:visible').first();
    await expect(lockup).toContainText(translations[option.id].brandName);
    await expect(lockup.locator('[data-brand-mark="lotus-star"]')).toHaveCount(1);
    expect(
      await lockup.evaluate((root) => {
        const name = root.querySelector('span[lang] > span')!;
        const range = document.createRange();
        range.selectNodeContents(name);
        return range.getBoundingClientRect().right <= root.getBoundingClientRect().right + 1;
      }),
      'localized wordmark fits without clipping',
    ).toBe(true);
    await lockup.screenshot({
      path: `test-results/brand-${option.id}-${testInfo.project.name}.png`,
    });
    await expect(
      page.getByRole('heading', { name: translations[option.id].f_title, exact: true }),
    ).toBeVisible();
    await expect(
      page.getByRole('button', { name: translations[option.id].login, exact: true }),
    ).toBeVisible();
    expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBe(
      true,
    );
    await page.reload();
    await expect(page.getByRole('radio')).toHaveCount(0);
    await expect(
      page.getByRole('heading', { name: translations[option.id].f_title, exact: true }),
    ).toBeVisible();
    await page.getByRole('button', { name: translations[option.id].login, exact: true }).click();
    await expect(
      page.getByRole('heading', { name: translations[option.id].loginTitle, exact: true }),
    ).toBeVisible();
    await expect(page.getByLabel(translations[option.id].username, { exact: true })).toBeVisible();
  });
}

test('Vietnamese registration, localized errors, reply and language switch preserve the account', async ({
  page,
}, testInfo) => {
  await page.goto('/');
  await choose(page, 'vi');
  const vi = translations.vi,
    en = translations.en;
  await page.getByRole('button', { name: vi.login, exact: true }).click();
  const username = `vi_${testInfo.project.name[0]}_${Date.now()}`;
  await page.getByLabel(vi.username, { exact: true }).fill(username);
  await page.getByLabel(vi.password, { exact: true }).fill('Sabai_test_2026');
  await page.getByRole('button', { name: vi.login, exact: true }).last().click();
  await expect(page.getByRole('alert')).toContainText('Tên tài khoản hoặc mật khẩu không đúng.');
  await page.getByRole('button', { name: vi.newAccount, exact: true }).click();
  await page.getByLabel(vi.password, { exact: true }).fill('Sabai_test_2026');
  await page.getByLabel(vi.confirmPassword, { exact: true }).fill('Sabai_test_2026');
  await page.getByRole('button', { name: vi.register, exact: true }).click();
  await expect(page.getByRole('heading', { name: vi.onboardingTitle, exact: true })).toBeVisible();
  await page.getByRole('button', { name: vi.birthDate, exact: true }).click();
  await selectWheel(page.getByRole('listbox', { name: vi.pickerYear, exact: true }), '1995');
  await selectWheel(page.getByRole('listbox', { name: vi.pickerMonth, exact: true }), 'Tháng 8');
  await selectWheel(page.getByRole('listbox', { name: vi.pickerDay, exact: true }), '17');
  await page.getByRole('dialog').getByRole('button', { name: vi.pickerDone, exact: true }).click();
  await page.getByLabel(vi.timeUnknown, { exact: true }).check();
  await page.getByRole('button', { name: vi.onboardingSave, exact: true }).click();
  await expect(page.getByRole('heading', { name: vi.w_hello, exact: true })).toBeVisible();
  await page
    .getByRole('navigation')
    .getByRole('button', { name: vi.w_questions, exact: true })
    .click();
  await page.locator('#chat-input').fill('Chào bạn');
  await page.getByRole('button', { name: vi.send, exact: true }).click();
  await expect(page.getByRole('log')).toContainText('Đây là câu trả lời minh họa', {
    timeout: 15000,
  });
  await expect(page.getByRole('button', { name: vi.stop, exact: true })).not.toBeVisible({
    timeout: 15000,
  });
  const before = await page.evaluate(async () => {
    const headers = { Authorization: `Bearer ${localStorage.getItem('sabai.session')}` };
    return {
      profile: await (await fetch('/api/profile', { headers })).json(),
      history: await (await fetch('/api/history', { headers })).json(),
    };
  });
  await page.getByRole('button', { name: vi.languageLabel, exact: true }).click();
  await choose(page, 'en');
  await expect(page.locator('html')).toHaveAttribute('lang', 'en-US');
  const after = await page.evaluate(async () => {
    const headers = { Authorization: `Bearer ${localStorage.getItem('sabai.session')}` };
    return {
      profile: await (await fetch('/api/profile', { headers })).json(),
      history: await (await fetch('/api/history', { headers })).json(),
    };
  });
  expect(after.profile.revision).toBe(before.profile.revision);
  expect(after.profile.chart).toEqual(before.profile.chart);
  expect(after.profile.profile.language).toBe('en');
  expect(after.history).toEqual(before.history);
  await expect(
    page.getByRole('heading', { name: `${en.brandName} · ${en.w_questions}`, exact: true }),
  ).toBeVisible();
  await page.locator('#chat-input').fill('Hello again');
  await page.getByRole('button', { name: en.send, exact: true }).click();
  await expect(page.getByRole('log')).toContainText('This is a demo reply', { timeout: 15000 });
  await expect(page.getByRole('button', { name: en.stop, exact: true })).not.toBeVisible({
    timeout: 15000,
  });
  await page.reload();
  await expect(page).toHaveURL(/\/consult$/);
  await expect(
    page.getByRole('heading', { name: `${en.brandName} · ${en.w_questions}`, exact: true }),
  ).toBeVisible();
  await expect(page.getByRole('log')).toContainText('Hello again');
  await expect(page.getByRole('radio')).toHaveCount(0);
});
