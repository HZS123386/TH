import { expect, test } from '@playwright/test';
import { selectWheel } from './pickers';

test('scrolling birth pickers, linked city timezone, cancel and account persistence', async ({
  page,
  context,
}, testInfo) => {
  const errors: string[] = [];
  page.on('pageerror', (error) => errors.push(error.message));
  await page.addInitScript(() => {
    localStorage.setItem('sabai.language', 'zh');
    localStorage.setItem('sabai.languageConfirmed', '1');
  });
  await page.goto('/');
  await page.getByRole('button', { name: '登录', exact: true }).click();
  await page.getByRole('button', { name: '第一次来？创建账号' }).click();
  await page
    .getByLabel('账号', { exact: true })
    .fill(`wheel_${testInfo.project.name[0]}_${Date.now()}`);
  await page.getByLabel('密码', { exact: true }).fill('Sabai_test_2026');
  await page.getByLabel('确认密码', { exact: true }).fill('Sabai_test_2026');
  await page.getByRole('button', { name: '创建账号', exact: true }).click();
  await page.getByLabel('怎么称呼你').fill('Dao');
  await page.getByRole('button', { name: '出生日期', exact: true }).click();
  let dialog = page.getByRole('dialog');
  const year = dialog.getByRole('listbox', { name: '年', exact: true });
  const box = (await year.boundingBox())!;
  const x = box.x + box.width / 2,
    y = box.y + box.height / 2;
  if (testInfo.project.name === 'mobile') {
    const touch = await context.newCDPSession(page);
    await touch.send('Input.dispatchTouchEvent', { type: 'touchStart', touchPoints: [{ x, y }] });
    for (let i = 1; i <= 10; i++) {
      await touch.send('Input.dispatchTouchEvent', {
        type: 'touchMove',
        touchPoints: [{ x, y: y + i * 5 }],
      });
      await page.waitForTimeout(30);
    }
    await touch.send('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [] });
    await touch.detach();
  } else {
    await page.mouse.move(x, y);
    await page.mouse.wheel(0, -60);
  }
  await expect(year.getByRole('option', { selected: true })).not.toHaveText('2000');
  await selectWheel(year, '1999');
  const month = dialog.getByRole('listbox', { name: '月', exact: true });
  const monthBox = (await month.boundingBox())!;
  await page.mouse.move(monthBox.x + monthBox.width / 2, monthBox.y + 110);
  await page.mouse.down();
  await page.mouse.move(monthBox.x + monthBox.width / 2, monthBox.y + 66, { steps: 8 });
  await page.mouse.up();
  await expect(month.getByRole('option', { selected: true })).toHaveText('2月');
  await selectWheel(dialog.getByRole('listbox', { name: '日', exact: true }), '20');
  await page.screenshot({
    path: `test-results/${testInfo.project.name}-birth-date-wheel.png`,
    animations: 'disabled',
  });
  await dialog.getByRole('button', { name: '完成', exact: true }).click();
  await expect(page.getByRole('button', { name: '出生日期', exact: true })).toHaveText(
    '1999年2月20日',
  );

  await page.getByRole('button', { name: '出生时间', exact: true }).click();
  dialog = page.getByRole('dialog');
  await dialog.getByRole('option', { name: '下午（PM）', exact: true }).click();
  await selectWheel(dialog.getByRole('listbox', { name: '几点', exact: true }), '07');
  await selectWheel(dialog.getByRole('listbox', { name: '几分', exact: true }), '15');
  await page.screenshot({
    path: `test-results/${testInfo.project.name}-birth-time-wheel.png`,
    animations: 'disabled',
  });
  await dialog.getByRole('button', { name: '完成', exact: true }).click();
  await expect(page.getByRole('button', { name: '出生时间', exact: true })).toHaveText(
    '下午（PM） 7:15',
  );

  await page.getByRole('button', { name: '出生城市', exact: true }).click();
  dialog = page.getByRole('dialog');
  await dialog.getByRole('option', { name: '中国', exact: true }).click();
  await selectWheel(dialog.getByRole('listbox', { name: '出生城市', exact: true }), '上海');
  await page.screenshot({
    path: `test-results/${testInfo.project.name}-birth-city-wheel.png`,
    animations: 'disabled',
  });
  await dialog.getByRole('button', { name: '完成', exact: true }).click();
  await expect(page.getByRole('button', { name: '出生城市', exact: true })).toHaveText(
    '中国 · 上海',
  );
  await expect(page.getByRole('button', { name: '出生地时区', exact: true })).toHaveText(
    'Asia/Shanghai',
  );

  await page.getByRole('button', { name: '出生地时区', exact: true }).click();
  dialog = page.getByRole('dialog');
  await dialog.getByRole('textbox').fill('America/Los Angeles');
  await expect(dialog.getByRole('option', { selected: true })).toHaveText('America/Los_Angeles');
  await page.keyboard.press('Escape');
  await expect(page.getByRole('button', { name: '出生地时区', exact: true })).toHaveText(
    'Asia/Shanghai',
  );
  await expect(page.getByRole('button', { name: '出生地时区', exact: true })).toBeFocused();
  expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBe(true);

  const saved = page.waitForResponse(
    (response) => response.url().endsWith('/api/profile') && response.request().method() === 'PUT',
  );
  await page.getByRole('button', { name: '保存生辰，进入我的空间' }).click();
  expect((await (await saved).json()).profile).toMatchObject({
    birth_date: '1999-02-20',
    birth_time: '19:15',
    birthplace: 'Shanghai, China',
    timezone: 'Asia/Shanghai',
  });
  await expect(page.getByRole('heading', { name: '今天，也给自己一点期待。' })).toBeVisible();
  await page.reload();
  await page.getByRole('navigation').getByRole('button', { name: '我的', exact: true }).click();
  await page.getByRole('button', { name: '编辑档案', exact: true }).click();
  await expect(page.getByRole('button', { name: '出生日期', exact: true })).toHaveText(
    '1999年2月20日',
  );
  await expect(page.getByRole('button', { name: '出生时间', exact: true })).toHaveText(
    '下午（PM） 7:15',
  );
  await expect(page.getByRole('button', { name: '出生城市', exact: true })).toHaveText(
    '中国 · 上海',
  );
  expect(errors).toEqual([]);
});
