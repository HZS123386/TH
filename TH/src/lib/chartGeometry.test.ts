import { expect, it } from 'vitest';
import { calculateThaiHoroscope } from 'thai-astrology';
import { chartPoint, chartRelations, wholeSignHouseCusps } from './chartGeometry';

it('checks every pair against independent sign-distance rules for the confirmed Beijing morning chart', () => {
  const chart = calculateThaiHoroscope({
    date: { year: 1999, month: 2, day: 20, era: 'CE' },
    time: { hour: 7, minute: 15 },
    ascendantReference: {
      method: 'sunrise',
      latitude: 39.9075,
      longitude: 116.39723,
      utcOffsetHours: 8,
      timePrecision: 'minute',
    },
    planetaryTimeReference: { civilUtcOffsetSeconds: 28800, referenceUtcOffsetSeconds: 24124 },
  });
  const points = Object.values(chart.points).filter((point) => point.number !== null);
  const expected: Record<number, string> = {
    2: 'sextile',
    3: 'square',
    4: 'trine',
    6: 'opposition',
  };
  const lines = chartRelations(chart);
  let pairs = 0;
  for (let i = 0; i < points.length; i++)
    for (const to of points.slice(i + 1)) {
      const from = points[i];
      const difference = Math.abs(from.sign - to.sign);
      const kind = expected[Math.min(difference, 12 - difference)];
      const line = lines.find((item) => item.from.key === from.key && item.to.key === to.key);
      expect(line?.kind).toBe(kind);
      pairs++;
    }
  expect(pairs).toBe(45);
  expect(lines).toHaveLength(19);
  expect(chart.points.sun.sign).toBe(10);
  expect(chart.points.moon.sign).toBe(11);
  expect(chart.points.ascendant.sign).toBe(10);
  const cusps = wholeSignHouseCusps(chart);
  expect(cusps.map((house) => house.longitudeDegrees)).toEqual([
    300, 330, 0, 30, 60, 90, 120, 150, 180, 210, 240, 270,
  ]);
  expect(cusps[0].longitudeDegrees).not.toBe(chart.points.ascendant.longitudeDegrees);
  expect(cusps.map((house) => [house.number, house.degrees, house.minutes])).toEqual(
    Array.from({ length: 12 }, (_, index) => [index + 1, 0, 0]),
  );
});

it('places the actual ascendant on the left and wraps longitudes at 360 degrees', () => {
  const ascendant = 359.5;
  const point = chartPoint(ascendant, 220, ascendant + 180);
  expect(point.x).toBeCloseTo(20);
  expect(point.y).toBeCloseTo(240);
  expect(chartPoint(360, 220, 270).x).toBeCloseTo(chartPoint(0, 220, 270).x);
  expect(chartPoint(360, 220, 270).y).toBeCloseTo(chartPoint(0, 220, 270).y);
});

it('draws only relationships supplied by the Thai engine, without inventing degree-based aspects', () => {
  const chart = calculateThaiHoroscope({
    date: { year: 1999, era: 'CE', month: 2, day: 20 },
    time: { hour: 9, minute: 15 },
    referenceMode: 'traditional',
  });
  expect(chartRelations({ ...chart, relationships: [] })).toEqual([]);
  for (const point of Object.values(chart.points)) {
    if (point.key !== 'sun' && point.key !== 'moon') point.number = null;
  }
  const relationships = chart.relationships.map(
    (row) =>
      ({
        ...row,
        opposition: [],
        squares: [[], [], []],
        trines: [[], []],
        sextiles: [[], []],
      }) as typeof row,
  );
  relationships.find((row) => row.sign === chart.points.sun.sign)!.opposition = [
    chart.points.moon.number!,
  ];
  const links = chartRelations({ ...chart, relationships });
  expect(links).toHaveLength(1);
  expect(links[0].kind).toBe('opposition');
  expect([links[0].from.key, links[0].to.key].sort()).toEqual(['moon', 'sun']);
});
