const fatePerfEnabled=new URLSearchParams(location.search).get('startup')==='1';
const fateBootLabels=document.documentElement.lang==='zh'
  ?{engine:'正在准备星空画面',app:'正在载入你的专属页面',slow:'网络有点慢，请稍候',failed:'页面加载失败，请检查网络后重试'}
  :{engine:'กำลังเตรียมภาพดวงดาว',app:'กำลังเปิดหน้าส่วนตัวของคุณ',slow:'เครือข่ายช้าเล็กน้อย กรุณารอสักครู่',failed:'โหลดไม่สำเร็จ กรุณาตรวจสอบเครือข่ายแล้วลองใหม่'};
let fateBootFinished=false;
const fateBootSlow=setTimeout(()=>{if(!fateBootFinished){window.fateBoot.stage('slow');const button=document.getElementById('fate-startup-retry');if(button)button.hidden=false;}},12000);
window.fateBoot={
  stage(stage){const status=document.getElementById('fate-startup-status');if(status)status.textContent=fateBootLabels[stage]||fateBootLabels.app;},
  fail(){if(fateBootFinished)return;clearTimeout(fateBootSlow);this.stage('failed');const button=document.getElementById('fate-startup-retry');if(button)button.hidden=false;},
  ready(){if(fateBootFinished)return;fateBootFinished=true;clearTimeout(fateBootSlow);document.getElementById('fate-startup')?.remove();performance.mark('fate-app-ready');window.dispatchEvent(new Event('fate-app-ready'));}
};
document.getElementById('fate-startup-retry')?.addEventListener('click',()=>location.reload());
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
    if(target.protocol!=='https:'||target.hostname!=='www.thaiepay.com') throw new Error('Invalid payment URL');
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
