import { useCallback, useEffect, useState } from 'react'
import { Alert, Box, Button, Card, Chip, CircularProgress, Grid, Paper, Stack, Switch, Typography } from '@mui/material'
import DeviceThermostatIcon from '@mui/icons-material/DeviceThermostat'
import WaterDropIcon from '@mui/icons-material/WaterDrop'
import WbSunnyIcon from '@mui/icons-material/WbSunny'
import GrassIcon from '@mui/icons-material/Grass'
import LightbulbOutlinedIcon from '@mui/icons-material/LightbulbOutlined'
import RefreshIcon from '@mui/icons-material/Refresh'
import { CartesianGrid, Legend, Line, LineChart, ResponsiveContainer, Tooltip, XAxis, YAxis } from 'recharts'
import api from '../services/api'
import { useAuth } from '../contexts/AuthContext'

type Device = { deviceId: string; name: string; status: string; ledState: boolean; lastSeenAt: string | null }
type Telemetry = { id: string; temperature: number | null; humidity: number | null; illuminance: number | null; soilMoisture: number | null; recordedAt: string }
type Command = { id: string; action: string; status: string; createdAt: string }

const formatTime = (value?: string | null) => value ? new Date(value).toLocaleString('vi-VN') : 'Chưa có dữ liệu'
const metric = (value: number | null | undefined, unit: string) => value == null ? '—' : `${value.toFixed(1)} ${unit}`

function MetricCard({ label, value, unit, icon, tone, hint }: {
  label: string; value: number | null | undefined; unit: string; icon: React.ReactNode; tone: string; hint: string
}) {
  return <Card sx={{ p: 2.5, height: '100%', border: '1px solid #e7edf2', boxShadow: '0 8px 26px rgba(16,44,64,.04)', borderRadius: 3 }}>
    <Stack direction="row" alignItems="center" justifyContent="space-between" mb={2}>
      <Typography color="text.secondary" fontWeight={600}>{label}</Typography>
      <Box sx={{ width: 42, height: 42, display: 'grid', placeItems: 'center', borderRadius: 2, color: tone, bgcolor: `${tone}14` }}>{icon}</Box>
    </Stack>
    <Typography variant="h4" fontWeight={800} letterSpacing="-.04em">{metric(value, unit)}</Typography>
    <Typography variant="body2" color="text.secondary" mt={1}>{hint}</Typography>
  </Card>
}

export default function Dashboard() {
  const { role } = useAuth()
  const [device, setDevice] = useState<Device | null>(null)
  const [history, setHistory] = useState<Telemetry[]>([])
  const [commands, setCommands] = useState<Command[]>([])
  const [error, setError] = useState('')
  const [busy, setBusy] = useState(false)
  const [loading, setLoading] = useState(true)

  const refresh = useCallback(async () => {
    try {
      const [dev, hist, cmds] = await Promise.all([
        api.get('/devices/esp32-001'),
        api.get('/devices/esp32-001/telemetry?size=30'),
        api.get('/devices/esp32-001/commands?size=5'),
      ])
      setDevice(dev.data)
      setHistory([...hist.data.content].reverse())
      setCommands(cmds.data.content)
      setError('')
    } catch {
      setError('Không thể tải dữ liệu. Kiểm tra backend và kết nối mạng.')
    } finally {
      setLoading(false)
    }
  }, [])

  useEffect(() => {
    void refresh()
    const timer = window.setInterval(() => void refresh(), 5000)
    return () => window.clearInterval(timer)
  }, [refresh])

  const sendCommand = async () => {
    if (!device || busy || role === 'VIEWER' || device.status !== 'ONLINE') return
    setBusy(true)
    try {
      await api.post(`/devices/${device.deviceId}/commands`, { action: device.ledState ? 'LED_OFF' : 'LED_ON' })
      await refresh()
    } catch {
      setError('Không gửi được lệnh điều khiển LED.')
    } finally {
      setBusy(false)
    }
  }

  if (loading && !device) return <Stack alignItems="center" py={10}><CircularProgress /><Typography mt={2}>Đang tải bảng điều khiển...</Typography></Stack>

  const latest = history[history.length - 1]
  const hot = latest?.temperature != null && latest.temperature > 35
  const chartData = history.map(item => ({ ...item, time: new Date(item.recordedAt).toLocaleTimeString('vi-VN') }))
  const lastCommand = commands[0]

  return <Stack spacing={3}>
    <Stack direction={{ xs: 'column', sm: 'row' }} justifyContent="space-between" alignItems={{ sm: 'center' }} gap={2}>
      <Box>
        <Typography variant="overline" color="primary" fontWeight={800} letterSpacing={2}>SMART ENVIRONMENT</Typography>
        <Typography variant="h4" fontWeight={800} letterSpacing="-.04em">Tổng quan môi trường</Typography>
        <Typography color="text.secondary">Theo dõi cảm biến và điều khiển thiết bị theo thời gian thực.</Typography>
      </Box>
      <Button variant="outlined" startIcon={<RefreshIcon />} onClick={() => void refresh()}>Làm mới</Button>
    </Stack>

    {error && <Alert severity="error" onClose={() => setError('')}>{error}</Alert>}
    {hot && <Alert severity="warning" variant="filled">Cảnh báo nhiệt độ: {latest?.temperature?.toFixed(1)} °C vượt ngưỡng 35 °C. Hãy kiểm tra khu vực đặt thiết bị.</Alert>}

    <Paper sx={{ p: 2.5, borderRadius: 3, border: '1px solid #e7edf2', boxShadow: 'none' }}>
      <Stack direction={{ xs: 'column', sm: 'row' }} justifyContent="space-between" alignItems={{ sm: 'center' }} spacing={2}>
        <Stack direction="row" alignItems="center" spacing={2}>
          <Box sx={{ width: 48, height: 48, bgcolor: '#e9f5f3', borderRadius: 2, display: 'grid', placeItems: 'center', fontSize: 24 }}>◉</Box>
          <Box><Typography fontWeight={800}>{device?.name || 'ESP32'}</Typography><Typography variant="body2" color="text.secondary">esp32-001 · Cập nhật: {formatTime(device?.lastSeenAt)}</Typography></Box>
        </Stack>
        <Chip label={device?.status === 'ONLINE' ? 'Đang kết nối' : 'Ngoại tuyến'} color={device?.status === 'ONLINE' ? 'success' : 'default'} sx={{ fontWeight: 700 }} />
      </Stack>
    </Paper>

    <Grid container spacing={2.5}>
      <Grid item xs={12} sm={6} lg={3}><MetricCard label="Nhiệt độ" value={latest?.temperature} unit="°C" icon={<DeviceThermostatIcon />} tone="#de6f4c" hint="Dữ liệu từ DHT22" /></Grid>
      <Grid item xs={12} sm={6} lg={3}><MetricCard label="Độ ẩm không khí" value={latest?.humidity} unit="%" icon={<WaterDropIcon />} tone="#3c91ba" hint="Dữ liệu từ DHT22" /></Grid>
      <Grid item xs={12} sm={6} lg={3}><MetricCard label="Ánh sáng" value={latest?.illuminance} unit="lux" icon={<WbSunnyIcon />} tone="#d9a442" hint="Chưa lắp cảm biến thì để trống" /></Grid>
      <Grid item xs={12} sm={6} lg={3}><MetricCard label="Độ ẩm đất" value={latest?.soilMoisture} unit="%" icon={<GrassIcon />} tone="#5b9e75" hint="Chưa lắp cảm biến thì để trống" /></Grid>
    </Grid>

    <Grid container spacing={2.5}>
      <Grid item xs={12} lg={8}>
        <Paper sx={{ p: 3, height: '100%', minHeight: 390, borderRadius: 3, border: '1px solid #e7edf2', boxShadow: 'none' }}>
          <Typography variant="h6" fontWeight={800}>Biểu đồ cảm biến</Typography>
          <Typography variant="body2" color="text.secondary" mb={3}>30 mẫu gần nhất · tự cập nhật mỗi 5 giây</Typography>
          {history.length === 0 ? <Stack alignItems="center" justifyContent="center" height={270}><Typography color="text.secondary">Chưa có dữ liệu cảm biến</Typography></Stack> :
            <Box height={280}><ResponsiveContainer width="100%" height="100%"><LineChart data={chartData} margin={{ left: -20, right: 15 }}>
              <CartesianGrid stroke="#eef2f5" vertical={false} /><XAxis dataKey="time" tick={{ fontSize: 11 }} minTickGap={24} /><YAxis tick={{ fontSize: 11 }} />
              <Tooltip contentStyle={{ borderRadius: 12, border: '1px solid #e7edf2' }} /><Legend />
              <Line type="monotone" dataKey="temperature" name="Nhiệt độ (°C)" stroke="#de6f4c" strokeWidth={3} dot={false} connectNulls={false} />
              <Line type="monotone" dataKey="humidity" name="Độ ẩm (%)" stroke="#3c91ba" strokeWidth={3} dot={false} connectNulls={false} />
            </LineChart></ResponsiveContainer></Box>}
        </Paper>
      </Grid>
      <Grid item xs={12} lg={4}>
        <Paper sx={{ p: 3, height: '100%', borderRadius: 3, border: '1px solid #e7edf2', boxShadow: 'none' }}>
          <Typography variant="h6" fontWeight={800}>Điều khiển LED</Typography>
          <Typography variant="body2" color="text.secondary" mb={3}>Lệnh được xác nhận khi thiết bị gửi ACK.</Typography>
          <Box sx={{ p: 2.5, bgcolor: '#f4f8f8', borderRadius: 2.5 }}>
            <Stack direction="row" spacing={2} alignItems="center" justifyContent="space-between">
              <Stack direction="row" spacing={1.5} alignItems="center"><LightbulbOutlinedIcon color={device?.ledState ? 'warning' : 'disabled'} /><Box><Typography fontWeight={700}>LED chính</Typography><Typography variant="body2" color="text.secondary">{device?.ledState ? 'Đang bật' : 'Đang tắt'}</Typography></Box></Stack>
              <Switch checked={device?.ledState ?? false} onChange={() => void sendCommand()} disabled={role === 'VIEWER' || device?.status !== 'ONLINE' || busy} inputProps={{ 'aria-label': 'Điều khiển LED' }} />
            </Stack>
          </Box>
          <Typography variant="body2" color="text.secondary" mt={2}>{role === 'VIEWER' ? 'Tài khoản viewer chỉ có quyền xem.' : device?.status !== 'ONLINE' ? 'Thiết bị ngoại tuyến, chưa thể gửi lệnh.' : busy ? 'Đang gửi lệnh...' : 'Bật hoặc tắt để gửi lệnh đến thiết bị.'}</Typography>
          <Box sx={{ borderTop: '1px solid #e7edf2', mt: 3, pt: 2 }}>
            <Typography fontWeight={700} mb={1}>Lệnh gần nhất</Typography>
            {lastCommand ? <><Typography variant="body2">{lastCommand.action === 'LED_ON' ? 'Bật LED' : 'Tắt LED'} · <strong>{lastCommand.status}</strong></Typography><Typography variant="caption" color="text.secondary">{formatTime(lastCommand.createdAt)}</Typography></> : <Typography variant="body2" color="text.secondary">Chưa có lệnh nào.</Typography>}
          </Box>
        </Paper>
      </Grid>
    </Grid>
  </Stack>
}
