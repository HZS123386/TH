import { expect, test, type Page } from '@playwright/test';
import { readFile } from 'node:fs/promises';
import { chooseChineseDate } from './pickers';
import type { BaziTestResult } from '../src/lib/bazi';
import type { Language } from '../src/types';

async function language(page: Page, prefill = false) {
  await page.addInitScript((prefill) => {
    localStorage.setItem('sabai.language', 'zh-CN');
    localStorage.setItem('sabai.languageConfirmed', '1');
    if (prefill)
      localStorage.setItem(
        'wanjai.birth',
        JSON.stringify({
          display_name: '',
          birth_date: '1995-08-17',
          birth_time: '10:30',
          timezone: 'Asia/Shanghai',
          birthplace: '',
          language: 'zh',
        }),
      );
  }, prefill);
}

test('public test page accepts a birth date without changing a guest profile and downloads its report', async ({
  page,
}, info) => {
  const errors: string[] = [];
  page.on('pageerror', (error) => errors.push(error.message));
  await language(page);
  await page.goto('/tools/bazi');
  await expect(page.getByTestId('bazi-test-page')).toBeVisible();
  await expect(page.getByRole('radio', { name: '八字排盘', exact: true })).toBeChecked();
  await expect(page.getByText('选择数据来源', { exact: true })).toHaveCount(0);
  await chooseChineseDate(page, '1995-08-17');
  await page.getByRole('button', { name: '生成结果与解读报告', exact: true }).click();
  await expect(page.getByTestId('bazi-source-github')).toContainText('乙亥');
  await expect(page.getByTestId('bazi-report')).toBeVisible();
  expect(await page.evaluate(() => localStorage.getItem('wanjai.birth'))).toBeNull();
  expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBe(true);
  const download = page.waitForEvent('download');
  await page.getByRole('button', { name: '保存报告', exact: true }).click();
  expect((await download).suggestedFilename()).toMatch(/^Bazi-.*\.html$/);
  await page.screenshot({
    path: `test-results/bazi-report-${info.project.name}.png`,
    fullPage: true,
  });
  await page.reload();
  await expect(page.getByTestId('bazi-test-page')).toBeVisible();
  expect(errors).toEqual([]);
});

test('reading cards use default calculations and generate a clean report', async ({
  page,
}, info) => {
  await language(page, true);
  await page.route('**/api/config', async (route) => {
    const response = await route.fetch();
    await route.fulfill({ json: { ...(await response.json()), roxy: { enabled: true } } });
  });
  await page.route('**/api/bazi/test', async (route) => {
    const input = route.request().postDataJSON();
    expect(input.source).toBe('roxy');
    expect(input.gender).toBeNull();
    if (input.topics.includes('annual')) {
      expect(input.topics).toEqual(['chart', 'annual']);
      expect(input.year).toBe(2026);
    } else {
      expect(input.topics).toEqual(['chart', 'strength']);
      expect(input.focus).toBe('work');
    }
    const chart = {
      pillars: { year: '乙亥', month: '甲申', day: '庚辰', hour: '辛巳' },
      visible_element_counts: { 木: 2, 火: 1, 土: 1, 金: 3, 水: 1 },
      time_known: true,
      engine: 'RoxyAPI',
      engine_version: 'v2',
      calculation_version: 'test-fixture',
      time_convention: 'test-only',
      calculation_time: null,
      source: '',
      notes: [],
    };
    const value: BaziTestResult = {
      report_id: 'intercepted-test-fixture',
      generated_at: '2026-11-07T12:00:00+07:00',
      input,
      calculation_input: {
        birth_date: input.profile.birth_date,
        birth_time: input.profile.birth_time,
        timezone: input.profile.timezone,
        internal: 'INTERNAL_CALCULATION_MARKER',
      },
      sources: {
        roxy: {
          status: 'ready',
          chart,
          errors: {},
          details: {
            strength: {
              cached: false,
              language: 'zh-Hans',
              data: {
                verdict: 'very-strong',
                score: 4.9,
                factors: [],
                internal: 'INTERNAL_RAW_MARKER',
              },
            },
            luck: { cached: false, language: 'zh-Hans', data: { startAge: 6, luckPillars: [] } },
            annual: {
              cached: false,
              language: 'zh-Hans',
              data: {
                year: 2026,
                annualPillar: { stem: { chinese: '丙' }, branch: { chinese: '午' } },
              },
            },
          },
        },
      },
      comparison: {
        status: 'match',
        rows: Object.entries(chart.pillars).map(([pillar, value]) => ({
          pillar: pillar as 'year',
          github: value,
          roxy: value,
          match: true,
        })),
        scope: 'four-pillars-only',
      },
      report: {
        title: '解读报告',
        language: 'zh',
        sections: [
          {
            id: 'chart',
            title: 'Roxy 解读样例',
            source: 'RoxyAPI / intercepted test',
            paragraphs: ['这是浏览器拦截样例，用于验证报告展示，不是真实接口解读。'],
          },
        ],
      },
    };
    for (const topic of ['strength', 'luck', 'annual'] as const) {
      if (!input.topics.includes(topic)) delete value.sources.roxy!.details![topic];
    }
    await route.fulfill({ json: value });
  });
  await page.goto('/tools/bazi');
  await expect(page.getByText('选择要测的内容', { exact: true })).toHaveCount(0);
  await expect(page.getByRole('radio', { name: '十年大运', exact: true })).toHaveCount(0);
  await page.getByRole('radio', { name: '全年运势', exact: true }).check();
  await page.getByLabel('要查看的年份', { exact: true }).fill('2026');
  await page.getByRole('button', { name: '生成结果与解读报告', exact: true }).click();
  await expect(page.getByTestId('bazi-annual-facts')).toContainText('丙午');
  await expect(page.getByTestId('bazi-report')).toContainText('中国占星 · 全年运势');
  const annualDownload = page.waitForEvent('download');
  await page.getByRole('button', { name: '保存报告', exact: true }).click();
  const annualHtml = await readFile((await (await annualDownload).path())!, 'utf8');
  expect(annualHtml).toContain('丙午');
  expect(annualHtml).toContain('2026');
  expect(annualHtml).not.toContain('INTERNAL_CALCULATION_MARKER');
  await page.getByRole('radio', { name: '八字事业', exact: true }).check();
  await expect(page.getByTestId('bazi-report')).toHaveCount(0);
  await expect(page.getByLabel('要查看的年份', { exact: true })).toHaveCount(0);
  await page.getByTestId('bazi-reading-cards').scrollIntoViewIfNeeded();
  await page.screenshot({ path: `test-results/bazi-category-${info.project.name}.png` });
  await page.getByRole('button', { name: '生成结果与解读报告', exact: true }).click();
  await expect(page.getByTestId('bazi-comparison')).toHaveCount(0);
  await expect(page.getByTestId('bazi-strength-facts')).toContainText('4.9');
  await expect(page.getByTestId('bazi-strength-facts')).toContainText('极强');
  await expect(page.getByTestId('bazi-luck-facts')).toHaveCount(0);
  await expect(page.getByTestId('bazi-annual-facts')).toHaveCount(0);
  await expect(page.getByTestId('bazi-report')).toContainText('浏览器拦截样例');
  await expect(page.getByText('把解读放回生活', { exact: true })).toHaveCount(0);
  await expect(page.getByText('阅读范围', { exact: true })).toHaveCount(0);
  await expect(page.getByTestId('bazi-report')).toContainText('中国占星 · 八字事业');
  await expect(page.locator('[data-testid="bazi-results"] details')).toHaveCount(0);
  await expect(page.getByText('查看 Roxy 原始返回', { exact: true })).toHaveCount(0);
  await expect(page.getByText('查看计算依据', { exact: true })).toHaveCount(0);
  const download = page.waitForEvent('download');
  await page.getByRole('button', { name: '保存报告', exact: true }).click();
  const html = await readFile((await (await download).path())!, 'utf8');
  expect(html).toContain('中国占星 · 八字事业');
  expect(html).toContain('浏览器拦截样例');
  expect(html).toContain('4.9');
  expect(html).toContain('极强');
  expect(html).not.toContain('INTERNAL_RAW_MARKER');
  expect(html).not.toContain('INTERNAL_CALCULATION_MARKER');
  expect(html).not.toContain('<details>');
  expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBe(true);
  await page.getByRole('radio', { name: '八字财运', exact: true }).check();
  await expect(page.getByTestId('bazi-report')).toHaveCount(0);
});

const localizedReports = {
  zh: {
    locale: 'zh-CN',
    factor: '金在金月处于旺势。',
    advice: '先区分固定支出与可调整的预算，再按实际承受能力安排新的支出。',
  },
  en: {
    locale: 'en-US',
    factor: 'Metal is prosperous in a Metal month',
    advice:
      'Separate fixed commitments from flexible spending before deciding how much to allocate.',
  },
  th: {
    locale: 'th',
    factor: 'ธาตุทองเกิดในเดือนธาตุทองและมีกำลังรุ่งเรือง',
    advice: 'แยกภาระค่าใช้จ่ายที่จำเป็นออกจากงบที่ปรับได้ แล้วค่อยวางแผนการใช้จ่ายใหม่ตามกำลังจริง',
  },
  vi: {
    locale: 'vi',
    factor: 'Kim ở tháng Kim có trạng thái vượng.',
    advice: 'Hãy tách chi phí cố định khỏi ngân sách linh hoạt trước khi quyết định khoản chi mới.',
  },
};
const baziCopies = JSON.parse(
  await readFile(new URL('../src/content/bazi-test.json', import.meta.url), 'utf8'),
);
for (const code of ['zh', 'en', 'th', 'vi'] as Language[]) {
  test(`calculation, advice and saved report use the ${code} system language`, async ({
    page,
  }, info) => {
    const copy = baziCopies[code],
      sample = localizedReports[code];
    await page.addInitScript(
      ({ code, locale }) => {
        localStorage.setItem('sabai.language', locale);
        localStorage.setItem('sabai.languageConfirmed', '1');
        localStorage.setItem(
          'wanjai.birth',
          JSON.stringify({
            display_name: '',
            birth_date: '1995-08-17',
            birth_time: '10:30',
            timezone: 'Asia/Shanghai',
            birthplace: '',
            language: code,
          }),
        );
      },
      { code, locale: sample.locale },
    );
    await page.route('**/api/config', async (route) => {
      const response = await route.fetch();
      await route.fulfill({ json: { ...(await response.json()), roxy: { enabled: true } } });
    });
    await page.route('**/api/bazi/test', async (route) => {
      const input = route.request().postDataJSON();
      expect(input.profile.language).toBe(code);
      expect(input.focus).toBe('money');
      expect(input.topics).toEqual(['chart', 'strength']);
      const result: BaziTestResult = {
        report_id: 'localized-intercepted-fixture',
        generated_at: '2026-11-07T12:00:00+08:00',
        input,
        calculation_input: {
          birth_date: input.profile.birth_date,
          birth_time: input.profile.birth_time,
          timezone: input.profile.timezone,
        },
        sources: {
          roxy: {
            status: 'ready',
            chart: {
              pillars: { year: '乙亥', month: '甲申', day: '庚辰', hour: '辛巳' },
              visible_element_counts: { 木: 2, 火: 1, 土: 1, 金: 3, 水: 1 },
              time_known: true,
              engine: 'RoxyAPI',
              engine_version: 'v2',
              calculation_version: 'intercepted-test',
              time_convention: 'local',
              calculation_time: null,
              source: '',
              notes: [],
            },
            details: {
              chart: {
                cached: false,
                language: 'en',
                data: { dayMaster: { chinese: '庚', element: 'Metal' } },
              },
              strength: {
                cached: false,
                language: 'en',
                data: {
                  verdict: 'very-strong',
                  score: 4.9,
                  factors: [
                    {
                      chinese: '得令',
                      contribution: 3,
                      detail: 'Metal is prosperous in a Metal month',
                    },
                  ],
                  favorableElements: ['Water', 'Wood'],
                  unfavorableElements: ['Metal'],
                },
              },
            },
          },
        },
        comparison: { status: 'match', rows: [], scope: 'four-pillars-only' },
        report: {
          title: copy.readings.money.title,
          language: code,
          generation: { state: 'ready' },
          translations: { 'strength.factors.0.detail': sample.factor },
          sections: [
            {
              id: 'advice',
              title: copy.reportSections.advice,
              source: 'intercepted-test',
              language: code,
              paragraphs: [sample.advice],
            },
          ],
        },
      };
      await route.fulfill({ json: result });
    });
    await page.goto('/tools/bazi');
    await page.getByRole('radio', { name: copy.readings.money.title, exact: true }).check();
    await page.getByRole('button', { name: copy.generate, exact: true }).click();
    await expect(page.getByTestId('bazi-strength-facts')).toContainText(sample.factor);
    await expect(page.getByTestId('bazi-report')).toContainText(sample.advice);
    if (code !== 'en')
      await expect(page.getByTestId('bazi-strength-facts')).not.toContainText(
        'Metal is prosperous',
      );
    if (code !== 'zh')
      expect(await page.getByTestId('bazi-results').textContent()).not.toMatch(/[\u3400-\u9fff]/);
    const download = page.waitForEvent('download');
    await page.getByRole('button', { name: copy.download, exact: true }).click();
    const html = await readFile((await (await download).path())!, 'utf8');
    expect(html).toContain(sample.advice);
    expect(html).toContain(sample.factor);
    expect(html).not.toContain('<details>');
    await page
      .getByTestId('bazi-report')
      .screenshot({ path: `test-results/bazi-report-${code}-${info.project.name}.png` });
    expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBe(
      true,
    );
  });
}
