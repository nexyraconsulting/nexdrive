/* NexDrive service worker — makes the app installable and usable offline.
 *
 * Strategy:
 *   - Precache the app shell + core assets on install (CORE below, plus a
 *     build-generated full list from sw-precache.js when present).
 *   - Navigations: network-first, falling back to the cached app shell, then
 *     to offline.html when nothing is cached yet.
 *   - Other same-origin GETs: stale-while-revalidate (instant from cache,
 *     refreshed in the background) so every visited screen works offline.
 *
 * Bump CACHE_VERSION to force clients to refetch the shell after a deploy.
 */
'use strict';

const CACHE_VERSION = 'nexdrive-v1';
const SHELL_URL = '/index.html';
const OFFLINE_URL = '/offline.html';

// App shell + the assets needed for a first offline launch.
const CORE = [
  '/',
  '/index.html',
  '/offline.html',
  '/manifest.webmanifest',
  '/css/nexdrive-base.css',
  '/js/config.js',
  '/js/nexdrive-runtime.js',
  '/js/product.js',
  '/js/vendor/react.production.min.js',
  '/js/vendor/react-dom.production.min.js',
  '/js/vendor/qrcode-generator.js',
  '/assets/logos/app-icon.svg',
  '/assets/logos/app-icon-180.png',
  '/assets/logos/app-icon-192.png',
  '/assets/logos/app-icon-512.png',
  '/assets/fonts/hanken-grotesk-latin.woff2',
  '/assets/fonts/hanken-grotesk-latin-ext.woff2',
];

// Optional fuller precache list written by build.js (scans public/).
// Absent in a raw checkout — the try/catch keeps install working regardless.
let PRECACHE = CORE.slice();
try {
  importScripts('/sw-precache.js');
  if (self.__PRECACHE_URLS && Array.isArray(self.__PRECACHE_URLS)) {
    PRECACHE = Array.from(new Set(CORE.concat(self.__PRECACHE_URLS)));
  }
} catch (e) {
  /* no generated list — CORE is enough to launch offline */
}

self.addEventListener('install', (event) => {
  event.waitUntil(
    (async () => {
      const cache = await caches.open(CACHE_VERSION);
      // addAll fails the whole install if any URL 404s; add individually so a
      // single missing asset never blocks the install.
      await Promise.all(
        PRECACHE.map((url) =>
          cache.add(new Request(url, { cache: 'reload' })).catch(() => {})
        )
      );
      await self.skipWaiting();
    })()
  );
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    (async () => {
      const keys = await caches.keys();
      await Promise.all(
        keys.filter((k) => k !== CACHE_VERSION).map((k) => caches.delete(k))
      );
      await self.clients.claim();
    })()
  );
});

self.addEventListener('message', (event) => {
  if (event.data === 'SKIP_WAITING') self.skipWaiting();
});

self.addEventListener('fetch', (event) => {
  const req = event.request;
  if (req.method !== 'GET') return;

  const url = new URL(req.url);
  if (url.origin !== self.location.origin) return; // let cross-origin pass through

  // Navigations → network-first, fall back to the cached shell, then offline.
  if (req.mode === 'navigate') {
    event.respondWith(
      (async () => {
        try {
          const fresh = await fetch(req);
          const cache = await caches.open(CACHE_VERSION);
          cache.put(SHELL_URL, fresh.clone());
          return fresh;
        } catch (e) {
          const cache = await caches.open(CACHE_VERSION);
          return (
            (await cache.match(SHELL_URL)) ||
            (await cache.match(OFFLINE_URL)) ||
            new Response('Offline', { status: 503, statusText: 'Offline' })
          );
        }
      })()
    );
    return;
  }

  // Other same-origin GETs → stale-while-revalidate.
  event.respondWith(
    (async () => {
      const cache = await caches.open(CACHE_VERSION);
      const cached = await cache.match(req);
      const network = fetch(req)
        .then((res) => {
          if (res && res.status === 200 && res.type === 'basic') {
            cache.put(req, res.clone());
          }
          return res;
        })
        .catch(() => null);
      return cached || (await network) ||
        new Response('', { status: 504, statusText: 'Offline' });
    })()
  );
});
