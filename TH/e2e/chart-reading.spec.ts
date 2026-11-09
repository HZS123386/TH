import { expect, test, type Page } from '@playwright/test';
import zh from '../src/locales/zh-CN.json' with { type: 'json' };
import th from '../src/locales/th.json' with { type: 'json' };
import vi from '../src/locales/vi.json' with { type: 'json' };
import en from '../src/locales/en-US.json' with { type: 'json' };
import zhData from '../src/data/wanjai-zh.json' with { type: 'json' };
import { chartRelations } from '../src/lib/chartGeometry';
import type { ThaiChart } from '../src/lib/thai';

const profile = {
  display_name: 'Nok',
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
    .getByRole('button', { name: zh.w_home, exact: true })
    .boundingBox();
  expect(last!.y + last!.height).toBeLessThanOrEqual(bottom.y);
  await page.getByTestId('chart-reading-button').click();
  await expect(page).toHaveURL(/\/chart\/reading$/);
  await expect(page.getByRole('heading', { name: zh.r_title, exact: true })).toBeVisible();
  await expect(page.getByTestId('reading-birth-source')).toContainText(profile.birth_date);
  await expect(page.getByTestId('reading-planets').locator('details')).toHaveCount(11);
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
    page.getByRole('navigation').getByRole('button', { name: zh.w_chart, exact: true }),
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

test('unknown birth time offers completion instead of invented planet or house readings', async ({
  page,
}) => {
  await prepare(page, 'zh', false);
  await page.goto('/chart');
  await page.getByTestId('chart-reading-button').click();
  await expect(page.getByTestId('reading-incomplete')).toContainText(zh.th_unknown);
  await expect(page.getByTestId('reading-planets')).toHaveCount(0);
  await expect(page.getByTestId('reading-houses')).toHaveCount(0);
  await page
    .getByTestId('reading-incomplete')
    .getByRole('button', { name: zh.j_editBirth, exact: true })
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
    await expect(page.getByTestId('reading-planets').locator('details')).toHaveCount(11);
    await expect(page.getByTestId('reading-houses').locator('details')).toHaveCount(12);
    await expect(page.getByTestId('chart-reading-page')).not.toContainText('undefined');
    expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBe(
      true,
    );
  });
}
