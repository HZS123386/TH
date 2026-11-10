import { spawn } from 'node:child_process';
import { existsSync } from 'node:fs';
import { python } from './python.mjs';
if (!existsSync(python)) {
  console.error('请先运行 pnpm setup:api');
  process.exit(1);
}
const apiPort = process.env.SABAI_API_PORT || '8000';
const webPort = process.env.SABAI_WEB_PORT || '5173';
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
  spawn(process.execPath, ['scripts/serve-app.mjs'], {
    stdio: 'inherit',
    env: { ...process.env, FATE_APP_PORT: webPort },
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
