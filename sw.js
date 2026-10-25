// Garaad offline cache — version g3-family-1
const CACHE = 'garaad-g3-family-1';
const CORE = ['./','index.html','manifest.webmanifest','icon-192.png','icon-512.png','icon-maskable-512.png','apple-touch-icon.png','favicon-64.png',
  'fonts/baloo2-800.woff2','fonts/lexend-400.woff2','fonts/lexend-500.woff2','fonts/lexend-600.woff2','fonts/lexend-700.woff2'];
self.addEventListener('install', e => { e.waitUntil(caches.open(CACHE).then(c => c.addAll(CORE)).then(() => self.skipWaiting())); });
self.addEventListener('activate', e => { e.waitUntil(caches.keys().then(ks => Promise.all(ks.filter(k => k !== CACHE).map(k => caches.delete(k)))).then(() => self.clients.claim())); });
self.addEventListener('fetch', e => {
  const req = e.request; if (req.method !== 'GET') return;
  const url = new URL(req.url);
  // the game page: try the network first so updates arrive, fall back to the saved copy offline
  if (req.mode === 'navigate' || (url.origin === location.origin && url.pathname.endsWith('/index.html'))) {
    e.respondWith(fetch(req).then(r => { const c = r.clone(); caches.open(CACHE).then(ca => ca.put('index.html', c)); return r; })
      .catch(() => caches.match('index.html').then(r => r || caches.match('./'))));
    return;
  }
  // icons, fonts: saved copy first
  e.respondWith(caches.match(req).then(hit => hit || fetch(req).then(r => {
    if (r && (r.ok || r.type === 'opaque')) { const c = r.clone(); caches.open(CACHE).then(ca => ca.put(req, c)); }
    return r;
  })));
});
