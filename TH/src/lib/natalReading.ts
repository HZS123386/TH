import type { ThaiHoroscope } from 'thai-astrology';
import type { Language } from '../types';
import copy from '../content/natal-reading.json';
import { chartRelations } from './chartGeometry';

export const readingPlanetKeys = [
  'sun',
  'moon',
  'mercury',
  'venus',
  'mars',
  'jupiter',
  'saturn',
  'uranus',
  'rahu',
  'ketu',
] as const;

export function natalPlanetShares(chart: ThaiHoroscope) {
  const links = chartRelations(chart);
  const total = links.length * 2;
  return readingPlanetKeys.map((key) => {
    const count = links.filter((line) => line.from.key === key || line.to.key === key).length;
    return { key, count, total, percent: total ? Math.round((count * 100) / total) : null };
  });
}

export const elementPointKeys = [
  'sun',
  'moon',
  'mercury',
  'venus',
  'mars',
  'jupiter',
  'saturn',
] as const;
export const readingTopics = [
  { key: 'work', houses: [10, 6, 3, 11] },
  { key: 'money', houses: [2, 11, 8] },
  { key: 'love', houses: [7, 5, 1] },
  { key: 'family', houses: [4, 2, 3] },
] as const;

export const natalReadingCopy = (language: Language) => copy[language];

export function natalDistribution(chart: ThaiHoroscope, kind: 'element' | 'modality') {
  const size = kind === 'element' ? 4 : 3;
  const groups = Array.from({ length: size }, (_, index) => ({
    index,
    points: elementPointKeys.filter((key) => chart.points[key].sign % size === index),
    percent: 0,
  }));
  // Equal counts keep equal percentages; exact counts remain visible beside rounded shares.
  for (const group of groups) group.percent = Number(((group.points.length * 100) / 7).toFixed(1));
  const largest = Math.max(...groups.map((group) => group.points.length));
  return { groups, leaders: groups.filter((group) => group.points.length === largest) };
}

export function natalTopicEvidence(chart: ThaiHoroscope) {
  return readingTopics.map((topic) => {
    const houses = topic.houses.map((number) =>
      chart.houses.find((house) => house.number === number)!,
    );
    const anchor = houses[0];
    return { ...topic, houses, anchor, ruler: chart.points[anchor.ruler.key] };
  });
}
