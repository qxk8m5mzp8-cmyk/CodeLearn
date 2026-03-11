// CodeLearn Service Worker — PWA offline support
const CACHE_NAME = ‘codelearn-v1’;
const STATIC_ASSETS = [
‘./’,
‘./index.html’,
‘./manifest.json’,
‘./icons/icon-192.png’,
‘./icons/icon-512.png’,
‘https://fonts.googleapis.com/css2?family=JetBrains+Mono:wght@300;400;600;700&family=Syne:wght@400;700;800&display=swap’
];

// Install: cache all static assets
self.addEventListener(‘install’, event => {
event.waitUntil(
caches.open(CACHE_NAME).then(cache => {
console.log(’[SW] Mise en cache des ressources statiques’);
return cache.addAll(STATIC_ASSETS).catch(err => {
console.warn(’[SW] Certaines ressources non mises en cache :’, err);
});
}).then(() => self.skipWaiting())
);
});

// Activate: clean old caches
self.addEventListener(‘activate’, event => {
event.waitUntil(
caches.keys().then(keys =>
Promise.all(
keys.filter(key => key !== CACHE_NAME).map(key => {
console.log(’[SW] Suppression ancien cache :’, key);
return caches.delete(key);
})
)
).then(() => self.clients.claim())
);
});

// Fetch: cache-first pour les assets statiques, network-first pour l’API Anthropic
self.addEventListener(‘fetch’, event => {
const url = new URL(event.request.url);

// API Anthropic : toujours réseau (jamais mis en cache)
if (url.hostname === ‘api.anthropic.com’) {
event.respondWith(fetch(event.request));
return;
}

// Google Fonts : stale-while-revalidate
if (url.hostname === ‘fonts.googleapis.com’ || url.hostname === ‘fonts.gstatic.com’) {
event.respondWith(
caches.open(CACHE_NAME).then(cache =>
cache.match(event.request).then(cached => {
const networkFetch = fetch(event.request).then(response => {
cache.put(event.request, response.clone());
return response;
});
return cached || networkFetch;
})
)
);
return;
}

// Tout le reste : cache-first avec fallback réseau
event.respondWith(
caches.match(event.request).then(cached => {
if (cached) return cached;
return fetch(event.request).then(response => {
if (response && response.status === 200 && response.type !== ‘opaque’) {
const clone = response.clone();
caches.open(CACHE_NAME).then(cache => cache.put(event.request, clone));
}
return response;
}).catch(() => {
// Fallback hors-ligne : retourner index.html
if (event.request.mode === ‘navigate’) {
return caches.match(’./index.html’);
}
});
})
);
});

// Background sync : notifier quand de retour en ligne
self.addEventListener(‘message’, event => {
if (event.data && event.data.type === ‘SKIP_WAITING’) {
self.skipWaiting();
}
});
