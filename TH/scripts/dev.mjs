import { spawn, spawnSync } from 'node:child_process';
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
if (!/^postgres(?:ql)?:\/\//.test(process.env.DATABASE_URL || '')) {
  console.error('请在 TH/.env 中配置 FATE 的 PostgreSQL DATABASE_URL');
  process.exit(1);
}
const postgresContainer = process.env.FATE_POSTGRES_CONTAINER;
if (postgresContainer) {
  if (!/^[A-Za-z0-9][A-Za-z0-9_.-]*$/.test(postgresContainer)) {
    console.error('FATE_POSTGRES_CONTAINER 不是有效的 Docker 容器名');
    process.exit(1);
  }
  const started = spawnSync('docker', ['start', postgresContainer], { stdio: ['ignore', 'ignore', 'inherit'], windowsHide: true });
  if (started.status !== 0) {
    console.error('无法启动 FATE 的 PostgreSQL 容器，请检查 Docker 服务');
    process.exit(1);
  }
  let ready = false;
  for (let attempt = 0; attempt < 20 && !ready; attempt++) {
    ready = spawnSync('docker', ['exec', postgresContainer, 'pg_isready', '-q'], { stdio: 'ignore', windowsHide: true }).status === 0;
    if (!ready) await new Promise(resolve => setTimeout(resolve, 300));
  }
  if (!ready) {
    console.error('FATE 的 PostgreSQL 尚未就绪');
    process.exit(1);
  }
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
