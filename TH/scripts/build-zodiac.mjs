import { mkdirSync, readdirSync } from 'node:fs';
import { spawnSync } from 'node:child_process';
import { resolve } from 'node:path';

// Package the supplied artwork for small UI icons; keep source PNGs unchanged.
const source = resolve('assets/zodiac/original');
const output = resolve('public/images/zodiac');
mkdirSync(output, { recursive: true });
for (const file of readdirSync(source).filter((name) => name.endsWith('.png'))) {
  for (const size of [96, 192]) {
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
console.log('Packaged twelve zodiac signs at 96px and 192px.');
