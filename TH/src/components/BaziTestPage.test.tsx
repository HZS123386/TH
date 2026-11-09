import { act, cleanup, fireEvent, render, screen, waitFor } from '@testing-library/react';
import { afterEach, beforeEach, expect, test, vi } from 'vitest';
import { BaziTestPage } from './BaziTestPage';
import { BaziRoxyDetails } from './BaziRoxyDetails';
import { translations } from '../lib/i18n';
import { api } from '../lib/api';
import { baziCopy, baziReportHtml, type BaziTestResult } from '../lib/bazi';
import { baziFactBlocks } from '../lib/baziFacts';
import { baziPillarName, baziProseMatches } from '../lib/baziLocale';
import type { Language, Profile } from '../types';

vi.mock('../lib/api', () => ({ api: vi.fn() }));
const profile: Profile = {
  display_name: '',
  birth_date: '1995-08-17',
  birth_time: '10:30',
  timezone: 'Asia/Shanghai',
  birthplace: '',
  language: 'zh',
};
const fixture = (): BaziTestResult => ({
  report_id: 'sample',
  generated_at: '2026-11-07T12:00:00+07:00',
  input: {
    profile,
    source: 'roxy',
    topics: ['chart'],
    focus: 'overview',
    clock: 'local',
    gender: null,
    year: 2026,
  },
  calculation_input: { birth_date: '1995-08-17', birth_time: '10:30', timezone: 'Asia/Shanghai' },
  sources: {},
  comparison: { status: 'partial', rows: [], scope: 'four-pillars-only' },
  report: {
    title: '解读报告',
    language: 'zh',
    sections: [
      {
        id: 'chart',
        title: '计算后的解读',
        source: 'RoxyAPI',
        paragraphs: ['这是对应当前生辰的解读文本。'],
      },
    ],
  },
});
const mount = (enabled = true, language: Language = 'zh') =>
  render(
    <BaziTestPage
      profile={profile}
      language={language}
      t={translations[language]}
      roxyEnabled={enabled}
      onBack={vi.fn()}
    />,
  );

beforeEach(() => vi.clearAllMocks());
afterEach(cleanup);

test('uses the default source and sends the chosen reading and calculation topics', async () => {
  vi.mocked(api).mockResolvedValue(fixture());
  mount();
  fireEvent.click(screen.getByRole('radio', { name: '八字事业' }));
  fireEvent.click(screen.getByRole('button', { name: '生成结果与解读报告' }));
  await screen.findByTestId('bazi-report');
  const init = vi.mocked(api).mock.calls[0][1]!;
  expect(JSON.parse(String(init.body))).toMatchObject({
    topics: ['chart', 'strength'],
    source: 'roxy',
    focus: 'work',
    profile,
  });
  expect(screen.getByText('这是对应当前生辰的解读文本。')).toBeInTheDocument();
  expect(screen.queryByText('选择数据来源')).not.toBeInTheDocument();
  expect(screen.queryByText('选择要测的内容')).not.toBeInTheDocument();
  expect(screen.queryByRole('radio', { name: '十年大运' })).not.toBeInTheDocument();
  expect(screen.queryByText('查看 Roxy 原始返回')).not.toBeInTheDocument();
  expect(screen.queryByText('查看计算依据')).not.toBeInTheDocument();
  expect(screen.queryByTestId('bazi-comparison')).not.toBeInTheDocument();
});

test('changing inputs aborts and discards a delayed old report', async () => {
  let finish!: (value: BaziTestResult) => void;
  vi.mocked(api).mockReturnValue(
    new Promise((resolve) => {
      finish = resolve;
    }),
  );
  mount();
  fireEvent.click(screen.getByRole('button', { name: '生成结果与解读报告' }));
  await waitFor(() => expect(api).toHaveBeenCalledOnce());
  const signal = vi.mocked(api).mock.calls[0][1]!.signal;
  fireEvent.click(screen.getByRole('radio', { name: '八字财运' }));
  expect(signal?.aborted).toBe(true);
  await act(async () => finish(fixture()));
  expect(screen.queryByTestId('bazi-report')).not.toBeInTheDocument();
});

test('local mode disables paid topics and works without a Roxy key', async () => {
  vi.mocked(api).mockResolvedValue(fixture());
  mount(false);
  expect(screen.getByRole('radio', { name: '全年运势' })).toBeDisabled();
  expect(screen.queryByLabelText('GitHub 本地计算')).not.toBeInTheDocument();
  fireEvent.click(screen.getByRole('button', { name: '生成结果与解读报告' }));
  await screen.findByTestId('bazi-report');
  expect(JSON.parse(String(vi.mocked(api).mock.calls[0][1]!.body))).toMatchObject({
    source: 'github',
    topics: ['chart'],
  });
});

test('downloadable reports escape user text and upstream HTML', () => {
  const result = fixture();
  result.input.profile = { ...profile, display_name: '<script>alert(1)</script>' };
  result.report.sections[0].paragraphs = ['<img src=x onerror=alert(1)>'];
  result.calculation_input.hidden = 'INTERNAL_CALCULATION_MARKER';
  result.sources.roxy = {
    status: 'ready',
    chart: null,
    details: {
      chart: { cached: false, language: 'zh', data: { internal: 'INTERNAL_RAW_MARKER' } },
      strength: {
        cached: false,
        language: 'zh',
        data: {
          verdict: 'very-strong',
          score: 4.9231,
          factors: [{ chinese: '月令', contribution: 3, detail: '因素说明' }],
        },
      },
      luck: {
        cached: false,
        language: 'zh',
        data: {
          startAge: 6.125,
          luckPillars: [
            {
              stem: { chinese: '乙' },
              branch: { chinese: '酉' },
              startAge: 6.125,
              endAge: 16.125,
              startYear: 2001,
              endYear: 2011,
            },
          ],
        },
      },
      annual: {
        cached: false,
        language: 'zh',
        data: { year: 2088, annualPillar: { stem: { chinese: '丙' }, branch: { chinese: '戌' } } },
      },
    },
  };
  const html = baziReportHtml(result);
  expect(html).not.toContain('<script>');
  expect(html).not.toContain('<img');
  expect(html).toContain('&lt;img');
  expect(html).not.toContain('INTERNAL_CALCULATION_MARKER');
  expect(html).not.toContain('INTERNAL_RAW_MARKER');
  expect(html).not.toContain('<details>');
  expect(html).toContain('4.9231');
  expect(html).toContain('极强');
  expect(html).toContain('因素说明');
  expect(html).toContain('6.125');
  expect(html).toContain('2001–2011');
  expect(html).toContain('乙酉');
  expect(html).toContain('2088');
  expect(html).toContain('丙戌');
});

test('annual reading includes its required calculation and sends the selected year', async () => {
  vi.mocked(api).mockResolvedValue(fixture());
  mount();
  fireEvent.click(screen.getByRole('radio', { name: '全年运势' }));
  expect(screen.queryByText('选择要测的内容')).not.toBeInTheDocument();
  fireEvent.change(screen.getByLabelText('要查看的年份'), { target: { value: '2028' } });
  fireEvent.click(screen.getByRole('button', { name: '生成结果与解读报告' }));
  await screen.findByTestId('bazi-report');
  expect(JSON.parse(String(vi.mocked(api).mock.calls[0][1]!.body))).toMatchObject({
    source: 'roxy',
    topics: ['chart', 'annual'],
    year: 2028,
  });
  expect(screen.getByTestId('bazi-report')).toHaveTextContent('中国占星 · 全年运势');
  fireEvent.click(screen.getByRole('radio', { name: '八字婚恋' }));
  expect(screen.queryByLabelText('要查看的年份')).not.toBeInTheDocument();
  expect(screen.queryByTestId('bazi-report')).not.toBeInTheDocument();
});

test('very strong is not displayed as weak and single-source exports do not claim a failed comparison', () => {
  render(
    <BaziRoxyDetails
      operation="strength"
      language="zh"
      data={{ verdict: 'very-strong', score: 4.9, factors: [] }}
    />,
  );
  expect(screen.getByTestId('bazi-strength-facts')).toHaveTextContent('极强');
  expect(screen.getByTestId('bazi-strength-facts')).not.toHaveTextContent('偏弱');
  const result = fixture();
  result.input.source = 'github';
  expect(baziReportHtml(result)).not.toContain('资料或结果不完整，暂不能完整对照');
});

test('legacy editorial and scope sections are absent from screen and download', async () => {
  const result = fixture();
  result.report.sections.push(
    { id: 'focus', title: '把解读放回生活', source: 'editorial', paragraphs: ['旧的固定提示'] },
    { id: 'scope', title: '阅读范围', source: 'scope', paragraphs: ['旧的阅读范围'] },
  );
  vi.mocked(api).mockResolvedValue(result);
  mount();
  fireEvent.click(screen.getByRole('button', { name: baziCopy('zh').generate }));
  await screen.findByTestId('bazi-report');
  expect(screen.queryByText('把解读放回生活')).not.toBeInTheDocument();
  expect(screen.queryByText('阅读范围')).not.toBeInTheDocument();
  expect(baziReportHtml(result)).not.toContain('旧的固定提示');
  expect(baziReportHtml(result)).not.toContain('旧的阅读范围');
});

const localizedFactor = {
  zh: '金在金月处于旺势。',
  en: 'Metal is prosperous in a Metal month',
  th: 'ธาตุทองเกิดในเดือนธาตุทองและมีกำลังรุ่งเรือง',
  vi: 'Kim ở tháng Kim có trạng thái vượng.',
};
const localAdvice = {
  zh: '先协调工作中的交付标准，再讨论各自可以承担的责任。',
  en: 'Agree on delivery standards before discussing individual responsibilities.',
  th: 'ตกลงมาตรฐานงานร่วมกันก่อนแบ่งหน้าที่ที่แต่ละคนรับผิดชอบได้',
  vi: 'Hãy thống nhất tiêu chuẩn công việc trước khi phân chia trách nhiệm.',
};
test.each(['zh', 'en', 'th', 'vi'] as const)(
  'facts and reports follow the selected %s language',
  async (language) => {
    const result = fixture();
    result.report.language = language;
    result.report.translations = { 'strength.factors.0.detail': localizedFactor[language] };
    result.report.sections = [
      {
        id: 'advice',
        title: baziCopy(language).reportSections.advice,
        source: 'calculated-reading',
        paragraphs: [localAdvice[language]],
      },
    ];
    const data = {
      verdict: 'very-strong',
      score: 4.9,
      factors: [
        { chinese: '得令', contribution: 3, detail: 'Metal is prosperous in a Metal month' },
      ],
      favorableElements: ['Water', 'Wood'],
      unfavorableElements: ['Metal'],
    };
    result.sources.roxy = {
      status: 'ready',
      chart: null,
      details: { strength: { cached: false, language: 'en', data } },
    };
    vi.mocked(api).mockResolvedValue(result);
    mount(true, language);
    fireEvent.click(screen.getByRole('button', { name: baziCopy(language).generate }));
    await screen.findByTestId('bazi-report');
    expect(JSON.parse(String(vi.mocked(api).mock.calls[0][1]!.body)).profile.language).toBe(
      language,
    );
    expect(screen.getByTestId('bazi-strength-facts')).toHaveTextContent(localizedFactor[language]);
    expect(screen.getByTestId('bazi-report')).toHaveTextContent(localAdvice[language]);
    const html = baziReportHtml(result);
    expect(html).toContain(localizedFactor[language]);
    expect(html).toContain(localAdvice[language]);
    if (language !== 'en') expect(html).not.toContain('Metal is prosperous');
    if (language !== 'zh') expect(baziPillarName('庚辰', language)).not.toMatch(/[\u3400-\u9fff]/);
    if (language === 'zh') {
      expect(screen.getByTestId('bazi-strength-facts')).not.toHaveTextContent('Water');
      expect(screen.getByTestId('bazi-strength-facts')).toHaveTextContent('水 / 木');
    }
  },
);

test.each(['unavailable', 'conflict', 'time_required', 'limited'])(
  'download includes a localized %s state',
  (state) => {
    const result = fixture();
    result.report.generation = { state };
    result.report.sections = [];
    expect(baziReportHtml(result)).toContain(
      (baziCopy('zh').reportStates as Record<string, string>)[state],
    );
  },
);

test('foreign-language factor text is not shown as untranslated prose', () => {
  const data = {
    verdict: 'balanced',
    score: 0,
    factors: [{ contribution: 0, detail: 'This is still an English explanation tôi' }],
  };
  expect(baziFactBlocks('strength', data, 'vi')[0].paragraphs?.join(' ')).not.toContain(
    'English explanation',
  );
  expect(
    baziProseMatches('This is an English paragraph about planning and your next steps tôi', 'vi'),
  ).toBe(false);
});
