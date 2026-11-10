import { expect, test } from '@playwright/test';
import { navigate, register } from './pickers';
import zh from '../src/locales/zh-CN.json' with { type: 'json' };

test.beforeEach(async ({ page }) => {
  await page.addInitScript(() => {
    localStorage.setItem('sabai.language', 'zh');
    localStorage.setItem('sabai.languageConfirmed', '1');
  });
  await page.goto('/');
});

test('personal Thai circle, catalog, divisions, live transits and account revision', async ({
  page,
}, info) => {
  const errors: string[] = [];
  page.on('pageerror', (error) => errors.push(error.message));
  await register(page, `thai_${info.project.name[0]}_${Date.now()}`);
  await page.getByRole('button', { name: '填入示例资料' }).click();
  await page.getByText('泰式排盘地点与坐标', { exact: true }).click();
  await expect(page.locator('#thai-location option')).toHaveCount(84);
  await page.getByLabel('选择排盘地点', { exact: true }).selectOption('geonames:1153671'); // Chiang Mai
  await page.getByRole('button', { name: '保存生辰，进入我的空间' }).click();
  await navigate(page, '我的星盘');
  const wheel = page.getByRole('img', { name: 'ราศี 本命', exact: true });
  await expect(wheel).toBeVisible();
  for (const name of [zh.th_natal, zh.th_navamsa, zh.th_drekkana]) {
    await expect(page.getByRole('button', { name, exact: true })).toHaveCount(0);
  }
  expect(
    await page
      .locator('[data-layout="jy-react"]')
      .evaluate((element) => getComputedStyle(element).backgroundColor),
  ).toBe('rgb(247, 244, 237)');
  await expect(wheel.locator('[data-planet]')).toHaveCount(10);
  const calculated = await page.evaluate(async () =>
    (
      await fetch('/api/thai-chart', {
        headers: { Authorization: `Bearer ${localStorage.getItem('sabai.session')}` },
      })
    ).json(),
  );
  for (const point of Object.values(calculated.chart.points) as {
    key: string;
    number: number | null;
    longitudeDegrees: number;
  }[]) {
    if (point.number === null) continue;
    await expect(wheel.locator(`[data-planet="${point.key}"]`)).toHaveAttribute(
      'data-longitude',
      String(point.longitudeDegrees),
    );
  }
  await wheel.locator('[data-planet="sun"]').click();
  await expect(page.getByRole('dialog')).toContainText(
    calculated.chart.points.sun.longitudeDegrees.toFixed(4),
  );
  await expect(page.getByTestId('orbit-birth-source')).toContainText('1995-08-17');
  await expect(page.getByRole('dialog')).toContainText(zh.c_birthScope);
  await page.getByRole('dialog').getByRole('button', { name: zh.pickerDone, exact: true }).click();
  await expect(page.getByTestId('natal-birth-card')).toContainText('1995-08-17');
  await expect(page.getByTestId('orbit-points').getByRole('button')).toHaveCount(11);
  await expect(page.getByTestId('natal-houses').getByRole('button')).toHaveCount(12);
  expect(
    await page
      .getByTestId('orbit-links')
      .evaluate((element) => element.scrollHeight <= element.clientHeight),
  ).toBe(true);
  await page.getByTestId('orbit-links').getByRole('button').first().click();
  await expect(page.getByRole('dialog')).toContainText(zh.c_relationScope);
  await expect(page.getByTestId('orbit-birth-source')).toContainText('1995-08-17');
  await page.getByRole('dialog').getByRole('button', { name: zh.pickerDone, exact: true }).click();
  await page.screenshot({
    path: `test-results/thai-${info.project.name}-orbit.png`,
    fullPage: true,
    animations: 'disabled',
  });
  await page.getByRole('button', { name: zh.c_traditionalView, exact: true }).click();
  const typeButton = page.getByRole('button', { name: zh.th_natal, exact: true });
  await expect(typeButton).toBeVisible();
  const viewBox = await page
    .getByRole('button', { name: zh.c_traditionalView, exact: true })
    .boundingBox();
  const typeBox = await typeButton.boundingBox();
  expect(typeBox!.y).toBeGreaterThanOrEqual(viewBox!.y + viewBox!.height);
  await expect(wheel.locator('circle')).toHaveCount(3);
  await expect(wheel.locator('line')).toHaveCount(8);
  await expect(wheel.locator('text[lang="th"]')).toHaveCount(12);
  const firstChart = await wheel.locator('desc').textContent();
  await page.screenshot({
    path: `test-results/thai-${info.project.name}-rasi.png`,
    fullPage: true,
    animations: 'disabled',
  });
  await page.getByRole('button', { name: 'นวางค์ 九分盘', exact: true }).click();
  const division = page.getByRole('img', { name: 'นวางค์ 九分盘', exact: true });
  await expect(division).toBeVisible();
  expect(await division.locator('desc').textContent()).not.toEqual(firstChart);
  await page.getByRole('button', { name: 'ตรียางค์ 三分盘', exact: true }).click();
  await expect(page.getByRole('img', { name: 'ตรียางค์ 三分盘', exact: true })).toBeVisible();
  await page.getByRole('button', { name: zh.c_orbitView, exact: true }).click();
  for (const name of [zh.th_natal, zh.th_navamsa, zh.th_drekkana]) {
    await expect(page.getByRole('button', { name, exact: true })).toHaveCount(0);
  }
  await expect(wheel.locator('[data-planet]')).toHaveCount(10);
  await page.getByRole('button', { name: zh.c_traditionalView, exact: true }).click();
  await expect(page.getByRole('img', { name: zh.th_drekkana, exact: true })).toBeVisible();
  const transits = page.waitForResponse((response) =>
    response.url().endsWith('/api/thai-transits'),
  );
  await page.getByRole('button', { name: '查看此刻泰式行运', exact: true }).click();
  const response = await transits;
  expect(response.ok()).toBe(true);
  const transit = await response.json();
  expect(transit.status).toBe('ready');
  expect(Object.keys(transit.comparison)).toHaveLength(10);
  await expect(
    page.getByText(
      '以曼谷当前时间计算ดาวจร及其落入的本命宫。这是此刻快照；首页日、周、月另按对应日期范围取样并使用公开规则解读。',
    ),
  ).toBeVisible();
  expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBe(true);
  await page.getByRole('button', { name: '编辑档案', exact: true }).click();
  await page.getByLabel('不记得确切时间').check();
  await page.getByRole('button', { name: '保存档案并生成命盘', exact: true }).click();
  await navigate(page, '我的星盘');
  await expect(page.getByTestId('birthday-overview')).toBeVisible();
  await expect(page.getByRole('img', { name: zh.th_chartLayout, exact: true })).toBeVisible();
  await expect(page.getByRole('img', { name: zh.th_natal, exact: true })).toHaveCount(0);
  await expect(page.getByRole('heading', { name: 'ทักษา 八项生辰主题' })).toHaveCount(0);
  await page
    .getByTestId('jy-chart-page')
    .getByRole('button', { name: zh.j_exampleChart, exact: true })
    .click();
  await expect(page.getByRole('note')).toContainText(zh.j_exampleNotice);
  await expect(page.getByRole('img', { name: zh.th_natal, exact: true })).toBeVisible();
  await page.getByRole('button', { name: zh.j_myChart, exact: true }).click();
  await expect(page.getByRole('img', { name: zh.th_chartLayout, exact: true })).toBeVisible();
  expect(
    await page.evaluate(async () => {
      const value = await (
        await fetch('/api/profile', {
          headers: { Authorization: `Bearer ${localStorage.getItem('sabai.session')}` },
        })
      ).json();
      return value.profile.birth_time;
    }),
  ).toBeNull();
  expect(errors).toEqual([]);
});

test('validation report exposes measured evidence and pending predictive accuracy', async ({
  page,
}) => {
  await page.goto('/reports/thai-validation.html?lang=th');
  await expect(
    page.getByRole('heading', { name: 'การเชื่อมต่อและตรวจสอบดวงไทย', exact: true }),
  ).toBeVisible();
  await expect(page.getByText('150 / 150', { exact: true })).toBeVisible();
  await page.getByLabel('Language').selectOption('en');
  await expect(
    page.getByText(
      /Independent same-school planetary\/ascendant reference cases are still missing/,
    ),
  ).toBeVisible();
  await expect(page.getByRole('link', { name: 'Full JSON and sources ↗' })).toHaveAttribute(
    'href',
    '/reports/thai-validation.json',
  );
});
