const CACHE_NAME = 'pasto-v2';
// Cache only assets within the service worker's scope (/pasto/assets/)
const urlsToCache = [
  './bundle.js',
  './codejar.min.js',
  './crypto.js',
  './language-mapping.js',
  './editor-shared.js',
  './mobile_controls.js',
  './manifest.json',
  './favicon.png'
];

// Install service worker and cache resources
self.addEventListener('install', event => {
  event.waitUntil(
    caches.open(CACHE_NAME)
      .then(cache => {
        return cache.addAll(urlsToCache)
          .catch(error => {
            console.error('Failed to cache some resources:', error);
            // Log which URLs failed
            return Promise.all(
              urlsToCache.map(url => {
                return fetch(url).then(response => {
                  if (!response.ok) {
                    console.error('Failed to fetch:', url, response.status);
                  }
                  return response;
                }).catch(e => {
                  console.error('Error fetching:', url, e);
                  throw e;
                });
              })
            );
          });
      })
  );
});

// Serve cached content when offline
self.addEventListener('fetch', event => {
  event.respondWith(
    caches.match(event.request)
      .then(response => {
        // Cache hit - return response
        if (response) {
          return response;
        }

        // Clone the request
        const fetchRequest = event.request.clone();

        return fetch(fetchRequest).then(response => {
          // Check if valid response
          if(!response || response.status !== 200 || response.type !== 'basic') {
            return response;
          }

          // Clone the response
          const responseToCache = response.clone();

          caches.open(CACHE_NAME)
            .then(cache => {
              cache.put(event.request, responseToCache);
            });

          return response;
        });
      })
  );
});

// Update service worker and clean up old caches
self.addEventListener('activate', event => {
  event.waitUntil(
    caches.keys().then(cacheNames => {
      return Promise.all(
        cacheNames.map(cacheName => {
          if (cacheName !== CACHE_NAME) {
            return caches.delete(cacheName);
          }
        })
      );
    })
  );
});