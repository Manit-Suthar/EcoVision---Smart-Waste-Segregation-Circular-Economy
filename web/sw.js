const CACHE_NAME = 'ecovision-v5';
const STATIC_ASSETS = [
    './',
    './index.html',
    './styles.css',
    './script.js',
    './api.js',
    './manifest.json',
    './icon.svg',
    './icon-192.png',
    './icon-512.png',
    '../shared/ecovision_model.onnx',
    '../shared/config.json',
    '../shared/labels.json',
    '../shared/waste_database.json',
    '../shared/categories.json',
    '../shared/bin_colors.json',
    'https://cdn.jsdelivr.net/npm/onnxruntime-web@1.18.0/dist/ort.min.js'
];

self.addEventListener('install', (event) => {
    event.waitUntil(
        caches.open(CACHE_NAME).then((cache) => cache.addAll(STATIC_ASSETS))
    );
    self.skipWaiting();
});

self.addEventListener('activate', (event) => {
    event.waitUntil(
        caches.keys().then((keys) => {
            return Promise.all(
                keys.filter((key) => key !== CACHE_NAME).map((key) => caches.delete(key))
            );
        })
    );
    self.clients.claim();
});

self.addEventListener('fetch', (event) => {
    event.respondWith(
        caches.match(event.request).then((cachedResponse) => {
            if (cachedResponse) {
                return cachedResponse; // Return from cache if available
            }
            return fetch(event.request).catch((err) => {
                console.error("Fetch failed (offline?):", err);
                return new Response("Offline", { status: 503 });
            });
        })
    );
});
