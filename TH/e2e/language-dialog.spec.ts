import { expect, test } from '@playwright/test';
import zh from '../src/locales/zh-CN.json' with { type: 'json' };
import en from '../src/locales/en-US.json' with { type: 'json' };
import th from '../src/locales/th.json' with { type: 'json' };
import vi from '../src/locales/vi.json' with { type: 'json' };
import { navigate } from './pickers';
const translations = { zh, en, th, vi };

test('first visit shows the warm language dialog, requires confirmation and remembers the choice', async ({
  page,
}, info) => {
  await page.addInitScript(() => {
    if (!localStorage.getItem('sabai.language')) localStorage.setItem('sabai.language', 'zh');
  });
  await page.setViewportSize({ width: info.project.name === 'mobile' ? 360 : 1280, height: 568 });
  await page.goto('/');
  const dialog = page.getByRole('dialog');
  await expect(dialog).toBeVisible();
  await expect(dialog).toHaveCSS('background-color', 'rgb(255, 254, 250)');
  await expect(page.locator('meta[name="theme-color"]')).toHaveAttribute('content', '#faf8f4');
  await expect(dialog.getByRole('radio')).toHaveCount(4);
  await expect(dialog.getByRole('button', { name: translations.zh.back, exact: true })).toHaveCount(
    0,
  );
  await page.keyboard.press('Escape');
  await expect(dialog).toBeVisible();
  expect(await page.evaluate(() => localStorage.getItem('sabai.languageConfirmed'))).toBeNull();
  const confirm = dialog.getByRole('button', {
    name: translations.zh.confirmLanguage,
    exact: true,
  });
  const box = await confirm.boundingBox();
  expect(box!.y + box!.height).toBeLessThanOrEqual(568);
  await dialog.getByRole('radio', { name: /English \(US\)/ }).check();
  await expect(page.locator('html')).toHaveAttribute('lang', 'en-US');
  await expect
    .poll(
      async () => {
        const choice = await dialog.getByRole('radio', { name: /English \(US\)/ }).boundingBox();
        const button = await dialog
          .getByRole('button', { name: translations.en.confirmLanguage, exact: true })
          .boundingBox();
        return choice!.y + choice!.height <= button!.y;
      },
      { message: 'selected language remains above the fixed confirmation area' },
    )
    .toBe(true);
  await page.screenshot({
    path: `test-results/language-dialog-short-${info.project.name}.png`,
    fullPage: true,
    animations: 'disabled',
  });
  await dialog.getByRole('button', { name: translations.en.confirmLanguage, exact: true }).click();
  await expect(dialog).toHaveCount(0);
  await expect(page.locator('html')).toHaveAttribute('lang', 'en-US');
  await page.reload();
  await expect(page.getByRole('dialog')).toHaveCount(0);
  await expect(page.locator('html')).toHaveAttribute('lang', 'en-US');
  expect(await page.evaluate(() => document.body.style.overflow)).toBe('');
});

test('My can reopen the language dialog; Escape restores the saved language', async ({ page }) => {
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
  await expect(page.getByRole('dialog')).toHaveCount(0);
  await navigate(page, translations.zh.w_mine);
  await page.getByRole('button', { name: translations.zh.languageLabel, exact: true }).click();
  const dialog = page.getByRole('dialog');
  await expect(dialog).toBeVisible();
  await expect(
    dialog.getByRole('button', { name: translations.zh.back, exact: true }),
  ).toBeVisible();
  await dialog.getByRole('radio', { name: /English \(US\)/ }).check();
  await expect(page).toHaveTitle(translations.en.pageTitle);
  await page.keyboard.press('Escape');
  await expect(dialog).toHaveCount(0);
  await expect(page).toHaveTitle(translations.zh.pageTitle);
  expect(await page.evaluate(() => localStorage.getItem('sabai.language'))).toBe('zh');
  expect(await page.evaluate(() => document.body.style.overflow)).toBe('');
  await page.getByRole('button', { name: translations.zh.languageLabel, exact: true }).click();
  await page
    .getByRole('dialog')
    .getByRole('button', { name: translations.zh.back, exact: true })
    .click();
  await expect(page.getByRole('dialog')).toHaveCount(0);
});

test('language dialog fits all four options and confirmation without scrolling as the viewport changes', async ({
  page,
}, info) => {
  await page.goto('/');
  const dialog = page.getByRole('dialog');
  await expect(dialog).toBeVisible();
  const sizes = [
    { width: 1280, height: 900 },
    { width: 500, height: 700 },
    { width: 393, height: 667 },
    { width: 360, height: 568 },
    { width: 320, height: 480 },
    { width: 320, height: 501 },
    { width: 320, height: 641 },
    { width: 320, height: 701 },
    { width: 844, height: 390 },
    { width: 568, height: 320 },
    { width: 320, height: 320 },
  ];
  for (const size of sizes) {
    await page.setViewportSize(size);
    for (const [language, copy] of Object.entries(translations)) {
      await dialog.locator(`input[value="${language}"]`).check();
      await expect(
        dialog.getByRole('button', { name: copy.confirmLanguage, exact: true }),
      ).toBeVisible();
      await expect
        .poll(
          () =>
            dialog.evaluate((element) => {
              const panel = element.getBoundingClientRect();
              const controls = element.querySelectorAll<HTMLElement>('label,button[type="submit"]');
              return {
                noHorizontalOverflow: element.scrollWidth <= element.clientWidth + 1,
                noVerticalOverflow: element.scrollHeight <= element.clientHeight + 1,
                noInternalScroll: Array.from(element.querySelectorAll<HTMLElement>('*')).every(
                  (node) =>
                    !/(auto|scroll)/.test(
                      getComputedStyle(node).overflowY + getComputedStyle(node).overflowX,
                    ),
                ),
                fitsViewport:
                  panel.top >= 0 &&
                  panel.bottom <= innerHeight + 1 &&
                  panel.left >= 0 &&
                  panel.right <= innerWidth + 1,
                controlsVisible: Array.from(controls).every((control) => {
                  const box = control.getBoundingClientRect();
                  return (
                    box.top >= panel.top &&
                    box.bottom <= panel.bottom &&
                    box.left >= panel.left &&
                    box.right <= panel.right
                  );
                }),
              };
            }),
          {
            message: `${language} at ${size.width}×${size.height}: content fits without hiding overflow`,
          },
        )
        .toEqual({
          noHorizontalOverflow: true,
          noVerticalOverflow: true,
          noInternalScroll: true,
          fitsViewport: true,
          controlsVisible: true,
        });
    }
    if (size.width === 500 || size.width === 320 || size.width === 844)
      await page.screenshot({
        path: `test-results/language-fit-${info.project.name}-${size.width}x${size.height}.png`,
        animations: 'disabled',
      });
  }
  await page.addStyleTag({ content: ':root { font-size: 20px !important; }' });
  for (const size of [
    { width: 500, height: 700 },
    { width: 320, height: 480 },
    { width: 320, height: 641 },
    { width: 568, height: 320 },
    { width: 320, height: 320 },
  ]) {
    await page.setViewportSize(size);
    for (const [language, copy] of Object.entries(translations)) {
      await dialog.locator(`input[value="${language}"]`).check();
      await expect(
        dialog.getByRole('button', { name: copy.confirmLanguage, exact: true }),
      ).toBeVisible();
      await expect
        .poll(
          () =>
            dialog.evaluate(
              (node) =>
                node.scrollHeight <= node.clientHeight + 1 &&
                node.scrollWidth <= node.clientWidth + 1,
            ),
          { message: `large text fits at ${size.width}×${size.height}` },
        )
        .toBe(true);
    }
  }
});
