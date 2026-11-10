import { cleanup, fireEvent, render, screen, within } from '@testing-library/react';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { useState } from 'react';
import { translations } from '../lib/i18n';
import { BirthDatePicker } from './BirthDatePicker';
import { BirthplacePicker, TimezonePicker } from './BirthplacePicker';
import * as apiClient from '../lib/api';

afterEach(() => {
  cleanup();
  vi.restoreAllMocks();
});
const t = translations.zh;
function choose(label: string, option: string) {
  fireEvent.click(
    within(screen.getByRole('listbox', { name: label })).getByRole('option', {
      name: option,
    }),
  );
}

describe('birth pickers', () => {
  it('selects a directory city outside the common list and restores its province and identity', async () => {
    const city = {
      id: 'geonames:1808963',
      countryCode: 'CN',
      nameEnglish: 'Handan',
      nameChinese: '邯郸市',
      provinceId: 'geonames:1808773',
      labelChinese: '中国，河北省，邯郸市',
      timeZone: 'Asia/Shanghai',
    };
    vi.spyOn(apiClient, 'api').mockImplementation(async (path) => {
      const params = new URL(String(path), 'http://localhost').searchParams;
      if (params.get('level') === 'detail') return { items: [city], total: 1, resolved: city };
      if (params.get('level') === 'province')
        return { items: [{ ...city, id: city.provinceId, nameChinese: '河北省' }], total: 1 };
      return { items: [city], total: 1 };
    });
    const change = vi.fn();
    const { rerender } = render(
      <BirthplacePicker
        value=""
        countryCode="CN"
        timezone="Asia/Bangkok"
        language="zh"
        t={t}
        onChange={change}
      />,
    );
    fireEvent.click(screen.getByRole('button', { name: t.birthplace }));
    await screen.findByRole('option', { name: '河北省' });
    choose(t.birthProvince, '河北省');
    fireEvent.change(screen.getByRole('textbox', { name: t.searchBirthCity }), {
      target: { value: '邯郸' },
    });
    await screen.findByRole('option', { name: '邯郸市' });
    expect(change).not.toHaveBeenCalled();
    const done = screen.getByRole('button', { name: t.pickerDone });
    await vi.waitFor(() => expect(done).toBeEnabled());
    fireEvent.click(done);
    expect(change).toHaveBeenCalledWith(city.labelChinese, city.timeZone, city);
    rerender(
      <BirthplacePicker
        value={city.labelChinese}
        countryCode="CN"
        locationId={city.id}
        timezone={city.timeZone}
        language="zh"
        t={t}
        onChange={change}
      />,
    );
    fireEvent.click(screen.getByRole('button', { name: t.birthplace }));
    await vi.waitFor(() =>
      expect(
        within(screen.getByRole('listbox', { name: t.birthProvince })).getByRole('option', {
          selected: true,
        }),
      ).toHaveTextContent('河北省'),
    );
    expect(
      within(screen.getByRole('listbox', { name: t.birthplace })).getByRole('option', {
        selected: true,
      }),
    ).toHaveTextContent('邯郸市');
    fireEvent.keyDown(document, { key: 'Escape' });
    expect(change).toHaveBeenCalledTimes(1);
  });

  it('keeps a previously saved common city selected when opening the full directory', async () => {
    const beijing = {
      id: 'geonames:1816670',
      countryCode: 'CN',
      nameEnglish: 'Beijing',
      nameChinese: '北京市',
      timeZone: 'Asia/Shanghai',
    };
    const shanghai = {
      ...beijing,
      id: 'geonames:1796236',
      nameEnglish: 'Shanghai',
      nameChinese: '上海市',
    };
    vi.spyOn(apiClient, 'api').mockImplementation(async (path) => {
      const params = new URL(String(path), 'http://localhost').searchParams;
      return params.get('level') === 'province'
        ? { items: [], total: 0 }
        : { items: [beijing, shanghai], total: 2 };
    });
    const change = vi.fn();
    render(
      <BirthplacePicker
        value="Shanghai, China"
        timezone="Asia/Shanghai"
        language="zh"
        t={t}
        onChange={change}
      />,
    );
    fireEvent.click(screen.getByRole('button', { name: t.birthplace }));
    await screen.findByRole('option', { name: '上海市' });
    expect(
      within(screen.getByRole('listbox', { name: t.birthplace })).getByRole('option', {
        selected: true,
      }),
    ).toHaveTextContent('上海市');
    await vi.waitFor(() =>
      expect(screen.getByRole('button', { name: t.pickerDone })).toBeEnabled(),
    );
    fireEvent.click(screen.getByRole('button', { name: t.pickerDone }));
    expect(change).toHaveBeenCalledWith('Shanghai, China', 'Asia/Shanghai', shanghai);
  });

  it('pages through the complete directory and discards the old city when switching country', async () => {
    const cn = {
      id: 'geonames:1816670',
      countryCode: 'CN',
      nameEnglish: 'Beijing',
      nameChinese: '北京市',
      timeZone: 'Asia/Shanghai',
    };
    const second = { ...cn, id: 'geonames:1808963', nameChinese: '邯郸市' };
    const th = {
      id: 'geonames:1609350',
      countryCode: 'TH',
      nameEnglish: 'Bangkok',
      nameChinese: '曼谷',
      timeZone: 'Asia/Bangkok',
    };
    vi.spyOn(apiClient, 'api').mockImplementation(async (path) => {
      const params = new URL(String(path), 'http://localhost').searchParams;
      if (params.get('level') === 'province') return { items: [], total: 0 };
      return params.get('country') === 'TH'
        ? { items: [th], total: 1 }
        : { items: [params.get('offset') === '100' ? second : cn], total: 101 };
    });
    const change = vi.fn();
    render(
      <BirthplacePicker
        value=""
        countryCode="CN"
        timezone="Asia/Shanghai"
        language="zh"
        t={t}
        onChange={change}
      />,
    );
    fireEvent.click(screen.getByRole('button', { name: t.birthplace }));
    await screen.findByRole('option', { name: '北京市' });
    fireEvent.click(screen.getByRole('button', { name: t.nextCityPage }));
    await screen.findByRole('option', { name: '邯郸市' });
    expect(screen.queryByRole('option', { name: '北京市' })).not.toBeInTheDocument();
    choose(t.birthCountry, '泰国');
    await screen.findByRole('option', { name: '曼谷' });
    expect(screen.queryByRole('option', { name: '邯郸市' })).not.toBeInTheDocument();
    await vi.waitFor(() =>
      expect(screen.getByRole('button', { name: t.pickerDone })).toBeEnabled(),
    );
    fireEvent.click(screen.getByRole('button', { name: t.pickerDone }));
    expect(change).toHaveBeenCalledWith('Bangkok, Thailand', 'Asia/Bangkok', th);
  });
  it('converts a Buddhist wheel year to Gregorian storage', () => {
    const change = vi.fn();
    render(<BirthDatePicker value="1999-02-20" maximum="2026-11-05" t={t} onChange={change} />);
    fireEvent.click(screen.getByRole('button', { name: '出生日期' }));
    fireEvent.click(screen.getByRole('button', { name: t.w_buddhist }));
    choose('年', '2543');
    fireEvent.click(screen.getByRole('button', { name: '完成' }));
    expect(change).toHaveBeenCalledWith('2000-02-20');
  });
  it('clamps February 29 to February 28 when the year changes, then commits only on Done', () => {
    const change = vi.fn();
    render(<BirthDatePicker value="2000-02-29" maximum="2026-11-04" t={t} onChange={change} />);
    fireEvent.click(screen.getByRole('button', { name: '出生日期' }));
    choose('年', '2001');
    expect(screen.getByRole('listbox', { name: '日' })).not.toHaveTextContent('29');
    expect(change).not.toHaveBeenCalled();
    fireEvent.click(screen.getByRole('button', { name: '完成' }));
    expect(change).toHaveBeenCalledWith('2001-02-28');
  });

  it('never offers a date later than today, and Escape discards edits', () => {
    const change = vi.fn();
    render(<BirthDatePicker value="2025-12-31" maximum="2026-11-04" t={t} onChange={change} />);
    fireEvent.click(screen.getByRole('button', { name: '出生日期' }));
    choose('年', '2026');
    expect(within(screen.getByRole('listbox', { name: '月' })).getAllByRole('option')).toHaveLength(
      11,
    );
    expect(within(screen.getByRole('listbox', { name: '日' })).getAllByRole('option')).toHaveLength(
      4,
    );
    fireEvent.keyDown(document, { key: 'Escape' });
    expect(screen.queryByRole('dialog')).not.toBeInTheDocument();
    expect(change).not.toHaveBeenCalled();
    expect(screen.getByRole('button', { name: '出生日期' })).toHaveTextContent('2025');
  });

  it('shows Gregorian years even in the Thai locale', () => {
    render(
      <BirthDatePicker
        value="1999-02-20"
        maximum="2026-11-04"
        t={translations.th}
        onChange={() => {}}
      />,
    );
    expect(screen.getByRole('button')).toHaveTextContent('1999');
    expect(screen.getByRole('button')).not.toHaveTextContent('2542');
  });

  it('cascades country and city and returns the city timezone', () => {
    const change = vi.fn();
    render(
      <BirthplacePicker
        value="Bangkok"
        timezone="Asia/Bangkok"
        language="zh"
        t={t}
        onChange={change}
      />,
    );
    fireEvent.click(screen.getByRole('button', { name: '出生城市' }));
    choose('国家 / 地区', '美国');
    expect(screen.queryByRole('option', { name: '曼谷' })).not.toBeInTheDocument();
    choose('出生城市', '洛杉矶');
    fireEvent.click(screen.getByRole('button', { name: '完成' }));
    expect(change).toHaveBeenCalledWith('Los Angeles, United States', 'America/Los_Angeles');
  });

  it('preserves a legacy free-form birthplace and its timezone', () => {
    const change = vi.fn();
    render(
      <BirthplacePicker
        value="My hometown"
        timezone="Europe/London"
        language="en"
        t={t}
        onChange={change}
      />,
    );
    fireEvent.click(screen.getByRole('button', { name: '出生城市' }));
    expect(screen.getByRole('textbox')).toHaveValue('My hometown');
    fireEvent.change(screen.getByRole('textbox'), { target: { value: '  My village  ' } });
    fireEvent.click(screen.getByRole('button', { name: '完成' }));
    expect(change).toHaveBeenCalledWith('My village', 'Europe/London');
  });

  it('uses the highlighted search result when confirming a timezone', () => {
    const change = vi.fn();
    render(<TimezonePicker value="Asia/Bangkok" t={t} onChange={change} />);
    fireEvent.click(screen.getByRole('button', { name: t.timezone }));
    fireEvent.change(screen.getByRole('textbox'), { target: { value: 'America/Los Angeles' } });
    expect(screen.getByRole('option', { selected: true })).toHaveTextContent('America/Los_Angeles');
    fireEvent.click(screen.getByRole('button', { name: '完成' }));
    expect(change).toHaveBeenCalledWith('America/Los_Angeles');
  });

  it('supports keyboard selection and keeps focus inside the dialog', () => {
    function Example() {
      const [value, setValue] = useState('2000-01-01');
      return <BirthDatePicker value={value} maximum="2026-11-04" t={t} onChange={setValue} />;
    }
    render(<Example />);
    const trigger = screen.getByRole('button', { name: '出生日期' });
    trigger.focus();
    fireEvent.click(trigger);
    fireEvent.keyDown(screen.getByRole('listbox', { name: '日' }), {
      key: 'ArrowDown',
    });
    const done = screen.getByRole('button', { name: '完成' });
    done.focus();
    fireEvent.keyDown(document, { key: 'Tab' });
    expect(screen.getByRole('button', { name: t.pickerCancel })).toHaveFocus();
    fireEvent.click(done);
    expect(trigger).toHaveTextContent('2日');
    expect(trigger).toHaveFocus();
  });
});
