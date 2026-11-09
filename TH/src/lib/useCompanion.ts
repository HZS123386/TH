import { useEffect, useRef, useState } from 'react';
import { api, session } from './api';
import { cleanCompanion, defaultCompanion, type CompanionState } from './wanjai';

const GUEST_KEY = 'wanjai.guest';
export function useCompanion(userId: string | undefined) {
  const [snapshot, setSnapshot] = useState<{ owner: string | undefined; state: CompanionState }>({
    owner: undefined,
    state: defaultCompanion,
  });
  const [ready, setReady] = useState(false);
  const [error, setError] = useState(false);
  const [attempt, setAttempt] = useState(0);
  const queue = useRef<Promise<unknown>>(Promise.resolve());
  const scope = useRef(0);
  const failed = useRef(false);
  const current = useRef(defaultCompanion);
  const save = useRef<(next: CompanionState) => void>(() => {});
  useEffect(() => {
    const generation = ++scope.current;
    const token = session.get();
    let active = true;
    setReady(false);
    setError(false);
    failed.current = false;
    queue.current = Promise.resolve();
    save.current = (next) => {
      if (!active) return;
      if (!userId) {
        try {
          localStorage.setItem(GUEST_KEY, JSON.stringify(next));
          failed.current = false;
          setError(false);
        } catch {
          failed.current = true;
          setError(true);
        }
        return;
      }
      // Capture the original session: a queued write must never use another login.
      queue.current = queue.current
        .catch(() => {})
        .then(async () => {
          if (!active) return;
          await api('/api/companion', {
            method: 'PUT',
            headers: { Authorization: `Bearer ${token}` },
            body: JSON.stringify(next),
          });
          if (active && scope.current === generation) {
            failed.current = false;
            setError(false);
          }
        })
        .catch(() => {
          if (active) {
            failed.current = true;
            setError(true);
          }
        });
    };
    async function load() {
      try {
        let raw: unknown = null;
        if (userId) raw = await api('/api/companion');
        else {
          try {
            raw = JSON.parse(localStorage.getItem(GUEST_KEY) || 'null');
          } catch {
            raw = null;
          }
        }
        if (!active) return;
        current.current = cleanCompanion(raw);
        setSnapshot({ owner: userId, state: current.current });
        setReady(true);
      } catch {
        if (active) setError(true);
      }
    }
    void load();
    return () => {
      active = false;
    };
  }, [userId, attempt]);
  const state = snapshot.owner === userId ? snapshot.state : defaultCompanion;
  function update(patch: Partial<CompanionState>) {
    if (!ready || snapshot.owner !== userId) return;
    const next = cleanCompanion({ ...current.current, ...patch });
    current.current = next;
    setSnapshot({ owner: userId, state: next });
    save.current(next);
  }
  return {
    state,
    update,
    ready: ready && snapshot.owner === userId,
    error,
    flush: async () => {
      await queue.current;
      return !failed.current;
    },
    retry: () => (ready ? save.current(current.current) : setAttempt((n) => n + 1)),
  };
}
