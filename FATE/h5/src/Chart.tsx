import { useEffect, useRef, useState } from 'react';
import type { ChartResult, Planet } from './api';
import { copy, landingThemes, message, type Language, type Topic } from './copy';
import { LandingIcon } from './LandingDetails';

const zodiac = ['♈', '♉', '♊', '♋', '♌', '♍', '♎', '♏', '♐', '♑', '♒', '♓'];
const topicPlanets: Record<Topic, string[]> = {
  life: [],
  love: ['Venus', 'Moon', 'Mercury'],
  career: ['Mercury', 'Mars', 'Sun'],
};
const planetNames: Record<string, string> = {
  Sun: '太阳', Moon: '月亮', Mercury: '水星', Venus: '金星', Mars: '火星', Jupiter: '木星',
  Saturn: '土星', Uranus: '天王星', Neptune: '海王星', Pluto: '冥王星', Ascendant: '上升点',
};
const signNames: Record<string, string> = {
  Aries: '白羊座', Taurus: '金牛座', Gemini: '双子座', Cancer: '巨蟹座', Leo: '狮子座', Virgo: '处女座',
  Libra: '天秤座', Scorpio: '天蝎座', Sagittarius: '射手座', Capricorn: '摩羯座', Aquarius: '水瓶座', Pisces: '双鱼座',
};
const houseSignNames = {
  zh: Object.values(signNames),
  th: ['เมษ', 'พฤษภ', 'เมถุน', 'กรกฎ', 'สิงห์', 'กันย์', 'ตุล', 'พิจิก', 'ธนู', 'มังกร', 'กุมภ์', 'มีน'],
};
const reportBadges = [
  { section: 'overall', icon: '✦' },
  { section: 'natal', icon: '☉' },
  { section: 'love', icon: '♡' },
  { section: 'career', icon: '◇' },
  { section: 'opportunities', icon: '✧' },
  { section: 'partnership', icon: '☽' },
] as const;
const careerPlanets = ['Mercury', 'Mars'];
const aspectNames: Record<string, string> = {
  conjunction: '合相', trine: '拱相', sextile: '六合', square: '刑相', opposition: '冲相',
};
const factorGroups = [
  { kind: 'favorable', aspects: ['trine', 'sextile'] },
  { kind: 'unfavorable', aspects: ['square', 'opposition'] },
] as const;

export function planetName(planet: Planet, language: Language) {
  return language === 'zh' ? planetNames[planet.id] ?? planet.label : planet.label;
}

export function planetSign(planet: Planet, language: Language) {
  return language === 'zh' ? signNames[planet.sign ?? ''] ?? planet.sign_name : planet.sign_name;
}

export function aspectName(aspect: ChartResult['aspects'][number], language: Language) {
  return language === 'zh' ? aspectNames[aspect.type] ?? aspect.label : aspect.label;
}

export function AspectFactors({ result, language }: { result: ChartResult; language: Language }) {
  const text = copy[language].chart.factors;
  const names = new Map(result.planets.map(planet => [planet.id, planetName(planet, language)]));
  const exact = result.precision === 'exact';

  return <div className="aspect-factors">
    {factorGroups.map(group => {
      const aspects = exact ? result.aspects.filter(aspect => group.aspects.some(type => type === aspect.type)).slice(0, 2) : [];
      return <section key={group.kind} className={`aspect-factor aspect-factor-${group.kind}`}>
        <h3>{text[group.kind]}</h3>
        {aspects.length ? <ul>{aspects.map(aspect => <li key={`${aspect.from}-${aspect.type}-${aspect.to}`}>
          {names.get(aspect.from) ?? aspect.from} · {aspectName(aspect, language)} · {names.get(aspect.to) ?? aspect.to}
        </li>)}</ul> : <p>{exact ? text.empty : '—'}</p>}
      </section>;
    })}
    <p className="aspect-factor-basis">{exact ? text.basis : text.noTime}</p>
  </div>;
}

function ReportHouses({ result, numbers, language }: {
  result: ChartResult; numbers: (2 | 7 | 10)[]; language: Language;
}) {
  const text = copy[language];
  const houses = numbers.flatMap(number => {
    const house = result.houses.find(item => item.number === number);
    return house ? [{ ...house, number }] : [];
  });
  if (!houses.length) return <p className="subtle">{text.report.housesUnavailable}</p>;

  return <dl className="report-house-list">
    {houses.map(house => {
      const sign = houseSignNames[language][Math.floor(house.longitude / 30)];
      const occupants = result.planets.filter(planet => planet.house === house.number);
      return <div key={house.number}>
        <dt>{text.chart.house(house.number)} · {text.report.houses[house.number]}</dt>
        <dd>{sign}{occupants.length > 0 && ` · ${occupants.map(planet => planetName(planet, language)).join(' / ')}`}</dd>
      </div>;
    })}
  </dl>;
}

function ReportBadges({ language }: { language: Language }) {
  const sections = copy[language].report.sections;
  return <ul className="report-badges">
    {reportBadges.map(({ section, icon }) => <li key={section}>
      <a href={`#report-${section}`} className="report-badge">
        <span aria-hidden="true">{icon}</span><strong>{sections[section]}</strong>
      </a>
    </li>)}
  </ul>;
}

export function ReportCheckout({ language, busy, error, onBack, onErase }: {
  language: Language; busy: boolean; error: string; onBack: () => void; onErase: () => void;
}) {
  const page = useRef<HTMLElement>(null);
  const [showDownloadNotice, setShowDownloadNotice] = useState(false);
  const text = copy[language];
  const checkout = text.checkout;
  useEffect(() => {
    page.current?.scrollIntoView();
    page.current?.focus({ preventScroll: true });
  }, []);

  return <main className="generation report-checkout" ref={page} tabIndex={-1} aria-labelledby="checkout-title">
    <header className="checkout-header">
      <p className="generation-brand"><span aria-hidden="true">✦</span> FATE</p>
      <p className="eyebrow">{checkout.eyebrow}</p>
      <h1 id="checkout-title">{checkout.title}</h1>
    </header>
    <section className="checkout-card" aria-labelledby="checkout-contents">
      <h2 id="checkout-contents"><span aria-hidden="true">✧</span> {checkout.contents} <span aria-hidden="true">✧</span></h2>
      <ul className="report-badges">
        {[...landingThemes.outlook, ...landingThemes.highlights].map(theme => <li key={theme.id}>
          <div className="report-badge report-badge-locked" data-section={theme.id}>
            <span aria-hidden="true">{theme.icon}</span>
            <strong>{theme[language]}</strong>
            <LandingIcon name="lock" />
          </div>
        </li>)}
      </ul>
      <div className="checkout-price"><span>{checkout.samplePrice}</span><strong>฿39</strong></div>
      <button className="primary checkout-pay" type="button" disabled aria-describedby="checkout-preview">
        <LandingIcon name="lock" />{checkout.pay}
      </button>
      <p className="subtle checkout-preview" id="checkout-preview">{checkout.preview}</p>
      <button className="primary checkout-download" type="button" onClick={() => setShowDownloadNotice(true)}>
        <LandingIcon name="download" />{checkout.download}
      </button>
      {showDownloadNotice && <p className="subtle checkout-preview" role="status">{checkout.downloadUnavailable}</p>}
    </section>
    <section className="checkout-about" aria-labelledby="checkout-about-title">
      <h2 id="checkout-about-title">{checkout.aboutTitle.map(line => <span key={line}>{line}</span>)}</h2>
      <p>{checkout.about}</p>
    </section>
    <div className="checkout-actions">
      <button className="secondary" type="button" disabled={busy} onClick={onBack}>{checkout.back}</button>
      <button className="secondary" type="button" disabled={busy} onClick={onErase}>{text.erase}</button>
    </div>
    {error && <p className="error" role="alert">{message(error, language)}</p>}
  </main>;
}

export function Chart({ result, language, topic }: { result: ChartResult; language: Language; topic: Topic }) {
  const preferred = topicPlanets[topic];
  const [selected, setSelected] = useState(() => preferred.find(id => result.planets.some(planet => planet.id === id)) ?? result.planets[0]?.id);
  const current = result.planets.find(planet => planet.id === selected);
  const exact = result.precision === 'exact';
  const text = copy[language].chart;
  const report = copy[language].report;
  const reading = [
    ...preferred.map(id => result.reading.find(item => item.id === id)).filter(item => item !== undefined),
    ...result.reading.filter(item => !preferred.includes(item.id)),
  ];
  const origin = result.planets.find(planet => planet.id === 'Ascendant')?.longitude ?? 0;
  const point = (degree: number, radius: number) => {
    const a = Math.PI - ((degree - origin) * Math.PI) / 180;
    return [160 + Math.cos(a) * radius, 160 - Math.sin(a) * radius];
  };
  const renderReadings = (items: ChartResult['reading']) => items.map(item => (
    <section className={item.id === selected ? 'reading selected-reading' : 'reading'} key={item.id} lang="th">
      <h4>{item.title}</h4><p className="basis">{item.basis}</p><p>{item.text}</p>
    </section>
  ));
  const natalReadings = reading.filter(item => item.id !== 'Venus' && !careerPlanets.includes(item.id));
  const loveReadings = reading.filter(item => item.id === 'Venus');
  const careerReadings = reading.filter(item => careerPlanets.includes(item.id));

  return (
    <article className="result-card" aria-labelledby="report-title">
      <header className="report-intro">
        <p className="eyebrow">FATE / {copy[language].topics[topic].label}</p>
        <h2 id="report-title">{report.title}</h2>
        <p className="subtle"><span lang="th">{result.place}</span> · {exact ? text.exact : text.dateOnly}</p>
        <nav className="report-contents" aria-label={report.contents}>
          <p>{report.contents}</p>
          <ReportBadges language={language} />
        </nav>
      </header>
      <section className="report-section" id="report-overall" tabIndex={-1}>
        <h3>{text.title}</h3>
        {exact ? (
          <svg className="wheel" viewBox="0 0 320 320" role="img" aria-label={text.wheel}>
            {[148, 119, 91].map(radius => <circle className="wheel-ring" cx="160" cy="160" r={radius} key={radius} />)}
            {zodiac.map((sign, i) => {
              const [x, y] = point(i * 30 + 15, 134);
              const [x1, y1] = point(i * 30, 119);
              const [x2, y2] = point(i * 30, 148);
              return <g key={sign}>
                <line className="wheel-line" x1={x1} y1={y1} x2={x2} y2={y2} />
                <text className="zodiac" x={x} y={y} dominantBaseline="central" textAnchor="middle">{sign}</text>
              </g>;
            })}
            {result.houses.map(house => {
              const [x, y] = point(house.longitude, 118);
              const [ix, iy] = point(house.longitude, 91);
              return <line className="wheel-line" key={house.number} x1={ix} y1={iy} x2={x} y2={y} />;
            })}
            {result.aspects.map((aspect, index) => {
              const first = result.planets.find(planet => planet.id === aspect.from)?.longitude;
              const second = result.planets.find(planet => planet.id === aspect.to)?.longitude;
              if (first == null || second == null) return null;
              const [x1, y1] = point(first, 88);
              const [x2, y2] = point(second, 88);
              return <line className="aspect-line" key={index} x1={x1} y1={y1} x2={x2} y2={y2} />;
            })}
            {result.planets.map((planet, i) => {
              if (planet.longitude == null) return null;
              const [x, y] = point(planet.longitude, 95 + (i % 3) * 6);
              return <g key={planet.id} className="wheel-target" data-planet={planet.id} onClick={() => setSelected(planet.id)}>
                <circle className="marker-hit" cx={x} cy={y} r="11" />
                <circle cx={x} cy={y} r={planet.id === selected ? 6 : 3.7} className={planet.id === selected ? 'marker active' : 'marker'} />
              </g>;
            })}
            <text className="wheel-title" x="160" y="164" textAnchor="middle">FATE</text>
          </svg>
        ) : <p className="notice">{text.noTime}</p>}
        {result.planets.length > 0 && (
          <div className="planet-list" role="group" aria-label={text.selectPlanet}>
            {result.planets.map(planet => <button key={planet.id} type="button" className="chip" aria-pressed={selected === planet.id} onClick={() => setSelected(planet.id)}>{planetName(planet, language)}</button>)}
          </div>
        )}
        {current && <p className="position" aria-live="polite">
          {planetName(current, language)}{text.inSign}{planetSign(current, language)}
          {current.degree != null ? ' · ' + current.degree.toFixed(2) + '°' : ''}
          {current.house != null ? ' · ' + text.house(current.house) : ''}
        </p>}
      </section>
      <section className="report-section" id="report-natal" tabIndex={-1}>
        <h3>{report.sections.natal}</h3>
        {natalReadings.length > 0 && text.readingLanguage && <p className="subtle small">{text.readingLanguage}</p>}
        {natalReadings.length ? renderReadings(natalReadings) : <p className="subtle">{reading.length ? report.readingUnavailable : text.noReading}</p>}
      </section>
      <section className="report-section" id="report-love" tabIndex={-1}>
        <h3>{report.sections.love}</h3>
        {loveReadings.length ? renderReadings(loveReadings) : <p className="subtle">{report.readingUnavailable}</p>}
      </section>
      <section className="report-section" id="report-career" tabIndex={-1}>
        <h3>{report.sections.career}</h3>
        <ReportHouses result={result} numbers={[10, 2]} language={language} />
        {renderReadings(careerReadings)}
      </section>
      <section className="report-section" id="report-opportunities" tabIndex={-1}>
        <h3>{report.sections.opportunities}</h3>
        <AspectFactors result={result} language={language} />
      </section>
      <section className="report-section" id="report-partnership" tabIndex={-1}>
        <h3>{report.sections.partnership}</h3>
        <ReportHouses result={result} numbers={[7]} language={language} />
      </section>
      <p className="subtle small">{text.note}</p>
    </article>
  );
}
