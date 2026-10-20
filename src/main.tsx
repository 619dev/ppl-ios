import React from 'react'
import ReactDOM from 'react-dom/client'
import App from './App'
import './index.css'
import { getPlatform } from './utils/platform'

document.documentElement.dataset.platform = getPlatform()

ReactDOM.createRoot(document.getElementById('root')!).render(
  <React.StrictMode>
    <div id="app-shell"><App /></div>
  </React.StrictMode>,
)
