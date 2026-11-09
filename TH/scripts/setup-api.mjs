import { spawnSync } from 'node:child_process';
import { existsSync } from 'node:fs';
import { python } from './python.mjs';
function run(command, args) {
  const result = spawnSync(command, args, { stdio: 'inherit' });
  if (result.status !== 0) process.exit(result.status ?? 1);
}
if (!existsSync(python)) {
  run(
    process.platform === 'win32' ? 'py' : 'python3.12',
    process.platform === 'win32' ? ['-3.12', '-m', 'venv', '.venv'] : ['-m', 'venv', '.venv'],
  );
}
run(python, ['-m', 'pip', 'install', '-r', 'backend/requirements.txt']);
