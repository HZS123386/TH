/* FATE · the current piano track, autoplay with a user-gesture fallback. */
(() => {
  'use strict';
  const source = 'assets/tarot-piano-v22.mp3';
  const AudioClass = window.Audio;
  let media = null;
  let handlers = null;
  let wanted = true;
  let playing = false;
  let starting = false;
  let gesturePending = false;
  let pageSuspended = false;
  let destroyed = false;
  let generation = 0;
  const getState = () => ({ playing, supported: !destroyed && typeof AudioClass === 'function' });
  function notify() {
    window.dispatchEvent(new CustomEvent('tarot-audio-state', { detail: getState() }));
  }
  function setPlaying(value) {
    if (playing === value) return;
    playing = value;
    notify();
  }
  function pause() {
    try { media?.pause(); } catch (_) {}
    setPlaying(false);
  }
  function release() {
    const old = media;
    media = null;
    if (!old) return;
    for (const [name, handler] of Object.entries(handlers || {})) old.removeEventListener(name, handler);
    handlers = null;
    try { old.pause(); old.removeAttribute('src'); old.load(); } catch (_) {}
  }
  function ensureMedia() {
    if (media?.error) release();
    if (media) return media;
    const created = new AudioClass();
    created.preload = 'auto';
    created.loop = true;
    created.volume = 0.4;
    created.playsInline = true;
    created.src = source;
    media = created;
    handlers = {
      playing() {
        if (media !== created) return;
        if (!wanted || destroyed || document.hidden || pageSuspended) { pause(); return; }
        gesturePending = false;
        setPlaying(true);
      },
      pause() {
        if (media !== created) return;
        if (wanted && !document.hidden && !pageSuspended) gesturePending = true;
        setPlaying(false);
      },
      waiting() { if (media === created) setPlaying(false); },
      ended() { if (media === created) setPlaying(false); },
      error() {
        if (media !== created) return;
        wanted = false;
        gesturePending = false;
        starting = false;
        setPlaying(false);
      }
    };
    for (const [name, handler] of Object.entries(handlers)) created.addEventListener(name, handler);
    return created;
  }
  async function activate(token, automatic = false) {
    let target;
    starting = true;
    gesturePending = false;
    try {
      target = ensureMedia();
      // On a fallback tap, play() stays in the trusted event's synchronous stack.
      await target.play();
      if (token !== generation || destroyed || !wanted || document.hidden || pageSuspended || target !== media) {
        if (target !== media || !wanted || destroyed || document.hidden || pageSuspended) target.pause();
        return playing;
      }
      gesturePending = false;
      setPlaying(!target.paused && !target.ended);
      return playing;
    } catch (error) {
      if (token !== generation || target !== media) return playing;
      pause();
      if (error?.name === 'NotAllowedError') {
        // Respect autoplay policy: wait for a real visitor interaction, never poll or unmute a workaround.
        gesturePending = wanted;
      } else {
        wanted = false;
        gesturePending = false;
      }
      if (!automatic) throw error;
      return false;
    } finally {
      if (token === generation) starting = false;
    }
  }
  function toggle() {
    if (!getState().supported) return Promise.resolve(false);
    const turnOff = wanted && (playing || starting);
    wanted = !turnOff;
    gesturePending = false;
    const token = ++generation;
    if (!wanted || document.hidden || pageSuspended) {
      starting = false;
      pause();
      return Promise.resolve(false);
    }
    return activate(token);
  }
  function startAutomatically() {
    if (!getState().supported || !wanted || playing || starting || document.hidden || pageSuspended) return;
    activate(++generation, true).catch(() => {});
  }
  function onGesture(event) {
    if (!event.isTrusted || !gesturePending || !wanted || playing || starting || destroyed || document.hidden || pageSuspended) return;
    // The music control has its own handler. Let one tap perform exactly one action.
    if (event.target?.closest?.('[data-action="music-toggle"]')) return;
    if (event.type === 'keydown' && (event.metaKey || event.ctrlKey || event.altKey || event.repeat || !['Enter', ' '].includes(event.key) && event.key?.length !== 1)) return;
    if (event.type === 'pointerup' && event.button !== undefined && event.button !== 0) return;
    activate(++generation, true).catch(() => {});
  }
  function onVisibility() {
    if (destroyed || pageSuspended) return;
    ++generation;
    if (document.hidden) {
      starting = false;
      pause();
    } else {
      starting = false;
      startAutomatically();
    }
  }
  function onPageHide() {
    ++generation;
    pageSuspended = true;
    starting = false;
    gesturePending = false;
    pause();
    release();
  }
  function onPageShow() {
    if (destroyed || !pageSuspended) return;
    pageSuspended = false;
    startAutomatically();
  }
  function destroy() {
    if (destroyed) return;
    wanted = false;
    onPageHide();
    destroyed = true;
    document.removeEventListener('visibilitychange', onVisibility);
    window.removeEventListener('pagehide', onPageHide);
    window.removeEventListener('pageshow', onPageShow);
    for (const type of ['pointerup', 'touchend', 'click', 'keydown']) document.removeEventListener(type, onGesture, true);
    notify();
  }
  document.addEventListener('visibilitychange', onVisibility);
  window.addEventListener('pagehide', onPageHide);
  window.addEventListener('pageshow', onPageShow);
  for (const type of ['pointerup', 'touchend', 'click', 'keydown']) document.addEventListener(type, onGesture, { capture: true, passive: true });
  window.TarotAmbience = { toggle, getState, destroy };
  startAutomatically();
})();
