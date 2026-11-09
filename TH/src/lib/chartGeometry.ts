import type { ThaiHoroscope } from 'thai-astrology';

export type ChartRelationKind = 'opposition' | 'square' | 'trine' | 'sextile';
export interface ChartRelation {
  from: ThaiHoroscope['points']['sun'];
  to: ThaiHoroscope['points']['sun'];
  kind: ChartRelationKind;
  color: string;
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
          color: { opposition: '#bc9a52', square: '#bb6f9a', trine: '#638fbd', sextile: '#638fbd' }[
            kind
          ],
        });
    }
  }
  return lines;
}
