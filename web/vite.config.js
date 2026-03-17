import { defineConfig } from 'vite'
import { resolve } from 'path'
import fs from 'fs'

// Find all PackageToJS outputs and serve them
const packageDir = resolve(__dirname, '../.build/plugins/PackageToJS/outputs/Package')

export default defineConfig({
  root: '.',
  server: {
    port: 3000,
  },
  resolve: {
    alias: {
      // Allow importing from the PackageToJS output
      '@pkg': packageDir,
    },
  },
  optimizeDeps: {
    exclude: ['@pkg'],
  },
})
