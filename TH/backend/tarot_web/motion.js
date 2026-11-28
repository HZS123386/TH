/* FATE · visual card rituals. All state and randomness remain in app/core. */
(() => {
  'use strict';
  let enabled = true;
  let active = null;
  const preference = window.matchMedia?.('(prefers-reduced-motion: reduce)');
  const canMove = () => enabled && !preference?.matches &&
    typeof Element !== 'undefined' && typeof Element.prototype.animate === 'function';

  function cancel() {
    if (!active) return;
    const session = active;
    active = null;
    session.cancelled = true;
    for (const entry of [...session.animations]) {
      try { entry.animation.cancel(); } catch (_) {}
      entry.settle(false);
    }
    session.clean();
  }

  function setEnabled(value) {
    enabled = Boolean(value);
    document.body.classList.toggle('motion-paused', !enabled);
    if (!enabled) cancel();
  }

  function session() {
    const cleanups = [];
    let cleaned = false;
    const state = {
      cancelled: false,
      animations: new Set(),
      cleanup(fn) { cleanups.push(fn); },
      clean() {
        if (cleaned) return;
        cleaned = true;
        for (const fn of cleanups.reverse()) {
          try { fn(); } catch (_) {}
        }
      }
    };
    active = state;
    return state;
  }

  function play(state, element, frames, options) {
    if (state.cancelled || !element?.isConnected) return Promise.resolve(false);
    return new Promise(resolve => {
      let animation;
      try { animation = element.animate(frames, options); }
      catch (_) { resolve(false); return; }
      let settled = false;
      const entry = {
        animation,
        settle(completed) {
          if (settled) return;
          settled = true;
          state.animations.delete(entry);
          animation.onfinish = animation.oncancel = null;
          resolve(completed);
        }
      };
      state.animations.add(entry);
      animation.onfinish = () => {
        entry.settle(true);
        // The default CSS is also the final frame. Remove the fill effect so
        // future hover/idle motion and detached elements have no held animation.
        try { animation.cancel(); } catch (_) {}
      };
      animation.oncancel = () => entry.settle(false);
    });
  }

  async function run(work) {
    cancel();
    if (!canMove()) return false;
    const state = session();
    try {
      await work(state);
      return !state.cancelled;
    } finally {
      state.clean();
      if (active === state) active = null;
    }
  }

  function shuffle(deck) {
    return run(async state => {
      if (!deck?.isConnected) return;
      const cards = [...deck.querySelectorAll('.deck-card:not(.selected)')];
      if (!cards.length) return;
      const bounds = deck.getBoundingClientRect();
      // Read all positions before animating or changing any card styles.
      const positions = cards.map(card => card.getBoundingClientRect());
      deck.classList.add('motion-active');
      state.cleanup(() => deck.classList.remove('motion-active'));
      const middleX = bounds.left + bounds.width / 2;
      const middleY = bounds.top + bounds.height * .48;
      const travel = Math.min(54, bounds.width * .16);
      await Promise.all(cards.map((card, index) => {
        const rect = positions[index];
        const x = middleX - (rect.left + rect.width / 2);
        const y = middleY - (rect.top + rect.height / 2);
        const side = index % 2 ? 1 : -1;
        const tilt = (index % 5 - 2) * 1.8;
        const oldZ = card.style.zIndex;
        card.style.zIndex = String(index + 2);
        state.cleanup(() => { card.style.zIndex = oldZ; });
        return play(state, card, [
          { transform: 'translate(0,0) rotate(0deg)', offset: 0 },
          { transform: `translate(${x}px,${y}px) rotate(${tilt}deg)`, offset: .28 },
          { transform: `translate(${x + travel * side}px,${y - 12}px) rotate(${side * 13}deg)`, offset: .51 },
          { transform: `translate(${x}px,${y}px) rotate(${tilt}deg)`, offset: .69 },
          { transform: 'translate(0,0) rotate(0deg)', offset: 1 }
        ], {
          duration: 460,
          delay: (index % 6) * 8 + Math.floor(index / 6) * 5,
          easing: 'cubic-bezier(.45,0,.2,1)',
          fill: 'both'
        });
      }));
    });
  }

  function pick(source, target) {
    return run(async state => {
      if (!source?.isConnected || !target?.isConnected) return;
      const from = source.getBoundingClientRect();
      const to = target.getBoundingClientRect();
      const back = source.querySelector('.tarot-back');
      if (!back || from.width <= 0 || from.height <= 0 || to.width <= 0 || to.height <= 0) return;
      const width = back.offsetWidth;
      const height = back.offsetHeight;
      if (!width || !height) return;
      const angle = Number.parseFloat(source.style.getPropertyValue('--fan-angle')) || 0;
      const drop = Number.parseFloat(source.style.getPropertyValue('--fan-drop')) || 0;
      const centerX = from.left + from.width / 2;
      const centerY = from.top + from.height / 2 + drop;
      const clone = document.createElement('div');
      clone.className = 'tarot-flight';
      clone.setAttribute('aria-hidden', 'true');
      clone.style.cssText = `left:${centerX - width / 2}px;top:${centerY - height / 2}px;width:${width}px;height:${height}px`;
      clone.append(back.cloneNode(true));
      // The source currently contains no IDs, but keep this clone safe if its
      // decorative markup later gains any ID or interactive attribute.
      for (const node of clone.querySelectorAll('[id],[data-action],[tabindex]')) {
        node.removeAttribute('id');
        node.removeAttribute('data-action');
        node.removeAttribute('tabindex');
      }
      document.body.append(clone);
      source.classList.add('is-lifting');
      target.classList.add('is-receiving');
      state.cleanup(() => {
        clone.remove();
        source.classList.remove('is-lifting');
        target.classList.remove('is-receiving');
      });
      const x = to.left + to.width / 2 - centerX;
      const y = to.top + to.height / 2 - centerY;
      const sx = target.clientWidth / width;
      const sy = target.clientHeight / height;
      const lift = Math.min(18, Math.abs(y) * .12 + 6);
      // Pass the slot by up to eight pixels before settling into it.
      const overshoot = Math.min(.12, 8 / Math.max(1, Math.hypot(x, y)));
      await play(state, clone, [
        {
          transform: `translate(0,0) rotate(${angle}deg) scale(1)`,
          offset: 0, easing: 'cubic-bezier(.25,.4,.35,1)'
        },
        {
          transform: `translate(${x * .16}px,${y * .16 - lift}px) rotate(${angle * .65}deg) scale(1.04)`,
          offset: .24, easing: 'cubic-bezier(.45,.04,.23,1)'
        },
        {
          transform: `translate(${x * (1 + overshoot)}px,${y * (1 + overshoot)}px) rotate(${-angle * .18}deg) scale(${sx},${sy})`,
          offset: .77, easing: 'cubic-bezier(.2,.75,.35,1)'
        },
        { transform: `translate(${x}px,${y}px) rotate(0deg) scale(${sx},${sy})`, offset: 1 }
      ], { duration: 420, fill: 'both' });
    });
  }

  function reveal(spread) {
    return run(async state => {
      if (!spread?.isConnected) return;
      const cards = [...spread.querySelectorAll('.flip-inner')];
      spread.classList.add('is-revealing');
      state.cleanup(() => spread.classList.remove('is-revealing'));
      await Promise.all(cards.map((card, index) => play(state, card, [
        { transform: 'rotateY(180deg) translateY(0)', offset: 0 },
        { transform: 'rotateY(88deg) translateY(-9px)', offset: .45 },
        { transform: 'rotateY(0deg) translateY(0)', offset: 1 }
      ], {
        duration: 440,
        delay: index * 70,
        easing: 'cubic-bezier(.22,.61,.36,1)',
        fill: 'both'
      })));
    });
  }

  preference?.addEventListener?.('change', event => {
    if (event.matches) cancel();
  });
  window.addEventListener('pagehide', cancel);
  window.TarotMotion = Object.freeze({ shuffle, pick, reveal, cancel, setEnabled });
})();
