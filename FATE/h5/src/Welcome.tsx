import { useLayoutEffect, useRef, useState, type RefObject } from 'react';
import { copy, type Language } from './copy';
import { AstrologerPortrait } from './LandingDetails';

const visitKey = 'fate-welcome-seen';
const transitionDuration = 820;
const portraitHandoff = 650;

export function Welcome({ language, destination, motionPreference, onEnter }: {
  language: Language;
  destination: RefObject<HTMLImageElement | null>;
  motionPreference: MediaQueryList;
  onEnter: () => void;
}) {
  const [returning] = useState(() => {
    try { return localStorage.getItem(visitKey) === '1'; } catch { return false; }
  });
  const [leaving, setLeaving] = useState(false);
  const portrait = useRef<HTMLImageElement>(null);
  const animations = useRef<Animation[]>([]);
  const pointer = useRef<{ id: number; x: number; y: number } | null>(null);
  const text = copy[language].welcome;

  useLayoutEffect(() => {
    document.documentElement.classList.add('welcome-open');
    window.scrollTo(0, 0);
    try { localStorage.setItem(visitKey, '1'); } catch { /* The welcome page is still usable. */ }
    return () => {
      animations.current.forEach(animation => animation.cancel());
      document.documentElement.classList.remove('welcome-open');
    };
  }, []);

  function enter() {
    if (animations.current.length) return;
    window.scrollTo(0, 0);
    const image = portrait.current;
    const homeImage = destination.current;
    const from = image?.getBoundingClientRect();
    const to = homeImage?.getBoundingClientRect();
    const hero = homeImage?.parentElement?.getBoundingClientRect();
    if (motionPreference.matches || !image || !homeImage || !hero || !from?.width || !from.height || !to?.width || !to.height) {
      onEnter();
      return;
    }

    const scaleY = to.height / from.height;
    const transform = `translate(${to.left - from.left}px, ${to.top - from.top}px) scale(${to.width / from.width}, ${scaleY})`;
    const cropTop = Math.max(0, hero.top - to.top) / scaleY;
    const cropBottom = Math.max(0, to.bottom - hero.bottom) / scaleY;
    setLeaving(true);
    const motion = image.animate([
      { transform: 'translate(0, 0) scale(1)', clipPath: 'inset(0px)' },
      { transform, clipPath: `inset(${cropTop}px 0px ${cropBottom}px 0px)` },
    ], { duration: transitionDuration, easing: 'cubic-bezier(.24,.62,.32,1)', fill: 'forwards' });
    // Reveal the homepage portrait beneath the moving image just before it fades out.
    animations.current = [motion,
      homeImage.animate([{ opacity: 0 }, { opacity: 1 }], {
        duration: portraitHandoff, easing: 'steps(1, end)', fill: 'both',
      }),
      image.animate([{ opacity: 1 }, { opacity: 0 }], {
        delay: portraitHandoff, duration: transitionDuration - portraitHandoff, fill: 'both',
      }),
    ];
    void motion.finished.then(onEnter, () => {});
  }

  return <section className={leaving ? 'welcome welcome-leaving' : 'welcome'} aria-labelledby="welcome-title"
    onPointerDown={event => {
      if (!event.isPrimary || event.button !== 0 || (event.target instanceof Element && event.target.closest('button'))) return;
      pointer.current = { id: event.pointerId, x: event.clientX, y: event.clientY };
      event.currentTarget.setPointerCapture(event.pointerId);
    }}
    onPointerUp={event => {
      const start = pointer.current;
      pointer.current = null;
      if (start?.id === event.pointerId && start.y - event.clientY > Math.max(48, Math.abs(start.x - event.clientX))) enter();
    }}
    onPointerCancel={() => { pointer.current = null; }}
    onWheel={event => { if (event.deltaY > 12) enter(); }}>
    <div className="welcome-background" aria-hidden="true" />
    <div className="welcome-stage">
      <AstrologerPortrait className="welcome-portrait" imageRef={portrait} sizes="(max-width: 450px) 144vw, 648px" />
      <div className="welcome-shade" aria-hidden="true" />
      <span className="welcome-sparkle" aria-hidden="true">✦</span>
      <div className="welcome-copy">
        <div className="welcome-divider" aria-hidden="true">✦</div>
        <h1 id="welcome-title">{returning ? text.returning : text.first}</h1>
        <p>{returning ? text.returningNote : text.firstNote}</p>
        <button className="welcome-start" type="button" disabled={leaving} onClick={enter}>
          <span aria-hidden="true">✧</span>{text.start}
        </button>
        <span className="welcome-hint">↑ {text.swipe}</span>
      </div>
    </div>
  </section>;
}
