import { useEffect, useState } from 'react';
import { ArrowRight, MessageCircle } from 'lucide-react';
import type { WanjaiPageProps } from './wanjai/WanjaiShared';
import { usePage } from './wanjai/WanjaiShared';

export function GuestChat({
  p,
  prefill,
  onContinue,
}: {
  p: WanjaiPageProps;
  prefill?: { text: string; id: number };
  onContinue: (text: string) => void;
}) {
  const [input, setInput] = useState(prefill?.text || '');
  const { concern, solution } = usePage(p);
  useEffect(() => {
    if (prefill) setInput(prefill.text);
  }, [prefill?.id]);
  return (
    <section className="jy-chat flex flex-col bg-panel" aria-label={p.t.w_questions}>
      <header className="flex items-center gap-3 px-4 pb-3 pt-4">
        <span className="grid h-11 w-11 place-items-center rounded-[15px] bg-primary text-on-primary">
          <MessageCircle size={24} />
        </span>
        <div className="flex-1">
          <h1 className="text-[17px] font-semibold">
            {p.t.brandName} · {p.t.w_questions}
          </h1>
          <p className="mt-1 text-xs text-ink/85">{p.t.j_listen}</p>
        </div>
      </header>
      <div className="border-y border-line bg-surface px-4 py-2">
        <button
          className="text-xs leading-6 text-muted"
          aria-label={p.t.j_chooseTopic}
          onClick={() => p.navigate('questions')}
        >
          {concern?.label || p.t.j_chooseTopic} ⌄
        </button>
      </div>
      <div className="flex-1 overflow-y-auto p-5">
        <div className="rounded-[20px] rounded-tl-sm border border-line bg-panel p-5">
          <p className="text-base leading-8">{concern?.question || p.t.j_startTalk}</p>
          <p className="mt-3 text-sm leading-7 text-ink/85">{p.t.j_loginChat}</p>
          {solution && p.state.option && (
            <p className="mt-3 border-t border-line pt-3 text-xs leading-6 text-muted">
              {solution.options.find((option) => option.id === p.state.option)?.summary}
            </p>
          )}
        </div>
        <div className="mt-5 space-y-2">
          {(concern?.followups || [p.t.w_daily, p.t.j_nextStep, p.t.w_lifeIntro])
            .slice(0, 3)
            .map((text) => (
              <button
                key={text}
                className="jy-outline w-full justify-between text-left"
                onClick={() => setInput(text)}
              >
                {text} ↗
              </button>
            ))}
        </div>
      </div>
      <form
        className="border-t border-line bg-panel px-4 py-3"
        onSubmit={(event) => {
          event.preventDefault();
          onContinue(input.trim());
        }}
      >
        <label htmlFor="guest-chat-input" className="sr-only">
          {p.t.j_askPlaceholder}
        </label>
        <div className="jy-composer">
          <textarea
            id="guest-chat-input"
            rows={1}
            className="jy-chat-input"
            placeholder={p.t.j_askPlaceholder}
            maxLength={2000}
            value={input}
            onChange={(e) => setInput(e.target.value)}
          />
        </div>
        <p className="my-2 text-[11px] leading-5 text-muted">{p.t.ux_loginDraft}</p>
        <button type="submit" className="jy-primary w-full !py-2.5 !text-sm">
          {p.t.j_loginContinue}
          <ArrowRight size={16} />
        </button>
      </form>
    </section>
  );
}
