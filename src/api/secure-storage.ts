import { Capacitor, registerPlugin } from '@capacitor/core'

interface SecureStoragePlugin {
  seal(options: { account: string; plaintext: string; purpose: string }): Promise<{ ciphertext: string }>
  open(options: { account: string; ciphertext: string; purpose: string }): Promise<{ plaintext: string }>
  setSecret(options: { account: string; name: string; value: string }): Promise<void>
  getSecret(options: { account: string; name: string }): Promise<{ value: string | null }>
  deleteSecret(options: { account: string; name: string }): Promise<void>
}

const SecureStorage = registerPlugin<SecureStoragePlugin>('SecureStorage')

export function hasNativeSecureStorage(): boolean {
  return Capacitor.isNativePlatform()
}

export async function sealForAccount(account: string, purpose: string, plaintext: string): Promise<string> {
  if (!hasNativeSecureStorage()) throw new Error('Secure storage is unavailable outside the native app')
  return (await SecureStorage.seal({ account, purpose, plaintext })).ciphertext
}

export async function openForAccount(account: string, purpose: string, ciphertext: string): Promise<string> {
  if (!hasNativeSecureStorage()) throw new Error('Secure storage is unavailable outside the native app')
  return (await SecureStorage.open({ account, purpose, ciphertext })).plaintext
}

export async function setSecureSecret(account: string, name: string, value: string): Promise<void> {
  if (!hasNativeSecureStorage()) return
  await SecureStorage.setSecret({ account, name, value })
}

export async function getSecureSecret(account: string, name: string): Promise<string | null> {
  if (!hasNativeSecureStorage()) return null
  return (await SecureStorage.getSecret({ account, name })).value
}

export async function deleteSecureSecret(account: string, name: string): Promise<void> {
  if (!hasNativeSecureStorage()) return
  await SecureStorage.deleteSecret({ account, name })
}
