import { usePageRoute, type AppView } from './lib/routes';
import { WanjaiShell } from './components/WanjaiShell';
import { useCallback, useEffect, useRef, useState } from 'react';
import { Check, CircleHelp, RefreshCw, X } from 'lucide-react';
import { api, ApiError, session } from './lib/api';
import { changeLanguage, useLocale } from './lib/i18n';
import { LANGUAGE_KEY, LANGUAGE_CONFIRMED_KEY, normalizeLanguage } from './lib/languages';
import type { Config, Account, Profile, ProfileRecord } from './types';
import { GUEST_BIRTH_KEY, readGuestBirth } from './lib/guestBirth';
import { clearWesternBirth, readWesternBirth, saveWesternBirth, westernCopy, westernExample } from './lib/western';
import { useWestern } from './lib/useWestern';
import { WesternHome } from './components/WesternHome';
import { WesternChart } from './components/WesternChart';
import { WesternBirthForm } from './components/WesternBirthForm';
import { WesternReports, WesternPurchaseDialog, WesternPurchases } from './components/WesternReports';
import { WesternProfile } from './components/WesternProfile';
import { Starfield } from './components/Starfield';
import { AuthPanel } from './components/AuthPanel';
import { LanguageChooser } from './components/LanguageChooser';

export default function App() {
  const { language, t } = useLocale();
  const [choosingLanguage, setChoosingLanguage] = useState(
    () =>
      localStorage.getItem(LANGUAGE_CONFIRMED_KEY) !== '1' ||
      !normalizeLanguage(localStorage.getItem(LANGUAGE_KEY)),
  );
  const previousLanguage = useRef(language);
  const [view, setView] = usePageRoute();
  const [account, setAccount] = useState<Account | null>(null);
  const [record, setRecord] = useState<ProfileRecord | null>(null);
  const [config, setConfig] = useState<Config | null>(null);
  const [loading, setLoading] = useState(true);
  const [connectError, setConnectError] = useState('');
  const [expired, setExpired] = useState(false);
  const [error, setError] = useState('');
  const [toast, setToast] = useState('');
  const [example, setExample] = useState(() => new URLSearchParams(location.search).get('example') === '1');
  const [purchase, setPurchase] = useState<{ example: boolean; preview: () => void } | null>(null);
  const [largeText, setLargeText] = useState(() => localStorage.getItem('fate.largeText') === '1');
  const owner = account?.user_id || 'guest';
  const [birth, setBirth] = useState<{ owner: string; value: Profile | null }>(() => ({
    owner: 'guest', value: readWesternBirth('guest') || readGuestBirth(),
  }));
  const profile = birth.owner === owner ? birth.value : null;
  const a = westernCopy(language);
  const profileMatches = !!profile && !!record && ['birth_date', 'birth_time', 'timezone', 'birthplace', 'location_id', 'latitude', 'longitude'].every(
    (key) => (profile[key as keyof Profile] ?? null) === (record.profile[key as keyof Profile] ?? null),
  );
  const profileRef = account && record?.profile_id && profileMatches
    ? { profile_id: record.profile_id, revision: record.revision } : null;
  const western = useWestern(config, profileRef, language, owner);
  const booting = useRef(false);
  const previousOwner = useRef(owner);
  useEffect(() => {
    setBirth({ owner, value: readWesternBirth(owner) || (owner === 'guest' ? readGuestBirth() : null) });
    if (previousOwner.current !== owner) {
      setExample(false); setPurchase(null);
      history.replaceState(null, '', location.pathname);
    }
    previousOwner.current = owner;
  }, [owner]);
  useEffect(() => {
    const syncExample = () => {
      setExample(new URLSearchParams(location.search).get('example') === '1');
      setPurchase(null);
    };
    window.addEventListener('popstate', syncExample);
    return () => window.removeEventListener('popstate', syncExample);
  }, []);
  useEffect(() => {
    document.documentElement.style.fontSize = largeText ? '18px' : '16px';
    return () => { document.documentElement.style.fontSize = ''; };
  }, [largeText]);
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
    const saved = await api<ProfileRecord | null>('/api/profile');
    setRecord(saved);
    setAccount(identity);
    setView((previous) => previous === 'auth' ? 'mine' : previous);
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
  }, []);
  useEffect(() => {
    if (toast) {
      const timer = setTimeout(() => setToast(''), 3500);
      return () => clearTimeout(timer);
    }
  }, [toast]);

  useEffect(() => {
    document.querySelector('meta[name="theme-color"]')?.setAttribute('content', '#130c24');
  }, []);
  function navigate(next: AppView) {
    setExample(false); setPurchase(null); setError('');
    setView(next);
    history.replaceState(null, '', location.pathname);
  }
  function openExample(next: 'chart' | 'report') {
    setView(next); setExample(true); setError('');
    history.replaceState(null, '', `${location.pathname}?example=1`);
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
    try {
      await api('/api/auth/logout', { method: 'POST' });
    } catch (err) {
      if (!(err instanceof ApiError && err.status === 401)) {
        setError(err instanceof Error ? err.message : String(err));
        return;
      }
    }
    session.clear(); setAccount(null); setRecord(null); setToast('');
    navigate('overview');
  }
  async function saveProfile(value: Profile) {
    saveWesternBirth(owner, value);
    setBirth({ owner, value });
    setToast(a.saved);
    navigate('chart');
  }
  function clearBirth() {
    if (!window.confirm(a.clearConfirm)) return;
    clearWesternBirth(owner);
    if (!account) localStorage.removeItem(GUEST_BIRTH_KEY);
    setBirth({ owner, value: null }); setToast(a.cleared);
  }
  function generateReport() {
    if (!profile) { navigate('profile'); return; }
    if (!western.result) { navigate('chart'); void western.calculate(); return; }
    navigate('report');
    if (!western.report) void western.generateReport();
  }
  let page;
  switch (view) {
    case 'overview':
      page = <WesternHome language={language} profile={profile} onBirth={() => navigate('profile')}
        onChart={() => navigate('chart')} onReports={() => navigate('reports')}
        onPurchase={() => setPurchase({ example: false, preview: () => {} })} />;
      break;
    case 'chart':
      page = <WesternChart result={example ? westernExample : western.result} example={example}
        profile={profile} status={western.status} language={language} t={t}
        onBirth={() => navigate('profile')} onExample={() => openExample('chart')}
        onRetry={() => void western.calculate()} onReport={() => example ? openExample('report') : generateReport()} />;
      break;
    case 'reports':
    case 'report':
      page = <WesternReports key={`${owner}:${language}`} language={language} t={t} owner={owner}
        detail={view === 'report'} example={example} report={western.report} loading={western.reportLoading}
        onGenerate={generateReport} onExample={() => openExample('report')} onBack={() => navigate('reports')}
        onPurchase={(preview, sample) => setPurchase({ example: sample, preview })} />;
      break;
    case 'mine':
      page = <WesternProfile language={language} t={t} account={account} profile={profile} largeText={largeText}
        onBirth={() => navigate('profile')} onReports={() => navigate('reports')} onPurchases={() => navigate('orders')}
        onLanguages={openLanguages} onLargeText={(value) => { setLargeText(value); localStorage.setItem('fate.largeText', value ? '1' : '0'); }}
        onLogin={() => navigate('auth')} onLogout={() => void logout()} onClear={clearBirth} />;
      break;
    case 'profile':
      page = <WesternBirthForm key={owner} profile={profile || record?.profile || null} language={language} t={t}
        onSave={saveProfile} onBack={() => navigate('mine')} />;
      break;
    case 'auth':
      page = config?.account_login
        ? <AuthPanel t={t} onAuthenticated={authenticated} onBack={() => navigate('mine')} />
        : <section className="jy-card"><p className="text-sm leading-7">{loading ? t.loading : t.missingProductionAuth}</p>
            <button onClick={() => void connect()} className="jy-outline mt-4">{a.retry}</button></section>;
      break;
    case 'orders':
      page = <WesternPurchases language={language} onRestore={() => setPurchase({ example: false, preview: () => {} })} />;
      break;
  }
  return (
    <div className="relative isolate min-h-screen">
      {choosingLanguage && <><Starfield /><LanguageChooser language={language} t={t}
        canCancel={localStorage.getItem(LANGUAGE_CONFIRMED_KEY) === '1'} onPreview={changeLanguage}
        onConfirm={confirmLanguage} onCancel={() => { void changeLanguage(previousLanguage.current); setChoosingLanguage(false); }} /></>}
      <div hidden={choosingLanguage}>
        <WanjaiShell t={t} language={language} view={view} navigate={navigate} onLanguages={openLanguages}
          onLogout={() => void logout()} signedIn={!!account} disabled={false} busy={loading} entry={false}>
          {error && <div role="alert" className="mb-4 flex items-start gap-3 rounded-xl border border-rose-400/30 bg-surface p-4 text-xs">
            <CircleHelp size={16} className="mt-1 shrink-0 text-gold" /><p className="flex-1 leading-6">{error}</p>
            <button aria-label={t.dismissError} onClick={() => setError('')}><X size={16} /></button>
          </div>}
          {connectError && <div role="status" className="mb-4 flex items-center gap-3 rounded-xl border border-line bg-panel/80 p-3 text-[11px] leading-6 text-muted">
            <p className="flex-1">{expired ? t.sessionExpired : a.connection}</p>
            <button aria-label={a.retry} onClick={() => void connect()} className="jy-icon"><RefreshCw size={16} /></button>
          </div>}
          {page}
        </WanjaiShell>
        {purchase && <WesternPurchaseDialog language={language} t={t} example={purchase.example}
          onCancel={() => setPurchase(null)} onPreview={() => { purchase.preview(); setPurchase(null); }} />}
        {toast && <div role="status" className="fixed bottom-24 left-1/2 z-50 flex max-w-[90vw] -translate-x-1/2 items-center gap-2 rounded-xl border border-gold/40 bg-panel px-5 py-3 text-xs leading-6 shadow-lg"><Check size={15} className="shrink-0 text-gold" />{toast}</div>}
      </div>
    </div>
  );
}
