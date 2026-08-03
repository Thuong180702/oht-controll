// Service Worker for OHT Control System (Offline-First PWA)
// Modeled after clean cache-first architecture for full offline operation

const CACHE_NAME = 'oht-pwa-v55';

// Core assets to pre-cache on install
const CORE_ASSETS = [
  './',
  './index.html',
  './loading.css',
  './manifest.json',
  './flutter_bootstrap.js',
  './flutter.js',
  './main.dart.js',
  './favicon.png',
  './icons/Icon-192.png',
  './icons/Icon-512.png',
  './assets/FontManifest.json',
  './assets/fonts/MaterialIcons-Regular.otf',
  './assets/packages/cupertino_icons/assets/CupertinoIcons.ttf'
];

// Install: Pre-cache all core assets & take control immediately
self.addEventListener('install', (event) => {
  self.skipWaiting();
  event.waitUntil(
    caches.open(CACHE_NAME).then((cache) => {
      return Promise.all(
        CORE_ASSETS.map((url) =>
          fetch(url)
            .then((response) => {
              if (response.ok) {
                return cache.put(url, response);
              }
            })
            .catch((err) => console.warn('[SW] Pre-cache skipped:', url, err))
        )
      );
    })
  );
});

// Activate: Claim clients and remove old caches immediately
self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys().then((keys) => {
      return Promise.all(
        keys.map((key) => {
          if (key !== CACHE_NAME) {
            console.log('[SW] Deleting legacy cache:', key);
            return caches.delete(key);
          }
        })
      );
    }).then(() => self.clients.claim())
  );
});

// Fetch: Cache-first strategy for ALL HTTP/HTTPS GET requests
// Only bypass WebSocket connections (ws:// and wss://)
self.addEventListener('fetch', (event) => {
  if (event.request.method !== 'GET') return;

  const url = event.request.url;

  // Never intercept WebSockets
  if (url.startsWith('ws://') || url.startsWith('wss://')) return;

  event.respondWith(
    caches.match(event.request).then((cached) => {
      if (cached) {
        return cached;
      }

      // If not in cache, fetch from network and dynamically cache
      return fetch(event.request)
        .then((response) => {
          if (response && response.status === 200) {
            const responseClone = response.clone();
            caches.open(CACHE_NAME).then((cache) => {
              cache.put(event.request, responseClone);
            });
          }
          return response;
        })
        .catch(() => {
          // If network fails (e.g. server turned off), try fallback for navigation
          if (event.request.mode === 'navigate') {
            return caches.match('./index.html') || caches.match('./');
          }
        });
    })
  );
});
