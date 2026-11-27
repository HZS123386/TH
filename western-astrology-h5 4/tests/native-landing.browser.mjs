import assert from 'node:assert/strict';
import { createServer } from 'node:http';
import { once } from 'node:events';
import { readFile } from 'node:fs/promises';
import { createRequire } from 'node:module';
import { after, before, test } from 'node:test';

const { chromium, expect } = createRequire(new URL('../../TH/package.json',import.meta.url))('@playwright/test');
const web = new URL('../web-client/web/',import.meta.url);
const assets = new URL('../web-client/assets/',import.meta.url);
let browser, browserProcess, server, url, index;

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
      response.writeHead(200,{'Content-Type':'text/html; charset=utf-8'}).end(
        index.replace('<div id="fate-flutter"></div>','<div id="fate-flutter"><p id="accepted-report">Accepted report</p></div>')
      );
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
  browserProcess = await chromium.launchServer({host:'127.0.0.1',channel:process.env.PLAYWRIGHT_CHANNEL || (process.platform === 'win32' ? 'chrome' : 'chromium')});
  browser = await chromium.connect(browserProcess.wsEndpoint());
});

after(async () => {
  server?.close();
  server?.closeAllConnections();
  await browserProcess?.kill();
});

test('the native landing form creates a report without loading or waiting for Flutter', async () => {
  const context = await browser.newContext({viewport:{width:390,height:844},reducedMotion:'reduce'});
  const pixelId = '29364528359833816';
  const requests = [], posts = [], conversions = [];
  let releasePost;
  const postGate = new Promise(resolve => { releasePost = resolve; });
  try {
    const page = await context.newPage();
    const errors = [];
    page.on('pageerror',error => errors.push(error.message));
    await page.route('**/*',async route => {
      const request = route.request(), address = new URL(request.url());
      if (address.origin === 'https://www.facebook.com' && address.pathname === '/tr/') {
        conversions.push(address.searchParams);
        return route.fulfill({status:204});
      }
      if (address.origin !== new URL(url).origin) return route.abort();
      requests.push(address.pathname);
      if (!address.pathname.startsWith('/api/')) return route.continue();
      const reply = json => route.fulfill({json});
      if (address.pathname === '/api/landing/visits') {
        const body = request.postDataJSON();
        return reply({ok:true,accepted_sequences:(body.events || []).map(event => event.sequence)});
      }
      if (address.pathname === '/api/thai-locations') return reply({items:Array.from({length:10},(_,index) => ({
        id:'geonames:' + (1816670 + index),nameChinese:index ? `测试城市${index}` : '北京市',
        nameEnglish:index ? `Test City ${index}` : 'Beijing',countryCode:'CN',timeZone:'Asia/Shanghai'
      })),total:10});
      if (address.pathname === '/api/landing/config') return reply({notice_version:'h5-data-use-3'});
      if (address.pathname === '/api/landing/consents') return reply({accepted:true,notice_version:'h5-data-use-3'});
      if (address.pathname === '/api/life-reports') {
        posts.push({headers:request.headers(),body:request.postDataJSON(),search:address.search});
        await postGate;
        return reply({id:'native-accepted-report',preview_state:'queued'});
      }
      return reply({ok:true});
    });

    await page.goto(url + '?lang=zh',{waitUntil:'domcontentloaded'});
    await expect(page.locator('#birth-form')).toBeVisible();
    await expect(page.locator('#fate-flutter')).toBeHidden();
    await expect(page.locator('#birth-submit')).toHaveText('查看解析');
    assert.equal(await page.locator('#birth-submit').evaluate(button => getComputedStyle(button,'::before').animationName),'none');
    assert.equal(requests.some(path => /main\.dart|skwasm|canvaskit/.test(path)),false);
    assert.equal(conversions.length,0);
    const pixelCalls = await page.evaluate(() => window.fbq.queue.map(call => Array.from(call)));
    assert.deepEqual(pixelCalls.filter(([command]) => command === 'init' || command === 'track'),[
      ['init',pixelId],
      ['track','PageView'],
    ]);

    await page.locator('#birth-submit').click();
    await expect.poll(() => conversions.length).toBe(1);
    assert.equal(conversions[0].get('ev'),'AddToCart');
    assert.equal(conversions[0].get('id'),pixelId);
    assert.equal(conversions[0].get('dl'),url);
    assert.equal(posts.length,0);

    await page.locator('#birth-date-trigger').click();
    await page.locator('#birth-picker-confirm').click();
    await page.locator('#birth-time-trigger').click();
    await page.locator('#birth-picker-confirm').click();
    await page.locator('#birth-city').fill('北京');
    const menu = page.locator('#birth-options'), option = page.getByRole('option',{name:'北京市',exact:false});
    await option.dispatchEvent('pointerdown',{pointerType:'touch',pointerId:1,isPrimary:true,buttons:1,clientX:100,clientY:160});
    await option.dispatchEvent('pointermove',{pointerType:'touch',pointerId:1,isPrimary:true,buttons:1,clientX:100,clientY:80});
    await option.dispatchEvent('pointerup',{pointerType:'touch',pointerId:1,isPrimary:true,buttons:0,clientX:100,clientY:80});
    await expect(page.locator('#birth-city')).toHaveValue('北京');
    await expect(menu).toBeVisible();
    assert.ok(await menu.evaluate(element => { element.scrollTop = 80; return element.scrollTop; }));
    await option.dispatchEvent('pointerdown',{pointerType:'touch',pointerId:2,isPrimary:true,buttons:1,clientX:100,clientY:100});
    await option.dispatchEvent('pointerup',{pointerType:'touch',pointerId:2,isPrimary:true,buttons:0,clientX:100,clientY:100});
    await expect(page.locator('#birth-city')).toHaveValue('北京市');
    await page.locator('#birth-submit').click();

    await expect(page.locator('#birth-generation')).toBeVisible();
    await expect(page.locator('#birth-generation-status')).toHaveText(/\S/);
    await expect(page.locator('#birth-form')).toBeHidden();
    assert.equal(await page.locator('.birth-generation-visual').evaluate(element => getComputedStyle(element).animationName),'none');
    releasePost();
    await expect(page).toHaveURL(/report\.html\?id=native-accepted-report&lang=zh$/);
    await expect(page.locator('#fate-startup')).toBeVisible();
    await page.evaluate(() => window.fateBoot.ready());
    await expect(page.locator('#accepted-report')).toBeVisible();
    await expect(page.locator('#fate-startup')).toBeHidden();
    assert.equal(conversions.length,1);
    assert.equal(posts.length,1);
    assert.equal(posts[0].search,'?wait=false');
    assert.match(posts[0].headers['idempotency-key'],/^[0-9a-f-]{36}$/);
    assert.equal(posts[0].body.profile.birth_date,'1990-07-15');
    assert.equal(posts[0].body.profile.birth_time,'07:15');
    assert.equal(posts[0].body.profile.location_id,'geonames:1816670');
    await page.goto(url + 'report.html?id=retained-report&lang=zh',{waitUntil:'domcontentloaded'});
    await expect(page.locator('#fate-startup')).toBeVisible();
    assert.deepEqual(errors,[]);
  } finally {
    releasePost();
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
  const requested = [];
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
      requested.push(address.pathname);
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
    assert.equal(await page.evaluate(() => window.fateH5.metaBrowser),'instagram');
    assert.equal(await page.evaluate(() => window.fateH5.metaPlatform),'ios');
    await page.addStyleTag({content:':root{--fate-safe-area-top:70px}'});
    assert.equal(await page.locator('#fate-birth').evaluate(element => getComputedStyle(element).paddingTop),'70px');
    assert.equal(await page.evaluate(() => window.fateBoot.embedded),true);
    await page.evaluate(() => {
      Object.defineProperty(window.visualViewport,'offsetTop',{configurable:true,value:44});
      window.visualViewport.dispatchEvent(new Event('scroll'));
    });
    assert.equal(await page.locator('#fate-birth').evaluate(element => getComputedStyle(element).top),'0px');
    assert.equal((await page.locator('#fate-birth').boundingBox()).y,0);
    assert.match(await page.locator('#birth-submit').evaluate(button => getComputedStyle(button,'::before').animationName),/birth-submit-breathe/);
    await page.locator('#birth-content').evaluate(element => { element.scrollTop = 420; });
    await expect(page.locator('.birth-header')).toBeInViewport();
    assert.ok((await page.locator('.birth-header').boundingBox()).y >= 0);
    await page.locator('#birth-date-trigger').click();
    await page.locator('#birth-picker-confirm').click();
    await page.locator('#birth-time-trigger').click();
    await page.locator('#birth-picker-confirm').click();
    await page.locator('#birth-city').fill('北京');
    await page.getByRole('option',{name:'北京市',exact:false}).click();
    await page.locator('#birth-submit').click();

    await expect(page.locator('#birth-generation')).toBeVisible();
    const generationBackground = await page.locator('.birth-generation-visual').evaluate(element => getComputedStyle(element).backgroundImage);
    assert.match(generationBackground,/report-loading-poster\.webp/);
    assert.doesNotMatch(generationBackground,/report-loading-animated\.webp/);
    assert.match(await page.locator('.birth-generation-visual').evaluate(element => getComputedStyle(element).animationName),/birth-generation-pulse/);
    await expect(page).toHaveURL(/report\.html\?id=embedded-accepted-report&lang=zh$/);
    await expect(page.locator('#fate-startup')).toBeVisible();
    const startupBackground = await page.locator('#fate-startup').evaluate(element => getComputedStyle(element,'::before').backgroundImage);
    assert.match(startupBackground,/report-loading-poster\.webp/);
    assert.doesNotMatch(startupBackground,/report-loading-animated\.webp/);
    assert.equal(requested.some(path => path.endsWith('/report-loading-animated.webp')),false);
    await page.evaluate(() => window.fateBoot.ready());
    await expect(page.locator('#accepted-report')).toBeVisible();
    await expect(page.locator('#fate-startup')).toBeHidden();
    assert.equal(await page.evaluate(() => window.fateBoot.openingReportId),'embedded-accepted-report');
    assert.match(owner,/^[0-9a-f]{48}$/);
    assert.equal(popups,0);
  } finally {
    await context.close();
  }
});

test('Instagram on Android keeps the header above the form while scrolling and changing languages', async () => {
  const context = await browser.newContext({
    viewport:{width:412,height:824}, hasTouch:true, isMobile:true,
    userAgent:'Mozilla/5.0 (Linux; Android 14; Pixel 7; wv) AppleWebKit/537.36 Version/4.0 Chrome/139.0.0.0 Mobile Safari/537.36 Instagram 410.0.0.0 Android'
  });
  try {
    const page = await context.newPage();
    await page.route('**/*',route => {
      const address = new URL(route.request().url());
      if (address.origin !== new URL(url).origin) return route.abort();
      if (address.pathname.startsWith('/api/')) return route.fulfill({json:{ok:true,items:[],accepted_sequences:[]}});
      return route.continue();
    });
    await page.goto(url + '?lang=zh',{waitUntil:'domcontentloaded'});
    const header = page.locator('.birth-header');
    const language = header.locator('#birth-language');
    const content = page.locator('#birth-content');
    await expect(language).toHaveValue('zh');
    assert.equal(await page.evaluate(() => window.fateH5.metaBrowser),'instagram');
    assert.equal(await page.evaluate(() => window.fateH5.metaPlatform),'android');
    await page.addStyleTag({content:':root{--fate-safe-area-top:70px}'});
    assert.equal(await page.locator('#fate-birth').evaluate(element => getComputedStyle(element).paddingTop),'0px');
    assert.equal(await page.locator('.birth-generation-visual').evaluate(element => getComputedStyle(element).animationName),'none');

    const checkPosition = async () => {
      const bar = await header.boundingBox();
      const body = await content.boundingBox();
      assert.equal(bar.y,0);
      assert.equal(bar.y + bar.height,body.y);
      await expect(header.getByRole('img',{name:'FATE'})).toBeInViewport({ratio:1});
      await expect(language).toBeInViewport({ratio:1});
    };
    await checkPosition();
    assert.ok(await content.evaluate(element => { element.scrollTop = 420; return element.scrollTop > 0; }));
    await language.focus();
    await page.evaluate(() => {
      Object.defineProperty(window.visualViewport,'offsetTop',{configurable:true,value:44});
      window.visualViewport.dispatchEvent(new Event('scroll'));
    });
    await page.setViewportSize({width:412,height:742});
    await checkPosition();
    await language.selectOption('en');
    await expect(page.locator('html')).toHaveAttribute('lang','en');
    await checkPosition();
  } finally {
    await context.close();
  }
});

test('Facebook embedded browser can scroll and select the city list', async () => {
  const context = await browser.newContext({
    viewport:{width:390,height:844},
    isMobile:true,
    hasTouch:true,
    userAgent:'Mozilla/5.0 (Linux; Android 15) AppleWebKit/537.36 Mobile Safari/537.36 [FBAN/FB4A;FBAV/540.0.0.0]'
  });
  try {
    const page = await context.newPage();
    await page.route('**/*',async route => {
      const request = route.request(), address = new URL(request.url());
      if (address.origin !== new URL(url).origin) return route.abort();
      if (!address.pathname.startsWith('/api/')) return route.continue();
      if (address.pathname === '/api/landing/visits') return route.fulfill({json:{ok:true,accepted_sequences:[]}});
      if (address.pathname === '/api/thai-locations') return route.fulfill({json:{
        items:Array.from({length:12},(_,index) => ({
          id:'geonames:' + (1816670 + index),nameChinese:index ? `测试城市${index}` : '北京市',
          nameEnglish:index ? `Test City ${index}` : 'Beijing',countryCode:'CN',timeZone:'Asia/Shanghai'
        })),total:12
      }});
      return route.fulfill({json:{ok:true}});
    });

    await page.goto(url + '?lang=zh',{waitUntil:'domcontentloaded'});
    assert.equal(await page.evaluate(() => window.fateH5.metaBrowser),'facebook');
    assert.equal(await page.evaluate(() => window.fateH5.metaPlatform),'android');
    await page.addStyleTag({content:':root{--fate-safe-area-top:70px}'});
    assert.equal(await page.locator('#fate-birth').evaluate(element => getComputedStyle(element).paddingTop),'0px');
    const city = page.locator('#birth-city'), menu = page.locator('#birth-options');
    await city.click();
    const option = page.getByRole('option',{name:'北京市',exact:false});
    await expect(option).toBeVisible();
    await page.evaluate(() => {
      Object.defineProperties(window.visualViewport,{
        offsetTop:{configurable:true,value:32},
        height:{configurable:true,value:500}
      });
      window.visualViewport.dispatchEvent(new Event('resize'));
    });
    assert.equal(await page.locator('#fate-birth').evaluate(element => getComputedStyle(element).top),'32px');
    await expect(menu).toBeVisible();
    await option.dispatchEvent('pointerdown',{pointerType:'touch',pointerId:7,isPrimary:true,buttons:1,clientX:100,clientY:160});
    await option.dispatchEvent('pointermove',{pointerType:'touch',pointerId:7,isPrimary:true,buttons:1,clientX:100,clientY:70});
    await option.dispatchEvent('pointerup',{pointerType:'touch',pointerId:7,isPrimary:true,buttons:0,clientX:100,clientY:70});
    assert.ok(await menu.evaluate(element => element.scrollTop >= 80));
    await expect(city).toHaveValue('');
    await option.dispatchEvent('pointerdown',{pointerType:'touch',pointerId:8,isPrimary:true,buttons:1,clientX:100,clientY:100});
    await option.dispatchEvent('pointerup',{pointerType:'touch',pointerId:8,isPrimary:true,buttons:0,clientX:100,clientY:100});
    await expect(city).toHaveValue('北京市');

    await page.locator('#birth-submit').tap();
    await expect(page.locator('#birth-date-trigger')).toBeFocused();
    assert.equal(await page.locator('#fate-birth').evaluate(element => getComputedStyle(element).top),'32px');
    await page.evaluate(() => {
      Object.defineProperties(window.visualViewport,{
        offsetTop:{configurable:true,value:0},
        height:{configurable:true,value:844}
      });
      window.visualViewport.dispatchEvent(new Event('resize'));
    });
    assert.equal(await page.locator('#fate-birth').evaluate(element => getComputedStyle(element).top),'0px');
  } finally {
    await context.close();
  }
});
