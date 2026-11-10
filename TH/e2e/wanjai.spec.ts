import { expect, test } from '@playwright/test';
import { loginAccount, navigate, register } from './pickers';
import zh from '../src/locales/zh-CN.json' with { type: 'json' };
import en from '../src/locales/en-US.json' with { type: 'json' };

async function editWish(page: import('@playwright/test').Page, text: string) {
  await page.getByRole('button', { name: zh.w_wish, exact: true }).click();
  await page.getByRole('dialog').getByLabel(zh.w_wish, { exact: true }).fill(text);
  await page.getByRole('dialog').getByRole('button', { name: zh.w_save, exact: true }).click();
}

test.beforeEach(async ({ page }) => {
  await page.addInitScript(() => {
    localStorage.setItem('sabai.language', 'zh');
    localStorage.setItem('sabai.languageConfirmed', '1');
    if (!localStorage.getItem('wanjai.birth'))
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
});

test('reference features: questions, plans, progress, reminders, keepsakes and language in My', async ({
  page,
}, info) => {
  const errors: string[] = [];
  page.on('pageerror', (e) => errors.push(e.message));
  await page.getByRole('button', { name: '本周运势', exact: true }).click();
  await expect(page.getByRole('button', { name: '本周运势', exact: true })).toHaveAttribute(
    'aria-pressed',
    'true',
  );
  await navigate(page, '聊聊');
  await page.getByRole('button', { name: zh.j_chooseTopic, exact: true }).click();
  await expect(
    page.locator('main').getByRole('button').filter({ hasText: '想换工作，又怕选错怎么办？' }),
  ).toBeVisible();
  await page.getByRole('button', { name: /想换工作，又怕选错怎么办？/ }).click();
  await page.getByRole('button', { name: /正在找工作，希望尽快有进展/ }).click();
  await page.locator('main').getByRole('button', { name: '免费试读', exact: true }).click();
  await expect(page.getByTestId('jy-plan-page')).toContainText('路径二');
  await page.getByRole('button', { name: /模拟解锁完整内容/ }).click();
  await expect(page.getByRole('dialog')).toContainText('本地演示，无真实支付、订单或收费。');
  await page.getByRole('dialog').getByRole('button', { name: '完成', exact: true }).click();
  await expect(page.getByRole('heading', { name: '可以直接改写的模板' })).toBeVisible();
  await page.locator('main').getByRole('button', { name: '七步陪伴', exact: true }).click();
  await page.getByRole('button', { name: '有点困难', exact: true }).click();
  await expect(page.getByText('今天已记录，明天再走一小步。')).toBeVisible();
  await expect(page.getByRole('button', { name: '有帮助', exact: true })).toBeDisabled();
  await page.screenshot({
    path: `test-results/wanjai-${info.project.name}-journey.png`,
    fullPage: true,
  });
  await navigate(page, '今日陪伴');
  await page.getByRole('button', { name: '有点累', exact: true }).click();
  await page.getByRole('button', { name: '陪伴偏好', exact: true }).click();
  await page.getByLabel('回访频率').selectOption('weekly');
  await page.getByLabel('偏好的时间（曼谷）').fill('20:00');
  await page.getByRole('dialog').getByRole('button', { name: '完成', exact: true }).click();
  await page.getByRole('button', { name: '提醒内容预览', exact: true }).click();
  await expect(page.getByRole('dialog')).toContainText('20:00');
  await expect(page.getByRole('dialog')).toContainText('不会发送提醒');
  await page.getByRole('dialog').getByRole('button', { name: '完成', exact: true }).click();
  await navigate(page, '随身好物');
  await expect(page.getByRole('article')).toHaveCount(6);
  await page.getByTestId('taste-panel').locator('summary').click();
  await page.getByLabel('价格上限').selectOption('300');
  await expect(page.getByRole('article')).toHaveCount(1);
  await page
    .getByRole('article')
    .getByRole('button', { name: /^收藏 / })
    .click();
  await navigate(page, '我的');
  await editWish(page, '每天一点，认真照顾自己。');
  await page.reload();
  await navigate(page, '我的');
  await expect(page.locator('blockquote')).toContainText('每天一点，认真照顾自己。');
  await expect(page.getByRole('button', { name: /我的收藏 · 1/ })).toBeVisible();
  await page.getByRole('button', { name: '切换语言', exact: true }).click();
  await page.getByRole('radio', { name: /English \(US\)/ }).check();
  await page.getByRole('button', { name: 'Confirm and continue', exact: true }).last().click();
  await expect(page.getByRole('heading', { name: en.j_mineTitle, exact: true })).toBeVisible();
  await page.getByRole('button', { name: 'A note for a friend', exact: true }).click();
  const download = page.waitForEvent('download');
  await page.getByRole('button', { name: 'Save the card', exact: true }).click();
  expect((await download).suggestedFilename()).toBe(`${en.brandName}-a-little-comfort.png`);
  expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBe(true);
  expect(errors).toEqual([]);
});

test('companion state follows the account across login and stays separate from another account', async ({
  page,
}, info) => {
  const name = `wanjai_${info.project.name[0]}_${Date.now()}`;
  await register(page, name);
  await page.getByRole('button', { name: '填入示例资料' }).click();
  await page.getByRole('button', { name: '保存生辰，进入我的空间' }).click();
  await navigate(page, '我的');
  await editWish(page, 'My private wish');
  await expect
    .poll(() =>
      page.evaluate(
        async () =>
          (
            await (
              await fetch('/api/companion', {
                headers: { Authorization: `Bearer ${localStorage.getItem('sabai.session')}` },
              })
            ).json()
          )?.wish,
      ),
    )
    .toBe('My private wish');
  await page.getByRole('button', { name: '退出登录' }).click();
  await loginAccount(page, name);
  await navigate(page, '我的');
  await expect(page.locator('blockquote')).toContainText('My private wish');
  await page.getByRole('button', { name: '退出登录' }).click();
  await register(page, `${name}_b`);
  await page.getByRole('button', { name: '填入示例资料' }).click();
  await page.getByRole('button', { name: '保存生辰，进入我的空间' }).click();
  await navigate(page, '我的');
  await page.getByRole('button', { name: zh.w_wish, exact: true }).click();
  await expect(page.getByRole('dialog').getByLabel(zh.w_wish, { exact: true })).toHaveValue('');
  await page
    .getByRole('dialog')
    .getByRole('button', { name: zh.pickerCancel, exact: true })
    .click();
  await expect(page.getByRole('button', { name: /我的收藏 · 0/ })).toBeVisible();
});
