#!/usr/bin/env node
/**
 * NexDrive app server for GoDaddy Node.js Hosting.
 *
 * Serves the installable PWA in public/ at the document root. The app runs
 * fully client-side in demo mode (in-memory sample data) — no backend or DB.
 *
 *   /            NexDrive app (installable PWA)
 *   /sw.js       service worker (served at root scope, no-cache)
 *   /manifest.webmanifest
 */
const express = require('express');
const path = require('path');
const fs = require('fs');

const PORT = process.env.PORT || 3000;
const HOST = process.env.HOST || '0.0.0.0';
const PUBLIC = path.join(__dirname, 'public');

if (!fs.existsSync(path.join(PUBLIC, 'index.html'))) {
  console.error('public/index.html not found — run `npm run build` first.');
  process.exit(1);
}

const app = express();
app.disable('x-powered-by');

app.use(
  express.static(PUBLIC, {
    index: 'index.html',
    etag: true,
    setHeaders(res, filePath) {
      const base = path.basename(filePath);
      const ext = path.extname(filePath).toLowerCase();

      if (ext === '.webmanifest') {
        res.setHeader('Content-Type', 'application/manifest+json; charset=utf-8');
      }
      // The service worker must not be cached by the browser and must be
      // allowed to control the whole origin.
      if (base === 'sw.js' || base === 'sw-precache.js') {
        res.setHeader('Content-Type', 'text/javascript; charset=utf-8');
        res.setHeader('Cache-Control', 'no-cache, no-store, must-revalidate');
        res.setHeader('Service-Worker-Allowed', '/');
      }
    },
  })
);

// SPA fallback: serve the app shell for html navigations that aren't files.
app.get('*', (req, res, next) => {
  if (req.method !== 'GET') return next();
  if (!req.headers.accept || !req.headers.accept.includes('text/html')) return next();
  res.sendFile(path.join(PUBLIC, 'index.html'));
});

app.use((req, res) => {
  res.status(404).type('text/plain').send('404 Not Found: ' + req.path);
});

app.listen(PORT, HOST, () => {
  const shown = HOST === '0.0.0.0' ? 'localhost' : HOST;
  console.log(`NexDrive running at http://${shown}:${PORT}`);
  console.log(`  app       http://${shown}:${PORT}/`);
  console.log(`  manifest  http://${shown}:${PORT}/manifest.webmanifest`);
  console.log(`  sw        http://${shown}:${PORT}/sw.js`);
});
