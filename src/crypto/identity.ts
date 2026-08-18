import { post, put } from '../api/http'
import { clearAllSenderKeys } from './groupCrypto'
import { getKeys, loadFromIndexedDB, setKeys, type KeyBundle } from './keystore'
import { generateKeyPair, generateSignKeyPair, initSodium, signMessage } from './ratchet'

async function generateIdentityKeys(): Promise<KeyBundle> {
  const sodium = await initSodium()
  const ikPair = await generateKeyPair()
  const spkPair = await generateKeyPair()
  const signPair = await generateSignKeyPair()
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
    opks,
  }
}

const pendingIdentityLoads = new Map<string, Promise<KeyBundle>>()

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
  const existing = getKeys() || await loadFromIndexedDB(accountId)
  if (existing) return existing

  const keys = await generateIdentityKeys()
  // The private identity is the startup-critical state. Network publication is
  // best-effort here: an expired/offline session must not permanently lock the
  // app before its normal auth refresh and retry paths can run.
  await setKeys(keys, accountId)
  try {
    await put('/api/users/keys', {
      ik_pub: keys.ik_pub,
      spk_pub: keys.spk_pub,
      spk_sig: keys.spk_sig,
      kem_pub: keys.sign_pub,
      prekeys: keys.opks.map(key => ({ key_id: key.key_id, opk_pub: key.pub })),
    })
    await post('/api/users/reset-sender-keys', {})
    clearAllSenderKeys()
    console.log('[Identity] New identity keys generated, sender keys reset')
  } catch (error) {
    console.warn('[Identity] Identity created locally; server sync will be retried after login:', error)
  }
  return keys
}
