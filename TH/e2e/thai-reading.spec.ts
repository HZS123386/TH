import { expect, test, type Page } from '@playwright/test';
import { readFile } from 'node:fs/promises';
import { chooseChineseDate } from './pickers';
import type { ThaiReadingResult } from '../src/lib/thaiReading';
import copy from '../src/content/thai-test.json' with { type: 'json' };
import zh from '../src/locales/zh-CN.json' with { type: 'json' };
import type { Language } from '../src/types';

const thaiReadingCopy = (language: Language) => copy[language];

const profile = {
  display_name: '',
  birth_date: '1995-08-17',
  birth_time: '09:30',
  timezone: 'Asia/Bangkok',
  birthplace: 'Bangkok, Thailand',
  language: 'zh',
};
async function setup(page: Page, language: Language = 'zh', prefill = true) {
  await page.addInitScript(
    ({ language, prefill, profile }) => {
      localStorage.setItem('sabai.language', language);
      localStorage.setItem('sabai.languageConfirmed', '1');
      if (prefill) localStorage.setItem('wanjai.birth', JSON.stringify(profile));
    },
    { language, prefill, profile },
  );
}

test('old test URL opens Thai astrology, accepts a real birthplace and calculates a real chart', async ({
  page,
}, info) => {
  const errors: string[] = [];
  page.on('pageerror', (error) => errors.push(error.message));
  await setup(page, 'zh', false);
  await page.goto('/bazi-test');
  await expect(page.getByTestId('thai-test-page')).toBeVisible();
  await expect(page.getByRole('radio', { name: '本命星盘', exact: true })).toBeChecked();
  const generate = page.getByRole('button', { name: '生成星盘与解读报告', exact: true });
  await expect(generate).toBeDisabled();
  await chooseChineseDate(page, '1995-08-17');
  await page.getByRole('checkbox', { name: zh.timeUnknown, exact: true }).uncheck();
  await page.getByRole('button', { name: '出生时间', exact: true }).click();
  await page.getByRole('dialog').getByRole('button', { name: '完成', exact: true }).click();
  await page.getByRole('button', { name: zh.birthplace, exact: true }).click();
  await page.getByRole('dialog').getByRole('button', { name: '完成', exact: true }).click();
  const responsePromise = page.waitForResponse((response) =>
    response.url().endsWith('/api/thai-reading'),
  );
  await generate.click();
  const response = await responsePromise;
  expect(response.status()).toBe(200);
  const result: ThaiReadingResult = await response.json();
  expect(result.natal.engine.name).toBe('thai-astrology');
  expect(result.natal.status).toBe('ready');
  const copy = thaiReadingCopy('zh');
  await expect(page.getByTestId('thai-result-input')).toContainText('1995-08-17');
  await expect(page.getByTestId('thai-result-ascendant')).toHaveCount(0);
  await expect(page.getByTestId('thai-report')).toContainText(copy.states.unconfigured);
  expect(await page.evaluate(() => localStorage.getItem('wanjai.birth'))).toBeNull();
  expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBe(true);
  await page.screenshot({
    path: `test-results/thai-reading-real-${info.project.name}.png`,
    fullPage: true,
  });
  await page.reload();
  await expect(page.getByTestId('thai-test-page')).toBeVisible();
  expect(errors).toEqual([]);
});

for (const language of ['zh', 'en', 'th', 'vi'] as const) {
  test(`six Thai themes and downloaded report follow ${language} at small width`, async ({
    page,
  }, info) => {
    const b = thaiReadingCopy(language);
    await setup(page, language);
    let result: ThaiReadingResult;
    let generationRequests = 0;
    await page.route('**/api/thai-reading', async (route) => {
      generationRequests++;
      const input = route.request().postDataJSON();
      expect(input.profile.language).toBe(language);
      expect(input).not.toHaveProperty('source');
      result = {
        report_id: 'browser-fixture',
        generated_at: '2026-11-07T12:00:00+07:00',
        input,
        natal: {
          status: 'ready',
          profile_revision: 0,
          chart: null,
          engine: {} as never,
          calendar: {} as never,
          taksa: null,
          location: null,
          time_known: true,
          required: [],
        },
        report: {
          title: `${b.category} · ${b.readings[input.reading as 'work'].title}`,
          summary: b.categoryIntro,
          language,
          generation: { state: 'ready', version: 'browser-test-fixture' },
          sections: [
            {
              id: 'opportunities',
              title: b.sections.opportunities,
              items: [
                {
                  title: b.categoryTitle,
                  text: b.intro,
                  period: input.reading === 'annual' ? { year: input.year, month: 4 } : null,
                  signals: [b.categoryIntro, b.yearNote],
                  response: b.intro,
                  example: b.required,
                },
              ],
            },
            {
              id: 'advice',
              title: b.sections.advice,
              items: [
                {
                  title: b.readings[input.reading as 'work'].title,
                  text: b.intro,
                  period: input.reading === 'annual' ? { year: input.year, month: 4 } : null,
                  steps: [b.intro, b.categoryIntro, b.yearNote, b.required],
                  example: b.required,
                  pitfall: b.categoryIntro,
                  check: b.yearNote,
                },
              ],
            },
          ],
        },
      };
      await route.fulfill({ json: result });
    });
    await page.goto('/thai-test');
    for (const card of Object.values(b.readings))
      await expect(page.getByRole('radio', { name: card.title, exact: true })).toBeEnabled();
    await page.getByRole('radio', { name: b.readings.annual.title, exact: true }).check();
    await page.getByLabel(b.year, { exact: true }).fill('2027');
    await page.getByRole('button', { name: b.generate, exact: true }).click();
    await expect(page.getByTestId('thai-report')).toContainText('2027');
    await expect(page.getByTestId('thai-report-summary')).toContainText(b.categoryIntro);
    const unlock = page.getByTestId('thai-unlock-button');
    const advice = page.getByTestId('thai-locked-content');
    await expect(unlock).toHaveText(b.unlock);
    await expect(advice).toHaveAttribute('data-locked', 'true');
    await expect(advice).toHaveAttribute('inert', '');
    await expect(advice).toHaveCSS('filter', 'blur(6px)');
    await expect(
      page.getByRole('heading', { name: b.sections.opportunities, exact: true }),
    ).toBeVisible();
    await expect(page.getByRole('heading', { name: b.sections.advice, exact: true })).toHaveCount(
      0,
    );
    await expect(page.getByTestId('thai-lock-badge')).toBeVisible();
    await page.setViewportSize({ width: 320, height: 800 });
    await page.evaluate(() => {
      document.documentElement.style.fontSize = '20px';
    });
    expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBe(
      true,
    );
    const buttonBox = await unlock.boundingBox();
    const navBox = await page.getByRole('navigation').boundingBox();
    expect(buttonBox!.y + buttonBox!.height).toBeLessThanOrEqual(navBox!.y);
    expect(navBox!.y - buttonBox!.y - buttonBox!.height).toBeLessThan(20);
    await page.evaluate(() => window.scrollTo(0, 0));
    expect((await unlock.boundingBox())!.y).toBeCloseTo(buttonBox!.y, 0);
    const previewDownload = page.waitForEvent('download');
    await page.getByRole('button', { name: b.downloadPreview, exact: true }).click();
    const previewHtml = await readFile((await (await previewDownload).path())!, 'utf8');
    expect(previewHtml).toContain(b.lockedSave);
    expect(previewHtml).not.toContain(b.intro);
    expect(previewHtml).not.toContain(b.sections.advice);
    await unlock.click();
    await expect(advice).toHaveAttribute('data-locked', 'false');
    await expect(advice).not.toHaveAttribute('inert');
    await expect(advice).toHaveCSS('filter', 'none');
    await expect(unlock).toHaveCount(0);
    await expect(page.getByTestId('thai-lock-badge')).toHaveCount(0);
    await expect(page.getByRole('heading', { name: b.sections.advice, exact: true })).toBeVisible();
    expect(generationRequests).toBe(1);
    await page.getByRole('radio', { name: b.readings.work.title, exact: true }).check();
    await expect(page.getByTestId('thai-report')).toHaveCount(0);
    await expect(page.getByLabel(b.year, { exact: true })).toHaveCount(0);
    await page.getByRole('button', { name: b.generate, exact: true }).click();
    await expect(page.getByTestId('thai-report')).toContainText(b.readings.work.title);
    await expect(advice).toHaveAttribute('data-locked', 'true');
    await page.getByTestId('thai-unlock-button').click();
    await expect(advice).toHaveAttribute('data-locked', 'false');
    expect(generationRequests).toBe(2);
    const download = page.waitForEvent('download');
    await page.getByRole('button', { name: b.download, exact: true }).click();
    const file = await download;
    expect(file.suggestedFilename()).toMatch(/^Thai-Astrology-.*\.html$/);
    const html = await readFile((await file.path())!, 'utf8');
    expect(html).toContain(`lang="${language}"`);
    expect(html).toContain(b.sections.advice);
    expect(html).toContain(b.summary);
    expect(html).toContain(b.example);
    expect(html).toContain(b.signals);
    expect(html).toContain(b.pitfall);
    expect(html).toContain(b.check);
    expect(html).toContain(b.required);
    expect(html).not.toContain(b.lockedSave);
    expect(html).not.toContain(b.planets.ascendant);
    expect(html).not.toContain('calculation_input');
    expect(html).not.toContain('Roxy');
    if (language !== 'th')
      expect(await page.getByTestId('thai-test-page').innerText()).not.toMatch(/[\u0e00-\u0e7f]/);
    await page.setViewportSize({ width: 320, height: 800 });
    await page.evaluate(() => {
      document.documentElement.style.fontSize = '20px';
    });
    expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBe(
      true,
    );
    await page.getByTestId('thai-reading-cards').scrollIntoViewIfNeeded();
    await page.screenshot({
      path: `test-results/thai-reading-${language}-${info.project.name}.png`,
    });
  });
}
