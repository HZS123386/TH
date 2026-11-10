import {
  BriefcaseBusiness,
  Droplets,
  Flame,
  Heart,
  House,
  Mountain,
  Wallet,
  Wind,
} from 'lucide-react';
import type { ThaiHoroscope } from 'thai-astrology';
import { natalDistribution, natalReadingCopy, natalTopicEvidence } from '../lib/natalReading';
import { fillCopy } from '../lib/fortune';
import { planetSymbols } from '../lib/chartGeometry';
import { contentFor } from '../lib/wanjai';
import { planetLabel } from './OrbitEvidence';
import type { WanjaiPageProps } from './wanjai/WanjaiShared';

type PointKey = keyof ThaiHoroscope['points'];
const elementIcons = [Flame, Mountain, Wind, Droplets];
const elementColors = ['text-amber-300', 'text-emerald-300', 'text-sky-300', 'text-violet-300'];
const topicIcons = [BriefcaseBusiness, Wallet, Heart, House];

export function NatalReadingSummary({ chart, p }: { chart: ThaiHoroscope; p: WanjaiPageProps }) {
  const copy = natalReadingCopy(p.language);
  const signs = contentFor(p.language).signs;
  const elements = natalDistribution(chart, 'element');
  const summaries = [
    {
      label: p.t.ux_summarySun,
      basis: signs[chart.points.sun.sign].name,
      text: copy.signStyles[chart.points.sun.sign],
    },
    {
      label: p.t.ux_summaryMoon,
      basis: signs[chart.points.moon.sign].name,
      text: copy.signStyles[chart.points.moon.sign],
    },
    {
      label: p.t.ux_summaryRhythm,
      basis: elements.leaders.map((group) => copy.elements[group.index]).join(' · '),
      text:
        elements.leaders.length > 1
          ? fillCopy(copy.tie, {
              names: elements.leaders.map((group) => copy.elements[group.index]).join(' · '),
            })
          : copy.elementNotes[elements.leaders[0].index],
    },
  ];
  return (
    <section className="space-y-4 border-y border-gold/20 py-5" data-testid="reading-summary">
      <h2 className="text-lg font-medium">{p.t.ux_summaryTitle}</h2>
      <p className="text-xs leading-6 text-muted">{p.t.ux_summaryNote}</p>
      <ol className="space-y-4">
        {summaries.map((item, index) => (
          <li key={item.label} className="flex gap-3">
            <span className="mt-0.5 w-5 shrink-0 text-sm tabular-nums text-gold/80">
              0{index + 1}
            </span>
            <div className="min-w-0">
              <h3 className="text-sm font-medium">
                {item.label}
                <span className="ml-2 text-xs font-normal text-gold/90">{item.basis}</span>
              </h3>
              <p className="mt-1 text-sm leading-7 text-ink/85">{item.text}</p>
            </div>
          </li>
        ))}
      </ol>
    </section>
  );
}

export function NatalReadingDistribution({
  chart,
  p,
}: {
  chart: ThaiHoroscope;
  p: WanjaiPageProps;
}) {
  const copy = natalReadingCopy(p.language);
  const elements = natalDistribution(chart, 'element');
  const modalities = natalDistribution(chart, 'modality');
  const names = elements.leaders.map((group) => copy.elements[group.index]).join(' · ');
  return (
    <section
      id="reading-elements"
      className="scroll-mt-32 space-y-4"
      data-testid="reading-elements"
    >
      <h2 className="text-lg font-medium">{copy.elementsTitle}</h2>
      <div className="grid grid-cols-4 gap-2">
        {elements.groups.map((group) => {
          const Icon = elementIcons[group.index];
          return (
            <article
              key={group.index}
              className="min-w-0 border-0 bg-transparent px-1 py-3 text-center"
              data-element={group.index}
              data-count={group.points.length}
            >
              <Icon
                size={23}
                strokeWidth={1.3}
                className={`mx-auto mb-2 ${elementColors[group.index]}`}
              />
              <p className="text-sm font-medium tabular-nums text-ink/90">{group.percent}%</p>
              <p className="mt-1 text-xs text-muted">{copy.elements[group.index]}</p>
              <p className="mt-1 text-[10px] text-muted/80">{group.points.length} / 7</p>
            </article>
          );
        })}
      </div>
      <div className="border-0 bg-transparent p-4" data-testid="reading-element-summary">
        <h3 className="text-sm font-medium text-gold/90">{fillCopy(copy.leading, { names })}</h3>
        {elements.leaders.length > 1 && (
          <p className="mt-2 text-xs leading-6 text-muted">{fillCopy(copy.tie, { names })}</p>
        )}
        <div className="mt-2 space-y-2 text-sm leading-7 text-ink/80">
          {elements.leaders.map((group) => (
            <p key={group.index}>{copy.elementNotes[group.index]}</p>
          ))}
        </div>
      </div>
      <div className="space-y-3 border-0 bg-transparent p-4" data-testid="reading-modalities">
        {modalities.groups.map((group) => (
          <div
            key={group.index}
            className="grid grid-cols-[minmax(0,1fr)_minmax(0,1.5fr)_auto] items-center gap-3 text-xs"
          >
            <span className="text-muted">{copy.modalities[group.index]}</span>
            <span className="h-1.5 overflow-hidden rounded-full bg-surface">
              <span
                className="block h-full rounded-full bg-gold/65"
                style={{ width: `${group.percent}%` }}
              />
            </span>
            <span className="tabular-nums text-ink/80">{group.percent}%</span>
          </div>
        ))}
        <details className="pt-3 text-xs leading-6 text-muted">
          <summary className="cursor-pointer text-gold/90">{copy.methodTitle}</summary>
          <p className="mt-2">{copy.method}</p>
          <p className="mt-2">{copy.zero}</p>
          <p className="mt-2">
            {elements.groups
              .map(
                (group) =>
                  `${copy.elements[group.index]}: ${group.points.map((key) => planetLabel(key, p.t)).join(' · ') || '—'}`,
              )
              .join(' / ')}
          </p>
        </details>
      </div>
    </section>
  );
}

export function NatalReadingTopics({
  chart,
  p,
  onFocus,
}: {
  chart: ThaiHoroscope;
  p: WanjaiPageProps;
  onFocus: (keys: PointKey[]) => void;
}) {
  const copy = natalReadingCopy(p.language);
  const signs = contentFor(p.language).signs;
  const houseTitles = p.t.r_houseTitles.split('｜');
  return (
    <section id="reading-topics" className="scroll-mt-32 space-y-4" data-testid="reading-topics">
      <h2 className="text-lg font-medium">{copy.topicsTitle}</h2>
      <p className="text-xs leading-7 text-muted">{copy.topicsIntro}</p>
      {natalTopicEvidence(chart).map((topic, index) => {
        const Icon = topicIcons[index];
        const text = copy.topics[index];
        return (
          <article
            key={topic.key}
            className="scroll-mt-32 rounded-[20px] border border-line bg-panel p-5"
            data-reading-topic={topic.key}
          >
            <h3 className="flex items-center gap-2 text-base font-medium">
              <Icon size={18} className="shrink-0 text-gold/85" />
              {text.title}
            </h3>
            <p className="mt-3 text-sm leading-7 text-ink/85">
              {text.contexts[topic.ruler.house - 1]}
            </p>
            <p className="mt-2 text-sm leading-7 text-ink/80">
              {copy.signStyles[topic.ruler.sign]}
            </p>
            <p className="mt-3 text-xs leading-7 text-muted">{text.question}</p>
            <div className="mt-4 rounded-xl bg-surface/70 p-3">
              <h4 className="text-xs font-medium text-gold/90">{copy.observe}</h4>
              <p className="mt-2 text-sm leading-7 text-ink/85">{text.action}</p>
            </div>
            <details
              className="mt-4 border-t border-line pt-3 text-xs leading-7 text-muted"
              data-topic-evidence={topic.key}
            >
              <summary className="cursor-pointer text-gold/90">{copy.basis}</summary>
              <p className="mt-2" data-ruler={topic.ruler.key} data-ruler-house={topic.ruler.house}>
                {fillCopy(copy.topicRuler, {
                  anchor: topic.anchor.number,
                  planet: planetLabel(topic.ruler.key, p.t),
                  sign: signs[topic.ruler.sign].name,
                  house: topic.ruler.house,
                })}
              </p>
              <p className="mt-2">{copy.connections}</p>
              <ul className="mt-1 space-y-1">
                {topic.houses.map((house) => (
                  <li key={house.number}>
                    {house.number} · {houseTitles[house.number - 1]} · {signs[house.sign].name} ·{' '}
                    {house.occupants.map((key) => planetLabel(key, p.t)).join(' / ') || p.t.r_empty}
                  </li>
                ))}
              </ul>
              <button
                type="button"
                className="jy-outline mt-3 w-full !text-xs"
                onClick={() => onFocus([topic.ruler.key])}
              >
                <span aria-hidden="true">{planetSymbols[topic.ruler.key]}</span>
                {copy.showOnChart}
              </button>
            </details>
          </article>
        );
      })}
    </section>
  );
}
