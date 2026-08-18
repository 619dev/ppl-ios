import { useEffect, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { ChevronLeft, File as FileIcon, Search } from 'lucide-react'
import { get } from '../api/http'
import { clearPendingSharedFile, getPendingSharedFile, type PendingSharedFile } from '../api/sharedFile'
import { Friend, useStore } from '../store'

export default function ShareTarget() {
  const navigate = useNavigate()
  const friends = useStore(state => state.friends)
  const setFriends = useStore(state => state.setFriends)
  const [pending, setPending] = useState<PendingSharedFile | null>(null)
  const [search, setSearch] = useState('')
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    Promise.all([
      getPendingSharedFile(),
      get<Friend[]>('/api/friends').then(setFriends),
    ]).then(([file]) => setPending(file)).finally(() => setLoading(false))
  }, [setFriends])

  const cancel = async () => {
    await clearPendingSharedFile(pending?.id).catch(() => undefined)
    navigate('/chats', { replace: true })
  }

  const visibleFriends = friends.filter(friend =>
    `${friend.nickname} ${friend.username}`.toLowerCase().includes(search.trim().toLowerCase())
  )

  return (
    <div className="page">
      <header className="page-header">
        <button className="icon-btn" onClick={cancel} aria-label="取消"><ChevronLeft size={24} /></button>
        <h1>发送给联系人</h1>
      </header>
      {pending && (
        <div className="card" style={{ margin: '12px 16px', display: 'flex', gap: 12, alignItems: 'center' }}>
          <FileIcon size={28} />
          <div style={{ minWidth: 0 }}>
            <div style={{ fontWeight: 600, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{pending.name}</div>
            <div className="preview">{formatSize(pending.size)}</div>
          </div>
        </div>
      )}
      <div style={{ margin: '8px 16px 12px', position: 'relative' }}>
        <Search size={17} style={{ position: 'absolute', left: 12, top: 11, color: 'var(--text-muted)' }} />
        <input className="input" value={search} onChange={e => setSearch(e.target.value)} placeholder="搜索联系人" style={{ paddingLeft: 38 }} />
      </div>
      {loading ? <div className="empty-state">正在准备文件…</div> : !pending ? (
        <div className="empty-state">没有可发送的文件</div>
      ) : (
        <div className="list">
          {visibleFriends.map(friend => (
            <button key={friend.id} className="list-item" style={{ width: '100%', border: 0, textAlign: 'left' }}
              onClick={() => navigate(`/chat/${friend.id}?share=1`)}>
              <div className="avatar">{friend.nickname?.[0] || friend.username?.[0] || '?'}</div>
              <div className="content"><div className="name">{friend.nickname || friend.username}</div><div className="preview">@{friend.username}</div></div>
            </button>
          ))}
          {visibleFriends.length === 0 && <div className="empty-state">没有匹配的联系人</div>}
        </div>
      )}
    </div>
  )
}

function formatSize(bytes: number) {
  if (bytes < 1024) return `${bytes} B`
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`
  return `${(bytes / 1024 / 1024).toFixed(1)} MB`
}
