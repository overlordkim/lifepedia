import { useState, useRef } from 'react'
import { useNavigate } from 'react-router-dom'
import { Camera } from 'lucide-react'
import { useAuth } from '../contexts/AuthContext'
import { uploadImage } from '../lib/supabase'
import Avatar from '../components/shared/Avatar'

export default function SettingsPage() {
  const navigate = useNavigate()
  const { user, logout, updateLocalProfile } = useAuth()
  const [editingName, setEditingName] = useState(user?.display_name || '')
  const [editingBio, setEditingBio] = useState(user?.bio || '')
  const [saving, setSaving] = useState(false)
  const [isUploading, setIsUploading] = useState(false)
  const [avatarKey, setAvatarKey] = useState(0)
  const fileRef = useRef<HTMLInputElement>(null)

  async function handleSave() {
    const name = editingName.trim() || '我'
    const bio = editingBio.trim() || '用百科的方式，记录我的人生'
    setSaving(true)
    updateLocalProfile({ display_name: name, bio })
    setSaving(false)
    navigate(-1)
  }

  async function handleAvatarChange(e: React.ChangeEvent<HTMLInputElement>) {
    const file = e.target.files?.[0]
    if (!file || !user) return
    setIsUploading(true)
    try {
      const blob = new Blob([await file.arrayBuffer()], { type: 'image/jpeg' })
      await uploadImage(blob, `../avatars/${user.id}.jpg`)
      setAvatarKey(prev => prev + 1)
    } catch (err: any) {
      alert('头像上传失败: ' + err.message)
    } finally {
      setIsUploading(false)
    }
  }

  function handleLogout() {
    logout()
    navigate('/', { replace: true })
  }

  if (!user) return null

  return (
    <div className="flex flex-col h-screen bg-[#F4F4F4]">
      {/* 顶栏 */}
      <div className="flex items-center px-4 h-12 shrink-0 bg-white border-b border-wiki-divider">
        <button onClick={() => navigate(-1)} className="text-wiki-secondary text-base">取消</button>
        <span className="flex-1 text-center text-[17px] font-semibold">设置</span>
        <div className="w-10" />
      </div>

      <div className="flex-1 overflow-y-auto">
        <div className="pt-6 space-y-6">
          {/* 头像 */}
          <div className="flex flex-col items-center gap-3">
            <button onClick={() => fileRef.current?.click()} className="relative">
              {isUploading ? (
                <div className="w-[88px] h-[88px] rounded-full bg-wiki-bg-secondary flex items-center justify-center">
                  <span className="w-6 h-6 border-2 border-wiki-border border-t-wiki-blue rounded-full animate-spin" />
                </div>
              ) : (
                <Avatar key={avatarKey} userId={user.id} name={user.display_name} size={88} />
              )}
              <div className="absolute bottom-0 right-0 w-[26px] h-[26px] bg-wiki-blue text-white rounded-full flex items-center justify-center shadow">
                <Camera size={13} />
              </div>
            </button>
            <p className="text-wiki-small text-wiki-tertiary">点击更换头像</p>
            <input ref={fileRef} type="file" accept="image/*" className="hidden" onChange={handleAvatarChange} />
          </div>

          {/* 信息卡片 */}
          <div className="mx-4 bg-white rounded-xl overflow-hidden">
            <div className="flex items-center gap-3 px-4 py-3.5">
              <span className="text-[15px] text-wiki-secondary w-[52px]">昵称</span>
              <input
                type="text"
                value={editingName}
                onChange={e => setEditingName(e.target.value)}
                placeholder="你的昵称"
                className="flex-1 text-[15px]"
              />
            </div>
            <div className="h-px bg-wiki-divider ml-[76px]" />
            <div className="flex items-start gap-3 px-4 py-3.5">
              <span className="text-[15px] text-wiki-secondary w-[52px] pt-0.5">签名</span>
              <textarea
                value={editingBio}
                onChange={e => setEditingBio(e.target.value)}
                placeholder="一句话介绍自己"
                rows={2}
                className="flex-1 text-[15px] resize-none"
              />
            </div>
          </div>

          {/* 关于卡片 */}
          <div className="mx-4 bg-white rounded-xl overflow-hidden">
            <div className="flex items-center px-4 py-3.5">
              <span className="text-[15px]">版本</span>
              <div className="flex-1" />
              <span className="text-[15px] text-wiki-tertiary">1.0.0 beta</span>
            </div>
          </div>

          {/* 保存 */}
          <div className="mx-4">
            <button
              onClick={handleSave}
              disabled={saving}
              className="w-full py-3 bg-wiki-blue text-white rounded-full font-semibold text-base"
            >
              {saving ? '保存中…' : '保存'}
            </button>
          </div>

          {/* 退出登录 */}
          <div className="mx-4">
            <button
              onClick={handleLogout}
              className="w-full py-3 text-red-500 text-base font-medium bg-white rounded-xl"
            >
              退出登录
            </button>
          </div>

          <div className="h-10" />
        </div>
      </div>
    </div>
  )
}
