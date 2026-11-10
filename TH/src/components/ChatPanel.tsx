import { useEffect, useRef, useState, type FormEvent } from 'react';
import {
  ArrowDown,
  ArrowUp,
  ArrowUpRight,
  Bookmark,
  MessageCircle,
  MoreHorizontal,
  Sparkles,
  Square,
  Trash2,
} from 'lucide-react';
import type { Copy } from '../lib/i18n';
import type { ChatEvidence, Memory, Message, Provider, ProviderId } from '../types';
import { BrandMark } from './BrandMark';
import { PickerDialog } from './PickerDialog';
import { ChatEvidencePanel } from './ChatEvidencePanel';

interface Props {
  t: Copy;
  messages: Message[];
  draft: string;
  generating: boolean;
  hasProfile: boolean;
  providers: Provider[];
  provider: ProviderId;
  expanded: boolean;
  onProvider: (id: ProviderId) => void;
  onSend: (message: string) => void;
  onStop: () => void;
  onClear: () => void;
  onProfile: () => void;
  prefill?: { text: string; id: number };
  draftKey?: string;
  onPrefillConsumed?: () => void;
  evidence?: ChatEvidence;
  memories?: Memory[];
  onRemember?: (content: string) => Promise<void>;
  onMemories?: () => void;
  realModelReady?: boolean;
  onTopics?: () => void;
  contextTitle?: string;
  contextSummary?: string;
}
export function ChatPanel({
  t,
  messages,
  draft,
  generating,
  hasProfile,
  providers,
  provider,
  onProvider,
  onSend,
  onStop,
  onClear,
  onProfile,
  prefill,
  draftKey,
  onPrefillConsumed,
  evidence,
  memories = [],
  onRemember,
  onMemories,
  realModelReady = false,
  onTopics,
  contextTitle,
  contextSummary,
}: Props) {
  const [optionsOpen, setOptionsOpen] = useState(false);
  const [historyOpen, setHistoryOpen] = useState(false);
  const [input, setInput] = useState(() => {
    try {
      return draftKey ? sessionStorage.getItem(`wanjai.chatDraft:${draftKey}`) || '' : '';
    } catch {
      return '';
    }
  });
  useEffect(() => {
    if (prefill) {
      setInput(prefill.text);
      onPrefillConsumed?.();
    }
  }, [prefill, onPrefillConsumed]);
  useEffect(() => {
    if (draftKey)
      try {
        sessionStorage.setItem(`wanjai.chatDraft:${draftKey}`, input);
      } catch {
        /* Keep the draft in memory when browser storage is unavailable. */
      }
  }, [draftKey, input]);
  const scroll = useRef<HTMLDivElement>(null);
  const inputRef = useRef<HTMLTextAreaElement>(null);
  const nearBottom = useRef(true);
  const [showScroll, setShowScroll] = useState(false);
  const [composing, setComposing] = useState(false);
  const [memoryDraft, setMemoryDraft] = useState<string | null>(null);
  const [savingMemory, setSavingMemory] = useState(false);
  const [memoryError, setMemoryError] = useState('');
  async function confirmMemory() {
    if (!onRemember || !memoryDraft?.trim() || savingMemory) return;
    setSavingMemory(true);
    setMemoryError('');
    try {
      await onRemember(memoryDraft.trim());
      setMemoryDraft(null);
    } catch (err) {
      setMemoryError(err instanceof Error ? err.message : String(err));
    } finally {
      setSavingMemory(false);
    }
  }
  useEffect(() => {
    if (!scroll.current) return;
    if (!messages.length && !generating) scroll.current.scrollTop = 0;
    else if (nearBottom.current) scroll.current.scrollTop = scroll.current.scrollHeight;
  }, [messages, draft, generating]);
  function submit(event?: FormEvent) {
    event?.preventDefault();
    if (!input.trim() || generating || !hasProfile) return;
    const message = input.trim();
    setInput('');
    nearBottom.current = true;
    onSend(message);
  }
  return (
    <section
      className="jy-chat flex min-w-0 flex-col overflow-hidden bg-panel"
      aria-labelledby="chat-title"
    >
      <header className="flex shrink-0 items-center gap-3 px-4 pb-3 pt-4">
        <span className="grid h-[42px] w-[42px] shrink-0 place-items-center rounded-[15px] bg-primary text-on-primary">
          <MessageCircle size={24} strokeWidth={1.5} />
        </span>
        <div className="min-w-0 flex-1">
          <h1 id="chat-title" className="text-[17px] font-semibold">
            {t.brandName} · {t.w_questions}
          </h1>
          <p className="mt-1 text-xs text-ink/85">{t.j_listen}</p>
        </div>
        <button
          className="jy-icon"
          aria-label={t.j_chatOptions}
          onClick={() => setOptionsOpen(true)}
        >
          <MoreHorizontal size={22} />
        </button>
      </header>
      <div className="flex shrink-0 items-center justify-between gap-2 border-y border-line bg-surface px-4 py-2">
        <button
          className="min-h-7 text-xs text-muted"
          aria-label={t.j_chooseTopic}
          disabled={generating}
          onClick={onTopics}
        >
          {contextTitle || t.j_chooseTopic} ⌄
        </button>
        <button className="text-[10px] text-muted" onClick={() => setOptionsOpen(true)}>
          {provider === 'mock' ? t.demo : t.brandName}
        </button>
      </div>
      {contextSummary && (
        <details className="shrink-0 border-b border-line bg-panel px-4 py-2 text-xs leading-6 text-muted">
          <summary className="cursor-pointer">{t.j_context}</summary>
          <p className="py-2">{contextSummary}</p>
        </details>
      )}
      {provider === 'mock' && (
        <p
          className="border-b border-line bg-surface px-5 py-3 text-[11px] leading-6 text-muted"
          role="note"
        >
          {realModelReady ? t.m_demoSelected : t.m_modelMissing}
        </p>
      )}
      <div className="relative min-h-0 flex-1">
        <div
          ref={scroll}
          className="chat-scroll h-full overflow-y-auto px-4 py-5"
          onScroll={() => {
            const el = scroll.current!;
            nearBottom.current = el.scrollHeight - el.scrollTop - el.clientHeight < 70;
            setShowScroll(!nearBottom.current);
          }}
          role="log"
          aria-label={t.chatTitle}
          aria-live="polite"
          aria-relevant="additions text"
        >
          {!messages.length && !generating ? (
            <div className="flex min-h-full flex-col justify-start pb-3 ">
              <div className="mx-auto mb-6 flex h-20 w-20 items-center justify-center rounded-[26px] border border-accent/5 bg-surface">
                <BrandMark className="h-12 w-12 text-accent/70" />
              </div>
              <p className="text-center text-[10px] tracking-[.2em] text-accent/80">{t.moment}</p>
              <h3 className="mt-4 text-center text-xl font-medium tracking-wide">{t.welcome}</h3>
              <p className="mx-auto mt-3 max-w-72 text-center text-xs leading-6 text-muted">
                {t.welcomeNote}
              </p>
              <div className="mx-auto mt-7 w-full max-w-sm space-y-2">
                {[t.prompt1, t.prompt2, t.prompt3].map((prompt) => (
                  <button
                    key={prompt}
                    className="flex w-full items-center gap-3 rounded-xl border border-line bg-canvas px-4 py-3 text-left text-xs text-ink/80 hover:border-accent/25 hover:bg-surface/50"
                    onClick={() => {
                      if (hasProfile) {
                        setInput(prompt);
                        inputRef.current?.focus();
                      } else onProfile();
                    }}
                  >
                    <Sparkles size={13} className="shrink-0 text-gold" />
                    <span className="flex-1">{prompt}</span>
                    <ArrowUpRight size={13} className="shrink-0 text-muted" />
                  </button>
                ))}
              </div>
            </div>
          ) : (
            <div className="space-y-6">
              {messages.map((message) => (
                <div
                  key={message.id}
                  id={`message-${message.id}`}
                  className={`enter flex gap-3 ${message.role === 'user' ? 'flex-row-reverse' : ''}`}
                >
                  {message.role === 'assistant' && (
                    <span className="mt-1 flex h-7 w-7 shrink-0 items-center justify-center rounded-lg bg-primary text-on-primary">
                      <BrandMark className="h-4 w-4" />
                    </span>
                  )}
                  <div
                    className={`min-w-0 max-w-[90%] rounded-2xl px-4 py-3 ${message.role === 'user' ? 'rounded-tr-sm bg-surface' : 'flex-1 rounded-tl-sm bg-surface'}`}
                  >
                    <div className="mb-1.5 text-[10px] font-medium text-muted">
                      {message.role === 'user' ? t.you : t.brandName}
                      {message.role === 'assistant' && message.provider === 'mock'
                        ? ` · ${t.demo}`
                        : ''}
                    </div>
                    <p className="whitespace-pre-wrap break-words text-[13px] leading-7">
                      {message.content}
                    </p>
                    {message.role === 'user' && onRemember && (
                      <button
                        type="button"
                        className="btn-quiet mt-2 !px-0 !py-1 !text-[10px]"
                        disabled={generating || memories.length >= 20}
                        onClick={() => {
                          setMemoryDraft(message.content.slice(0, 500));
                          setMemoryError('');
                        }}
                      >
                        <Bookmark size={12} />
                        {t.m_remember}
                      </button>
                    )}
                    {message.evidence && <ChatEvidencePanel value={message.evidence} t={t} />}
                  </div>
                </div>
              ))}
              {generating && (
                <div className="flex gap-3">
                  <span className="mt-1 flex h-7 w-7 shrink-0 items-center justify-center rounded-lg bg-primary text-on-primary">
                    <BrandMark className="h-4 w-4" />
                  </span>
                  <div className="min-w-0 flex-1 rounded-2xl rounded-tl-sm bg-surface px-4 py-3">
                    <div className="mb-1.5 text-[10px] font-medium text-muted">
                      {t.brandName}
                      {provider === 'mock' ? ` · ${t.demo}` : ''}
                    </div>
                    <p className="whitespace-pre-wrap break-words text-[13px] leading-7">
                      {draft || t.thinking}
                      <span className="ml-1 inline-block h-3 w-1 animate-pulse bg-accent/60" />
                    </p>
                    {evidence && <ChatEvidencePanel value={evidence} t={t} />}
                  </div>
                </div>
              )}
            </div>
          )}
        </div>
        {showScroll && (
          <button
            aria-label={t.latestMessage}
            className="absolute bottom-3 right-5 rounded-full border border-line bg-surface p-2 shadow-soft"
            onClick={() => {
              scroll.current?.scrollTo({ top: scroll.current.scrollHeight, behavior: 'smooth' });
              nearBottom.current = true;
            }}
          >
            <ArrowDown size={15} />
          </button>
        )}
      </div>
      <form className="border-t border-line px-4 py-3 sm:px-6" onSubmit={submit}>
        {!hasProfile && (
          <button
            type="button"
            className="mb-3 flex w-full items-center justify-between rounded-lg bg-surface px-3 py-2 text-xs text-accent"
            onClick={onProfile}
          >
            {t.needProfile}
            <ArrowUpRight size={14} />
          </button>
        )}
        <div className="jy-composer">
          <label className="sr-only" htmlFor="chat-input">
            {t.inputPlaceholder}
          </label>
          <textarea
            id="chat-input"
            ref={inputRef}
            rows={1}
            maxLength={2000}
            className="jy-chat-input"
            placeholder={hasProfile ? t.inputPlaceholder : t.needProfile}
            value={input}
            disabled={!hasProfile || generating}
            onChange={(e) => setInput(e.target.value)}
            onCompositionStart={() => setComposing(true)}
            onCompositionEnd={() => setComposing(false)}
            onKeyDown={(e) => {
              if (e.key === 'Enter' && !e.shiftKey && !e.nativeEvent.isComposing && !composing) {
                e.preventDefault();
                submit();
              }
            }}
          />
          {generating ? (
            <button
              type="button"
              onClick={onStop}
              className="grid h-11 w-11 shrink-0 place-items-center rounded-2xl bg-primary text-on-primary hover:bg-primary/90"
              aria-label={t.stop}
            >
              <Square size={16} fill="currentColor" />
            </button>
          ) : (
            <button
              type="submit"
              className="grid h-11 w-11 shrink-0 place-items-center rounded-2xl bg-primary text-on-primary hover:bg-primary/90"
              aria-label={t.send}
              disabled={!input.trim() || !hasProfile}
            >
              <ArrowUp size={17} />
            </button>
          )}
        </div>
      </form>
      {optionsOpen && (
        <PickerDialog
          title={t.j_chatOptions}
          t={t}
          onCancel={() => setOptionsOpen(false)}
          onConfirm={() => setOptionsOpen(false)}
        >
          <label className="label" htmlFor="chat-model">
            {t.providerLabel}
          </label>
          <select
            id="chat-model"
            value={provider}
            disabled={generating}
            className="field mb-4"
            onChange={(e) => onProvider(e.target.value as ProviderId)}
          >
            {providers.map((option) => (
              <option key={option.id} value={option.id} disabled={!option.enabled}>
                {option.id === 'mock'
                  ? t.demo
                  : option.id === 'companion'
                    ? t.m_companionMode
                    : option.name}
                {!option.enabled ? ` · ${t.notConfigured}` : ''}
              </option>
            ))}
          </select>
          {onMemories && (
            <button
              className="jy-link"
              disabled={generating}
              onClick={() => {
                setOptionsOpen(false);
                onMemories();
              }}
            >
              <Bookmark size={16} />
              <span className="flex-1">
                {t.m_manage} · {memories.length}
              </span>
              ↗
            </button>
          )}
          <button
            className="jy-link"
            onClick={() => {
              setOptionsOpen(false);
              setHistoryOpen(true);
            }}
          >
            {t.j_viewHistory} ↗
          </button>
          <button
            className="jy-link text-accent"
            disabled={generating || !messages.length}
            onClick={() => {
              setOptionsOpen(false);
              onClear();
            }}
          >
            <Trash2 size={16} />
            {t.clear}
          </button>
          <p className="mt-4 text-xs leading-7 text-muted">{t.m_privacy}</p>
        </PickerDialog>
      )}
      {historyOpen && (
        <PickerDialog
          title={t.j_viewHistory}
          t={t}
          onCancel={() => setHistoryOpen(false)}
          onConfirm={() => setHistoryOpen(false)}
        >
          <div className="max-h-[45dvh] space-y-4 overflow-y-auto">
            {messages
              .filter((message) => message.role === 'user')
              .map((message) => (
                <button
                  key={message.id}
                  className="jy-link"
                  onClick={() => {
                    setHistoryOpen(false);
                    document
                      .getElementById(`message-${message.id}`)
                      ?.scrollIntoView({ block: 'center' });
                  }}
                >
                  {message.content}
                </button>
              ))}
          </div>
        </PickerDialog>
      )}
      {memoryDraft !== null && (
        <PickerDialog
          title={t.m_confirm}
          t={t}
          confirmLabel={savingMemory ? t.loading : t.remember}
          confirmDisabled={savingMemory || !memoryDraft.trim()}
          onCancel={() => {
            if (!savingMemory) setMemoryDraft(null);
          }}
          onConfirm={() => void confirmMemory()}
        >
          <p className="mb-4 text-xs leading-6 text-muted">{t.m_noteHelp}</p>
          <label className="label" htmlFor="chat-memory">
            {t.m_editText}
          </label>
          <textarea
            id="chat-memory"
            className="field min-h-28"
            value={memoryDraft}
            maxLength={500}
            onChange={(event) => setMemoryDraft(event.target.value)}
          />
          {memoryError && (
            <p role="alert" className="mt-3 text-xs text-accent">
              {memoryError}
            </p>
          )}
        </PickerDialog>
      )}
    </section>
  );
}
