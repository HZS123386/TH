/** Landing-page palette and four-point star, shared with exported brand artwork. */
export const brandColors = {
  canvas: '#130c24',
  panel: '#20152f',
  ink: '#fff5df',
  gold: '#e4bc78',
  muted: '#b4a8c6',
} as const;

export const brandSymbolPaths: ReadonlyArray<{
  d: string;
  tone: 'gold' | 'ink';
  fill: 'none' | 'solid' | 'soft';
  width: number;
}> = [
  {
    d: 'M32 6C35.8 23.5 40.5 28.2 58 32C40.5 35.8 35.8 40.5 32 58C28.2 40.5 23.5 35.8 6 32C23.5 28.2 28.2 23.5 32 6Z',
    tone: 'gold',
    fill: 'none',
    width: 2.5,
  },
];

export function brandSvg(ink: string = brandColors.ink, gold: string = brandColors.gold) {
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
    const color = path.tone === 'gold' ? brandColors.gold : brandColors.ink;
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
