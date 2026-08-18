/**
 * Capacitor Local Notifications
 *
 * Used on iOS (Capacitor) to show system-level notifications when the app
 * receives a message via WebSocket while in the foreground or background.
 *
 * These notifications are created entirely on-device from WebSocket events
 * while the app is running. The project does not register for APNs and cannot
 * receive remote notifications after iOS has suspended or terminated it.
 *
 * On web platforms, this is a no-op — browser Notification API is used instead.
 */
import { LocalNotifications } from '@capacitor/local-notifications'
import { isNativePlatform } from '../utils/platform'

let permissionGranted = false

/**
 * Request local notification permissions.
 * Should be called once during app initialization.
 */
export async function initLocalNotifications(): Promise<void> {
  if (!isNativePlatform()) return

  try {
    let perm = await LocalNotifications.checkPermissions()
    if (perm.display === 'prompt') {
      perm = await LocalNotifications.requestPermissions()
    }
    permissionGranted = perm.display === 'granted'
    if (permissionGranted) {
      console.log('[LocalNotification] ✅ Permission granted')
    } else {
      console.warn('[LocalNotification] Permission not granted:', perm.display)
    }

    // Listen for notification tap to navigate to the chat
    LocalNotifications.addListener('localNotificationActionPerformed', (action) => {
      const data = action.notification.extra
      if (data?.chatId) {
        const path = data.isGroup
          ? `/chat/${data.chatId}?group=1`
          : `/chat/${data.chatId}`
        window.location.href = path
      }
    })
  } catch (e) {
    console.warn('[LocalNotification] Init failed:', e)
  }
}

/**
 * Show a local notification for an incoming message.
 * This creates a system-level notification (banner + notification center).
 */
export async function showLocalNotification(opts: {
  title: string
  body: string
  chatId?: string
  isGroup?: boolean
}): Promise<void> {
  if (!isNativePlatform() || !permissionGranted) return

  try {
    await LocalNotifications.schedule({
      notifications: [
        {
          id: Date.now() % 2147483647, // must be a 32-bit int
          title: opts.title,
          body: opts.body,
          sound: 'default',
          extra: {
            chatId: opts.chatId,
            isGroup: opts.isGroup,
          },
        },
      ],
    })
  } catch (e) {
    console.warn('[LocalNotification] Schedule failed:', e)
  }
}
