import { expect, test, type Page } from '@playwright/test';
import zh from '../src/locales/zh-CN.json' with { type: 'json' };
import th from '../src/locales/th.json' with { type: 'json' };
import vi from '../src/locales/vi.json' with { type: 'json' };
import en from '../src/locales/en-US.json' with { type: 'json' };
import zhData from '../src/data/wanjai-zh.json' with { type: 'json' };
import { chartRelations } from '../src/lib/chartGeometry';
import type { ThaiChart } from '../src/lib/thai';
import natalCopy from '../src/content/natal-reading.json' with { type: 'json' };

const profile = {
  display_name: 'Nok',
  gender: 'female',
  birth_date: '1999-02-20',
  birth_time: '19:15',
  timezone: 'Asia/Bangkok',
  birthplace: 'Bangkok',
  language: 'zh',
};
const copies = { zh, th, vi, en };

async function prepare(page: Page, language = 'zh', complete = true) {
  await page.addInitScript(
    ({ language, profile, complete }) => {
      localStorage.setItem('sabai.language', language);
      localStorage.setItem('sabai.languageConfirmed', '1');
      if (!localStorage.getItem('wanjai.birth'))
        localStorage.setItem(
          'wanjai.birth',
          JSON.stringify({
            ...profile,
            language,
            ...(!complete ? { birth_time: null, birthplace: '' } : {}),
          }),
        );
    },
    { language, profile, complete },
  );
}

async function expectDock(page: Page) {
  const button = await page.getByTestId('chart-reading-button').boundingBox();
  const nav = await page.getByRole('navigation').boundingBox();
  expect(button).not.toBeNull();
  expect(nav).not.toBeNull();
  expect(button!.y + button!.height).toBeLessThanOrEqual(nav!.y);
  expect(nav!.y + nav!.height).toBeCloseTo(page.viewportSize()!.height, 0);
  expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBe(true);
  return button!;
}

test('fixed full-reading action navigates to this birth chart and survives refresh and Back', async ({
  page,
}, info) => {
  const errors: string[] = [];
  page.on('pageerror', (error) => errors.push(error.message));
  await prepare(page);
  const calculation = page.waitForResponse((response) =>
    response.url().endsWith('/api/thai-chart/preview'),
  );
  await page.goto('/chart');
  const native: ThaiChart = await (await calculation).json();
  await expect(page.getByTestId('natal-birth-card')).toBeVisible();
  const first = await expectDock(page);
  await page.screenshot({ path: `test-results/reading-action-${info.project.name}.png` });
  await page.evaluate(() => window.scrollTo(0, document.body.scrollHeight));
  const bottom = await expectDock(page);
  expect(bottom.y).toBeCloseTo(first.y, 0);
  const last = await page
    .getByTestId('jy-chart-page')
    .getByRole('button', { name: zh.c_updateBirth, exact: true })
    .boundingBox();
  expect(last!.y + last!.height).toBeLessThanOrEqual(bottom.y);
  await page.getByTestId('chart-reading-button').click();
  await expect(page).toHaveURL(/\/chart\/reading$/);
  await expect(page.getByRole('heading', { name: zh.r_title, exact: true })).toBeVisible();
  await expect(page.getByTestId('reading-birth-source')).toContainText(profile.birth_date);
  for (const point of Object.values(native.chart!.points)) {
    if (point.number === null) continue;
    await expect(
      page.getByTestId('reading-chart').locator(`[data-planet="${point.key}"]`),
    ).toHaveAttribute('data-longitude', String(point.longitudeDegrees));
  }
  await expect(page.getByTestId('reading-planets').locator('[data-reading-detail]')).toHaveCount(
    10,
  );
  await expect(page.getByTestId('reading-houses').locator('details')).toHaveCount(12);
  await expect(page.getByTestId('reading-relations').locator('ul > li')).toHaveCount(
    chartRelations(native.chart!).length,
  );
  await expect(page.locator('[data-reading-point="sun"]')).toContainText(
    zhData.signs[native.chart!.points.sun.sign].name,
  );
  await page.locator('[data-reading-detail="sun"] > summary').click();
  await expect(page.locator('[data-reading-detail="sun"]')).toContainText(
    `${native.chart!.points.sun.degrees}°`,
  );
  await expect(page.getByTestId('chart-reading-button')).toHaveCount(0);
  await expect(
    page.getByRole('navigation').getByRole('button', { name: zh.ux_reports, exact: true }),
  ).toHaveAttribute('aria-current', 'page');
  await page.screenshot({ path: `test-results/full-reading-${info.project.name}.png` });
  await page.reload();
  await expect(page.getByTestId('reading-planets')).toBeVisible();
  await page.goBack();
  await expect(page).toHaveURL(/\/chart$/);
  await expect(page.getByTestId('chart-reading-button')).toBeVisible();
  await page.getByRole('button', { name: zh.j_exampleChart, exact: true }).first().click();
  await expect(page.getByTestId('chart-reading-button')).toHaveCount(0);
  await page.getByRole('button', { name: zh.j_myChart, exact: true }).click();
  await expect(page.getByTestId('chart-reading-button')).toBeVisible();
  await page.getByTestId('chart-reading-button').click();
  await page.evaluate(() => {
    const value = JSON.parse(localStorage.getItem('wanjai.birth')!);
    localStorage.setItem('wanjai.birth', JSON.stringify({ ...value, birth_date: '2001-03-11' }));
  });
  await page.reload();
  await expect(page.getByTestId('reading-birth-source')).toContainText('2001-03-11');
  await expect(page.getByTestId('reading-birth-source')).not.toContainText('1999-02-20');
  await expect(page.getByTestId('reading-planets')).toBeVisible();
  expect(errors).toEqual([]);
});

test('full reading counts real placements, grounds life topics and highlights the same natal data', async ({
  page,
}, info) => {
  await prepare(page);
  let calculations = 0;
  const modelRequests: string[] = [];
  page.on('request', (request) => {
    if (request.url().endsWith('/api/thai-chart/preview')) calculations++;
    if (/\/api\/(chat|thai-readings)/.test(request.url())) modelRequests.push(request.url());
  });
  const calculated = page.waitForResponse((response) =>
    response.url().endsWith('/api/thai-chart/preview'),
  );
  await page.goto('/chart');
  const native: ThaiChart = await (await calculated).json();
  const chart = native.chart!;
  const wheel = page.getByTestId('thai-orbit-wheel');
  const positions = await wheel
    .locator('[data-planet]')
    .evaluateAll((nodes) =>
      nodes.map((node) => [node.getAttribute('data-planet'), node.getAttribute('data-longitude')]),
    );
  const lines = await wheel
    .locator('[data-link]')
    .evaluateAll((nodes) => nodes.map((node) => node.getAttribute('data-link')));
  const baseline = calculations;
  await page.getByTestId('chart-reading-button').click();
  await expect(page.getByTestId('reading-chart')).toBeVisible();
  expect(
    await wheel
      .locator('[data-planet]')
      .evaluateAll((nodes) =>
        nodes.map((node) => [
          node.getAttribute('data-planet'),
          node.getAttribute('data-longitude'),
        ]),
      ),
  ).toEqual(positions);
  expect(
    await wheel
      .locator('[data-link]')
      .evaluateAll((nodes) => nodes.map((node) => node.getAttribute('data-link'))),
  ).toEqual(lines);
  const selector = page.getByTestId('reading-planet-selector');
  await expect(selector.getByRole('button')).toHaveCount(10);
  await expect(selector.locator('[data-planet-choice="ascendant"]')).toHaveCount(0);
  await expect(
    page.locator('[data-reading-point="ascendant"], [data-reading-detail="ascendant"]'),
  ).toHaveCount(0);
  await expect(page.locator('[data-reading-point]')).toHaveCount(2);
  await expect(wheel.locator('[data-ascendant="true"]')).toContainText('ASC');
  const containerStyle = await page.getByTestId('reading-planets').evaluate((element) => {
    const style = getComputedStyle(element);
    return { background: style.backgroundColor, border: style.borderTopWidth };
  });
  expect(containerStyle).toEqual({ background: 'rgba(0, 0, 0, 0)', border: '0px' });
  const nativeLinks = chartRelations(chart);
  for (const body of Object.values(chart.points)) {
    if (body.number === null) continue;
    const count = nativeLinks.filter(
      (line) => line.from.key === body.key || line.to.key === body.key,
    ).length;
    const badge = selector.locator(`[data-planet-choice="${body.key}"] [data-share-percent]`);
    await expect(badge).toHaveText(
      nativeLinks.length ? `${Math.round((count * 100) / (nativeLinks.length * 2))}%` : '—',
    );
    const circle = await selector.locator(`[data-planet-circle="${body.key}"]`).boundingBox();
    const box = await badge.boundingBox();
    expect(circle!.height).toBeCloseTo(circle!.width, 0);
    expect(box!.x).toBeGreaterThan(circle!.x + circle!.width / 2);
    expect(box!.y).toBeLessThanOrEqual(circle!.y + 2);
  }
  const bodies = ['sun', 'moon', 'mercury', 'venus', 'mars', 'jupiter', 'saturn'] as const;
  const expected = [0, 1, 2, 3].map(
    (index) => bodies.filter((key) => chart.points[key].sign % 4 === index).length,
  );
  for (let index = 0; index < 4; index++)
    await expect(page.locator(`[data-element="${index}"]`)).toHaveAttribute(
      'data-count',
      String(expected[index]),
    );
  await expect(page.locator('[data-reading-topic]')).toHaveCount(4);
  for (const [key, number] of [
    ['work', 10],
    ['money', 2],
    ['love', 7],
    ['family', 4],
  ] as const) {
    const house = chart.houses[number - 1];
    await expect(page.locator(`[data-topic-evidence="${key}"] [data-ruler]`)).toHaveAttribute(
      'data-ruler',
      house.ruler.key,
    );
    await expect(page.locator(`[data-topic-evidence="${key}"] [data-ruler]`)).toHaveAttribute(
      'data-ruler-house',
      String(house.ruler.house),
    );
  }
  await page
    .getByTestId('reading-planet-selector')
    .getByRole('button', { name: `${natalCopy.zh.showOnChart} · ${zh.c_planet_moon}`, exact: true })
    .click();
  await expect(wheel.locator('[data-planet="moon"]')).toHaveAttribute('data-highlighted', 'true');
  await expect(wheel.locator('[data-planet="sun"]')).toHaveAttribute('data-highlighted', 'false');
  await page.getByRole('button', { name: natalCopy.zh.reset, exact: true }).click();
  await expect(wheel.locator('[data-highlighted="true"]')).toHaveCount(0);
  expect(
    await wheel
      .locator('[data-planet]')
      .evaluateAll((nodes) =>
        nodes.map((node) => [
          node.getAttribute('data-planet'),
          node.getAttribute('data-longitude'),
        ]),
      ),
  ).toEqual(positions);
  expect(calculations).toBe(baseline);
  expect(modelRequests).toEqual([]);
  await page.screenshot({
    path: `test-results/reading-overview-${info.project.name}.png`,
    animations: 'disabled',
  });
  await page
    .getByTestId('reading-contents')
    .getByRole('button', { name: natalCopy.zh.sections[2], exact: true })
    .click();
  await page.screenshot({
    path: `test-results/reading-planet-circles-${info.project.name}.png`,
    animations: 'disabled',
  });
  await page
    .getByTestId('reading-contents')
    .getByRole('button', { name: natalCopy.zh.sections[1], exact: true })
    .click();
  await page.screenshot({
    path: `test-results/reading-elements-${info.project.name}.png`,
    animations: 'disabled',
  });
  await page
    .getByTestId('reading-contents')
    .getByRole('button', { name: natalCopy.zh.sections[5], exact: true })
    .click();
  await page.screenshot({
    path: `test-results/reading-topics-${info.project.name}.png`,
    animations: 'disabled',
  });
});

test('planet symbols and house cusps preserve native Thai positions and explain whole-sign boundaries', async ({
  page,
}) => {
  await prepare(page);
  const calculation = page.waitForResponse((response) =>
    response.url().endsWith('/api/thai-chart/preview'),
  );
  await page.goto('/chart');
  const native: ThaiChart = await (await calculation).json();
  const tables = page.getByTestId('planet-cusp-tables');
  await expect(tables.getByRole('heading', { name: zh.c_planetHouseTitle })).toBeVisible();
  await expect(tables.locator('img')).toHaveCount(0);
  await expect(tables.locator('[data-natal-point]')).toHaveCount(11);
  await expect(tables.locator('[data-planet-symbol="sun"]')).toHaveText('☉');
  await expect(tables.locator('[data-planet-symbol="moon"]')).toHaveText('☾');
  await expect(tables.locator('[data-planet-symbol="mercury"]')).toHaveText('☿');
  const codes = [
    'ARI',
    'TAU',
    'GEM',
    'CAN',
    'LEO',
    'VIR',
    'LIB',
    'SCO',
    'SAG',
    'CAP',
    'AQU',
    'PIS',
  ];
  for (const point of Object.values(native.chart!.points)) {
    const row = tables.locator(`[data-natal-point="${point.key}"]`);
    await expect(row.locator('abbr')).toHaveText(codes[point.sign]);
    await expect(row).toContainText(
      `${point.degrees}°${String(Math.floor(point.minutes)).padStart(2, '0')}′`,
    );
  }
  await expect(tables.locator('[data-house-cusp]')).toHaveCount(12);
  for (const house of native.chart!.houses) {
    const row = tables.locator(`[data-house-cusp="${house.number}"]`);
    await expect(row).toHaveAttribute('data-longitude', String(house.sign * 30));
    await expect(row.locator('abbr')).toHaveText(codes[house.sign]);
    await expect(row).toContainText('0°00′');
  }
  await tables.locator('[data-natal-point="sun"]').click();
  const pointDialog = page.getByRole('dialog', { name: zh.c_planet_sun, exact: true });
  await expect(pointDialog).toContainText(native.chart!.points.sun.longitudeDegrees.toFixed(4));
  await page.keyboard.press('Escape');
  await tables.locator('[data-house-cusp="1"]').click();
  const cuspDialog = page.getByRole('dialog', { name: `${zh.c_houseCuspsTitle} 1`, exact: true });
  await expect(cuspDialog).toContainText(zh.c_wholeStartNote);
  await expect(cuspDialog).toContainText(`${(native.chart!.houses[0].sign * 30).toFixed(2)}°`);
  await page.keyboard.press('Escape');
  expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBe(true);
});

test('chart enlargement preserves Thai positions and closes only the active dialog', async ({
  page,
}, info) => {
  await prepare(page);
  await page.goto('/chart');
  const expand = page.getByRole('button', { name: zh.c_expandChart, exact: true });
  await expect(expand).toBeVisible();
  const original = page.getByTestId('thai-orbit-wheel');
  const sunLongitude = await original.locator('[data-planet="sun"]').getAttribute('data-longitude');
  await expect(original.locator('[data-zodiac-label]')).toHaveText([
    'ARI',
    'TAU',
    'GEM',
    'CAN',
    'LEO',
    'VIR',
    'LIB',
    'SCO',
    'SAG',
    'CAP',
    'AQU',
    'PIS',
  ]);
  await expand.click();
  const zoom = page.getByRole('dialog', { name: zh.c_expandedChart, exact: true });
  await expect(zoom).toBeVisible();
  await expect(zoom.locator('[data-planet="sun"]')).toHaveAttribute(
    'data-longitude',
    sunLongitude!,
  );
  await zoom.locator('[data-planet="sun"]').click();
  const details = page.getByRole('dialog', { name: zh.c_planet_sun, exact: true });
  await expect(details).toBeVisible();
  await expect(details).toContainText(profile.birth_date);
  await page.keyboard.press('Escape');
  await expect(details).toHaveCount(0);
  await expect(zoom).toBeVisible();
  await page.screenshot({ path: `test-results/chart-expanded-${info.project.name}.png` });
  await page.keyboard.press('Escape');
  await expect(zoom).toHaveCount(0);
  await expect(expand).toBeFocused();
  await expectDock(page);
  await page.getByRole('button', { name: zh.c_traditionalView, exact: true }).click();
  await expand.click();
  await expect(zoom.getByRole('img', { name: zh.th_natal, exact: true })).toBeVisible();
  await zoom.getByRole('button', { name: zh.pickerDone, exact: true }).click();
  await expect(zoom).toHaveCount(0);
});

test('unknown birth time offers completion instead of invented planet or house readings', async ({
  page,
}) => {
  await prepare(page, 'zh', false);
  await page.goto('/chart');
  const setup = page.getByRole('dialog', { name: zh.c_chartSetupTitle, exact: true });
  await expect(setup).toBeVisible();
  await setup.getByRole('button', { name: zh.pickerCancel, exact: true }).click();
  const chartPage = page.getByTestId('jy-chart-page');
  await expect(chartPage.getByTestId('birthday-overview')).toBeVisible();
  for (const text of [
    zh.th_chartPending,
    zh.th_factOnly,
    zh.th_calendar,
    zh.w_bazi,
    zh.th_rules,
    zh.th_noGuarantee,
    zh.w_life,
    zh.j_themeOverview,
    zh.j_chartMethods,
  ]) {
    await expect(chartPage.getByText(text, { exact: true })).toHaveCount(0);
  }
  await expect(page.getByTestId('chart-reading-button')).toHaveCount(0);
  await page.goto('/chart/reading');
  await expect(page.getByTestId('reading-incomplete')).toContainText(zh.ux_unknownBirthNote);
  await expect(page.getByTestId('reading-planets')).toHaveCount(0);
  await expect(page.getByTestId('reading-houses')).toHaveCount(0);
  await page
    .getByTestId('reading-incomplete')
    .getByRole('button', { name: zh.ux_completeChart, exact: true })
    .click();
  await expect(page).toHaveURL(/\/birth$/);
});

for (const language of ['zh', 'th', 'vi', 'en'] as const) {
  test(`reading action and page follow ${language} at 320px with larger text`, async ({ page }) => {
    const copy = copies[language];
    await page.setViewportSize({ width: 320, height: 740 });
    await prepare(page, language);
    await page.goto('/chart');
    await expect(page.getByTestId('natal-birth-card')).toBeVisible();
    await page.evaluate(() => {
      document.documentElement.style.fontSize = '20px';
    });
    await expect(page.getByTestId('chart-reading-button')).toHaveText(copy.r_all);
    await expectDock(page);
    await page.getByTestId('chart-reading-button').click();
    await expect(page.getByRole('heading', { name: copy.r_title, exact: true })).toBeVisible();
    await expect(page.getByTestId('reading-planets').locator('[data-reading-detail]')).toHaveCount(
      10,
    );
    await expect(page.getByTestId('reading-houses').locator('details')).toHaveCount(12);
    await expect(page.getByTestId('chart-reading-page')).not.toContainText('undefined');
    expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBe(
      true,
    );
  });
}
