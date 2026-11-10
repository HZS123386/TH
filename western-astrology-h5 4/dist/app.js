'use strict';
import { createElement } from 'react';
import { createRoot } from 'react-dom/client';
import { ThaiReadingExperience } from '../src/components/ThaiReadingExperience';
const copy = {
  th: {
    persona: 'หมอดู AI ส่วนตัวของคุณ',
    formTitle: 'อ่านแนวโน้มชีวิตจากข้อมูลเกิดของคุณ',
    formCaption: 'อ่านลักษณะส่วนตัวฟรี แล้วเปิดอ่านดวงเจ็ดหัวข้อ',
    disclaimer: 'คำอ่านสร้างด้วย AI เพื่อความบันเทิงและสำรวจตัวเอง',
    topics: {
      love: { title: 'วิเคราะห์ดวงชะตา', sub: 'ความรัก · คู่ครอง · ความสัมพันธ์' },
      life: {
        eyebrow: 'ดวงรายปี · พื้นดวง · ความรัก',
        title: 'ชีวิตคู่มั่นคงไหม?<br><span>เมื่อไหร่จะพ้นช่วงขาลง?</span>',
        sub: 'เข้าใจแนวโน้มชีวิตและสิ่งที่ควรใส่ใจ',
      },
    },
  },
  zh: {
    persona: '你的专属 AI 占星师',
    formTitle: '从出生时刻，读懂你的运程',
    formCaption: '先免费了解个人特点，再解锁七大运程主题',
    disclaimer: '解读由 AI 生成，仅供娱乐与自我探索',
    topics: {
      love: { title: '运程解析', sub: '婚姻情感 · 相处沟通 · 姻缘倾向' },
      life: {
        eyebrow: '年度运程 · 格局解读 · 婚姻情感',
        title: '婚姻稳不稳？<br><span>低谷还要熬多久？</span>',
        sub: '看清人生起伏，读懂下一程',
      },
    },
  },
};
let lang=new URLSearchParams(location.search).get('lang')==='zh'?'zh':'th';
let topic=['love','career','life'].includes(new URLSearchParams(location.search).get('topic'))?new URLSearchParams(location.search).get('topic'):'life';
const readingIds = ['overview', 'annual', 'money', 'love', 'work', 'family'];
let selectedReading = new URLSearchParams(location.search).get('reading');
if (!readingIds.includes(selectedReading)) selectedReading = { life: 'overview', love: 'love', career: 'work' }[topic];
topic = selectedReading === 'love' ? 'love' : 'life';
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
  document.title = lang === 'zh' ? '运程解析 · FATE' : 'วิเคราะห์ดวงชะตา · FATE';
  document.querySelectorAll('[data-t]').forEach(el => { el.innerHTML = c[el.dataset.t] ?? ''; });
  document.querySelectorAll('[data-lang]').forEach(el => { el.classList.toggle('active', el.dataset.lang === lang); el.setAttribute('aria-pressed', String(el.dataset.lang === lang)); });
  $('#hero-eyebrow').textContent = t.eyebrow ?? landing.thaiLabel;
  $('#hero-title').innerHTML = t.title;
  const heroSub = $('#hero-sub');
  heroSub.innerHTML = t.sub;
  heroSub.hidden = !t.sub;
  $('.portrait').alt = landing.portraitAlt;
  readingRoot.render(createElement(ThaiReadingExperience, { language: lang }));
  const url = new URL(location.href);
  url.searchParams.set('lang', lang); url.searchParams.set('topic', topic); url.searchParams.set('reading', selectedReading);
  history.replaceState(null, '', url);
}
document.querySelectorAll('[data-lang]').forEach(b=>b.addEventListener('click',()=>{onLanguageChange(b.dataset.lang)}));
render();
