import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'

export default defineConfig({
  plugins: [vue()],
  server: {
    port: 7788,
    strictPort: true,
    host: true,
    open: true
  },
  preview: {
    port: 7788,
    strictPort: true
  }
})
