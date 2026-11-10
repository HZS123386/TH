import { useEffect, useRef, useState } from 'react';
import type { Config, Language } from '../types';
import {
  requestWesternCalculation,
  requestWesternReport,
  type WesternCalculation,
  type WesternProfileRef,
  type WesternReport,
} from './western';

export function useWestern(
  config: Config | null,
  profile: WesternProfileRef | null,
  language: Language,
  owner: string,
) {
  const context = JSON.stringify([owner, profile?.profile_id, profile?.revision, language]);
  const currentContext = useRef(context);
  currentContext.current = context;
  const [state, setState] = useState<{
    context: string;
    result: WesternCalculation | null;
    report: WesternReport | null;
    status: 'idle' | 'loading' | 'unavailable' | 'error';
    reportLoading: boolean;
  }>({ context, result: null, report: null, status: 'idle', reportLoading: false });
  const activeRequest = useRef<AbortController | null>(null);
  const requestKeys = useRef<{ context: string; calculation: string; report?: string } | null>(
    null,
  );
  const supported =
    config?.modules.some(
      (module) => module.id === 'western_astrology' && module.status === 'ready',
    ) ?? false;
  useEffect(() => {
    activeRequest.current?.abort();
    activeRequest.current = null;
    requestKeys.current = null;
    setState({ context, result: null, report: null, status: 'idle', reportLoading: false });
    return () => {
      activeRequest.current?.abort();
    };
  }, [context]);
  // Hide a previous account/revision immediately, before the reset effect runs.
  const visible =
    state.context === context
      ? state
      : { result: null, report: null, status: 'idle' as const, reportLoading: false };
  function keys() {
    if (requestKeys.current?.context !== context)
      requestKeys.current = { context, calculation: crypto.randomUUID() };
    return requestKeys.current;
  }
  async function calculate() {
    if (activeRequest.current) return;
    if (!supported || !profile) {
      setState({
        context,
        result: null,
        report: null,
        status: 'unavailable',
        reportLoading: false,
      });
      return;
    }
    const controller = new AbortController();
    activeRequest.current = controller;
    const timeout = setTimeout(() => controller.abort(), 60_000);
    setState({ context, result: null, report: null, status: 'loading', reportLoading: false });
    try {
      const response = await requestWesternCalculation(
        profile,
        keys().calculation,
        controller.signal,
      );
      if (context !== currentContext.current || controller.signal.aborted) return;
      setState({ context, result: response, report: null, status: 'idle', reportLoading: false });
    } catch {
      if (context === currentContext.current)
        setState({ context, result: null, report: null, status: 'error', reportLoading: false });
    } finally {
      clearTimeout(timeout);
      if (activeRequest.current === controller) activeRequest.current = null;
    }
  }
  async function generateReport() {
    if (activeRequest.current || !supported || !profile || !visible.result) return;
    const controller = new AbortController();
    activeRequest.current = controller;
    const timeout = setTimeout(() => controller.abort(), 60_000);
    const stableKeys = keys();
    stableKeys.report ||= crypto.randomUUID();
    setState((previous) => ({ ...previous, reportLoading: true }));
    try {
      const response = await requestWesternReport(
        visible.result,
        profile,
        language,
        stableKeys.report,
        controller.signal,
      );
      if (context === currentContext.current && !controller.signal.aborted)
        setState((previous) => ({ ...previous, report: response }));
    } catch {
      if (context === currentContext.current)
        setState((previous) => ({ ...previous, status: 'error' }));
    } finally {
      clearTimeout(timeout);
      if (context === currentContext.current)
        setState((previous) => ({ ...previous, reportLoading: false }));
      if (activeRequest.current === controller) activeRequest.current = null;
    }
  }
  return { ...visible, supported, calculate, generateReport };
}
