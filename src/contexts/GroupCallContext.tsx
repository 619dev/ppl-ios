/**
 * Global Group Call Context
 *
 * Provides group call state to the entire app so incoming group calls
 * can be received from any page, not just the Chat page.
 */
import { createContext, useContext, ReactNode } from 'react'
import { useGroupCall, GroupCallStatus, VoiceMode, formatDuration } from '../hooks/useGroupCall'
import { useStore } from '../store'

type GroupCallContextType = ReturnType<typeof useGroupCall>

const GroupCallContext = createContext<GroupCallContextType | null>(null)

export function GroupCallProvider({ children }: { children: ReactNode }) {
  const user = useStore(s => s.user)
  const groupCall = useGroupCall(user?.id)

  return (
    <GroupCallContext.Provider value={groupCall}>
      {children}
    </GroupCallContext.Provider>
  )
}

export function useGroupCallContext(): GroupCallContextType {
  const ctx = useContext(GroupCallContext)
  if (!ctx) throw new Error('useGroupCallContext must be used within GroupCallProvider')
  return ctx
}

export { formatDuration }
export type { GroupCallStatus, VoiceMode }
