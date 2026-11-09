import { usePageRoute } from './lib/routes';
import { WanjaiShell, type WanjaiBottomAction } from './components/WanjaiShell';
import { GuestChat } from './components/GuestChat';
import { useCallback, useEffect, useRef, useState } from 'react';
import { Check, CircleHelp, RefreshCw, X } from 'lucide-react';
import { api, ApiError, chat, session } from './lib/api';
import { changeLanguage, useLocale } from './lib/i18n';
import { LANGUAGE_KEY, LANGUAGE_CONFIRMED_KEY, normalizeLanguage } from './lib/languages';
import type {
  ChatEvidence,
  Config,
  Account,
  Memory,
  Message,
  Profile,
  ProfileRecord,
  ProviderId,
} from './types';

import { ChartPanel } from './components/ChartPanel';
import { BaziTestPage } from './components/BaziTestPage';
import { ThaiTestPage } from './components/ThaiTestPage';
import { ThaiChartReading } from './components/ThaiChartReading';
import { ChatPanel } from './components/ChatPanel';
import { MemoryPanel } from './components/MemoryPanel';
import { ProfileForm } from './components/ProfileForm';
import { BirthEntry } from './components/BirthEntry';
import { GUEST_BIRTH_KEY, readGuestBirth } from './lib/guestBirth';

import { ModuleCatalog } from './components/ModuleCatalog';
import { Starfield } from './components/Starfield';
import { AuthPanel } from './components/AuthPanel';
import { LanguageChooser } from './components/LanguageChooser';

import {
  WanjaiHome,
  WanjaiQuestions,
  WanjaiConcern,
  WanjaiDaily,
  WanjaiJourney,
  WanjaiReports,
  WanjaiChart,
  WanjaiShop,
  WanjaiMine,
  WanjaiShare,
  WanjaiInbox,
  PageIntro,
} from './components/WanjaiPages';
import { useCompanion } from './lib/useCompanion';
import { useThaiChart } from './lib/thai';
import { contentFor, type WanjaiView } from './lib/wanjai';
type View = WanjaiView;
export default function App() {
  const { language, t } = useLocale();
  const [choosingLanguage, setChoosingLanguage] = useState(
    () =>
      localStorage.getItem(LANGUAGE_CONFIRMED_KEY) !== '1' ||
      !normalizeLanguage(localStorage.getItem(LANGUAGE_KEY)),
  );
  const previousLanguage = useRef(language);
  const [requestedView, setView] = usePageRoute();
  const pendingChat = useRef(false);
  const pendingSituation = useRef<Pick<
    ReturnType<typeof useCompanion>['state'],
    'concern' | 'option' | 'topic' | 'period'
  > | null>(null);
  const [account, setAccount] = useState<Account | null>(null);
  const companion = useCompanion(account?.user_id);
  useEffect(() => {
    if (account && companion.ready && pendingSituation.current) {
      companion.update(pendingSituation.current);
      pendingSituation.current = null;
    }
  }, [account?.user_id, companion.ready]);
  const [chatPrefill, setChatPrefill] = useState<{ text: string; id: number }>();
  useEffect(() => {
    document.documentElement.style.fontSize = companion.state.large_text ? '18px' : '16px';
    return () => {
      document.documentElement.style.fontSize = '';
    };
  }, [companion.state.large_text]);
  const [config, setConfig] = useState<Config | null>(null);
  const [record, setRecord] = useState<ProfileRecord | null>(null);
  const [guestProfile, setGuestProfile] = useState<Profile | null>(readGuestBirth);
  const profile = record?.profile || (!account ? guestProfile : null);
  const thai = useThaiChart(account?.user_id, record, !account ? guestProfile : null);
  const [messages, setMessages] = useState<Message[]>([]);
  const [memories, setMemories] = useState<Memory[]>([]);
  const [provider, setProvider] = useState<ProviderId>('mock');
  const [loading, setLoading] = useState(true);
  const [connectError, setConnectError] = useState('');
  const [expired, setExpired] = useState(false);
  const [error, setError] = useState('');
  const [toast, setToast] = useState('');
  const [baziOpen, setBaziOpen] = useState(false);
  const [chartExample, setChartExample] = useState(false);
  const [thaiBottomAction, setThaiBottomAction] = useState<WanjaiBottomAction>();
  const [generating, setGenerating] = useState(false);
  const [draft, setDraft] = useState('');
  const [chatEvidence, setChatEvidence] = useState<ChatEvidence>();
  const abortRef = useRef<AbortController | null>(null);
  const booting = useRef(false);
  const onboarding = !!account && !record;
  const view =
    onboarding && !['bazi-test', 'thai-test'].includes(requestedView)
      ? 'profile'
      : !account && requestedView === 'memories'
        ? 'auth'
        : requestedView;
  useEffect(() => {
    if (view !== 'chart') setChartExample(false);
  }, [view]);

  const restoreAccount = useCallback(async () => {
    const identity = await api<Account | { kind: 'demo' }>('/api/auth/me');
    if (identity.kind !== 'account') return;
    const storedLanguage = normalizeLanguage(localStorage.getItem(LANGUAGE_KEY));
    if (localStorage.getItem(LANGUAGE_CONFIRMED_KEY) === '1' && storedLanguage) {
      await api('/api/preferences/language', {
        method: 'PUT',
        body: JSON.stringify({ language: storedLanguage }),
      });
    }
    const [saved, history, notes] = await Promise.all([
      api<ProfileRecord | null>('/api/profile'),
      api<Message[]>('/api/history'),
      api<Memory[]>('/api/memories'),
    ]);
    setRecord(saved);
    setMessages(history);
    setMemories(notes);
    setAccount(identity);
    setView((previous) =>
      saved
        ? pendingChat.current
          ? 'chat'
          : previous === 'auth' || previous === 'profile'
            ? 'overview'
            : previous
        : 'profile',
    );
    if (saved) pendingChat.current = false;
  }, []);

  const connect = useCallback(async () => {
    if (booting.current) return;
    booting.current = true;
    setLoading(true);
    setConnectError('');
    try {
      const conf = await api<Config>('/api/config');
      setConfig(conf);
      if (session.get()) await restoreAccount();
      setProvider(
        conf.providers.find((item) => item.id === conf.default_provider && item.enabled)?.id ||
          'mock',
      );
      setExpired(false);
    } catch (err) {
      const authExpired = err instanceof ApiError && err.status === 401;
      setExpired(authExpired);
      if (authExpired) {
        session.clear();
        setError(t.sessionExpired);
      } else setConnectError(err instanceof Error ? err.message : String(err));
    } finally {
      setLoading(false);
      booting.current = false;
    }
  }, [language, restoreAccount]);
  // Establish one session on mount. Language changes don't create a new session.
  useEffect(() => {
    void connect();
    return () => abortRef.current?.abort();
  }, []);
  useEffect(() => {
    if (toast) {
      const timer = setTimeout(() => setToast(''), 3500);
      return () => clearTimeout(timer);
    }
  }, [toast]);

  useEffect(() => {
    document.querySelector('meta[name="theme-color"]')?.setAttribute('content', '#faf8f4');
  }, []);
  function navigate(next: View) {
    setView(!account && next === 'memories' ? 'auth' : next);
    setError('');
  }
  async function authenticated(token: string) {
    session.set(token);
    setLoading(true);
    try {
      await restoreAccount();
      setError('');
    } finally {
      setLoading(false);
    }
  }
  function openLanguages() {
    previousLanguage.current = language;
    setChoosingLanguage(true);
    setToast('');
    setError('');
  }
  async function confirmLanguage() {
    if (account) {
      await api('/api/preferences/language', { method: 'PUT', body: JSON.stringify({ language }) });
      setRecord((prev) => (prev ? { ...prev, profile: { ...prev.profile, language } } : prev));
    }
    localStorage.setItem(LANGUAGE_KEY, language);
    localStorage.setItem(LANGUAGE_CONFIRMED_KEY, '1');
    setChoosingLanguage(false);
    setError('');
    setToast('');
  }
  async function logout() {
    if (!(await companion.flush())) {
      setError(t.w_syncError);
      return;
    }
    try {
      await api('/api/auth/logout', { method: 'POST' });
    } catch (err) {
      if (!(err instanceof ApiError && err.status === 401)) {
        setError(err instanceof Error ? err.message : String(err));
        return;
      }
    }
    session.clear();
    setAccount(null);
    setRecord(null);
    setMessages([]);
    setMemories([]);
    setChatPrefill(undefined);
    pendingChat.current = false;
    pendingSituation.current = null;
    setToast('');
    setView('overview');
    setError('');
  }
  async function saveProfile(profile: Profile) {
    const saved = await api<ProfileRecord>('/api/profile', {
      method: 'PUT',
      body: JSON.stringify(profile),
    });
    setRecord(saved);
    setMessages([]);
    setToast(t.saved);
    navigate(pendingChat.current ? 'chat' : 'overview');
    pendingChat.current = false;
  }
  async function saveGuestBirth(value: Profile, openConcern = false) {
    localStorage.setItem(GUEST_BIRTH_KEY, JSON.stringify(value));
    setGuestProfile(value);
    companion.update({ period: 'today' });
    navigate(openConcern && companion.state.concern ? 'concern' : 'overview');
  }
  async function addMemory(content: string) {
    const saved = await api<Memory>('/api/memories', {
      method: 'POST',
      body: JSON.stringify({ content }),
    });
    setMemories((prev) => [...prev, saved]);
    setToast(t.memorySaved);
  }
  async function deleteMemory(id: string) {
    await api(`/api/memories/${id}`, { method: 'DELETE' });
    setMemories((prev) => prev.filter((item) => item.id !== id));
    setToast(t.memoryDeleted);
  }
  async function editMemory(id: string, content: string) {
    const saved = await api<Memory>(`/api/memories/${id}`, {
      method: 'PUT',
      body: JSON.stringify({ content }),
    });
    setMemories((prev) => prev.map((item) => (item.id === id ? saved : item)));
    setToast(t.memorySaved);
  }
  async function send(message: string) {
    if (abortRef.current || !record) return;
    const controller = new AbortController();
    abortRef.current = controller;
    setError('');
    setDraft('');
    setChatEvidence(undefined);
    setGenerating(true);
    setMessages((prev) => [
      ...prev,
      {
        id: crypto.randomUUID(),
        role: 'user',
        content: message,
        created: Date.now() / 1000,
        provider,
      },
    ]);
    try {
      if (!(await companion.flush())) throw new Error(t.w_syncError);
      await chat(
        message,
        provider,
        controller.signal,
        (packet) => {
          if (packet.event === 'token') setDraft((prev) => prev + packet.data.text);
          if (packet.event === 'metadata') setChatEvidence(packet.data.evidence);
        },
        (() => {
          const data = contentFor(language);
          const concern = data.concernLibrary.find((c) => c.id === companion.state.concern);
          if (!concern) return '';
          const plan = data.solutionLibrary[concern.id as keyof typeof data.solutionLibrary];
          return (
            concern.question +
            '\n' +
            (plan.options.find((o) => o.id === companion.state.option)?.summary || '')
          );
        })(),
        companion.state.period,
      );
    } catch (err) {
      if (controller.signal.aborted) setToast(t.stopped);
      else setError((err instanceof Error ? err.message : String(err)) + ' ' + t.failed);
    } finally {
      try {
        setMessages(await api<Message[]>('/api/history'));
      } catch (err) {
        setError(err instanceof Error ? err.message : String(err));
      }
      setGenerating(false);
      setDraft('');
      abortRef.current = null;
    }
  }
  async function clearHistory() {
    if (!window.confirm(t.confirmClear)) return;
    try {
      await api('/api/history', { method: 'DELETE' });
      setMessages([]);
      setToast(t.historyCleared);
    } catch (err) {
      setError(err instanceof Error ? err.message : String(err));
    }
  }
  const pageProps = {
    view,
    language,
    t,
    state: companion.state,
    update: companion.update,
    record,
    profile,
    account,
    thai,
    navigate,
    openLanguages,
    ask: (question: string) => {
      setChatPrefill({ text: question, id: Date.now() });
      navigate('chat');
    },
  };
  const chatProps = {
    t,
    messages,
    draft,
    generating,
    hasProfile: !!record,
    providers: config?.providers || [],
    provider,
    expanded: true,
    prefill: chatPrefill,
    draftKey: account?.user_id,
    onPrefillConsumed: () => setChatPrefill(undefined),
    onProvider: setProvider,
    onSend: (message: string) => void send(message),
    onStop: () => abortRef.current?.abort(),
    onClear: () => void clearHistory(),
    onProfile: () => navigate('profile'),
    evidence: chatEvidence,
    memories,
    onRemember: addMemory,
    onMemories: () => navigate('memories'),
    realModelReady: config?.companion?.real_model_ready || false,
  };
  let page;
  switch (view) {
    case 'thai-test':
      page = (
        <ThaiTestPage
          key={account?.user_id || 'guest'}
          profile={profile}
          language={language}
          t={t}
          onBack={() => navigate('mine')}
          onBottomActionChange={setThaiBottomAction}
        />
      );
      break;
    case 'bazi-test':
      page = (
        <BaziTestPage
          key={account?.user_id || 'guest'}
          profile={profile}
          language={language}
          t={t}
          roxyEnabled={config?.roxy?.enabled || false}
          onBack={() => navigate('mine')}
        />
      );
      break;
    case 'overview':
      page = <WanjaiHome {...pageProps} />;
      break;
    case 'example':
      page = <WanjaiChart key="teaching-example" {...pageProps} exampleOnly />;
      break;
    case 'questions':
      page = <WanjaiQuestions {...pageProps} />;
      break;
    case 'concern':
      page = <WanjaiConcern {...pageProps} />;
      break;
    case 'daily':
      page = <WanjaiDaily {...pageProps} />;
      break;
    case 'journey':
      page = <WanjaiJourney {...pageProps} />;
      break;
    case 'solution':
    case 'life':
      page = <WanjaiReports {...pageProps} />;
      break;
    case 'shop':
    case 'favorites':
    case 'orders':
      page = <WanjaiShop key={view} {...pageProps} />;
      break;
    case 'inbox':
      page = <WanjaiInbox {...pageProps} />;
      break;
    case 'mine':
      page = <WanjaiMine key={account?.user_id || 'guest'} {...pageProps} />;
      break;
    case 'share':
      page = <WanjaiShare {...pageProps} />;
      break;
    case 'chart':
      page = (
        <WanjaiChart {...pageProps} showExample={chartExample} onExampleChange={setChartExample}>
          <details
            className="panel p-5"
            open={baziOpen}
            onToggle={(event) => setBaziOpen(event.currentTarget.open)}
          >
            <summary className="mb-4 cursor-pointer text-sm text-muted">{t.w_bazi}</summary>
            <ChartPanel
              record={record}
              t={t}
              onEdit={() => navigate('profile')}
              disabled={generating}
            />
          </details>
        </WanjaiChart>
      );
      break;
    case 'chart-reading':
      page = <ThaiChartReading {...pageProps} />;
      break;
    case 'auth':
      page = config?.account_login ? (
        <AuthPanel
          t={t}
          onAuthenticated={authenticated}
          onBack={() => {
            pendingChat.current = false;
            pendingSituation.current = null;
            setChatPrefill(undefined);
            navigate('overview');
          }}
        />
      ) : (
        <p className="panel p-8">{t.missingProductionAuth}</p>
      );
      break;
    case 'profile':
      page = (
        <ProfileForm
          profile={record?.profile || guestProfile || undefined}
          language={language}
          t={t}
          onSave={saveProfile}
          onBack={() => navigate('mine')}
          onboarding={onboarding}
        />
      );
      break;
    case 'memories':
      page = (
        <>
          <PageIntro title={t.memoryTitle} sub={t.privacyNote} />
          <MemoryPanel
            memories={memories}
            t={t}
            onAdd={addMemory}
            onDelete={deleteMemory}
            onEdit={editMemory}
            onViewAll={() => {}}
          />
        </>
      );
      break;
    case 'explore':
      page = (
        <>
          <PageIntro title={t.w_bazi} sub={t.moduleIntro} />
          <ModuleCatalog
            modules={config?.modules || []}
            t={t}
            onStart={(id) => {
              if (id === 'thai_astrology') navigate('thai-test');
              else if (id === 'bazi') navigate('bazi-test');
              else {
                setChatPrefill({ text: t.w_bazi, id: Date.now() });
                navigate('chat');
              }
            }}
          />
        </>
      );
      break;
    case 'chat':
      page = account ? (
        <ChatPanel
          {...chatProps}
          onTopics={() => navigate('questions')}
          contextTitle={
            contentFor(language).concernLibrary.find((c) => c.id === companion.state.concern)?.label
          }
          contextSummary={
            contentFor(language).concernLibrary.find((c) => c.id === companion.state.concern)
              ?.question
          }
        />
      ) : (
        <GuestChat
          p={pageProps}
          prefill={chatPrefill}
          onContinue={(text) => {
            if (text) setChatPrefill({ text, id: Date.now() });
            pendingChat.current = true;
            pendingSituation.current = {
              concern: companion.state.concern,
              option: companion.state.option,
              topic: companion.state.topic,
              period: companion.state.period,
            };
            navigate('auth');
          }}
        />
      );
      break;
  }
  if (
    !account &&
    !['auth', 'example', 'bazi-test', 'thai-test'].includes(view) &&
    (!guestProfile || view === 'profile')
  ) {
    page = (
      <BirthEntry
        key={guestProfile ? JSON.stringify(guestProfile) : 'new'}
        profile={guestProfile}
        language={language}
        t={t}
        state={companion.state}
        update={companion.update}
        onSave={saveGuestBirth}
        onPreview={() => navigate('example')}
        onCancel={guestProfile ? () => navigate('mine') : undefined}
      />
    );
  }
  return (
    <div className="relative isolate min-h-screen">
      {choosingLanguage && (
        <>
          <Starfield />
          <LanguageChooser
            language={language}
            t={t}
            canCancel={localStorage.getItem(LANGUAGE_CONFIRMED_KEY) === '1'}
            onPreview={changeLanguage}
            onConfirm={confirmLanguage}
            onCancel={() => {
              void changeLanguage(previousLanguage.current);
              setChoosingLanguage(false);
            }}
          />
        </>
      )}
      <div hidden={choosingLanguage}>
        <WanjaiShell
          t={t}
          language={language}
          view={view}
          navigate={navigate}
          onLanguages={openLanguages}
          onLogout={() => void logout()}
          signedIn={!!account}
          disabled={onboarding || loading || !companion.ready}
          busy={generating}
          entry={!account && !profile && !['auth', 'bazi-test', 'thai-test'].includes(view)}
          bottomAction={
            view === 'thai-test'
              ? thaiBottomAction
              : view === 'chart' &&
                  !chartExample &&
                  profile &&
                  !loading &&
                  !connectError &&
                  companion.ready
                ? { label: t.r_all, onClick: () => navigate('chart-reading') }
                : undefined
          }
        >
          {error && (
            <div
              role="alert"
              className="mb-4 flex items-start gap-3 rounded-xl border border-[#d5aba0] bg-[#f5e5de] p-4 text-sm text-accent"
            >
              <CircleHelp size={16} className="mt-1 shrink-0" />
              <p className="flex-1 leading-7">{error}</p>
              <button aria-label={t.dismissError} onClick={() => setError('')}>
                <X size={16} />
              </button>
            </div>
          )}
          {companion.error && (
            <div role="alert" className="jy-card mb-4">
              <p className="jy-copy">{t.w_syncError}</p>
              <button className="jy-outline mt-3" onClick={companion.retry}>
                {t.w_retrySave}
              </button>
            </div>
          )}
          {loading ||
          (!companion.ready && !['auth', 'profile'].includes(view) && !companion.error) ? (
            <div
              role="status"
              className="flex min-h-80 items-center justify-center gap-3 text-sm text-muted"
            >
              <RefreshCw size={18} className="animate-spin" />
              {t.loading}
            </div>
          ) : connectError ? (
            <div
              role="alert"
              className="jy-card flex min-h-80 flex-col items-center justify-center gap-4 text-center"
            >
              <h2>{t.error}</h2>
              <p className="jy-copy">{expired ? t.sessionExpired : connectError}</p>
              <button className="jy-primary" onClick={() => void connect()}>
                {t.retry}
              </button>
            </div>
          ) : (
            (companion.ready || ['auth', 'profile'].includes(view)) && page
          )}
        </WanjaiShell>
        {toast && (
          <div
            role="status"
            className="fixed bottom-24 left-1/2 z-50 flex max-w-[90vw] -translate-x-1/2 items-center gap-2 rounded-xl border border-gold/40 bg-panel px-5 py-3 text-xs leading-6 shadow-lg"
          >
            <Check size={15} className="shrink-0 text-accent" />
            {toast}
          </div>
        )}
      </div>
    </div>
  );
}
