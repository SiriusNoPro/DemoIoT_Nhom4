import React from 'react'
import ReactDOM from 'react-dom/client'
import App from './App.tsx'
import { CssBaseline, ThemeProvider, createTheme } from '@mui/material'
import { AuthProvider } from './contexts/AuthContext.tsx'

const theme = createTheme({
  palette: {
    mode: 'light',
    primary: { main: '#18715f' },
    secondary: { main: '#3c91ba' },
    background: { default: '#f6f8f8' },
  },
  typography: { fontFamily: 'Inter, Segoe UI, Arial, sans-serif' },
  shape: { borderRadius: 12 },
})

ReactDOM.createRoot(document.getElementById('root')!).render(
  <React.StrictMode>
    <ThemeProvider theme={theme}>
      <CssBaseline />
      <AuthProvider>
        <App />
      </AuthProvider>
    </ThemeProvider>
  </React.StrictMode>,
)
