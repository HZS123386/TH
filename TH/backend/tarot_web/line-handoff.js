(function(root){
  'use strict';
  const addFriendUrl='https://line.me/R/ti/p/TrGGcMWmuV';
  const claimPattern=/^T[1-9][0-9]{4}$/;

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

  root.TarotLine=Object.freeze({addFriendUrl,qrPath:'assets/line-friend-qr.jpg',receiptCode,newRequestKey,register});
})(typeof window==='undefined'?globalThis:window);
