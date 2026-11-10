import type { ThaiHoroscope } from 'thai-astrology';

export type ChartRelationKind = 'opposition' | 'square' | 'trine' | 'sextile';
export interface ChartRelation {
  from: ThaiHoroscope['points']['sun'];
  to: ThaiHoroscope['points']['sun'];
  kind: ChartRelationKind;
  color: string;
}

export const planetSymbols: Record<keyof ThaiHoroscope['points'], string> = {
  sun: '☉',
  moon: '☾',
  mercury: '☿',
  venus: '♀\uFE0E',
  mars: '♂\uFE0E',
  jupiter: '♃',
  saturn: '♄',
  uranus: '♅',
  rahu: '☊',
  ketu: '☋',
  ascendant: 'AC',
};

export function wholeSignHouseCusps(chart: ThaiHoroscope) {
  // The engine assigns each whole-sign house a sign; its cusp is that sign's boundary.
  return chart.houses.map((house) => {
    const longitudeDegrees = house.sign * 30;
    return {
      ...house,
      longitudeDegrees,
      degrees: longitudeDegrees % 30,
      minutes: (longitudeDegrees % 1) * 60,
    };
  });
}

export const chartPoint = (longitude: number, radius: number, rotation: number) => {
  const radians = ((rotation - longitude) * Math.PI) / 180;
  return { x: 240 + radius * Math.cos(radians), y: 240 + radius * Math.sin(radians) };
};

export function chartRelations(chart: ThaiHoroscope) {
  const planets = Object.values(chart.points).filter((point) => point.number !== null);
  const lines: ChartRelation[] = [];
  for (let i = 0; i < planets.length; i++) {
    const from = planets[i],
      relation = chart.relationships.find((row) => row.sign === from.sign);
    if (!relation) continue;
    for (const to of planets.slice(i + 1)) {
      const number = to.number!;
      const kind: ChartRelationKind | null = relation.opposition.includes(number)
        ? 'opposition'
        : relation.squares.flat().includes(number)
          ? 'square'
          : relation.trines.flat().includes(number)
            ? 'trine'
            : relation.sextiles.flat().includes(number)
              ? 'sextile'
              : null;
      if (kind)
        lines.push({
          from,
          to,
          kind,
          color: { opposition: '#e2bc68', square: '#e58bcb', trine: '#78b4eb', sextile: '#a2ce85' }[
            kind
          ],
        });
    }
  }
  return lines;
}
