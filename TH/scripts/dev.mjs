import { spawn } from 'node:child_process';
import { existsSync } from 'node:fs';
import path from 'node:path';
import { loadEnvFile } from 'node:process';
import { fileURLToPath } from 'node:url';
import { python } from './python.mjs';
// Resolve the existing services from their source directory, even when launched at the repository root.
process.chdir(fileURLToPath(new URL('../', import.meta.url)));
if (existsSync('.env')) loadEnvFile('.env');
if (!existsSync(python)) {
  console.error('请先运行 pnpm setup:api');
  process.exit(1);
}
const apiPort = process.env.SABAI_API_PORT || '8000';
const webPort = process.env.SABAI_WEB_PORT || process.env.FATE_APP_PORT || '5174';
const skipBuild = process.argv.includes('--skip-build') ? ['--skip-build'] : [];
const landingRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../../western-astrology-h5 4');
const upstream = `http://127.0.0.1:${apiPort}`;
const children = [
  spawn(
    python,
    [
      '-m',
      'uvicorn',
      'backend.app.main:create_app',
      '--factory',
      '--host',
      '127.0.0.1',
      '--port',
      apiPort,
      ...(process.env.SABAI_NO_RELOAD === '1' ? [] : ['--reload', '--reload-dir', 'backend']),
    ],
    { stdio: 'inherit' },
  ),
  spawn(process.execPath, ['scripts/serve-app.mjs', ...skipBuild], {
    stdio: 'inherit',
    env: { ...process.env, FATE_APP_PORT: webPort, FATE_API_UPSTREAM: upstream },
  }),
  spawn(process.execPath, ['scripts/serve-flutter.mjs', ...skipBuild], {
    cwd: landingRoot,
    stdio: 'inherit',
    env: { ...process.env, FATE_API_UPSTREAM: upstream },
  }),
];
let closing = false;
function close(code = 0) {
  if (closing) return;
  closing = true;
  for (const child of children) {
    if (process.platform === 'win32' && child.pid)
      spawn('taskkill', ['/pid', String(child.pid), '/t', '/f'], {
        stdio: 'ignore',
        windowsHide: true,
      });
    else child.kill('SIGTERM');
  }
  process.exitCode = code;
}
for (const child of children) {
  child.on('error', (error) => {
    console.error(error.message);
    close(1);
  });
  child.on('exit', (code) => close(code ?? 0));
}
process.on('SIGINT', () => close());
process.on('SIGTERM', () => close());
