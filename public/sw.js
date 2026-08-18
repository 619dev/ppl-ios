/* PaperPhoneLite Service Worker — offline shell and media cache */
const CACHE_NAME = 'paperphonelite-shell-v2'
const MEDIA_CACHE_NAME = 'paperphone-media-v2'
const STICKER_CACHE_NAME = 'paperphone-stickers-v1'

// Install: cache app shell
self.addEventListener('install', (event) => {
  self.skipWaiting()
})

// Activate: clean old caches
self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys().then(keys =>
      Promise.all(keys.filter(k => ![CACHE_NAME, MEDIA_CACHE_NAME, STICKER_CACHE_NAME].includes(k)).map(k => caches.delete(k)))
    ).then(() => self.clients.claim())
  )
})

// Fetch: network-first for API, cache-first for assets
self.addEventListener('fetch', (event) => {
  const url = new URL(event.request.url)

  // API JSON is persisted by the app with account isolation. Media responses
  // remain in Cache Storage so they are available while offline.
  if (url.pathname.startsWith('/ws')) return
  if (url.pathname.startsWith('/api') && !url.pathname.startsWith('/api/uploads') && !url.pathname.startsWith('/api/media')) return

  // For navigation and assets, try network first then cache
  if (event.request.mode === 'navigate') {
    event.respondWith(
      fetch(event.request).catch(() => caches.match('/index.html'))
    )
    return
  }

  // Static assets: cache-first
  if (event.request.method === 'GET') {
    event.respondWith(
      caches.match(event.request, { ignoreVary: true }).then(cached => {
        const fetchPromise = fetch(event.request).then(response => {
          if (response && response.status === 200) {
            const clone = response.clone()
            const isMedia = response.headers.get('content-type')?.match(/^(image|video|audio)\//)
            caches.open(isMedia ? MEDIA_CACHE_NAME : CACHE_NAME).then(cache => cache.put(event.request, clone))
          }
          return response
        }).catch(() => cached)
        return cached || fetchPromise
      })
    )
  }
})
