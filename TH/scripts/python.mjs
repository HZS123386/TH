import { spawnSync } from 'node:child_process';
import { existsSync } from 'node:fs';
export const python =
  process.platform === 'win32' ? '.venv/Scripts/python.exe' : '.venv/bin/python';
if (process.argv[1]?.endsWith('python.mjs')) {
  if (!existsSync(python)) {
    console.error('请先运行 pnpm setup:api');
    process.exit(1);
  }
  const result = spawnSync(python, process.argv.slice(2), { stdio: 'inherit' });
  process.exit(result.status ?? 1);
}
