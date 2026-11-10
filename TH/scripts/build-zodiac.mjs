import { mkdirSync, readdirSync } from 'node:fs';
import { spawnSync } from 'node:child_process';
import { resolve } from 'node:path';

// Package the supplied artwork for small UI icons; keep source PNGs unchanged.
const illustrated = process.argv.includes('--illustrated');
const source = resolve(illustrated ? 'assets/zodiac/illustrated' : 'assets/zodiac/original');
const output = resolve(illustrated ? 'public/images/zodiac/illustrated' : 'public/images/zodiac');
mkdirSync(output, { recursive: true });
const files = readdirSync(source).filter((name) => name.endsWith('.png'));
if (illustrated && files.length !== 12)
  throw new Error('Expected all twelve zodiac illustrations.');
const sizes = illustrated ? [96, 192, 256, 512] : [96, 192];
for (const file of files) {
  for (const size of sizes) {
    const result = spawnSync(
      'ffmpeg',
      [
        '-hide_banner',
        '-loglevel',
        'error',
        '-y',
        '-i',
        resolve(source, file),
        '-vf',
        `scale=${size}:${size}:flags=lanczos`,
        '-frames:v',
        '1',
        '-c:v',
        'libwebp',
        '-lossless',
        '1',
        '-compression_level',
        '6',
        resolve(output, `${file.slice(0, -4)}-${size}.webp`),
      ],
      { stdio: 'inherit', windowsHide: true },
    );
    if (result.error) throw result.error;
    if (result.status !== 0) throw new Error(`Unable to package ${file} at ${size}px`);
  }
}
console.log(`Packaged ${files.length} zodiac signs at ${sizes.join(', ')}px.`);
