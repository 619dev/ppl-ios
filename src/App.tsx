import { BrowserRouter, Routes, Route, Navigate, useNavigate } from 'react-router-dom'
import { useEffect, useState } from 'react'
import { useStore } from './store'
import { useSocket } from './hooks/useSocket'
import { ensureIdentityKeys, syncIdentityKeysWithServer } from './crypto/identity'
import { hydrateSenderKeys } from './crypto/groupCrypto'
import { getPresentationSettings, handlePresentationAppState, hydratePresentationCrypto, isPresentationUnlocked, presentationCiphertextForPlaintext, unlockPresentationCrypto } from './crypto/presentationCrypto'
import Login from './pages/Login'
import Chats from './pages/Chats'
import Chat from './pages/Chat'
import Contacts from './pages/Contacts'
import Discover from './pages/Discover'
import Profile from './pages/Profile'
import UserProfile from './pages/UserProfile'
import GroupInfo from './pages/GroupInfo'
import PrivacyPolicy from './pages/PrivacyPolicy'
import TermsOfUse from './pages/TermsOfUse'
import TabBar from './components/TabBar'
import NotificationToast from './components/NotificationToast'
import { get, post } from './api/http'
import { getPlatform, isNativePlatform } from './utils/platform'
import { useAutoDeleteCleanup } from './hooks/useAutoDeleteCleanup'
import { initLocalNotifications } from './api/localNotification'
import { setAppBadgeCount } from './api/appBadge'
import { useI18n } from './hooks/useI18n'
import { isNativeTorPlatform, onTorStatusChange, startTor } from './api/tor-bridge'

function ProtectedLayout() {
  useSocket()
  useAutoDeleteCleanup()
  const totalUnread = useStore(state =>
    Object.values(state.unread).reduce((total, count) => total + count, 0)
  )

  useEffect(() => {
    if (getPlatform() !== 'ios') return
    initLocalNotifications().catch(error => console.warn('[LocalNotification] Init failed:', error))
  }, [])

  useEffect(() => {
    if (getPlatform() === 'ios') setAppBadgeCount(totalUnread)
  }, [totalUnread])

  // Android uses ntfy so no Google push framework is required.
  useEffect(() => {
    if (getPlatform() === 'android') {
      ;(async () => {
        try {
          const topicRes = await get<{ ntfy_topic: string }>('/api/push/ntfy-topic')
          if (topicRes?.ntfy_topic) {
            const statusRes = await get<any>('/api/push/status')
            if (!statusRes?.user_ntfy_subscriptions || statusRes.user_ntfy_subscriptions === 0) {
              await post('/api/push/ntfy', { ntfy_topic: topicRes.ntfy_topic, platform: 'android' })
              console.log('[ntfy] ✅ Auto-registered topic:', topicRes.ntfy_topic)
            }
          }
        } catch (e) {
          console.warn('[ntfy] Auto-register failed:', e)
        }
      })()
    }
  }, [])

  // ── Capacitor: Android back button handling ──
  useEffect(() => {
    if (getPlatform() !== 'android') return
    let cleanup: (() => void) | undefined
    import('@capacitor/app').then(({ App }) => {
      const listener = App.addListener('backButton', ({ canGoBack }) => {
        if (canGoBack) {
          window.history.back()
        } else {
          App.exitApp()
        }
      })
      cleanup = () => { listener.then(l => l.remove()) }
    })
    return () => { cleanup?.() }
  }, [])

  return (
    <>
        <Routes>
          <Route path="/chats" element={<Chats />} />
          <Route path="/chat/:id" element={<Chat />} />
          <Route path="/contacts" element={<Contacts />} />
          <Route path="/discover" element={<Discover />} />
          <Route path="/profile" element={<Profile />} />
          <Route path="/user/:id" element={<UserProfile />} />
          <Route path="/group/:id" element={<GroupInfo />} />
          <Route path="/privacy" element={<PrivacyPolicy />} />
          <Route path="/terms" element={<TermsOfUse />} />
          <Route path="*" element={<Navigate to="/chats" replace />} />
        </Routes>
        <TabBar />
        <NotificationToast />
    </>
  )
}

export default function App() {
  const token = useStore(s => s.token)
  const user = useStore(s => s.user)
  const theme = useStore(s => s.theme)
  const [hydratedAccount, setHydratedAccount] = useState<string | null>(null)
  const [showPresentationUnlock, setShowPresentationUnlock] = useState(false)
  const [presentationPassword, setPresentationPassword] = useState('')
  const [presentationUnlockError, setPresentationUnlockError] = useState('')
  const [presentationUnlockBusy, setPresentationUnlockBusy] = useState(false)
  const { t } = useI18n()

  // A persisted session bypasses the login page, so native Tor must be
  // started at the app root. Otherwise every HTTP/WS request to the onion
  // service is attempted before a WebKit proxy exists and reconnects forever.
  useEffect(() => {
    if (!isNativeTorPlatform) return
    let cancelled = false
    let removeListener: (() => void) | undefined

    onTorStatusChange(state => {
      if (state.ready) window.dispatchEvent(new Event('paperphone:network-changed'))
    }).then(handle => {
      if (cancelled) void handle?.remove()
      else if (handle) removeListener = () => void handle.remove()
    }).catch(error => console.warn('[Tor] Status listener failed:', error))

    startTor().then(state => {
      if (!cancelled && state.ready) window.dispatchEvent(new Event('paperphone:network-changed'))
    }).catch(error => console.error('[Tor] Startup failed:', error))

    return () => {
      cancelled = true
      removeListener?.()
    }
  }, [])

  const syncPresentationUnlockPrompt = () => {
    const shouldPrompt = Boolean(useStore.getState().token && useStore.getState().user?.id)
      && getPresentationSettings().enabled
      && !isPresentationUnlocked()
    setShowPresentationUnlock(shouldPrompt)
    if (!shouldPrompt) {
      setPresentationPassword('')
      setPresentationUnlockError('')
    }
  }

  useEffect(() => {
    document.documentElement.setAttribute('data-theme', theme)
  }, [theme])

  useEffect(() => {
    let cancelled = false
    if (!token || !user?.id) {
      setHydratedAccount(null)
      return
    }
    Promise.all([ensureIdentityKeys(user.id), hydrateSenderKeys(user.id), hydratePresentationCrypto(user.id)])
      .then(() => {
        if (cancelled) return
        syncPresentationUnlockPrompt()
        setHydratedAccount(user.id)
      })
      .catch(err => {
        console.error('[App] Secure crypto state hydration failed:', err)
        if (!cancelled) {
          syncPresentationUnlockPrompt()
          setHydratedAccount(user.id)
        }
      })
    return () => { cancelled = true }
  // Access tokens rotate independently of the signed-in account. Rehydrating
  // on every refresh clears the in-memory presentation password immediately
  // after a successful startup unlock, so key this lifecycle to the account.
  }, [user?.id])

  useEffect(() => {
    if (!token || !user?.id || hydratedAccount !== user.id) return
    let cancelled = false
    const reconcile = () => {
      if (cancelled) return
      syncIdentityKeysWithServer(user.id).catch(error => {
        console.warn('[Identity] Server reconciliation deferred until network recovery:', error)
      })
    }
    reconcile()
    window.addEventListener('online', reconcile)
    window.addEventListener('paperphone:network-changed', reconcile)
    return () => {
      cancelled = true
      window.removeEventListener('online', reconcile)
      window.removeEventListener('paperphone:network-changed', reconcile)
    }
  }, [token, user?.id, hydratedAccount])

  const unlockPresentationAtStartup = async (event: React.FormEvent) => {
    event.preventDefault()
    if (!presentationPassword || presentationUnlockBusy) return
    setPresentationUnlockBusy(true)
    setPresentationUnlockError('')
    try {
      if (await unlockPresentationCrypto(presentationPassword)) {
        setShowPresentationUnlock(false)
        setPresentationPassword('')
      } else {
        setPresentationUnlockError(t('chat.presentation_startup_wrong_password'))
      }
    } finally {
      setPresentationUnlockBusy(false)
    }
  }

  const cancelPresentationUnlock = () => {
    setShowPresentationUnlock(false)
    setPresentationPassword('')
    setPresentationUnlockError('')
  }

  useEffect(() => {
    const onVisibility = () => handlePresentationAppState(document.visibilityState === 'visible')
    const onPresentationState = () => {
      syncPresentationUnlockPrompt()
      if (!isPresentationUnlocked()) {
        const messages = useStore.getState().messages
        const locked = Object.fromEntries(Object.entries(messages).map(([chatId, items]) => [
          chatId,
          items.map(({ decrypted, ...message }) => ({ ...message, ...(presentationCiphertextForPlaintext(decrypted) ? { decrypted: presentationCiphertextForPlaintext(decrypted) } : {}) })),
        ]))
        useStore.setState({ messages: locked })
      }
    }
    document.addEventListener('visibilitychange', onVisibility)
    window.addEventListener('paperphone:presentation-state-changed', onPresentationState)
    let removeNative: (() => void) | undefined
    import('@capacitor/app').then(({ App: CapApp }) => CapApp.addListener('appStateChange', ({ isActive }) => handlePresentationAppState(isActive)))
      .then(handle => { removeNative = () => void handle.remove() }).catch(() => {})
    return () => {
      document.removeEventListener('visibilitychange', onVisibility)
      window.removeEventListener('paperphone:presentation-state-changed', onPresentationState)
      removeNative?.()
    }
  }, [])

  // ── Capacitor: Deep Link handler ──
  // Handles paperphonelite:// URLs to navigate within the app
  useEffect(() => {
    if (!isNativePlatform()) return
    let cleanup: (() => void) | undefined
    import('@capacitor/app').then(({ App: CapApp }) => {
      const listener = CapApp.addListener('appUrlOpen', (event) => {
        console.log('[DeepLink] URL opened:', event.url)
        // paperphonelite://chat/123  → /chat/123
        // paperphonelite://user/abc  → /user/abc
        // paperphonelite://add-friend?id=xxx → /contacts?add=xxx
        try {
          const url = new URL(event.url)
          const path = url.pathname || url.host + (url.pathname || '')
          if (path) {
            window.location.href = '/' + path.replace(/^\/+/, '')
          }
        } catch {
          // Fallback: strip scheme and navigate
          const path = event.url.replace(/^paperphonelite:\/\//, '')
          if (path) window.location.href = '/' + path
        }
      })
      cleanup = () => { listener.then(l => l.remove()) }
    })
    return () => { cleanup?.() }
  }, [])

  return (
    <BrowserRouter>
      <Routes>
        <Route path="/login" element={token ? <Navigate to="/chats" replace /> : <Login />} />
        <Route path="/privacy" element={<PrivacyPolicy />} />
        <Route path="/terms" element={<TermsOfUse />} />
        <Route path="/*" element={token && user?.id && hydratedAccount === user.id ? <ProtectedLayout /> : <Navigate to="/login" replace />} />
      </Routes>
      {showPresentationUnlock && (
        <div className="modal-overlay" role="presentation">
          <form className="modal" role="dialog" aria-modal="true" aria-labelledby="presentation-startup-title" onSubmit={unlockPresentationAtStartup}>
            <h2 id="presentation-startup-title" style={{ fontSize: 17, fontWeight: 600, marginBottom: 16 }}>
              {t('profile.message_privacy')}
            </h2>
            <div className="input-group" style={{ marginBottom: 12 }}>
              <label htmlFor="presentation-startup-password">{t('chat.presentation_startup_password_prompt')}</label>
              <input
                className="input"
                id="presentation-startup-password"
                type="password"
                autoComplete="current-password"
                autoFocus
                value={presentationPassword}
                onChange={event => {
                  setPresentationPassword(event.target.value)
                  if (presentationUnlockError) setPresentationUnlockError('')
                }}
              />
            </div>
            {presentationUnlockError && (
              <div role="alert" style={{ color: 'var(--danger)', fontSize: 13, marginBottom: 12 }}>
                {presentationUnlockError}
              </div>
            )}
            <div style={{ display: 'flex', gap: 10 }}>
              <button type="button" className="btn btn-full" onClick={cancelPresentationUnlock} disabled={presentationUnlockBusy}>
                {t('common.cancel')}
              </button>
              <button type="submit" className="btn btn-primary btn-full" disabled={!presentationPassword || presentationUnlockBusy}>
                {presentationUnlockBusy ? t('common.loading') : t('common.confirm')}
              </button>
            </div>
          </form>
        </div>
      )}
    </BrowserRouter>
  )
}
