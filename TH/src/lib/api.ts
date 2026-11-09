import type { StreamEvent } from '../types';
import { i18n } from './i18n';

const SESSION_KEY = 'sabai.session';
export const session = {
  get: () => localStorage.getItem(SESSION_KEY),
  set: (token: string) => localStorage.setItem(SESSION_KEY, token),
  clear: () => localStorage.removeItem(SESSION_KEY),
};
export class ApiError extends Error {
  constructor(
    message: string,
    public status: number,
  ) {
    super(message);
  }
}
async function errorFor(response: Response) {
  const body = await response.json().catch(() => ({}));
  const message =
    typeof body.detail === 'string'
      ? body.detail
      : Array.isArray(body.detail)
        ? body.detail.map((item: { msg: string }) => item.msg).join('；')
        : i18n.t('requestFailed');
  return new ApiError(message, response.status);
}
export async function api<T>(path: string, init: RequestInit = {}): Promise<T> {
  const token = session.get();
  const response = await localizedFetch(path, {
    ...init,
    headers: {
      'Content-Type': 'application/json',
      'Accept-Language': i18n.language,
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
      ...init.headers,
    },
  });
  if (!response.ok) throw await errorFor(response);
  return response.status === 204 ? (undefined as T) : response.json();
}

async function localizedFetch(path: string, init: RequestInit) {
  try {
    return await fetch(path, init);
  } catch (error) {
    if (init.signal?.aborted) throw error;
    throw new Error(i18n.t('networkError'));
  }
}

export async function consumeSSE(
  stream: ReadableStream<Uint8Array>,
  onEvent: (event: StreamEvent) => void,
) {
  const reader = stream.getReader();
  const decoder = new TextDecoder();
  let buffer = '',
    finished = false;
  const consume = () => {
    buffer = buffer.replace(/\r\n/g, '\n');
    let boundary: number;
    while ((boundary = buffer.indexOf('\n\n')) >= 0) {
      const frame = buffer.slice(0, boundary);
      buffer = buffer.slice(boundary + 2);
      const lines = frame.split('\n');
      const event = lines
        .find((line) => line.startsWith('event:'))
        ?.slice(6)
        .trim();
      const data = lines
        .filter((line) => line.startsWith('data:'))
        .map((line) => line.slice(5).trimStart())
        .join('\n');
      if (!event || !data) continue;
      if (!['metadata', 'token', 'done', 'error'].includes(event)) continue;
      let parsed;
      try {
        parsed = JSON.parse(data);
      } catch {
        throw new Error(i18n.t('streamInvalid'));
      }
      if (event === 'error') throw new Error(parsed.message || i18n.t('requestFailed'));
      if (event === 'token' && typeof parsed.text !== 'string')
        throw new Error(i18n.t('streamInvalid'));
      onEvent({ event, data: parsed } as StreamEvent);
      if (event === 'done') finished = true;
    }
  };
  try {
    while (true) {
      const chunk = await reader.read();
      if (chunk.done) break;
      buffer += decoder.decode(chunk.value, { stream: true });
      consume();
    }
    buffer += decoder.decode();
    consume();
    if (!finished) throw new Error(i18n.t('streamInterrupted'));
  } finally {
    await reader.cancel().catch(() => {});
    reader.releaseLock();
  }
}

export async function chat(
  message: string,
  provider: string,
  signal: AbortSignal,
  onEvent: (event: StreamEvent) => void,
  context = '',
  period?: 'today' | 'week' | 'month',
) {
  const response = await localizedFetch('/api/chat', {
    method: 'POST',
    signal,
    headers: {
      'Content-Type': 'application/json',
      'Accept-Language': i18n.language,
      Authorization: `Bearer ${session.get() ?? ''}`,
    },
    body: JSON.stringify({ message, provider, context, period }),
  });
  if (!response.ok) throw await errorFor(response);
  if (!response.body) throw new Error(i18n.t('streamUnavailable'));
  await consumeSSE(response.body, onEvent);
}
