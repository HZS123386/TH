import { ArrowRight, Check } from 'lucide-react';
import { bangkokDay, type Topic } from '../../lib/wanjai';
import { ThaiBasis } from '../ThaiBasis';
import { JourneyCard, TalkEntry } from './WanjaiCards';
import { type WanjaiPageProps, concernIcons, PageIntro, usePage } from './WanjaiShared';

export function WanjaiQuestions(p: WanjaiPageProps) {
  const { data } = usePage(p);
  const cards = (start: number, end: number) =>
    data.concernLibrary.slice(start, end).map((concern, i) => {
      const Icon = concernIcons[start + i];
      return (
        <button
          key={concern.id}
          className={`flex min-h-[87px] w-full items-center gap-3 rounded-[17px] border p-4 text-left ${p.state.concern === concern.id ? 'border-primary bg-[#eadfcd]' : 'border-[#decbb0] bg-[#fffaf1]'}`}
          onClick={() => {
            p.update({ concern: concern.id, option: null, topic: concern.topic as Topic });
            p.navigate('concern');
          }}
        >
          <span className="grid h-11 w-11 shrink-0 place-items-center rounded-full border border-[#dbc39a] bg-[#f2e6cb] text-[#9c7945]">
            <Icon size={23} strokeWidth={1.5} />
          </span>
          <span className="min-w-0 flex-1">
            <small className="text-[11px] text-[#997d58]">{concern.label}</small>
            <b className="mt-1 block text-[15px] font-normal leading-7">{concern.question}</b>
          </span>
          <ArrowRight size={15} className="shrink-0 text-accent" />
        </button>
      );
    });
  return (
    <div data-testid="jy-questions-page">
      <PageIntro title={p.t.f_concern.replace(/（.*?）/, '')} sub={p.t.w_hubSub} />
      <div className="space-y-3">{cards(0, 6)}</div>
      <details className="my-5">
        <summary className="cursor-pointer py-2 text-sm text-[#8c6f49]">
          {p.t.j_otherConcerns}
        </summary>
        <div className="mt-3 space-y-3">{cards(6, 10)}</div>
      </details>
      <button className="jy-outline w-full" onClick={() => p.navigate('chat')}>
        {p.t.j_noQuestion}
      </button>
      <button
        className="mt-4 min-h-11 w-full text-sm text-[#9a7d56]"
        onClick={() => p.navigate('overview')}
      >
        {p.t.w_home} →
      </button>
    </div>
  );
}

export function WanjaiConcern(p: WanjaiPageProps) {
  const { t, state, update, navigate } = p;
  const { data, concern, solution } = usePage(p);
  if (!concern || !solution) return <WanjaiQuestions {...p} />;
  const Icon = concernIcons[data.concernLibrary.findIndex((row) => row.id === concern.id)];
  const option = solution.options.find((row) => row.id === state.option);
  const path = option ? solution.paths[solution.options.indexOf(option)] : null;
  return (
    <div className="space-y-[18px]" data-testid="jy-concern-page">
      <button className="min-h-10 text-sm text-[#9b8058]" onClick={() => navigate('questions')}>
        ‹ {t.w_chooseQuestion}
      </button>
      <header className="text-center">
        <span className="mx-auto grid h-16 w-16 place-items-center rounded-full border border-[#d8bf91] bg-[#eee0c5] text-[#9c7945]">
          <Icon size={29} strokeWidth={1.5} />
        </span>
        <p className="jy-kicker mt-4">
          {concern.label} · {t.j_nextStep}
        </p>
        <h1 className="mt-2 text-[25px] font-medium leading-[1.65]">{concern.question}</h1>
      </header>
      <TalkEntry p={p} compact text={t.j_topicCaption} />
      <section className="jy-card">
        <h2 className="mb-2 text-[17px]">{solution.intakeTitle}</h2>
        <p className="mb-4 text-xs leading-6 text-muted">{t.w_savedContext}</p>
        <div className="space-y-2">
          {solution.options.map((row) => (
            <button
              key={row.id}
              aria-pressed={state.option === row.id}
              className={`flex min-h-12 w-full items-center gap-3 rounded-xl border p-3 text-left text-sm leading-7 ${state.option === row.id ? 'border-primary bg-[#efe1cf] text-accent' : 'border-line bg-[#fbf6ec]'}`}
              onClick={() => update({ option: row.id as 'a' | 'b' })}
            >
              <span className="flex-1">{row.label}</span>
              {state.option === row.id && <Check size={16} />}
            </button>
          ))}
        </div>
      </section>
      <details className="jy-card !p-0">
        <summary className="cursor-pointer p-4 text-sm text-[#92754f]">{t.j_themeOverview}</summary>
        <div className="border-t border-line px-4 pb-4">
          <ThaiBasis p={p} topic={concern.topic as Topic} />
        </div>
      </details>
      <article className="rounded-[19px] border-l-[3px] border-[#b99a65] bg-[#ede3d0] p-5">
        <p className="jy-kicker">
          {t.j_conclusion} · {t.w_editorial}
        </p>
        <p className="mt-3 text-[16px] leading-8">{option?.summary || concern.lead}</p>
        {path && (
          <>
            <h2 className="mb-2 mt-5 text-[17px] leading-7">{path.title}</h2>
            <p className="jy-copy">{path.action}</p>
          </>
        )}
      </article>
      {!option && (
        <section>
          <h2 className="mb-2 text-xl">{t.j_smallSteps}</h2>
          <p className="mb-4 text-xs leading-6 text-muted">{t.j_stepHelp}</p>
          <div className="space-y-2">
            {concern.steps.map((step, i) => {
              const key = `${bangkokDay()}:${concern.id}:${i}`;
              const done = state.checks.includes(key);
              return (
                <button
                  key={key}
                  aria-pressed={done}
                  className={`flex w-full items-center gap-3 rounded-xl border p-4 text-left ${done ? 'border-[#9faa8e] bg-[#e8ecdf]' : 'border-line bg-panel'}`}
                  onClick={() =>
                    update({
                      checks: done
                        ? state.checks.filter((row) => row !== key)
                        : [...state.checks, key],
                    })
                  }
                >
                  <span className="grid h-7 w-7 shrink-0 place-items-center rounded-full border border-gold/40 text-xs text-gold">
                    {done ? <Check size={14} /> : i + 1}
                  </span>
                  <span className="text-sm leading-7">{step}</span>
                </button>
              );
            })}
          </div>
        </section>
      )}
      <JourneyCard p={p} />
      <section className="jy-card">
        <h2 className="mb-2 text-[18px]">{t.w_followups}</h2>
        {concern.followups.map((q) => (
          <button key={q} className="jy-link" onClick={() => p.ask(q)}>
            <span>{q}</span>
            <ArrowRight size={15} className="shrink-0 text-accent" />
          </button>
        ))}
        <button className="jy-primary mt-4 w-full" onClick={() => p.ask(concern.question)}>
          {t.w_askOwn}
          <ArrowRight size={16} />
        </button>
      </section>
      <section className="rounded-[19px] border border-[#d6c29e] bg-[#eee3cf] p-5">
        <p className="jy-kicker">{t.w_preview}</p>
        <h2 className="my-2 text-xl">{t.w_solution}</h2>
        <p className="jy-copy">{t.w_planIntro}</p>
        <button className="jy-outline mt-4 w-full" onClick={() => navigate('solution')}>
          {t.w_preview}
          <ArrowRight size={16} />
        </button>
      </section>
      <p className="text-xs leading-7 text-[#9b8a6f]">
        {t.w_editorial} · {t.j_backendNote}
      </p>
      <button className="jy-outline w-full" onClick={() => navigate('overview')}>
        {t.w_today}
        <ArrowRight size={16} />
      </button>
    </div>
  );
}
