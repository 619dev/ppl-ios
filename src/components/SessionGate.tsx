import type { ReactNode } from 'react'
import { Navigate } from 'react-router-dom'

export default function SessionGate({ authenticated, hydrated, loadingLabel, children }: {
  authenticated: boolean
  hydrated: boolean
  loadingLabel: string
  children: ReactNode
}) {
  if (!authenticated) return <Navigate to="/login" replace />
  // Stay on the requested route while Keychain and local crypto state restore.
  // Redirecting to login here bounces back immediately for a persisted token.
  if (!hydrated) return <div className="page" role="status" aria-live="polite">
    <div className="empty-state">{loadingLabel}</div>
  </div>
  return children
}
