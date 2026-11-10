import { expect, test } from '@playwright/test';
import { readFile } from 'node:fs/promises';
import zh from '../src/locales/zh-CN.json' with { type: 'json' };
import natalCopy from '../src/content/natal-reading.json' with { type: 'json' };
import { selectWheel } from './pickers';
import type { Fortune } from '../src/lib/fortune';
import type { ThaiChart } from '../src/lib/thai';
import thaiCopy from '../src/content/thai-test.json' with { type: 'json' };

const profile = {
  display_name: '体验用户',
  gender: 'female',
  birth_date: '1998-06-15',
  birth_time: '09:30',
  birthplace: '中国，上海市',
  country_code: 'CN',
  location_id: 'geonames:1796236',
  timezone: 'Asia/Shanghai',
  language: 'zh',
};

async function prepare(page: import('@playwright/test').Page, unknown = false) {
  await page.addInitScript(
    ({ profile, unknown }) => {
      if (window !== window.top) return;
      localStorage.setItem('sabai.language', 'zh');
      localStorage.setItem('sabai.languageConfirmed', '1');
      if (!localStorage.getItem('wanjai.birth'))
        localStorage.setItem(
          'wanjai.birth',
          JSON.stringify({ ...profile, birth_time: unknown ? null : profile.birth_time }),
        );
    },
    { profile, unknown },
  );
}

test('unknown time has an honest result and completing it returns to the chart, including after editor refresh', async ({
  page,
}, info) => {
  await prepare(page, true);
  await page.route('**/api/thai-chart/preview', (route) =>
    route.request().postDataJSON().birth_time === null
      ? route.fulfill({ status: 503, json: { detail: 'thai_calculation_failed' } })
      : route.continue(),
  );
  await page.goto('/chart');
  await expect(page.getByTestId('birthday-overview')).toContainText(zh.ux_unknownBirthNote);
  await expect(page.getByTestId('thai-chart-placeholder')).toHaveCount(0);
  await expect(page.getByTestId('chart-reading-button')).toHaveCount(0);
  await page.screenshot({ path: `test-results/ux-birthday-${info.project.name}.png` });
  await page
    .getByTestId('birthday-overview')
    .getByRole('button', { name: zh.ux_completeChart, exact: true })
    .click();
  await expect(page).toHaveURL(/\/birth$/);
  await expect(page.getByLabel(zh.name, { exact: true })).toHaveValue(profile.display_name);
  await expect(
    page.getByText(zh.ux_advancedBirth, { exact: true }).locator('..'),
  ).not.toHaveAttribute('open');
  await page.getByRole('checkbox', { name: zh.timeUnknown, exact: true }).uncheck();
  await page.getByRole('button', { name: zh.birthTime, exact: true }).click();
  const time = page.getByRole('dialog', { name: zh.birthTime, exact: true });
  await time.getByRole('option', { name: zh.am, exact: true }).click();
  await selectWheel(time.getByRole('listbox', { name: zh.birthHour, exact: true }), '09');
  await selectWheel(time.getByRole('listbox', { name: zh.birthMinute, exact: true }), '30');
  await time.getByRole('button', { name: zh.pickerDone, exact: true }).click();
  await page.reload();
  // An unsaved edit is intentionally not applied on refresh; the return destination survives.
  await page.getByRole('checkbox', { name: zh.timeUnknown, exact: true }).uncheck();
  await page.getByRole('button', { name: zh.birthTime, exact: true }).click();
  const again = page.getByRole('dialog', { name: zh.birthTime, exact: true });
  await again.getByRole('button', { name: zh.pickerDone, exact: true }).click();
  await page.getByRole('button', { name: zh.ux_saveReturn, exact: true }).click();
  await expect(page).toHaveURL(/\/chart$/);
  await expect(page.getByTestId('natal-birth-card')).toBeVisible();
  await expect(page.getByTestId('chart-reading-button')).toHaveText(zh.r_all);
  await page
    .getByRole('navigation')
    .getByRole('button', { name: zh.ux_reports, exact: true })
    .click();
  await page
    .getByTestId('report-library')
    .getByRole('button', { name: new RegExp('^' + zh.ux_topicReport) })
    .click();
  await expect(page.getByTestId('thai-birth-summary')).toBeVisible();
  await expect(page.getByRole('button', { name: zh.birthDate, exact: true })).toHaveCount(0);
  const annual = thaiCopy.zh;
  await page.getByRole('radio', { name: annual.readings.annual.title, exact: true }).check();
  await page.getByLabel(annual.year, { exact: true }).fill('2027');
  await page.getByRole('button', { name: zh.j_editBirth, exact: true }).click();
  await page.getByRole('button', { name: zh.ux_saveReturn, exact: true }).click();
  await expect(page).toHaveURL(/\/thai-test\?reading=annual&year=2027$/);
  await expect(
    page.getByRole('radio', { name: annual.readings.annual.title, exact: true }),
  ).toBeChecked();
  await expect(page.getByLabel(annual.year, { exact: true })).toHaveValue('2027');
});

test('a summary leads the reading, family advice matches the topic, and saved snapshots retain their original profile', async ({
  page,
}, info) => {
  await prepare(page);
  const calculated = page.waitForResponse((response) =>
    response.url().endsWith('/api/thai-chart/preview'),
  );
  await page.goto('/chart/reading');
  const result: ThaiChart = await (await calculated).json();
  const summary = page.getByTestId('reading-summary');
  await expect(summary.locator('li')).toHaveCount(3);
  const summaryBox = await summary.boundingBox();
  const chartBox = await page.getByTestId('reading-chart').boundingBox();
  expect(summaryBox!.y).toBeLessThan(chartBox!.y);
  const family = page.locator('[data-reading-topic="family"]');
  const ruler = result.chart!.points[result.chart!.houses[3].ruler.key];
  await expect(family).toContainText(natalCopy.zh.topics[3].contexts[ruler.house - 1]);
  await expect(family).toContainText(natalCopy.zh.topics[3].action);
  await expect(family).not.toContainText('确认交付内容');
  await page.getByRole('button', { name: zh.ux_saveReport, exact: true }).click();
  await expect(page.getByTestId('reading-library-actions')).toContainText(zh.ux_savedReport);
  await page.screenshot({ path: `test-results/ux-summary-${info.project.name}.png` });
  await page
    .getByRole('navigation')
    .getByRole('button', { name: zh.ux_reports, exact: true })
    .click();
  const saved = page.getByTestId('saved-readings');
  await expect(saved.getByRole('article')).toHaveCount(1);
  await page.getByRole('button', { name: zh.j_editBirth, exact: true }).click();
  await page.getByLabel(zh.name, { exact: true }).fill('已更新的档案');
  await page.getByRole('button', { name: zh.ux_saveReturn, exact: true }).click();
  await expect(page).toHaveURL(/\/reports$/);
  await expect(page.getByTestId('report-library')).toContainText('已更新的档案');
  await saved.getByRole('button', { name: new RegExp(zh.ux_openSaved) }).click();
  const iframe = page.locator('iframe');
  await expect(iframe).toHaveAttribute('sandbox', '');
  await expect(page.frameLocator('iframe').getByTestId('reading-birth-source')).toContainText(
    profile.display_name,
  );
  await expect(page.frameLocator('iframe').getByTestId('reading-birth-source')).not.toContainText(
    '已更新的档案',
  );
  await page.keyboard.press('Escape');
  const downloading = page.waitForEvent('download');
  await saved.getByRole('button', { name: zh.ux_downloadReport, exact: true }).click();
  const downloaded = await downloading;
  expect(downloaded.suggestedFilename()).toMatch(/\.html$/);
  const html = await readFile((await downloaded.path())!, 'utf8');
  expect(html).toContain(natalCopy.zh.topics[3].action);
  expect(html).toContain('data-longitude=');
  expect(html).not.toContain('<script');
  await page.reload();
  await expect(page.getByTestId('saved-readings').getByRole('article')).toHaveCount(1);
});

test('shared AI limits preserve the reading and use the actual retry time', async ({ page }) => {
  await prepare(page);
  let facts!: Fortune;
  await page.route('**/api/fortune', async (route) => {
    const response = await route.fetch();
    facts = await response.json();
    await route.fulfill({
      response,
      json: { ...facts, generation: { available: true, state: 'rules', cached: false } },
    });
  });
  await page.route('**/api/fortune/narrative', async (route) =>
    route.fulfill({
      json: {
        period: facts.period,
        period_start: facts.period_start,
        period_end: facts.period_end,
        for_date: facts.calendar.date,
        analysis_signature: facts.analysis!.signature,
        narrative: facts.narrative,
        generation: {
          available: true,
          state: 'fallback',
          reason: 'limited',
          limit_scope: 'network',
          retry_after: 2,
          cached: false,
        },
      },
    }),
  );
  await page.goto('/fortune');
  const status = page.getByTestId('fortune-fallback-status');
  await expect(status).toContainText(zh.ux_sharedLimit);
  await expect(status).not.toContainText(zh.ux_personalLimit);
  await expect(status.getByRole('button')).toBeDisabled();
  await expect(page.getByTestId('fortune-narrative')).not.toBeEmpty();
  await expect(status.getByRole('button', { name: zh.ux_retryReading, exact: true })).toBeEnabled({
    timeout: 5000,
  });
});
