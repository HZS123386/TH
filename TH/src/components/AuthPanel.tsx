import { useEffect, useState, type FormEvent } from 'react';
import { ArrowLeft, ArrowRight, LockKeyhole } from 'lucide-react';
import { api } from '../lib/api';
import type { Copy } from '../lib/i18n';
import { BrandMark } from './BrandMark';

export function AuthPanel({
  t,
  onAuthenticated,
  onBack,
}: {
  t: Copy;
  onAuthenticated: (token: string) => Promise<void>;
  onBack: () => void;
}) {
  const [mode, setMode] = useState<'login' | 'register'>('login');
  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');
  const [confirmation, setConfirmation] = useState('');
  const [pending, setPending] = useState(false);
  const [error, setError] = useState('');
  useEffect(() => setError(''), [t]);
  async function submit(event: FormEvent) {
    event.preventDefault();
    setError('');
    if (mode === 'register' && password !== confirmation) {
      setError(t.passwordMismatch);
      return;
    }
    setPending(true);
    try {
      const auth = await api<{ token: string }>(`/api/auth/${mode}`, {
        method: 'POST',
        body: JSON.stringify({ username: username.trim(), password }),
      });
      await onAuthenticated(auth.token);
    } catch (err) {
      setError(err instanceof Error ? err.message : String(err));
    } finally {
      setPending(false);
    }
  }
  return (
    <section className="panel enter mx-auto max-w-lg p-6 sm:p-9">
      <BrandMark className="mb-6 h-12 w-12 text-accent" />
      <h2 className="text-xl font-semibold leading-relaxed">
        {mode === 'register' ? t.registerTitle : t.loginTitle}
      </h2>
      <p className="mb-7 mt-3 text-sm leading-7 text-muted">{t.loginSub}</p>
      <form
        onSubmit={submit}
        className="space-y-5"
        onInvalidCapture={(event) => {
          event.preventDefault();
          setError(t.formInvalid);
          event.currentTarget.querySelector<HTMLElement>('input:invalid')?.focus();
        }}
      >
        <fieldset disabled={pending} className="space-y-5">
          <div>
            <label htmlFor="account-username" className="label">
              {t.username}
            </label>
            <input
              id="account-username"
              className="field"
              autoComplete="username"
              autoCapitalize="none"
              spellCheck={false}
              minLength={3}
              maxLength={32}
              pattern="[A-Za-z0-9_]+"
              placeholder="sabai_nok"
              required
              value={username}
              onChange={(e) => setUsername(e.target.value)}
            />
            <p className="mt-2 text-[11px] text-muted">{t.usernameHint}</p>
          </div>
          <div>
            <label htmlFor="account-password" className="label">
              {t.password}
            </label>
            <input
              id="account-password"
              type="password"
              className="field"
              autoComplete={mode === 'register' ? 'new-password' : 'current-password'}
              required
              minLength={8}
              maxLength={128}
              value={password}
              onChange={(e) => setPassword(e.target.value)}
            />
            <p className="mt-2 text-[11px] text-muted">{t.passwordHint}</p>
          </div>
          {mode === 'register' && (
            <div>
              <label htmlFor="account-confirmation" className="label">
                {t.confirmPassword}
              </label>
              <input
                id="account-confirmation"
                className="field"
                type="password"
                autoComplete="new-password"
                required
                minLength={8}
                maxLength={128}
                value={confirmation}
                onChange={(e) => setConfirmation(e.target.value)}
              />
            </div>
          )}
        </fieldset>
        {error && (
          <p role="alert" className="text-sm leading-6 text-rose-300">
            {error}
          </p>
        )}
        <button className="btn-primary w-full" disabled={pending}>
          <LockKeyhole size={15} />
          {pending ? t.saving : mode === 'register' ? t.register : t.login}
          <ArrowRight size={15} className="ml-auto" />
        </button>
      </form>
      <button
        className="btn-quiet mt-4 w-full !text-xs"
        disabled={pending}
        onClick={() => {
          setMode((prev) => (prev === 'login' ? 'register' : 'login'));
          setError('');
          setPassword('');
          setConfirmation('');
        }}
      >
        {mode === 'register' ? t.haveAccount : t.newAccount}
      </button>
      <button className="btn-quiet mt-5 !text-xs" disabled={pending} onClick={onBack}>
        <ArrowLeft size={14} />
        {t.cancel}
      </button>
    </section>
  );
}
