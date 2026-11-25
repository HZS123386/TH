/* A visibly labelled simulation, never a live-user statistic or waiting gate. */
(() => {
  'use strict';
  const steps = [3, 5, 7, 9, 10, 12];
  let step = 0, timer = null;
  const nodes = () => [...document.querySelectorAll('.queue-status')];
  function pause() { if (timer !== null) clearTimeout(timer); timer = null; }
  function paint(animate = false) {
    for (const button of nodes()) {
      const number = button.querySelector('.queue-count');
      if (!number) continue;
      number.textContent = String(steps[step]);
      button.setAttribute('aria-label', button.dataset.queuePrefix + steps[step] + button.dataset.queueSuffix);
      number.classList.remove('queue-count-change');
      if (animate && !window.matchMedia?.('(prefers-reduced-motion: reduce)').matches && !document.body.classList.contains('motion-paused')) {
        void number.offsetWidth;
        number.classList.add('queue-count-change');
      }
    }
  }
  function schedule() {
    if (timer !== null || document.hidden || !nodes().length || step >= steps.length - 1) return;
    timer = setTimeout(() => {
      timer = null;
      if (document.hidden || !nodes().length) return;
      step++;
      paint(true);
      schedule();
    }, 1600);
  }
  function mount() { paint(); if (document.hidden || !nodes().length) pause(); else schedule(); }
  document.addEventListener('visibilitychange', mount);
  window.addEventListener('pagehide', pause);
  window.addEventListener('pageshow', mount);
  window.TarotQueue = { getCount: () => steps[step], mount };
})();
