import { get, post, put } from '../api/http'
import { clearAllSenderKeys } from './groupCrypto'
import { getKeys, loadFromIndexedDB, setKeys, type KeyBundle } from './keystore'
import { generateKemKeyPair, generateKeyPair, generateSignKeyPair, initSodium, signMessage } from './ratchet'

async function generateIdentityKeys(): Promise<KeyBundle> {
  const sodium = await initSodium()
  const ikPair = await generateKeyPair()
  const spkPair = await generateKeyPair()
  const signPair = await generateSignKeyPair()
  const kemPair = await generateKemKeyPair()
  if (!kemPair) throw new Error('ML-KEM key generation is unavailable')
  const spkSig = await signMessage(sodium.from_base64(spkPair.publicKey), signPair.privateKey)
  const opks: KeyBundle['opks'] = []
  for (let keyId = 0; keyId < 20; keyId++) {
    const opk = await generateKeyPair()
    opks.push({ key_id: keyId, pub: opk.publicKey, priv: opk.privateKey })
  }
  return {
    ik_pub: ikPair.publicKey, ik_priv: ikPair.privateKey,
    spk_pub: spkPair.publicKey, spk_priv: spkPair.privateKey,
    spk_sig: spkSig,
    sign_pub: signPair.publicKey, sign_priv: signPair.privateKey,
    kem_pub: kemPair.kemPub, kem_priv: kemPair.kemPriv,
    opks,
  }
}

const pendingIdentityLoads = new Map<string, Promise<KeyBundle>>()
const pendingIdentitySyncs = new Map<string, Promise<boolean>>()

async function publishIdentityKeys(keys: KeyBundle): Promise<void> {
  await put('/api/users/keys', {
    ik_pub: keys.ik_pub,
    spk_pub: keys.spk_pub,
    spk_sig: keys.spk_sig,
    kem_pub: keys.kem_pub || keys.sign_pub,
    prekeys: keys.opks.map(key => ({ key_id: key.key_id, opk_pub: key.pub })),
  })
  await post('/api/users/reset-sender-keys', {})
  clearAllSenderKeys()
}

/**
 * Make the server publish the public key matching this device's private key.
 * This is intentionally retryable: persisted sessions can initialize before
 * native Tor is ready, so the first publication attempt may be offline.
 */
export async function syncIdentityKeysWithServer(accountId: string): Promise<boolean> {
  const pending = pendingIdentitySyncs.get(accountId)
  if (pending) return pending
  const sync = (async () => {
    const keys = getKeys() || await loadFromIndexedDB(accountId)
    if (!keys) return false
    const me = await get('/api/users/me')
    if (me?.ik_pub === keys.ik_pub && me?.kem_pub === keys.kem_pub) return false
    await publishIdentityKeys(keys)
    console.log('[Identity] Server public identity reconciled with local private key')
    return true
  })()
  pendingIdentitySyncs.set(accountId, sync)
  try {
    return await sync
  } finally {
    if (pendingIdentitySyncs.get(accountId) === sync) pendingIdentitySyncs.delete(accountId)
  }
}

/** Restores identity keys, or provisions a replacement identity on a new install. */
export async function ensureIdentityKeys(accountId: string): Promise<KeyBundle> {
  const pending = pendingIdentityLoads.get(accountId)
  if (pending) return pending

  const load = ensureIdentityKeysOnce(accountId)
  pendingIdentityLoads.set(accountId, load)
  try {
    return await load
  } finally {
    if (pendingIdentityLoads.get(accountId) === load) pendingIdentityLoads.delete(accountId)
  }
}

async function ensureIdentityKeysOnce(accountId: string): Promise<KeyBundle> {
  let existing = getKeys() || await loadFromIndexedDB(accountId)
  if (existing && (!existing.kem_pub || !existing.kem_priv)) {
    const kemPair = await generateKemKeyPair()
    if (!kemPair) throw new Error('ML-KEM key migration is unavailable')
    existing = { ...existing, kem_pub: kemPair.kemPub, kem_priv: kemPair.kemPriv }
    await setKeys(existing, accountId)
  }
  if (existing) return existing

  const keys = await generateIdentityKeys()
  // The private identity is the startup-critical state. Network publication is
  // best-effort here: an expired/offline session must not permanently lock the
  // app before its normal auth refresh and retry paths can run.
  await setKeys(keys, accountId)
  try {
    await publishIdentityKeys(keys)
    console.log('[Identity] New identity keys generated, sender keys reset')
  } catch (error) {
    console.warn('[Identity] Identity created locally; server sync will be retried after login:', error)
  }
  return keys
}
