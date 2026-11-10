import { expect, test } from '@playwright/test';
import zh from '../src/locales/zh-CN.json' with { type: 'json' };
import { chooseChineseDate, navigate, selectWheel } from './pickers';

const profile = {
  display_name: 'Nok',
  birth_date: '1999-02-20',
  birth_time: '09:15',
  birthplace: 'Bangkok',
  timezone: 'Asia/Bangkok',
  language: 'zh',
};

test.beforeEach(async ({ page }) => {
  await page.addInitScript(() => {
    localStorage.setItem('sabai.language', 'zh');
    localStorage.setItem('sabai.languageConfirmed', '1');
  });
});

test('first chart visit collects birth details, calculates the real chart and stays completed after refresh', async ({
  page,
}) => {
  await page.goto('/chart');
  const setup = page.getByRole('dialog', { name: zh.c_chartSetupTitle, exact: true });
  await expect(setup).toBeVisible();
  await expect(setup.getByRole('button', { name: zh.timezone, exact: true })).toHaveCount(0);
  await setup.getByLabel(zh.name, { exact: true }).fill('小星');
  await setup.getByText(zh.c_male, { exact: true }).click();
  await chooseChineseDate(page, '1999-02-20');
  await expect(setup).toBeVisible();
  await setup.getByRole('button', { name: zh.birthplace, exact: true }).click();
  const places = page.getByRole('dialog', { name: zh.birthplace, exact: true });
  await selectWheel(places.getByRole('listbox', { name: zh.birthCountry, exact: true }), '中国');
  await places.getByRole('button', { name: zh.pickerDone, exact: true }).click();
  await setup.getByRole('button', { name: zh.birthTime, exact: true }).click();
  const time = page.getByRole('dialog', { name: zh.birthTime, exact: true });
  await time.getByRole('option', { name: zh.pm, exact: true }).click();
  await selectWheel(time.getByRole('listbox', { name: zh.birthHour, exact: true }), '07');
  await selectWheel(time.getByRole('listbox', { name: zh.birthMinute, exact: true }), '15');
  await time.getByRole('button', { name: zh.pickerDone, exact: true }).click();
  const calculation = page.waitForResponse((response) =>
    response.url().endsWith('/api/thai-chart/preview'),
  );
  await setup.getByRole('button', { name: zh.c_viewMyChart, exact: true }).click();
  const result = await (await calculation).json();
  expect(result.status).toBe('ready');
  await expect(setup).toHaveCount(0);
  await expect(page).toHaveURL(/\/chart$/);
  await expect(page.getByTestId('natal-birth-card')).toContainText('小星');
  await expect(page.getByTestId('natal-chart-hero')).toContainText('小星');
  await expect(page.locator('[data-starfield="page"]')).toHaveCount(1);
  await expect(page.getByTestId('thai-orbit-wheel').locator('[data-planet="sun"]')).toHaveAttribute(
    'data-longitude',
    String(result.chart.points.sun.longitudeDegrees),
  );
  expect(
    await page.evaluate(() => JSON.parse(localStorage.getItem('wanjai.birth')!)),
  ).toMatchObject({
    display_name: '小星',
    gender: 'male',
    birth_date: '1999-02-20',
    birth_time: '19:15',
    timezone: 'Asia/Shanghai',
    birthplace: expect.stringContaining('北京'),
    country_code: 'CN',
    location_id: expect.stringMatching(/^geonames:/),
  });
  await page.reload();
  await expect(page.getByTestId('natal-birth-card')).toBeVisible();
  await expect(setup).toHaveCount(0);
  await navigate(page, zh.w_mine);
  await navigate(page, zh.w_chart);
  await expect(setup).toHaveCount(0);
});

test('failed chart setup retains the draft and supports retry', async ({ page }) => {
  await page.addInitScript((profile) => {
    if (!localStorage.getItem('wanjai.birth'))
      localStorage.setItem('wanjai.birth', JSON.stringify(profile));
  }, profile);
  let fail = true;
  await page.route('**/api/thai-chart/preview', async (route) => {
    if (route.request().postDataJSON().gender === 'female' && fail) {
      fail = false;
      await route.fulfill({
        status: 503,
        contentType: 'application/json',
        body: JSON.stringify({ detail: 'thai_calculation_failed' }),
      });
    } else await route.continue();
  });
  await page.goto('/chart');
  const setup = page.getByRole('dialog', { name: zh.c_chartSetupTitle, exact: true });
  await setup.getByText(zh.c_female, { exact: true }).click();
  await setup.getByRole('button', { name: zh.c_viewMyChart, exact: true }).click();
  await expect(setup.getByRole('alert')).toBeVisible();
  await expect(setup.getByLabel(zh.name, { exact: true })).toHaveValue('Nok');
  expect(
    await page.evaluate(() => JSON.parse(localStorage.getItem('wanjai.birth')!).gender),
  ).toBeUndefined();
  await setup.getByRole('button', { name: zh.c_viewMyChart, exact: true }).click();
  await expect(setup).toHaveCount(0);
  expect(await page.evaluate(() => JSON.parse(localStorage.getItem('wanjai.birth')!).gender)).toBe(
    'female',
  );
});

test('explicit unknown time is saved without inventing a personal ascendant or houses', async ({
  page,
}) => {
  await page.addInitScript((profile) => {
    if (!localStorage.getItem('wanjai.birth'))
      localStorage.setItem('wanjai.birth', JSON.stringify(profile));
  }, profile);
  await page.goto('/chart');
  const setup = page.getByRole('dialog', { name: zh.c_chartSetupTitle, exact: true });
  await setup.getByText(zh.c_female, { exact: true }).click();
  await setup.getByRole('checkbox', { name: zh.timeUnknown, exact: true }).check();
  await setup.getByRole('button', { name: zh.ux_viewBirthday, exact: true }).click();
  await expect(setup).toHaveCount(0);
  await expect(page.getByTestId('birthday-overview')).toBeVisible();
  await expect(page.getByTestId('chart-reading-button')).toHaveCount(0);
  await expect(page.getByTestId('natal-chart-data')).toHaveCount(0);
  expect(
    await page.evaluate(() => JSON.parse(localStorage.getItem('wanjai.birth')!).birth_time),
  ).toBeNull();
  await page.reload();
  await expect(page.getByTestId('birthday-overview')).toBeVisible();
  await expect(setup).toHaveCount(0);
});

test('chart setup saves to the signed-in account and restores on refresh', async ({
  page,
  request,
}, info) => {
  const registered = await request.post('/api/auth/register', {
    data: { username: `chart_${info.project.name}_${Date.now()}`, password: 'Sabai_test_2026' },
  });
  expect(registered.ok()).toBe(true);
  const { token } = await registered.json();
  const headers = { Authorization: `Bearer ${token}` };
  expect((await request.put('/api/profile', { headers, data: profile })).ok()).toBe(true);
  await page.addInitScript((token) => localStorage.setItem('sabai.session', token), token);
  await page.goto('/chart');
  const setup = page.getByRole('dialog', { name: zh.c_chartSetupTitle, exact: true });
  await expect(setup.getByLabel(zh.name, { exact: true })).toHaveValue('Nok');
  await setup.getByText(zh.c_male, { exact: true }).click();
  await setup.getByRole('button', { name: zh.c_viewMyChart, exact: true }).click();
  await expect(setup).toHaveCount(0);
  expect((await (await request.get('/api/profile', { headers })).json()).profile.gender).toBe(
    'male',
  );
  await page.reload();
  await expect(page.getByTestId('natal-birth-card')).toBeVisible();
  await expect(setup).toHaveCount(0);
});
