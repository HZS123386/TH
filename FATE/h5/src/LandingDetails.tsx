import { useState, type Ref } from 'react';
import { copy, landingThemes, type Language } from './copy';

const paths = {
  book: 'M12 7v14m0-14C9 4 5 4 2 5v14c4-1 7 0 10 2 3-2 6-3 10-2V5c-3-1-7-1-10 2Z',
  lock: 'M7 10V7a5 5 0 0 1 10 0v3M5 10h14v11H5zM12 15v2',
  download: 'M12 3v12m-5-5 5 5 5-5M4 16v4a1 1 0 0 0 1 1h14a1 1 0 0 0 1-1v-4',
  history: 'M3 12a9 9 0 1 1 3 6.7M3 5v7h7m2-5v5l3 2',
  cloud: 'M2 15h16a3 3 0 1 0-2.8-4A4.8 4.8 0 0 0 6 12a2.2 2.2 0 0 0-4 1.4M5 18h14m-7-6a1.5 1.5 0 0 0-3 0',
};

const themeBoards = [
  { crop: '121 196 517 389', themes: landingThemes.outlook },
  { crop: '656 644 517 443', themes: landingThemes.highlights },
];

export function LandingIcon({ name }: { name: keyof typeof paths }) {
  return <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.4"
    strokeLinecap="round" strokeLinejoin="round" aria-hidden="true"><path d={paths[name]} /></svg>;
}

export function AstrologerPortrait({ className, imageRef, sizes = '(max-width: 450px) 100vw, 450px' }: {
  className: string; imageRef?: Ref<HTMLImageElement>; sizes?: string;
}) {
  return <img ref={imageRef} className={className} src="/assets/astrologer-purple-stars-450.webp"
    srcSet="/assets/astrologer-purple-stars-450.webp 450w, /assets/astrologer-purple-stars-900.webp 900w, /assets/astrologer-purple-stars-1199.webp 1199w"
    sizes={sizes} width="1199" height="1312" alt="" fetchPriority="high" draggable={false} />;
}

export function QuestionPicker({ language, question, setQuestion, preset, setPreset }: {
  language: Language; question: string; setQuestion: (value: string) => void;
  preset: number | null; setPreset: (value: number | null) => void;
}) {
  const text = copy[language];
  const [writing, setWriting] = useState(false);

  return <section className="question-panel" aria-labelledby="question-title">
    <h3 id="question-title">{text.questionTitle}</h3>
    <p id="question-hint">{text.questionHint}</p>
    <div className="question-controls">
      {!writing && <div className="question-options" tabIndex={0} role="group" aria-labelledby="question-title">
        {text.questions.map(([label, prompt], index) => (
          <button key={index} type="button" aria-pressed={preset === index} onClick={event => {
            event.currentTarget.parentElement?.scrollTo({ top: event.currentTarget.offsetTop, behavior: 'instant' });
            setQuestion('');
            setPreset(preset === index ? null : index);
          }}>
            <span>{label}</span><strong>{prompt}</strong>{preset === index && <small>{text.selected}</small>}
          </button>
        ))}
      </div>}
      <input className={writing ? 'question-input' : 'question-input question-input-compact'}
        aria-label={text.questionTitle} aria-describedby="question-hint" placeholder={writing ? text.questionTitle : text.writeQuestion}
        autoComplete="off" maxLength={120} value={writing ? question : ''}
        onFocus={() => { setWriting(true); setPreset(null); }} onChange={event => setQuestion(event.target.value)} />
      {writing && <button className="question-browse" type="button" onClick={() => { setQuestion(''); setWriting(false); }}>{text.browseQuestions}</button>}
    </div>
  </section>;
}

export function ThemeCards({ language }: { language: Language }) {
  return <section className="topic-section" aria-labelledby="topic-heading">
    <h3 id="topic-heading"><LandingIcon name="cloud" />{copy[language].topicLabel}<LandingIcon name="cloud" /></h3>
    <div className="theme-boards">
      {themeBoards.map(({ crop, themes }) => <div className="theme-board" key={crop}>
        <div className="theme-illustration" aria-hidden="true">
          <svg viewBox={crop} preserveAspectRatio="xMidYMid slice">
            <image href="/assets/theme-thai-artwork.jpg" width="1315" height="1197" />
          </svg>
        </div>
        <ul className="theme-pills">
          {themes.map(theme => <li key={theme.id}><span>{theme[language]}</span></li>)}
        </ul>
      </div>)}
    </div>
  </section>;
}
