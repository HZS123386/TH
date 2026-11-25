/* LINE recipient verified through the report CTA at https://ipplay.top/. */
(function(root){
  'use strict';
  const addFriendUrl='https://line.me/ti/p/TrGGcMWmuV';
  // A stable display reference, not a server-side lookup key. The copied message
  // carries the original report ID, question and cards for manual fulfilment.
  function receiptCode(report){
    let value=2166136261;
    for(const character of String(report.id)){value=Math.imul(value^character.charCodeAt(0),16777619)}
    return String(100000+(value>>>0)%900000);
  }
  function compose(report,lang,content,core){
    const th=lang==='th',local=value=>typeof value==='string'?value:value?.[th?'th':'zh']||value?.zh||'';
    const spread=core.spreads[report.spreadId||'relationship'];
    const date=new Date(report.created);
    const stamp=Number.isFinite(date.getTime())?date.toISOString():'';
    const lines=[
      'FATE / MIRA',
      (th?'รหัสรับรายงาน: ':'领取编号：')+receiptCode(report),
      (th?'คำถาม: ':'咨询问题：')+report.question,
      (th?'ผังไพ่: ':'本次牌阵：')+local(spread.name),
      ...report.cards.map((card,index)=>{
        const detail=content.cards.find(item=>item.id===card.id);
        return (index+1)+'. '+local(spread.positions[index])+' / '+local(detail.name)+' / '+(card.reversed?(th?'กลับหัว':'逆位'):(th?'ตั้งตรง':'正位'));
      }),
      '',(th?'รหัสอ้างอิง: ':'参考编号：')+report.id,
      (th?'สร้างเมื่อ: ':'生成时间：')+stamp,
      (th?'ภาษา: ไทย':'语言：简体中文'),
      '',th?'กรุณาส่งคำอ่านฉบับเต็มจากคำถามและไพ่ชุดนี้ให้ฉันทาง LINE ขอบคุณ':'请根据以上问题和牌阵，通过 LINE 发送完整解读，谢谢。'
    ];
    return lines.join('\n');
  }
  root.TarotLine=Object.freeze({addFriendUrl,qrPath:'assets/line-qr.png',receiptCode,compose});
})(typeof window==='undefined'?globalThis:window);
