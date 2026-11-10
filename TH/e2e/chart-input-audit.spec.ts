import { expect, test } from '@playwright/test';
import zh from '../src/locales/zh-CN.json' with { type: 'json' };
import type { ThaiChart } from '../src/lib/thai';

const profile = {
  gender: 'female',
  display_name: 'Audit sample',
  birth_date: '1999-02-20',
  birth_time: '07:15',
  timezone: 'Asia/Shanghai',
  birthplace: 'Beijing',
  country_code: 'CN',
  language: 'zh',
};
test.beforeEach(async ({ page }) => {
  await page.addInitScript((profile) => {
    localStorage.setItem('sabai.language', 'zh');
    localStorage.setItem('sabai.languageConfirmed', '1');
    if (!localStorage.getItem('wanjai.birth'))
      localStorage.setItem('wanjai.birth', JSON.stringify(profile));
  }, profile);
});

test('confirmed morning clock, UTC, coordinates and Thai calculation labels stay consistent', async ({
  page,
}) => {
  const pending = page.waitForResponse((response) =>
    response.url().endsWith('/api/thai-chart/preview'),
  );
  await page.goto('/chart');
  const value: ThaiChart = await (await pending).json();
  expect(value.calculation_input?.utc_datetime).toBe('1999-02-19T23:15+00:00');
  await expect(page.getByTestId('natal-birth-card')).toContainText('07:15 · 上午');
  await expect(page.getByTestId('chart-calculation-settings')).toHaveCount(0);
  await expect(page.getByRole('button', { name: zh.c_orbitView, exact: true })).toBeVisible();
  await expect(page.getByTestId('natal-birth-card')).toContainText(zh.q_sun);
  await expect(page.getByTestId('natal-birth-card')).toContainText(zh.q_moon);
  await expect(page.getByTestId('natal-birth-card')).toContainText(zh.q_asc);
  const wheel = page.getByRole('img', { name: zh.th_natal, exact: true });
  for (const [key, point] of Object.entries(value.chart!.points)) {
    if (point.number === null) continue;
    await expect(wheel.locator(`[data-planet="${key}"]`)).toHaveAttribute(
      'data-longitude',
      String(point.longitudeDegrees),
    );
  }
  await page.getByTestId('chart-reading-button').click();
  await page.getByTestId('reading-calculation').locator(':scope > summary').click();
  await expect(page.getByTestId('reading-birth-source')).toContainText('07:15 · 上午');
  const settings = page.getByTestId('chart-calculation-settings');
  await expect(settings).toContainText(zh.q_system);
  await expect(settings).toContainText(zh.q_houses);
  await settings.locator('summary').click();
  await expect(settings).toContainText('1999-02-20T07:15+08:00');
  await expect(settings).toContainText('1999-02-19T23:15+00:00');
  await expect(settings).toContainText('39.9075, 116.39723');
});

test('AM and PM picker drafts preview different 24-hour values without changing a cancelled choice', async ({
  page,
}) => {
  await page.goto('/birth');
  const input = page.getByRole('button', { name: zh.birthTime, exact: true });
  await expect(input).toContainText(zh.am);
  await input.click();
  let dialog = page.getByRole('dialog');
  await dialog.getByRole('option', { name: zh.pm, exact: true }).click();
  await expect(dialog.getByTestId('birth-clock-preview')).toContainText('19:15');
  await dialog.getByRole('button', { name: zh.pickerCancel, exact: true }).click();
  await expect(input).toContainText(zh.am);
  await input.click();
  dialog = page.getByRole('dialog');
  await dialog.getByRole('option', { name: zh.pm, exact: true }).click();
  await dialog.getByRole('button', { name: zh.pickerDone, exact: true }).click();
  await expect(input).toContainText(zh.pm);
  await input.click();
  dialog = page.getByRole('dialog');
  await dialog.getByRole('option', { name: zh.am, exact: true }).click();
  await expect(dialog.getByTestId('birth-clock-preview')).toContainText('07:15');
  await dialog.getByRole('button', { name: zh.pickerDone, exact: true }).click();
  await page.getByRole('button', { name: zh.ux_saveReturn, exact: true }).click();
  await expect
    .poll(() => page.evaluate(() => JSON.parse(localStorage.getItem('wanjai.birth')!).birth_time))
    .toBe('07:15');
});
