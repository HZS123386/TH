import { expect, test } from '@playwright/test';
import { chooseChineseDate, navigate, register } from './pickers';
import zh from '../src/locales/zh-CN.json' with { type: 'json' };
import th from '../src/locales/th.json' with { type: 'json' };

test('JY teaching example is accessible before birthday and never becomes a personal birth profile', async ({
  page,
}, info) => {
  await page.goto('/');
  await page.getByRole('radio', { name: /简体中文/ }).check();
  await page.getByRole('button', { name: zh.confirmLanguage, exact: true }).click();
  await expect(page.getByTestId('birth-entry')).toBeVisible();
  await expect(page.getByRole('button', { name: zh.j_exampleChart, exact: true })).toHaveCount(0);
  await page.goto('/example');
  await expect(page).toHaveURL(/\/example$/);
  await expect(page.getByRole('note')).toContainText(zh.j_exampleNotice);
  await expect(page.getByRole('img', { name: zh.th_natal, exact: true })).toBeVisible();
  await expect(page.getByRole('button', { name: zh.edit, exact: true })).toHaveCount(0);
  await page.reload();
  await expect(page.getByRole('img', { name: zh.th_natal, exact: true })).toBeVisible();
  expect(await page.evaluate(() => localStorage.getItem('wanjai.birth'))).toBeNull();
  expect(await page.evaluate(() => localStorage.getItem('sabai.session'))).toBeNull();
  await page.screenshot({
    path: `test-results/jy-${info.project.name}-example.png`,
    fullPage: true,
    animations: 'disabled',
  });
  await page.getByRole('button', { name: zh.back, exact: true }).click();
  await expect(page.getByTestId('birth-entry')).toBeVisible();
  await expect(page.getByRole('button', { name: zh.f_cta, exact: true })).toBeDisabled();
});

test('JY page flow retains local language, logo and wheels and carries a selected situation into real chat', async ({
  page,
}, info) => {
  const errors: string[] = [];
  page.on('pageerror', (error) => errors.push(error.message));
  await page.goto('/');
  await page.getByRole('radio', { name: /简体中文/ }).check();
  await page.getByRole('button', { name: zh.confirmLanguage, exact: true }).click();
  await expect(page.locator('[data-layout="jy-react"] [data-brand-mark="astro-star"]')).toHaveCount(
    1,
  );
  await expect(page.getByRole('button', { name: zh.f_cta, exact: true })).toBeDisabled();
  await chooseChineseDate(page, '1999-02-20');
  await page.getByRole('button', { name: /想换工作，又怕选错怎么办/ }).click();
  await page.getByRole('button', { name: zh.j_seeConcern, exact: true }).click();
  await expect(page).toHaveURL(/\/reflection$/);
  const label = await page
    .getByTestId('jy-concern-page')
    .getByRole('button', { name: /正在找工作/ })
    .textContent();
  expect(label).toBeTruthy();
  await page.getByRole('button', { name: /正在找工作/ }).click();
  await page.getByRole('button', { name: zh.w_preview, exact: true }).click();
  await expect(page).toHaveURL(/\/plan$/);
  await expect(page.getByTestId('jy-plan-page')).toContainText('路径二');
  await page.goBack();
  await expect(page.getByRole('button', { name: /正在找工作/ })).toHaveAttribute(
    'aria-pressed',
    'true',
  );
  await page.getByRole('button', { name: zh.w_talk, exact: true }).first().click();
  await expect(page).toHaveURL(/\/consult$/);
  await page
    .getByRole('textbox', { name: zh.j_askPlaceholder, exact: true })
    .fill('本周想换工作，但不能立即辞职。');
  await page.getByRole('button', { name: zh.j_loginContinue, exact: true }).click();
  await page.getByRole('button', { name: zh.newAccount, exact: true }).click();
  await page
    .getByLabel(zh.username, { exact: true })
    .fill(`jy_${info.project.name[0]}_${Date.now()}`);
  await page.getByLabel(zh.password, { exact: true }).fill('Sabai_test_2026');
  await page.getByLabel(zh.confirmPassword, { exact: true }).fill('Sabai_test_2026');
  await page.getByRole('button', { name: zh.register, exact: true }).click();
  await page.getByLabel(zh.name, { exact: true }).fill('Nok');
  await expect(page.getByRole('button', { name: zh.birthDate, exact: true })).toContainText('1999');
  await page.getByRole('button', { name: zh.onboardingSave, exact: true }).click();
  await expect(page.locator('#chat-input')).toHaveValue('本周想换工作，但不能立即辞职。');
  const request = page.waitForRequest((request) => request.url().endsWith('/api/chat'));
  await page.getByRole('button', { name: zh.send, exact: true }).click();
  expect((await request).postDataJSON().context).toContain('求职行动');
  await expect(page.getByRole('button', { name: zh.stop, exact: true })).not.toBeVisible({
    timeout: 15000,
  });
  await page.getByTestId('chat-evidence').locator('summary').click();
  await expect(page.getByTestId('chat-evidence')).toContainText(zh.w_week);
  await page.reload();
  await expect(page).toHaveURL(/\/consult$/);
  await expect(page.getByRole('log')).toContainText('本周想换工作');
  await page.screenshot({
    path: `test-results/jy-${info.project.name}-chat.png`,
    fullPage: true,
    animations: 'disabled',
  });
  expect(errors).toEqual([]);
});

test('JY shop details, quantity, demo checkout, wish and language survive account reload', async ({
  page,
}, info) => {
  await page.addInitScript(() => {
    localStorage.setItem('sabai.language', 'zh');
    localStorage.setItem('sabai.languageConfirmed', '1');
  });
  await page.goto('/');
  await register(page, `shop_${info.project.name[0]}_${Date.now()}`);
  await page.getByRole('button', { name: zh.sample, exact: true }).click();
  await page.getByRole('button', { name: zh.onboardingSave, exact: true }).click();
  await navigate(page, zh.w_shop);
  await page.getByTestId('taste-panel').locator('summary').click();
  await page.getByRole('button', { name: zh.j_soft, exact: true }).click();
  await page.getByLabel(zh.w_budget, { exact: true }).selectOption('500');
  await page.getByRole('button', { name: '月光石 · 温柔心愿手串', exact: true }).first().click();
  let dialog = page.getByRole('dialog');
  await dialog.getByRole('button', { name: '18 cm', exact: true }).click();
  await dialog.getByRole('button', { name: zh.j_quantity + ' +', exact: true }).click();
  await dialog.getByRole('button', { name: zh.j_checkout, exact: true }).click();
  await expect(dialog).toContainText('18 cm × 2');
  await expect(dialog).toContainText('฿980');
  await dialog.getByRole('button', { name: zh.j_simulateOrder, exact: true }).click();
  await expect(dialog).toContainText(zh.w_paymentNote);
  await dialog.getByRole('button', { name: zh.j_orders, exact: true }).click();
  await expect(page).toHaveURL(/\/orders$/);
  await expect(page.getByRole('article')).toContainText('18 cm × 2');
  await page.reload();
  await expect(page.getByRole('article')).toContainText('18 cm × 2');
  await navigate(page, zh.w_mine);
  await page.getByRole('button', { name: zh.w_wish, exact: true }).click();
  dialog = page.getByRole('dialog');
  await dialog.getByLabel(zh.w_wish).fill('每天留一点时间给自己。');
  await dialog.getByRole('button', { name: zh.w_save, exact: true }).click();
  await page.getByRole('button', { name: zh.languageLabel, exact: true }).click();
  await page.getByRole('radio', { name: /ภาษาไทย/ }).check();
  await page.getByRole('button', { name: th.confirmLanguage, exact: true }).click();
  await expect(page.getByRole('heading', { name: th.j_mineTitle, exact: true })).toBeVisible();
  await expect(page.getByTestId('jy-profile-page')).toContainText('每天留一点时间给自己。');
  await expect(page.locator('[data-brand-lockup]')).toContainText(th.brandName);
  await page.screenshot({
    path: `test-results/jy-${info.project.name}-profile-th.png`,
    fullPage: true,
    animations: 'disabled',
  });
  expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBe(true);
});
