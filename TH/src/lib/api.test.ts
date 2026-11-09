import { beforeEach, describe, expect, it } from 'vitest';
import { changeLanguage } from './i18n';
import { consumeSSE } from './api';
import type { StreamEvent } from '../types';

function streamFrom(text: string, chunkSize = 1) {
  const bytes = new TextEncoder().encode(text);
  return new ReadableStream<Uint8Array>({
    start(controller) {
      for (let i = 0; i < bytes.length; i += chunkSize)
        controller.enqueue(bytes.slice(i, i + chunkSize));
      controller.close();
    },
  });
}
describe('SSE conversation protocol', () => {
  beforeEach(() => changeLanguage('zh'));
  it('keeps split UTF-8 characters, CRLF and split event boundaries intact', async () => {
    const events: StreamEvent[] = [];
    await consumeSSE(
      streamFrom(
        'event: token\r\ndata: {"text":"你好 สวัสดี"}\r\n\r\nevent: done\r\ndata: {"message_id":"1","provider":"mock"}\r\n\r\n',
      ),
      (packet) => events.push(packet),
    );
    expect(events).toEqual([
      { event: 'token', data: { text: '你好 สวัสดี' } },
      { event: 'done', data: { message_id: '1', provider: 'mock' } },
    ]);
  });
  it('surfaces server errors instead of treating partial output as success', async () => {
    await expect(
      consumeSSE(
        streamFrom('event: error\ndata: {"message":"上游中断","saved":false}\n\n'),
        () => {},
      ),
    ).rejects.toThrow('上游中断');
  });
  it('rejects a stream that ends before done', async () => {
    await expect(
      consumeSSE(streamFrom('event: token\ndata: {"text":"半条"}\n\n'), () => {}),
    ).rejects.toThrow('连接已中断');
  });
  it('ignores comments and unknown event types', async () => {
    const events: StreamEvent[] = [];
    await consumeSSE(
      streamFrom(
        ': keepalive\n\nevent: future\ndata: {}\n\nevent: done\ndata: {"message_id":"2","provider":"mock"}\n\n',
      ),
      (packet) => events.push(packet),
    );
    expect(events).toHaveLength(1);
  });
});
