import { expect, it } from 'vitest';
import { calculateThaiHoroscope } from 'thai-astrology';
import {
  elementPointKeys,
  natalDistribution,
  natalPlanetShares,
  natalTopicEvidence,
} from './natalReading';

function chartAt(hour = 9) {
  return calculateThaiHoroscope({
    date: { year: 1999, era: 'CE', month: 2, day: 20 },
    time: { hour, minute: 15 },
    referenceMode: 'traditional',
  });
}

it('counts only seven classical bodies equally and displays their rounded shares', () => {
  const chart = chartAt();
  elementPointKeys.forEach((key, index) => {
    chart.points[key].sign = [0, 4, 8, 1, 5, 2, 3][index];
  });
  for (const key of ['rahu', 'ketu', 'uranus', 'ascendant'] as const) chart.points[key].sign = 3;
  const before = JSON.stringify(chart);
  const result = natalDistribution(chart, 'element');
  expect(result.groups.map((group) => group.points.length)).toEqual([3, 2, 1, 1]);
  expect(result.groups.map((group) => group.percent)).toEqual([42.9, 28.6, 14.3, 14.3]);
  expect(result.groups.flatMap((group) => group.points).sort()).toEqual(
    [...elementPointKeys].sort(),
  );
  expect(JSON.stringify(chart)).toBe(before);
});

it('keeps tied leading elements and a zero element rather than inventing a single dominant element', () => {
  const chart = chartAt();
  elementPointKeys.forEach((key, index) => {
    chart.points[key].sign = [0, 4, 8, 1, 5, 9, 2][index];
  });
  const result = natalDistribution(chart, 'element');
  expect(result.leaders.map((group) => group.index)).toEqual([0, 1]);
  expect(result.groups.map((group) => group.percent)).toEqual([42.9, 42.9, 14.3, 0]);
});

it('groups modalities separately from elements', () => {
  const chart = chartAt();
  elementPointKeys.forEach((key, index) => {
    chart.points[key].sign = [0, 3, 6, 9, 1, 4, 2][index];
  });
  const result = natalDistribution(chart, 'modality');
  expect(result.groups.map((group) => group.points.length)).toEqual([4, 2, 1]);
  expect(result.groups.reduce((sum, group) => sum + group.percent, 0)).toBeCloseTo(100, 0);
});

it('counts both ends of real relationship records and excludes the ascendant from planet badges', () => {
  const chart = chartAt();
  for (const key of ['mercury', 'venus', 'jupiter', 'saturn', 'uranus', 'rahu', 'ketu'] as const)
    chart.points[key].number = null;
  chart.relationships = chart.relationships.map((row) => ({
    ...row,
    opposition: [],
    squares: [[], [], []],
    trines: [[], []],
    sextiles: [[], []],
  }));
  const sun = chart.relationships.find((row) => row.sign === chart.points.sun.sign)!;
  sun.opposition = [chart.points.moon.number!];
  sun.squares = [[chart.points.mars.number!], [], []];
  const before = JSON.stringify(chart);
  const shares = natalPlanetShares(chart);
  expect(shares).toHaveLength(10);
  expect(shares.find((share) => share.key === 'sun')).toMatchObject({
    count: 2,
    total: 4,
    percent: 50,
  });
  expect(shares.find((share) => share.key === 'moon')).toMatchObject({
    count: 1,
    total: 4,
    percent: 25,
  });
  expect(shares.find((share) => share.key === 'mars')).toMatchObject({
    count: 1,
    total: 4,
    percent: 25,
  });
  expect(shares.find((share) => share.key === 'mercury')?.percent).toBe(0);
  expect(shares.map((share) => share.key)).not.toContain('ascendant');
  expect(JSON.stringify(chart)).toBe(before);
});

it('does not invent a percentage when a chart has no relationship records', () => {
  const shares = natalPlanetShares({ ...chartAt(), relationships: [] });
  expect(
    shares.every((share) => share.count === 0 && share.total === 0 && share.percent === null),
  ).toBe(true);
});

it('grounds every life topic in the actual houses and ruler placements of the supplied chart', () => {
  const morning = chartAt(7);
  const evening = chartAt(19);
  for (const chart of [morning, evening]) {
    const topics = natalTopicEvidence(chart);
    expect(topics.map((topic) => topic.anchor.number)).toEqual([10, 2, 7, 4]);
    for (const topic of topics) {
      expect(topic.anchor).toBe(chart.houses[topic.anchor.number - 1]);
      expect(topic.ruler).toBe(chart.points[topic.anchor.ruler.key]);
      expect(topic.ruler.house).toBe(topic.anchor.ruler.house);
      for (const house of topic.houses) expect(house).toBe(chart.houses[house.number - 1]);
    }
  }
  expect(
    natalTopicEvidence(morning).map((topic) => [topic.ruler.key, topic.ruler.house]),
  ).not.toEqual(natalTopicEvidence(evening).map((topic) => [topic.ruler.key, topic.ruler.house]));
});
