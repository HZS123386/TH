import { spawn, type ChildProcess } from "node:child_process";
import { once } from "node:events";
import { readFile, readdir } from "node:fs/promises";
import { request } from "node:http";
import { createServer } from "node:net";
import { brotliDecompressSync, gunzipSync } from "node:zlib";
import { afterAll, beforeAll, expect, it } from "vitest";

let server: ChildProcess;
let port: number;

beforeAll(async () => {
  const socket = createServer().listen(0, "127.0.0.1");
  await once(socket, "listening");
  port = (socket.address() as { port: number }).port;
  await new Promise<void>(resolve => socket.close(() => resolve()));
  server = spawn(process.execPath, ["scripts/serve-flutter.mjs", "--skip-build"], {
    env: { ...process.env, FATE_H5_PORT: String(port) },
    stdio: ["ignore", "pipe", "pipe"],
    windowsHide: true,
  });
  await new Promise<void>((resolve, reject) => {
    server.once("error", reject);
    server.once("exit", code => reject(new Error(`Preview exited: ${code}`)));
    server.stdout!.on("data", chunk => {
      if (String(chunk).includes("FATE Flutter H5:")) resolve();
    });
  });
});

afterAll(async () => {
  if (!server || server.exitCode !== null) return;
  const exited = once(server, "exit");
  server.kill();
  await exited;
});

function get(path: string, headers: Record<string, string> = {}, method = "GET") {
  return new Promise<{ status: number; headers: Record<string, string | string[] | undefined>; body: Buffer }>((resolve, reject) => {
    const req = request({ host: "127.0.0.1", port, path: "/thai-landing/" + path, headers, method }, res => {
      const chunks: Buffer[] = [];
      res.on("data", chunk => chunks.push(chunk));
      res.on("error", reject);
      res.on("end", () => resolve({ status: res.statusCode!, headers: res.headers, body: Buffer.concat(chunks) }));
    });
    req.on("error", reject);
    req.end();
  });
}

it("compresses the actual Wasm response and preserves versioned engine caching", async () => {
  const revision = (await readdir("site/engine"))[0];
  const path = `engine/${revision}/skwasm.wasm`;
  const response = await get(path, { "Accept-Encoding": "gzip" });
  expect(response.status).toBe(200);
  expect(response.headers["content-encoding"]).toBe("gzip");
  expect(response.headers.vary).toBe("Accept-Encoding");
  expect(Number(response.headers["content-length"])).toBe(response.body.length);
  expect(response.body.equals(await readFile("site/" + path + ".gz"))).toBe(true);
  expect(response.headers["cache-control"]).toContain("immutable");
  expect(gunzipSync(response.body).equals(await readFile("site/" + path))).toBe(true);
});

it("honors gzip rejection, HEAD requests and conditional cache validation", async () => {
  const headers = { "Accept-Encoding": "gzip;q=0, br;q=0, *;q=1" };
  const response = await get("main.dart.wasm", headers);
  expect(response.headers["content-encoding"]).toBeUndefined();
  expect(Number(response.headers["content-length"])).toBe(response.body.length);
  expect(response.body.equals(await readFile("site/main.dart.wasm"))).toBe(true);
  const head = await get("main.dart.wasm", { "Accept-Encoding": "gzip" }, "HEAD");
  expect(head.status).toBe(200);
  expect(head.headers["content-encoding"]).toBe("gzip");
  expect(head.body.length).toBe(0);
  const cached = await get("main.dart.wasm", { "If-None-Match": String(head.headers.etag), "Accept-Encoding": "gzip" });
  expect(cached.status).toBe(304);
  expect(cached.headers.vary).toBe("Accept-Encoding");
  expect(cached.body.length).toBe(0);
});

it("serves exact Brotli files with quality preferences, HEAD and representation-specific caching", async () => {
  const response = await get("main.dart.wasm", { "Accept-Encoding": "gzip, br" });
  expect(response.headers["content-encoding"]).toBe("br");
  expect(response.headers["content-type"]).toBe("application/wasm");
  expect(response.body.equals(await readFile("site/main.dart.wasm.br"))).toBe(true);
  expect(brotliDecompressSync(response.body).equals(await readFile("site/main.dart.wasm"))).toBe(true);
  const head = await get("main.dart.wasm", { "Accept-Encoding": "br" }, "HEAD");
  expect(head.body.length).toBe(0);
  expect(Number(head.headers["content-length"])).toBe(response.body.length);
  const cached = await get("main.dart.wasm", { "Accept-Encoding": "br", "If-None-Match": String(head.headers.etag) });
  expect(cached.status).toBe(304);
  const gzip = await get("main.dart.wasm", { "Accept-Encoding": "gzip;q=1, br;q=0.5", "If-None-Match": String(head.headers.etag) });
  expect(gzip.status).toBe(200);
  expect(gzip.headers["content-encoding"]).toBe("gzip");
  expect(gzip.headers.etag).not.toBe(head.headers.etag);
  const identity = await get("main.dart.wasm", { "Accept-Encoding": "identity;q=1, br;q=0.5" });
  expect(identity.headers["content-encoding"]).toBeUndefined();
  expect(identity.body.equals(await readFile("site/main.dart.wasm"))).toBe(true);
  expect((await get("main.dart.wasm", { "Accept-Encoding": "*;q=0" })).status).toBe(406);
});

it("keeps the video byte-range response uncompressed for mobile playback", async () => {
  const response = await get("media/report-loading-web.mp4", { Range: "bytes=0-127", "Accept-Encoding": "gzip" });
  expect(response.status).toBe(206);
  expect(response.headers["content-encoding"]).toBeUndefined();
  expect(response.headers["content-range"]).toMatch(/^bytes 0-127\//);
  expect(response.body).toEqual((await readFile("site/media/report-loading-web.mp4")).subarray(0, 128));
});

it("serves the landing artwork with the browser image MIME type", async () => {
  const response = await get("assets/assets/images/theme-thai-artwork.jpg", {}, "HEAD");
  expect(response.status).toBe(200);
  expect(response.headers["content-type"]).toBe("image/jpeg");
});
