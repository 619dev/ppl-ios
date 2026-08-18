/**
 * Global Call Context
 *
 * Provides call state to the entire app so incoming calls can be
 * received from any page, not just the Chat page.
 */
import { createContext, useContext, ReactNode } from 'react'
import { useCall, CallState, VoiceMode, formatDuration } from '../hooks/useCall'
import { useStore } from '../store'

type CallContextType = ReturnType<typeof useCall>

const CallContext = createContext<CallContextType | null>(null)

export function CallProvider({ children }: { children: ReactNode }) {
  const user = useStore(s => s.user)
  const call = useCall(user?.id)

  return (
    <CallContext.Provider value={call}>
      {children}
    </CallContext.Provider>
  )
}

export function useCallContext(): CallContextType {
  const ctx = useContext(CallContext)
  if (!ctx) throw new Error('useCallContext must be used within CallProvider')
  return ctx
}

export { formatDuration }
export type { CallState, VoiceMode }
