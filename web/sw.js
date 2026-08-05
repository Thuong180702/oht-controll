// Service Worker for OHT Control System (Offline-First + Auto Background Update)
// Strategy: Network-First for entrypoints (auto-update on internet), Cache-First for static assets, Bypass WS/APIs.

const CACHE_PREFIX = 'oht-pwa-cache-';
const CURRENT_CACHE_VERSION = 'v1.0.1';
const CACHE_NAME = `${CACHE_PREFIX}${CURRENT_CACHE_VERSION}`;

// Core entrypoint resources that must always be checked on network when internet is available
const ENTRYPOINTS = [
  './',
  './index.html',
  './flutter_bootstrap.js',
  './main.dart.js',
  './manifest.json',
];

// Static assets cached for fast boot
const STATIC_ASSETS = [
  './loading.css',
  './favicon.png',
  './icons/Icon-192.png',
  './icons/Icon-512.png',
  './assets/FontManifest.json',
  './assets/fonts/MaterialIcons-Regular.otf',
  './assets/packages/cupertino_icons/assets/CupertinoIcons.ttf',
];

// ─── INSTALL ─────────────────────────────────────────────────────────────────
self.addEventListener('install', (event) => {
  console.log('[SW] Installing new Service Worker version:', CURRENT_CACHE_VERSION);
  self.skipWaiting();
  event.waitUntil(
    caches.open(CACHE_NAME).then((cache) => {
      const allAssets = [...ENTRYPOINTS, ...STATIC_ASSETS];
      return Promise.all(
        allAssets.map((url) =>
          fetch(url, { cache: 'no-cache' })
            .then((response) => {
              if (response && response.ok) {
                return cache.put(url, response);
              }
            })
            .catch((err) => console.warn('[SW] Pre-cache fallback for:', url, err))
        )
      );
    })
  );
});

// ─── ACTIVATE ────────────────────────────────────────────────────────────────
self.addEventListener('activate', (event) => {
  console.log('[SW] Activating Service Worker & purging old caches...');
  event.waitUntil(
    caches.keys().then((keys) => {
      return Promise.all(
        keys.map((key) => {
          if (key.startsWith(CACHE_PREFIX) && key !== CACHE_NAME) {
            console.log('[SW] Deleting legacy cache:', key);
            return caches.delete(key);
          }
        })
      );
    }).then(() => self.clients.claim())
  );
});

// ─── FETCH ───────────────────────────────────────────────────────────────────
self.addEventListener('fetch', (event) => {
  if (event.request.method !== 'GET') return;

  const url = event.request.url;

  // Never intercept WebSockets, MQTT, local IPs, or API calls
  if (
    url.startsWith('ws://') ||
    url.startsWith('wss://') ||
    url.includes('/api/') ||
    /10\.\d+\.\d+\.\d+/.test(url) ||
    /192\.168\.\d+\.\d+/.test(url)
  ) {
    return;
  }

  const isEntrypoint = ENTRYPOINTS.some((ep) => url.endsWith(ep.replace('./', '')) || url.endsWith('/'));

  if (isEntrypoint) {
    // Entrypoints: Network-First with Cache Fallback for instant auto-updates when online
    event.respondWith(
      fetch(event.request, { cache: 'no-cache' })
        .then((networkResponse) => {
          if (networkResponse && networkResponse.ok) {
            const clone = networkResponse.clone();
            caches.open(CACHE_NAME).then((cache) => cache.put(event.request, clone));
            return networkResponse;
          }
          return caches.match(event.request);
        })
        .catch(() => {
          // Offline fallback
          return caches.match(event.request).then((cached) => {
            if (cached) return cached;
            if (event.request.mode === 'navigate') {
              return caches.match('./index.html') || caches.match('./');
            }
          });
        })
    );
  } else {
    // Static assets: Cache-First with Network Fallback
    event.respondWith(
      caches.match(event.request).then((cached) => {
        if (cached) return cached;
        return fetch(event.request)
          .then((networkResponse) => {
            if (networkResponse && networkResponse.ok) {
              const clone = networkResponse.clone();
              caches.open(CACHE_NAME).then((cache) => cache.put(event.request, clone));
            }
            return networkResponse;
          })
          .catch(() => null);
      })
    );
  }
});

// ─── MESSAGING ───────────────────────────────────────────────────────────────
self.addEventListener('message', (event) => {
  if (event.data && event.data.type === 'SKIP_WAITING') {
    self.skipWaiting();
  }
});
