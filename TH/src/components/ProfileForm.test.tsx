import { cleanup, fireEvent, render, screen, waitFor, within } from '@testing-library/react';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { translations } from '../lib/i18n';
import { ProfileForm } from './ProfileForm';
afterEach(cleanup);
describe('birth profile', () => {
  it('submits null for an unknown time instead of silently using noon', async () => {
    const save = vi.fn().mockResolvedValue(undefined);
    render(<ProfileForm language="zh" t={translations.zh} onSave={save} onBack={() => {}} />);
    fireEvent.click(screen.getByText('填入示例资料'));
    fireEvent.click(screen.getByLabelText('不记得确切时间'));
    expect(screen.getByRole('button', { name: '出生时间' })).toBeDisabled();
    fireEvent.submit(screen.getByText('保存档案并生成命盘').closest('form')!);
    await waitFor(() =>
      expect(save).toHaveBeenCalledWith(
        expect.objectContaining({
          birth_date: '1995-08-17',
          birth_time: null,
          timezone: 'Asia/Bangkok',
        }),
      ),
    );
  });
  it.each([
    ['am', '12', '00', '00:00'],
    ['pm', '12', '00', '12:00'],
    ['pm', '9', '35', '21:35'],
  ])('saves %s %s:%s as local 24-hour time %s', async (period, hour, minute, expected) => {
    const save = vi.fn().mockResolvedValue(undefined);
    render(<ProfileForm language="zh" t={translations.zh} onSave={save} onBack={() => {}} />);
    fireEvent.click(screen.getByText('填入示例资料'));
    fireEvent.click(screen.getByRole('button', { name: '出生时间' }));
    const dialog = within(screen.getByRole('dialog'));
    fireEvent.click(
      within(dialog.getByRole('listbox', { name: '上午 / 下午' })).getByRole('option', {
        name: period === 'am' ? '上午（AM）' : '下午（PM）',
      }),
    );
    fireEvent.click(
      within(dialog.getByRole('listbox', { name: '几点' })).getByRole('option', {
        name: hour.padStart(2, '0'),
      }),
    );
    fireEvent.click(
      within(dialog.getByRole('listbox', { name: '几分' })).getByRole('option', {
        name: minute,
      }),
    );
    fireEvent.click(dialog.getByRole('button', { name: '完成' }));
    fireEvent.submit(screen.getByText('保存档案并生成命盘').closest('form')!);
    await waitFor(() =>
      expect(save).toHaveBeenCalledWith(expect.objectContaining({ birth_time: expected })),
    );
  });
  it('requires a birth date before saving', async () => {
    const save = vi.fn();
    render(<ProfileForm language="zh" t={translations.zh} onSave={save} onBack={() => {}} />);
    fireEvent.submit(screen.getByText('保存档案并生成命盘').closest('form')!);
    expect(await screen.findByRole('alert')).toHaveTextContent(translations.zh.chooseBirthDate);
    expect(save).not.toHaveBeenCalled();
  });
  it('allows leaving the optional time and city empty', async () => {
    const save = vi.fn().mockResolvedValue(undefined);
    render(
      <ProfileForm
        profile={{
          display_name: '',
          birth_date: '1999-02-20',
          birth_time: '',
          birthplace: '',
          timezone: 'Asia/Bangkok',
          language: 'zh',
        }}
        language="zh"
        t={translations.zh}
        onSave={save}
        onBack={() => {}}
      />,
    );
    fireEvent.submit(screen.getByText('保存档案并生成命盘').closest('form')!);
    await waitFor(() =>
      expect(save).toHaveBeenCalledWith(
        expect.objectContaining({ birth_time: null, birthplace: '' }),
      ),
    );
  });
  it('restores the selected time when unknown is unchecked', async () => {
    const save = vi.fn().mockResolvedValue(undefined);
    render(<ProfileForm language="zh" t={translations.zh} onSave={save} onBack={() => {}} />);
    fireEvent.click(screen.getByText('填入示例资料'));
    fireEvent.click(screen.getByRole('button', { name: '出生时间' }));
    fireEvent.click(
      within(screen.getByRole('listbox', { name: '上午 / 下午' })).getByRole('option', {
        name: '下午（PM）',
      }),
    );
    fireEvent.click(screen.getByRole('button', { name: '完成' }));
    fireEvent.click(screen.getByLabelText('不记得确切时间'));
    fireEvent.click(screen.getByLabelText('不记得确切时间'));
    expect(screen.getByRole('button', { name: '出生时间' })).toHaveTextContent('9:30');
    fireEvent.submit(screen.getByText('保存档案并生成命盘').closest('form')!);
    await waitFor(() =>
      expect(save).toHaveBeenCalledWith(expect.objectContaining({ birth_time: '21:30' })),
    );
  });
  it('shows a server validation error and allows correcting the form', async () => {
    render(
      <ProfileForm
        language="zh"
        t={translations.zh}
        onSave={vi.fn().mockRejectedValue(new Error('出生时刻不存在'))}
        onBack={() => {}}
      />,
    );
    fireEvent.click(screen.getByText('填入示例资料'));
    fireEvent.submit(screen.getByText('保存档案并生成命盘').closest('form')!);
    expect(await screen.findByRole('alert')).toHaveTextContent('出生时刻不存在');
    expect(screen.getByRole('button', { name: '保存档案并生成命盘' })).toBeEnabled();
  });
});
