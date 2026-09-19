import { useCallback, useEffect, useState } from 'react'
import { Alert, Box, Paper, Table, TableBody, TableCell, TableContainer, TableHead, TablePagination, TableRow, Typography } from '@mui/material'
import api from '../services/api'

type Telemetry = { id: string; temperature: number | null; humidity: number | null; illuminance: number | null; soilMoisture: number | null; recordedAt: string }
const display = (value: number | null) => value == null ? '—' : value.toFixed(1)

export default function Logs() {
  const [logs, setLogs] = useState<Telemetry[]>([])
  const [page, setPage] = useState(0)
  const [total, setTotal] = useState(0)
  const [error, setError] = useState('')
  const rowsPerPage = 10

  const fetchLogs = useCallback(async () => {
    try {
      const response = await api.get(`/devices/esp32-001/telemetry?page=${page}&size=${rowsPerPage}`)
      setLogs(response.data.content)
      setTotal(response.data.totalElements)
      setError('')
    } catch {
      setError('Không thể tải lịch sử đo. Kiểm tra kết nối backend.')
    }
  }, [page])

  useEffect(() => {
    void fetchLogs()
    const timer = window.setInterval(() => void fetchLogs(), 10000)
    return () => window.clearInterval(timer)
  }, [fetchLogs])

  return <Box>
    <Typography variant="h4" fontWeight={800} mb={1}>Lịch sử đo</Typography>
    <Typography color="text.secondary" mb={3}>Dữ liệu của esp32-001 · cập nhật mỗi 10 giây</Typography>
    {error && <Alert severity="error" sx={{ mb: 2 }}>{error}</Alert>}
    <Paper sx={{ border: '1px solid #e7edf2', borderRadius: 3, boxShadow: 'none', overflow: 'hidden' }}>
      <TableContainer sx={{ maxHeight: 650 }}><Table stickyHeader>
        <TableHead><TableRow>
          <TableCell sx={{ fontWeight: 800 }}>Thời gian</TableCell>
          <TableCell align="right" sx={{ fontWeight: 800 }}>Nhiệt độ (°C)</TableCell>
          <TableCell align="right" sx={{ fontWeight: 800 }}>Độ ẩm (%)</TableCell>
          <TableCell align="right" sx={{ fontWeight: 800 }}>Ánh sáng (lux)</TableCell>
          <TableCell align="right" sx={{ fontWeight: 800 }}>Độ ẩm đất (%)</TableCell>
        </TableRow></TableHead>
        <TableBody>{logs.map(row => <TableRow hover key={row.id}>
          <TableCell>{new Date(row.recordedAt).toLocaleString('vi-VN')}</TableCell>
          <TableCell align="right">{display(row.temperature)}</TableCell>
          <TableCell align="right">{display(row.humidity)}</TableCell>
          <TableCell align="right">{display(row.illuminance)}</TableCell>
          <TableCell align="right">{display(row.soilMoisture)}</TableCell>
        </TableRow>)}
        {logs.length === 0 && <TableRow><TableCell colSpan={5} align="center">Chưa có dữ liệu đo.</TableCell></TableRow>}
        </TableBody>
      </Table></TableContainer>
      <TablePagination component="div" rowsPerPageOptions={[rowsPerPage]} count={total} rowsPerPage={rowsPerPage} page={page} onPageChange={(_, next) => setPage(next)} />
    </Paper>
  </Box>
}
