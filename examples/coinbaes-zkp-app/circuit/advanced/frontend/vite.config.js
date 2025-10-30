import { defineConfig } from 'vite';
import { resolve } from 'path';
import { nodePolyfills } from 'vite-plugin-node-polyfills';

export default defineConfig({
  root: '.',
  build: {
    outDir: 'dist',
    target: 'esnext',
    rollupOptions: {
      input: {
        main: resolve(__dirname, 'index.html')
      }
    }
  },
  plugins: [
    nodePolyfills()
  ],
  server: {
    port: 5174,
    open: true,
    headers: {
      'Cross-Origin-Opener-Policy': 'same-origin',
      'Cross-Origin-Embedder-Policy': 'require-corp',
      'Content-Security-Policy': "default-src 'self'; script-src 'self' 'unsafe-eval' 'unsafe-inline'; style-src 'self' 'unsafe-inline'; connect-src 'self' https://mainnet.base.org https://base.easscan.org https://crs.aztec.network data: blob:; worker-src 'self' blob:;"
    }
  },
  resolve: {
    alias: {
      '../target/advanced.json': resolve(__dirname, '../target/advanced.json'),
      'pino': 'pino/browser.js'
    }
  },
  optimizeDeps: {
    esbuildOptions: {
      target: 'esnext'
    },
    exclude: ['@noir-lang/noirc_abi', '@noir-lang/acvm_js', '@aztec/bb.js']
  },
  worker: {
    format: 'es'
  }
});
