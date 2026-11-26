import assert from 'node:assert/strict';
import { createServer } from 'node:http';
import { once } from 'node:events';
import { readFile } from 'node:fs/promises';
import { createRequire } from 'node:module';
import { after, before, test } from 'node:test';

const { chromium, expect } = createRequire(new URL('../../TH/package.json',import.meta.url))('@playwright/test');
const web = new URL('../web-client/web/',import.meta.url);
const assets = new URL('../web-client/assets/',import.meta.url);
let browser, server, url, index;

before(async () => {
  index = (await readFile(new URL('index.html',web),'utf8'))
    .replace('$FLUTTER_BASE_HREF','/thai-landing/')
    .replace('{{flutter_bootstrap_js}}','');
  server = createServer(async (request,response) => {
    const address = new URL(request.url,'http://127.0.0.1');
    if (address.pathname === '/thai-landing/' || address.pathname === '/thai-landing/index.html') {
      response.writeHead(200,{'Content-Type':'text/html; charset=utf-8'}).end(index);
      return;
    }
    if (address.pathname === '/thai-landing/report.html') {
      response.writeHead(200,{'Content-Type':'text/html; charset=utf-8'}).end('<!doctype html><title>Accepted report</title><p id="accepted-report">Accepted report</p>');
      return;
    }
    const source = new Map([
      ['/thai-landing/browser.js',new URL('browser.js',web)],
      ['/thai-landing/birth-form.js',new URL('birth-form.js',web)],
      ['/thai-landing/birth-form.css',new URL('birth-form.css',web)],
    ]).get(address.pathname);
    const copy = /^\/thai-landing\/assets\/assets\/copy\/([a-z]{2})\.json$/.exec(address.pathname);
    try {
      const body = await readFile(source || (copy && new URL('copy/' + copy[1] + '.json',assets)));
      const type = address.pathname.endsWith('.css') ? 'text/css' : address.pathname.endsWith('.json') ? 'application/json' : 'text/javascript';
      response.writeHead(200,{'Content-Type':type}).end(body);
    } catch {
      response.writeHead(404).end();
    }
  });
  server.listen(0,'127.0.0.1');
  await once(server,'listening');
  url = `http://127.0.0.1:${server.address().port}/thai-landing/`;
  browser = await chromium.launch({channel:process.env.PLAYWRIGHT_CHANNEL || (process.platform === 'win32' ? 'chrome' : 'chromium')});
});

after(async () => { try { await browser?.close(); } finally { await new Promise(resolve => server?.close(resolve)); } });

test('the native landing form creates a report without loading or waiting for Flutter', async () => {
  const context = await browser.newContext({viewport:{width:390,height:844},reducedMotion:'reduce'});
  const requests = [], posts = [];
  try {
    const page = await context.newPage();
    const errors = [];
    page.on('pageerror',error => errors.push(error.message));
    await page.route('**/*',async route => {
      const request = route.request(), address = new URL(request.url());
      if (address.origin !== new URL(url).origin) return route.abort();
      requests.push(address.pathname);
      if (!address.pathname.startsWith('/api/')) return route.continue();
      const reply = json => route.fulfill({json});
      if (address.pathname === '/api/landing/visits') {
        const body = request.postDataJSON();
        return reply({ok:true,accepted_sequences:(body.events || []).map(event => event.sequence)});
      }
      if (address.pathname === '/api/thai-locations') return reply({items:[{
        id:'geonames:1816670',nameChinese:'北京市',nameEnglish:'Beijing',countryCode:'CN',timeZone:'Asia/Shanghai'
      }],total:1});
      if (address.pathname === '/api/landing/config') return reply({notice_version:'h5-data-use-3'});
      if (address.pathname === '/api/landing/consents') return reply({accepted:true,notice_version:'h5-data-use-3'});
      if (address.pathname === '/api/life-reports') {
        posts.push({headers:request.headers(),body:request.postDataJSON(),search:address.search});
        return reply({id:'native-accepted-report',preview_state:'queued'});
      }
      return reply({ok:true});
    });

    await page.goto(url + '?lang=zh',{waitUntil:'domcontentloaded'});
    await expect(page.locator('#birth-form')).toBeVisible();
    await expect(page.locator('#fate-flutter')).toBeHidden();
    assert.equal(await page.locator('#birth-submit').evaluate(button => getComputedStyle(button,'::before').animationName),'none');
    assert.equal(requests.some(path => /main\.dart|skwasm|canvaskit/.test(path)),false);

    await page.locator('#birth-date-trigger').click();
    await page.locator('#birth-picker-confirm').click();
    await page.locator('#birth-time-trigger').click();
    await page.locator('#birth-picker-confirm').click();
    await page.locator('#birth-city').fill('北京');
    await page.getByRole('option',{name:'北京市',exact:false}).dispatchEvent('pointerdown',{pointerType:'touch',pointerId:1,isPrimary:true,buttons:1});
    await expect(page.locator('#birth-city')).toHaveValue('北京市');
    await page.locator('#birth-submit').click();

    await expect(page.locator('#birth-generation')).toBeVisible();
    await expect(page).toHaveURL(/report\.html\?id=native-accepted-report&lang=zh$/);
    await expect(page.locator('#accepted-report')).toBeVisible();
    assert.equal(posts.length,1);
    assert.equal(posts[0].search,'?wait=false');
    assert.match(posts[0].headers['idempotency-key'],/^[0-9a-f-]{36}$/);
    assert.equal(posts[0].body.profile.birth_date,'1990-07-15');
    assert.equal(posts[0].body.profile.birth_time,'07:15');
    assert.equal(posts[0].body.profile.location_id,'geonames:1816670');
    assert.deepEqual(errors,[]);
  } finally {
    await context.close();
  }
});

test('Meta embedded browsers can submit when Web Storage is unavailable', async () => {
  const context = await browser.newContext({
    viewport:{width:390,height:844},
    reducedMotion:'no-preference',
    userAgent:'Mozilla/5.0 (iPhone) AppleWebKit/605.1.15 Instagram 410.0.0.0 Mobile'
  });
  let owner, popups = 0;
  try {
    await context.addInitScript(() => {
      for (const method of ['getItem','setItem','removeItem']) {
        Object.defineProperty(Storage.prototype,method,{configurable:true,value(){ throw Error('storage disabled'); }});
      }
    });
    const page = await context.newPage();
    page.on('popup',() => { popups++; });
    await page.route('**/*',async route => {
      const request = route.request(), address = new URL(request.url());
      if (address.origin !== new URL(url).origin) return route.abort();
      if (!address.pathname.startsWith('/api/')) return route.continue();
      const reply = json => route.fulfill({json});
      if (address.pathname === '/api/landing/visits') return reply({ok:true,accepted_sequences:[]});
      if (address.pathname === '/api/thai-locations') return reply({items:[{
        id:'geonames:1816670',nameChinese:'北京市',nameEnglish:'Beijing',countryCode:'CN',timeZone:'Asia/Shanghai'
      }],total:1});
      if (address.pathname === '/api/landing/config') return reply({notice_version:'h5-data-use-3'});
      if (address.pathname === '/api/landing/consents') return reply({accepted:true,notice_version:'h5-data-use-3'});
      if (address.pathname === '/api/life-reports') {
        owner = request.headers()['x-report-key'];
        return reply({id:'embedded-accepted-report',preview_state:'queued'});
      }
      return reply({ok:true});
    });

    await page.goto(url + '?lang=zh',{waitUntil:'domcontentloaded'});
    assert.equal(await page.evaluate(() => window.fateH5.embedded),true);
    assert.equal(await page.evaluate(() => window.fateBoot.embedded),true);
    assert.match(await page.locator('#birth-submit').evaluate(button => getComputedStyle(button,'::before').animationName),/birth-submit-breathe/);
    await page.locator('#birth-date-trigger').click();
    await page.locator('#birth-picker-confirm').click();
    await page.locator('#birth-time-trigger').click();
    await page.locator('#birth-picker-confirm').click();
    await page.locator('#birth-city').fill('北京');
    await page.getByRole('option',{name:'北京市',exact:false}).click();
    await page.locator('#birth-submit').click();

    await expect(page).toHaveURL(/report\.html\?id=embedded-accepted-report&lang=zh$/);
    assert.match(owner,/^[0-9a-f]{48}$/);
    assert.equal(popups,0);
  } finally {
    await context.close();
  }
});
