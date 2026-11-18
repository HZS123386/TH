import { mkdir, writeFile } from 'node:fs/promises';
import { calculateThaiHoroscope } from 'thai-astrology';
import { calculateDailyCalendar, ENGINE } from '../../scripts/thai-engine.mjs';

// Bundle the existing engine's results for offline browsing without a new API.
const firstYear = 2025, lastYear = 2030;
const target = new URL('../assets/calendar/', import.meta.url);
await mkdir(target, { recursive: true });
const chartFor = date => calculateThaiHoroscope({
  date: { year: date.getUTCFullYear(), month: date.getUTCMonth() + 1, day: date.getUTCDate(), era: 'CE' },
  time: { hour: 12, minute: 0 }, referenceMode: 'traditional',
});
for (let year = firstYear; year <= lastYear; year++) {
  const days = [];
  for (const date = new Date(Date.UTC(year, 0, 1)); date.getUTCFullYear() === year; date.setUTCDate(date.getUTCDate() + 1)) {
    const iso = date.toISOString().slice(0, 10);
    const daily = calculateDailyCalendar(iso);
    const { calendar, points: { moon } } = chartFor(date);
    const smallEra = calendar.chulaSakarat;
    const matches = value => (value % 7 || 7) === calendar.civilWeekday;
    // Expand the same four Kalayok bases used by calculateDailyCalendar.
    const kalayok = [
      ['thongchai', smallEra * 10 + 3], ['athibodi', smallEra % 498],
      ['ubat', smallEra * 10 + 2], ['lokawinas', smallEra + 1120],
    ].filter(([, value]) => matches(value)).map(([key]) => key);
    const lunar = daily.lunar;
    if (!lunar) throw new Error(`Missing lunar date: ${iso}`);
    const tomorrow = chartFor(new Date(date.getTime() + 86400000)).calendar.thaiLunarDate;
    const wanPhra = lunar.day === 8 || lunar.day === 15 ||
      (lunar.phase === 'waning' && lunar.day === 14 && tomorrow?.phase === 'waxing' && tomorrow.day === 1);
    // Dithi Riang Mon: waxing 7/10/13, waning 4/8/10/14 (source in manifest).
    const riangMon = (lunar.phase === 'waxing' ? [7, 10, 13] : [4, 8, 10, 14]).includes(lunar.day);
    days.push({ ...daily, small_era: smallEra, kalayok, wan_phra: wanPhra, riang_mon: riangMon,
      mansion: { index: moon.nakshatraIndex + 1, quarter: moon.nakshatraQuarter, name: moon.nakshatraName, rerk: moon.rerk },
    });
  }
  await writeFile(new URL(`${year}.json`, target), JSON.stringify({ schema: 1, year, days }) + '\n');
  console.log(`${year}: ${days.length} days`);
}
await writeFile(new URL('source.json', target), JSON.stringify({
  schema: 1, first_year: firstYear, last_year: lastYear, engine: ENGINE,
  reference: 'Traditional Thai calendar, civil date, Bangkok noon; daytime Ubakong only',
  sources: [
    'https://www.culture.go.th/culture_th/ewt_news.php?filename=index&nid=9131',
    'https://www.maneedee.com/yam-ubakong/',
    'https://myhora.com/calendar/thai-05-2414-R09.aspx',
    'https://siamduang.com/wp-content/uploads/2019/09/การให้ฤกษ์ฉบับง่าย-Example.pdf',
  ],
}, null, 2) + '\n');
