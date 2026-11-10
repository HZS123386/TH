import { useState } from 'react';
import { ArrowRight, Bell, Check, Leaf, Pause, Play, RotateCcw } from 'lucide-react';
import { bangkokDay, contentFor } from '../../lib/wanjai';
import { PickerDialog } from '../PickerDialog';
import {
  type WanjaiPageProps,
  feedbackNames,
  palettes,
  PageIntro,
  ArrowButton,
  Note,
  usePage,
} from './WanjaiShared';

export function WanjaiJourney(p: WanjaiPageProps) {
  const { t, state, update, navigate } = p;
  const { concern, solution } = usePage(p);
  const [reset, setReset] = useState(false);
  if (!concern)
    return (
      <>
        <PageIntro title={t.w_journey} sub={t.w_journeyNeed} />
        <ArrowButton onClick={() => navigate('questions')}>{t.w_chooseQuestion}</ArrowButton>
      </>
    );
  const records = state.records.filter((r) => r.concern === concern.id);
  const recorded = records.some((r) => r.day === bangkokDay());
  const steps = [...concern.steps, ...concern.followupAnswers, t.th_lifePractice, concern.steps[0]];
  const advice =
    records.at(-1)?.feedback === 'hard'
      ? concern.steps[0]
      : records.length === 0 && state.option && solution
        ? solution.paths[state.option === 'b' ? 1 : 0].action
        : steps[Math.min(records.length, 6)];
  return (
    <div className="mx-auto max-w-3xl">
      <button className="mb-3 min-h-10 text-sm text-muted" onClick={() => navigate('concern')}>
        ‹ {t.j_backQuestion}
      </button>
      <PageIntro title={t.j_journeyTitle} sub={concern.question} />
      <section className="panel p-6 sm:p-8">
        <p className="text-xs text-muted">{t.w_journeyHint}</p>
        <div className="my-6 flex gap-2" aria-label={`${records.length} / 7`}>
          {Array.from({ length: 7 }, (_, i) => (
            <span
              key={i}
              className={`h-1.5 flex-1 rounded-full ${i < records.length ? 'bg-primary' : 'bg-line'}`}
            />
          ))}
        </div>
        <p className="mb-3 text-xs text-gold">
          {t.w_step} {Math.min(records.length + 1, 7)} / 7
        </p>
        <h2 className="font-display text-xl leading-9">
          {records.length === 7 ? t.w_completed : state.paused ? t.w_pause : advice}
        </h2>
        {records.length < 7 && !state.paused && (
          <div className="mt-7">
            <p className="mb-3 text-sm text-muted">{recorded ? t.w_dayRecorded : t.w_record}</p>
            <div className="flex flex-wrap gap-3">
              {(['good', 'ordinary', 'hard'] as const).map((feedback) => (
                <button
                  key={feedback}
                  disabled={recorded}
                  className="btn-quiet border border-line"
                  onClick={() =>
                    update({
                      records: [
                        ...state.records,
                        { concern: concern.id, day: bangkokDay(), feedback },
                      ],
                    })
                  }
                >
                  {t[feedbackNames[feedback]]}
                </button>
              ))}
            </div>
          </div>
        )}
        <div className="mt-7 flex flex-wrap gap-3 border-t border-line pt-4">
          <button className="btn-quiet !text-xs" onClick={() => update({ paused: !state.paused })}>
            {state.paused ? <Play size={14} /> : <Pause size={14} />}
            {state.paused ? t.w_resume : t.w_pause}
          </button>
          {records.length > 0 && (
            <button
              className="btn-quiet !text-xs"
              onClick={() => {
                const last = records.at(-1)!;
                update({
                  records: state.records.filter(
                    (r) => !(r.concern === last.concern && r.day === last.day),
                  ),
                });
              }}
            >
              <RotateCcw size={14} />
              {t.w_undo}
            </button>
          )}
        </div>
      </section>
      <h2 className="mb-3 mt-7 font-display text-xl">{t.w_records}</h2>
      {records.map((r, i) => (
        <div
          key={r.day}
          className="mb-3 flex flex-wrap items-center gap-4 rounded-xl border border-line bg-panel p-4 text-sm"
        >
          <span className="text-gold">{i + 1}</span>
          <span className="flex-1">
            {r.day} · {t.w_bangkok}
          </span>
          <span className="text-accent">{t[feedbackNames[r.feedback]]}</span>
        </div>
      ))}
      <Note>{t.w_basisNote}</Note>
      <button className="jy-outline w-full" onClick={() => setReset(true)}>
        {t.j_restartJourney}
      </button>
      {reset && (
        <PickerDialog
          title={t.j_restartJourney}
          t={t}
          onCancel={() => setReset(false)}
          onConfirm={() => {
            update({
              records: state.records.filter((row) => row.concern !== concern.id),
              paused: false,
            });
            setReset(false);
          }}
        >
          <p className="jy-copy">{t.j_resetJourneyNote}</p>
        </PickerDialog>
      )}
    </div>
  );
}

export function WanjaiDaily(p: WanjaiPageProps & { embedded?: boolean }) {
  const { t, state, update, navigate } = p;
  const { data, concern, solution } = usePage(p);
  const [settings, setSettings] = useState(false);
  const [preview, setPreview] = useState(false);
  const [draftFrequency, setDraftFrequency] = useState(state.frequency);
  const [draftTime, setDraftTime] = useState(state.reminder_time);
  const weekday = new Date(`${bangkokDay()}T12:00:00+07:00`).getUTCDay();
  const action =
    state.mood === 'tired'
      ? t.w_rhythmNote
      : (state.option && solution?.paths[state.option === 'b' ? 1 : 0].action) ||
        concern?.steps[weekday % 3] ||
        data.COMPANION_WEEKLY_ACTIONS[state.topic][(weekday + 6) % 7][0];
  return (
    <div className="mx-auto max-w-4xl">
      {!p.embedded && <PageIntro title={t.w_daily} sub={`${bangkokDay()} · ${t.w_bangkok}`} />}
      <section className="rounded-[22px] border border-line bg-[radial-gradient(ellipse_at_110%_-10%,#6c428e66,transparent_65%)] bg-surface p-[21px] text-ink [&_.btn-quiet]:text-gold">
        <p className="mb-4 text-xs text-gold">✧ {t.j_todayMessage}</p>
        <h2 className="mb-3 font-display text-[26px] leading-[1.55]">
          {state.mood === 'tired' ? t.j_todayGentle : t.w_focus}
        </h2>
        <p className="mb-5 text-sm leading-8 text-ink/85">{action}</p>
        <h2 className="mb-4 text-sm">{t.w_mood}</h2>
        <div className="flex flex-wrap gap-3">
          {(['steady', 'ready', 'tired'] as const).map((mood) => (
            <button
              key={mood}
              aria-pressed={state.mood === mood}
              className={`flex-1 rounded-xl border px-2 py-2.5 text-xs ${state.mood === mood ? 'border-gold bg-primary text-on-primary' : 'border-line text-ink'}`}
              onClick={() => update({ mood })}
            >
              {t[`w_${mood}`]}
            </button>
          ))}
        </div>
        <button className="btn-quiet mt-4 !px-0" onClick={() => p.ask(concern?.question || action)}>
          {t.w_talk}
          <ArrowRight size={15} />
        </button>
      </section>
      <div className="my-4 grid gap-4">
        <section className="panel p-6">
          <Leaf className="mb-4 text-gold" size={25} />
          <h2 className="font-display text-xl">{t.w_rhythm}</h2>
          <div className="my-4 flex gap-2">
            {(['day', 'late'] as const).map((routine) => (
              <button
                key={routine}
                className="btn-quiet border border-line !text-xs"
                aria-pressed={state.routine === routine}
                onClick={() => update({ routine })}
              >
                {state.routine === routine && <Check size={13} />}
                {routine === 'day' ? t.w_dayRoutine : t.w_lateRoutine}
              </button>
            ))}
          </div>
          <p className="text-sm leading-7 text-muted">{t.w_rhythmNote}</p>
        </section>
        <section className="panel p-6">
          <h2 className="font-display text-xl">{t.w_palette}</h2>
          <div className="my-5 flex gap-4">
            {palettes[weekday % 4].map((color) => (
              <span
                key={color}
                className="h-16 w-16 rounded-full border border-black/5"
                style={{ backgroundColor: color }}
              />
            ))}
          </div>
          <p className="text-xs leading-6 text-muted">{t.w_paletteNote}</p>
          <button className="btn-quiet mt-3 !px-0" onClick={() => navigate('shop')}>
            {t.w_shop}
            <ArrowRight size={15} />
          </button>
        </section>
      </div>
      <section className="panel flex flex-wrap items-start gap-4 p-6">
        <Bell className="text-gold" size={23} />
        <div className="flex-1">
          <h2 className="text-base">{t.w_reminder}</h2>
          <p className="my-2 text-sm text-accent">
            {
              t[
                state.frequency === 'off'
                  ? 'w_off'
                  : state.frequency === 'daily'
                    ? 'w_dailyOption'
                    : 'w_weeklyOption'
              ]
            }{' '}
            · {state.reminder_time}
          </p>
          <p className="text-xs leading-6 text-muted">{t.w_lineOff}</p>
        </div>
        <button
          className="btn-quiet border border-line"
          onClick={() => {
            setDraftFrequency(state.frequency);
            setDraftTime(state.reminder_time);
            setSettings(true);
          }}
        >
          {t.w_reminder}
        </button>
        <button className="btn-quiet" onClick={() => setPreview(true)}>
          {t.w_reminderPreview}
        </button>
      </section>
      <Note>{t.w_basisNote}</Note>
      {settings && (
        <PickerDialog
          title={t.w_reminder}
          t={t}
          onCancel={() => setSettings(false)}
          onConfirm={() => {
            update({ frequency: draftFrequency, reminder_time: draftTime });
            setSettings(false);
          }}
        >
          <label className="label" htmlFor="reminder-frequency">
            {t.w_frequency}
          </label>
          <select
            id="reminder-frequency"
            className="field mb-5"
            value={draftFrequency}
            onChange={(e) => setDraftFrequency(e.target.value as typeof draftFrequency)}
          >
            {(['off', 'daily', 'weekly'] as const).map((v) => (
              <option key={v} value={v}>
                {t[v === 'off' ? 'w_off' : v === 'daily' ? 'w_dailyOption' : 'w_weeklyOption']}
              </option>
            ))}
          </select>
          <label className="label" htmlFor="reminder-time">
            {t.w_time}
          </label>
          <input
            id="reminder-time"
            className="field"
            type="time"
            value={draftTime}
            onChange={(e) => setDraftTime(e.target.value || '09:00')}
          />
          <Note>{t.w_lineOff}</Note>
        </PickerDialog>
      )}
      {preview && (
        <PickerDialog
          title={t.w_reminderPreview}
          t={t}
          onCancel={() => setPreview(false)}
          onConfirm={() => setPreview(false)}
        >
          <p className="rounded-xl bg-surface p-5 text-sm leading-7">
            {t.brandName} · {state.reminder_time}
            <br />
            {action}
          </p>
          <Note>{t.w_lineOff}</Note>
        </PickerDialog>
      )}
    </div>
  );
}

export function WanjaiInbox(p: WanjaiPageProps) {
  const { t, state, navigate } = p;
  const { concern } = usePage(p);
  return (
    <div className="mx-auto max-w-3xl">
      <PageIntro title={t.w_inbox} sub={t.w_lineOff} />
      <section className="panel mb-5 p-6">
        <p className="mb-3 text-xs text-gold">
          {t.w_reminderPreview} · {bangkokDay()}
        </p>
        <h2 className="font-display text-xl">{t.w_return}</h2>
        <p className="my-4 text-sm leading-8 text-muted">{concern?.steps[0] || t.w_smallAction}</p>
        <ArrowButton onClick={() => navigate('daily')}>{t.w_daily}</ArrowButton>
      </section>
      <section className="panel p-6">
        <h2 className="mb-5 font-display text-xl">{t.w_records}</h2>
        {state.records.length ? (
          state.records
            .slice(-7)
            .reverse()
            .map((r) => (
              <div
                className="border-b border-line py-4 text-sm last:border-0"
                key={`${r.concern}:${r.day}`}
              >
                <p className="mb-1 text-xs text-muted">{r.day}</p>
                <p>
                  {contentFor(p.language).concernLibrary.find((c) => c.id === r.concern)?.label} ·{' '}
                  {t[feedbackNames[r.feedback]]}
                </p>
              </div>
            ))
        ) : (
          <p className="text-sm text-muted">{t.w_journeyHint}</p>
        )}
        <button className="btn-quiet mt-5 !px-0" onClick={() => navigate('journey')}>
          {t.w_journey}
          <ArrowRight size={14} />
        </button>
      </section>
      <Note>{t.w_lineOff}</Note>
    </div>
  );
}
