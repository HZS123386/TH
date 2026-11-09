import type { Language } from '../types';

interface City {
  id: string;
  zone: string;
  names: Record<Language, string>;
}
function city(id: string, zone: string, zh: string, th: string, vi: string): City {
  return { id, zone, names: { en: id, zh, th, vi } };
}

// Common offline cities, with free-form entry for other places. No coordinates
// or geocoding are inferred from these display names.
export const BIRTH_COUNTRIES = [
  {
    id: 'TH',
    name: 'Thailand',
    cities: [
      city('Bangkok', 'Asia/Bangkok', '曼谷', 'กรุงเทพมหานคร', 'Bangkok'),
      city('Chiang Mai', 'Asia/Bangkok', '清迈', 'เชียงใหม่', 'Chiang Mai'),
      city('Chiang Rai', 'Asia/Bangkok', '清莱', 'เชียงราย', 'Chiang Rai'),
      city('Phuket', 'Asia/Bangkok', '普吉', 'ภูเก็ต', 'Phuket'),
      city('Pattaya', 'Asia/Bangkok', '芭提雅', 'พัทยา', 'Pattaya'),
      city('Khon Kaen', 'Asia/Bangkok', '孔敬', 'ขอนแก่น', 'Khon Kaen'),
      city('Hat Yai', 'Asia/Bangkok', '合艾', 'หาดใหญ่', 'Hat Yai'),
      city('Nakhon Ratchasima', 'Asia/Bangkok', '呵叻', 'นครราชสีมา', 'Nakhon Ratchasima'),
    ],
  },
  {
    id: 'CN',
    name: 'China',
    cities: [
      city('Beijing', 'Asia/Shanghai', '北京', 'ปักกิ่ง', 'Bắc Kinh'),
      city('Shanghai', 'Asia/Shanghai', '上海', 'เซี่ยงไฮ้', 'Thượng Hải'),
      city('Guangzhou', 'Asia/Shanghai', '广州', 'กว่างโจว', 'Quảng Châu'),
      city('Shenzhen', 'Asia/Shanghai', '深圳', 'เซินเจิ้น', 'Thâm Quyến'),
      city('Chengdu', 'Asia/Shanghai', '成都', 'เฉิงตู', 'Thành Đô'),
      city('Chongqing', 'Asia/Shanghai', '重庆', 'ฉงชิ่ง', 'Trùng Khánh'),
      city('Hangzhou', 'Asia/Shanghai', '杭州', 'หางโจว', 'Hàng Châu'),
      city('Wuhan', 'Asia/Shanghai', '武汉', 'อู่ฮั่น', 'Vũ Hán'),
    ],
  },
  {
    id: 'VN',
    name: 'Vietnam',
    cities: [
      city('Hanoi', 'Asia/Ho_Chi_Minh', '河内', 'ฮานอย', 'Hà Nội'),
      city(
        'Ho Chi Minh City',
        'Asia/Ho_Chi_Minh',
        '胡志明市',
        'โฮจิมินห์ซิตี',
        'Thành phố Hồ Chí Minh',
      ),
      city('Da Nang', 'Asia/Ho_Chi_Minh', '岘港', 'ดานัง', 'Đà Nẵng'),
      city('Hai Phong', 'Asia/Ho_Chi_Minh', '海防', 'ไฮฟอง', 'Hải Phòng'),
      city('Hue', 'Asia/Ho_Chi_Minh', '顺化', 'เว้', 'Huế'),
      city('Can Tho', 'Asia/Ho_Chi_Minh', '芹苴', 'เกิ่นเทอ', 'Cần Thơ'),
    ],
  },
  {
    id: 'US',
    name: 'United States',
    cities: [
      city('New York', 'America/New_York', '纽约', 'นิวยอร์ก', 'New York'),
      city('Los Angeles', 'America/Los_Angeles', '洛杉矶', 'ลอสแอนเจลิส', 'Los Angeles'),
      city('Chicago', 'America/Chicago', '芝加哥', 'ชิคาโก', 'Chicago'),
      city('Houston', 'America/Chicago', '休斯敦', 'ฮิวสตัน', 'Houston'),
      city('San Francisco', 'America/Los_Angeles', '旧金山', 'ซานฟรานซิสโก', 'San Francisco'),
      city('Seattle', 'America/Los_Angeles', '西雅图', 'ซีแอตเทิล', 'Seattle'),
      city('Denver', 'America/Denver', '丹佛', 'เดนเวอร์', 'Denver'),
      city('Honolulu', 'Pacific/Honolulu', '檀香山', 'โฮโนลูลู', 'Honolulu'),
    ],
  },
];

export function findBirthplace(value: string) {
  for (const country of BIRTH_COUNTRIES) {
    const city = country.cities.find(
      (item) =>
        value === `${item.id}, ${country.name}` ||
        Object.values(item.names).some((name) => name.toLowerCase() === value.toLowerCase()),
    );
    if (city) return { country, city };
  }
  return null;
}

export const COMMON_TIMEZONES = [
  ...new Set(BIRTH_COUNTRIES.flatMap((country) => country.cities.map((city) => city.zone))),
  'Asia/Hong_Kong',
  'Asia/Taipei',
  'Asia/Singapore',
  'Asia/Tokyo',
  'Europe/London',
  'Australia/Sydney',
  'UTC',
];
