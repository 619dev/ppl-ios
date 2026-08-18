const DB_NAME = 'PaperPhoneSecureCache'
const STORE_NAME = 'encrypted-cache'

function db(): Promise<IDBDatabase> {
  return new Promise((resolve, reject) => {
    const req = indexedDB.open(DB_NAME, 1)
    req.onupgradeneeded = () => {
      if (!req.result.objectStoreNames.contains(STORE_NAME)) req.result.createObjectStore(STORE_NAME)
    }
    req.onsuccess = () => resolve(req.result)
    req.onerror = () => reject(req.error)
  })
}

export async function readSecureCache(key: string): Promise<string | null> {
  const database = await db()
  return new Promise((resolve, reject) => {
    const req = database.transaction(STORE_NAME, 'readonly').objectStore(STORE_NAME).get(key)
    req.onsuccess = () => { database.close(); resolve(req.result || null) }
    req.onerror = () => { database.close(); reject(req.error) }
  })
}

export async function writeSecureCache(key: string, value: string): Promise<void> {
  const database = await db()
  return new Promise((resolve, reject) => {
    const tx = database.transaction(STORE_NAME, 'readwrite')
    tx.objectStore(STORE_NAME).put(value, key)
    tx.oncomplete = () => { database.close(); resolve() }
    tx.onerror = () => { database.close(); reject(tx.error) }
  })
}

export async function deleteSecureCache(key: string): Promise<void> {
  const database = await db()
  return new Promise(resolve => {
    const tx = database.transaction(STORE_NAME, 'readwrite')
    tx.objectStore(STORE_NAME).delete(key)
    tx.oncomplete = tx.onerror = () => { database.close(); resolve() }
  })
}
