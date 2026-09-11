#!/usr/bin/env node
// Minimal static file server for build/web — no extra dependency beyond
// Node's own http/fs, so the harness doesn't need a second package (e.g.
// `serve`) installed just to host a directory. Falls back to index.html
// for any unknown path so GoRouter's client-side routes resolve on a
// direct navigation or reload, matching normal SPA hosting behaviour.
import http from 'node:http';
import { createReadStream, existsSync, statSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const webRoot = path.resolve(here, '..', '..', '..', 'build', 'web');
const port = Number(process.env.E2E_PORT || 4173);

const MIME = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.mjs': 'text/javascript; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.wasm': 'application/wasm',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.svg': 'image/svg+xml',
  '.ico': 'image/x-icon',
  '.woff2': 'font/woff2',
};

if (!existsSync(webRoot)) {
  console.error(
    `ERROR: ${webRoot} does not exist. Run "npm run e2e:build" (or "npm run test:e2e", which builds first) before serving.`,
  );
  process.exit(1);
}

const server = http.createServer((req, res) => {
  const urlPath = decodeURIComponent((req.url || '/').split('?')[0]);
  let filePath = path.join(webRoot, urlPath);

  if (!filePath.startsWith(webRoot)) {
    res.writeHead(403);
    res.end();
    return;
  }
  if (urlPath === '/' || !existsSync(filePath) || statSync(filePath).isDirectory()) {
    filePath = path.join(webRoot, 'index.html');
  }

  const ext = path.extname(filePath);
  res.writeHead(200, { 'Content-Type': MIME[ext] || 'application/octet-stream' });
  createReadStream(filePath).pipe(res);
});

server.listen(port, '127.0.0.1', () => {
  console.log(`e2e static server listening on http://127.0.0.1:${port}`);
});
