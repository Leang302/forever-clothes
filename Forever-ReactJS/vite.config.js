import path from 'node:path'
import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

// https://vitejs.dev/config/
export default defineConfig({
  plugins: [react()],
  resolve: {
    // `@/` = src/, the import alias shadcn/ui components use.
    alias: { '@': path.resolve(import.meta.dirname, './src') },
  },
})
