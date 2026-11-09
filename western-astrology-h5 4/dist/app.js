'use strict';
import { createElement } from 'react';
import { createRoot } from 'react-dom/client';
import { ThaiReadingExperience } from '../src/components/ThaiReadingExperience';
const copy = {
  th: {
    persona: 'ผู้ช่วยโหราศาสตร์ AI',
    formTitle: 'เริ่มจากข้อมูลวันเกิดของคุณ',
    formCaption: 'แผนที่ดวงดาวหนึ่งเดียว จากช่วงเวลาที่คุณเกิด',
    disclaimer: 'คำอ่านสร้างด้วย AI เพื่อความบันเทิงและสำรวจตัวเอง',
    topics: {
      love: { title: 'ทำไมความรัก<br><span>ถึงวนกลับมาที่เดิม?</span>', sub: 'เข้าใจรูปแบบความรัก และสิ่งที่ใจต้องการ<br>ผ่านแผนที่ดวงดาวของคุณ' },
      career: { title: 'อยากเปลี่ยนงาน<br><span>แต่ไม่รู้จะไปทางไหน?</span>', sub: 'สำรวจจุดแข็งและสไตล์การทำงาน<br>ผ่านแผนที่ดวงดาวของคุณ' },
      life: { title: 'ชีวิตช่วงนี้<br><span>ควรโฟกัสเรื่องไหนดี?</span>', sub: 'เข้าใจตัวเอง ทั้งความรักและการงาน<br>ผ่านแผนที่ดวงดาวของคุณ' },
    },
  },
  zh: {
    persona: '你的 AI 占星师',
    formTitle: '从你的出生时刻开始',
    formCaption: '解读属于你的星盘，看见更真实的自己',
    disclaimer: '解读由 AI 生成，仅供娱乐与自我探索',
    topics: {
      love: { title: '为什么每段感情<br><span>总在重复同一种困局？</span>', sub: '从你的星盘，读懂感情里的习惯<br>也看见内心真正想要的爱' },
      career: { title: '想换一份工作<br><span>却不知道该往哪里走？</span>', sub: '从你的星盘，看见自身优势<br>找到更适合你的工作方式' },
      life: { title: '现在的人生阶段<br><span>该把精力放在哪里？</span>', sub: '用星盘探索你的性格、感情与事业<br>找到属于自己的生活节奏' },
    },
  },
};
let lang=new URLSearchParams(location.search).get('lang')==='zh'?'zh':'th';
let topic=['love','career','life'].includes(new URLSearchParams(location.search).get('topic'))?new URLSearchParams(location.search).get('topic'):'life';
const readingIds = ['overview', 'annual', 'money', 'love', 'work', 'family'];
let selectedReading = new URLSearchParams(location.search).get('reading');
if (!readingIds.includes(selectedReading)) selectedReading = { life: 'overview', love: 'love', career: 'work' }[topic];
topic = selectedReading === 'work' ? 'career' : selectedReading === 'love' ? 'love' : 'life';
const $=s=>document.querySelector(s);
const readingRoot = createRoot($('#thai-reading-root'));
const landingCopy = {
  zh: { thaiLabel: '泰式占星', portraitAlt: '身着紫色斗篷的 AI 占星师与金色星盘' },
  th: { thaiLabel: 'โหราศาสตร์ไทย', portraitAlt: 'ผู้ช่วยโหราศาสตร์ AI ในเสื้อคลุมสีม่วงกับวงจักรราศีสีทอง' },
};
function onLanguageChange(value) { lang = value; render(); }
function render() {
  const c = copy[lang], t = c.topics[topic], landing = landingCopy[lang];
  document.documentElement.lang = lang;
  document.title = lang === 'zh' ? '人生报告 · ASTRO AI' : 'ASTRO · AI โหราศาสตร์ไทยของคุณ';
  document.querySelectorAll('[data-t]').forEach(el => { el.innerHTML = landing[el.dataset.t] ?? c[el.dataset.t] ?? ''; });
  document.querySelectorAll('[data-lang]').forEach(el => { el.classList.toggle('active', el.dataset.lang === lang); el.setAttribute('aria-pressed', String(el.dataset.lang === lang)); });
  $('#hero-title').innerHTML = t.title;
  $('#hero-sub').innerHTML = t.sub;
  $('.portrait').alt = landing.portraitAlt;
  readingRoot.render(createElement(ThaiReadingExperience, { language: lang, onLanguageChange }));
  const url = new URL(location.href);
  url.searchParams.set('lang', lang); url.searchParams.set('topic', topic); url.searchParams.set('reading', selectedReading);
  history.replaceState(null, '', url);
}
document.querySelectorAll('[data-lang]').forEach(b=>b.addEventListener('click',()=>{onLanguageChange(b.dataset.lang)}));
render();
