import { useEffect, useRef, useState } from 'react';
import type { ChartResult, Place } from './api';
import { AspectFactors, aspectName, planetName, planetSign } from './Chart';
import { copy, type Language } from './copy';

export const birthDetailMs = 650;
export const interpretationSteps = [
  { key: 'placements', progress: 82, duration: 2400 },
  { key: 'reading', progress: 95, duration: 2600 },
] as const;
const preparationProgress = { review: 10, submitting: 20, queued: 25, running: 50 } as const;
const stepOrder = ['basics', ...interpretationSteps.map(step => step.key)] as const;
export type ReadingFlowStage = keyof typeof preparationProgress | typeof interpretationSteps[number]['key'] | 'complete' | 'loading';
const videoStallMs = 8000;

function ReadingProgress({ label, progress }: { label: string; progress: number }) {
  return <div className="generation-progress" role="progressbar" aria-label={label} aria-valuenow={progress}>
    <div className="generation-track" aria-hidden="true">
      <div className="generation-trail" style={{ width: `${progress}%` }}><span>✦</span></div>
    </div>
    <span className="generation-percent" aria-hidden="true">{progress}%</span>
  </div>;
}

function BirthDetails({ day, time, city, question, language, reducedMotion }: {
  day: string; time: string | null; city: string; question: string; language: Language; reducedMotion: boolean;
}) {
  const [index, setIndex] = useState(0);
  const text = copy[language];
  const details = [
    { label: text.date, value: <time dateTime={day}>{day}</time> },
    { label: text.time, value: time ?? text.unknown },
    { label: text.generation.birthplace, value: city },
  ];
  if (question) details.push({ label: text.generation.question, value: question });
  const count = details.length;

  useEffect(() => {
    if (reducedMotion) return;
    const timer = window.setInterval(() => setIndex(current => (current + 1) % count), birthDetailMs);
    return () => window.clearInterval(timer);
  }, [count, reducedMotion]);

  return <dl className="generation-details" aria-label={text.generation.birthDetails}>
    {(reducedMotion ? details : [details[index]]).map(({ label, value }) => (
      <div key={label} style={{ animationDuration: `${birthDetailMs}ms` }}>
        <dt>{label}</dt><dd>{value}</dd>
      </div>
    ))}
  </dl>;
}

function Placements({ result, language }: { result: ChartResult; language: Language }) {
  const text = copy[language];
  const words = text.interpretation;
  const dateOnly = result.precision === 'date_only';
  const headlinePlanets = result.planets.filter(planet => ['Sun', 'Moon', 'Ascendant'].includes(planet.id));
  const positions = headlinePlanets.length ? headlinePlanets : result.planets.slice(0, 3);
  const names = new Map(result.planets.map(planet => [planet.id, planetName(planet, language)]));
  const aspects = dateOnly ? [] : result.aspects.slice(0, 2);
  const counts = [`${words.planets} ${result.planets.filter(planet => planet.id !== 'Ascendant').length}`];
  if (!dateOnly) counts.push(`${words.houses} ${result.houses.length}`, `${words.aspects} ${result.aspects.length}`);

  return <>
    <p className="generation-basis">{counts.join(' · ')}</p>
    {positions.length > 0 && <dl className="interpretation-metrics">
      {positions.map(planet => <div key={planet.id}>
        <dt>{planetName(planet, language)}</dt><dd>{planetSign(planet, language)}</dd>
      </div>)}
    </dl>}
    {aspects.length > 0 && <ul className="interpretation-aspects" aria-label={words.aspects}>
      {aspects.map(aspect => <li key={`${aspect.from}-${aspect.type}-${aspect.to}`}>
        {names.get(aspect.from) ?? aspect.from} · {aspectName(aspect, language)} · {names.get(aspect.to) ?? aspect.to}
      </li>)}
    </ul>}
    {dateOnly && <p className="generation-explanation">{text.chart.noTime}</p>}
  </>;
}

function LoadingAnimation({ reducedMotion, onFinished }: { reducedMotion: boolean; onFinished: () => void }) {
  const video = useRef<HTMLVideoElement>(null);
  useEffect(() => {
    if (reducedMotion) {
      const timer = window.setTimeout(onFinished, 550);
      return () => window.clearTimeout(timer);
    }
    const player = video.current;
    if (!player) return;
    let lastTime = player.currentTime;
    let lastAdvance = performance.now();
    // A stalled player must not hold up the checkout.
    const watchdog = window.setInterval(() => {
      if (player.ended) return;
      if (document.hidden || player.currentTime > lastTime) {
        lastTime = player.currentTime;
        lastAdvance = performance.now();
      } else if (performance.now() - lastAdvance >= videoStallMs) {
        onFinished();
      }
    }, 1000);
    void player.play().catch(() => {
      if (player.isConnected) onFinished();
    });
    return () => window.clearInterval(watchdog);
  }, [onFinished, reducedMotion]);

  return <div className="generation-visual" aria-hidden="true">
    {reducedMotion ? <img className="generation-art" src="/assets/report-loading-poster.webp" alt="" />
      : <video ref={video} className="generation-art" src="/assets/report-loading-web.mp4" poster="/assets/report-loading-poster.webp"
        muted playsInline onEnded={onFinished} onError={onFinished} />}
  </div>;
}

export function Interpretation({ stage, result, language, day, time, place, question, reducedMotion, onAnimationFinished }: {
  stage: ReadingFlowStage; result: ChartResult | null; language: Language; day: string; time: string | null;
  place: Place; question: string; reducedMotion: boolean; onAnimationFinished: () => void;
}) {
  const page = useRef<HTMLElement>(null);
  const text = copy[language];
  const words = text.interpretation;
  const basics = stage === 'review' || stage === 'submitting' || stage === 'queued' || stage === 'running';
  const loading = stage === 'loading';
  const complete = stage === 'complete' || loading;
  const stepIndex = basics ? 0 : stage === 'placements' ? 1 : 2;
  const step = stepOrder[stepIndex];
  const next = stepOrder[stepIndex + 1];
  const progress = basics ? preparationProgress[stage] : complete ? 100 : interpretationSteps[stepIndex - 1].progress;
  const dateOnly = result?.precision === 'date_only';
  const city = (language === 'zh' ? place.name_zh : place.name_th) || place.name;

  let status = words.steps[step].status;
  if (basics) status = text.generation.stages[stage];
  if (stage === 'placements' && dateOnly) status = words.dateOnlyPlacements;
  if (complete) status = loading ? words.summarizing : words.complete;

  useEffect(() => { page.current?.focus(); }, []);

  return <main ref={page} tabIndex={-1} aria-labelledby="interpretation-title"
    className={complete ? 'generation interpretation generation-complete' : 'generation interpretation'}>
    <section className="generation-summary">
      <p className="generation-brand"><span aria-hidden="true">✦</span> FATE</p>
      <h1 id="interpretation-title">{words.title}</h1>
      <div className="generation-card interpretation-detail" key={loading ? 'loading' : step}>
        <h2>{loading ? text.generation.method : words.steps[step].title}</h2>
        {basics && <BirthDetails day={day} time={time} city={city} question={question}
          language={language} reducedMotion={reducedMotion} />}
        {stage === 'placements' && result && <Placements result={result} language={language} />}
        {step === 'reading' && !loading && result && <AspectFactors result={result} language={language} />}
        {loading && <>
          <p className="generation-method">{text.chart.wheel}</p>
          <p className="generation-basis">{dateOnly ? text.chart.dateOnly : text.chart.exact}</p>
          <p className="generation-explanation">{dateOnly ? text.chart.noTime : text.generation.basis}</p>
        </>}
      </div>
    </section>
    <section className="interpretation-process" data-loading={loading}>
      <div className="generation-card generation-status">
        <ol className="interpretation-steps" aria-label={text.generation.process}>
          {stepOrder.map((item, index) => <li key={item}
            aria-current={!complete && index === stepIndex ? 'step' : undefined} data-complete={complete || index < stepIndex}>
            <span aria-hidden="true">{complete || index < stepIndex ? '✓' : index + 1}</span>{words.steps[item].title}
          </li>)}
        </ol>
        <p role="status">{status}</p>
        <ReadingProgress label={text.progress} progress={progress} />
        {!complete && <p className="interpretation-next">{words.next} · {next ? words.steps[next].title : text.checkout.title}</p>}
      </div>
      {loading && <LoadingAnimation reducedMotion={reducedMotion} onFinished={onAnimationFinished} />}
    </section>
  </main>;
}
