import { expect, test } from '@playwright/test';
import zh from '../src/locales/zh-CN.json' with { type: 'json' };
import { selectWheel } from './pickers';

test.beforeEach(async ({ page }) => {
  await page.addInitScript(() => {
    localStorage.setItem('sabai.language', 'zh');
    localStorage.setItem('sabai.languageConfirmed', '1');
    if (!localStorage.getItem('wanjai.birth'))
      localStorage.setItem(
        'wanjai.birth',
        JSON.stringify({
          display_name: 'Nok',
          birth_date: '1999-02-20',
          birth_time: '09:15',
          birthplace: 'Bangkok',
          timezone: 'Asia/Bangkok',
          language: 'zh',
        }),
      );
  });
  await page.goto('/chart');
});

test('Chinese directory covers every province and saves the selected city identity and coordinates', async ({
  page,
}, info) => {
  const setup = page.getByRole('dialog', { name: zh.c_chartSetupTitle, exact: true });
  await setup.getByRole('button', { name: zh.birthplace, exact: true }).click();
  const places = page.getByRole('dialog', { name: zh.birthplace, exact: true });
  await selectWheel(places.getByRole('listbox', { name: zh.birthCountry, exact: true }), '中国');
  const provinces = places.getByRole('listbox', { name: zh.birthProvince, exact: true });
  await expect(provinces.getByRole('option')).toHaveCount(35);
  await selectWheel(provinces, '河北省');
  const directory = page.waitForResponse((response) => {
    const url = new URL(response.url());
    return (
      url.pathname === '/api/thai-locations' &&
      url.searchParams.get('province') === 'geonames:1808773' &&
      url.searchParams.get('query') === '邯郸'
    );
  });
  await places.getByRole('textbox', { name: zh.searchBirthCity, exact: true }).fill('邯郸');
  const rows = (await (await directory).json()).items;
  const city = rows.find((row: { id: string }) => row.id === 'geonames:1808963');
  expect(city).toBeTruthy();
  await places.locator('[data-wheel-value="geonames:1808963"]').click();
  await page.screenshot({
    path: `test-results/city-directory-cn-${info.project.name}.png`,
    animations: 'disabled',
  });
  await places.getByRole('button', { name: zh.pickerDone, exact: true }).click();
  await setup.getByText(zh.c_female, { exact: true }).click();
  const calculated = page.waitForResponse(
    (response) =>
      response.url().endsWith('/api/thai-chart/preview') &&
      response.request().postDataJSON().location_id === city.id,
  );
  await setup.getByRole('button', { name: zh.c_viewMyChart, exact: true }).click();
  const result = await (await calculated).json();
  expect(result.status).toBe('ready');
  expect(result.chart.input.ascendantReference.latitude).toBe(city.latitude);
  expect(result.chart.input.ascendantReference.longitude).toBe(city.longitude);
  const card = page.getByTestId('natal-birth-card');
  await expect(card).toContainText('邯郸');
  await expect(card).not.toContainText('Asia/');
  expect(
    await page.evaluate(() => JSON.parse(localStorage.getItem('wanjai.birth')!)),
  ).toMatchObject({ location_id: city.id, country_code: 'CN', timezone: city.timeZone });
  await page.reload();
  await expect(page.getByTestId('natal-birth-card')).toBeVisible();
  await page.getByRole('button', { name: zh.edit, exact: true }).click();
  await page.locator('summary').filter({ hasText: zh.f_optional }).click();
  await page.getByRole('button', { name: zh.birthplace, exact: true }).click();
  await expect(
    places.getByRole('listbox', { name: zh.birthProvince }).getByRole('option', { selected: true }),
  ).toHaveText('河北省');
  await expect(places.locator('[data-wheel-value="geonames:1808963"]')).toHaveAttribute(
    'aria-selected',
    'true',
  );
  await page.keyboard.press('Escape');
  expect(
    await page.evaluate(() => JSON.parse(localStorage.getItem('wanjai.birth')!).location_id),
  ).toBe(city.id);
});

test('Thai directory covers all 77 provinces and can select a district outside the common-city list', async ({
  page,
}, info) => {
  const setup = page.getByRole('dialog', { name: zh.c_chartSetupTitle, exact: true });
  await setup.getByRole('button', { name: zh.birthplace, exact: true }).click();
  const places = page.getByRole('dialog', { name: zh.birthplace, exact: true });
  const provinces = places.getByRole('listbox', { name: zh.birthProvince, exact: true });
  await expect(provinces.getByRole('option')).toHaveCount(78);
  await selectWheel(provinces, '清迈府');
  await places.getByRole('textbox', { name: zh.searchBirthCity, exact: true }).fill('邯郸');
  await expect(places.getByText(zh.noBirthCities, { exact: true })).toBeVisible();
  await expect(places.getByRole('button', { name: zh.pickerDone, exact: true })).toBeDisabled();
  const directory = page.waitForResponse((response) => {
    const url = new URL(response.url());
    return (
      url.pathname === '/api/thai-locations' &&
      url.searchParams.get('country') === 'TH' &&
      url.searchParams.get('query') === 'เมืองเชียงใหม่'
    );
  });
  await places
    .getByRole('textbox', { name: zh.searchBirthCity, exact: true })
    .fill('เมืองเชียงใหม่');
  const rows = (await (await directory).json()).items;
  const city = rows.find((row: { id: string }) => row.id === 'geonames:1152000');
  expect(city).toBeTruthy();
  await places.locator('[data-wheel-value="geonames:1152000"]').click();
  await page.screenshot({
    path: `test-results/city-directory-th-${info.project.name}.png`,
    animations: 'disabled',
  });
  await places.getByRole('button', { name: zh.pickerDone, exact: true }).click();
  await setup.getByText(zh.c_female, { exact: true }).click();
  const calculated = page.waitForResponse(
    (response) =>
      response.url().endsWith('/api/thai-chart/preview') &&
      response.request().postDataJSON().location_id === city.id,
  );
  await setup.getByRole('button', { name: zh.c_viewMyChart, exact: true }).click();
  const result = await (await calculated).json();
  expect(result.status).toBe('ready');
  expect(result.location.latitude).toBe(city.latitude);
  expect(result.location.longitude).toBe(city.longitude);
  await expect(setup).toHaveCount(0);
  expect(
    await page.evaluate(() => JSON.parse(localStorage.getItem('wanjai.birth')!)),
  ).toMatchObject({ location_id: city.id, country_code: 'TH', timezone: 'Asia/Bangkok' });
});
