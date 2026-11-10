import { spawn } from 'node:child_process';
import { existsSync } from 'node:fs';
import { homedir } from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

export const projectRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
export const appRoot = path.join(projectRoot, 'app');
const cachedSdk = path.join(homedir(), '.cache', 'fate-sdk', 'flutter', 'bin', 'flutter.bat');
export const flutterBinary = process.env.FATE_FLUTTER_BIN || (process.platform === 'win32' && existsSync(cachedSdk) ? cachedSdk : 'flutter');

export function runFlutter(args) {
  return new Promise((resolve, reject) => {
    // A .bat entry needs a Windows shell; quote each argument independently.
    const quote = (value) => `'${String(value).replaceAll("'", "''")}'`;
    const command = `& ${quote(flutterBinary)} ${args.map(quote).join(' ')}; exit $LASTEXITCODE`;
    const child = process.platform === 'win32'
      ? spawn('powershell.exe', ['-NoProfile', '-NonInteractive', '-Command', command], { cwd: appRoot, stdio: 'inherit', windowsHide: true })
      : spawn(flutterBinary, args, { cwd: appRoot, stdio: 'inherit' });
    child.on('error', reject);
    child.on('exit', (code) => code === 0 ? resolve() : reject(new Error(`Flutter exited with code ${code}`)));
  });
}

export async function buildAppPreview() {
  await runFlutter(['build', 'web', '--release', '--wasm', '--no-web-resources-cdn', '--dart-define=FATE_API_BASE_URL=']);
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const args = process.argv.slice(2);
  try {
    if (args[0] === 'build-preview') await buildAppPreview();
    else await runFlutter(args.length ? args : ['--version']);
  }
  catch (error) { console.error(error.message); process.exitCode = 1; }
}
