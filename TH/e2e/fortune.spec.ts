import { expect, test } from '@playwright/test';
import { chooseChineseDate, navigate, register, selectWheel } from './pickers';
import zh from '../src/locales/zh-CN.json' with { type: 'json' };
import en from '../src/locales/en-US.json' with { type: 'json' };
import type { Fortune } from '../src/lib/fortune';
import type { Page } from '@playwright/test';

const signIds = [
  'aries',
  'taurus',
  'gemini',
  'cancer',
  'leo',
  'virgo',
  'libra',
  'scorpio',
  'sagittarius',
  'capricorn',
  'aquarius',
  'pisces',
];

async function expectReadings(page: Page, result: Fortune, copy = zh) {
  await expect(page.getByTestId('fortune-focus')).toHaveAttribute('data-period', result.period);
  await expect(page.getByTestId('fortune-focus')).toContainText(result.birth.date);
  await expect(page.getByTestId('fortune-focus')).toContainText(result.narrative.affirmation);
  for (const paragraph of result.narrative.paragraphs) {
    await expect(
      page.getByTestId('fortune-narrative').getByText(paragraph, { exact: true }),
    ).toBeVisible();
  }
  const icons = page.getByTestId('jy-fortune-page').locator('img[data-zodiac-sign]');
  await expect(icons).toHaveCount(result.birth.reference_signs.length);
  for (const [index, sign] of result.birth.reference_signs.entries()) {
    await expect(icons.nth(index)).toHaveAttribute('data-zodiac-sign', signIds[sign]);
    await expect(icons.nth(index)).toHaveAttribute(
      'src',
      `/images/zodiac/${signIds[sign]}-96.webp`,
    );
    await expect(icons.nth(index)).toHaveJSProperty('complete', true);
    expect(
      await icons.nth(index).evaluate((image) => (image as HTMLImageElement).naturalWidth),
    ).toBeGreaterThan(0);
  }
  await expect(page.getByTestId('fortune-topics').getByRole('article')).toHaveCount(4);
  for (const topic of ['love', 'money', 'family', 'work'] as const) {
    const reading = result.readings[topic];
    const card = page.getByTestId(`fortune-${topic}`);
    await expect(card).toHaveAttribute('data-code', reading.code);
    await expect(card.getByText(copy[`f_${reading.code}`], { exact: true })).toBeVisible();
    await expect(
      card.getByText(result.narrative.topics[topic].text, { exact: true }),
    ).toBeVisible();
  }
  await expect(page.getByTestId('fortune-topics')).not.toContainText(zh.f_money_steady);
  await expect(page.getByRole('dialog')).toHaveCount(0);
}

test('language then mandatory birthday unlocks real free periods and persists without login', async ({
  page,
}, info) => {
  const errors: string[] = [];
  page.on('pageerror', (error) => errors.push(error.message));
  await page.goto('/');
  await page.getByRole('radio', { name: /简体中文/ }).check();
  await page.getByRole('button', { name: zh.confirmLanguage, exact: true }).click();
  await expect(page.getByTestId('birth-entry')).toBeVisible();
  await expect(page.getByRole('button', { name: zh.f_cta, exact: true })).toBeDisabled();
  await navigate(page, zh.w_home);
  await expect(page.getByTestId('fortune-focus')).toHaveCount(0);
  await chooseChineseDate(page, '1999-02-20');
  await page.getByRole('button', { name: /对方忽冷忽热，我还要继续吗/ }).click();
  const initial = page.waitForResponse(
    (response) =>
      response.url().endsWith('/api/fortune') &&
      response.request().postDataJSON().period === 'today',
  );
  await page.getByRole('button', { name: zh.j_todayLater, exact: true }).click();
  const first = await initial;
  expect(first.ok()).toBe(true);
  const baseline: Fortune = await first.json();
  expect(baseline.birth).toMatchObject({
    date: '1999-02-20',
    time_known: false,
    zone_known: false,
  });
  expect(baseline.limits.natal_houses_used).toBe(false);
  expect(await page.evaluate(() => localStorage.getItem('sabai.session'))).toBeNull();
  await expectReadings(page, baseline);
  await expect(page.getByTestId('fortune-focus')).not.toContainText('对方忽冷忽热，我还要继续吗？');
  await expect(page.getByTestId('fortune-focus')).toContainText(zh.f_basisSun);
  for (const period of ['week', 'month'] as const) {
    const pending = page.waitForResponse(
      (response) =>
        response.url().endsWith('/api/fortune') &&
        response.request().postDataJSON().period === period,
    );
    await page.getByRole('button', { name: zh[`w_${period}`], exact: true }).click();
    const response = await pending;
    expect(response.ok()).toBe(true);
    const result: Fortune = await response.json();
    expect(result.period).toBe(period);
    expect(result.birth.reference_signs).toEqual(baseline.birth.reference_signs);
    expect(result.sampling.count).toBe(period === 'week' ? 7 : Number(result.period_end.slice(-2)));
    await expect(page.getByTestId('fortune-focus')).toContainText(zh[`n_motto_${period}`]);
    await expectReadings(page, result);
  }
  await page.getByTestId('fortune-basis').locator('summary').first().click();
  await expect(page.getByTestId('fortune-basis')).toContainText(zh.f_samplingDays);
  await expect(page.getByRole('button', { name: '本年运势', exact: true })).toHaveCount(0);
  await expect(page.getByTestId('fortune-basis')).toContainText(zh.f_basisSun);
  expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBe(true);
  await page.screenshot({
    path: `test-results/free-fortune-${info.project.name}.png`,
    fullPage: true,
  });
  await page.reload();
  await expect(page.getByTestId('birth-entry')).toHaveCount(0);
  await expect(page.getByTestId('fortune-focus')).toBeVisible();
  await navigate(page, zh.w_mine);
  await page.getByRole('button', { name: zh.languageLabel, exact: true }).click();
  await page.getByRole('radio', { name: /English \(US\)/ }).check();
  await page.getByRole('button', { name: en.confirmLanguage, exact: true }).click();
  await expect(page.locator('main')).toContainText('1999-02-20');
  const english = page.waitForResponse(
    (response) =>
      response.url().endsWith('/api/fortune') &&
      response.request().postDataJSON().profile.language === 'en',
  );
  await navigate(page, en.w_home);
  await expect(page.getByTestId('fortune-focus')).toContainText(en.n_motto_month);
  await expectReadings(page, await (await english).json(), en);
  expect(
    await page.evaluate(() => JSON.parse(localStorage.getItem('wanjai.birth')!).birth_date),
  ).toBe('1999-02-20');
  await page.getByRole('button', { name: en.f_chatReading, exact: true }).click();
  await expect(page.getByLabel(en.j_askPlaceholder, { exact: true })).toHaveValue(
    new RegExp(en.w_month),
  );
  await expect(page.getByLabel(en.j_askPlaceholder, { exact: true })).toHaveValue(
    new RegExp(en.f_chatReading),
  );
  expect(errors).toEqual([]);
});

test('optional wheels, birthday changes and explicit account binding use the saved birth data', async ({
  page,
}, info) => {
  await page.addInitScript(() => {
    localStorage.setItem('sabai.language', 'zh');
    localStorage.setItem('sabai.languageConfirmed', '1');
  });
  await page.goto('/');
  await chooseChineseDate(page, '1999-02-20');
  await page.getByText(zh.f_optional, { exact: true }).click();
  await page.getByRole('button', { name: zh.birthTime, exact: true }).click();
  let dialog = page.getByRole('dialog');
  await dialog.getByRole('option', { name: zh.pm, exact: true }).click();
  await selectWheel(dialog.getByRole('listbox', { name: zh.birthHour, exact: true }), '07');
  await selectWheel(dialog.getByRole('listbox', { name: zh.birthMinute, exact: true }), '15');
  await dialog.getByRole('button', { name: zh.pickerDone, exact: true }).click();
  await page.getByRole('button', { name: zh.birthplace, exact: true }).click();
  dialog = page.getByRole('dialog');
  await dialog.getByRole('button', { name: zh.pickerDone, exact: true }).click();
  const pending = page.waitForResponse((response) => response.url().endsWith('/api/fortune'));
  await page.getByRole('button', { name: zh.f_cta, exact: true }).click();
  const first = await (await pending).json();
  expect(first.birth.basis).toBe('ascendant');
  await expectReadings(page, first);
  await expect(page.getByTestId('fortune-focus')).toContainText(zh.f_basisAsc);
  await navigate(page, zh.w_chart);
  await expect(page.getByRole('img', { name: zh.th_natal, exact: true })).toBeVisible();
  const originalMarkers = await page
    .getByTestId('thai-orbit-wheel')
    .locator('[data-planet]')
    .evaluateAll((elements) => elements.map((element) => element.getAttribute('data-longitude')));
  const transit = page.waitForResponse((response) =>
    response.url().endsWith('/api/thai-transits/preview'),
  );
  await page.getByRole('button', { name: zh.th_transits, exact: true }).click();
  expect((await (await transit).json()).status).toBe('ready');
  await navigate(page, zh.w_mine);
  await page.getByRole('button', { name: zh.edit, exact: true }).click();
  await chooseChineseDate(page, '1995-08-17');
  const changed = page.waitForResponse(
    (response) =>
      response.url().endsWith('/api/fortune') &&
      response.request().postDataJSON().profile.birth_date === '1995-08-17',
  );
  await page.getByRole('button', { name: zh.f_cta, exact: true }).click();
  const second = await (await changed).json();
  expect(second.birth.date).toBe('1995-08-17');
  expect(second.birth.reference_signs).not.toEqual(first.birth.reference_signs);
  await expectReadings(page, second);
  await navigate(page, zh.w_chart);
  await expect(page.getByRole('img', { name: zh.th_natal, exact: true })).toBeVisible();
  const changedMarkers = await page
    .getByTestId('thai-orbit-wheel')
    .locator('[data-planet]')
    .evaluateAll((elements) => elements.map((element) => element.getAttribute('data-longitude')));
  expect(changedMarkers).not.toEqual(originalMarkers);
  await register(page, `free_${info.project.name[0]}_${Date.now()}`);
  await expect(page.getByRole('button', { name: zh.birthDate, exact: true })).toContainText(
    '1995年8月17日',
  );
  const saved = page.waitForResponse(
    (response) => response.url().endsWith('/api/profile') && response.request().method() === 'PUT',
  );
  await page.getByRole('button', { name: zh.onboardingSave, exact: true }).click();
  expect((await (await saved).json()).profile).toMatchObject({
    birth_date: '1995-08-17',
    birth_time: '19:15',
    birthplace: 'Bangkok, Thailand',
  });
  await page.getByRole('button', { name: zh.logout, exact: true }).click();
  await expect(page.getByTestId('fortune-focus')).toBeVisible();
  expect(
    await page.evaluate(() => JSON.parse(localStorage.getItem('wanjai.birth')!).birth_date),
  ).toBe('1995-08-17');
});

test('period failures hide the previous reading and retry restores calculated results', async ({
  page,
}) => {
  await page.addInitScript(() => {
    localStorage.setItem('sabai.language', 'zh');
    localStorage.setItem('sabai.languageConfirmed', '1');
    localStorage.setItem(
      'wanjai.birth',
      JSON.stringify({
        birth_date: '1999-02-20',
        birth_time: null,
        birthplace: '',
        timezone: 'Asia/Bangkok',
        display_name: '',
        language: 'zh',
      }),
    );
  });
  await page.goto('/');
  await expect(page.getByTestId('fortune-focus')).toHaveAttribute('data-period', 'today');
  await page.route(
    '**/api/fortune',
    (route) => route.fulfill({ status: 503, json: { detail: '计算暂时不可用，请重试。' } }),
    { times: 1 },
  );
  await page.getByRole('button', { name: zh.w_week, exact: true }).click();
  await expect(page.getByRole('alert')).toContainText('计算暂时不可用，请重试。');
  await expect(page.getByTestId('fortune-focus')).toHaveCount(0);
  await expect(page.getByTestId('fortune-topics')).toHaveCount(0);
  const pending = page.waitForResponse((response) => response.url().endsWith('/api/fortune'));
  await page.getByRole('button', { name: zh.retry, exact: true }).click();
  const result: Fortune = await (await pending).json();
  expect(result.period).toBe('week');
  await expectReadings(page, result);

  let release!: () => void;
  let notifyReady!: () => void;
  let notifyFinished!: () => void;
  const held = new Promise<void>((resolve) => {
    release = resolve;
  });
  const ready = new Promise<void>((resolve) => {
    notifyReady = resolve;
  });
  const finished = new Promise<void>((resolve) => {
    notifyFinished = resolve;
  });
  await page.route('**/api/fortune', async (route) => {
    if (route.request().postDataJSON().period !== 'today') return route.continue();
    const response = await route.fetch();
    notifyReady();
    await held;
    try {
      await route.fulfill({ response });
    } finally {
      notifyFinished();
    }
  });
  await page.getByRole('button', { name: zh.w_today, exact: true }).click();
  await ready;
  await expect(page.getByRole('status')).toContainText(zh.w_today);
  await expect(page.getByTestId('fortune-focus')).toHaveCount(0);
  const monthly = page.waitForResponse(
    (response) =>
      response.url().endsWith('/api/fortune') &&
      response.request().postDataJSON().period === 'month',
  );
  await page.getByRole('button', { name: zh.w_month, exact: true }).click();
  const month: Fortune = await (await monthly).json();
  await expectReadings(page, month);
  release();
  await finished;
  await expect(page.getByTestId('fortune-focus')).toHaveAttribute('data-period', 'month');
  await expect(page.getByRole('button', { name: zh.w_month, exact: true })).toHaveAttribute(
    'aria-pressed',
    'true',
  );
});
