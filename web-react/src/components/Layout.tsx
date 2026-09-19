import { Outlet, useLocation, useNavigate } from 'react-router-dom'
import { AppBar, Box, Button, Chip, CssBaseline, Drawer, IconButton, List, ListItemButton, ListItemIcon, ListItemText, Toolbar, Typography } from '@mui/material'
import DashboardIcon from '@mui/icons-material/Dashboard'
import ListAltIcon from '@mui/icons-material/ListAlt'
import LogoutIcon from '@mui/icons-material/Logout'
import MenuIcon from '@mui/icons-material/Menu'
import { useState } from 'react'
import { useAuth } from '../contexts/AuthContext'

const drawerWidth = 246

export default function Layout() {
  const { logout, role, token } = useAuth()
  const navigate = useNavigate()
  const location = useLocation()
  const [mobileOpen, setMobileOpen] = useState(false)
  if (!token) return null

  const menu = <Box sx={{ p: 2 }}>
    <Box sx={{ px: 1.5, pt: 2, pb: 4 }}>
      <Typography variant="h6" fontWeight={800} color="primary">◉ EcoSense</Typography>
      <Typography variant="caption" color="text.secondary">IoT MONITORING STUDIO</Typography>
    </Box>
    {[{ label: 'Tổng quan', path: '/', icon: <DashboardIcon /> }, { label: 'Lịch sử đo', path: '/logs', icon: <ListAltIcon /> }].map(item =>
      <List key={item.path} disablePadding sx={{ mb: 1 }}><ListItemButton selected={location.pathname === item.path} onClick={() => { navigate(item.path); setMobileOpen(false) }} sx={{ borderRadius: 2, '&.Mui-selected': { bgcolor: '#e7f4f1', color: '#18715f' } }}>
        <ListItemIcon sx={{ minWidth: 38, color: 'inherit' }}>{item.icon}</ListItemIcon><ListItemText primary={item.label} primaryTypographyProps={{ fontWeight: 700 }} />
      </ListItemButton></List>)
    }
  </Box>

  return <Box sx={{ display: 'flex', minHeight: '100vh', bgcolor: '#f6f8f8' }}>
    <CssBaseline />
    <AppBar position="fixed" elevation={0} sx={{ bgcolor: '#fff', color: 'text.primary', borderBottom: '1px solid #e7edf2', width: { md: `calc(100% - ${drawerWidth}px)` }, ml: { md: `${drawerWidth}px` } }}>
      <Toolbar sx={{ gap: 2 }}>
        <IconButton edge="start" onClick={() => setMobileOpen(true)} sx={{ display: { md: 'none' } }} aria-label="Mở menu"><MenuIcon /></IconButton>
        <Typography fontWeight={800} sx={{ flexGrow: 1 }}>Trạm môi trường thông minh</Typography>
        <Chip label={role || 'USER'} size="small" sx={{ fontWeight: 700, bgcolor: '#e7f4f1', color: '#18715f' }} />
        <Button color="inherit" startIcon={<LogoutIcon />} onClick={() => { logout(); navigate('/login') }} sx={{ display: { xs: 'none', sm: 'inline-flex' } }}>Đăng xuất</Button>
        <IconButton onClick={() => { logout(); navigate('/login') }} sx={{ display: { sm: 'none' } }} aria-label="Đăng xuất"><LogoutIcon /></IconButton>
      </Toolbar>
    </AppBar>
    <Box component="nav" sx={{ width: { md: drawerWidth }, flexShrink: { md: 0 } }}>
      <Drawer variant="temporary" open={mobileOpen} onClose={() => setMobileOpen(false)} ModalProps={{ keepMounted: true }} sx={{ display: { xs: 'block', md: 'none' }, '& .MuiDrawer-paper': { width: drawerWidth } }}>{menu}</Drawer>
      <Drawer variant="permanent" open sx={{ display: { xs: 'none', md: 'block' }, '& .MuiDrawer-paper': { width: drawerWidth, borderRight: '1px solid #e7edf2' } }}>{menu}</Drawer>
    </Box>
    <Box component="main" sx={{ flexGrow: 1, minWidth: 0, p: { xs: 2, sm: 3, lg: 4 } }}><Toolbar /><Outlet /></Box>
  </Box>
}
