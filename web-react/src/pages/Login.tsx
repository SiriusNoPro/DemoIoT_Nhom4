import { useState } from 'react'
import { Alert, Box, Button, Paper, Stack, TextField, Typography } from '@mui/material'
import api from '../services/api'
import { useAuth } from '../contexts/AuthContext'

export default function Login() {
  const [username, setUsername] = useState('')
  const [password, setPassword] = useState('')
  const [error, setError] = useState('')
  const [busy, setBusy] = useState(false)
  const { login } = useAuth()

  const handleLogin = async (event: React.FormEvent) => {
    event.preventDefault()
    setBusy(true)
    setError('')
    try {
      const response = await api.post('/auth/login', { username, password })
      login(response.data.accessToken, response.data.role)
    } catch {
      setError('Đăng nhập thất bại. Kiểm tra tài khoản, mật khẩu hoặc backend.')
    } finally {
      setBusy(false)
    }
  }

  return <Box sx={{ minHeight: '100vh', display: 'grid', gridTemplateColumns: { xs: '1fr', md: '1fr 1fr' }, bgcolor: '#f6f8f8' }}>
    <Stack justifyContent="space-between" sx={{ display: { xs: 'none', md: 'flex' }, p: 6, color: '#fff', bgcolor: '#153f38', backgroundImage: 'radial-gradient(circle at 80% 20%, #327c69 0, transparent 42%), linear-gradient(145deg, #153f38, #102c2a)' }}>
      <Typography variant="h5" fontWeight={800}>◉ EcoSense</Typography>
      <Box><Typography variant="overline" sx={{ letterSpacing: 3, color: '#9ce0c9' }}>IoT SMART ENVIRONMENT</Typography><Typography variant="h2" fontWeight={800} lineHeight={1.12} mt={2}>Hiểu môi trường.<br />Chủ động điều khiển.</Typography><Typography variant="h6" sx={{ opacity: .75, mt: 3, maxWidth: 460, fontWeight: 400 }}>Một nơi để theo dõi cảm biến, trạng thái thiết bị và lệnh điều khiển.</Typography></Box>
      <Typography sx={{ opacity: .6 }}>ESP32 · MQTT · Spring Boot · React</Typography>
    </Stack>
    <Stack alignItems="center" justifyContent="center" sx={{ p: 3 }}>
      <Paper elevation={0} sx={{ width: '100%', maxWidth: 430, p: { xs: 3, sm: 5 }, borderRadius: 4, border: '1px solid #e7edf2' }}>
        <Typography color="primary" fontWeight={800} sx={{ display: { md: 'none' }, mb: 3 }}>◉ EcoSense</Typography>
        <Typography variant="h4" fontWeight={800}>Chào mừng trở lại</Typography>
        <Typography color="text.secondary" mt={1} mb={4}>Đăng nhập để xem trạm môi trường của bạn.</Typography>
        <form onSubmit={handleLogin}>
          <Stack spacing={2.5}>
            <TextField required fullWidth label="Tên đăng nhập" autoComplete="username" value={username} onChange={e => setUsername(e.target.value)} />
            <TextField required fullWidth label="Mật khẩu" type="password" autoComplete="current-password" value={password} onChange={e => setPassword(e.target.value)} />
            {error && <Alert severity="error">{error}</Alert>}
            <Button fullWidth size="large" variant="contained" type="submit" disabled={busy} sx={{ py: 1.5 }}>{busy ? 'Đang đăng nhập...' : 'Đăng nhập'}</Button>
          </Stack>
        </form>
        <Typography variant="body2" color="text.secondary" mt={4}>Tài khoản demo: operator / Operator@123</Typography>
      </Paper>
    </Stack>
  </Box>
}
