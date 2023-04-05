import { fileURLToPath, URL } from 'node:url'

import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'

// https://vitejs.dev/config/
export default defineConfig({
  plugins: [vue()],
  resolve: {
    alias: {
      '@': fileURLToPath(new URL('./src', import.meta.url))
    }
  },
  build: {
    outDir: '../dist',
    // assetsDir: 'admin'
    assetsDir: 'admin/assets',
    copyPublicDir: true,
    // rollupOptions: {
    //   output: {
    //     assetFileNames: 'admin/assets/[name]-[hash][extname]',
    //     entryFileNames: 'admin/assets/[name].js',
    //   },
    // }
  },
})
