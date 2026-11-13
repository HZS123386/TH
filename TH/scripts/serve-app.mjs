import { createServer, request as httpRequest } from 'node:http';
import { request as httpsRequest } from 'node:https';
import { createReadStream, existsSync } from 'node:fs';
import { stat } from 'node:fs/promises';
import path from 'node:path';
import { appRoot, buildAppPreview } from './flutter-app.mjs';

const port = Number(process.env.FATE_APP_PORT || '5174');
if (!Number.isInteger(port) || port < 1 || port > 65535) throw new Error('Invalid FATE_APP_PORT');
const backend = new URL(process.env.FATE_API_UPSTREAM || 'http://127.0.0.1:8000');
if (!['http:', 'https:'].includes(backend.protocol)) throw new Error('Invalid API upstream');
if (!process.argv.includes('--skip-build')) {
  await buildAppPreview();
}
const webRoot = path.resolve(appRoot, 'build', 'web');
if (!existsSync(path.join(webRoot, 'index.html'))) throw new Error('Run pnpm build:app:preview first');
const mime = { '.html': 'text/html; charset=utf-8', '.js': 'text/javascript', '.mjs': 'text/javascript', '.css': 'text/css', '.json': 'application/json', '.wasm': 'application/wasm', '.png': 'image/png', '.svg': 'image/svg+xml', '.webp': 'image/webp', '.mp4': 'video/mp4', '.ttf': 'font/ttf', '.otf': 'font/otf', '.woff2': 'font/woff2' };

const server = createServer(async (req, res) => {
  let url;
  try { url = new URL(req.url, 'http://localhost'); } catch { res.writeHead(400).end(); return; }
  if (url.pathname.startsWith('/api/') || url.pathname === '/health') {
    const target = new URL(url.pathname + url.search, backend);
    const send = target.protocol === 'https:' ? httpsRequest : httpRequest;
    const upstream = send(target, { method: req.method, headers: { ...req.headers, host: target.host } }, (response) => {
      res.writeHead(response.statusCode || 502, response.headers); response.pipe(res);
    });
    upstream.on('error', () => {
      if (res.headersSent) { res.destroy(); return; }
      res.writeHead(503, { 'Content-Type': 'application/json' }).end(JSON.stringify({ error: { code: 'backend_unavailable', retryable: true } }));
    });
    req.on('aborted', () => upstream.destroy()); req.pipe(upstream); return;
  }
  if (!['GET', 'HEAD'].includes(req.method)) { res.writeHead(405).end(); return; }
  let file;
  try { file = path.resolve(webRoot, '.' + decodeURIComponent(url.pathname)); }
  catch { res.writeHead(400).end(); return; }
  if (file !== webRoot && !file.startsWith(webRoot + path.sep)) { res.writeHead(403).end(); return; }
  try {
    if ((await stat(file)).isDirectory()) file = path.join(file, 'index.html');
    const info = await stat(file);
    const etag = `W/"${info.size.toString(16)}-${info.mtimeMs.toString(16)}"`;
    const headers = {
      'Content-Type': mime[path.extname(file)] || 'application/octet-stream',
      'Cache-Control': 'no-cache',
      ETag: etag,
      // The local Wasm preview uses the same-origin assets needed for Skwasm workers.
      'Cross-Origin-Opener-Policy': 'same-origin',
      'Cross-Origin-Embedder-Policy': 'require-corp',
    };
    // Revalidate unversioned assets so refreshes reuse bytes and rebuilds stay current.
    if (req.headers['if-none-match']?.split(',').some((tag) => tag.trim() === etag || tag.trim() === '*')) {
      res.writeHead(304, headers).end(); return;
    }
    res.writeHead(200, { ...headers, 'Content-Length': info.size });
    if (req.method === 'HEAD') res.end(); else createReadStream(file).pipe(res);
  } catch { res.writeHead(404).end(); }
});
server.listen(port, '127.0.0.1', () => console.log(`FATE Flutter APP: http://127.0.0.1:${port}`));
process.on('SIGTERM', () => server.close());
process.on('SIGINT', () => server.close());
