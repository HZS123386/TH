import { expect, test } from '@playwright/test';
import { chooseChineseDate, loginAccount, navigate, register, openChatOptions } from './pickers';
import zh from '../src/locales/zh-CN.json' with { type: 'json' };

test.beforeEach(async ({ page }) => {
  await page.addInitScript(() => {
    localStorage.setItem('sabai.language', 'zh');
    localStorage.setItem('sabai.languageConfirmed', '1');
  });
  await page.goto('/');
});

test('account birth profile, memory, two chat turns, reload and clear', async ({ page }, info) => {
  const username = `flow_${info.project.name[0]}_${Date.now()}`;
  await register(page, username);
  await page.getByRole('button', { name: '填入示例资料' }).click();
  await page.getByRole('button', { name: '出生时间', exact: true }).click();
  await page.getByRole('option', { name: '下午（PM）', exact: true }).click();
  await page.getByRole('dialog').getByRole('button', { name: '完成', exact: true }).click();
  await page.getByRole('button', { name: '保存生辰，进入我的空间' }).click();
  await expect(page.getByRole('heading', { name: '今天，也给自己一点期待。' })).toBeVisible();
  await page.getByRole('button', { name: '退出登录' }).click();
  await loginAccount(page, username);
  await navigate(page, '我的星盘');
  await page.getByText('八字工具', { exact: true }).click();
  await expect(page.getByText('21:30', { exact: true })).toBeVisible();
  await navigate(page, '我的记忆');
  await page.getByRole('textbox').fill('我喜欢简短的回答，也喜欢清迈。');
  await page.getByRole('button', { name: '确认并记住' }).click();
  await expect(page.getByText('我喜欢简短的回答，也喜欢清迈。', { exact: true })).toBeVisible();
  await navigate(page, '聊聊');
  await page.locator('#chat-input').fill('谈谈我的工作');
  await page.getByRole('button', { name: '发送', exact: true }).click();
  await expect(page.getByRole('button', { name: '停止生成' })).not.toBeVisible({ timeout: 15000 });
  await expect(page.getByRole('log')).toContainText('我喜欢简短的回答，也喜欢清迈。');
  await page.locator('#chat-input').fill('接着聊一聊');
  await page.getByRole('button', { name: '发送', exact: true }).click();
  await expect(page.getByRole('log')).toContainText('上一轮你问过「谈谈我的工作」', {
    timeout: 15000,
  });
  await expect(page.getByRole('button', { name: '停止生成' })).not.toBeVisible({ timeout: 15000 });
  await openChatOptions(page);
  await page
    .getByRole('dialog')
    .getByRole('button', { name: new RegExp(zh.j_viewHistory) })
    .click();
  await page.getByRole('dialog').getByRole('button', { name: '谈谈我的工作', exact: true }).click();
  await expect(page.getByRole('dialog')).toHaveCount(0);
  await expect(page.getByRole('log').getByText('谈谈我的工作', { exact: true })).toBeInViewport();
  await page.locator('#chat-input').fill('这是一份尚未发送的草稿');
  await navigate(page, '我的');
  await navigate(page, '聊聊');
  await expect(page.locator('#chat-input')).toHaveValue('这是一份尚未发送的草稿');
  await page.reload();
  await navigate(page, '聊聊');
  await expect(page.getByRole('log')).toContainText('接着聊一聊');
  await expect(page.locator('#chat-input')).toHaveValue('这是一份尚未发送的草稿');
  await openChatOptions(page);
  page.once('dialog', (dialog) => dialog.accept());
  await page.getByRole('button', { name: '清空对话', exact: true }).click();
  await expect(page.getByRole('heading', { name: '此刻，你想聊些什么？' })).toBeVisible();
  await navigate(page, '我的记忆');
  await page.getByRole('button', { name: '删除记忆' }).click();
  await expect(page.getByText('这里还没有记忆')).toBeVisible();
});

test('guest Thai chart asks for birth details without a fabricated chart', async ({ page }) => {
  await expect(
    page.getByRole('button', { name: '免费查看我的今日运势', exact: true }),
  ).toBeDisabled();
  await chooseChineseDate(page, '1999-02-20');
  await page.getByRole('button', { name: '免费查看我的今日运势', exact: true }).click();
  await navigate(page, '我的星盘');
  await expect(page.getByRole('heading', { name: '我的泰式命盘', exact: true })).toBeVisible();
  await expect(
    page.getByText(
      '出生时间未知：仅展示出生公历星期及可确定的泰历日期；不推测上升、宫位、行星位置或ทักษา。',
      { exact: true },
    ),
  ).toBeVisible();
  await expect(page.getByRole('img', { name: 'ราศี 本命', exact: true })).toHaveCount(0);
  await expect(page.getByRole('img', { name: zh.th_chartLayout, exact: true })).toBeVisible();
  await page.getByText('计算口径与来源', { exact: true }).click();
  await expect(page.getByRole('link', { name: '引擎接入与验证记录 ↗' })).toBeVisible();
});

test('unknown birth time stays bound after a new login', async ({ page }, info) => {
  const username = `unknown_${info.project.name[0]}_${Date.now()}`;
  await register(page, username);
  await chooseChineseDate(page, '1998-02-14');
  await page.getByLabel('不记得确切时间').check();
  await expect(page.getByRole('button', { name: '出生时间', exact: true })).toBeDisabled();
  await page.getByRole('button', { name: '保存生辰，进入我的空间' }).click();
  await page.getByRole('button', { name: '退出登录' }).click();
  await loginAccount(page, username);
  await navigate(page, '我的');
  await page.getByRole('button', { name: '编辑档案', exact: true }).click();
  await expect(page.getByRole('button', { name: '出生日期', exact: true })).toHaveText(
    '1998年2月14日',
  );
  await expect(page.getByLabel('不记得确切时间')).toBeChecked();
});
