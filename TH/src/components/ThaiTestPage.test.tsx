import { act, cleanup, fireEvent, render, screen } from '@testing-library/react';
import { afterEach, beforeEach, expect, test, vi } from 'vitest';
import { ThaiTestPage } from './ThaiTestPage';
import { translations } from '../lib/i18n';
import { api } from '../lib/api';
import {
  thaiReadingCopy,
  thaiReportHtml,
  thaiPeriodLabel,
  type ThaiReadingResult,
} from '../lib/thaiReading';
import type { Language, Profile } from '../types';
import type { WanjaiBottomAction } from './WanjaiShell';

vi.mock('../lib/api', () => ({ api: vi.fn() }));
const profile: Profile = {
  display_name: '',
  birth_date: '1995-08-17',
  birth_time: '09:30',
  timezone: 'Asia/Bangkok',
  birthplace: 'Bangkok, Thailand',
  language: 'zh',
};
const fixture = (language: Language = 'zh'): ThaiReadingResult => ({
  report_id: 'synthetic-test',
  generated_at: '2026-11-07T12:00:00+07:00',
  input: { profile: { ...profile, language }, reading: 'work', year: 2026 },
  natal: {
    status: 'ready',
    chart: null,
    profile_revision: 0,
    engine: {} as never,
    calendar: {} as never,
    taksa: null,
    location: null,
    time_known: true,
    required: [],
  },
  report: {
    title: thaiReadingCopy(language).readings.work.title,
    summary: '先明确工作分工，再决定是否接受额外任务。',
    language,
    generation: { state: 'ready', version: 'test' },
    sections: [
      {
        id: 'opportunities',
        title: thaiReadingCopy(language).sections.opportunities,
        items: [
          {
            title: '留意临时增加的负担',
            text: '提醒内容也只在解锁之后完整展示。',
            period: null,
            signals: [
              '手头的事情还没有做完，又接到了额外请求。',
              '答应以后才发现自己没有足够时间完成。',
            ],
            response: '先看清楚当前的安排，再和对方重新确认先后顺序。',
            example: '如果同事请你加班，可以先确认目前最需要完成的任务。',
          },
        ],
      },
      {
        id: 'advice',
        title: thaiReadingCopy(language).sections.advice,
        items: [
          {
            title: '先把分工说清楚',
            text: '<synthetic> & "report"',
            period: null,
            steps: [
              '先把手头需要完成的事情写下来。',
              '再与对方确认各自负责的内容。',
              '最后一起检查有没有遗漏的事情。',
              '把检查结果记下来，下次合作前一起参考。',
            ],
            example: '可以这样说：我来整理，你来核对，做好后再一起检查。',
            pitfall: '不要还没看清任务就承诺完成时间，先确认自己能承担多少。',
            check: '完成后看看有没有重复修改，和对方确认分工是否清楚。',
          },
        ],
      },
    ],
  },
});
const mount = (
  language: Language = 'zh',
  value: Profile | null = profile,
  onBottomActionChange = vi.fn<(action: WanjaiBottomAction | undefined) => void>(),
) =>
  render(
    <ThaiTestPage
      profile={value}
      language={language}
      t={translations[language]}
      onBack={vi.fn()}
      onBottomActionChange={onBottomActionChange}
    />,
  );
beforeEach(() => vi.clearAllMocks());
afterEach(cleanup);

test('submits the chosen Thai subject and real birthplace without Bazi or Roxy options', async () => {
  vi.mocked(api).mockResolvedValue(fixture());
  const bottom = vi.fn<(action: WanjaiBottomAction | undefined) => void>();
  mount('zh', profile, bottom);
  fireEvent.click(screen.getByRole('radio', { name: '事业解读' }));
  fireEvent.click(screen.getByRole('button', { name: '生成星盘与解读报告' }));
  await screen.findByTestId('thai-report');
  const [path, init] = vi.mocked(api).mock.calls[0];
  expect(path).toBe('/api/thai-reading');
  expect(JSON.parse(String(init!.body))).toMatchObject({ reading: 'work', profile });
  expect(JSON.parse(String(init!.body))).not.toHaveProperty('source');
  expect(screen.getByTestId('thai-test-page')).not.toHaveTextContent('八字');
  expect(screen.queryByText('查看计算依据')).not.toBeInTheDocument();
  expect(screen.queryByText('查看 Roxy 原始返回')).not.toBeInTheDocument();
  expect(screen.getByText('<synthetic> & "report"')).toBeInTheDocument();
  expect(screen.getByTestId('thai-report-summary')).toHaveTextContent('先明确工作分工');
  expect(screen.getByTestId('thai-locked-content')).toHaveAttribute('data-locked', 'true');
  expect(screen.getByTestId('thai-locked-content')).toHaveAttribute('aria-hidden', 'true');
  expect(screen.getByRole('heading', { name: '需要留意的地方' })).toBeVisible();
  expect(screen.queryByRole('heading', { name: '你可以这样做' })).not.toBeInTheDocument();
  expect(screen.getByTestId('thai-lock-badge')).toBeVisible();
  expect(screen.queryByRole('heading', { name: '留意临时增加的负担' })).not.toBeInTheDocument();
  expect(screen.queryByRole('heading', { name: '先把分工说清楚' })).not.toBeInTheDocument();
  expect(bottom.mock.calls.at(-1)![0]!.label).toBe('查看全部内容，请解锁');
  act(() => bottom.mock.calls.at(-1)![0]!.onClick());
  expect(screen.getByRole('heading', { name: '先把分工说清楚' })).toBeInTheDocument();
  expect(screen.getByTestId('thai-locked-content')).toHaveAttribute('data-locked', 'false');
  expect(screen.queryByTestId('thai-lock-badge')).not.toBeInTheDocument();
  expect(screen.getByRole('heading', { name: '留意临时增加的负担' })).toBeVisible();
  expect(screen.getByText('最后一起检查有没有遗漏的事情。')).toBeVisible();
  expect(bottom.mock.calls.at(-1)![0]).toBeUndefined();
  expect(api).toHaveBeenCalledTimes(1);
  fireEvent.click(screen.getByRole('radio', { name: '财富解读' }));
  expect(screen.queryByTestId('thai-report')).not.toBeInTheDocument();
});

test('changing subjects cancels and discards a delayed old result', async () => {
  let resolve: (value: ThaiReadingResult) => void = () => {};
  vi.mocked(api).mockImplementation(
    () =>
      new Promise((done) => {
        resolve = done as typeof resolve;
      }),
  );
  mount();
  fireEvent.click(screen.getByRole('button', { name: '生成星盘与解读报告' }));
  const signal = vi.mocked(api).mock.calls[0][1]!.signal!;
  fireEvent.click(screen.getByRole('radio', { name: '感情解读' }));
  expect(signal.aborted).toBe(true);
  await act(async () => resolve(fixture()));
  expect(screen.queryByTestId('thai-report')).not.toBeInTheDocument();
  expect(screen.getByRole('button', { name: '生成星盘与解读报告' })).toBeEnabled();
});

test('requires exact birth time and location before allowing a personal reading', () => {
  mount('zh', { ...profile, birth_time: null });
  expect(screen.getByRole('button', { name: '生成星盘与解读报告' })).toBeDisabled();
  cleanup();
  mount('zh', { ...profile, birthplace: '' });
  expect(screen.getByRole('button', { name: '生成星盘与解读报告' })).toBeDisabled();
  expect(api).not.toHaveBeenCalled();
});

test('only the annual subject submits a selected year and hides old reports on language changes', async () => {
  vi.mocked(api).mockResolvedValue(fixture());
  const view = mount();
  fireEvent.click(screen.getByRole('radio', { name: '全年运势' }));
  fireEvent.change(screen.getByLabelText('要查看的年份'), { target: { value: '2027' } });
  fireEvent.click(screen.getByRole('button', { name: '生成星盘与解读报告' }));
  await screen.findByTestId('thai-report');
  expect(JSON.parse(String(vi.mocked(api).mock.calls[0][1]!.body))).toMatchObject({
    reading: 'annual',
    year: 2027,
  });
  view.rerender(
    <ThaiTestPage profile={profile} language="th" t={translations.th} onBack={vi.fn()} />,
  );
  expect(screen.queryByTestId('thai-report')).not.toBeInTheDocument();
  expect(screen.getByRole('button', { name: thaiReadingCopy('th').generate })).toBeInTheDocument();
});

test.each(['zh', 'en', 'th', 'vi'] as const)(
  'localizes all six themes and escaped report downloads in %s',
  (language) => {
    mount(language);
    const b = thaiReadingCopy(language);
    for (const item of Object.values(b.readings))
      expect(screen.getByRole('radio', { name: item.title })).toBeEnabled();
    const result = fixture(language);
    result.input.reading = 'annual';
    result.input.year = 2027;
    const html = thaiReportHtml(result, true);
    expect(html).toContain(`lang="${language}"`);
    expect(html).toContain(b.sections.advice);
    expect(html).toContain(b.summary);
    expect(html).toContain('&lt;synthetic&gt; &amp; &quot;report&quot;');
    expect(html).not.toContain('<synthetic>');
    expect(html).not.toContain('calculation_input');
    expect(html).toContain('2027');
    expect(html).not.toContain(b.planets.ascendant);
  },
);

test('shows simple verified months and numbered actions without any chart terminology', async () => {
  const result = fixture();
  result.input.reading = 'annual';
  result.input.year = 2027;
  result.report.sections[0].items[0].period = { year: 2027, month: 4 };
  result.natal.chart = {
    points: { ascendant: { sign: 2 }, sun: { sign: 3 }, moon: { sign: 4 } },
  } as never;
  vi.mocked(api).mockResolvedValue(result);
  mount();
  fireEvent.click(screen.getByRole('radio', { name: '全年运势' }));
  fireEvent.click(screen.getByRole('button', { name: '生成星盘与解读报告' }));
  const report = await screen.findByTestId('thai-report');
  expect(report).toHaveTextContent('2027年4月');
  expect(screen.queryByTestId('thai-result-ascendant')).not.toBeInTheDocument();
  expect(screen.getByTestId('thai-results')).not.toHaveTextContent('宫主');
  expect(screen.getByTestId('thai-results')).not.toHaveTextContent('上升');
  expect(thaiReportHtml(result, true)).toContain('2027年4月');
  expect(thaiPeriodLabel({ year: 2027, month: 4 }, 'th')).toContain('2027');
});

test('saved preview omits locked advice, while the unlocked download includes steps and examples', () => {
  const result = fixture();
  const preview = thaiReportHtml(result, false);
  expect(preview).toContain(thaiReadingCopy('zh').lockedSave);
  expect(preview).not.toContain('先把分工说清楚');
  expect(preview).not.toContain('提醒内容也只在解锁之后完整展示。');
  expect(preview).not.toContain('你可以这样做');
  expect(preview).not.toContain('先把手头需要完成的事情写下来。');
  expect(preview).toContain('先明确工作分工');
  const full = thaiReportHtml(result, true);
  expect(full).toContain('先把分工说清楚');
  expect(full).toContain('先把手头需要完成的事情写下来。');
  expect(full).toContain('举个例子');
  expect(full).toContain('提醒内容也只在解锁之后完整展示。');
  expect(full).toContain('做完后这样检查');
});
