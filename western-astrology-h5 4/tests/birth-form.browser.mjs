import assert from 'node:assert/strict';
import { spawn } from 'node:child_process';
import { once } from 'node:events';
import { readFile } from 'node:fs/promises';
import { createRequire } from 'node:module';
import { createServer } from 'node:net';
import { fileURLToPath } from 'node:url';
import { after, before, test } from 'node:test';

const { chromium, expect } = createRequire(new URL('../../TH/package.json',import.meta.url))('@playwright/test');
const project = fileURLToPath(new URL('../',import.meta.url));
let browser, preview, url;
before(async () => {
  const socket = createServer();
  socket.listen(0,'127.0.0.1');
  await once(socket,'listening');
  const port = socket.address().port;
  await new Promise(resolve => socket.close(resolve));
  preview = spawn(process.execPath,['scripts/serve-flutter.mjs','--skip-build'],{cwd:project,windowsHide:true,
    env:{...process.env,FATE_H5_PORT:String(port),FATE_API_UPSTREAM:'http://127.0.0.1:1'}});
  await once(preview.stdout,'data');
  url = 'http://127.0.0.1:' + port + '/thai-landing/';
  browser = await chromium.launch({channel:process.env.PLAYWRIGHT_CHANNEL || (process.platform === 'win32' ? 'chrome' : 'chromium')});
});
after(async () => { try { await browser?.close(); } finally { preview?.kill(); } });

const bangkok = {id:'geonames:1609350',nameThai:'กรุงเทพมหานคร',nameEnglish:'Bangkok',countryCode:'TH',timeZone:'Asia/Bangkok'};
const beijing = {id:'geonames:1816670',nameChinese:'北京市',nameEnglish:'Beijing',countryCode:'CN',timeZone:'Asia/Shanghai'};

async function scrollBirthWheel(wheel, value) {
  await wheel.evaluate((rail, number) => {
    const row = rail.querySelector('.birth-wheel-item').getBoundingClientRect().height;
    rail.scrollTop = (number - Number(rail.getAttribute('aria-valuemin'))) * row;
  },value);
  await expect(wheel).toHaveAttribute('aria-valuenow',String(value));
}

async function selectBirthValue(page, field, value) {
  await page.locator('#birth-' + field + '-trigger').click();
  const wheels = page.locator('#birth-picker').getByRole('spinbutton');
  const parts = value.split(/[-:]/).map(Number);
  for (const [index, part] of parts.entries()) await scrollBirthWheel(wheels.nth(index),part);
  await page.locator('#birth-picker-confirm').click();
  await expect(page.locator('#birth-' + field)).toHaveValue(value);
}

test('date and time wheels highlight the selection and commit only valid values', async () => {
  const context = await browser.newContext({viewport:{width:390,height:844},hasTouch:true});
  try {
    const page = await context.newPage();
    await context.route('**/api/**',route => route.fulfill({json:{items:[],total:0}}));
    await page.goto(url + '?lang=zh',{waitUntil:'domcontentloaded'});
    const date = page.locator('#birth-date-trigger'), time = page.locator('#birth-time-trigger');
    const dialog = page.getByRole('dialog', {name:'出生日期'});
    await date.click();
    await expect(dialog.locator('[data-selected]')).toHaveText(['1990年','7月','15日']);
    const day = dialog.getByRole('spinbutton',{name:'日',exact:true});
    await day.hover();
    const row = await day.locator('.birth-wheel-item').first().evaluate(item => item.getBoundingClientRect().height);
    await page.mouse.wheel(0,row);
    await expect(day).toHaveAttribute('aria-valuenow','16');
    await page.locator('#birth-picker-close').click();
    await expect(page.locator('#birth-date')).toHaveValue('');

    await date.click();
    const year = dialog.getByRole('spinbutton',{name:'年',exact:true});
    await scrollBirthWheel(year,2000);
    await scrollBirthWheel(dialog.getByRole('spinbutton',{name:'月',exact:true}),2);
    await scrollBirthWheel(day,29);
    await scrollBirthWheel(year,2001);
    await expect(day).toHaveAttribute('aria-valuenow','28');
    await page.locator('#birth-picker-confirm').click();
    await expect(date).toContainText('2001年2月28日');

    await time.click();
    await expect(page.getByRole('dialog',{name:'出生时间'}).locator('[data-selected]')).toHaveText(['07','15']);
    const minute = page.locator('#birth-picker').getByRole('spinbutton',{name:'分钟',exact:true});
    await minute.press('Home');
    await minute.press('ArrowUp');
    await page.locator('#birth-picker-confirm').click();
    await expect(time).toContainText('07:01');
    await page.locator('#birth-unknown').check();
    await expect(time).toBeDisabled();
  } finally { await context.close(); }
});

// Mirror the visit API's acknowledgement and (visit, sequence) uniqueness on retries.
function visitCollector() {
  const events = new Map();
  return {
    events,
    async accept(route) {
      const {id,source,campaign,events:batch = []} = route.request().postDataJSON();
      for (const event of batch) events.set(id + ':' + event.sequence,{id,source,campaign,...event});
      await route.fulfill({json:{ok:true,accepted_sequences:batch.map(event => event.sequence)}}).catch(() => {});
    }
  };
}

for (const scenario of ['refresh-after-accept','refresh-before-delivery','refresh-with-accepted-history-receipt']) {
  test('continues the original report: ' + scenario, async () => {
    const context = await browser.newContext({viewport:{width:390,height:844},reducedMotion:'reduce'});
    let releaseEngine, releaseResponse;
    const engine = new Promise(resolve => { releaseEngine = resolve; });
    const response = new Promise(resolve => { releaseResponse = resolve; });
    const fixture = JSON.parse(await readFile(new URL('../web-client/test/fixtures/th-preview.json',import.meta.url),'utf8'));
    const posts = [], lookups = [], errors = [], visits = visitCollector();
    let accepted, owner, jobs = 0;
    try {
      if (['refresh-before-delivery','refresh-with-accepted-history-receipt'].includes(scenario)) {
        await context.addInitScript(() => {
          const write = Storage.prototype.setItem;
          Storage.prototype.setItem = function(key,value) {
            if (this === sessionStorage && ['fate-birth-submission','active-preview'].includes(key)) throw Error('storage disabled');
            return write.call(this,key,value);
          };
        });
      }
      if (scenario === 'refresh-with-accepted-history-receipt') {
        await context.addInitScript(() => {
          const replace = history.replaceState.bind(history);
          history.replaceState = (state,title,target) => {
            const receipt = history.state?.['fate-birth-submission']?.reportId;
            if (receipt && target && new URL(target,location.href).pathname.endsWith('/report.html') &&
                !sessionStorage.getItem('test-reloaded-accepted-receipt')) {
              // Reload the form once after acceptance but before the report URL is set.
              sessionStorage.setItem('test-reloaded-accepted-receipt',receipt);
              return;
            }
            return replace(state,title,target);
          };
        });
      }
      const page = await context.newPage();
      page.on('pageerror',error => errors.push(error.message));
      await context.route('**/*',async route => {
        const request = route.request(), address = new URL(request.url()), path = address.pathname;
        if (address.origin !== new URL(url).origin && /^https?:$/.test(address.protocol)) return route.abort();
        if (/\/main\.dart\.(wasm|js)$/.test(path)) await engine;
        if (!path.startsWith('/api/')) return route.continue().catch(() => {});
        const reply = json => route.fulfill({json});
        if (path === '/api/landing/visits') return visits.accept(route);
        if (path === '/api/thai-locations') return reply({items:[bangkok],total:1});
        if (path === '/api/landing/config') return reply({notice_version:'h5-data-use-3'});
        if (path === '/api/landing/consents') return reply({accepted:true,notice_version:'h5-data-use-3'});
        if (path.startsWith('/api/life-reports/submissions/')) {
          lookups.push(path.split('/').pop());
          assert.equal(request.headers()['x-report-key'],owner);
          return accepted ? reply(accepted) : route.fulfill({status:404,json:{code:'life_submission_not_found'}});
        }
        if (path === '/api/life-reports') {
          const id = request.headers()['idempotency-key'];
          assert.match(id,/^[0-9a-f-]{36}$/);
          posts.push(id);
          const first = posts.length === 1;
          if (first) owner = request.headers()['x-report-key'];
          assert.equal(request.headers()['x-report-key'],owner);
          if (first && scenario === 'refresh-before-delivery') {
            await response;
            return route.abort().catch(() => {});
          }
          const {landing_visit,...input} = request.postDataJSON();
          assert.equal(input.profile.birth_date,'1995-08-17');
          jobs++;
          accepted = {...fixture,input};
          if (first) await response;
          return reply(accepted).catch(() => {});
        }
        if (path === '/api/life-reports/' + fixture.id) {
          assert.equal(request.headers()['x-report-key'],owner);
          return reply(accepted);
        }
        return reply({recorded:true});
      });
      await page.goto(url + '?topic=career&startup=1&utm_source=example&utm_campaign=handoff',{waitUntil:'domcontentloaded'});
      await selectBirthValue(page,'date','1995-08-17');
      await selectBirthValue(page,'time','09:30');
      await page.locator('#birth-city').click();
      await page.getByRole('option',{name:bangkok.nameThai,exact:false}).click();
      await page.locator('#birth-submit').click();
      await expect(page.locator('#birth-generation')).toBeVisible();
      await expect(page.locator('#birth-form')).toBeHidden();
      await expect.poll(() => posts.length).toBe(1);
      if (scenario === 'refresh-with-accepted-history-receipt') {
        releaseResponse();
        await page.waitForFunction(id => sessionStorage.getItem('test-reloaded-accepted-receipt') === id &&
          window.fateBoot?.openingReportId === id,fixture.id);
        releaseEngine();
      } else {
        await page.reload({waitUntil:'domcontentloaded'});
        await expect.poll(() => lookups.length).toBe(1);
        assert.equal(lookups[0],posts[0]);
        await expect.poll(() => jobs).toBe(1);
        releaseEngine();
      }
      releaseResponse();
      await expect(page).toHaveURL(new RegExp('report\\.html\\?id=' + fixture.id),{timeout:30000});
      assert.equal(jobs,1);
      assert.equal(posts.length,scenario === 'refresh-before-delivery' ? 2 : 1);
      assert.equal(new Set(posts).size,1);
      assert.equal(await page.evaluate(() => sessionStorage.getItem('fate-birth-submission')),null);
      const actions = () => [...visits.events.values()].filter(event => event.kind === 'action');
      await expect.poll(() => actions().some(event => event.action === 'report_ready')).toBe(true);
      assert.equal(new Set(actions().map(event => event.id)).size,1,'one attributed visit');
      assert.equal(actions().filter(event => event.page === 'birth_form' && event.action === 'view').length,1);
      for (const action of ['form_progress_empty','click_generate_report','consent_accept','generate','report_ready']) {
        assert.equal(actions().filter(event => event.action === action).length,1,action);
      }
      assert.ok(actions().every(event => event.source === 'example' && event.campaign === 'handoff'));
      assert.ok(actions().some(event => event.page === 'generating_preview' && event.action === 'view'));
      assert.deepEqual(errors,[]);
    } finally { releaseEngine(); releaseResponse(); await context.close(); }
  });
}

test('a new visitor fills the native form with Flutter held, then submits exactly once to the existing report flow', async () => {
  const context = await browser.newContext({viewport:{width:390,height:844},reducedMotion:'no-preference'});
  let release, releasePost, releasePreview;
  const gate = new Promise(resolve => { release = resolve; });
  const postGate = new Promise(resolve => { releasePost = resolve; });
  const previewGate = new Promise(resolve => { releasePreview = resolve; });
  try {
    const page = await context.newPage();
    const errors = [], calls = [], directory = [], reads = [], visits = visitCollector();
    let generated, submittedOwner, submittedVisit, rejectConsent = true;
    let finishCancelled;
    page.on('pageerror',error => errors.push(error.message));
    const fixture = JSON.parse(await readFile(new URL('../web-client/test/fixtures/th-preview.json',import.meta.url),'utf8'));
    const thaiCopy = JSON.parse(await readFile(new URL('../web-client/assets/copy/th.json',import.meta.url),'utf8'));
    await page.route('**/*',async route => {
      const address = new URL(route.request().url()), path = address.pathname;
      if (address.origin !== new URL(url).origin && /^https?:$/.test(address.protocol)) return route.abort();
      if (path.endsWith('/main.dart.wasm') || path.endsWith('/main.dart.js')) await gate;
      if (!path.startsWith('/api/')) return route.continue();
      calls.push(route.request().method() + ' ' + path);
      const respond = json => route.fulfill({json});
      if (path === '/api/landing/visits') return visits.accept(route);
      if (path === '/api/thai-locations') {
        directory.push(Object.fromEntries(address.searchParams));
        assert.equal(route.request().headers()['x-report-key'],undefined);
        const query = address.searchParams.get('query');
        if (query === 'cancel-me') {
          await new Promise(resolve => { finishCancelled = resolve; });
          return route.abort('aborted').catch(() => {});
        }
        if (query === 'offline') return route.abort('failed');
        if (query === 'bad-json') return route.fulfill({contentType:'application/json',body:'{'});
        if (query === 'bad-shape') return respond({items:null});
        if (query === 'server-error') return route.fulfill({status:503,json:{detail:'unavailable'}});
        const item = address.searchParams.get('country') === 'CN' ? beijing : bangkok;
        return respond({items:[item],total:1});
      }
      if (path === '/api/landing/config') return respond({notice_version:'h5-data-use-3'});
      if (path === '/api/landing/consents') {
        assert.deepEqual(route.request().postDataJSON(),{notice_version:'h5-data-use-3',granted:true});
        submittedOwner = route.request().headers()['x-report-key'];
        return respond({accepted:!rejectConsent,notice_version:'h5-data-use-3'});
      }
      if (path === '/api/life-reports' && route.request().method() === 'POST') {
        const {landing_visit,...input} = route.request().postDataJSON();
        assert.equal(address.searchParams.get('wait'),'false');
        assert.ok(submittedOwner && route.request().headers()['x-report-key'] === submittedOwner);
        submittedVisit = landing_visit;
        generated = {...fixture,input};
        await postGate;
        return respond({...generated,preview:null,chart:null,preview_state:'queued'});
      }
      if (path === '/api/life-reports/' + fixture.id) {
        assert.equal(route.request().headers()['x-report-key'],submittedOwner);
        reads.push(address.search);
        if (reads.length === 1) return respond({...generated,preview:null,chart:null,preview_state:'generating'});
        await previewGate;
        return respond(generated);
      }
      return respond({recorded:true,accepted:true});
    });
    await page.goto(url + '?topic=career&utm_source=example',{waitUntil:'domcontentloaded'});
    const date = page.locator('#birth-date-trigger'), city = page.locator('#birth-city'), time = page.locator('#birth-time-trigger');
    await expect(date).toBeVisible();
    await expect(page.locator('#fate-flutter')).toBeHidden();
    const language = page.locator('#birth-language');
    assert.equal(await language.locator('option').count(),9);
    for (const lang of ['zh','vi','my','km','lo','ms','id','en','th']) {
      await language.selectOption(lang);
      await expect(page.locator('#birth-form h2')).toHaveText(/\S/);
      assert.equal(new URL(page.url()).searchParams.get('utm_source'),'example');
    }
    await page.locator('#birth-submit').click();
    await expect(date).toBeFocused();
    await selectBirthValue(page,'date','1995-08-17');
    await page.locator('#birth-unknown').check();
    await expect(time).toBeDisabled();
    await city.click();
    await page.getByRole('option',{name:bangkok.nameThai,exact:false}).click();
    await language.selectOption('zh');
    await expect(date).toContainText('1995年8月17日');
    await expect(city).toHaveValue('');
    await city.fill('cancel-me');
    await expect.poll(() => typeof finishCancelled).toBe('function');
    for (const query of ['offline','bad-json','bad-shape','server-error']) {
      await city.fill(query);
      if (query === 'offline') finishCancelled();
      await expect(page.locator('#birth-options button[data-next]')).toBeVisible();
    }
    await city.fill('北京');
    await page.getByRole('option',{name:'北京市',exact:false}).click();
    assert.ok(directory.some(item => item.country === 'CN' && item.level === 'locality' && item.query === '北京'));
    await expect(page.locator('.birth-board')).toHaveCount(2);
    await expect(page.locator('.birth-board li')).toHaveCount(6);
    await language.selectOption('th');
    await page.locator('#birth-unknown').uncheck();
    await selectBirthValue(page,'time','09:30');
    await city.click();
    await page.getByRole('option',{name:bangkok.nameThai,exact:false}).click();
    await page.locator('#birth-question').selectOption('custom');
    await page.locator('#birth-custom').fill('My career question');
    await page.locator('#birth-submit').click();
    await expect(page.locator('#birth-message')).toHaveText(/\S/);
    assert.equal(generated,undefined);
    rejectConsent = false;
    await page.locator('#birth-submit').click();
    await expect(page.locator('#birth-generation')).toBeVisible();
    await expect(page.locator('#birth-generation-title')).toHaveText(thaiCopy.generation.th.previewTitle);
    await expect(page.locator('#birth-form')).toBeHidden();
    await page.locator('#birth-form').evaluate(form => form.requestSubmit());
    releasePost();
    await page.waitForFunction(id => sessionStorage.getItem('active-preview') === id,fixture.id);
    await expect(page).toHaveURL(/report\.html\?id=/,{timeout:60000});
    await page.waitForFunction(id => window.fateBoot?.openingReportId === id,fixture.id);
    await expect(page.locator('#fate-startup')).toBeVisible();
    assert.equal(await page.evaluate(() => performance.getEntriesByName('fate-app-ready').length),0);
    assert.equal(reads.length,0);
    release();
    await expect(page).toHaveURL(/report\.html\?id=/,{timeout:60000});
    assert.equal(generated.input.user_question,'My career question');
    assert.equal(generated.input.report_kind,'fortune');
    assert.equal(generated.input.profile.location_id,bangkok.id);
    assert.equal(generated.input.profile.birth_date,'1995-08-17');
    assert.equal(generated.input.profile.birth_time,'09:30');
    assert.equal(submittedVisit.source,'example');
    await expect.poll(() => reads.some(query => query.includes('wait_preview=true')),{timeout:15000}).toBe(true);
    const reportAnimation = page.locator('video[src$="report-loading-web.mp4"]:visible, img[src*="report-loading-animated.webp"]:visible');
    await expect(reportAnimation).toHaveCount(1,{timeout:10000});
    releasePreview();
    assert.equal(calls.filter(call => call === 'POST /api/life-reports').length,1);
    const accepted = calls.indexOf('POST /api/landing/consents');
    assert.ok(accepted >= 0 && accepted < calls.indexOf('POST /api/life-reports'));
    await expect(page.locator('#fate-birth')).toBeHidden();
    await expect(page.locator('#fate-flutter')).toBeVisible();
    await expect.poll(() => [...visits.events.values()].filter(e => e.action === 'request_failed' && e.kind === 'action').length).toBe(3);
    const failures = [...visits.events.values()].filter(e => e.action === 'request_failed' && e.kind === 'action');
    assert.deepEqual(failures.map(e => [e.page,e.failure_path,e.failure_code]).sort(),[
      ['birth_form','/api/thai-locations','badResult'],['birth_form','/api/thai-locations','badResult'],
      ['birth_form','/api/thai-locations','network'],
    ]);
    await expect.poll(() => [...visits.events.values()].some(e => e.kind === 'action' && e.action === 'report_ready')).toBe(true);
    const actions = [...visits.events.values()].filter(e => e.kind === 'action');
    assert.equal(actions.filter(e => e.action === 'click_generate_report').length,3);
    assert.equal(actions.filter(e => e.action === 'invalid_form').length,1);
    assert.equal(actions.filter(e => e.action === 'generate').length,1);
    assert.equal(actions.filter(e => e.action === 'report_ready').length,1);
    assert.ok(actions.every(e => e.id === submittedVisit.id));
    assert.doesNotMatch(JSON.stringify(actions),/1995-08-17|My career question|北京|09:30/);
    assert.deepEqual(errors,[]);
  } finally { release(); releasePost(); releasePreview(); await context.close(); }
});

test('Instagram Android uses only the low-memory report animation', async () => {
  const context = await browser.newContext({
    viewport:{width:412,height:824},hasTouch:true,isMobile:true,
    userAgent:'Mozilla/5.0 (Linux; Android 16; PLR110; wv) AppleWebKit/537.36 Version/4.0 Chrome/139.0.0.0 Mobile Safari/537.36 Instagram 417.0.0.54.77 Android'
  });
  const fixture = JSON.parse(await readFile(new URL('../web-client/test/fixtures/th-preview.json',import.meta.url),'utf8'));
  const generating = {...fixture,preview:null,chart:null,preview_state:'generating'};
  const errors = [];
  try {
    const page = await context.newPage();
    page.on('pageerror',error => errors.push(error.message));
    await page.route('**/*',async route => {
      const address = new URL(route.request().url());
      if (address.origin !== new URL(url).origin && /^https?:$/.test(address.protocol)) return route.abort();
      if (!address.pathname.startsWith('/api/')) return route.continue();
      if (address.pathname === '/api/landing/visits') {
        const events = route.request().postDataJSON()?.events || [];
        return route.fulfill({json:{ok:true,accepted_sequences:events.map(event => event.sequence)}});
      }
      if (address.pathname === '/api/life-reports/' + fixture.id) return route.fulfill({json:generating});
      return route.fulfill({json:{recorded:true}});
    });
    await page.goto(url + 'report.html?id=' + fixture.id + '&lang=th',{waitUntil:'domcontentloaded'});
    await expect(page.locator('.fate-generation-lite:visible')).toHaveCount(1,{timeout:30000});
    await expect(page.locator('video[src$="report-loading-web.mp4"]')).toHaveCount(0);
    await expect(page.locator('img[src*="report-loading-animated.webp"]')).toHaveCount(0);
    assert.equal(await page.locator('.fate-generation-lite').evaluate(element => getComputedStyle(element).animationName),'fate-generation-lite');
    assert.deepEqual(errors,[]);
  } finally {
    await context.close();
  }
});
