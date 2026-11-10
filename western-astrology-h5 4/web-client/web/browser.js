const fatePerfEnabled=new URLSearchParams(location.search).get('startup')==='1';
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
    if(!fatePerfEnabled)return;
    requestAnimationFrame(()=>console.debug('[FATE H5 performance] '+JSON.stringify({page,readyMs:Math.round(performance.now()),resources:performance.getEntriesByType('resource').filter(e=>/api\/|main\.dart|skwasm|canvaskit|fonts\/|astrologer/.test(e.name)).map(e=>({name:new URL(e.name).pathname.replace(/(life-reports\/)\w{8,}/,'$1:id'),startMs:Math.round(e.startTime),endMs:Math.round(e.responseEnd),bytes:e.transferSize}))})));
  }
};
