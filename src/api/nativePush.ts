/**
 * Capacitor Native Push Notifications (APNS)
 *
 * Used on iOS (Capacitor) for native push notifications.
 * Registers the device's APNS token with our server and handles
 * incoming push notification events.
 */
import { PushNotifications } from '@capacitor/push-notifications'
import { post } from './http'
import { useStore } from '../store'
import { setAppBadgeCount } from './appBadge'

let registered = false

/**
 * Initialize native push notifications.
 * - Requests permission
 * - Registers with APNS
 * - Sends APNS token to our server
 * - Sets up notification listeners
 */
export async function initNativePush(): Promise<void> {
  if (registered) return

  try {
    // Check / request permission
    let permStatus = await PushNotifications.checkPermissions()
    if (permStatus.receive === 'prompt') {
      permStatus = await PushNotifications.requestPermissions()
    }
    if (permStatus.receive !== 'granted') {
      console.warn('[NativePush] Permission not granted')
      return
    }

    // Listen for registration success (APNS token)
    PushNotifications.addListener('registration', async (token) => {
      // Normalize token: lowercase hex, strip non-hex characters
      const rawToken = token.value.replace(/[^0-9a-fA-F]/g, '').toLowerCase()
      console.log('[NativePush] ✅ APNS Token:', rawToken.substring(0, 20) + '...', `(${rawToken.length} chars)`)

      // Validate token length — standard APNs device tokens are 64 hex chars (32 bytes)
      if (rawToken.length !== 64) {
        console.warn(`[NativePush] ⚠️ Unexpected APNS token length: ${rawToken.length} (expected 64). Token may be invalid.`)
      }

      // Register APNS token on our server
      try {
        await post('/api/push/apns', {
          apns_token: rawToken,
          platform: 'ios',
        })
        console.log('[NativePush] ✅ APNS token registered on server')
      } catch (e) {
        console.error('[NativePush] Failed to register APNS token on server:', e)
      }
    })

    // Listen for registration errors
    PushNotifications.addListener('registrationError', (err) => {
      console.error('[NativePush] Registration error:', err.error)
    })

    // Listen for incoming push when app is in foreground
    PushNotifications.addListener('pushNotificationReceived', (notification) => {
      console.log('[NativePush] Received in foreground:', notification)
      // APNS payloads may contain a fixed badge value (commonly 1). Restore the
      // authoritative unread total after iOS applies the push payload.
      const unread = Object.values(useStore.getState().unread)
        .reduce((total, count) => total + count, 0)
      setAppBadgeCount(unread)
    })

    // Listen for push notification tap (app opened from notification)
    PushNotifications.addListener('pushNotificationActionPerformed', (action) => {
      console.log('[NativePush] Notification tapped:', action)
      const data = action.notification.data
      // Navigate to chat if the notification contains a chat_id
      if (data?.chat_id) {
        window.location.hash = ''
        window.location.href = `/chat/${data.chat_id}`
      }
    })

    // Register with APNS
    await PushNotifications.register()
    registered = true
    console.log('[NativePush] ✅ Registered with APNS')
  } catch (e) {
    console.error('[NativePush] Init failed:', e)
  }
}

/**
 * Remove APNS token from server on logout.
 */
export async function unregisterNativePush(): Promise<void> {
  if (!registered) return
  try {
    await PushNotifications.removeAllListeners()
    registered = false
    console.log('[NativePush] Unregistered')
  } catch (e) {
    console.error('[NativePush] Unregister failed:', e)
  }
}
