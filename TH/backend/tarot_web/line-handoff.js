(function(root){
  'use strict';
  const addFriendUrl='https://line.me/ti/p/TrGGcMWmuV';
  const claimPattern=/^(?:T[1-9][0-9]{4}|T-(?:[0-9A-HJKMNP-TV-Z]{12}|[1-9][0-9]{5,17}))$/;

  function receiptCode(report){
    const code=report.lineReceipt?.claimCode;
    return typeof code==='string'&&claimPattern.test(code)?code:'';
  }

  function newRequestKey(){
    return Array.from(crypto.getRandomValues(new Uint8Array(16)),byte=>byte.toString(16).padStart(2,'0')).join('');
  }

  async function register(report,language){
    const controller=new AbortController();
    const timeout=setTimeout(()=>controller.abort(),12000);
    try{
      const response=await fetch('/api/tarot/receipts',{
        method:'POST',cache:'no-store',signal:controller.signal,
        headers:{'Content-Type':'application/json','Accept-Language':language},
        body:JSON.stringify({
          request_key:report.lineReceipt.requestKey,report_id:report.id,question:report.question,
          topic:report.topic,spread_id:report.spreadId||'relationship',language,
          cards:report.cards.map(({id,reversed})=>({id,reversed})),
        }),
      });
      if(!response.ok)throw new Error('Tarot registration failed');
      const {claim_code:code}=await response.json();
      if(typeof code!=='string'||!claimPattern.test(code))throw new Error('Invalid tarot receipt');
      return code;
    }finally{
      clearTimeout(timeout);
    }
  }

  function manualMessage(report,language){
    const th=language==='th';
    const local=value=>value[language]||value.zh;
    const spread=window.TarotCore.spreads[report.spreadId||'relationship'];
    const lines=[
      'FATE / MIRA',
      (th?'คำถาม: ':'咨询问题：')+report.question,
      (th?'ผังไพ่: ':'本次牌阵：')+local(spread.name),
      ...report.cards.map((card,index)=>{
        const detail=window.TAROT_CONTENT.cards.find(item=>item.id===card.id);
        const side=card.reversed?(th?'กลับหัว':'逆位'):(th?'ตั้งตรง':'正位');
        return (index+1)+'. '+local(spread.positions[index])+' / '+local(detail.name)+' / '+side;
      }),
      (th?'รหัสอ้างอิง: ':'参考编号：')+report.id,
      th?'ภาษา: ไทย':'语言：简体中文',
    ];
    return lines.join('\n');
  }

  root.TarotLine=Object.freeze({addFriendUrl,qrPath:'assets/line-qr.png',receiptCode,newRequestKey,register,manualMessage});
})(typeof window==='undefined'?globalThis:window);
