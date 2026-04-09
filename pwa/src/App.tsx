import { useState, useCallback, useEffect } from 'react'
import { BrowserRouter, Routes, Route, Navigate, useNavigate, useLocation } from 'react-router-dom'
import { AuthProvider, useAuth } from './contexts/AuthContext'
import LoginPage from './pages/LoginPage'
import FeedPage from './pages/FeedPage'
import EntryPage from './pages/EntryPage'
import ComposePage from './pages/ComposePage'
import MyPage from './pages/MyPage'
import UserProfilePage from './pages/UserProfilePage'
import SettingsPage from './pages/SettingsPage'
import NotificationsPage from './pages/NotificationsPage'
import TabBar from './components/layout/TabBar'

function AppShell() {
  const { isLoggedIn } = useAuth()

  if (!isLoggedIn) return <LoginPage />

  return (
    <BrowserRouter>
      <Routes>
        <Route path="/" element={<MainLayout initialTab="feed" />} />
        <Route path="/me" element={<MainLayout initialTab="myPage" />} />
        <Route path="/entry/:id" element={<EntryPage />} />
        <Route path="/compose" element={<ComposePage />} />
        <Route path="/user/:userId" element={<UserProfilePage />} />
        <Route path="/settings" element={<SettingsPage />} />
        <Route path="/notifications" element={<NotificationsPage />} />
        <Route path="*" element={<Navigate to="/" replace />} />
      </Routes>
    </BrowserRouter>
  )
}

function MainLayout({ initialTab }: { initialTab: 'feed' | 'myPage' }) {
  const navigate = useNavigate()
  const location = useLocation()
  const [tab, setTab] = useState<'feed' | 'myPage'>(initialTab)

  useEffect(() => {
    setTab(initialTab)
  }, [initialTab])

  const handleSelect = useCallback((t: 'feed' | 'myPage') => {
    setTab(t)
    navigate(t === 'feed' ? '/' : '/me', { replace: true })
  }, [navigate])

  const handleCompose = useCallback(() => navigate('/compose'), [navigate])

  return (
    <div className="h-screen flex flex-col">
      <div className="flex-1 overflow-hidden">
        {tab === 'feed' ? <FeedPage /> : <MyPage />}
      </div>
      <TabBar selected={tab} onSelect={handleSelect} onCompose={handleCompose} visible />
    </div>
  )
}

export default function App() {
  return (
    <AuthProvider>
      <AppShell />
    </AuthProvider>
  )
}
