import {spawn} from 'node:child_process';

for (const browser of ['chromium','firefox','webkit']) {
  console.log(`\nTesting ${browser}...`);
  const nativeArgs = browser === 'webkit'
    ? ['--test-name-pattern=native landing form creates|Safari desktop|iOS Safari',
        'tests/native-landing.browser.mjs']
    : ['tests/native-landing.browser.mjs'];
  const runs = browser === 'chromium'
    ? [['tests/native-landing.browser.mjs','tests/birth-form.browser.mjs']]
    : [
        nativeArgs,
        ['--test-name-pattern=desktop handoff removes both legacy loaders',
          'tests/birth-form.browser.mjs'],
      ];
  for (const args of runs) {
    const child = spawn(process.execPath,['--test',...args],{
      cwd: new URL('../',import.meta.url),
      env: {...process.env,PLAYWRIGHT_BROWSER:browser},
      stdio:'inherit',
    });
    const code = await new Promise((resolve,reject) => {
      child.once('error',reject);
      child.once('exit',resolve);
    });
    if (code !== 0) process.exit(code ?? 1);
  }
}
