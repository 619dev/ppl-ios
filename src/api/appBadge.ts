import { Badge } from '@capawesome/capacitor-badge'
import { isNativePlatform } from '../utils/platform'

/** Keep the native app-icon badge in sync with the in-app unread count. */
export async function setAppBadgeCount(count: number): Promise<void> {
  if (!isNativePlatform()) return

  try {
    await Badge.set({ count: Math.max(0, Math.trunc(count)) })
  } catch (error) {
    console.warn('[AppBadge] Failed to update badge:', error)
  }
}
