const fateOwnerName = 'astro-life-report-key';
const fateValidOwner = value => typeof value === 'string' && /^[A-Za-z0-9_-]{32,128}$/.test(value);
const fateHex = bytes => Array.from(bytes, value => value.toString(16).padStart(2, '0')).join('');
function fateOwnerStores() {
  const stores = [];
  for (const read of [() => window.localStorage, () => window.sessionStorage]) {
    try { stores.push(read()); } catch {}
  }
  return stores;
}
function fateSavedOwner(stores) {
  for (const store of stores) {
    try {
      const value = store.getItem(fateOwnerName);
      if (fateValidOwner(value)) return value;
    } catch {}
  }
  return null;
}
let fateOwner;
function fateOwnerKey() {
  const stores = fateOwnerStores();
  const key = fateOwner ?? fateSavedOwner(stores) ?? fateHex(crypto.getRandomValues(new Uint8Array(24)));
  let persisted = false;
  for (const store of stores) {
    try {
      if (store.getItem(fateOwnerName) !== key) store.setItem(fateOwnerName, key);
      persisted = store.getItem(fateOwnerName) === key || persisted;
    } catch {}
  }
  fateOwner = persisted ? key : null;
  return fateOwner;
}

// Upgrade only the deployed IP site; local previews keep their existing origin.
// The short-lived host cookie avoids putting report credentials in URLs or logs.
const fateHttpsUpgrading=(()=>{
  if(location.host!=='129.226.126.212'||!location.pathname.startsWith('/thai-landing/'))return false;
  if(new URLSearchParams(location.search).get('legacy_http')==='1')return false;
  const bridgeName='fate-https-owner',upgradeName='_fate_https';
  const stores=fateOwnerStores();
  const cookie=()=>{try{return document.cookie.split(';').map(value=>value.trim()).find(value=>value.startsWith(bridgeName+'='))?.slice(bridgeName.length+1)||null;}catch{return null;}};
  const clearBridge=()=>{try{document.cookie=`${bridgeName}=; Path=/thai-landing/; Max-Age=0; SameSite=Lax; Secure`;}catch{}};
  const redirect=(protocol,legacy=false,migrating=false)=>{const target=new URL(location.href);target.protocol=protocol;target.searchParams.delete(upgradeName);if(migrating)target.searchParams.set(upgradeName,'1');if(legacy)target.searchParams.set('legacy_http','1');location.replace(target.href);return true;};
  if(location.protocol==='http:'){
    const owner=fateSavedOwner(stores);
    if(owner){
      try{document.cookie=`${bridgeName}=${owner}; Path=/thai-landing/; Max-Age=60; SameSite=Lax`;}catch{return false;}
      if(cookie()!==owner)return false;
    }
    return redirect('https:',false,!!owner);
  }
  if(location.protocol!=='https:')return false;
  const incoming=cookie();
  const upgrading=new URLSearchParams(location.search).get(upgradeName)==='1';
  if(!fateValidOwner(incoming))return upgrading?redirect('http:',true):false;
  const current=fateSavedOwner(stores);
  if(current&&current!==incoming){
    // Keep both owners recoverable, and let the old HTTP link retain its reports.
    let preserved=false;
    for(const store of stores){try{store.setItem(fateOwnerName+'-http',incoming);preserved=store.getItem(fateOwnerName+'-http')===incoming||preserved;}catch{}}
    if(preserved)clearBridge();
    return redirect('http:',true);
  }
  let persisted=false;
  for(const store of stores){try{store.setItem(fateOwnerName,incoming);persisted=store.getItem(fateOwnerName)===incoming||persisted;}catch{}}
  if(!persisted)return redirect('http:',true);
  clearBridge();
  if(upgrading){const target=new URL(location.href);target.searchParams.delete(upgradeName);history.replaceState(null,'',target.href);}
  return false;
})();
const fatePerfEnabled=new URLSearchParams(location.search).get('startup')==='1';
const fateBootLabels={
  zh:{engine:'正在准备星空画面',app:'正在载入你的专属页面',slow:'网络有点慢，请稍候',retry:'连接暂时中断，正在重新加载',failed:'页面加载失败，请检查网络后重试'},
  th:{engine:'กำลังเตรียมภาพดวงดาว',app:'กำลังเปิดหน้าส่วนตัวของคุณ',slow:'เครือข่ายช้าเล็กน้อย กรุณารอสักครู่',retry:'การเชื่อมต่อขัดข้อง กำลังโหลดใหม่',failed:'โหลดไม่สำเร็จ กรุณาตรวจสอบเครือข่ายแล้วลองใหม่'},
  en:{engine:'Preparing your sky',app:'Loading your page',slow:'The network is slow. Please wait',retry:'Connection interrupted. Reloading',failed:'The page could not load. Check your connection and try again'},
  vi:{engine:'Đang chuẩn bị bầu trời của bạn',app:'Đang tải trang của bạn',slow:'Mạng hơi chậm. Vui lòng đợi',retry:'Kết nối gián đoạn. Đang tải lại',failed:'Chưa tải được trang. Hãy kiểm tra mạng và thử lại'},
  "my":{"engine": "သင့်ကြယ်ကောင်းကင်ကို ဖွင့်နေသည်", "app": "သင့်ကြယ်ကောင်းကင်ကို ဖွင့်နေသည်", "slow": "ကွန်ရက်နှေးနေသည်။ ခဏစောင့်ပါ", "retry": "ချိတ်ဆက်မှုပြတ်သွားသည်။ ပြန်တင်နေသည်", "failed": "စာမျက်နှာ မတင်နိုင်ပါ။ ကွန်ရက်စစ်ပြီး ပြန်ကြိုးစားပါ"},
  "km":{"engine": "កំពុងបើកមេឃរបស់អ្នក", "app": "កំពុងបើកមេឃរបស់អ្នក", "slow": "បណ្ដាញយឺត។ សូមរង់ចាំ", "retry": "ការតភ្ជាប់ដាច់។ កំពុងផ្ទុកឡើងវិញ", "failed": "មិនអាចផ្ទុកទំព័រ។ ពិនិត្យបណ្ដាញ ហើយសាកល្បងម្ដងទៀត"},
  "lo":{"engine": "ກຳລັງເປີດທ້ອງຟ້າຂອງທ່ານ", "app": "ກຳລັງເປີດທ້ອງຟ້າຂອງທ່ານ", "slow": "ເຄືອຂ່າຍຊ້າ. ກະລຸນາລໍຖ້າ", "retry": "ການເຊື່ອມຕໍ່ຂາດ. ກຳລັງໂຫຼດໃໝ່", "failed": "ໂຫຼດໜ້າບໍ່ໄດ້. ກວດເຄືອຂ່າຍ ແລະລອງໃໝ່"},
  "ms":{"engine": "Membuka langit anda", "app": "Membuka langit anda", "slow": "Rangkaian perlahan. Sila tunggu", "retry": "Sambungan terputus. Memuatkan semula", "failed": "Halaman tidak dapat dimuatkan. Semak sambungan dan cuba lagi"},
  "id":{"engine": "Membuka langit Anda", "app": "Membuka langit Anda", "slow": "Jaringan lambat. Silakan tunggu", "retry": "Koneksi terputus. Memuat ulang", "failed": "Halaman belum dapat dimuat. Periksa koneksi dan coba lagi"}
}[document.documentElement.lang];
let fateBootFinished=false,fateBootFailed=false,fateBootRecovery,fateBootPhase='entry';
const fateBootRetryKey='fate-startup-recovery-at';
// Consume a queued retry even if navigation stalled, then latch the path preference before its TTL expires.
const fateBootRetry=(()=>{
  try{
    const previous=JSON.parse(sessionStorage.getItem(fateBootRetryKey)||'null');
    const age=Date.now()-previous?.at;
    if(previous?.path!==location.pathname||(!previous.pending&&!(age>=0&&age<120000)))return null;
    if(previous.pending){try{sessionStorage.setItem(fateBootRetryKey,JSON.stringify({at:Date.now(),path:location.pathname,pending:false,compatibility:previous.compatibility===true}));}catch{}}
    return previous;
  }catch{return null;}
})();
const fateBootSlow=fateHttpsUpgrading?undefined:setTimeout(()=>{if(!fateBootFinished){window.fateBoot.stage('slow');const button=document.getElementById('fate-startup-retry');if(button)button.hidden=false;}},12000);
// A truncated HTML stream may render the overlay without ever reaching the inline bootstrap.
const fateBootHtml=fateHttpsUpgrading?undefined:setTimeout(()=>{if(document.readyState==='loading'&&!window._flutter?.buildConfig)window.fateBoot.fail();},20000);
const fateBootWatchdog=fateHttpsUpgrading?undefined:setTimeout(()=>window.fateBoot.fail(),90000);
window.fateBoot={
  upgrading:fateHttpsUpgrading,
  compatibility:fateBootRetry?.compatibility===true,
  stage(stage){if(fateBootFinished||(fateBootFailed&&stage!=='retry'&&stage!=='failed'))return;if(stage==='engine'||stage==='app')fateBootPhase=stage;const startup=document.getElementById('fate-startup');if(startup)startup.dataset.state=stage;const status=document.getElementById('fate-startup-status');if(status)status.textContent=fateBootLabels[stage]||fateBootLabels.app;},
  fail(){
    if(fateHttpsUpgrading||fateBootFinished||fateBootFailed)return;
    fateBootFailed=true;clearTimeout(fateBootSlow);clearTimeout(fateBootHtml);clearTimeout(fateBootWatchdog);
    // A failed ES-module import stays rejected for this document; retry it once in a fresh document.
    let recover=false;
    if(!fateBootRetry){try{
      // App assets can fail after the engine is ready; those retries retain the normal renderer.
      const marker=JSON.stringify({at:Date.now(),path:location.pathname,pending:true,compatibility:fateBootPhase!=='app'});
      sessionStorage.setItem(fateBootRetryKey,marker);
      recover=sessionStorage.getItem(fateBootRetryKey)===marker;
    }catch{}}
    if(recover){this.stage('retry');fateBootRecovery=setTimeout(()=>location.reload(),700);return;}
    this.stage('failed');const button=document.getElementById('fate-startup-retry');if(button)button.hidden=false;
  },
  ready(){
    if(fateBootFinished)return;
    fateBootFinished=true;clearTimeout(fateBootSlow);clearTimeout(fateBootHtml);clearTimeout(fateBootWatchdog);clearTimeout(fateBootRecovery);
    try{sessionStorage.removeItem(fateBootRetryKey);}catch{}
    document.getElementById('fate-startup')?.remove();performance.mark('fate-app-ready');window.dispatchEvent(new Event('fate-app-ready'));
  }
};
// Flutter's JavaScript entrypoint uses a callback and does not reject on a script fetch error.
window.addEventListener('error',event=>{
  if(event.error||event.message||(event.target?.tagName==='SCRIPT'&&/\/(?:main\.dart\.js|flutter_bootstrap\.js|(?:skwasm|canvaskit)(?:_[\w]+)?\.js)(?:\?|$)/.test(event.target.src)))window.fateBoot.fail();
},true);
window.addEventListener('unhandledrejection',()=>window.fateBoot.fail());
// The HTML response can stall after rendering the button but before DOMContentLoaded.
document.addEventListener('click',event=>{if(event.target?.closest?.('#fate-startup-retry'))location.reload();});
const fatePendingKey = 'fate-activity-pending';
let fateActivity, fateActivitySequence = 0, fatePending = [], fateDropped = {};
let fateUnstored = new Map(), fateRemoved = new Set(), fateStoredKeys = new Set(), fateStoredDropped = {}, fateOverflow = {};
let fateSending = 0, fateRetryAt = 0, fateRetryCount = 0, fateSendTimer, fateDwellTimer;
const fateTrackingAllowed = () => window.navigator?.globalPrivacyControl !== true && window.navigator?.doNotTrack !== '1';
const fateMetaPixelId = '2150104392567893';
let fateMetaPixelStarted = false;
function trackFatePageView() {
  if (!fateTrackingAllowed()) return;
  try {
    const landing = new URL('.', document.baseURI).pathname;
    if (location.pathname !== landing && location.pathname !== landing + 'index.html') return;
    if (!fateMetaPixelStarted) {
      if (!window.fbq) {
        const fbq = function () {
          if (fbq.callMethod) fbq.callMethod.apply(fbq, arguments);
          else fbq.queue.push(arguments);
        };
        Object.assign(fbq, { push: fbq, loaded: true, version: '2.0', queue: [] });
        window.fbq = window._fbq = fbq;
        const script = document.createElement('script');
        script.async = true;
        script.src = 'https://connect.facebook.net/en_US/fbevents.js';
        document.head.append(script);
      }
      // Send explicit landing events without automatic form or history tracking.
      window.fbq.disablePushState = true;
      window.fbq('set', 'autoConfig', false, fateMetaPixelId);
      window.fbq('init', fateMetaPixelId);
      window.fbq('track', 'PageView');
      fateMetaPixelStarted = true;
    }
  } catch {
    // A tracking failure must never block report generation.
  }
}
function sendFateLineClaimPixel() {
  if (!fateTrackingAllowed()) return;
  const pixel = new URL('https://www.facebook.com/tr/');
  const reportPage = new URL(location.pathname, location.href);
  pixel.searchParams.set('id', fateMetaPixelId);
  pixel.searchParams.set('ev', 'AddToCart');
  pixel.searchParams.set('dl', reportPage.href);
  pixel.searchParams.set('ts', String(Date.now()));
  for (const name of ['fbp', 'fbc']) {
    const prefix = '_' + name + '=';
    const value = document.cookie.split(';').map(cookie => cookie.trim())
      .find(cookie => cookie.startsWith(prefix))?.slice(prefix.length);
    if (value && /^fb\.\d+\.\d+\.[A-Za-z0-9_-]+$/.test(value)) {
      pixel.searchParams.set(name, value);
    }
  }
  // Keep the request alive across the LINE redirect and omit the report ID from the URL.
  void fetch(pixel.href, {
    mode: 'no-cors', keepalive: true, credentials: 'include', referrerPolicy: 'no-referrer',
  }).catch(() => {});
}
function trackFateLineClaimClick() {
  if (!fateTrackingAllowed()) return Promise.resolve();
  return new Promise(resolve => {
    let finished = false;
    let transaction;
    const timer = setTimeout(() => {
      try { transaction?.abort(); } catch {}
      finish();
    }, 300);
    function finish() {
      finished = true;
      clearTimeout(timer);
      resolve();
    }
    async function track() {
      const owner = fateOwnerKey();
      if (!owner) return finish();
      const digest = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(owner));
      if (finished) return;
      // A browser that clicked the former entry can still record first contact on LINE.
      const marker = 'line-claim:' + fateHex(new Uint8Array(digest));
      const request = indexedDB.open('fate-meta-pixel-' + fateMetaPixelId, 1);
      request.onupgradeneeded = () => request.result.createObjectStore('add-to-cart');
      request.onerror = finish;
      request.onblocked = finish;
      request.onsuccess = () => {
        const database = request.result;
        if (finished || !fateTrackingAllowed()) {
          database.close();
          finish();
          return;
        }
        try {
          transaction = database.transaction('add-to-cart', 'readwrite');
          transaction.onabort = () => {
            database.close();
            finish();
          };
          transaction.oncomplete = () => {
            database.close();
            if (finished) return;
            try {
              sendFateLineClaimPixel();
            } catch {}
            finish();
          };
          transaction.objectStore('add-to-cart').add(true, marker);
        } catch {
          database.close();
          finish();
        }
      };
    }
    void track().catch(finish);
  });
}
const fateState = () => document.visibilityState === 'hidden' ? 'hidden' : 'visible';
const fateEventKey = item => `${item.visit.id}:${item.event.sequence}`;
const fateEntryParams = new URLSearchParams(location.search);
const fateVisitStorageKey = 'fate-visit-context';
let fateVisit;
function fateUuid() {
  const bytes = crypto.getRandomValues(new Uint8Array(16));
  bytes[6] = (bytes[6] & 15) | 64;
  bytes[8] = (bytes[8] & 63) | 128;
  const hex = fateHex(bytes);
  return `${hex.slice(0, 8)}-${hex.slice(8, 12)}-${hex.slice(12, 16)}-${hex.slice(16, 20)}-${hex.slice(20)}`;
}
function rememberFateVisit() {
  if (!fateVisit || !fateTrackingAllowed()) return;
  try { sessionStorage.setItem(fateVisitStorageKey, JSON.stringify(fateVisit)); } catch {}
  try {
    const state = history.state;
    if (state == null || (typeof state === 'object' && !Array.isArray(state))) {
      history.replaceState({ ...state, fateVisit }, '');
    }
  } catch {}
}
function restoreFateVisit(value) {
  if (typeof value?.id !== 'string' || !/^[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}$/i.test(value.id)) return null;
  const tag = field => typeof value[field] === 'string' && /^[A-Za-z0-9_.~-]{0,64}$/.test(value[field]) ? value[field] : '';
  const region = typeof value.region === 'string' && /^[A-Z]{2}$/.test(value.region) ? value.region : null;
  return { id: value.id, source: tag('source'), campaign: tag('campaign'), ...(region ? { region } : {}) };
}
function fateVisitContext() {
  if (!fateTrackingAllowed() || fateHttpsUpgrading) return null;
  if (fateVisit) return fateVisit;
  const type = performance.getEntriesByType?.('navigation')?.[0]?.type;
  // A fresh document entry uses its own URL tags, even in a previously used tab.
  if (type !== 'navigate') {
    try { fateVisit = restoreFateVisit(history.state?.fateVisit); } catch {}
    if (!fateVisit && type === 'reload') {
      try { fateVisit = restoreFateVisit(JSON.parse(sessionStorage.getItem(fateVisitStorageKey) || 'null')); } catch {}
    }
  }
  if (!fateVisit) {
    const tag = name => (fateEntryParams.get(name) || '').replace(/[^A-Za-z0-9_.~-]/g, '').slice(0, 64);
    const region = fateEntryParams.get('utm_region')?.trim().toUpperCase();
    fateVisit = { id: fateUuid(), source: tag('utm_source'), campaign: tag('utm_campaign'),
      ...(/^[A-Z]{2}$/.test(region || '') ? { region } : {}) };
  }
  rememberFateVisit();
  return fateVisit;
}
function persistFateActivity(added, delivered = []) {
  if (!fateActivity) return false;
  if (added) fateUnstored.set(fateEventKey(added), added);
  for (const key of delivered) { fateUnstored.delete(key); fateRemoved.add(key); }
  let stored = fatePending, readable = false;
  try {
    const saved = JSON.parse(sessionStorage.getItem(fatePendingKey) || '{}');
    if (saved.owner && saved.owner !== fateActivity.key) { clearFateActivity(false); return false; }
    stored = Array.isArray(saved.items) ? saved.items.filter(item => typeof item?.visit?.id === 'string' &&
      Number.isSafeInteger(item?.event?.sequence) && Number.isFinite(item?.event?.occurred_at)) : [];
    fateStoredKeys = new Set(stored.map(fateEventKey));
    fateStoredDropped = saved.dropped || {};
    readable = true;
  } catch {}
  // Merge only unsaved changes into the latest shared queue; cached snapshots may already be acknowledged.
  fateRemoved = new Set([...fateRemoved].filter(key => fateStoredKeys.has(key)));
  const merged = new Map(stored.map(item => [fateEventKey(item), item]));
  for (const [key, item] of fateUnstored) if (!merged.has(key)) merged.set(key, item);
  for (const key of fateRemoved) merged.delete(key);
  for (const key of delivered) merged.delete(key);
  const forget = item => {
    const key = fateEventKey(item);
    fateUnstored.delete(key);
    if (fateStoredKeys.has(key)) fateRemoved.add(key);
  };
  const checkpoints = new Set();
  fatePending = [...merged.values()].sort((a, b) => b.event.sequence - a.event.sequence).filter(item => {
    const checkpoint = `${item.visit.id}:${item.event.page_view_id}`;
    if (item.event.occurred_at < Date.now() / 1000 - 30 * 86400 ||
        (item.event.kind === 'dwell' && checkpoints.has(checkpoint))) {
      forget(item); return false;
    }
    if (item.event.kind === 'dwell') checkpoints.add(checkpoint);
    return true;
  }).reverse();
  while (fatePending.length > 500) {
    const removed = fatePending.shift();
    forget(removed);
    fateOverflow[removed.visit.id] = (fateOverflow[removed.visit.id] || 0) + 1;
  }
  fateDropped = { ...fateStoredDropped };
  for (const [id, count] of Object.entries(fateOverflow)) fateDropped[id] = Math.min(2147483647, (fateDropped[id] || 0) + count);
  if (readable) try {
    sessionStorage.setItem(fatePendingKey, JSON.stringify({ owner: fateActivity.key, items: fatePending, dropped: fateDropped }));
    fateUnstored.clear(); fateRemoved.clear(); fateOverflow = {};
    fateStoredKeys = new Set(fatePending.map(fateEventKey));
    fateStoredDropped = { ...fateDropped };
  } catch {}
  return true;
}
function clearFateActivity(clearStored = true) {
  fatePending = []; fateDropped = {}; fateActivity = undefined;
  fateUnstored.clear(); fateRemoved.clear(); fateStoredKeys.clear(); fateStoredDropped = {}; fateOverflow = {};
  fateRetryAt = 0; fateRetryCount = 0;
  clearTimeout(fateSendTimer); clearTimeout(fateDwellTimer);
  if (clearStored) try { sessionStorage.removeItem(fatePendingKey); } catch {}
}
function scheduleFateActivity(delay = 250) {
  clearTimeout(fateSendTimer);
  fateSendTimer = setTimeout(flushFateActivity, Math.max(delay, fateRetryAt - Date.now()));
}
async function flushFateActivity(urgent = false) {
  if (!fateTrackingAllowed()) { clearFateActivity(); return; }
  if (!fateActivity || fateSending >= (urgent ? 2 : 1)) return;
  if (!persistFateActivity() || !fatePending.length) return;
  if (Date.now() < fateRetryAt) { scheduleFateActivity(); return; }
  const owner = fateActivity.key, endpoint = fateActivity.endpoint, first = urgent ? fatePending.at(-1) : fatePending[0];
  const matching = fatePending.filter(item => item.visit.id === first.visit.id);
  const batch = urgent ? matching.slice(-20) : matching.slice(0, 20);
  fateSending++;
  const controller = new AbortController();
  const deadline = setTimeout(() => controller.abort(), 15000);
  let retryDelay = 0;
  try {
    // Small batches stay below the browser's shared 64 KiB keepalive budget.
    const response = await fetch(endpoint, {
      method: 'POST', keepalive: true, signal: controller.signal,
      headers: { 'Content-Type': 'application/json', 'X-Report-Key': owner, 'X-Visit-Id': first.visit.id },
      body: JSON.stringify({ ...first.visit, events: batch.map(item => item.event), dropped_events: fateDropped[first.visit.id] || 0 }),
    });
    if (!response.ok) {
      const retry = response.headers.get('Retry-After');
      retryDelay = /^\d+(\.\d+)?$/.test(retry || '') ? Number(retry) * 1000 : Math.max(0, Date.parse(retry) - Date.now()) || 0;
      throw new Error('Activity not acknowledged');
    }
    const result = await response.json();
    if (result.ok !== true || !Array.isArray(result.accepted_sequences)) throw new Error('Activity not acknowledged');
    if (fateActivity?.key !== owner) return;
    const accepted = new Set(result.accepted_sequences);
    const delivered = batch.filter(item => accepted.has(item.event.sequence)).map(fateEventKey);
    if (!delivered.length) throw new Error('Activity not acknowledged');
    fateRetryCount = 0; fateRetryAt = 0;
    persistFateActivity(undefined, delivered);
  } catch {
    if (fateActivity?.key === owner) {
      fateRetryCount++;
      fateRetryAt = Date.now() + Math.max(retryDelay, Math.min(60000, 1000 * 2 ** Math.min(fateRetryCount, 6)));
    }
  } finally {
    clearTimeout(deadline);
    fateSending--;
    if (fatePending.length && fateActivity) scheduleFateActivity();
  }
}
function recordFateActivity(kind = 'action', state = fateState(), action, failure = {}) {
  if (!fateTrackingAllowed()) { clearFateActivity(); return; }
  if (!fateActivity) return;
  const now = performance.now();
  if (fateActivity.visibleSince !== null) fateActivity.visibleMs += Math.max(0, now - fateActivity.visibleSince);
  fateActivity.visibleSince = state === 'visible' ? now : null;
  let previous = 0;
  try { previous = Number(sessionStorage.getItem('fate-activity-sequence')) || 0; } catch {}
  fateActivitySequence = Math.max(Date.now(), fateActivitySequence + 1, previous + 1);
  try { sessionStorage.setItem('fate-activity-sequence', String(fateActivitySequence)); } catch {}
  const event = { ...fateActivity.activity, ...(action ? { action } : {}), ...failure, state, kind, sequence: fateActivitySequence,
    page_view_id: fateActivity.pageViewId, occurred_at: Date.now() / 1000, visible_ms: Math.min(2592000000, Math.round(fateActivity.visibleMs)) };
  persistFateActivity({ visit: fateActivity.visit, event });
  scheduleFateActivity();
}
function scheduleFateDwell() {
  clearTimeout(fateDwellTimer);
  if (fateActivity && fateState() === 'visible') fateDwellTimer = setTimeout(() => {
    recordFateActivity('dwell'); scheduleFateDwell();
  }, 15000);
}
function fateVisibility(state) {
  recordFateActivity('state', state);
  clearTimeout(fateSendTimer);
  void flushFateActivity(state !== 'visible');
  scheduleFateDwell();
}
document.addEventListener('visibilitychange', () => fateVisibility(fateState()));
window.addEventListener('pagehide', () => {
  rememberFateVisit();
  fateVisibility('pagehide');
});
window.addEventListener('pageshow', event => {
  if (event.persisted) {
    rememberFateVisit();
    fateVisibility(fateState());
  }
});
window.addEventListener('online', () => { scheduleFateActivity(0); });
// Capture the entry's state before Flutter manages browser history.
try { fateVisitContext(); } catch {}
window.fateH5 = {
  ownerKey: fateOwnerKey,
  trackLineClaimClick: trackFateLineClaimClick,
  visitContext() { return JSON.stringify(fateVisitContext() || {}); },
  trackFailure(path, code, method) {
    recordFateActivity('action', fateState(), 'request_failed', { failure_path: path, failure_code: code, failure_method: method });
    if (fateActivity) fateActivity.activity = { ...fateActivity.activity, action: 'request_failed' };
  },
  trackActivity(payload, key, endpoint) {
    if (!fateTrackingAllowed()) { clearFateActivity(); return; }
    try {
      const { activity, ...visit } = JSON.parse(payload);
      if (!fateActivity || fateActivity.key !== key) {
        clearFateActivity(false);
        try {
          const saved = JSON.parse(sessionStorage.getItem(fatePendingKey) || '{}');
          if (saved.owner && saved.owner !== key) sessionStorage.removeItem(fatePendingKey);
        } catch {}
      }
      if (fateActivity && (fateActivity.visit.id !== visit.id || fateActivity.activity.page !== activity.page)) {
        recordFateActivity('state', fateState(), 'leave_page');
        fateActivity = undefined;
      }
      if (!fateActivity) {
        fateActivity = { visit, activity, key, endpoint, visibleMs: 0, visibleSince: null,
          pageViewId: fateUuid() };
      } else fateActivity.activity = activity;
      recordFateActivity();
      scheduleFateDwell();
    } catch {}
  },
  today(zone) {
    const parts=new Intl.DateTimeFormat('en-CA',{timeZone:zone,year:'numeric',month:'2-digit',day:'2-digit'}).formatToParts(new Date());
    const get=name=>parts.find(part=>part.type===name).value;
    return `${get('year')}-${get('month')}-${get('day')}`;
  },
  async exportDocument(payload,format) {
    const module=await import('./runtime/report-pdf.js');
    return module.exportDocument(payload,format);
  },
  postPayment(action,fieldsJson) {
    const target=new URL(action);
    if(target.origin!=='https://www.thaiepay.com'||target.pathname!=='/epaylink/payment.aspx'||target.username||target.password) throw new Error('Invalid payment URL');
    const form=document.createElement('form');
    form.action=target.href;form.method='post';form.target='_blank';form.rel='noopener';
    for(const [name,value] of Object.entries(JSON.parse(fieldsJson))) {
      const input=document.createElement('input');input.type='hidden';input.name=name;input.value=value;form.append(input);
    }
    document.body.append(form);form.submit();form.remove();
  },
  pageReady(page) {
    if(page==='app-ready')requestAnimationFrame(()=>requestAnimationFrame(()=>{
      rememberFateVisit();
      window.fateBoot.ready();
      trackFatePageView();
    }));
    if(!fatePerfEnabled)return;
    requestAnimationFrame(()=>console.debug('[FATE H5 performance] '+JSON.stringify({page,readyMs:Math.round(performance.now()),resources:performance.getEntriesByType('resource').filter(e=>/api\/|main\.dart|skwasm|canvaskit|fonts\/|astrologer/.test(e.name)).map(e=>({name:new URL(e.name).pathname.replace(/(life-reports\/)\w{8,}/,'$1:id'),startMs:Math.round(e.startTime),endMs:Math.round(e.responseEnd),bytes:e.transferSize}))})));
  }
};
