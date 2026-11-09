import { expect, test } from '@playwright/test';
import { navigate, register, loginAccount, openChatOptions, manageMemories } from './pickers';
import zh from '../src/locales/zh-CN.json' with { type: 'json' };
import type { ChatEvidence, Message } from '../src/types';

for (const reviewed of [true, false]) {
  test(`collaborative assistant shows ${reviewed ? 'joint review' : 'single-model fallback'} and keeps it after refresh`, async ({
    page,
  }, info) => {
    // Model responses are synthetic in browser tests; no live credentials are used.
    let history: Message[] = [];
    await page.route('**/api/config', async (route) => {
      const response = await route.fetch();
      const config = await response.json();
      config.default_provider = 'companion';
      config.providers.find((item: { id: string }) => item.id === 'companion').enabled = true;
      config.companion.real_model_ready = true;
      await route.fulfill({ json: config });
    });
    await page.route('**/api/history', (route) => route.fulfill({ json: history }));
    await page.route('**/api/chat', async (route) => {
      const request = route.request().postDataJSON();
      expect(request.provider).toBe('companion');
      const evidence: ChatEvidence = {
        profile_revision: 1,
        system: 'thai-suriyayatra',
        calculated_at: new Date().toISOString(),
        natal_status: 'time-unknown',
        recall: { mode: 'recent', count: 0, confirmed_count: 0 },
        fortunes: [],
        generation: {
          mode: 'companion',
          reviewed,
          response_provider: reviewed ? 'kimi' : 'qwen',
          steps: [
            { provider: 'qwen', role: 'draft', status: 'completed' },
            { provider: 'kimi', role: 'refine', status: reviewed ? 'completed' : 'failed' },
          ],
        },
      };
      const reply = '先保住收入，今天只挑一份合适的岗位看看要求。';
      const created = Date.now() / 1000;
      history = [
        { id: 'test-user', role: 'user', content: request.message, provider: 'companion', created },
        {
          id: 'test-answer',
          role: 'assistant',
          content: reply,
          provider: 'companion',
          created,
          evidence,
        },
      ];
      const frames = [
        [
          'metadata',
          { provider: 'companion', model: 'synthetic-test', profile_revision: 1, evidence },
        ],
        ['token', { text: reply }],
        ['done', { message_id: 'test-answer', provider: 'companion' }],
      ];
      await route.fulfill({
        contentType: 'text/event-stream',
        body: frames
          .map(([event, data]) => `event: ${event}\ndata: ${JSON.stringify(data)}\n\n`)
          .join(''),
      });
    });
    await page.addInitScript(() => {
      localStorage.setItem('sabai.language', 'zh');
      localStorage.setItem('sabai.languageConfirmed', '1');
    });
    await page.goto('/');
    await register(page, `joint_${info.project.name[0]}_${reviewed ? 'r' : 'f'}_${Date.now()}`);
    await page.getByRole('button', { name: zh.sample, exact: true }).click();
    await page.getByRole('button', { name: zh.onboardingSave, exact: true }).click();
    await navigate(page, zh.w_questions);
    await openChatOptions(page);
    await expect(page.getByRole('combobox', { name: zh.providerLabel })).toHaveValue('companion');
    await page
      .getByRole('dialog')
      .getByRole('button', { name: zh.pickerDone, exact: true })
      .click();
    await page.locator('#chat-input').fill('我想换工作，但现在还不能辞职。');
    await page.getByRole('button', { name: zh.send, exact: true }).click();
    await expect(page.getByRole('log')).toContainText('今天只挑一份合适的岗位');
    const expected = reviewed
      ? zh.m_cooperativeReply
      : zh.m_singleReply.replace('{{model}}', 'Qwen');
    await page.getByTestId('chat-evidence').locator('summary').click();
    await expect(page.getByTestId('chat-model-workflow')).toHaveText(expected);
    await page.getByTestId('chat-model-workflow').scrollIntoViewIfNeeded();
    await expect(page.getByTestId('chat-model-workflow')).toBeVisible();
    expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBe(
      true,
    );
    await page.screenshot({
      path: `test-results/companion-workflow-${info.project.name}-${reviewed}.png`,
      fullPage: true,
    });
    await page.reload();
    await navigate(page, zh.w_questions);
    await page.getByTestId('chat-evidence').locator('summary').click();
    await expect(page.getByTestId('chat-model-workflow')).toHaveText(expected);
  });
}

test('Thai companion keeps account memory, supports explicit confirmation and editing, and exposes calculation evidence', async ({
  page,
}, info) => {
  const errors: string[] = [];
  page.on('pageerror', (error) => errors.push(error.message));
  await page.addInitScript(() => {
    localStorage.setItem('sabai.language', 'zh');
    localStorage.setItem('sabai.languageConfirmed', '1');
  });
  await page.goto('/');
  const username = `comp_${info.project.name[0]}_${Date.now()}`;
  await register(page, username);
  await page.getByRole('button', { name: zh.sample, exact: true }).click();
  await page.getByRole('button', { name: zh.onboardingSave, exact: true }).click();
  await navigate(page, zh.w_questions);
  await expect(page.getByRole('note')).toContainText(zh.m_modelMissing);
  await openChatOptions(page);
  await expect(page.getByRole('combobox', { name: zh.providerLabel })).toContainText('Kimi');
  await page.getByRole('dialog').getByRole('button', { name: zh.pickerDone, exact: true }).click();
  const sentence = '我正在准备转行，希望先保住收入，不要催我立刻辞职。';
  await page.locator('#chat-input').fill(sentence);
  await page.getByRole('button', { name: zh.send, exact: true }).click();
  await expect(page.getByRole('button', { name: zh.stop, exact: true })).not.toBeVisible({
    timeout: 15000,
  });
  await page.getByTestId('chat-evidence').locator('summary').click();
  await expect(page.getByTestId('chat-evidence')).toContainText(zh.w_today);
  await expect(page.getByTestId('chat-evidence')).toContainText(zh.f_basisAsc);
  await page.getByRole('button', { name: zh.m_remember, exact: true }).click();
  const dialog = page.getByRole('dialog');
  await expect(dialog.getByRole('textbox')).toHaveValue(sentence);
  await dialog.getByRole('textbox').fill('正在准备转行，优先保住收入。');
  await dialog.getByRole('button', { name: zh.remember, exact: true }).click();
  await expect(dialog).toHaveCount(0);
  await manageMemories(page);
  await expect(page.locator('main')).toContainText('正在准备转行，优先保住收入。');
  await page.getByRole('button', { name: zh.m_edit, exact: true }).click();
  await page.getByRole('dialog').getByRole('textbox').fill('先找到合适的录用机会，再决定离职。');
  await page.getByRole('dialog').getByRole('button', { name: zh.w_save, exact: true }).click();
  await expect(page.getByRole('dialog')).toHaveCount(0);
  await page.getByRole('button', { name: zh.logout, exact: true }).click();
  await loginAccount(page, username);
  await navigate(page, zh.w_questions);
  await page.locator('#chat-input').fill('我们之前聊过的事情，这周该怎么继续？');
  await page.getByRole('button', { name: zh.send, exact: true }).click();
  await expect(page.getByRole('log')).toContainText('先找到合适的录用机会，再决定离职。', {
    timeout: 15000,
  });
  await expect(page.getByRole('button', { name: zh.stop, exact: true })).not.toBeVisible({
    timeout: 15000,
  });
  await page.getByTestId('chat-evidence').last().locator('summary').click();
  await expect(page.getByTestId('chat-evidence').last()).toContainText(zh.w_week);
  await expect(page.getByTestId('chat-evidence').last()).toContainText(
    '已确认记忆 1 条 · 回顾对话 1 条',
  );
  expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBe(true);
  await page.screenshot({
    path: `test-results/companion-chat-${info.project.name}.png`,
    fullPage: true,
  });
  await manageMemories(page);
  await page.getByRole('button', { name: zh.delete, exact: true }).click();
  await expect(page.locator('main')).toContainText(zh.memoryEmpty);
  await page.getByRole('button', { name: zh.logout, exact: true }).click();
  await register(page, `${username}_b`);
  await page.getByRole('button', { name: zh.sample, exact: true }).click();
  await page.getByRole('button', { name: zh.onboardingSave, exact: true }).click();
  await navigate(page, zh.w_questions);
  await expect(page.getByRole('log')).not.toContainText(sentence);
  await expect(page.getByTestId('chat-evidence')).toHaveCount(0);
  expect(errors).toEqual([]);
});
