import { del, get, post } from './http'

export interface BarkStatus {
  configured: boolean
  endpoint_hint?: string
}

/**
 * Bark endpoints contain the device key, so only send them to the selected
 * PaperPhone server and never persist them in WebView storage.
 */
export function normalizeBarkEndpoint(value: string): string {
  const raw = value.trim().replace(/\/+$/, '')
  let url: URL
  try {
    url = new URL(raw)
  } catch {
    throw new Error('invalid_url')
  }
  if (url.protocol !== 'https:' && url.protocol !== 'http:') throw new Error('invalid_url')
  if (url.username || url.password || url.search || url.hash) throw new Error('invalid_url')
  if (url.pathname === '/' || !url.pathname.slice(1)) throw new Error('missing_key')
  return url.toString().replace(/\/$/, '')
}

export async function getBarkStatus(): Promise<BarkStatus> {
  return get<BarkStatus>('/api/push/bark')
}

export async function saveBarkEndpoint(endpoint: string): Promise<void> {
  await post('/api/push/bark', { endpoint: normalizeBarkEndpoint(endpoint), platform: 'ios' })
}

export async function testBarkEndpoint(endpoint?: string): Promise<void> {
  await post('/api/push/bark/test', endpoint ? { endpoint: normalizeBarkEndpoint(endpoint) } : {})
}

export async function deleteBarkEndpoint(): Promise<void> {
  await del('/api/push/bark')
}
