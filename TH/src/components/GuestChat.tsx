import { useEffect, useState } from 'react';
import { ArrowUp, MessageCircle, MoreHorizontal } from 'lucide-react';
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
    <section className="jy-chat flex flex-col bg-[#f8f4ec]" aria-label={p.t.w_questions}>
      <header className="flex items-center gap-3 px-4 pb-3 pt-4">
        <span className="grid h-11 w-11 place-items-center rounded-[15px] bg-primary text-white">
          <MessageCircle size={24} />
        </span>
        <div className="flex-1">
          <h1 className="text-[17px] font-semibold">
            {p.t.brandName} · {p.t.w_questions}
          </h1>
          <p className="mt-1 text-xs text-[#78674f]">{p.t.j_listen}</p>
        </div>
        <button
          className="jy-icon"
          aria-label={p.t.j_chatOptions}
          onClick={() => onContinue(input)}
        >
          <MoreHorizontal size={20} />
        </button>
      </header>
      <div className="border-y border-[#e3d8c8] bg-[#f2ebdf] px-4 py-2">
        <button
          className="text-xs leading-6 text-[#806447]"
          aria-label={p.t.j_chooseTopic}
          onClick={() => p.navigate('questions')}
        >
          {concern?.label || p.t.j_chooseTopic} ⌄
        </button>
      </div>
      <div className="flex-1 overflow-y-auto p-5">
        <div className="rounded-[20px] rounded-tl-sm border border-[#e8dece] bg-[#fffaf1] p-5">
          <p className="text-base leading-8">{concern?.question || p.t.j_startTalk}</p>
          <p className="mt-3 text-sm leading-7 text-[#8b765b]">{p.t.j_loginChat}</p>
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
        className="border-t border-line bg-[#f7f1e7] px-4 py-3"
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
          <button
            type="submit"
            className="grid h-11 w-11 shrink-0 place-items-center rounded-2xl bg-primary text-white"
            aria-label={p.t.j_loginContinue}
          >
            <ArrowUp size={19} />
          </button>
        </div>
      </form>
    </section>
  );
}
