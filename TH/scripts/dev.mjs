import { spawn } from 'node:child_process';
import { existsSync } from 'node:fs';
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
const webPort = process.env.SABAI_WEB_PORT || process.env.FATE_APP_PORT || '5176';
const previewArgs = process.argv.includes('--skip-build') ? ['--skip-build'] : [];
const previewEnv = { ...process.env, FATE_API_UPSTREAM: `http://127.0.0.1:${apiPort}` };
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
  spawn(process.execPath, ['scripts/serve-app.mjs', ...previewArgs], {
    stdio: 'inherit',
    env: { ...previewEnv, FATE_APP_PORT: webPort },
  }),
  spawn(process.execPath, ['scripts/serve-flutter.mjs', ...previewArgs], {
    cwd: fileURLToPath(new URL('../../western-astrology-h5 4/', import.meta.url)),
    stdio: 'inherit',
    env: previewEnv,
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
