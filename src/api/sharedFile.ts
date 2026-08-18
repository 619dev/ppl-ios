import { Capacitor, registerPlugin } from '@capacitor/core'

export interface PendingSharedFile {
  id: string
  name: string
  mimeType: string
  size: number
  path: string
}

interface SharedFilePlugin {
  getPending(): Promise<{ file: PendingSharedFile | null }>
  clearPending(options?: { id?: string }): Promise<void>
}

const SharedFile = registerPlugin<SharedFilePlugin>('SharedFile')

export async function getPendingSharedFile(): Promise<PendingSharedFile | null> {
  if (!Capacitor.isNativePlatform()) return null
  return (await SharedFile.getPending()).file
}

export async function readPendingSharedFile(file: PendingSharedFile): Promise<File> {
  const response = await fetch(Capacitor.convertFileSrc(file.path))
  if (!response.ok) throw new Error(`Unable to read shared file (${response.status})`)
  const blob = await response.blob()
  return new File([blob], file.name, { type: file.mimeType || blob.type || 'application/octet-stream' })
}

export async function clearPendingSharedFile(id?: string): Promise<void> {
  if (!Capacitor.isNativePlatform()) return
  await SharedFile.clearPending(id ? { id } : undefined)
}
