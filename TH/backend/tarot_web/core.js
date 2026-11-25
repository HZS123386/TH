/* Local demo only: no computed prediction, payment provider or backend. */
(function(root){
  const spreads={
    single:{
      id:'single',count:1,
      name:{zh:'单牌指引',th:'ไพ่ใบเดียวชี้แนวทาง'},
      description:{zh:'围绕一件眼前小事，用一张牌找到此刻可以尝试的角度。',th:'ใช้ไพ่หนึ่งใบมองเรื่องตรงหน้า และหาแนวทางเล็ก ๆ ที่ลองทำได้ตอนนี้'},
      positions:[{zh:'此刻的指引',th:'แนวทางสำหรับตอนนี้'}]
    },
    relationship:{
      id:'relationship',count:3,
      name:{zh:'三张解析牌阵',th:'ผังไพ่สามใบ'},
      description:{zh:'从现状、卡点与建议三个角度，梳理你最在意的事。',th:'มองสถานการณ์ สิ่งที่ติดค้าง และคำแนะนำ เพื่อทำความเข้าใจเรื่องที่คุณใส่ใจ'} ,
      positions:[{zh:'现状',th:'สถานการณ์ตอนนี้'},{zh:'卡点',th:'สิ่งที่ติดค้าง'},{zh:'建议',th:'คำแนะนำ'}]
    },
    decision:{
      id:'decision',count:5,
      name:{zh:'二选一牌阵',th:'ไพ่เปรียบเทียบสองทางเลือก'},
      description:{zh:'把两个方向的吸引与代价放在一起比较，帮助你整理自己的取舍。',th:'เปรียบเทียบสิ่งที่ดึงดูดและสิ่งที่ต้องแลกของสองทางเลือก เพื่อช่วยจัดระเบียบการตัดสินใจของคุณ'},
      positions:[{zh:'当前处境',th:'สถานการณ์ปัจจุบัน'},{zh:'方向一的吸引',th:'สิ่งที่ดึงดูดในทางเลือกแรก'},{zh:'方向一的代价',th:'สิ่งที่ต้องแลกในทางเลือกแรก'},{zh:'方向二的吸引',th:'สิ่งที่ดึงดูดในทางเลือกที่สอง'},{zh:'方向二的代价',th:'สิ่งที่ต้องแลกในทางเลือกที่สอง'}]
    }
  };
  function matchSpread(question){
    const text=String(question||'').trim().toLowerCase();
    // Explicit alternatives take priority over "today". A bare "怎么选择" is not enough.
    const explicitChoice=/二选一|两难|要不要|该不该|(?:辞职|离职|跳槽|换工作|分手|复合|表白|放下|继续|联系|离开|接受|拒绝).{0,8}(?:吗|么|好不好)|是否.{0,24}(?:辞职|离职|分手|复合|表白|继续|联系|离开)|选(?:择)?哪(?:一|个|条|种|边)|两个(?:方向|选择|选项|方案)|两(?:条路|种选择)|(?:继续|坚持).{0,18}(?:或|还是|与|和).{0,8}(?:放下|放弃|结束|分手)|(?:放下|放弃|结束|分手).{0,18}(?:或|还是|与|和).{0,8}(?:继续|坚持)|ลาออก|เลือก.{0,48}(?:ระหว่าง|หรือ)|(?:ควร|จะ).{0,48}(?:หรือไม่|ดีไหม)|(?:ไปต่อ|อยู่ต่อ).{0,30}(?:หรือ|พอ|หยุด|ออก)|สองทางเลือก|สองตัวเลือก|ตัดสินใจระหว่าง/iu.test(text);
    const chineseAlternative=/(?:继续|放下|分手|复合|辞职|留下|跳槽|表白|主动|等待|联系|接受|拒绝|离开|换工作|坚持|放弃|选|选择|方案|方向).{0,24}还是.{1,28}/u.test(text);
    const thaiAlternative=/(?:ไปต่อ|เลิก|อยู่ต่อ|จากไป|เริ่ม|หยุด|บอก|รอ|ติดต่อ|รับ|ปฏิเสธ).{0,24}หรือ.{1,28}/u.test(text);
    if(explicitChoice||chineseAlternative||thaiAlternative)return {spreadId:'decision',reason:{zh:'问题里有明确的取舍或两个方向，适合把各自的吸引与代价放在一起比较。',th:'คำถามมีการตัดสินใจหรือสองทางเลือกชัดเจน จึงเหมาะกับการเปรียบเทียบสิ่งที่ดึงดูดและสิ่งที่ต้องแลกของแต่ละทาง'}};
    if(/今天|此刻|今日|当下|一句|提醒|现在先做什么|วันนี้|ตอนนี้|ขณะนี้|เตือนใจ|ข้อความสั้น|คำแนะนำสั้น/iu.test(text))return {spreadId:'single',reason:{zh:'问题聚焦今天、此刻或一个提醒，用一张牌集中看眼前可以尝试的一步。',th:'คำถามเน้นวันนี้ ตอนนี้ หรือข้อเตือนใจ จึงใช้ไพ่หนึ่งใบเพื่อมองก้าวเล็ก ๆ ที่ลองทำได้ตรงหน้า'}};
    return {spreadId:'relationship',reason:{zh:'先从现状、卡点和建议梳理问题，三张解析牌阵能提供三个清晰的观察角度。',th:'เริ่มทำความเข้าใจจากสถานการณ์ สิ่งที่ติดค้าง และคำแนะนำ ผังไพ่สามใบจึงให้มุมมองที่ชัดเจนสามด้าน'}};
  }
  function topicFor(text, spreadId=matchSpread(text).spreadId){
    if(/工作|事业|职业|升职|跳槽|辞职|离职|项目|งาน|อาชีพ|ลาออก/.test(text))return 'work';
    if(/沟通|争执|吵|表达|สื่อสาร|ทะเลาะ|คุย/.test(text))return 'communication';
    if(/单身|相遇|โสด|คนใหม่/.test(text))return 'single';
    if(/关系|感情|爱情|喜欢|复合|分手|他|她|ความรัก|ความสัมพันธ์|เขา/.test(text))return spreadId==='decision'?'decision':'connection';
    return 'general';
  }
  function clarifyQuestion(question){
    // Only exact broad phrases need a follow-up; short but specific questions pass through.
    const normalized=String(question??'').trim().toLowerCase().replace(/[\s\p{P}]/gu,'');
    const matches=(zh,th)=>zh.includes(normalized)||th.some(value=>[value,value+'ค่ะ',value+'ครับ'].some(x=>x.replace(/[\s\p{P}]/gu,'')===normalized));
    const currentRelationship={label:{zh:'目前这段关系',th:'ความสัมพันธ์ตอนนี้'},question:{zh:'目前这段关系里，我最需要看清什么？',th:'ในความสัมพันธ์นี้ ฉันควรทำความเข้าใจเรื่องใดให้ชัดขึ้น?'}};
    const currentWork={label:{zh:'目前工作里的困惑',th:'เรื่องที่ติดใจในงาน'},question:{zh:'目前工作里的困惑，我可以怎样理清下一步？',th:'ฉันอยากเข้าใจปัญหาในงานให้ชัดขึ้น ควรเริ่มอย่างไร?'}};
    if(matches(['感情','爱情','想问感情','想咨询感情','感情问题'],['ความรัก','เรื่องความรัก','อยากถามเรื่องความรัก','ปรึกษาความรัก','ปัญหาความรัก','ความสัมพันธ์','เรื่องความสัมพันธ์']))return {
      id:'relationship',prompt:{zh:'关于感情，你更想聊哪一件事？',th:'เรื่องความรัก คุณอยากคุยเรื่องไหนมากที่สุด?'},
      options:[currentRelationship,
        {label:{zh:'准备新的相遇',th:'เปิดใจพบคนใหม่'},question:{zh:'我想准备好新的相遇，可以先做些什么？',th:'ฉันอยากเปิดใจพบคนใหม่ ควรเริ่มอย่างไร?'}},
        {label:{zh:'继续，还是放下',th:'ไปต่อหรือพอแค่นี้'},question:{zh:'这段关系，我该继续还是放下？',th:'ฉันควรไปต่อกับความสัมพันธ์นี้ หรือพอแค่นี้?'}}]
    };
    if(matches(['事业','工作','想问事业'],['งาน','การงาน','เรื่องงาน','อาชีพ','อยากถามเรื่องงาน','อยากปรึกษาเรื่องงาน','ปรึกษาเรื่องงาน']))return {
      id:'work',prompt:{zh:'关于工作，你更在意哪一个问题？',th:'เรื่องงาน ตอนนี้คุณอยากมองประเด็นไหนให้ชัด?'},
      options:[currentWork,{label:{zh:'是否换一份工作',th:'เปลี่ยนงานดีไหม'},question:{zh:'我该继续目前的工作，还是考虑换工作？',th:'ฉันควรลาออกไปหางานใหม่ หรืออยู่ที่งานเดิม?'}}]
    };
    if(matches(['运势','算一下','看看','帮我看看','不知道问什么','咨询'],['ดวง','ดูดวง','ดูให้หน่อย','ช่วยดูให้หน่อย','ไม่รู้จะถามอะไร','ปรึกษา','อยากปรึกษา']))return {
      id:'general',prompt:{zh:'可以从一件在意的事开始，你想先聊什么？',th:'เริ่มจากเรื่องที่คุณใส่ใจได้ อยากคุยเรื่องไหนก่อน?'},
      options:[{label:{zh:'关系里的心事',th:'เรื่องความสัมพันธ์'},question:{...currentRelationship.question}},
        {label:{zh:'事业与工作',th:'งานและอาชีพ'},question:{...currentWork.question}},
        {label:{zh:'当下的一点提醒',th:'คำแนะนำสำหรับตอนนี้'},question:{zh:'今天，我最需要留意什么？',th:'วันนี้ฉันควรใส่ใจอะไรเป็นพิเศษ?'}}]
    };
    return null;
  }
  function randomInt(max){if(!Number.isInteger(max)||max<1)throw new Error('Invalid random range');const limit=Math.floor(4294967296/max)*max;let n;do{const v=new Uint32Array(1);crypto.getRandomValues(v);n=v[0]}while(n>=limit);return n%max}
  function shuffle(){const a=Array.from({length:22},(_,id)=>({id,reversed:randomInt(2)===1}));for(let i=a.length-1;i>0;i--){const j=randomInt(i+1);[a[i],a[j]]=[a[j],a[i]]}return a}
  function validCards(cards,n){return Array.isArray(cards)&&cards.length===n&&cards.every(c=>c&&typeof c==='object'&&Number.isInteger(c.id)&&c.id>=0&&c.id<22&&typeof c.reversed==='boolean')&&new Set(cards.map(c=>c.id)).size===n}
  function validReport(r){const spreadId=r?.spreadId===undefined?'relationship':r.spreadId;const spread=Object.prototype.hasOwnProperty.call(spreads,spreadId)?spreads[spreadId]:null;return !!r&&!!spread&&typeof r.id==='string'&&/^MIRA-[A-Z0-9-]+$/.test(r.id)&&typeof r.topic==='string'&&typeof r.question==='string'&&r.question.length<=180&&Number.isFinite(r.created)&&validCards(r.cards,spread.count)&&typeof r.unlocked==='boolean'}
  function makeReport(topic,question,cards,spreadId='relationship'){const spread=Object.prototype.hasOwnProperty.call(spreads,spreadId)?spreads[spreadId]:null;if(!spread)throw new Error('Unknown spread');if(!validCards(cards,spread.count))throw new Error('Select '+spread.count+' different cards');return {id:'MIRA-'+Date.now().toString(36).toUpperCase()+'-'+randomInt(1679616).toString(36).padStart(4,'0').toUpperCase(),topic,question:String(question||'').trim().slice(0,180),spreadId,cards:cards.map(c=>({...c})),created:Date.now(),unlocked:false,plan:[false,false,false],messages:[]}}
  root.TarotCore={randomInt,shuffle,validCards,validReport,makeReport,spreads,matchSpread,topicFor,clarifyQuestion};
})(typeof window==='undefined'?globalThis:window);
