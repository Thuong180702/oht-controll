// OHT Control System — Custom Service Worker
// Strategy: Pure Cache-first for offline reliability, network-bypass for WebSockets/Local IPs

const CACHE_VERSION = 'oht-v1';
const CACHE_NAME = `oht-app-cache-${CACHE_VERSION}`;

// Critical resources that MUST be cached for offline boot
const CRITICAL_RESOURCES = [
  './',
  './index.html',
  './main.dart.js',
  './flutter.js',
  './flutter_bootstrap.js',
  './manifest.json',
  './loading.css',
  './favicon.png',
];

// Resources that are nice-to-have but not critical
const OPTIONAL_RESOURCES = [
  './icons/Icon-192.png',
  './icons/Icon-512.png',
  './icons/Icon-maskable-192.png',
  './icons/Icon-maskable-512.png',
];

// Patterns to never cache (WebSocket, local network, API)
const BYPASS_PATTERNS = [
  /^wss?:\/\//,       // WebSocket connections
  /^mqtt/,            // MQTT connections
  /\/ws\/?$/,         // WebSocket endpoints
  /10\.\d+\.\d+\.\d+/,   // Local 10.x.x.x network
  /192\.168\.\d+\.\d+/,  // Local 192.168.x.x network
  /172\.(1[6-9]|2\d|3[01])\.\d+\.\d+/, // Local 172.16-31.x.x
];

// ─── INSTALL ─────────────────────────────────────────────────────────────────

self.addEventListener('install', (event) => {
  console.log('[SW] Installing service worker...');
  event.waitUntil(
    caches.open(CACHE_NAME)
      .then(async (cache) => {
        const allResources = [...CRITICAL_RESOURCES, ...OPTIONAL_RESOURCES];
        let loaded = 0;
        const total = allResources.length;

        for (const url of CRITICAL_RESOURCES) {
          try {
            const response = await fetchWithRetry(url, 3);
            if (response && response.ok) {
              await cache.put(url, response);
            }
            loaded++;
            reportProgress(loaded, total, `Caching: ${url.split('/').pop()}`);
          } catch (err) {
            console.warn(`[SW] Critical resource failed: ${url}`, err);
            loaded++;
            reportProgress(loaded, total, `Warning: ${url.split('/').pop()}`);
          }
        }

        for (const url of OPTIONAL_RESOURCES) {
          try {
            const response = await fetchWithRetry(url, 2);
            if (response && response.ok) {
              await cache.put(url, response);
            }
          } catch (err) {
            console.warn(`[SW] Optional resource skipped: ${url}`, err);
          }
          loaded++;
          reportProgress(loaded, total, `Caching: ${url.split('/').pop()}`);
        }

        reportProgress(total, total, 'Installation complete');
        console.log('[SW] Install complete');
      })
      .then(() => self.skipWaiting())
  );
});

// ─── ACTIVATE ────────────────────────────────────────────────────────────────

self.addEventListener('activate', (event) => {
  console.log('[SW] Activating service worker...');
  event.waitUntil(
    caches.keys()
      .then((cacheNames) => {
        return Promise.all(
          cacheNames
            .filter((name) => name.startsWith('oht-') && name !== CACHE_NAME)
            .map((name) => {
              console.log(`[SW] Deleting old cache: ${name}`);
              return caches.delete(name);
            })
        );
      })
      .then(() => self.clients.claim())
      .then(() => {
        console.log('[SW] Activation complete');
      })
  );
});

// ─── FETCH ───────────────────────────────────────────────────────────────────

self.addEventListener('fetch', (event) => {
  const url = event.request.url;

  // Never intercept WebSocket or local network requests
  if (shouldBypass(url) || event.request.method !== 'GET') {
    return;
  }

  // Pure Cache-First for EVERYTHING (including navigation / index.html)
  // This guarantees tabs NEVER reload when switched or refocused.
  event.respondWith(cacheFirstWithNetworkFallback(event.request));
});

// ─── MESSAGE HANDLER ─────────────────────────────────────────────────────────

self.addEventListener('message', (event) => {
  if (event.data && event.data.type === 'CHECK_UPDATE') {
    checkForUpdates();
  }

  if (event.data && event.data.type === 'SKIP_WAITING') {
    self.skipWaiting();
  }

  if (event.data && event.data.type === 'GET_CACHE_STATUS') {
    getCacheStatus().then(status => {
      if (event.source) {
        event.source.postMessage({
          type: 'CACHE_STATUS',
          ...status,
        });
      }
    });
  }
});

// ─── CACHE STRATEGIES ────────────────────────────────────────────────────────

async function cacheFirstWithNetworkFallback(request) {
  try {
    // 1. Try cache first
    const cached = await caches.match(request);
    if (cached) {
      return cached;
    }

    // 2. Cache miss - try network
    const networkResponse = await fetch(request);
    if (networkResponse && networkResponse.ok) {
      const cache = await caches.open(CACHE_NAME);
      cache.put(request, networkResponse.clone());
      return networkResponse;
    }

    return networkResponse;
  } catch (err) {
    // 3. Network failed - last resort for navigation is cached index.html
    if (request.mode === 'navigate') {
      const indexCached = await caches.match('./index.html');
      if (indexCached) return indexCached;
    }

    console.error('[SW] Both cache and network failed:', request.url);
    return new Response('Offline - resource not cached', {
      status: 503,
      headers: { 'Content-Type': 'text/plain' }
    });
  }
}

// ─── UPDATE CHECK ────────────────────────────────────────────────────────────

async function checkForUpdates() {
  try {
    const response = await fetch('./manifest.json', { cache: 'no-store' });
    if (!response.ok) return;

    const cached = await caches.match('./manifest.json');
    if (!cached) return;

    const newText = await response.clone().text();
    const cachedText = await cached.text();

    if (newText !== cachedText) {
      console.log('[SW] Update detected via manifest!');
      // Notify all clients that an update is available (User can click "Cập nhật ngay" if they want)
      const clients = await self.clients.matchAll();
      for (const client of clients) {
        client.postMessage({ type: 'UPDATE_AVAILABLE' });
      }
    }
  } catch (err) {
    console.log('[SW] Update check skipped (offline)');
  }
}

async function getCacheStatus() {
  try {
    const cache = await caches.open(CACHE_NAME);
    const keys = await cache.keys();
    const missing = [];

    for (const url of CRITICAL_RESOURCES) {
      const match = await cache.match(url);
      if (!match) {
        missing.push(url);
      }
    }

    return {
      total: keys.length,
      criticalMissing: missing,
      hasMissingCritical: missing.length > 0,
    };
  } catch (err) {
    return { total: 0, criticalMissing: CRITICAL_RESOURCES, hasMissingCritical: true };
  }
}

// ─── UTILITIES ───────────────────────────────────────────────────────────────

function shouldBypass(url) {
  for (const pattern of BYPASS_PATTERNS) {
    if (pattern.test(url)) return true;
  }
  return false;
}

async function fetchWithRetry(url, maxRetries = 3) {
  let lastError;
  for (let attempt = 0; attempt < maxRetries; attempt++) {
    try {
      const response = await fetch(url);
      if (response.ok) return response;
      lastError = new Error(`HTTP ${response.status}`);
    } catch (err) {
      lastError = err;
      if (attempt < maxRetries - 1) {
        await new Promise(r => setTimeout(r, 500 * Math.pow(2, attempt)));
      }
    }
  }
  throw lastError;
}

function reportProgress(loaded, total, message) {
  self.clients.matchAll().then(clients => {
    for (const client of clients) {
      client.postMessage({
        type: 'CACHE_PROGRESS',
        loaded,
        total,
        message,
        percent: Math.round((loaded / total) * 100),
      });
    }
  });
}
