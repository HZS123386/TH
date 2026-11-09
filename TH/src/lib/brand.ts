/** Original lotus/star artwork shared by the app, favicon and exported card. */
export const brandSymbolPaths = [
  {
    d: 'M11 27A23 23 0 0 1 24 11M40 11A23 23 0 0 1 53 27',
    tone: 'gold',
    fill: 'none',
    width: 1.25,
  },
  {
    d: 'M32 5l1.7 4.8 5.1 1.7-5.1 1.7L32 18l-1.7-4.8-5.1-1.7 5.1-1.7Z',
    tone: 'gold',
    fill: 'solid',
    width: 1,
  },
  { d: 'M32 49C18 53 7 45 6 35c12-1 20 4 26 14Z', tone: 'ink', fill: 'soft', width: 1.65 },
  { d: 'M32 49c14 4 25-4 26-14-12-1-20 4-26 14Z', tone: 'ink', fill: 'soft', width: 1.65 },
  { d: 'M32 48C18 47 12 37 13 27c11 1 18 9 19 21Z', tone: 'ink', fill: 'none', width: 1.65 },
  { d: 'M32 48c14-1 20-11 19-21-11 1-18 9-19 21Z', tone: 'ink', fill: 'none', width: 1.65 },
  { d: 'M32 48C20 40 22 29 32 21c10 8 12 19 0 27Z', tone: 'ink', fill: 'soft', width: 1.65 },
  { d: 'M17 55q15 8 30 0M24 60h16', tone: 'gold', fill: 'none', width: 1.6 },
] as const;

export function brandSvg(ink = '#8d3a31', gold = '#ad8848') {
  return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" fill="none" stroke-linecap="round" stroke-linejoin="round">${brandSymbolPaths
    .map((path) => {
      const color = path.tone === 'gold' ? gold : ink;
      return `<path d="${path.d}" stroke="${color}" stroke-width="${path.width}" fill="${path.fill === 'none' ? 'none' : color}"${path.fill === 'soft' ? ' fill-opacity=".045"' : ''}/>`;
    })
    .join('')}</svg>`;
}

export function drawBrandMark(ctx: CanvasRenderingContext2D, x: number, y: number, size: number) {
  ctx.save();
  ctx.translate(x, y);
  ctx.scale(size / 64, size / 64);
  ctx.lineCap = 'round';
  ctx.lineJoin = 'round';
  for (const path of brandSymbolPaths) {
    const shape = new Path2D(path.d);
    const color = path.tone === 'gold' ? '#ad8848' : '#8d3a31';
    if (path.fill !== 'none') {
      ctx.globalAlpha = path.fill === 'soft' ? 0.045 : 1;
      ctx.fillStyle = color;
      ctx.fill(shape);
    }
    ctx.globalAlpha = 1;
    ctx.lineWidth = path.width;
    ctx.strokeStyle = color;
    ctx.stroke(shape);
  }
  ctx.restore();
}
