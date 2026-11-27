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

for (const scenario of ['refresh-after-accept','refresh-before-delivery','flutter-recovers-first','refresh-with-accepted-history-receipt']) {
  test('continues the original report: ' + scenario, async () => {
    const context = await browser.newContext({viewport:{width:390,height:844},reducedMotion:'reduce'});
    let releaseEngine, releaseResponse;
    const engine = new Promise(resolve => { releaseEngine = resolve; });
    const response = new Promise(resolve => { releaseResponse = resolve; });
    const fixture = JSON.parse(await readFile(new URL('../web-client/test/fixtures/th-preview.json',import.meta.url),'utf8'));
    const posts = [], lookups = [], errors = [], visits = visitCollector();
    let accepted, owner, jobs = 0, showedReport = false;
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
      const page = await context.newPage();
      page.on('pageerror',error => errors.push(error.message));
      page.on('console',line => { if (line.text().includes('"page":"report-content"')) showedReport = true; });
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
        if (path === '/api/life-reports/' + fixture.id) return reply(accepted);
        return reply({recorded:true});
      });
      await page.goto(url + '?topic=career&startup=1&utm_source=example&utm_campaign=handoff',{waitUntil:'domcontentloaded'});
      await selectBirthValue(page,'date','1995-08-17');
      await selectBirthValue(page,'time','09:30');
      await page.locator('#birth-city').click();
      await page.getByRole('option',{name:bangkok.nameThai,exact:false}).click();
      await page.locator('#birth-submit').click();
      await expect(page.locator('#birth-generation')).toBeVisible();
      await expect(page.locator('#birth-generation-video')).not.toHaveAttribute('src',/./);
      await expect.poll(() => posts.length).toBe(1);
      if (scenario === 'flutter-recovers-first') {
        // Trigger the existing watchdog callback while the engine download is stalled.
        await page.evaluate(() => window.fateBoot.fail());
        releaseEngine();
        await page.waitForFunction(() => performance.getEntriesByName('fate-app-ready').length > 0);
        await expect(page.locator('#birth-generation-retry')).toBeHidden();
      } else if (scenario === 'refresh-with-accepted-history-receipt') {
        releaseResponse();
        await page.waitForFunction(id => history.state?.['fate-birth-submission']?.reportId === id,fixture.id);
        await page.reload({waitUntil:'commit'});
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
      if (scenario !== 'refresh-with-accepted-history-receipt') await expect.poll(() => showedReport).toBe(true);
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
      if (scenario === 'flutter-recovers-first') {
        const pixels = await page.evaluate(() => window.fbq.queue.filter(call => call[0] === 'track' && call[1] === 'PageView').length);
        assert.equal(pixels,1,'one Meta PageView queued for this landing document');
      }
      assert.deepEqual(errors,[]);
    } finally { releaseEngine(); releaseResponse(); await context.close(); }
  });
}

test('a new visitor fills the native form with Flutter held, then submits exactly once to the existing report flow', async () => {
  const context = await browser.newContext({viewport:{width:390,height:844},hasTouch:true,reducedMotion:'no-preference'});
  let release, finishReport;
  const gate = new Promise(resolve => { release = resolve; });
  const ready = new Promise(resolve => { finishReport = resolve; });
  try {
    const page = await context.newPage();
    const errors = [], calls = [], directory = [], reads = [], media = [], visits = visitCollector();
    let generated, submittedOwner, submittedVisit, rejectConsent = true;
    let finishCancelled;
    page.on('pageerror',error => errors.push(error.message));
    const fixture = JSON.parse(await readFile(new URL('../web-client/test/fixtures/th-preview.json',import.meta.url),'utf8'));
    const thaiCopy = JSON.parse(await readFile(new URL('../web-client/assets/copy/th.json',import.meta.url),'utf8'));
    await page.route('**/*',async route => {
      const address = new URL(route.request().url()), path = address.pathname;
      if (address.origin !== new URL(url).origin && /^https?:$/.test(address.protocol)) return route.abort();
      if (/report-loading-(?:inline|web)\.mp4$|report-loading-animated\.webp$/.test(path)) media.push(path);
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
        return respond({...generated,preview:null,chart:null,preview_state:'queued'});
      }
      if (path === '/api/life-reports/' + fixture.id) {
        assert.equal(route.request().headers()['x-report-key'],submittedOwner);
        reads.push(address.search);
        if (reads.length === 1) return respond({...generated,preview:null,preview_state:'generating'});
        if (reads.length === 2) return respond({...generated,preview:null,preview_state:'generating',
          preview_generation_progress:{percent:37,
            sections:['preview_summary','preview_strength','preview_decisions','preview_relationships']
              .map(key => ({key,percent:37}))}});
        await ready;
        return respond(generated);
      }
      return respond({recorded:true,accepted:true});
    });
    await page.goto(url + '?topic=career&utm_source=example',{waitUntil:'domcontentloaded'});
    const date = page.locator('#birth-date-trigger'), city = page.locator('#birth-city'), time = page.locator('#birth-time-trigger');
    const cityToggle = page.locator('#birth-city-toggle');
    await expect(date).toBeVisible();
    await expect(page.locator('#birth-question, #birth-custom')).toHaveCount(0);
    assert.deepEqual(media,[]);
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
    await cityToggle.tap();
    await expect(cityToggle).toHaveAttribute('aria-expanded','true');
    await expect(city).not.toBeFocused();
    const firstCity = page.getByRole('option',{name:bangkok.nameThai,exact:false});
    await expect(firstCity).toBeVisible();
    await cityToggle.tap();
    await expect(firstCity).toBeHidden();
    await cityToggle.tap();
    await firstCity.tap();
    await expect(city).toHaveValue(bangkok.nameThai);
    await expect(city).not.toBeFocused();
    await expect(cityToggle).toHaveAttribute('aria-expanded','false');
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
    await page.locator('#birth-submit').click();
    await expect(page.locator('#birth-message')).toHaveText(/\S/);
    assert.equal(generated,undefined);
    rejectConsent = false;
    await page.locator('#birth-submit').click();
    await expect(page.locator('#birth-generation')).toBeVisible();
    await expect(page.locator('#birth-form')).toBeHidden();
    await expect(page.locator('#birth-generation-title')).toHaveText(thaiCopy.generation.th.previewTitle);
    const phoneViewport = page.viewportSize();
    for (const viewport of [phoneViewport, {width:1624,height:805}]) {
      await page.setViewportSize(viewport);
      const {left,right} = await page.locator('.birth-generation-content').evaluate(content => {
        const section = content.parentElement.getBoundingClientRect();
        const bounds = content.getBoundingClientRect();
        return {left:bounds.left - section.left,right:section.right - bounds.right};
      });
      assert.ok(Math.abs(left - right) <= 1, `Generation content is centered at ${viewport.width}px`);
      assert.ok(Math.min(left,right) >= 14, `Generation content has side padding at ${viewport.width}px`);
    }
    await page.setViewportSize(phoneViewport);
    const status = page.locator('#birth-generation-status');
    const meter = page.locator('#birth-generation-progress');
    await expect(meter).toHaveAttribute('aria-valuenow','0');
    await expect(page.locator('#birth-generation-details')).toContainText('09:30');
    await expect(meter).toContainText('✦');
    const video = page.locator('#birth-generation-video');
    await expect.poll(() => video.evaluate(el => el.currentTime)).toBeGreaterThan(0);
    await page.locator('#birth-form').evaluate(form => form.requestSubmit());
    await page.waitForFunction(id => sessionStorage.getItem('active-preview') === id,fixture.id);
    await expect(status).toHaveText(thaiCopy.generation.th.preview);
    assert.equal(await page.evaluate(() => performance.getEntriesByName('fate-app-ready').length),0);
    assert.equal(reads.length,0);
    release();
    await expect(page.locator('#birth-generation-placements')).toBeVisible();
    await expect(page.locator('#birth-generation-planets dt').first()).toBeVisible();
    await expect(meter).toHaveAttribute('aria-valuenow','37');
    await expect(page.locator('#birth-generation-reading')).toBeVisible();
    await expect(status).toHaveText(thaiCopy.jy.th.interpretation.steps.reading.status);
    await expect(page.locator('#birth-generation')).toBeVisible();
    await expect(video).toHaveAttribute('data-playing','');
    finishReport();
    await expect(page).toHaveURL(/report\.html\?id=/,{timeout:60000});
    await expect(video).toHaveCount(0);
    assert.ok(media.length && media.every(path => path.endsWith('/report-loading-inline.mp4')));
    assert.equal(Object.hasOwn(generated.input,'user_question'),false);
    assert.equal(Object.hasOwn(generated.input,'career_question'),false);
    assert.equal(generated.input.report_kind,'fortune');
    assert.equal(generated.input.profile.location_id,bangkok.id);
    assert.equal(generated.input.profile.birth_date,'1995-08-17');
    assert.equal(generated.input.profile.birth_time,'09:30');
    assert.equal(submittedVisit.source,'example');
    await expect.poll(() => reads.some(query => query.includes('wait_preview=true')),{timeout:15000}).toBe(true);
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
    assert.doesNotMatch(JSON.stringify(actions),/1995-08-17|北京|09:30/);
    assert.deepEqual(errors,[]);
  } finally { release(); finishReport(); await context.close(); }
});

test('an interrupted startup keeps the edited form and a manual retry restores it', async () => {
  const context = await browser.newContext({viewport:{width:360,height:640}});
  let release;
  const gate = new Promise(resolve => { release = resolve; });
  let fail = true, finishCreate, created = 0;
  const visits = visitCollector();
  const server = new Promise(resolve => { finishCreate = resolve; });
  try {
    const page = await context.newPage();
    await page.route('**/*',async route => {
      const req = new URL(route.request().url());
      if (req.origin !== new URL(url).origin && /^https?:$/.test(req.protocol)) return route.abort();
      if (req.pathname === '/api/landing/visits') return visits.accept(route);
      if (req.pathname === '/api/thai-locations') return route.fulfill({json:{items:[beijing],total:1}});
      if (req.pathname === '/api/landing/config') return route.fulfill({json:{notice_version:'h5-data-use-3'}});
      if (req.pathname === '/api/landing/consents') return route.fulfill({json:{accepted:true,notice_version:'h5-data-use-3'}});
      if (req.pathname === '/api/life-reports') {
        created++;
        const {landing_visit,...input} = route.request().postDataJSON();
        assert.equal(input.report_kind,'marriage');
        assert.equal(input.profile.birth_time,null);
        assert.equal(input.profile.location_id,beijing.id);
        assert.equal(input.profile.language,'zh');
        await server;
        return route.fulfill({json:{id:'accepted-missing-fields',input}});
      }
      if (req.pathname.startsWith('/api/')) return route.fulfill({json:{recorded:true}});
      if (fail && /\/main\.dart\.(wasm|js)$/.test(req.pathname)) { await gate; return route.abort(); }
      return route.continue();
    });
    await page.goto(url + '?lang=zh',{waitUntil:'domcontentloaded'});
    await selectBirthValue(page,'date','2001-02-03');
    await page.locator('#birth-unknown').check();
    release();
    await expect(page.locator('#birth-retry')).toBeVisible({timeout:15000});
    await expect(page.locator('#birth-date')).toHaveValue('2001-02-03');
    fail = false;
    await Promise.all([page.waitForNavigation(),page.locator('#birth-retry').click()]);
    await expect(page.locator('#birth-date')).toHaveValue('2001-02-03');
    await expect(page.locator('#birth-unknown')).toBeChecked();
    await expect.poll(() => new Set([...visits.events.values()].filter(e => e.page === 'birth_form' && e.action === 'view').map(e => e.page_view_id)).size).toBe(2);
    const restoredEvents = [...visits.events.values()].sort((a,b) => a.sequence - b.sequence);
    const restoredId = restoredEvents.filter(e => e.action === 'view' && e.page === 'birth_form').at(-1).page_view_id;
    assert.deepEqual(restoredEvents.filter(e => e.page_view_id === restoredId && e.kind === 'action' && e.action.startsWith('form_progress')).map(e => e.action),['form_progress_place']);
    assert.equal(await page.evaluate(() => sessionStorage.getItem('fate-birth-reload')),null);
    await expect(page.locator('#fate-birth footer a')).toHaveCount(0);
    await expect(page.locator('#birth-date')).toHaveValue('2001-02-03');
    await page.locator('#birth-city').click();
    await page.getByRole('option',{name:beijing.nameChinese,exact:false}).click();
    await page.locator('#birth-submit').click();
    await expect(page.locator('#birth-generation')).toBeVisible();
    await expect.poll(() => created).toBe(1);
    finishCreate();
    await expect(page.locator('#birth-form')).toBeVisible();
    await expect(page.locator('#birth-message')).toHaveText(/完整/);
    assert.equal(await page.evaluate(() => sessionStorage.getItem('active-preview')),null);
    assert.equal(created,1);
  } finally { release(); finishCreate(); await context.close(); }
});
