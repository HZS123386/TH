'use strict';
import { createElement } from 'react';
import { createRoot } from 'react-dom/client';
import { ThaiReadingExperience } from '../src/components/ThaiReadingExperience';
import { lifeCopy } from '../src/lib/lifeReport';
const copy = {
  th: {
    persona: 'หมอดู AI ส่วนตัวของคุณ',
    formTitle: 'ก้าวต่อไป ดวงดาวบอกอะไร?',
    formCaption: 'กรอกข้อมูลเกิดเพื่อดูดวงเฉพาะคุณ',
    disclaimer: 'คำอ่านสร้างด้วย AI เพื่อความบันเทิงและสำรวจตัวเอง',
    topics: {
      love: { title: 'ทำไมความรัก<br><span>ถึงวนกลับมาที่เดิม?</span>', sub: 'เข้าใจรูปแบบความรัก และสิ่งที่ใจต้องการ<br>ผ่านแผนที่ดวงดาวของคุณ' },
      life: {
        eyebrow: 'ชีวิตคู่ · ดวงการเงิน · จังหวะชีวิต',
        title: 'ชีวิตคู่มั่นคงไหม?<br><span>เมื่อไหร่จะพ้นช่วงขาลง?</span>',
        sub: '',
      },
    },
  },
  zh: {
    persona: '你的专属 AI 占星师',
    formTitle: '下一程，星盘怎么说？',
    formCaption: '填写出生信息，开启专属解读。',
    disclaimer: '解读由 AI 生成，仅供娱乐与自我探索',
    topics: {
      love: { title: '为什么每段感情<br><span>总在重复同一种困局？</span>', sub: '从你的星盘，读懂感情里的习惯<br>也看见内心真正想要的爱' },
      life: {
        eyebrow: '婚姻 · 财运 · 人生起伏',
        title: '婚姻稳不稳？<br><span>低谷还要熬多久？</span>',
        sub: '',
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
  document.title = `${lifeCopy[lang].title} · ASTRO AI`;
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
