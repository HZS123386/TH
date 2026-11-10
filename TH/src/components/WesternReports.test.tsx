import { cleanup, fireEvent, render, screen } from '@testing-library/react';
import { afterEach, expect, it, vi } from 'vitest';
import { translations } from '../lib/i18n';
import { westernCopy, type WesternReport } from '../lib/western';
import { WesternPurchaseDialog, WesternReports } from './WesternReports';

afterEach(() => {
  cleanup();
  localStorage.clear();
});
const a = westernCopy('zh');
const defaults = {
  language: 'zh' as const,
  t: translations.zh,
  owner: 'test',
  detail: true,
  example: false,
  loading: false,
  onGenerate: vi.fn(),
  onExample: vi.fn(),
  onBack: vi.fn(),
  onPurchase: vi.fn(),
};

it('renders real preview text while keeping full-report content absent from the DOM', () => {
  const report: WesternReport = {
    report_id: 'r',
    system: 'western_natal',
    calculation_result_id: 'c',
    locale: 'zh',
    access: 'preview',
    summary: '个人试读结论',
    preview: [{ key: 'traits', title: '你的特点', paragraphs: ['来自当前星盘的试读'] }],
    sections: [],
  };
  const purchase = vi.fn();
  render(<WesternReports {...defaults} report={report} onPurchase={purchase} />);
  expect(screen.getByText('来自当前星盘的试读')).toBeVisible();
  expect(screen.queryByText(a.sampleAdvice1Text)).toBeNull();
  fireEvent.click(screen.getAllByRole('button', { name: a.unlock })[0]);
  expect(purchase).toHaveBeenCalledWith(expect.any(Function), false);
  expect(screen.queryByText(a.sampleAdvice1Text)).toBeNull();
});

it('offers only a clearly labelled example expansion and no browser purchase', () => {
  const preview = vi.fn();
  render(
    <WesternPurchaseDialog
      language="zh"
      t={translations.zh}
      example
      onCancel={vi.fn()}
      onPreview={preview}
    />,
  );
  expect(screen.getByRole('button', { name: a.appleBuy })).toBeDisabled();
  expect(screen.getByText(a.purchasePreview)).toBeVisible();
  fireEvent.click(screen.getByRole('button', { name: a.restore }));
  expect(screen.getByRole('status')).toHaveTextContent(a.restoreNote);
  fireEvent.click(screen.getByRole('button', { name: a.previewFull }));
  expect(preview).toHaveBeenCalledTimes(1);
  expect(Object.keys(localStorage)).toEqual([]);
});

it('does not offer example expansion for a personal report purchase', () => {
  render(
    <WesternPurchaseDialog
      language="zh"
      t={translations.zh}
      example={false}
      onCancel={vi.fn()}
      onPreview={vi.fn()}
    />,
  );
  expect(screen.queryByRole('button', { name: a.previewFull })).toBeNull();
});
