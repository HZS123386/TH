// Upgrade only the deployed IP site; local previews keep their existing origin.
// The short-lived host cookie avoids putting report credentials in URLs or logs.
const fateHttpsUpgrading=(()=>{
  if(location.host!=='129.226.126.212'||!location.pathname.startsWith('/thai-landing/'))return false;
  if(new URLSearchParams(location.search).get('legacy_http')==='1')return false;
  const ownerName='astro-life-report-key',bridgeName='fate-https-owner',upgradeName='_fate_https';
  const valid=value=>typeof value==='string'&&/^[A-Za-z0-9_-]{32,128}$/.test(value);
  const stores=[];
  for(const read of [()=>window.localStorage,()=>window.sessionStorage]){try{stores.push(read());}catch{}}
  const saved=()=>{for(const store of stores){try{const value=store.getItem(ownerName);if(valid(value))return value;}catch{}}return null;};
  const cookie=()=>{try{return document.cookie.split(';').map(value=>value.trim()).find(value=>value.startsWith(bridgeName+'='))?.slice(bridgeName.length+1)||null;}catch{return null;}};
  const clearBridge=()=>{try{document.cookie=`${bridgeName}=; Path=/thai-landing/; Max-Age=0; SameSite=Lax; Secure`;}catch{}};
  const redirect=(protocol,legacy=false,migrating=false)=>{const target=new URL(location.href);target.protocol=protocol;target.searchParams.delete(upgradeName);if(migrating)target.searchParams.set(upgradeName,'1');if(legacy)target.searchParams.set('legacy_http','1');location.replace(target.href);return true;};
  if(location.protocol==='http:'){
    const owner=saved();
    if(owner){
      try{document.cookie=`${bridgeName}=${owner}; Path=/thai-landing/; Max-Age=60; SameSite=Lax`;}catch{return false;}
      if(cookie()!==owner)return false;
    }
    return redirect('https:',false,!!owner);
  }
  if(location.protocol!=='https:')return false;
  const incoming=cookie();
  const upgrading=new URLSearchParams(location.search).get(upgradeName)==='1';
  if(!valid(incoming))return upgrading?redirect('http:',true):false;
  const current=saved();
  if(current&&current!==incoming){
    // Keep both owners recoverable, and let the old HTTP link retain its reports.
    let preserved=false;
    for(const store of stores){try{store.setItem(ownerName+'-http',incoming);preserved=store.getItem(ownerName+'-http')===incoming||preserved;}catch{}}
    if(preserved)clearBridge();
    return redirect('http:',true);
  }
  let persisted=false;
  for(const store of stores){try{store.setItem(ownerName,incoming);persisted=store.getItem(ownerName)===incoming||persisted;}catch{}}
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
  stage(stage){if(fateBootFinished||(fateBootFailed&&stage!=='retry'&&stage!=='failed'))return;if(stage==='engine'||stage==='app')fateBootPhase=stage;const status=document.getElementById('fate-startup-status');if(status)status.textContent=fateBootLabels[stage]||fateBootLabels.app;},
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
window.fateH5 = {
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
    if(page==='app-ready')requestAnimationFrame(()=>requestAnimationFrame(()=>window.fateBoot.ready()));
    if(!fatePerfEnabled)return;
    requestAnimationFrame(()=>console.debug('[FATE H5 performance] '+JSON.stringify({page,readyMs:Math.round(performance.now()),resources:performance.getEntriesByType('resource').filter(e=>/api\/|main\.dart|skwasm|canvaskit|fonts\/|astrologer/.test(e.name)).map(e=>({name:new URL(e.name).pathname.replace(/(life-reports\/)\w{8,}/,'$1:id'),startMs:Math.round(e.startTime),endMs:Math.round(e.responseEnd),bytes:e.transferSize}))})));
  }
};
