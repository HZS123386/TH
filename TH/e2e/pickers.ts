import { expect, type Locator, type Page } from '@playwright/test';
import zh from '../src/locales/zh-CN.json' with { type: 'json' };
import en from '../src/locales/en-US.json' with { type: 'json' };
import th from '../src/locales/th.json' with { type: 'json' };
import vi from '../src/locales/vi.json' with { type: 'json' };

export async function navigate(page: Page, name: string) {
  const copy = [zh, en, th, vi];
  const home = copy.find((t) => t.w_home === name);
  if (home) {
    await page.getByRole('button', { name: home.homeLabel, exact: true }).click();
    return;
  }
  if (copy.some((t) => [t.w_chart, t.w_questions, t.w_shop, t.w_mine].includes(name))) {
    await page.getByRole('navigation').getByRole('button', { name, exact: true }).click();
    return;
  }
  const menu = page.getByRole('button', {
    name: /^(Open navigation|打开导航|เปิดเมนู|Mở điều hướng)$/,
    exact: true,
  });
  if ((await menu.getAttribute('aria-expanded')) !== 'true') await menu.click();
  await page.getByRole('complementary').getByRole('button', { name, exact: true }).click();
}

export async function openChatOptions(page: Page) {
  await page.getByRole('button', { name: zh.j_chatOptions, exact: true }).click();
  return page.getByRole('dialog');
}

export async function manageMemories(page: Page) {
  const dialog = await openChatOptions(page);
  await dialog.getByRole('button', { name: new RegExp('^' + zh.m_manage) }).click();
}

export async function register(page: Page, username: string) {
  await page.getByRole('button', { name: '登录', exact: true }).click();
  await page.getByRole('button', { name: '第一次来？创建账号', exact: true }).click();
  await page.getByLabel('账号', { exact: true }).fill(username);
  await page.getByLabel('密码', { exact: true }).fill('Sabai_test_2026');
  await page.getByLabel('确认密码', { exact: true }).fill('Sabai_test_2026');
  await page.getByRole('button', { name: '创建账号', exact: true }).click();
  await expect(
    page.getByRole('heading', { name: '先认识你的出生时刻', exact: true }),
  ).toBeVisible();
}

export async function loginAccount(page: Page, username: string) {
  await page.getByRole('button', { name: '登录', exact: true }).click();
  await page.getByLabel('账号', { exact: true }).fill(username);
  await page.getByLabel('密码', { exact: true }).fill('Sabai_test_2026');
  await page.getByRole('button', { name: '登录', exact: true }).last().click();
}

export async function selectWheel(column: Locator, label: string) {
  const labels = await column.getByRole('option').allTextContents();
  const index = labels.findIndex((item) => item.trim() === label);
  expect(index, `wheel option ${label}`).toBeGreaterThanOrEqual(0);
  await column.focus();
  await column.press('Home');
  for (let i = 0; i < Math.floor(index / 10); i++) await column.press('PageDown');
  for (let i = 0; i < index % 10; i++) await column.press('ArrowDown');
  await expect(column.getByRole('option', { selected: true })).toHaveText(label);
}

export async function chooseChineseDate(page: Page, date: string) {
  const [year, month, day] = date.split('-').map(Number);
  await page.getByRole('button', { name: '出生日期', exact: true }).click();
  const dialog = page.getByRole('dialog');
  await selectWheel(dialog.getByRole('listbox', { name: '年', exact: true }), String(year));
  await selectWheel(dialog.getByRole('listbox', { name: '月', exact: true }), `${month}月`);
  await selectWheel(dialog.getByRole('listbox', { name: '日', exact: true }), String(day));
  await dialog.getByRole('button', { name: '完成', exact: true }).click();
}
