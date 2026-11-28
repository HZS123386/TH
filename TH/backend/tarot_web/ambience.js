/* FATE · load the background loop when the visitor enables it. */
(() => {
  'use strict';
  const AudioClass = window.Audio;
  let media = null;
  let handlers = null;
  let wanted = false;
  let playing = false;
  let starting = false;
  let pageSuspended = false;
  let destroyed = false;
  let generation = 0;
  const getState = () => ({ enabled: wanted, supported: !destroyed && typeof AudioClass === 'function' });
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
    created.preload = 'none';
    created.loop = true;
    created.volume = 0.4;
    created.playsInline = true;
    created.src = created.canPlayType('audio/ogg; codecs="vorbis"')
      ? 'assets/tarot-loop-v2.ogg'
      : 'assets/tarot-loop-v2.mp3';
    media = created;
    handlers = {
      playing() {
        if (media !== created) return;
        if (!wanted || destroyed || document.hidden || pageSuspended) { pause(); return; }
        setPlaying(true);
      },
      pause() {
        if (media !== created) return;
        setPlaying(false);
      },
      waiting() { if (media === created) setPlaying(false); },
      ended() { if (media === created) setPlaying(false); },
      error() {
        if (media !== created) return;
        wanted = false;
        starting = false;
        setPlaying(false);
        notify();
      }
    };
    for (const [name, handler] of Object.entries(handlers)) created.addEventListener(name, handler);
    return created;
  }
  async function activate(token, resuming = false) {
    let target;
    starting = true;
    try {
      target = ensureMedia();
      await target.play();
      if (token !== generation || destroyed || !wanted || document.hidden || pageSuspended || target !== media) {
        if (target !== media || !wanted || destroyed || document.hidden || pageSuspended) target.pause();
        return playing;
      }
      setPlaying(!target.paused && !target.ended);
      return playing;
    } catch (error) {
      if (token !== generation || (target && target !== media)) return playing;
      wanted = false;
      pause();
      notify();
      if (!resuming) throw error;
      return false;
    } finally {
      if (token === generation) starting = false;
    }
  }
  function toggle() {
    if (!getState().supported) return Promise.resolve(false);
    wanted = !wanted;
    notify();
    const token = ++generation;
    if (!wanted || document.hidden || pageSuspended) {
      starting = false;
      pause();
      release();
      return Promise.resolve(false);
    }
    return activate(token);
  }
  function resumePlayback() {
    if (!getState().supported || !wanted || playing || starting || document.hidden || pageSuspended) return;
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
      resumePlayback();
    }
  }
  function onPageHide() {
    ++generation;
    pageSuspended = true;
    starting = false;
    pause();
    release();
  }
  function onPageShow() {
    if (destroyed || !pageSuspended) return;
    pageSuspended = false;
    resumePlayback();
  }
  function destroy() {
    if (destroyed) return;
    wanted = false;
    onPageHide();
    destroyed = true;
    document.removeEventListener('visibilitychange', onVisibility);
    window.removeEventListener('pagehide', onPageHide);
    window.removeEventListener('pageshow', onPageShow);
    notify();
  }
  document.addEventListener('visibilitychange', onVisibility);
  window.addEventListener('pagehide', onPageHide);
  window.addEventListener('pageshow', onPageShow);
  window.TarotAmbience = { toggle, getState, destroy };
})();
